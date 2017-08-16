/**
\file gmos_string.h

\brief GMOS string manipulation interface.

Copyright 2008 Grey Innovation Pty Ltd. All rights reserved.

*/

#ifndef _GMOS_STRING_H
#define _GMOS_STRING_H

#include <stddef.h>

#ifdef GMOS_ON_PC
#include <string.h>
#include <stdlib.h>
#else
void* memcpy(void* t, const void* s, size_t n);
void* memmove(void* t, const void* s, size_t n);
void* memset(void* t, int c, size_t n);
char* strcpy(char* t, const char* s);
char* strncpy(char* t, const char* s, size_t n);
char* strcat(char* t, const char* s);
char* strncat(char* t, const char* s, size_t n);
int memcmp(const void* s1, const void* s2, size_t n);
int strcmp(const char* s1, const char* s2);
int strncmp(const char* s1, const char* s2, size_t n);
int strnicmp(const char* s1, const char* s2, size_t n);
//const char* strchr(const char* s, int c);
//const char* strrchr(const char* s, int c);
size_t strlen(const char* s);
size_t strnlen(const char * s, size_t max_len);
//const void * memchr(void const *s, int c, size_t n);

const char* strnstrn(const char* haystack, size_t hn,
                     const char* needle, size_t nn);
int toupper(int);
int atoi(const char* s);

unsigned long strtoul(const char* str, char ** endptr, int base);
long strtol(const char* str, char ** endptr, int base);

#endif

#endif

/* End of file */
