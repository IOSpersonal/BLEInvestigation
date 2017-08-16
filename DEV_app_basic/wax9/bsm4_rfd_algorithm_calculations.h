/**
\file rfd_algorithm_calculations.h

\brief Header for PRO RFD positional algorithm

Copyright 2009 Grey Innovation Pty Ltd

*/

#ifndef _RFD_ALGORITHM_CALCULATIONS_H
#define _RFD_ALGORITHM_CALCULATIONS_H

#include "gmos_vector.h"
#include "bsm4_rfd_positional_algorithm.h"

typedef enum {
	RFD_ALGO_GYRO_NOT_GREEN = 0,
	RFD_ALGO_GYRO_GREEN_STANDING,
	RFD_ALGO_GYRO_GREEN_LATERAL,
} rfd_algo_gyro_green_t;

// what to do about forwards 90 - choose one of:
//#define FORWARD_90_ZERO_LATERAL
//#define FORWARD_90_X_ONLY_LATERAL
//#define FORWARD_90_KEEP_LATERAL
#define FORWARD_90_PROGRESSIVE_FILTER
#define LATERAL_PROGRESSIVE_REDUCE
#define LATERAL_PROGRESSIVE_USE_NOTUNTWISTED

#define FORWARD_90_KEEP_ARTIFICIAL_TWIST

//#define FORWARD_ANGLE_USING_DIP_Y
//#define LATERAL_ANGLE_USING_DIP_X

#define TWIST_DIFFERENTIAL_LIMIT

float wrap_at_pi(float angle);

float rfd_algorithm_calculate_differential_angle(
			float top_angle,
			float bottom_angle);

float rfd_algorithm_calculate_forward_flexion(
			gmos_vector3* normalised_unlateral_accelerations) __attribute__((nonnull));

float rfd_algorithm_calculate_lateral_flexion(
            gmos_vector3* normalised_accel_for_calc,
			gmos_vector3* normalised_accel_for_thresholds,
            float default_lateral,
            rfd_mdm_position_t mdm_pos_idx) __attribute__((nonnull));

float rfd_algorithm_calculate_forwardByOnlyY(
            gmos_vector3* accelerations) __attribute__((nonnull));

float rfd_algorithm_calculate_lateralByOnlyX(
            gmos_vector3* accelerations) __attribute__((nonnull));

float rfd_algorithm_calculate_dipX(
            gmos_vector3* accelerations) __attribute__((nonnull));

float rfd_algorithm_calculate_dipY(
            gmos_vector3* accelerations) __attribute__((nonnull));

float rfd_algorithm_calculate_dipZ(
            gmos_vector3* accelerations) __attribute__((nonnull));

float rfd_algorithm_calculate_top_twist(
           float bottom_delta_twist, float top_twist,
           float bottom_dipz, float top_dipz);

uint8_t rfd_algorithm_is_standing_green(
                          float top_forward_cal,
                          float top_lateral_cal,
                          float bottom_forward_cal,
                          float bottom_lateral_cal) __attribute__((nonnull));

uint8_t rfd_algorithm_is_lateralonly_green(
                          float top_lateral_byx_cal,
                          float bottom_lateral_byx_cal,
                          float top_y) __attribute__((nonnull));

void rfd_algorithm_apply_progressive_x_filter(
                          rfd_mdm_position_t mdm_pos_idx, 
                          gmos_vector3* accel) __attribute__((nonnull));

float rfd_algorithm_apply_progressive_lateral_nountwist(
                          rfd_mdm_position_t mdm_pos_idx, 
                          gmos_vector3* filtered_normalised_accel, 
                          float lateral) __attribute__((nonnull));

float rfd_algorithm_apply_progressive_lateral_filter(
                          rfd_mdm_position_t mdm_pos_idx, 
                          gmos_vector3* filtered_normalised_accel, 
                          float lateral) __attribute__((nonnull));

float rfd_algorithm_apply_progressive_lateral_limit(
                          rfd_mdm_position_t mdm_pos_idx, 
                          gmos_vector3* filtered_normalised_accel, 
                          float lateral);

//void rfd_algorithm_calculate_accel_minus_calibration(
//	       gmos_vector3* measured_accel,
//	 	   float calibration_forward,
//		   float calibration_lateral,
//		   gmos_vector3* accel_minus_calibration) __attribute__((nonnull));

void rfd_algorithm_calculate_unlateral_accelerations(
          gmos_vector3* untwisted,
          float lateral,
          gmos_vector3* unlateral) __attribute__((nonnull));

void rfd_algorithm_calculate_untwisted_accelerations(
		   gmos_vector3* measured,
	       float twist,
		   gmos_vector3* untwisted) __attribute__((nonnull));

float rfd_algorithm_limit_differential_twist(float diff_twist);

float rfd_algorithm_calculate_gyro_return_to_zero(float previous_diff_twist);

float rfd_algorithm_calculate_artificial_twist_delta(
           uint8_t calibrated_lookup,
           float current_forward_2d, float current_lateral_2d,
           float recent_forward_2d, float recent_lateral_2d,
           float recent_forward_3d, float recent_lateral_3d,
           float previous_forward_3d, float previous_lateral_3d,
           float forward_cal, float lateral_cal);

float rfd_algorithm_calculate_differential_twist_position(
           float previous_diff_twist,
           float top_twist_delta,
           float bottom_twist_delta,
           gmos_vector3* average_top_accelerations,
           gmos_vector3* average_bottom_accelerations) __attribute__((nonnull));

void rfd_algorithm_calculations_init();

#endif

/* End of file */
