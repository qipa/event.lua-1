#ifndef SOCKET_PIPE_H
#define SOCKET_PIPE_H
#include "socket_tcp.h"

struct pipe_message {
	struct pipe_message* next;
	int source;
	int session;
	void* data;
	size_t size;
};

struct pipe_session;

typedef void (*pipe_session_callback)(struct pipe_session*,struct pipe_message* message,void *userdata);


struct pipe_session* pipe_sesson_new(struct ev_loop_ctx* loop_ctx);
void pipe_session_destroy(struct pipe_session* session);
int pipe_write_fd(struct pipe_session* session);
void pipe_session_setcb(struct pipe_session* session, pipe_session_callback read_cb, void* userdata);

#endif