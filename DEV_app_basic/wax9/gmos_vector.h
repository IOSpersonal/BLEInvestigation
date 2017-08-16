/**
\file gmos_vector.h

\brief Header for GMOS floating-point 3-vector-manipulation module

Copyright 2009 Grey Innovation Pty Ltd

*/

#ifndef _GMOS_VECTOR_H
#define _GMOS_VECTOR_H

#include <stdint.h>
#include "gmos_string.h"

typedef enum {
    GMOS_VECTOR3_X = 0,
    GMOS_VECTOR3_Y,
    GMOS_VECTOR3_Z,
    GMOS_VECTOR3_NUM_AXES,
} gmos_vector3_axis_t;

typedef float gmos_vector3[GMOS_VECTOR3_NUM_AXES];
typedef float gmos_matrix3x3[GMOS_VECTOR3_NUM_AXES][GMOS_VECTOR3_NUM_AXES];

static const gmos_matrix3x3 GMOS_MATRIX3X3_EYE =
	{ {1.0f,0.0f,0.0f}, {0.0f,1.0f,0.0f}, {0.0f,0.0f,1.0f} };

#define gmos_vector3_basis_vector(axis) GMOS_MATRIX3X3_EYE[axis]

#define gmos_vector3_on_each_axis(counter, operation) \
{ uint8_t counter; for (counter = 0; counter < GMOS_VECTOR3_NUM_AXES; counter++) {operation} }

__attribute__((nonnull)) static inline
void gmos_vector3_copy(gmos_vector3* dest, gmos_vector3* src)
{ memcpy(dest, src, sizeof(gmos_vector3)); }

__attribute__((nonnull)) static inline
void gmos_vector3_add(gmos_vector3* dest, gmos_vector3* src1, gmos_vector3* src2)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] = (*src1)[axis] + (*src2)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_add_to(gmos_vector3* dest, gmos_vector3* add)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] += (*add)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_add_const(gmos_vector3* dest, float add)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] += add;} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_subtract(gmos_vector3* dest, gmos_vector3* src1, gmos_vector3* src2)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] = (*src1)[axis] - (*src2)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_subtract_from(gmos_vector3* dest, gmos_vector3* sub)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] -= (*sub)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_sub_const(gmos_vector3* dest, float sub)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] -= sub;} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_element_multiply(gmos_vector3* dest, gmos_vector3* src1, gmos_vector3* src2)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] = (*src1)[axis] * (*src2)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_element_multiply_by(gmos_vector3* dest, gmos_vector3* mul)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] *= (*mul)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_multiply_by_const(gmos_vector3* dest, float mul)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] *= mul;} ); }

void gmos_vector3_lhs_matrix_multiply(gmos_vector3* lhs, gmos_matrix3x3* rhs_matrix3x3, gmos_vector3* result) __attribute__((nonnull));

__attribute__((nonnull)) static inline
void gmos_vector3_element_divide(gmos_vector3* dest, gmos_vector3* src1, gmos_vector3* src2)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] = (*src1)[axis] / (*src2)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_element_divide_by(gmos_vector3* dest, gmos_vector3* den)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] /= (*den)[axis];} ); }

__attribute__((nonnull)) static inline
void gmos_vector3_divide_by_const(gmos_vector3* dest, float den)
{ gmos_vector3_on_each_axis(axis, {(*dest)[axis] /= den;} ); }

float gmos_vector3_magnitude(gmos_vector3* vector) __attribute__((nonnull));

void gmos_vector3_normalise(gmos_vector3* vector) __attribute__((nonnull));

__attribute__((nonnull)) static inline
float gmos_vector3_dot_product(gmos_vector3* lhs, gmos_vector3* rhs)
{ float res = 0.0f; gmos_vector3_on_each_axis(axis, {res += (*lhs)[axis] * (*rhs)[axis];} ); return res; }

#define gmos_matrix3x3_on_each_element(row_counter, col_counter, operation) \
{ \
	uint8_t row_counter, col_counter; \
	for (row_counter = 0; row_counter < GMOS_VECTOR3_NUM_AXES; row_counter++) \
		for (col_counter = 0; col_counter < GMOS_VECTOR3_NUM_AXES; col_counter++) \
			{operation} \
}

__attribute__((nonnull)) static inline
void gmos_matrix3x3_copy(gmos_matrix3x3* dest, gmos_matrix3x3* src)
{ memcpy(dest, src, sizeof(gmos_matrix3x3)); }

__attribute__((nonnull)) static inline
void gmos_matrix3x3_subtract(gmos_matrix3x3* lhs, gmos_matrix3x3* rhs, gmos_matrix3x3* result)
{ gmos_matrix3x3_on_each_element(row, col, (*result)[row][col] = (*lhs)[row][col] - (*rhs)[row][col];) }

void gmos_matrix3x3_matrix3x3_multiply(gmos_matrix3x3* lhs, gmos_matrix3x3* rhs, gmos_matrix3x3* result) __attribute__((nonnull));

void gmos_vector3_get_rotation_matrix_about_basis(gmos_vector3_axis_t around, float clockwiseRadians, gmos_matrix3x3* result) __attribute__((nonnull));
void gmos_vector3_get_rotation_matrix_about_axis(gmos_vector3* around, float clockwiseRadians, gmos_matrix3x3* result) __attribute__((nonnull));
  // FIXME: counter-clockwise makes more sense in a RH coordinate system.

void gmos_vector3_rotate_about_basis(gmos_vector3* vector, gmos_vector3_axis_t around, float clockwiseRadians, gmos_vector3* result) __attribute__((nonnull));
void gmos_vector3_rotate_about_axis(gmos_vector3* vector, gmos_vector3* around, float clockwiseRadians, gmos_vector3* result) __attribute__((nonnull));

#endif

/* End of file. */
