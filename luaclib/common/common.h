#ifndef COMMON_H
#define COMMON_H
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

uint16_t checksum(uint16_t* addr,size_t size);
int message_decrypt(uint16_t* rseed,uint8_t* message,size_t size);
uint8_t* message_encrypt(uint16_t* wseed,uint16_t id,const uint8_t* message,size_t size);
#endif