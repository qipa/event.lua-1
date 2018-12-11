#ifndef SOCKET_HTTP_H
#define SOCKET_HTTP_H

#include "socket_event.h"

struct http_request;
struct http_multi;
typedef void(*request_callback)( struct http_request* request, void* ud );

struct http_multi* http_multi_new(struct ev_loop_ctx* ev_loop);
struct http_request* http_request_new();
void http_request_delete(struct http_request* request);

int set_url(struct http_request* request, const char* url);

const char* get_headers(struct http_request* request);
const char* get_content(struct http_request* request);

int http_multi_perform(struct http_multi* multi, struct http_request* request);



#endif