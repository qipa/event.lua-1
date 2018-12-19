
#include "common/thread_pool.h"


typedef thread_ctx {
	pthread_t pid;
	int index;
	lua_State* L;
} thread_ctx_t;

typedef lthread_pool {
	struct thread_pool* core;

	const char* boot;

	sem_t sem;

	thread_ctx_t* thr_mgr;
} lthread_pool_t;

void 
tp_init(struct thread_pool* pool, int index, pthread_t pid, void* ud) {
	lthread_pool_t* ltp = ud;
	sem_post(&ltp->sem);

	thread_ctx_t* ctx = &ltp->thr_mgr[index];
	ctx->pid = pid;
	ctx->index = index;
}

void 
tp_fina(struct thread_pool* pool, int index, pthread_t pid, void* ud) {

}


static int
lcreate(lua_State* L) {
	int fd = lua_tointeger(L, 1);
	const char* boot = lua_tostring(L, 2);
	int count = lua_tointeger(L, 3);

	lthread_pool_t* ltp = malloc(sizeof(*ltp));
	ltp->core = thread_pool_create(tp_init, tp_fina, ltp);
	ltp->boot = strdup(boot);
	ltp->thr_mgr = malloc(count * sizeof(thread_ctx_t));
	pthread_mutex_init(&ltp->mutex, NULL);

	sem_init(&ltp->sem, 0, -count);

	thread_pool_start(ltp->core, count);

	sem_wait(&ltp->sem);
}