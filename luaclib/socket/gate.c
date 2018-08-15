#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>
#include <math.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "lstate.h"

#include "socket/gate.h"

#define CACHED_SIZE 		1024 * 1024
#define MAX_FREQ 			500
#define ALIVE_TIME 			60
#define WARN_OUTPUT_FLOW 	10 * 1024
#define MAX_SEQMENT 		64 * 1024
#define HEADER 				2

__thread uint8_t CACHED_BUFFER[CACHED_SIZE];

struct gate_callback {
	accept_callback accept;
	close_callback close;
	data_callback data;
};

struct gate_ctx {
	struct ev_loop_ctx* loop_ctx;

	struct ev_listener* listener;

	struct object_container* container;
	uint32_t client_count;

	uint32_t max_freq;
	uint32_t max_client;
	uint32_t max_offset;
	uint32_t max_index;
	
	uint32_t index;

	struct gate_callback cb;
	void* ud;
};

struct ev_client {
	struct gate_ctx* gate;
	struct ev_session* session;
	struct ev_timer timer;
	uint32_t id;
	uint32_t countor;
	uint32_t need;
	int freq;
	int markdead;
	uint8_t seed;
	uint16_t order;
	double tick;
};

#define SLOT(id,max) (id - (id / max) * max)

static void 
close_client(int id,void* data) {
	struct ev_client* client = data;
	ev_session_free(client->session);
	ev_timer_stop(loop_ctx_get(client->gate->loop_ctx),(struct ev_timer*)&client->timer);
	uint32_t slot = SLOT(client->id,client->gate->max_offset);
	container_remove(client->gate->container,slot);
	client->gate->client_count--;
	free(client);
}

static inline void
grab_client(struct ev_client* client) {
	client->countor++;
}

static inline void
release_client(struct ev_client* client) {
	client->countor--;
	if (client->countor == 0) {
		close_client(0, client);
	}
}

static inline struct ev_client*
get_client(struct gate_ctx* gate,uint32_t id) {
	uint32_t slot = SLOT(id,gate->max_offset);
	struct ev_client* client = container_get(gate->container,slot);
	if (!client || client->id != id) {
		return NULL;
	}

	if (client->markdead == 1) {
		return NULL;
	}

	grab_client(client);
	return client;
}

static void
error_happen(struct ev_session* session,void* ud) {
	struct ev_client* client = ud;
	int id = client->id;
	struct gate_ctx* gate = client->gate;
	gate->cb.close(gate->ud,id);

	release_client(client);
}

static inline int 
read_header(struct ev_client* client) {
	size_t total = ev_session_input_size(client->session);
	if (total < HEADER) {
		return -1;
	}

	uint8_t header[HEADER];
	ev_session_read(client->session,(char*)header,HEADER);

	client->need = header[0] | header[1] << 8;
	client->need -= HEADER;

	if (client->need > MAX_SEQMENT) {
		error_happen(client->session, client);
		return -1;
	}
	return 0;
}

static inline int 
read_body(struct ev_client* client) {
	size_t total = ev_session_input_size(client->session);
	if (total < client->need) {
		return -1;
	}

	uint8_t* data = CACHED_BUFFER;
	if (client->need > CACHED_SIZE) {
		data = malloc(client->need);
	}
	ev_session_read(client->session,(char*)data,client->need);
	
	int i;
    for (i = 0; i < client->need; ++i) {
        data[i] = data[i] ^ client->seed;
        client->seed += data[i];
    }

    uint16_t sum = checksum((uint16_t*)data,client->need);
    uint16_t order = data[2] | data[3] << 8;
    uint16_t id = data[4] | data[5] << 8;

    if (sum != 0 || order != client->order) {
	    if (data != CACHED_BUFFER) {
	    	free(data);
	    }
	    error_happen(client->session, client);
		return -1;
    } else {
    	client->order++;
    }
    client->freq++;
    client->tick = loop_ctx_now(client->gate->loop_ctx);
    client->gate->cb.data(client->gate->ud,client->id,id,&data[6],client->need - 6);

    if (data != CACHED_BUFFER) {
    	free(data);
    }

    client->need = 0;

    return 0;
}

static void
read_complete(struct ev_session* ev_session, void* ud) {
	struct ev_client* client = ud;

	grab_client(client);

	for(;;) {
		if (client->need == 0) {
			if (read_header(client) < 0) {
				break;
			}
		} else {
			if (read_body(client) < 0) {
				break;
			}
		}
	}

	release_client(client);
}	

static void
timeout(struct ev_loop* loop,struct ev_timer* io,int revents) {
	assert(revents & EV_TIMER);
	struct ev_client* client = io->data;
	grab_client(client);

	if (ev_session_output_size(client->session) > WARN_OUTPUT_FLOW) {
		fprintf(stderr,"client:%d more then %dkb flow need to send out\n",client->id,WARN_OUTPUT_FLOW/1024);
	}

	if (client->freq > client->gate->max_freq) {
		fprintf(stderr,"client:%d more then %d message receive in recent 1s\n",client->id,client->freq);
		error_happen(NULL, client);
	} else {
		client->freq = 0;
		if (client->tick != 0 && loop_ctx_now(client->gate->loop_ctx) - client->tick > ALIVE_TIME) {
			error_happen(NULL, client);
		}
	}
	release_client(client);
}

static void 
accept_client(struct ev_listener *listener, int fd, const char* addr, void *ud) {
	struct gate_ctx* gate = ud;

	socket_nonblock(fd);
	socket_keep_alive(fd);
	socket_closeonexec(fd);

	if (gate->client_count >= gate->max_client) {
		close(fd);
		return;
	}

	gate->client_count++;

	struct ev_client* client = malloc(sizeof(*client));
	memset(client,0,sizeof(*client));

	struct ev_session* session = ev_session_bind(gate->loop_ctx,fd);
	int slot = container_add(gate->container,client);
	
	uint32_t index = gate->index++;
	if (index >= gate->max_index) {
		gate->index = 1;
	}
	
	client->gate = gate;
	client->session = session;
	client->id = index * gate->max_offset + slot;

	grab_client(client);

	ev_session_setcb(client->session,read_complete,NULL,error_happen,client);
	ev_session_enable(client->session,EV_READ);

	client->timer.data = client;
	ev_timer_init(&client->timer,timeout,1,1);
	ev_timer_start(loop_ctx_get(gate->loop_ctx),&client->timer);

	gate->cb.accept(gate->ud,client->id,addr);
}

static void
close_complete(struct ev_session* ev_session, void* ud) {
	struct ev_client* client = ud;
	release_client(client);
}

static void
close_error(struct ev_session* session, void* ud) {
	struct ev_client* client = ud;
	fprintf(stderr,"client:%d close error\n",client->id);
	release_client(client);
}

struct gate_ctx*
gate_create(struct ev_loop_ctx* loop_ctx,uint32_t max_client, uint32_t max_freq,void* ud) {
	struct gate_ctx* gate = malloc(sizeof(*gate));
	memset(gate,0,sizeof(*gate));
	gate->container = container_create(max_client);
	gate->loop_ctx = loop_ctx;
	gate->ud = ud;
	gate->max_freq = max_freq;
	gate->max_client = max_client;
	gate->max_offset = 0;
	gate->client_count = 0;
	gate->index = 1;

	int offset = 0;
	for (; max_client > 0; offset++) {
        max_client /= 10;
	}
    gate->max_offset = pow(10,offset);
	gate->max_index = 0xffffffff / gate->max_offset;
	return gate;
}

int
gate_start(struct gate_ctx* gate,const char* ip,int port) {
	struct sockaddr_in si;
	si.sin_family = AF_INET;
	si.sin_addr.s_addr = inet_addr(ip);
	si.sin_port = htons(port);

	int flag = SOCKET_OPT_NOBLOCK | SOCKET_OPT_CLOSE_ON_EXEC | SOCKET_OPT_REUSEABLE_ADDR;
	gate->listener = ev_listener_bind(gate->loop_ctx,(struct sockaddr*)&si,sizeof(si),16,flag,accept_client,gate);
	if (!gate->listener) {
		return -1;
	}
	if (port == 0) {
		char addr[INET6_ADDRSTRLEN] = {0};
		if (ev_listener_addr(gate->listener,addr,INET6_ADDRSTRLEN,&port) < 0) {
			return port;
		}
	}
	return port;
} 

void
gate_callback(struct gate_ctx* gate,accept_callback accept,close_callback close,data_callback data) {
	gate->cb.accept = accept;
	gate->cb.close = close;
	gate->cb.data = data;
}

int
gate_stop(struct gate_ctx* gate) {
	if (gate->listener == NULL) {
		return -1;
	}

	ev_listener_free(gate->listener);
	gate->listener = NULL;
	return 0;
}

int
gate_close(struct gate_ctx* gate,uint32_t client_id,int grace) {
	struct ev_client* client = get_client(gate,client_id);
	if (!client) {
		return -1;
	}
	if (!grace) {
		release_client(client);
	}
	else {
		client->markdead = 1;
		ev_session_setcb(client->session, NULL, close_complete, close_error, client);
		ev_session_enable(client->session, EV_WRITE);
		ev_session_disable(client->session, EV_READ);
	}
	release_client(client);
	return 0;
}

int
gate_send(struct gate_ctx* gate,uint32_t client_id,ushort message_id,void* data,size_t size) {
	struct ev_client* client = get_client(gate,client_id);
	if (!client) {
		return -1;
	}

	ushort total = size + sizeof(short) * 2;

    uint8_t* mb = malloc(total);
    memcpy(mb, &total, sizeof(ushort));
    memcpy(mb + sizeof(ushort), &message_id, sizeof(ushort));
    memcpy(mb + sizeof(ushort) * 2, data, size);

    int ret = ev_session_write(client->session,(char*)mb,total);
    release_client(client);
	if (ret < 0) {
		free(mb);
		return -1;
	}
	return 0;
}

void
gate_release(struct gate_ctx* gate) {
	gate_stop(gate);
	container_foreach(gate->container,close_client);
	container_release(gate->container);
	free(gate);
}
