/**
\file rfd_positional_algorithm.h

\brief Header for PRO RFD positional algorithm

Copyright 2009 Grey Innovation Pty Ltd

*/

#ifndef _RFD_POSITIONAL_ALGORITHM_H
#define _RFD_POSITIONAL_ALGORITHM_H

#define NUM_MDMS 2

typedef enum {
    RFD_MDM_TOP = 0,
    RFD_MDM_BOTTOM,
    RFD_MDM_DIFFERENTIAL,
    RFD_MDM_POSITION_NUM,
} rfd_mdm_position_t;

typedef enum {
    RFD_MDE_LEFT = 0,
    RFD_MDE_RIGHT,
    RFD_MDE_POSITION_NUM,
} rfd_mde_position_t;

typedef enum {
    RFD_BODY_ANGLE_FORWARD = 0,
    RFD_BODY_ANGLE_LATERAL,
    RFD_BODY_ANGLE_TWIST,
    RFD_BODY_ANGLE_ARTIFICIAL_TWIST,
    RFD_BODY_ANGLE_NUM,
} rfd_body_angle_t;
#define RFD_BODY_ANGLE_CSV_NUM 3

typedef enum {
    RFD_RAW_ACCEL_X = 0,
    RFD_RAW_ACCEL_Y,
    RFD_RAW_ACCEL_Z,
    RFD_RAW_GYRO,
    RFD_RAW_MOVEMENT_NUM,
} rfd_raw_movement_data_t;

typedef enum {
    RFD_RAW_ENVELOPE = 0,
    RFD_RAW_EMG_NUM,
} rfd_raw_emg_data_t;

void rfd_pos_algo_init(void);

float rfd_pos_algo_raw_movement_for_position(rfd_mdm_position_t position, rfd_raw_movement_data_t data_type);
float rfd_pos_algo_raw_movement_for_channel(uint8_t channel, rfd_raw_movement_data_t data_type);
float rfd_pos_algo_calibrated_body_angle_radians(rfd_mdm_position_t position, rfd_body_angle_t body_angle);

void rfd_pos_algo_recv_calculate_command(
           uint8_t valid0, float x0, float y0, float z0, float g0,
           uint8_t valid1, uint16_t e1,
           uint8_t valid2, float x2, float y2, float z2, float g2,
           uint8_t valid3, uint16_t e3);
void rfd_pos_algo_recv_movement_calibrate_command(void);
void rfd_pos_algo_recv_movement_twist_reset_command(const char* reason) __attribute__((nonnull));

void rfd_pos_algo_set_calibration_angles(
        rfd_mdm_position_t mdm_position,
        float forward_calibration,
        float lateral_calibration);
void rfd_pos_algo_get_calibration_angles(
                rfd_mdm_position_t mdm_position,
                float* forward_calibration,
                float* lateral_calibration) __attribute__((nonnull));

void rfd_pos_algo_recv_emg_calibration_start(void);
float rfd_pos_algo_get_emg_calibration_peak_average(rfd_mde_position_t mde_position);
void rfd_pos_algo_set_emg_calibration_peak_average(rfd_mde_position_t mde_position, float new_value);
uint8_t rfd_pos_algo_emg_valid(void);

#endif

/* End of file */
