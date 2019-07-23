/* Functions for working with timespec structures
 * Written by Daniel Collins (2017)
 * timespec_mod by Alex Forencich (2019)
 * 
 * This is free and unencumbered software released into the public domain.
 *
 * Anyone is free to copy, modify, publish, use, compile, sell, or
 * distribute this software, either in source code form or as a compiled
 * binary, for any purpose, commercial or non-commercial, and by any
 * means.
 *
 * In jurisdictions that recognize copyright laws, the author or authors
 * of this software dedicate any and all copyright interest in the
 * software to the public domain. We make this dedication for the benefit
 * of the public at large and to the detriment of our heirs and
 * successors. We intend this dedication to be an overt act of
 * relinquishment in perpetuity of all present and future rights to this
 * software under copyright law.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * For more information, please refer to <http://unlicense.org/>
*/

#ifndef DAN_TIMESPEC_H
#define DAN_TIMESPEC_H

#include <stdbool.h>
#include <sys/time.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

struct timespec timespec_add(struct timespec ts1, struct timespec ts2);
struct timespec timespec_sub(struct timespec ts1, struct timespec ts2);
struct timespec timespec_mod(struct timespec ts1, struct timespec ts2);

bool timespec_eq(struct timespec ts1, struct timespec ts2);
bool timespec_gt(struct timespec ts1, struct timespec ts2);
bool timespec_ge(struct timespec ts1, struct timespec ts2);
bool timespec_lt(struct timespec ts1, struct timespec ts2);
bool timespec_le(struct timespec ts1, struct timespec ts2);

struct timespec timespec_from_double(double s);
double timespec_to_double(struct timespec ts);
struct timespec timespec_from_timeval(struct timeval tv);
struct timeval timespec_to_timeval(struct timespec ts);
struct timespec timespec_from_ms(long milliseconds);
long timespec_to_ms(struct timespec ts);

struct timespec timespec_normalise(struct timespec ts);

#ifdef __cplusplus
}
#endif

#endif /* !DAN_TIMESPEC_H */
