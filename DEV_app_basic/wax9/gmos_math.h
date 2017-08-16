/**
\file hal/gmos_math.h

\brief Header for GMOS mathematical functions library

Copyright 2009 Grey Innovation Pty Ltd

*/

#ifndef _GMOS_MATH_H
#define _GMOS_MATH_H

#include <stdint.h>
//#include "gmos_config.h"

#ifdef GMOS_MATH_DEBUG
    #include <gmos_assert.h>
    #define GMOS_MATH_DEBUG_ASSERT(condition) assert(condition)
#else
    #define GMOS_MATH_DEBUG_ASSERT(condition)
#endif

#if defined(ARM32)

    // Yagarto does not provide a header for its maths library, and uses non-standard names!
    #define gmos_math_cos(x) cosf(x)
    float cosf(float);
    #define gmos_math_sin(x) sinf(x)
    float sinf(float);
    #define gmos_math_tan(x) tanf(x)
    float tanf(float);
    #define gmos_math_acos(x) acosf(x)
    float acosf(float);
    #define gmos_math_asin(x) asinf(x)
    float asinf(float);
    #define gmos_math_atan(x) atanf(x)
    float atanf(float);
    #define gmos_math_atan2(y,x) atan2f(y,x)
    float atan2f(float, float);
    #define gmos_math_cosh(x) coshf(x)
    float coshf(float);
    #define gmos_math_sinh(x) sinhf(x)
    float sinhf(float);
    #define gmos_math_exp(x) expf(x)
    float expf(float);
    #define gmos_math_ldexp(x,y) ldexpf(x,y)
    float ldexpf(float, int);
    #define gmos_math_log(x) logf(x)
    float logf(float);
    #define gmos_math_log10(x) log10f(x)
    float log10f(float);
    #define gmos_math_pow(x,y) powf(x,y)
    float powf(float, float);
    #define gmos_math_sqrt(x) sqrtf(x)
    float sqrtf(float);
    #define gmos_math_fmod(x,y) fmodf(x,y)
    float fmodf(float, float);
    #define gmos_math_isnan(x) (uint8_t)isnanf(x)
    int isnanf(float);
    #define gmos_math_isinf(x) (uint8_t)isinff(x)
    int isinff(float);
    #define gmos_math_ceil(x) (int32_t)ceilf(x)
    float ceilf(float);
    #define gmos_math_floor(x) (int32_t)floorf(x)
    float floorf(float);

    #define GMOS_MATH_EMULATE_ABS
    #define GMOS_MATH_STANDARD_MUL_U8_U8_U8
    #define GMOS_MATH_STANDARD_MUL_U8_U8_U16
    #define GMOS_MATH_STANDARD_MUL_U16_U16_HU16_APPROX
    #define GMOS_MATH_STANDARD_MUL_U16_U16_U32
    #define GMOS_MATH_STANDARD_MUL_U32_U16_U32
    #define GMOS_MATH_STANDARD_MUL_S16_U16_S32

#elif defined(GMOS_ON_PC)

    #define _NO_OLDNAMES // stops y0 getting defined (mingw)
    #undef __USE_MISC // stops y0 getting define (gcc4)
    #include <math.h>
    #define __USE_MISC
    #undef _NO_OLDNAMES

    #include <float.h>
    #include <stdlib.h>

    #define gmos_math_cos(x) cos((float)(x))
    #define gmos_math_sin(x) sin((float)(x))
    #define gmos_math_tan(x) tan((float)(x))
    #define gmos_math_acos(x) acos((float)(x))
    #define gmos_math_asin(x) asin((float)(x))
    #define gmos_math_atan(x) atan((float)(x))
    #define gmos_math_atan2(y,x) atan2((float)(y),(float)(x))
    #define gmos_math_cosh(x) cosh((float)(x))
    #define gmos_math_sinh(x) sinh((float)(x))
    #define gmos_math_exp(x) exp((float)(x))
    #define gmos_math_ldexp(x,y) ldexp((float)(x),(float)(y))
    #define gmos_math_log(x) log((float)(x))
    #define gmos_math_log10(x) log10((float)(x))
    #define gmos_math_pow(x,y) pow((float)(x),(float)(y))
    #define gmos_math_sqrt(x) sqrt((float)(x))
    #define gmos_math_fmod(x,y) fmod((float)(x),(float)(y))
    #define gmos_math_isnan(x) (uint8_t)_isnan(x)
    #define gmos_math_isinf(x) (uint8_t)!_finite(x)
    #define gmos_math_ceil(x) (int32_t)ceil((float)x)
    #define gmos_math_floor(x) (int32_t)floor((float)x)

    #define GMOS_MATH_BUILTIN_ABS
    #define GMOS_MATH_STANDARD_MUL_U8_U8_U8
    #define GMOS_MATH_STANDARD_MUL_U8_U8_U16
    #define GMOS_MATH_STANDARD_MUL_U16_U16_HU16_APPROX
    #define GMOS_MATH_STANDARD_MUL_U16_U16_U32
    #define GMOS_MATH_STANDARD_MUL_U32_U16_U32
    #define GMOS_MATH_STANDARD_MUL_S16_U16_S32

#elif defined(__AVR_ATmega88P__) || defined(__AVR_ATmega168P__) || defined(__AVR_ATmega328P__)

    #define GMOS_MATH_EMULATE_ABS
    #include "atmegan8p/gmos_math.h"
    #define GMOS_MATH_STANDARD_MUL_U16_U16_HU16_APPROX
    #define GMOS_MATH_STANDARD_MUL_U16_U16_U32
    #define GMOS_MATH_STANDARD_MUL_U32_U16_U32
    #define GMOS_MATH_STANDARD_MUL_S16_U16_S32

#else

    #include <math.h>
    #define gmos_math_cos(x) cos((float)(x))
    #define gmos_math_sin(x) sin((float)(x))
    #define gmos_math_tan(x) tan((float)(x))
    #define gmos_math_acos(x) acos((float)(x))
    #define gmos_math_asin(x) asin((float)(x))
    #define gmos_math_atan(x) atan((float)(x))
    #define gmos_math_atan2(y,x) atan2((float)(y),(float)(x))
    #define gmos_math_cosh(x) cosh((float)(x))
    #define gmos_math_sinh(x) sinh((float)(x))
    #define gmos_math_exp(x) exp((float)(x))
    #define gmos_math_ldexp(x,y) ldexp((float)(x),(float)(y))
    #define gmos_math_log(x) log((float)(x))
    #define gmos_math_log10(x) log10((float)(x))
    #define gmos_math_pow(x,y)) pow((float)(x),(float)(y))
    #define gmos_math_sqrt(x) sqrt((float)(x))
    #define gmos_math_fmod(x,y) fmod((float)(x),(float)(y))
    #define gmos_math_isnan(x) (uint8_t)isnan((float)(x))
    #define gmos_math_isinf(x) (uint8_t)isinf((float)(x))
    #define gmos_math_ceil(x) (int32_t)ceil((float)x)
    #define gmos_math_floor(x) (int32_t)floor((float)x)

    #define GMOS_MATH_BUILTIN_ABS
    #define GMOS_MATH_STANDARD_MUL_U8_U8_U16
    #define GMOS_MATH_STANDARD_MUL_U16_U16_HU16_APPROX
    #define GMOS_MATH_STANDARD_MUL_U16_U16_U32
    #define GMOS_MATH_STANDARD_MUL_U32_U16_U32
    #define GMOS_MATH_STANDARD_MUL_S16_U16_S32

#endif


#ifdef M_PI
    #define GMOS_MATH_PI M_PI
#else
    #define GMOS_MATH_PI 3.14159265358979323846f
#endif

#ifdef M_PI_2
    #define GMOS_MATH_HALF_PI M_PI_2
#elif defined(HALF_PI)
    #define GMOS_MATH_HALF_PI HALF_PI
#else
    #define GMOS_MATH_HALF_PI 1.57079632679489661923f
#endif

#ifdef M_TWO_PI
    #define GMOS_MATH_TWO_PI M_TWO_PI
#else
    #define GMOS_MATH_TWO_PI 6.28318530717958647692f
#endif

#ifdef M_1_PI
    #define GMOS_MATH_1_ON_PI M_1_PI
#else
    #define GMOS_MATH_1_ON_PI 0.318309886183790671538f
#endif

#ifdef M_E
    #define GMOS_MATH_E M_E
#else
    #define GMOS_MATH_E 2.71828182845904523536f
#endif


#ifdef GMOS_MATH_BUILTIN_ABS
    #define gmos_math_abs(val)  fabs(val) // double fabs(double v), float fabsf(float v)
#elif defined(GMOS_MATH_EMULATE_ABS)
    #define gmos_math_abs(val)  ({ typeof(val) _val = val; (_val < 0) ? -_val : _val; })
#endif


#ifdef GMOS_MATH_STANDARD_MUL_U8_U8_U8
    /* Returns (x * y) */
    static inline uint8_t gmos_math_mul_u8_u8_u8(uint8_t x, uint8_t y)
    {
        return (uint8_t)x * (uint8_t)y;
    }
#endif

#ifdef GMOS_MATH_STANDARD_MUL_U8_U8_U16
    /* Returns (x * y) */
    static inline uint16_t gmos_math_mul_u8_u8_u16(uint8_t x, uint8_t y)
    {
        return (uint16_t)x * (uint16_t)y;
    }
    #define gmos_math_mul_u8_cu8_u16 gmos_math_mul_u8_u8_u16
#endif

#ifdef GMOS_MATH_STANDARD_MUL_U16_U16_U32
    /* Returns (x * y) */
    static inline uint32_t gmos_math_mul_u16_u16_u32(uint16_t x, uint16_t y)
    {
        return (uint32_t)x *(uint32_t)y;
    }
#elif defined(GMOS_MATH_EMULATE_MUL_U16_U16_U32)
    /* Returns (x * y) */
    uint32_t gmos_math_mul_u16_u16_u32(uint16_t x, uint16_t y);
#endif

/* Returns (x * y) */
static inline uint32_t gmos_math_mul_u16_u16_hu16(uint16_t x, uint16_t y)
{
    return (uint16_t)(gmos_math_mul_u16_u16_u32(x, y) >> 16);
}

#ifdef GMOS_MATH_STANDARD_MUL_U16_U16_HU16_APPROX
    /* Returns high 16 bits of (x * y) */
    #define gmos_math_mul_u16_u16_hu16_approx gmos_math_mul_u16_u16_hu16
    #define gmos_math_mul_u16_cu16_hu16_approx gmos_math_mul_u16_u16_hu16
#elif defined(GMOS_MATH_EMULATE_MUL_U16_U16_HU16_APPROX)
    /* Returns approximation of high 16 bits of (x * y) */
    static inline uint16_t gmos_math_mul_u16_u16_hu16_approx(uint16_t x, uint16_t y)
    {
        //a * c + ((a * d + b * c) >> 8) (ignore +(b*d)>>16)
        uint16_t result;
        uint8_t  a = (uint8_t)(x >> 8);
        uint8_t  b = (uint8_t)x;
        uint8_t  c = (uint8_t)(y >> 8);
        uint8_t  d = (uint8_t)y;
        result  = gmos_math_mul_u8_u8_u16(a, d);
        result += gmos_math_mul_u8_u8_u16(b, c);
        result >>= 8;
        result += gmos_math_mul_u8_u8_u16(a, c);
        return result;
    }
#endif

#ifdef GMOS_MATH_STANDARD_MUL_U32_U16_U32
    /* Returns (x * y) */
    static inline uint32_t gmos_math_mul_u32_u16_u32(uint32_t x, uint16_t y)
    {
        return (x * (uint32_t)y);
    }
#elif defined(GMOS_MATH_EMULATE_MUL_U32_U16_U32)
    /* Returns (x * y) */
    uint32_t gmos_math_mul_u32_u16_u32(uint32_t x, uint16_t y);
#endif

#ifdef GMOS_MATH_STANDARD_MUL_S16_U16_S32
    /* Returns (x * y) */
    static inline int32_t gmos_math_mul_s16_u16_s32(int16_t x, uint16_t y)
    {
        return (int32_t)x * (int32_t)y;
    }
#elif defined(GMOS_MATH_EMULATE_MUL_S16_U16_S32)
    /* Returns (x * y) */
    static inline int32_t gmos_math_mul_s16_u16_s32(int16_t x, uint16_t y)
    {
        // Note: could be further optimised by hand
        uint8_t negative = (uint8_t)(x < 0);
        uint16_t abs_x = negative ? -x : x;
        int32_t result = (int32_t)gmos_math_mul_u16_u16_u32(abs_x, y);
        result = negative ? -result : result;
        //GMOS_MATH_DEBUG_ASSERT(result == (int32_t)((int32_t)x*(uint32_t)y));
        return result;
    }
#endif


// The following are #defines to allow use in constant declarations (as well as in functions)

#define gmos_math_sign(source) \
( ((source) > 0.0f) ? +1 : ((source) < 0.0f) ? -1 : 0 )

#define gmos_math_to_degrees(radians) \
( (radians) * (180.0f * GMOS_MATH_1_ON_PI) )

#define gmos_math_to_radians(degrees) \
( (degrees) * (GMOS_MATH_PI / 180.0f) )


#ifdef GMOS_MATH_DEBUG
    static inline void gmos_math_unit_test(void)
    {
        uint32_t u_result;
        int32_t s_result;
        u_result = (uint32_t)gmos_math_mul_u8_u8_u16(20, 30);
        u_result = (uint32_t)gmos_math_mul_u8_u8_u16(1, 4);
        u_result = (uint32_t)gmos_math_mul_u8_cu8_u16(100, 150);
        assert(u_result == 100*150);
        u_result = (uint32_t)gmos_math_mul_u8_cu8_u16(100, 1);
        assert(u_result == 100);
        u_result = (uint32_t)gmos_math_mul_u8_cu8_u16(100, 0);
        assert(u_result == 0);
        u_result = gmos_math_mul_u16_u16_u32(2000, 3000);
        assert(u_result == 2000UL*3000UL);
        s_result = gmos_math_mul_s16_u16_s32(-2000, 3000);
        assert(s_result == -2000L*3000L);
        u_result = gmos_math_mul_u16_u16_u32((uint16_t)16000UL, (uint16_t)16000UL);
        assert(u_result == 16000UL*16000UL);
        u_result = gmos_math_mul_u32_u16_u32((uint32_t)600000UL, (uint16_t)16000UL);
        assert(u_result == 600000UL*16000UL);
    }
#endif

#endif

/* End of file. */
