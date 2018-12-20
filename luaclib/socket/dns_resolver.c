










typedef struct dns_channel {
	dns_resolver_t* resolver;
	ares_channel channel;
	ares_options opts;
} dns_channel_t;

typedef struct dns_task {
	int fd;
	ev_io rio;
	ev_io wio;
} dns_task_t;

KHASH_MAP_INIT_INT(task, dns_task_t*);

typedef khash_t(task) task_hash_t;

typedef struct dns_resolver {
	task_hash_t* hash;
	int count;
	struct ev_timer io;
	struct ev_loop_ctx* ev_loop;
} dns_resolver_t;


void
dns_init() {

}

void
dns_fina() {

}

void
task_hash_set(task_hash_t* hash, int fd, task_hash_t* task) {
	int ok;
	khiter_t k = kh_put(task, hash, fd, &ok);
	assert(ok == 1 || ok == 2);
	kh_value(hash, k) = task;
}

task_hash_t*
task_hash_get(task_hash_t* hash, int fd) {
	khiter_t k = kh_get(task, hash, fd);
	if ( k == kh_end(hash) ) {
		return NULL;
	}
	return kh_value(hash, k);
}

void
task_hash_del(task_hash_t* hash, int fd) {
	kh_del(hash, hash, fd);
}

static void
timer_cb(struct ev_loop* loop,struct ev_timer* io,int revents) {
	resolver_t* resolver = io->data;
	ares_process_fd(resolver->_ares_channel, ARES_SOCKET_BAD, ARES_SOCKET_BAD);
}

static void
dns_poll_cb(struct ev_loop* loop,struct ev_io* io,int revents) {
	dns_task_t* task = io->data;

	int w = ARES_SOCKET_BAD, r = ARES_SOCKET_BAD;
	if (revents & EV_READ) r = io->fd;
	if (revents & EV_WRITE) w = io->fd;

	ares_process_fd(ctx->channel, r, w);
}

static void
dns_sock_state_cb(void* ud, ares_socket_t sock, int readable, int writable) {
	resolver_t* resolver = ud;
	task_hash_t* task = task_hash_get(sock);
	if (readable || writable) {
		if (!task) {
			if (!ev_is_active((struct ev_timer*)&resolver->io)) {
				ev_timer_start(loop_ctx_get(resolver->ev_loop),(struct ev_timer*)&resolver->io);
			}

			task = malloc(sizeof(*task));
			memset(task, 0, sizeof(*task));
			task->fd = sock;

			task->rio.data = task;
			ev_io_init(&task->rio,dns_poll_cb,sock,EV_READ);

			task->wio.data = task;
			ev_io_init(&task->wio,dns_poll_cb,sock,EV_WRITE);

			resolver->count++;
		}


		if (readable) {
			ev_io_start(loop_ctx_get(resolver->ev_loop), &task->rio);
		}

		if (writable) {
			ev_io_start(loop_ctx_get(resolver->ev_loop), &task->Wio);
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



resolver_t*
dns_resolver_new(struct ev_loop_ctx* ev_loop) {
	resolver_t* resolver = malloc(sizeof(*resolver));
	resolver->ev_loop = ev_loop;

	resolver->io.data = resolver;
	ev_timer_init((struct ev_timer*)&resolver->io,timer_cb,0.1,0.1);
}

void
set_timeout(resolver_t* resolver, int timeout) {

}


void 
static void
query_callback(void* ud, int status, int timeouts, struct hostent *hosten) {

}

int
dns_query(resolver_t* resolver, const char* name) {
	ares_gethostbyname(resolver->channel, name, AF_INET, query_callback, resolver);
}