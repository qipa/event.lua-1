#ifndef GATE_H
#define GATE_H

#include "ev.h"
#include "socket/socket_event.h"
#include "socket/socket_util.h"
#include "common/object_container.h"
#include "common/common.h"

struct gate_ctx;

typedef void (*accept_callback)(void* ud,int id,const char* addr);
typedef void (*close_callback)(void* ud,int id);
typedef void (*data_callback)(void* ud,int client_id,int message_id,void* data,size_t size);

struct gate_ctx* gate_create(struct ev_loop_ctx* loop_ctx,uint32_t max_client,uint32_t max_freq,void* ud);
void gate_release(struct gate_ctx* gate);
int gate_start(struct gate_ctx* gate,const char* ip,int port);
int gate_stop(struct gate_ctx* gate);
int gate_close(struct gate_ctx* gate,int client_id,int grace);

void gate_callback(struct gate_ctx* gate,accept_callback accept,close_callback close,data_callback data);

int gate_send(struct gate_ctx* gate,int client_id,ushort message_id,void* data,size_t size);

#endif