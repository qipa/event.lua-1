#include "dns_resolver.h"

#include "ares.h"
#include "khash.h"

typedef struct dns_task {
	int fd;
	ev_io rio;
	ev_io wio;
} dns_task_t;

KHASH_MAP_INIT_INT(task, dns_task_t*);

typedef khash_t(task) task_hash_t;

typedef struct dns_resolver {
	ares_channel channel;
	struct ares_options opts;
	task_hash_t* hash;
	int count;
	struct ev_timer io;
	struct ev_loop_ctx* ev_loop;
} dns_resolver_t;

typedef struct query_param {
	dns_resolve_result cb;
	void* ud;
} query_param_t;

void
dns_init() {
	ares_library_init(ARES_LIB_INIT_ALL);
}

void
dns_fina() {
	ares_library_cleanup();
}

void
task_hash_set(task_hash_t* hash, int fd, dns_task_t* task) {
	int ok;
	khiter_t k = kh_put(task, hash, fd, &ok);
	assert(ok == 1 || ok == 2);
	kh_value(hash, k) = task;
}

dns_task_t*
task_hash_get(task_hash_t* hash, int fd) {
	khiter_t k = kh_get(task, hash, fd);
	if ( k == kh_end(hash) ) {
		return NULL;
	}
	return kh_value(hash, k);
}

void
task_hash_del(task_hash_t* hash, int fd) {
	khiter_t k = kh_get(task, hash, fd);
	kh_del(task, hash, k);
}

static void
timer_cb(struct ev_loop* loop,struct ev_timer* io,int revents) {
	dns_resolver_t* resolver = io->data;
	ares_process_fd(resolver->channel, ARES_SOCKET_BAD, ARES_SOCKET_BAD);
}

static void
dns_poll_cb(struct ev_loop* loop,struct ev_io* io,int revents) {
	dns_resolver_t* resolver = io->data;

	int w = ARES_SOCKET_BAD, r = ARES_SOCKET_BAD;
	if (revents & EV_READ) r = io->fd;
	if (revents & EV_WRITE) w = io->fd;

	ares_process_fd(resolver->channel, r, w);
}

static void
dns_sock_state_cb(void* ud, ares_socket_t sock, int readable, int writable) {
	dns_resolver_t* resolver = ud;
	dns_task_t* task = task_hash_get(resolver->hash, sock);
	if (readable || writable) {
		if (!task) {
			if (!ev_is_active((struct ev_timer*)&resolver->io)) {
				ev_timer_start(loop_ctx_get(resolver->ev_loop),(struct ev_timer*)&resolver->io);
			}

			task = malloc(sizeof(*task));
			memset(task, 0, sizeof(*task));
			task->fd = sock;

			task->rio.data = resolver;
			ev_io_init(&task->rio,dns_poll_cb,sock,EV_READ);

			task->wio.data = resolver;
			ev_io_init(&task->wio,dns_poll_cb,sock,EV_WRITE);

			resolver->count++;

			task_hash_set(resolver->hash, sock, task);
		}

		if (readable) {
			ev_io_start(loop_ctx_get(resolver->ev_loop), &task->rio);
		}

		if (writable) {
			ev_io_start(loop_ctx_get(resolver->ev_loop), &task->wio);
		}
	} else {
		task_hash_del(resolver->hash, sock);
		
		if (ev_is_active(&task->rio)) {
			ev_io_stop(loop_ctx_get(resolver->ev_loop), &task->rio);
		}
		if (ev_is_active(&task->wio)) {
			ev_io_stop(loop_ctx_get(resolver->ev_loop), &task->wio);
		}

		free(task);

		resolver->count--;

		if (ev_is_active((struct ev_timer*)&resolver->io)) {
			ev_timer_stop(loop_ctx_get(resolver->ev_loop),(struct ev_timer*)&resolver->io);
		} 
	}
}



dns_resolver_t*
dns_resolver_new(struct ev_loop_ctx* ev_loop) {
	dns_resolver_t* resolver = malloc(sizeof(*resolver));

	resolver->opts.timeout = 3000;
	resolver->opts.tries = 1;
	resolver->opts.sock_state_cb_data  = resolver;
	resolver->opts.sock_state_cb = dns_sock_state_cb;

	if (ares_init_options(&resolver->channel, &resolver->opts, ARES_OPT_TIMEOUTMS | ARES_OPT_TRIES | ARES_OPT_TRIES |ARES_OPT_SOCK_STATE_CB) != ARES_SUCCESS) {
		free(resolver);
		return NULL;
	}

	resolver->hash = kh_init(task);

	resolver->ev_loop = ev_loop;
	resolver->io.data = resolver;
	ev_timer_init((struct ev_timer*)&resolver->io,timer_cb,0.1,0.1);

	return resolver;
}

void
dns_resolver_delete(dns_resolver_t* resolver) {
	ares_destroy(resolver->channel);
}
 
static void
query_callback(void* ud, int status, int timeouts, struct hostent *host) {
	query_param_t* param = ud;
	if (status != ARES_SUCCESS) {
		param->cb(status, NULL, param->ud);
	}
	else {
		param->cb(status, host, param->ud);
		// char ip[INET6_ADDRSTRLEN];
		// int i;
		// for(i = 0; host->h_addr_list[i];++i) {
		// 	inet_ntop(host->h_addrtype, host->h_addr_list[i], ip, sizeof(ip));
		// }
	}
	free(param);
}

void
dns_query(dns_resolver_t* resolver, const char* name, dns_resolve_result cb, void* ud) {
	query_param_t* param = malloc(sizeof(*param));
	param->cb = cb;
	param->ud = ud;
	ares_gethostbyname(resolver->channel, name, AF_INET, query_callback, param);
}

const char*
dns_last_error(int status) {
	return ares_strerror(status);
}