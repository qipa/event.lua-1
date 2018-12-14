#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include "ev.h"
#include "socket/socket_tcp.h"
#include "socket/socket_httpc.h"
#include "socket/socket_util.h"
#include "socket/pipe_message.h"

#define LUA_EV_ERROR    0
#define LUA_EV_TIMEOUT	1
#define LUA_EV_ACCEPT   2
#define LUA_EV_CONNECT  3
#define LUA_EV_DATA     4

#define META_EVENT 			"meta_event"
#define META_SESSION 		"meta_session"
#define META_TIMER			"meta_timer"
#define META_LISTENER 		"meta_listener"
#define META_UDP 			"meta_udp"
#define META_PIPE			"meta_pipe"
#define META_REQUEST		"meta_request"

#define STATE_HEAD 0
#define STATE_BODY 1

#define HEADER_TYPE_WORD 	2
#define HEADER_TYPE_DWORD 	4

#define THREAD_CACHED_SIZE (1024 * 1024)
#define MAX_PACKET_SIZE (16 * 1024 * 1024)

#define MB (1024*1024)

__thread char THREAD_CACHED_BUFFER[THREAD_CACHED_SIZE];

struct lua_ev_timer;

struct lua_ev {
	struct ev_loop_ctx* loop_ctx;
	struct http_multi* multi;
	lua_State* main;
	int ref;
	int callback;
	struct lua_ev_timer* freelist;
};

struct lua_ev_session {
	struct lua_ev* lev;
	struct ev_session* session;
	int ref;
	int closed;
	int wait;

	int execute;
	int markdead;

	int header;
	int state;
	int need;
		
	int threhold;
};

struct lua_ev_listener {
	struct lua_ev* lev;
	struct ev_listener* listener;
	int ref;
	int closed;
	int header;
};

struct lua_ev_timer {
	struct lua_ev* lev;
	struct ev_timer io;
	int ref;
	struct lua_ev_timer* next;
};

struct lua_udp_session {
	struct lua_ev* lev;
	struct ev_io rio;
	int fd;

	int ref;
	int closed;
	int callback;

	char* recv_buffer;
	size_t recv_size;
};

struct lua_pipe {
	struct lua_ev* lev;
	struct ev_io io;
	int recv_fd;
	int send_fd;
	int ref;
	int callback;
	int closed;
};

struct lua_httpc {
	struct lua_ev* lev;
	struct http_request* lrequest;
	int ref;
	int callback;
};

static int
meta_init(lua_State* L,const char* meta) {
	luaL_newmetatable(L,meta);
 	lua_setmetatable(L, -2);
	lua_pushvalue(L, -1);
	return luaL_ref(L, LUA_REGISTRYINDEX);
}

static struct lua_ev_session*
session_create(lua_State* L, struct lua_ev* lev,int fd,int header) {
	struct lua_ev_session* lev_session = lua_newuserdata(L, sizeof(struct lua_ev_session));
	memset(lev_session, 0, sizeof(*lev_session));
	lev_session->lev = lev;
	lev_session->closed = 0;
	lev_session->header = header;
	lev_session->state = STATE_HEAD;
	lev_session->execute = 0;
	lev_session->markdead = 0;
	lev_session->threhold = MB;

	if (fd > 0)
		lev_session->session = ev_session_bind(lev->loop_ctx, fd);

	lev_session->ref = meta_init(L,META_SESSION);

	return lev_session;
}

static int
session_destroy(struct lua_ev_session* lev_session) {
	struct lua_ev* lev = lev_session->lev;
	luaL_unref(lev->main, LUA_REGISTRYINDEX, lev_session->ref);
	ev_session_free(lev_session->session);
	return 0;
}

static inline void
udp_destroy(struct lua_udp_session* udp_session) {
	struct lua_ev* lev = udp_session->lev;
	luaL_unref(lev->main, LUA_REGISTRYINDEX, udp_session->ref);
	luaL_unref(lev->main, LUA_REGISTRYINDEX, udp_session->callback);
	if (ev_is_active(&udp_session->rio))
		ev_io_stop(loop_ctx_get(lev->loop_ctx), &udp_session->rio);

	udp_session->closed = 1;
	free(udp_session->recv_buffer);
	close(udp_session->fd);
}

static void
error_occur(struct ev_session* ev_session,void* ud) {
	struct lua_ev_session* lev_session = ud;
	struct lua_ev* lev = lev_session->lev;

	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev->callback);
	lua_pushinteger(lev->main, LUA_EV_ERROR);
	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev_session->ref);
	lua_pcall(lev->main, 2, 0, 0);

	lev_session->closed = 1;

	if (lev_session->execute) {
		lev_session->markdead = 1;
	} else {
		session_destroy(lev_session);
	}
}

static void
read_complete(struct ev_session* ev_session, void* ud) {
	struct lua_ev_session* lev_session = ud;
	lev_session->execute = 1;

	struct lua_ev* lev = lev_session->lev;

	if (lev_session->header == 0) {
		lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev->callback);
		lua_pushinteger(lev->main, LUA_EV_DATA);
		lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev_session->ref);
		lua_pcall(lev->main, 2, 0, 0);
	} else {
		while(lev_session->markdead == 0) {
			size_t len = ev_session_input_size(lev_session->session);
			if (lev_session->state == STATE_HEAD) {
				if (len < lev_session->header)
					break;

				if (lev_session->header == HEADER_TYPE_WORD) {
					uint8_t header[HEADER_TYPE_WORD];
					ev_session_read(lev_session->session,(char*)header,HEADER_TYPE_WORD);
					lev_session->need = header[0] | header[1] << 8;
				} else {
					assert(lev_session->header == HEADER_TYPE_DWORD);
					uint8_t header[HEADER_TYPE_DWORD];
					ev_session_read(lev_session->session,(char*)header,HEADER_TYPE_DWORD);
					lev_session->need = header[0] | header[1] << 8 | header[2] << 16 | header[3] << 24;
				}
				lev_session->need -= lev_session->header;
				lev_session->state = STATE_BODY;
			} else if (lev_session->state == STATE_BODY) {
				if (len < lev_session->need)
					break;

				if (lev_session->need > MAX_PACKET_SIZE) {
					error_occur(ev_session, ud);
					break;
				}
				
				char* data = THREAD_CACHED_BUFFER;
				if (lev_session->need > THREAD_CACHED_SIZE)
					data = malloc(lev_session->need);

				ev_session_read(lev_session->session,data,lev_session->need);

				lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev->callback);
				lua_pushinteger(lev->main, LUA_EV_DATA);
				lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev_session->ref);
				lua_pushlightuserdata(lev->main,data);
				lua_pushinteger(lev->main,lev_session->need);
				lua_pcall(lev->main, 4, 0, 0);
				lev_session->state = STATE_HEAD;

				if (data != THREAD_CACHED_BUFFER)
					free(data);
			}
		}
	}

	lev_session->execute = 0;

	if (lev_session->markdead) {
		session_destroy(lev_session);
	}
}	

static void
close_complete(struct ev_session* ev_session, void* ud) {
	struct lua_ev_session* lev_session = ud;
	struct lua_ev* lev = lev_session->lev;
	assert(lev_session->closed == 1);

	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev->callback);
	lua_pushinteger(lev->main, LUA_EV_ERROR);
	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev_session->ref);

	session_destroy(lev_session);

	lua_pcall(lev->main, 2, 0, 0);
}

static void
connect_complete(struct ev_session* session,void *userdata) {
	struct lua_ev_session* lev_session = userdata;
	struct lua_ev* lev = lev_session->lev;

	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev->callback);
	lua_pushinteger(lev->main, LUA_EV_CONNECT);
	lua_pushinteger(lev->main, lev_session->wait);

	int fd = ev_session_fd(session);
	int error;
	socklen_t len = sizeof(error);  
	int code = getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len);  
	if (code < 0 || error) {  
		char* strerr;
		if (code >= 0) {
			strerr = strerror(error);
		} else {
			strerr = strerror(errno);
		}
		lua_pushboolean(lev->main,0);
		lua_pushstring(lev->main,strerr);
		session_destroy(lev_session);
	} else {
		socket_nonblock(fd);
		socket_keep_alive(fd);
		socket_closeonexec(fd);

		lua_pushboolean(lev->main,1);
		lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev_session->ref);

		ev_session_setcb(lev_session->session,read_complete,NULL,error_occur,lev_session);
		ev_session_disable(lev_session->session,EV_WRITE);
		ev_session_enable(lev_session->session,EV_READ);
	}
	lua_pcall(lev->main, 4, 0, 0);
}

static void 
accept_socket(struct ev_listener *listener, int fd, const char* addr, void *ud) {
	struct lua_ev_listener* lev_listener = ud;
	struct lua_ev* lev = lev_listener->lev;

	socket_nonblock(fd);
	socket_no_delay(fd);
	socket_keep_alive(fd);
	socket_closeonexec(fd);

	struct lua_ev_session* lev_session = session_create(lev->main, lev, fd, lev_listener->header);

	ev_session_setcb(lev_session->session,read_complete,NULL,error_occur,lev_session);
	ev_session_enable(lev_session->session,EV_READ);

	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev->callback);
	lua_pushinteger(lev->main, LUA_EV_ACCEPT);
	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev_listener->ref);
	lua_pushvalue(lev->main,-4);
	lua_pushstring(lev->main,addr);

	lua_pcall(lev->main, 4, 0, 0);
}

static void
timeout(struct ev_loop* loop,struct ev_timer* io,int revents) {
	struct lua_ev_timer* lev_timer = io->data;
	struct lua_ev* lev = lev_timer->lev;
	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev->callback);
	lua_pushinteger(lev->main, LUA_EV_TIMEOUT);
	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lev_timer->ref);
	lua_pcall(lev->main, 2, 0, 0);
}

static void
udp_recv(struct ev_loop* loop,struct ev_io* io,int revents) {
	struct lua_udp_session* udp_session = io->data;
	struct lua_ev* lev = udp_session->lev;

	for(;;) {
		struct sockaddr_in si;
		socklen_t slen = sizeof(si);
		int n = recvfrom(udp_session->fd, udp_session->recv_buffer, udp_session->recv_size, 0, (struct sockaddr*)&si, &slen);
		if (n<0) {
			switch(errno) {
				case EINTR:
					continue;
				case EAGAIN:
					return;
				default: {
					break;
				}
			}

			lua_rawgeti(lev->main, LUA_REGISTRYINDEX, udp_session->callback);
			lua_rawgeti(lev->main, LUA_REGISTRYINDEX, udp_session->ref);
			lua_pushboolean(lev->main,0);
			lua_pushstring(lev->main,strerror(errno));
			lua_pcall(lev->main, 3, 0, 0);

			udp_destroy(udp_session);
			return;
		}
		lua_rawgeti(lev->main, LUA_REGISTRYINDEX, udp_session->callback);
		lua_rawgeti(lev->main, LUA_REGISTRYINDEX, udp_session->ref);
		
		lua_pushlstring(lev->main,udp_session->recv_buffer,n);

        char tmp[INET6_ADDRSTRLEN];
        if (inet_ntop(si.sin_family, (void*)&si.sin_addr, tmp, sizeof(tmp))) {
        	lua_pushstring(lev->main,tmp);
        } else {
        	lua_pushstring(lev->main,"unknow");
        }
        lua_pushinteger(lev->main,ntohs(si.sin_port));
		
		lua_pcall(lev->main, 4, 0, 0);
	}
}

void
pipe_recv(struct ev_loop* loop,ev_io* io,int revents) {
	struct lua_pipe* lpipe = io->data;
	struct lua_ev* lev = lpipe->lev;

	for (;;) {
		struct pipe_message* message = NULL;
		int n = read(io->fd, &message, sizeof(message));
		if (n < 0) {
			if (errno == EINTR)
				continue;
			else if (errno == EAGAIN) {
				return;
			} else {
				assert(0);
			}
		}

		assert(n == sizeof(message));

		lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lpipe->callback);
		lua_rawgeti(lev->main, LUA_REGISTRYINDEX, lpipe->ref);
		lua_pushinteger(lev->main, message->source);
		lua_pushinteger(lev->main, message->session);
		lua_pushlightuserdata(lev->main, message->data);
		lua_pushinteger(lev->main, message->size);
		lua_pcall(lev->main, 5, 0, 0);

		free(message);
	}
}

//-------------------------tcp session api---------------------------

static inline struct lua_ev_session* 
get_session(lua_State* L, int index) {
	struct lua_ev_session* lev_session = (struct lua_ev_session*)lua_touserdata(L, 1);
	if (lev_session->closed) {
		luaL_error(L,"session already closed");
	}
	return lev_session;
}

static int
_session_write(lua_State* L) {
	struct lua_ev_session* lev_session = get_session(L, 1);
	
	int noheader = 0;
	size_t size = 0;
	char* data = NULL;
	
	int vt = lua_type(L,2);
	switch(vt) {
		case LUA_TSTRING: {
			data = (char*)lua_tolstring(L, 2, &size);
			noheader = luaL_optinteger(L, 3, 0);
			break;
		}
		case LUA_TLIGHTUSERDATA:{
			data = lua_touserdata(L, 2);
			size = luaL_checkinteger(L, 3);
			noheader = luaL_optinteger(L, 4, 0);
			break;
		}
		default:
			luaL_error(L,"session write error:unknow lua type:%s",lua_typename(L,vt));
	}

	if (size == 0) {
		luaL_error(L,"session write error:size is zero");
	}

	char* block = NULL;
	if (lev_session->header != 0 && noheader == 0) {
		
	    if (lev_session->header == HEADER_TYPE_WORD) {
	    	ushort length = size + lev_session->header;
	   	 	block = malloc(length);
	   	 	memcpy(block, &length, sizeof(ushort));
	   	 	memcpy(block + sizeof(ushort), data, size);
	   	 	size = length;
	    } else {
	    	uint32_t length = size + lev_session->header;
	   	 	block = malloc(length);
	   	 	memcpy(block, &length, sizeof(uint32_t));
	   	 	memcpy(block + sizeof(uint32_t), data, size);
	   	 	size = length;
	    }

	    if (vt == LUA_TLIGHTUSERDATA) {
	    	free(data);
	    }
	} else {
		if (vt == LUA_TSTRING) {
			block = malloc(size);
			memcpy(block, data, size);
		} else {
			block = data;
		}
	}

	if (ev_session_write(lev_session->session, block, size) == -1) {
		free(block);
		lua_pushboolean(L,0);
		return 1;
	}
	size_t total = ev_session_output_size(lev_session->session);
	if (total >= lev_session->threhold) {
		size_t howmuch = total / MB;
		lev_session->threhold += MB;
		fprintf(stderr,"channel:%p more than %ldmb data need to send out\n",lev_session,howmuch);
	} else {
		size_t threhold = lev_session->threhold;
		if ( threhold > MB && total < threhold / 2) {
			lev_session->threhold -= MB;
		}	
	}
	lua_pushboolean(L,1);
	
	return 1;
}

static int
_session_read(lua_State* L) {
	struct lua_ev_session* lev_session = get_session(L, 1);
	size_t size = luaL_optinteger(L,2,0);

	size_t total = ev_session_input_size(lev_session->session);
	if (total == 0) {
		return 0;
	}

	if (size == 0 || size > total) {
		size = total;
	}

	char* data = THREAD_CACHED_BUFFER;
	if (size > THREAD_CACHED_SIZE) {
		data = malloc(size);
	}
			
	ev_session_read(lev_session->session,data,size);

	lua_pushlstring(L, data, size);
	
	if (data != THREAD_CACHED_BUFFER) {
		free(data);
	}

	return 1;
}

static int
_session_read_util(lua_State* L) {
	struct lua_ev_session* lev_session = get_session(L, 1);
	size_t size;
	const char* sep = lua_tolstring(L,2,&size);

	size_t length;
	char* data = ev_session_read_util(lev_session->session,sep,size,THREAD_CACHED_BUFFER,THREAD_CACHED_SIZE,&length);
	if (!data) {
		return 0;
	}
	
	lua_pushlstring(L, data, length);

	if (data != THREAD_CACHED_BUFFER) {
		free(data);
	}
	return 1;
}

static int
_session_alive(lua_State* L) {
	struct lua_ev_session* lev_session = (struct lua_ev_session*)lua_touserdata(L, 1);
	lua_pushboolean(L,lev_session->closed == 0);
	return 1;
}

static int
_session_close(lua_State* L) {
	struct lua_ev_session* lev_session = get_session(L, 1);
	
	luaL_checktype(L, 2, LUA_TBOOLEAN);
	int immediately = lua_toboolean(L, 2);

	lev_session->closed = 1;

	if (!immediately) {
		ev_session_setcb(lev_session->session, NULL, close_complete, error_occur, lev_session);
		ev_session_disable(lev_session->session,EV_READ);
		ev_session_enable(lev_session->session, EV_WRITE);
	} else {
		if (lev_session->execute) {
			lev_session->markdead = 1;
		} else {
			session_destroy(lev_session);
		}
	}

	return 0;
}

//-------------------------endof tcp session api---------------------------

//-------------------------tcp listener api---------------------------
static int
_listen_alive(lua_State* L) {
	struct lua_ev_listener* lev_listener = (struct lua_ev_listener*)lua_touserdata(L, 1);
	lua_pushboolean(L,lev_listener->closed == 0);
	return 1;
}

static int
_listen_addr(lua_State* L) {
	struct lua_ev_listener* lev_listener = (struct lua_ev_listener*)lua_touserdata(L, 1);
	if (!lev_listener->listener) {
		return 0;
	}
	char addr[INET6_ADDRSTRLEN] = {0};
	int port = 0;
	if (ev_listener_addr(lev_listener->listener,addr,INET6_ADDRSTRLEN,&port) < 0) {
		return 0;
	}

	lua_newtable(L);
	if (port == 0) {
		lua_pushstring(L, addr);
		lua_setfield(L, -2, "file");
	} else {
		lua_pushstring(L, addr);
		lua_setfield(L, -2, "ip");
		lua_pushinteger(L, port);
		lua_setfield(L, -2, "port");
	}
	return 1;
}

static int
_listen_close(lua_State* L) {
	struct lua_ev_listener* lev_listener = (struct lua_ev_listener*)lua_touserdata(L, 1);
	if (lev_listener->closed)
		luaL_error(L, "listener alreay closed");

	lev_listener->closed = 1;
	luaL_unref(L, LUA_REGISTRYINDEX, lev_listener->ref);
	ev_listener_free(lev_listener->listener);
	return 0;
}
//-------------------------endof tcp listener api---------------------------

//-------------------------timer api---------------------------
static int
_timer_cancel(lua_State* L) {
	struct lua_ev_timer* lev_timer = (struct lua_ev_timer*)lua_touserdata(L, 1);
	if (ev_is_active(&lev_timer->io) == 0) {
		luaL_error(L, "timer already cancel");
	}
	struct lua_ev* lev = lev_timer->lev;
	ev_timer_stop(loop_ctx_get(lev->loop_ctx),(struct ev_timer*)&lev_timer->io);
	lev_timer->next = lev->freelist;
	lev->freelist = lev_timer;
	return 0;
}

static int
_timer_alive(lua_State* L) {
	struct lua_ev_timer* lev_timer = (struct lua_ev_timer*)lua_touserdata(L, 1);
	lua_pushboolean(L,ev_is_active(&lev_timer->io));
	return 1;
}
//-------------------------endof timer api---------------------------

//-------------------------udp api---------------------------
static int
_udp_send(lua_State* L) {
	struct lua_udp_session* udp_session = (struct lua_udp_session*)lua_touserdata(L, 1);
	if (udp_session->closed == 1)
		luaL_error(L,"udp session:%d already closed",udp_session->fd);

	size_t length;
	const char* ip = luaL_checklstring(L,2,&length);
	int port = luaL_checkinteger(L,3);

	struct sockaddr_in si;
	si.sin_family = AF_INET;
	si.sin_addr.s_addr = inet_addr(ip);
	si.sin_port = htons(port);

	size_t size;
	char* data = NULL;
	int needfree = 0;

	switch(lua_type(L,4)) {
		case LUA_TSTRING: {
			data = (char*)lua_tolstring(L,4,&size);
			break;
		}
		case LUA_TUSERDATA:{
			data = (char*)lua_touserdata(L,4);
			size = lua_tointeger(L,5);
			needfree = 1;
			break;
		}
		default:
			luaL_error(L,"session write error:unknow lua type:%s",lua_typename(L,lua_type(L,2)));
	}

	if (size == 0)
		luaL_error(L,"udp session send error size");

	int total = socket_udp_write(udp_session->fd,data,size,(struct sockaddr *)&si,sizeof(si));

	if (needfree)
		free(data);

	if (total < 0) {
		udp_destroy(udp_session);
		lua_pushboolean(L,0);
		lua_pushstring(L,strerror(errno));
		return 2;
	}
	assert(total == size);
	lua_pushboolean(L,1);
	return 1;
}

static int
_udp_alive(lua_State* L) {
	struct lua_udp_session* udp_session = (struct lua_udp_session*)lua_touserdata(L, 1);
	lua_pushinteger(L,udp_session->closed);
	return 1;
}

static int
_udp_close(lua_State* L) {
	struct lua_udp_session* udp_session = (struct lua_udp_session*)lua_touserdata(L, 1);
	if (udp_session->closed == 1)
		luaL_error(L,"udp session:%d already closed",udp_session->fd);
	udp_destroy(udp_session);
	return 0;
}
//-------------------------endof udp api---------------------------

//-------------------------pipe api---------------------------
static int
_lpipe_alive(lua_State* L) {
	struct lua_pipe* lpipe = (struct lua_pipe*)lua_touserdata(L, 1);
	lua_pushinteger(L, lpipe->closed == 1);
	return 1;
}

static int
_lpipe_release(lua_State* L) {
	struct lua_pipe* lpipe = (struct lua_pipe*)lua_touserdata(L, 1);
	if (lpipe->closed)
		luaL_error(L,"mail box already closed");

	ev_io_stop(loop_ctx_get(lpipe->lev->loop_ctx), &lpipe->io);
	close(lpipe->recv_fd);
	close(lpipe->send_fd);

	luaL_unref(L, LUA_REGISTRYINDEX, lpipe->ref);
	luaL_unref(L, LUA_REGISTRYINDEX, lpipe->callback);

	lpipe->closed = 1;
	return 1;
}
//-------------------------endof pipe api---------------------------

//-------------------------event api---------------------------

union un_sockaddr {
	struct sockaddr_un su;
	struct sockaddr_in si;
};

struct sockaddr*
get_addr(lua_State* L, int index, union un_sockaddr* sa, int* addrlen, int remove) {
	luaL_checktype(L, index, LUA_TTABLE);
	lua_getfield(L, index, "file");

	struct sockaddr* addr;

	if (!lua_isnil(L, -1)) {
		const char* file = luaL_checkstring(L, -1);
		lua_pop(L, 1);

		if (remove) {
			unlink(file);
		}

		sa->su.sun_family = AF_UNIX;  
		strcpy(sa->su.sun_path, file);

		addr = (struct sockaddr*)&sa->su;
		*addrlen = sizeof(sa->su);
	} else {
		lua_pop(L, 1);
		lua_getfield(L, index, "ip");
		const char* ip = luaL_checkstring(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, index, "port");
		int port = luaL_checkinteger(L, -1);
		lua_pop(L, 1);

		sa->si.sin_family = AF_INET;
		sa->si.sin_addr.s_addr = inet_addr(ip);
		sa->si.sin_port = htons(port);

		addr = (struct sockaddr*)&sa->si;
		*addrlen = sizeof(sa->si);
	}
	return addr;
}

static int
_listen(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	
	int header = lua_tointeger(L, 2);
	if (header != 0) {
		if (header != HEADER_TYPE_WORD && header != HEADER_TYPE_DWORD) {
			luaL_error(L,"create listener error:error header size:%d",header);
		}
	}
	
	int multi = lua_toboolean(L, 3);

	union un_sockaddr sa;
	int addrlen = 0;
	struct sockaddr* addr = get_addr(L, 4, &sa, &addrlen, 1);
	
	struct lua_ev_listener* lev_listener = lua_newuserdata(L, sizeof(*lev_listener));
	lev_listener->lev = lev;
	lev_listener->closed = 0;
	lev_listener->header = header;

	int flag = SOCKET_OPT_NOBLOCK | SOCKET_OPT_CLOSE_ON_EXEC | SOCKET_OPT_REUSEABLE_ADDR;
	if (multi)
		flag |= SOCKET_OPT_REUSEABLE_PORT;

	lev_listener->listener = ev_listener_bind(lev->loop_ctx,addr,addrlen,16,flag,accept_socket,lev_listener);
	if (!lev_listener->listener) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, strdup(strerror(errno)));
		return 2;
	}

	lev_listener->ref = meta_init(L,META_LISTENER);

	return 1;
}

static int
_connect(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	int header = lua_tointeger(L, 2);
	if (header != 0) {
		if (header != HEADER_TYPE_WORD && header != HEADER_TYPE_DWORD)
			luaL_error(L,"error header size:%d",header);
	}

	int wait = lua_tointeger(L, 3);
	union un_sockaddr sa;
	int addrlen = 0;
	struct sockaddr* addr = get_addr(L, 4, &sa, &addrlen, 0);

	int block = 1;
	if (wait > 0) {
		block = 0;
	}

	int status;
	struct lua_ev_session* lev_session = session_create(L,lev,-1,header);
	lev_session->lev = lev;
	lev_session->wait = wait;
	lev_session->session = ev_session_connect(lev->loop_ctx,addr,addrlen,block,&status);

	if (status == CONNECT_STATUS_CONNECT_FAIL) {
		lua_pushboolean(L,0);
		lua_pushstring(L,strerror(errno));
		return 2;
	}

	if (!block) {
		ev_session_setcb(lev_session->session,NULL,connect_complete,NULL,lev_session);
		ev_session_enable(lev_session->session,EV_WRITE);
		lua_pushboolean(L,1);
	} else {
		ev_session_setcb(lev_session->session, read_complete, NULL, error_occur, lev_session);
		ev_session_enable(lev_session->session, EV_READ);
	}
	
	return 1;
}

static int
_bind(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	int fd = lua_tointeger(L, 2);
	
	struct lua_ev_session* lev_session = session_create(L,lev,fd,0);
	ev_session_setcb(lev_session->session, read_complete, NULL, error_occur, lev_session);
	ev_session_enable(lev_session->session, EV_READ);
	return 1;
}

static int
_timer(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);

	double ti = lua_tonumber(L, 2);
	int once = lua_toboolean(L,3);
	double freq = 0;
	if (!once)
		freq = ti;

	struct lua_ev_timer* lev_timer = NULL;
	if (lev->freelist) {
		lev_timer = lev->freelist;
		lev->freelist = lev->freelist->next;
		lua_rawgeti(L, LUA_REGISTRYINDEX, lev_timer->ref);
	} else {
		lev_timer = lua_newuserdata(L, sizeof(*lev_timer));
		lev_timer->lev = lev;
		lev_timer->ref = meta_init(L,META_TIMER);
	}
	
	lev_timer->io.data = lev_timer;
	ev_timer_init((struct ev_timer*)&lev_timer->io,timeout,ti,freq);
	ev_timer_start(loop_ctx_get(lev->loop_ctx),(struct ev_timer*)&lev_timer->io);

	return 1;
}


static int
_udp_new(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	size_t recv_size = lua_tointeger(L,2);

	luaL_checktype(L,3,LUA_TFUNCTION);
	
	const char* ip = NULL;
	size_t size;
	int port = 0;
	if (!lua_isnil(L,4)) {
		ip = luaL_checklstring(L, 4, &size);
		port = luaL_checkinteger(L, 5);
	}

	int fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (fd < 0) {
		lua_pushboolean(L,0);
		lua_pushstring(L,strerror(errno));
		return 2;
	}

	if (ip) {
		struct sockaddr_in si;
		si.sin_family = AF_INET;
		si.sin_addr.s_addr = inet_addr(ip);
		si.sin_port = htons(port);

		int status = bind(fd, (struct sockaddr*)&si, sizeof(si));
		if (status != 0) {
			close(fd);
			lua_pushboolean(L,0);
			lua_pushstring(L,strerror(errno));
			return 2;
		}
	}

	lua_pushvalue(L,3);
	int callback = luaL_ref(L,LUA_REGISTRYINDEX);

	struct lua_udp_session* udp_session = lua_newuserdata(L, sizeof(struct lua_udp_session));
	memset(udp_session,0,sizeof(*udp_session));

	udp_session->fd = fd;
	udp_session->lev = lev;
	udp_session->closed = 0;
	udp_session->callback = callback;
	udp_session->recv_size = recv_size;
	udp_session->recv_buffer = malloc(udp_session->recv_size);
	udp_session->ref = meta_init(L,META_UDP);

	socket_nonblock(udp_session->fd);
	// socket_recv_buffer(udp_session->fd,1024 * 1024);

	ev_io_init(&udp_session->rio,udp_recv,udp_session->fd,EV_READ);
	udp_session->rio.data = udp_session;
	ev_io_start(loop_ctx_get(lev->loop_ctx),&udp_session->rio);

	return 1;
}

static int
_lpipe_new(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TFUNCTION);
	int callback = luaL_ref(L, LUA_REGISTRYINDEX);

	struct lua_pipe* lpipe = lua_newuserdata(L, sizeof(struct lua_pipe));
	memset(lpipe,0,sizeof(*lpipe));

	int fd[2];
	if (pipe(fd)) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, strerror(errno));
		return 2;
	}

	socket_nonblock(fd[0]);
	socket_nonblock(fd[1]);

	lpipe->lev = lev;
	lpipe->recv_fd = fd[0];
	lpipe->send_fd = fd[1];
	lpipe->callback = callback;
	lpipe->closed = 0;

	lpipe->io.data = lpipe;
	ev_io_init(&lpipe->io, pipe_recv, lpipe->recv_fd, EV_READ);
	ev_io_start(loop_ctx_get(lpipe->lev->loop_ctx), &lpipe->io);

	lpipe->ref = meta_init(L, META_PIPE);
	lua_pushinteger(L, lpipe->send_fd);

	return 2;
}

extern int lgate_create(lua_State* L,struct ev_loop_ctx* loop_ctx,uint32_t max_client,uint32_t max_freq);

static int
_lgate_new(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	uint32_t max_client = luaL_optinteger(L, 2, 1000);
	uint32_t max_freq = luaL_optinteger(L, 3, 1000);
	if (max_client <= 0 || max_client >= 10000) {
		luaL_error(L,"error create gate,size invalid:%d",max_client);
	}
	return lgate_create(L,lev->loop_ctx,max_client,max_freq);
}

void 
request_done(struct http_request* request, void* ud) {
	struct lua_httpc* userdata = ud;
	struct lua_ev* lev = userdata->lev;

	lua_rawgeti(lev->main, LUA_REGISTRYINDEX, userdata->callback);
	
	lua_pushinteger(lev->main, get_http_code(request));
	lua_pushstring(lev->main, get_http_error(request));

	size_t headers_size;
	const char* headers = get_http_headers(request, &headers_size);
	lua_pushlstring(lev->main, headers, headers_size);

	size_t content_size;
	const char* content = get_http_content(request, &content_size);
	lua_pushlstring(lev->main, content, content_size);

	lua_pcall(lev->main, 4, 0, 0);

	luaL_unref(lev->main, LUA_REGISTRYINDEX, userdata->ref);
}

static int
_lrequset_set_url(lua_State* L) {
	struct lua_httpc* httpc = (struct lua_httpc*)lua_touserdata(L, 1);
	const char* url = lua_tostring(L, 2);
	set_url(httpc->lrequest, url);
	return 0;
}

static int
_lrequset_set_header(lua_State* L) {
	struct lua_httpc* httpc = (struct lua_httpc*)lua_touserdata(L, 1);
	size_t size;
	const char* header = luaL_checklstring(L, 2, &size);
	set_header(httpc->lrequest, header, size);
	return 0;
}

static int
_lrequset_set_timeout(lua_State* L) {
	struct lua_httpc* httpc = (struct lua_httpc*)lua_touserdata(L, 1);
	int timeout = luaL_checkinteger(L, 2);
	set_timeout(httpc->lrequest, timeout);
	return 0;
}

static int
_lrequset_set_post_data(lua_State* L) {
	struct lua_httpc* httpc = (struct lua_httpc*)lua_touserdata(L, 1);
	size_t size;
	const char* content = luaL_checklstring(L, 2, &size);
	set_post_data(httpc->lrequest, content, size);
	return 0;
}

static int
_lrequset_set_unix_socket(lua_State* L) {
	struct lua_httpc* httpc = (struct lua_httpc*)lua_touserdata(L, 1);
	const char* socket_path = luaL_checkstring(L, 2);
	set_unix_socket_path(httpc->lrequest, socket_path);
	return 0;
}

static int
_lrequset_perform(lua_State* L) {
	struct lua_httpc* httpc = (struct lua_httpc*)lua_touserdata(L, 1);
	struct lua_ev* lev = httpc->lev;
	int status = http_request_perform(lev->multi, httpc->lrequest, request_done, httpc);
	lua_pushinteger(L, status);
	return 1;
}

static int
_lhttpc_request(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TFUNCTION);
	int callback = luaL_ref(L, LUA_REGISTRYINDEX);
	struct lua_httpc* httpc = lua_newuserdata(L, sizeof(*httpc));
	memset(httpc,0,sizeof(*httpc));

	httpc->lev = lev;
	httpc->lrequest = http_request_new();
	httpc->callback = callback;
	httpc->ref = meta_init(L, META_REQUEST);

	return 1;
}

static int
_dispatch(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	loop_ctx_dispatch(lev->loop_ctx);
	return 0;
}

static int
_release(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	http_multi_delete(lev->multi);
	loop_ctx_release(lev->loop_ctx);
	luaL_unref(L, LUA_REGISTRYINDEX, lev->ref);
	return 0;
}

static int
_break(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	loop_ctx_break(lev->loop_ctx);
	return 0;
}

static int
_clean(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	loop_ctx_clean(lev->loop_ctx);
	while(lev->freelist) {
		struct lua_ev_timer* timer = lev->freelist;
		lev->freelist = lev->freelist->next;
		luaL_unref(L, LUA_REGISTRYINDEX, timer->ref);
	}
	return 0;
}

static int
_now(lua_State* L) {
	struct lua_ev* lev = (struct lua_ev*)lua_touserdata(L, 1);
	double now = loop_ctx_now(lev->loop_ctx) * 1000;
	lua_pushinteger(L, now);
	return 1;
}
//-------------------------endof event api---------------------------

static int
_event_new(lua_State* L) {
	luaL_checktype(L,1,LUA_TFUNCTION);
	int callback = luaL_ref(L,LUA_REGISTRYINDEX);

	struct lua_ev* lev = lua_newuserdata(L, sizeof(*lev));
	lev->loop_ctx = loop_ctx_create();
	lev->multi = http_multi_new(lev->loop_ctx);
	lev->main = L;
	lev->callback = callback;
	lev->freelist = NULL;
	lev->ref = meta_init(L,META_EVENT);

	return 1;
}

int
luaopen_ev_core(lua_State* L) {
	luaL_checkversion(L);
	
	luaL_newmetatable(L, META_EVENT);
	const luaL_Reg meta_event[] = {
		{ "listen", _listen },
		{ "connect", _connect },
		{ "bind", _bind },
		{ "timer", _timer },
		{ "udp", _udp_new },
		{ "pipe", _lpipe_new },
		{ "gate", _lgate_new },
		{ "httpc_request", _lhttpc_request },
		{ "breakout", _break },
		{ "dispatch", _dispatch },
		{ "clean", _clean },
		{ "now", _now },
		{ "release", _release },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta_event);
	lua_setfield(L, -2, "__index");
	lua_pop(L,1);

	luaL_newmetatable(L, META_SESSION);
	const luaL_Reg meta_session[] = {
		{ "write", _session_write },
		{ "read", _session_read },
		{ "read_util", _session_read_util },
		{ "alive", _session_alive },
		{ "close", _session_close },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta_session);
	lua_setfield(L, -2, "__index");
	lua_pop(L,1);

	luaL_newmetatable(L, META_LISTENER);
	const luaL_Reg meta_listener[] = {
		{ "alive", _listen_alive },
		{ "addr", _listen_addr },
		{ "close", _listen_close },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta_listener);
	lua_setfield(L, -2, "__index");
	lua_pop(L,1);

	luaL_newmetatable(L, META_TIMER);
	const luaL_Reg meta_timer[] = {
		{ "cancel", _timer_cancel },
		{ "alive", _timer_alive },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta_timer);
	lua_setfield(L, -2, "__index");
	lua_pop(L,1);

	luaL_newmetatable(L, META_UDP);
	const luaL_Reg meta_udp[] = {
		{ "send", _udp_send },
		{ "alive", _udp_alive },
		{ "close", _udp_close },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta_udp);
	lua_setfield(L, -2, "__index");
	lua_pop(L,1);

	luaL_newmetatable(L, META_PIPE);
	const luaL_Reg meta_pipe[] = {
		{ "alive", _lpipe_alive },
		{ "release", _lpipe_release },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta_pipe);
	lua_setfield(L, -2, "__index");
	lua_pop(L,1);

	luaL_newmetatable(L, META_REQUEST);
	const luaL_Reg meta_request[] = {
		{ "set_url", _lrequset_set_url },
		{ "set_header", _lrequset_set_header },
		{ "set_post_data", _lrequset_set_post_data },
		{ "set_unix_socket", _lrequset_set_unix_socket },
		{ "set_timeout", _lrequset_set_timeout },
		{ "perfrom", _lrequset_perform },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta_request);
	lua_setfield(L, -2, "__index");
	lua_pop(L,1);

	const luaL_Reg l[] = {
		{ "new", _event_new },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
