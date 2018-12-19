#ifndef THREAD_POOL_H
#define THREAD_POOL_H



struct thread_pool;
struct task;

typedef void (*task_consumer)(struct task*,void*);

typedef void (*thread_init)(struct thread_pool* pool, int index, void* ud);
typedef void (*thread_fina)(struct thread_pool* pool, int index, void* ud);

struct thread_pool* thread_pool_create(thread_init init_func, thread_fina fina_func, void* ud);
void thread_pool_start(struct thread_pool* pool, int thread_count);
void thread_pool_push_task(struct thread_pool* pool, task_consumer consumer, void* ud);


#endif