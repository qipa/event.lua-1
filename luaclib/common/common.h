#ifndef COMMON_H
#define COMMON_H
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

typedef struct vector2 {
	float x;
	float z;
} vector2_t;



uint16_t checksum(uint16_t* addr,size_t size);
int message_decrypt(uint16_t* rseed,uint8_t* message,size_t size);
uint8_t* message_encrypt(uint16_t* wseed,uint16_t id,const uint8_t* message,size_t size);

float sqrt_dot2dot(vector2_t* a, vector2_t* b);
float dot2dot(vector2_t* a, vector2_t* b);
float dot2segment(vector2_t* x0, vector2_t* x1, vector2_t* x);

void rotation(vector2_t* dot, vector2_t* center,float angle);
void move_torward(vector2_t* result, vector2_t* from, vector2_t* dir, float dt);
void move_forward(vector2_t* result, vector2_t* from, vector2_t* to, float pass);

int capsule_intersect(vector2_t* src, vector2_t* u, float cr, vector2_t* center, float r);
int rectangle_intersect(vector2_t* src, float length, float width, float angle, vector2_t* center, float r);
int sector_intersect(vector2_t* src, float angle, float degree, float l, vector2_t* center, float r);
#endif