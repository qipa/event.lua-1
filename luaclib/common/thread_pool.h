#ifndef THREAD_POOL_H
#define THREAD_POOL_H

#include <pthread.h>

struct thread_pool;
struct task;

typedef void (*task_consumer)(int index, int session, void* data, size_t size);

typedef void (*thread_init)(struct thread_pool* pool, int index, pthread_t pid, void* ud);
typedef void (*thread_fina)(struct thread_pool* pool, int index, pthread_t pid, void* ud);

struct thread_pool* thread_pool_create(thread_init init_func, thread_fina fina_func, void* ud);
void thread_pool_start(struct thread_pool* pool, int thread_count);
void thread_pool_push_task(struct thread_pool* pool, task_consumer consumer, void* ud);


#endif