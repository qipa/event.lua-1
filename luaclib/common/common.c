#include "common.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <math.h>

#define PI  (3.141592653589793238462643383279502884)

#define rad(angle) (angle/PI)

static const vector2_t VECTOR2_ZERO = {0,0};

uint16_t 
checksum(uint16_t* addr,size_t size) {
    uint32_t sum = 0;
    while(size > 1) {
    	sum += *addr++;
    	size-=2;
    }
    if (size > 0) {
    	sum += *(uint8_t*)addr;
    }
    while(sum >> 16) {
    	sum = (sum & 0xffff) + (sum >> 16);
    }
    return (int16_t)~sum;
}

uint8_t*
message_encrypt(uint16_t* wseed,uint16_t id,const uint8_t* message,size_t size) {
    uint16_t total = sizeof(uint16_t) * 3 + size;
    uint8_t* data = malloc(total);

    memcpy(data, (uint8_t*)&total, sizeof(uint16_t));
    uint8_t* reserve = data + sizeof(uint16_t);
    memcpy(data + sizeof(uint16_t) * 2, (uint8_t*)&id, sizeof(uint16_t));
    memcpy(data + sizeof(uint16_t) * 3, message, size);

    uint16_t* addr = (uint16_t*)(data + sizeof(uint16_t) * 2);
    size_t length = total - sizeof(uint16_t) * 2;

    uint32_t sum = 0;
    while(length > 1) {
        uint16_t tmp = *addr;

        sum += tmp;

        *addr = tmp ^ (*wseed);
        *wseed += tmp;

        addr++;

        length -= 2;
    }
    if (length > 0) {
        uint8_t tmp = *(uint8_t*)addr;
        sum += tmp;
        *(uint8_t*)addr = tmp ^ (*wseed);
        *wseed += tmp;
    }
    while(sum >> 16) {
        sum = (sum & 0xffff) + (sum >> 16);
    }
    *(uint16_t*)reserve = (uint16_t)~sum;

    return data;
}

int
message_decrypt(uint16_t* rseed,uint8_t* message,size_t size) {
    if (size < sizeof(uint16_t) * 2) {
        return -1;
    }

    uint16_t* data = (uint16_t*)message;

    uint32_t sum = data[0];
    uint16_t* addr = &data[1];
    size_t length = size - sizeof(uint16_t);
    while(length > 1) {
        uint16_t tmp = *addr;

        *addr = tmp ^ (*rseed);
        *rseed += *addr;

        sum += *addr;
        
        addr++;

        length -= 2;
    }
    if (length > 0) {
        uint8_t* data = (uint8_t*)addr;
        uint8_t tmp = *data;
        
        *data = tmp ^ (*rseed);
        *rseed += *data;

        sum += *data;
    }

    while(sum >> 16) {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    if ((uint16_t)~sum != 0) {
        return -1;
    }
    return 0;
}


static inline void
vector2_sub(vector2_t* result, vector2_t* a, vector2_t* b) {
    result->x = a->x - b->x;
    result->z = a->z - b->z;
}

static inline float
vector2_dot(vector2_t* a, vector2_t* b) {
    return a->x * b->x + a->z * b->z;
}

static inline void
vector2_max(vector2_t* result, vector2_t* a, vector2_t* b) {
    float x,z;
    if (a->x < b->x) {
        x = b->x;
    } else {
        x = a->x;
    }
    if (a->z < b->z) {
        z = b->z;
    } else {
        z = a->z;
    }
    result->x = x;
    result->z = z;
}

static inline float
sqrt_vector2_magnitude(vector2_t* u) {
    return u->x * u->x + u->z * u->z;
}

static inline float
vector2_magnitude(vector2_t* u) {
    return sqrt(sqrt_vector2_magnitude(u));
}

static inline float
sqrt_dot2dot(vector2_t* a, vector2_t* b) {
    return (a->x - b->x) * (a->x - b->x) + (a->z - b->z) * (a->z - b->z);
}

static inline float
dot2dot(vector2_t* a, vector2_t* b) {
    return sqrt(sqrt_dot2dot(a, b));
}

static inline void
rotation(vector2_t* dot, vector2_t* center,float angle) {
    float r = rad(angle);
    float si = sin(r);
    float co = cos(r);

    float x = dot->x;
    float z = dot->z;
    dot->x = (x - center->x) * co - (z - center->z) * si + center->x;
    dot->z = (x - center->x) * si - (z - center->z) * co + center->z;
}

static inline float
sqrt_dot2segment(vector2_t* x0, vector2_t* u, vector2_t* x) {
    vector2_t vt;

    vector2_sub(&vt, x, x0);

    float t = vector2_dot(&vt, u) / sqrt_vector2_magnitude(u);
    if (t < 0) {
        t = 0;
    } else if (t > 1) {
        t = 1;
    }

    vector2_t dot;
    dot.x = x0->x + t * u->x;
    dot.z = x0->z + t * u->z;

    return sqrt_dot2dot(x, &dot);
}

int
capsule_intersect(vector2_t* src, vector2_t* u, float cr, vector2_t* center, float r) {
    return sqrt_dot2segment(src, u, center) <= (cr + r) * (cr + r);
}

int
rectangle_intersect(vector2_t* src, float length, float width, float angle, vector2_t* center, float r) {
    float rd = rad(angle);

    vector2_t rt_center;
    rt_center.x = src->x + (cos(rd) * (length / 2));
    rt_center.z = src->z + (sin(rd) * (length / 2));

    vector2_t delta_center;
    delta_center.x = center->x - rt_center.x;
    delta_center.z = center->z - rt_center.z;

    rotation(&delta_center, (vector2_t*)&VECTOR2_ZERO, angle);

    vector2_t h;
    h.x = length / 2;
    h.z = width / 2;

    vector2_t v;
    v.x = delta_center.x >= 0 ? delta_center.x : -delta_center.x;
    v.z = delta_center.z >= 0 ? delta_center.z : -delta_center.z;

    vector2_t u;
    u.x = v.x - h.x < 0 ? 0 : v.x - h.x;
    u.z = v.z - h.z < 0 ? 0 : v.z - h.z;

    return sqrt_vector2_magnitude(&u) <= r * r;
}