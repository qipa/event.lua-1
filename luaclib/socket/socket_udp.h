#ifndef UDP_SESSION_H
#define UDP_SESSION_H

struct udp_session;
typedef void (*udp_session_read_callback)(struct udp_session*,char* buffer, size_t size, const char* ip, ushort port,void *userdata);
typedef void (*udp_session_event_callback)(struct udp_session*,void *userdata);

#endif