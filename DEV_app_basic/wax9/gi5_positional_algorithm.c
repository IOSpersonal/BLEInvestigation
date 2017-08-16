/**
\file gi5_positional_algorithm.c

\brief Grey Innovation BSMv5 Positional Algorithm implementation

\note Define USE_GI5_POSITIONAL_ALGORITHM in order to use these functions, otherwise they have no effect.

Copyright 2012 Grey Innovation Pty Ltd. All rights reserved.

*/
#define USE_GI5_POSITIONAL_ALGORITHM

#ifdef USE_GI5_POSITIONAL_ALGORITHM


#include "gmos_vector.h"
#include "gmos_math.h"

#ifdef RFD_PA

#endif

#include "data_streams.h"
#include "rfdapi.h"
#include "gi5_positional_algorithm.h"
#include "bsm4_rfd_algorithm_calculations.h"
#include "app_measurement.h"
//#include "system_config.h"

enum system_config_id
{
    V5LUMBARSPINE_TWOMDM_3M8S12B_3A8S12B_3G8S12B_TWOMDE_1E20S10B=0,
    BSM4_TWOMDM_3A20S12B_2G0S0B_1G20S12B_TWOMDE_1E20S10B=1,
    GOLF1_TWOMDM_3M6S10B_3A6S10B_3G40S12B=2,
    LANDING2PELVIC_TWOMDM_3M4S10B_3A4S10B_3G40S12B=3,
    ASKLING2_TWOMDM_3M8S12B_3A8S12B_1G20S12B_1G60S12B_1G20S12B=4,
    OHS1_FOURMDM_3M4S10B_3A4S10B_3G10S10B_FOURMDE_1E10S10B=5,
    OHS2_FOURMDM_3M4S10B_3A4S10B_3G10S10B_TWOMDE_1E10S10B=6,
    RUNNING2_TWOMDM_1A100S12B_2A20S12B=7,
    OHS3_SIXMDM_3M4S10B_3A4S10B_3G10S10B_TWOMDE_1E10S10B=8,
    ONEMDE_1E350S10B=9,
    ASKLING1_TWOMDM_3M4S12B_3A4S12B_3G40S12B=10,
    LANDING1_TWOMDM_3M8S12B_3A8S12B_3G30S12B=11,
    TWOMDE_1E160S10B=12,
    RUNNING1_ONEMDM_3A100S12B=13,
    R118_TWOMDM_3M4S10B_3A8S10B_3G8S10B_TWOMDE_1E20S10B=14,
    ONEMDM_3M4S10B_3A8S10B_3G8S10B=15,
    CALIBRATION_ONEMDM_3M8S12B_3A20S12B_3G30S12B_3LA20S12B=16,
    RUNNING3_TWOMDM_1A200S12B_2A0S0B=17,
    V5LUMBARSPINE_TWOMDM_3M10S12B_3A10S12B_3G20S12B=18,
    FLASHINVESTIGATION_TWOMDM_3A200S16B_3M200S16B_3G200S16B_3LA200S16B_FLASH=19,
    RUNNING4_TWOMDM_1A100S12B_2A0S12B_3G30S10B=20,
    FOURMDE_1E90S10B = 21,
    SIXMDE_1E80S8B = 22,
    TWOMDE_1E225S8B = 23,
    EIGHTMDE_1E50S8B = 24,
    TWOMDM_1A50S8B_TWOMDE_1E100S8B = 25,
    FLASHINVESTIGATION_TWOMDM_3A200S16B_3M200S16B_3G200S16B_FLASH = 26,
    ONEMDM_1A100S12B_ONEMDE_1E180S10B = 27,
    VIBRATION_TWOMDM_3A50S10B = 28,
    KNEE_TWOMDM_3A4S10B_3G50S10B = 29,
};

app_processed_data_t app_processed_data;

const char* config_fitment_forward[] = { "Gi.Fitment.Lower.FF", "Gi.Fitment.Upper.FF" };
const char* config_fitment_lateral[] = { "Gi.Fitment.Lower.LF", "Gi.Fitment.Upper.LF" };
const char* config_fitment_twist = "Gi.Fitment.Diff.TW";
const char* config_fitment_accel[] = { "Gi.Fitment.Lower.AS", "Gi.Fitment.Upper.AS" };
const float fitment_angle_scale = 1000.0f;

#define LOWER 0
#define UPPER 1
#define POSITIONS 2

#define X 0
#define Y 1
#define Z 2
#define AXES 3

#define YAW 0
#define PITCH 1
#define ROLL 2

#define ACCEL_DEBOUNCE_LENGTH 4
#define GYRO_DRIFT_CAPTURE_LENGTH 50
#define GYRO_DRIFT_LENGTH 100
#define MAG_FILTER_LENGTH 3

#define NOMINAL_ROW_SAMPLE_RATE 20.0f

#define R_TO_D (180.0f / RFDAPI_MATH_PI)
#define D_TO_R (RFDAPI_MATH_PI / 180.0f)

#define MIN(a,b)  ( {typeof(a) _a = a; typeof(b) _b = b; _a < _b ? _a : _b;} )

typedef enum {
    FLAGS_NUDGE_X = 1,
    FLAGS_NUDGE_Y = 2,
    FLAGS_NUDGE_Z = 4,
    FLAGS_RESET_Z = 8,
    FLAGS_LIMIT_Z = 16,
    FLAGS_RESET_XY = 32,
    FLAGS_FITMENT = 64,
    FLAGS_DRIFT_INSERT = 128,
    FLAGS_INIT_GYRO_DRIFT = 256,
    FLAGS_INIT_XY = 512,
    FLAGS_DYNAMIC_RESET_Z = 1024,
    FLAGS_LIMIT_MAG = 2048,
    FLAGS_MAG_CLOSE_TO_GRAVITY = 4096,
    FLAGS_IN_GREENZONE = 8192,
    FLAGS_IGNORE_GYRO = 16384,
    FLAGS_IGNORE_ACCEL = 32768,
    FLAGS_IGNORE_MAG = 65536,
    FLAGS_INIT_Z = 131072,
    FLAGS_INTERPOLATED_GYRO = 262144,
} algo_flags_t;

typedef struct {
    float data[AXES][GYRO_DRIFT_LENGTH]; // unit: DPS
    float data_sum[AXES]; // unit: DPS*data_sum_count
    float data_sum_corrected[AXES]; // unit: DPS*GYRO_DRIFT_LENGTH (valid once every GYRO_DRIFT_LENGTH)
    gmos_vector3 running_average; // unit: DPS*GYRO_DRIFT_CAPTURE_LENGTH
    uint16_t data_sum_count;
    uint16_t running_average_len;
    uint16_t tail;
} algo_drift_t;

typedef struct {
    algo_drift_t gyro_drift;
    float fitment_angle_radians[AXES];
    float sensor_angle_radians[AXES];
    float body_angle_radians[AXES];
    float previous_body_angle_radians[AXES];
    float accel_debounce[AXES][ACCEL_DEBOUNCE_LENGTH];
    float accel_debounce_magnitude[ACCEL_DEBOUNCE_LENGTH];
    float accel_debounced_magnitude;
    gmos_vector3 scaled_accel;
    gmos_vector3 scaled_debounced_accel;
    gmos_vector3 scaled_body_accel;
    gmos_vector3 scaled_debounced_body_accel;
    gmos_vector3 gyro_dps;
    gmos_vector3 body_gyro_dps;
    gmos_vector3 raw_mag;

    gmos_vector3 raw_mag_low_accumulated; // minima (only used at fitment)
    gmos_vector3 raw_mag_high_accumulated; // maxima (only used at fitment)
    gmos_vector3 raw_mag_hardiron; // calculated at fitment
    gmos_vector3 raw_mag_scale; // calculated at fitment

    gmos_vector3 mag_ypr;
    float mag_xh;
    float mag_yh;
    float mag_h_magnitude; // magnitude of heading information
    float accel_scale;
    float accel_world_forward;
    float accel_world_lateral;
    float dip_x;
    float diff_twist_correction;
    float confidence_indicator;
    uint32_t green_zone_counter;
    uint8_t unchanged_gyro_count;
    uint8_t whole_body_twist_counter;
    algo_flags_t flags;
} algo_mdm_t;
algo_mdm_t gi5_algo[POSITIONS];

enum {
    GI5_IGNORE_MAG_DIFF_TWIST_LIMIT = 1,
    GI5_IGNORE_ORIENTATION = 2,
    GI5_ENABLE_NUDGE_Z = 4,
    GI5_ENABLE_HARDIRON_CORR = 8,
    GI5_DISABLE_GYRO_DRIFT = 16,
};

typedef struct {
    uint32_t config_flags;
    float mag_diff_filter[MAG_FILTER_LENGTH];
} posalg_t;
posalg_t gi5_posalg;

static void debug_gyro_pre(algo_mdm_t* lower, algo_mdm_t* upper);
static void debug_gyro_body(const algo_mdm_t* lower, const algo_mdm_t* upper);
static uint8_t is_moving_accel(gmos_vector3* accel, float threshold)
{
    return (rfdapi_math_abs(gmos_vector3_magnitude(accel) - 1.0f) > threshold);
}

static uint8_t is_moving_gyro(gmos_vector3* gyro_dps, float threshold)
{
    return (gmos_vector3_magnitude(gyro_dps) > threshold);
}

#ifdef __DLL_EXPORTS
static const char* upper_lower_string(algo_mdm_t* mdm)
{
     return (mdm == &gi5_algo[LOWER]) ? "lower" : "upper";
}
#endif

static void gyro_insert_drift_deltas(algo_mdm_t* mdm)
{
    uint8_t init = (mdm->flags & FLAGS_INIT_GYRO_DRIFT) != 0;
    algo_drift_t* drift = &mdm->gyro_drift;
    
    if (init) {
        drift->tail = 0;
        drift->data_sum_count = 0;
        memset(drift->data, 0, sizeof(drift->data));
    } else {
        drift->tail = (drift->tail < GYRO_DRIFT_LENGTH - 1) ? (drift->tail + 1) : 0;
    }

    const char* doing;
    uint8_t axis;
    for (axis = 0; axis < AXES; axis++) {
        float insert_dps = mdm->gyro_drift.running_average[axis] / (float)GYRO_DRIFT_CAPTURE_LENGTH;

        if (init) {
            doing="init";
            drift->data_sum[axis] = insert_dps;
            drift->data_sum_corrected[axis] = insert_dps;
            drift->data[axis][drift->tail] = insert_dps;
        } else if (drift->tail == 0) { // tail wrapped, use the rounding error fix
            doing="tail wrap";
            drift->data_sum[axis] = drift->data_sum_corrected[axis] - drift->data[axis][drift->tail] + insert_dps;
            drift->data_sum_corrected[axis] = insert_dps;
            drift->data[axis][drift->tail] = insert_dps;
        } else if (drift->data_sum_count < GYRO_DRIFT_LENGTH) { // filling the drift filter still
            doing="filling";
            drift->data_sum[axis] += insert_dps;
            drift->data_sum_corrected[axis] += insert_dps;
            drift->data[axis][drift->tail] = insert_dps;
        } else { // rolling
            doing="rolling";
            drift->data_sum[axis] = drift->data_sum[axis] - drift->data[axis][drift->tail] + insert_dps;
            drift->data_sum_corrected[axis] += insert_dps;
            drift->data[axis][drift->tail] = insert_dps;
        }
    }

    if (drift->data_sum_count < GYRO_DRIFT_LENGTH) {
        drift->data_sum_count++;
    }

    //rfdapi_record_debug("DF[%c] %s #%d s=%f,%f,%f c=%f,%f,%f i=%f,%f,%f",  
    //       (mdm == &gi5_algo[LOWER]) ? 'L' : 'U',
    //       doing,
    //       drift->data_sum_count,
    //       drift->data_sum[X],
    //       drift->data_sum[Y],
    //       drift->data_sum[Z],
    //       drift->data_sum_corrected[X],
    //       drift->data_sum_corrected[Y],
    //       drift->data_sum_corrected[Z],
    //       mdm->gyro_drift.running_average[X] / (float)GYRO_DRIFT_CAPTURE_LENGTH,
    //       mdm->gyro_drift.running_average[Y] / (float)GYRO_DRIFT_CAPTURE_LENGTH,
    //       mdm->gyro_drift.running_average[Z] / (float)GYRO_DRIFT_CAPTURE_LENGTH);


    mdm->flags |= FLAGS_DRIFT_INSERT;
    mdm->flags &= ~FLAGS_INIT_GYRO_DRIFT;
}

static void gyro_drift_compensate(const float* sensor, const algo_drift_t* drift, float* result)
{
    uint8_t axis;
    for (axis = 0; axis < AXES; axis++) {
        result[axis] = sensor[axis] - drift->data_sum[axis] / (float)drift->data_sum_count;
    }
}

static void bsm_v5_receive_gyro_drift(algo_mdm_t* mdm)
{
    uint8_t result = 0;
    uint8_t accel_moving = is_moving_accel(&mdm->scaled_accel, 0.05f);
    uint8_t restart_moving_average = 0;
    if (accel_moving) {
        result = 2;
        restart_moving_average = 1;
    } else {
        uint8_t axis;
        for (axis = 0; axis < AXES; axis++) {
            mdm->gyro_drift.running_average[axis] += mdm->gyro_dps[axis];
        }
        mdm->gyro_drift.running_average_len++;
        if (mdm->gyro_drift.running_average_len >= GYRO_DRIFT_CAPTURE_LENGTH) {
            uint8_t gyro_moving = is_moving_gyro(&mdm->gyro_drift.running_average, GYRO_DRIFT_CAPTURE_LENGTH*3.0f);
            if (!gyro_moving) {
                gyro_insert_drift_deltas(mdm);
            } else {
                result = 3;
            }
            restart_moving_average = 1;
        } else {
            result = 1;
        }
    }

    if (restart_moving_average) {
        memset(&mdm->gyro_drift.running_average, 0, sizeof(mdm->gyro_drift.running_average));
        mdm->gyro_drift.running_average_len = 0;
    }

    if ((mdm->flags & GI5_DISABLE_GYRO_DRIFT) == 0) {
        gyro_drift_compensate((const float*)mdm->gyro_dps, (const algo_drift_t*)&mdm->gyro_drift, (float*)mdm->gyro_dps);
    }
    //rfdapi_record_debug_point(result, "%s_drift_inserted_result", upper_lower_string(mdm));
}

static void tilt_compensated_magnetometer_heading(
    gmos_vector3* raw_mag, 
    gmos_vector3* raw_mag_hardiron,
    gmos_vector3* raw_mag_scale,
    gmos_vector3* scaled_accel,
    gmos_vector3* ypr,
    float* xh, float* yh, float* h_magnitude)
{
    float x = ((*raw_mag)[X] + (*raw_mag_hardiron)[X]) * (*raw_mag_scale)[X];
    float y = ((*raw_mag)[Y] + (*raw_mag_hardiron)[Y]) * (*raw_mag_scale)[Y];
    float z = ((*raw_mag)[Z] + (*raw_mag_hardiron)[Z]) * (*raw_mag_scale)[Z];

    // ypr: yaw pitch roll or psi theta phi

    // From http://cache.freescale.com/files/sensors/doc/app_note/AN4248.pdf
    (*ypr)[ROLL] = gmos_math_atan2((*scaled_accel)[Y], (*scaled_accel)[Z]);
    (*ypr)[PITCH] = gmos_math_atan2(
        -(*scaled_accel)[X], 
        (*scaled_accel)[Y] * gmos_math_sin((*ypr)[ROLL]) + (*scaled_accel)[Z] * gmos_math_cos((*ypr)[ROLL])); // fixme: atan() not atan2()
    *yh = z * gmos_math_sin((*ypr)[ROLL]) 
        - y * gmos_math_cos((*ypr)[ROLL]);
    *xh = x * gmos_math_cos((*ypr)[PITCH]) 
        + y * gmos_math_sin((*ypr)[PITCH]) * gmos_math_sin((*ypr)[ROLL]) 
        + z * gmos_math_sin((*ypr)[PITCH]) * gmos_math_cos((*ypr)[ROLL]);

    (*ypr)[YAW] = gmos_math_atan2(*yh, *xh); // MJS: freescale and https://gist.github.com/322555 disagree on -yh ??

    *h_magnitude = gmos_math_sqrt((*yh)*(*yh)+(*xh)*(*xh)); //fixme probably doesn't need the sqrt
}

static void capture_hardiron_magnetometer_data(algo_mdm_t* mdm)
{
    // calculated on every sample, but captured only at fitment
    uint8_t axis;
    for (axis = 0; axis < AXES; axis++) {
        if (mdm->raw_mag[axis] < mdm->raw_mag_low_accumulated[axis]) { 
            mdm->raw_mag_low_accumulated[axis] = mdm->raw_mag[axis];
        }
        if (mdm->raw_mag[axis] > mdm->raw_mag_high_accumulated[axis]) {
            mdm->raw_mag_high_accumulated[axis] = mdm->raw_mag[axis];
        }
    }
}

static void bsm_v5_receive_mag(algo_mdm_t* mdm)
{
    capture_hardiron_magnetometer_data(mdm);
    tilt_compensated_magnetometer_heading(
        &(mdm->raw_mag), &(mdm->raw_mag_hardiron), &(mdm->raw_mag_scale),
        &(mdm->scaled_accel), &(mdm->mag_ypr), 
        &(mdm->mag_xh), &(mdm->mag_yh), &(mdm->mag_h_magnitude));
}


gmos_vector3* measured;

static void rfd_algorithm_calculate_unforward_accelerations(gmos_vector3* src, float angle, gmos_vector3* dest)
{
    gmos_vector3_rotate_about_basis(src, GMOS_VECTOR3_X, -angle, dest);
}

static void bsm_v5_project_halfstep(gmos_vector3* a, gmos_vector3* b, gmos_vector3* result)
{
    (*result)[X] =  (*b)[X] + 0.5f * ((*b)[X] - (*a)[X]);
    (*result)[Y] =  (*b)[Y] + 0.5f * ((*b)[Y] - (*a)[Y]);
    (*result)[Z] =  (*b)[Z] + 0.5f * ((*b)[Z] - (*a)[Z]);
}

void rfd_algorithm_calculate_unlateral_accelerations(
                                                     gmos_vector3* untwisted,
                                                     float lateral,
                                                     gmos_vector3* unlateral)
{
    gmos_vector3_rotate_about_basis(
                                    untwisted,
                                    GMOS_VECTOR3_Y,
                                    -lateral,
                                    unlateral);
}

void rfd_algorithm_calculate_untwisted_accelerations(
                                                     gmos_vector3* measured_accel,
                                                     float twist,
                                                     gmos_vector3* untwisted)
{
#ifdef UNTWIST_ACCELERATIONS
    gmos_vector3_rotate_about_basis(
                                    measured_accel,
                                    GMOS_VECTOR3_Z,
                                    -twist,
                                    untwisted);
#else
    gmos_vector3_copy(untwisted, measured);
#endif
}

float rfd_algorithm_calculate_lateralByOnlyX(gmos_vector3* accelerations)
{
    float magnitude = gmos_vector3_magnitude(accelerations);
    float aX = (*accelerations)[GMOS_VECTOR3_X] / magnitude;
    float dip = gmos_math_asin(aX);
    return dip;
}

float rfd_algorithm_calculate_forward_flexion(
                                              gmos_vector3* normalised_unlateral_accelerations)
{
    float forward;
#ifdef FORWARD_ANGLE_USING_DIP_Y
    forward = rfd_algorithm_calculate_dipY(normalised_unlateral_accelerations);
#else
    float aY = (*normalised_unlateral_accelerations)[GMOS_VECTOR3_Y];
    float aZ = (*normalised_unlateral_accelerations)[GMOS_VECTOR3_Z];
    forward = gmos_math_atan2(aY, aZ);
#endif
    forward = wrap_at_pi(forward);
    return forward;
}

float rfd_algorithm_calculate_lateral_flexion(
                                              gmos_vector3* normalised_accel_for_calc,
                                              gmos_vector3* normalised_accel_for_thresholds,
                                              float default_lateral,
                                              rfd_mdm_position_t mdm_pos_idx)
{
    float lateral;
#ifdef LATERAL_ANGLE_USING_DIP_X
    lateral = rfd_algorithm_calculate_dipX(accelerations);
#else
    float aX = (*normalised_accel_for_calc)[GMOS_VECTOR3_X];
    float aZ = (*normalised_accel_for_calc)[GMOS_VECTOR3_Z];
    lateral = gmos_math_atan2(aX, aZ);
    
#ifndef FORWARD_90_PROGRESSIVE_FILTER
    // the progressive reduce fixes this by limiting instead
    // rule7 causes an inversion past 90 forward
    // this rule set causes asymettric lateral response past 90 forward
    float aY = (*normalised_accel_for_calc)[GMOS_VECTOR3_Y];
    float adjust = 0.0f;
    // Note: it may make sense to update these rules for values of exactly zero.
    if (aX <  0.0f && aY <  0.0f && aZ <  0.0f                   ) adjust += GMOS_MATH_PI; // rules 1,2
    if (aX <= 0.0f && aY >  0.0f && aZ >  0.0f && lateral <  0.0f) adjust -= GMOS_MATH_PI; // rule  3
    if (aX >  0.0f && aY >  0.0f && aZ <  0.0f && lateral >  0.0f) adjust -= GMOS_MATH_PI; // rule  5
    if (aX >  0.0f && aY <  0.0f && aZ <  0.0f                   ) adjust -= GMOS_MATH_PI; // rule  6
    if (aX <  0.0f && aY >  0.0f                                 ) adjust += GMOS_MATH_PI; // rule  7
    //            if (aX >  0.0f && aY <  0.0f && aZ >  0.0f && lateral <  0.0f) adjust -= GMOS_MATH_PI; // rule  8
    //            if (aX == 0.0f && aY >  0.0f && aZ <  0.0f && lateral != 0.0f) adjust -= GMOS_MATH_PI; // rule  9
    
    lateral += adjust;
    if (lateral >= +GMOS_MATH_PI) lateral -= GMOS_MATH_PI;
    if (lateral <= -GMOS_MATH_PI) lateral += GMOS_MATH_PI;
    
    // Any lateral flexion is unknown when at (or near) 90 degrees forward,
    // as it is a rotation around the gravity vector, making limited or no difference
    // to measured acceleration.
    // => Lock in a default value to allow accurate calculation of forward flexion.
    float rawY = (*normalised_accel_for_thresholds)[GMOS_VECTOR3_Y];
    if (gmos_math_abs(rawY) > rfd_algo_accel_90_forwardY) {
        lateral = default_lateral;
    }
#endif
    
#endif
    return lateral;
}

/*float wrap_at_pi(float angle)
{
    if (gmos_math_abs(angle) > GMOS_MATH_PI) {
        angle += -gmos_math_sign(angle) * GMOS_MATH_TWO_PI;
    }
    return angle;
}*/

static void bsm_v5_calc_body_gyro_upper(algo_mdm_t* mdm)
{
//    rfdapi_record_debug_point(mdm->gyro_dps[X], "%s_gx", upper_lower_string(mdm));
//    rfdapi_record_debug_point(mdm->gyro_dps[Y], "%s_gy", upper_lower_string(mdm));
//    rfdapi_record_debug_point(mdm->gyro_dps[Z], "%s_gz", upper_lower_string(mdm));

    if (mdm->whole_body_twist_counter > 0) {
        --mdm->whole_body_twist_counter;
    }
    if (mdm->whole_body_twist_counter > 0) {
        memset(&mdm->body_gyro_dps, 0, sizeof(mdm->body_gyro_dps));
    } else {
        gmos_vector3 projected;
        bsm_v5_project_halfstep(&mdm->previous_body_angle_radians, &mdm->body_angle_radians, &projected);

        memcpy(&mdm->body_gyro_dps, &mdm->gyro_dps, sizeof(gmos_vector3));
//equiv to 35250        rfd_algorithm_calculate_untwisted_accelerations(&mdm->body_gyro_dps, -projected[Z], &mdm->body_gyro_dps);
//equiv to 35250        rfd_algorithm_calculate_unlateral_accelerations(&mdm->body_gyro_dps, -projected[Y], &mdm->body_gyro_dps);

//equiv to 35251        rfd_algorithm_calculate_unforward_accelerations(&mdm->body_gyro_dps, -mdm->fitment_angle_radians[X], &mdm->body_gyro_dps);
//equiv to 35251        rfd_algorithm_calculate_unlateral_accelerations(&mdm->body_gyro_dps, projected[Y] - mdm->fitment_angle_radians[Y], &mdm->body_gyro_dps);

        rfd_algorithm_calculate_unforward_accelerations(&mdm->body_gyro_dps, -mdm->fitment_angle_radians[X], &mdm->body_gyro_dps);
        rfd_algorithm_calculate_unlateral_accelerations(&mdm->body_gyro_dps, -mdm->fitment_angle_radians[Y], &mdm->body_gyro_dps);
        rfd_algorithm_calculate_untwisted_accelerations(&mdm->body_gyro_dps, -projected[Z], &mdm->body_gyro_dps);
        rfd_algorithm_calculate_unlateral_accelerations(&mdm->body_gyro_dps, -projected[Y], &mdm->body_gyro_dps);
    }
}

static void bsm_v5_calc_body_gyro_lower(algo_mdm_t* mdm)
{
//    rfdapi_record_debug_point(mdm->gyro_dps[X], "%s_gx", upper_lower_string(mdm));
//    rfdapi_record_debug_point(mdm->gyro_dps[Y], "%s_gy", upper_lower_string(mdm));
//    rfdapi_record_debug_point(mdm->gyro_dps[Z], "%s_gz", upper_lower_string(mdm));

    if (mdm->whole_body_twist_counter > 0) {
        --mdm->whole_body_twist_counter;
    }
    if (mdm->whole_body_twist_counter > 0) {
        memset(&mdm->body_gyro_dps, 0, sizeof(mdm->body_gyro_dps));
    } else {
        gmos_vector3 projected;
        bsm_v5_project_halfstep(&mdm->previous_body_angle_radians, &mdm->body_angle_radians, &projected);

        memcpy(&mdm->body_gyro_dps, &mdm->gyro_dps, sizeof(gmos_vector3));
        rfd_algorithm_calculate_unforward_accelerations(&mdm->body_gyro_dps, -mdm->fitment_angle_radians[X], &mdm->body_gyro_dps);
        rfd_algorithm_calculate_unlateral_accelerations(&mdm->body_gyro_dps, -mdm->fitment_angle_radians[Y], &mdm->body_gyro_dps);
        rfd_algorithm_calculate_untwisted_accelerations(&mdm->body_gyro_dps, -projected[Z], &mdm->body_gyro_dps);
        rfd_algorithm_calculate_unlateral_accelerations(&mdm->body_gyro_dps, -projected[Y], &mdm->body_gyro_dps);
    }
}

static void debug_whole_body_twist_pre(algo_mdm_t* lower, algo_mdm_t* upper)
{
#ifdef __DLL_EXPORTS
    static gmos_vector3 lower_raw_gyro;
    lower_raw_gyro[0] += lower->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[1] += lower->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[2] += lower->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(lower_raw_gyro[0], "gyro_pre_wbt_x1");
//    rfdapi_record_debug_point(lower_raw_gyro[1], "gyro_pre_wbt_y1");
//    rfdapi_record_debug_point(lower_raw_gyro[2], "gyro_pre_wbt_z1");

    static gmos_vector3 upper_raw_gyro;
    upper_raw_gyro[0] += upper->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[1] += upper->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[2] += upper->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(upper_raw_gyro[0], "gyro_pre_wbt_x2");
//    rfdapi_record_debug_point(upper_raw_gyro[1], "gyro_pre_wbt_y2");
//    rfdapi_record_debug_point(upper_raw_gyro[2], "gyro_pre_wbt_z2");

//    rfdapi_record_debug_point(lower->gyro_dps[0], "gyro_pre_wbt_x1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[1], "gyro_pre_wbt_y1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[2], "gyro_pre_wbt_z1_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[0], "gyro_pre_wbt_x2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[1], "gyro_pre_wbt_y2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[2], "gyro_pre_wbt_z2_dps");

    gmos_vector3 tmp;
    gmos_vector3 whole_body_twist;
    // don't use accel_world_forward as this can be well off the sphere and needs sign adjustment past 90 forwards
    rfd_algorithm_calculate_unforward_accelerations(&lower->gyro_dps, -(lower->body_angle_radians[X] + lower->fitment_angle_radians[X]), &tmp);
    rfd_algorithm_calculate_unlateral_accelerations(&tmp, -(lower->body_angle_radians[Y] + lower->fitment_angle_radians[Y]), &whole_body_twist);
//    rfdapi_record_debug_point(whole_body_twist[0], "wbt_x1_dps");
//    rfdapi_record_debug_point(whole_body_twist[1], "wbt_y1_dps");
//    rfdapi_record_debug_point(whole_body_twist[2], "wbt_z1_dps");

    rfd_algorithm_calculate_unforward_accelerations(&upper->gyro_dps, -(upper->body_angle_radians[X] + upper->fitment_angle_radians[X]), &tmp);
    rfd_algorithm_calculate_unlateral_accelerations(&tmp, -(upper->body_angle_radians[Y] + upper->fitment_angle_radians[Y]), &whole_body_twist);
//    rfdapi_record_debug_point(whole_body_twist[0], "wbt_x2_dps");
//    rfdapi_record_debug_point(whole_body_twist[1], "wbt_y2_dps");
//    rfdapi_record_debug_point(whole_body_twist[2], "wbt_z2_dps");
#endif
}

static void debug_whole_body_twist_post(const algo_mdm_t* lower, const algo_mdm_t* upper)
{
#ifdef __DLL_EXPORTS
    static gmos_vector3 lower_raw_gyro;
    lower_raw_gyro[0] += lower->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[1] += lower->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[2] += lower->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(lower_raw_gyro[0], "gyro_post_wbt_x1");
//    rfdapi_record_debug_point(lower_raw_gyro[1], "gyro_post_wbt_y1");
//    rfdapi_record_debug_point(lower_raw_gyro[2], "gyro_post_wbt_z1");

    static gmos_vector3 upper_raw_gyro;
    upper_raw_gyro[0] += upper->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[1] += upper->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[2] += upper->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(upper_raw_gyro[0], "gyro_post_wbt_x2");
//    rfdapi_record_debug_point(upper_raw_gyro[1], "gyro_post_wbt_y2");
//    rfdapi_record_debug_point(upper_raw_gyro[2], "gyro_post_wbt_z2");

//    rfdapi_record_debug_point(lower->gyro_dps[0], "gyro_post_wbt_x1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[1], "gyro_post_wbt_y1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[2], "gyro_post_wbt_z1_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[0], "gyro_post_wbt_x2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[1], "gyro_post_wbt_y2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[2], "gyro_post_wbt_z2_dps");
#endif
}

static void bsm_v5_remove_whole_body_twist(algo_mdm_t* lower, algo_mdm_t* upper)
{
    gmos_vector3 tmp;
    gmos_vector3 whole_body_twist;
    rfd_algorithm_calculate_unforward_accelerations(&lower->gyro_dps, -(lower->body_angle_radians[X] + lower->fitment_angle_radians[X]), &tmp);
    rfd_algorithm_calculate_unlateral_accelerations(&tmp, -(lower->body_angle_radians[Y] + lower->fitment_angle_radians[Y]), &whole_body_twist);

    whole_body_twist[X] = 0.0f;
    whole_body_twist[Y] = 0.0f;

    if (0){//is_moving_gyro(&whole_body_twist, 20.0f)) {
        upper->whole_body_twist_counter = 5;
        lower->whole_body_twist_counter = 5;
    } else {
        gmos_vector3 correction;
        rfd_algorithm_calculate_unlateral_accelerations(&whole_body_twist, +(lower->body_angle_radians[Y] + lower->fitment_angle_radians[Y]), &tmp);
        rfd_algorithm_calculate_unforward_accelerations(&tmp, +(lower->body_angle_radians[X] + lower->fitment_angle_radians[X]), &correction);
        gmos_vector3_subtract_from(&lower->gyro_dps, &correction);

        rfd_algorithm_calculate_unlateral_accelerations(&whole_body_twist, +(upper->body_angle_radians[Y] + upper->fitment_angle_radians[Y]), &tmp);
        rfd_algorithm_calculate_unforward_accelerations(&tmp, +(upper->body_angle_radians[X] + upper->fitment_angle_radians[X]), &correction);
        gmos_vector3_subtract_from(&upper->gyro_dps, &correction);
    }
}

static void debug_gyro_drift_corrected(const algo_mdm_t* lower, const algo_mdm_t* upper)
{
#ifdef __DLL_EXPORTS
    static gmos_vector3 lower_raw_gyro;
    lower_raw_gyro[0] += lower->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[1] += lower->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[2] += lower->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(lower_raw_gyro[0], "gyro_drift_corr_x1");
//    rfdapi_record_debug_point(lower_raw_gyro[1], "gyro_drift_corr_y1");
//    rfdapi_record_debug_point(lower_raw_gyro[2], "gyro_drift_corr_z1");

    static gmos_vector3 upper_raw_gyro;
    upper_raw_gyro[0] += upper->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[1] += upper->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[2] += upper->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(upper_raw_gyro[0], "gyro_drift_corr_x2");
//    rfdapi_record_debug_point(upper_raw_gyro[1], "gyro_drift_corr_y2");
//    rfdapi_record_debug_point(upper_raw_gyro[2], "gyro_drift_corr_z2");

//    rfdapi_record_debug_point(lower->gyro_dps[0], "gyro_drift_corr_x1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[1], "gyro_drift_corr_y1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[2], "gyro_drift_corr_z1_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[0], "gyro_drift_corr_x2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[1], "gyro_drift_corr_y2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[2], "gyro_drift_corr_z2_dps");

    uint8_t axis;
    for (axis = 0; axis < AXES; axis++) {
        rfdapi_record_debug_point(upper->gyro_drift.data_sum[axis] / (float)upper->gyro_drift.data_sum_count, "drift_upper%c", "xyz"[axis]);
        rfdapi_record_debug_point(lower->gyro_drift.data_sum[axis] / (float)lower->gyro_drift.data_sum_count, "drift_lower%c", "xyz"[axis]);
    }

#endif
}

static void bsm_v5_receive_gyro(algo_mdm_t* lower, algo_mdm_t* upper)
{
    debug_gyro_pre(lower, upper);
    bsm_v5_receive_gyro_drift(lower);
    bsm_v5_receive_gyro_drift(upper);

    debug_gyro_drift_corrected(lower, upper);

    debug_whole_body_twist_pre(lower, upper);
    bsm_v5_remove_whole_body_twist(lower, upper);
    debug_whole_body_twist_post(lower, upper);
    bsm_v5_calc_body_gyro_lower(lower);
    bsm_v5_calc_body_gyro_upper(upper);
    debug_gyro_body(lower, upper);
}

static void bsm_v5_debounce_accel(algo_mdm_t* mdm)
{
    uint8_t axis;
    for (axis = 0; axis < AXES; axis++) {
        float sum = 0.0f;
        uint8_t idx;
        for (idx = 0; idx < ACCEL_DEBOUNCE_LENGTH - 1; idx++) {
            float value = mdm->accel_debounce[axis][idx + 1];
            mdm->accel_debounce[axis][idx] = value;
            sum += value;
        }
        float value = mdm->scaled_accel[axis];
        mdm->accel_debounce[axis][idx] = value;
        sum += value;
        mdm->scaled_debounced_accel[axis] = sum / (float)ACCEL_DEBOUNCE_LENGTH;
    }

    {
        float sum = 0.0f;
        uint8_t idx;
        for (idx = 0; idx < ACCEL_DEBOUNCE_LENGTH - 1; idx++) {
            float value = mdm->accel_debounce_magnitude[idx + 1];
            mdm->accel_debounce_magnitude[idx] = value;
            sum += value;
        }
        float value = gmos_vector3_magnitude(&mdm->scaled_accel);
        mdm->accel_debounce_magnitude[idx] = value;
        sum += value;
        mdm->accel_debounced_magnitude = sum / (float)ACCEL_DEBOUNCE_LENGTH;
    }

//    rfdapi_record_debug_point(mdm->accel_debounced_magnitude, "%s_deb_acc_mag", upper_lower_string(mdm));
}

static void bsm_v5_receive_accel(algo_mdm_t* mdm)
{
    //rfdapi_record_debug_point(rfd_algorithm_calculate_dipX(&mdm->scaled_accel) * R_TO_D, "%s_dipx", upper_lower_string(mdm));
    //rfdapi_record_debug_point(rfd_algorithm_calculate_dipY(&mdm->scaled_accel) * R_TO_D, "%s_dipy", upper_lower_string(mdm));

    if ( (rfdapi_math_sign(mdm->scaled_accel[X]) == 0)
        && (rfdapi_math_sign(mdm->scaled_accel[Y]) == 0)
        && (rfdapi_math_sign(mdm->scaled_accel[Z]) == 0) ) {
            mdm->scaled_accel[Z] = 1.0f;
    } else {
        mdm->scaled_accel[X] *= mdm->accel_scale;
        mdm->scaled_accel[Y] *= mdm->accel_scale;
        mdm->scaled_accel[Z] *= mdm->accel_scale;
    }

    gmos_vector3 un_lat_fit_accel;
    rfd_algorithm_calculate_unlateral_accelerations(&mdm->scaled_accel, -mdm->fitment_angle_radians[Y], &un_lat_fit_accel);
    rfd_algorithm_calculate_unforward_accelerations(&un_lat_fit_accel, -mdm->fitment_angle_radians[X], &mdm->scaled_body_accel);
    const float rfd_algo_lateral_filter_length = 15.0f;
    mdm->dip_x = ((mdm->dip_x * (rfd_algo_lateral_filter_length - 1.0))
        - rfd_algorithm_calculate_lateralByOnlyX(&mdm->scaled_body_accel))
        / rfd_algo_lateral_filter_length;

    bsm_v5_debounce_accel(mdm);

    mdm->accel_world_forward = rfd_algorithm_calculate_forward_flexion(&mdm->scaled_debounced_accel);
    mdm->accel_world_lateral = -rfd_algorithm_calculate_lateral_flexion(
        &mdm->scaled_debounced_accel,
        &mdm->scaled_debounced_accel,
        -mdm->body_angle_radians[Y], 0);

    rfd_algorithm_calculate_unlateral_accelerations(&mdm->scaled_debounced_accel, -mdm->fitment_angle_radians[Y], &un_lat_fit_accel);
    rfd_algorithm_calculate_unforward_accelerations(&un_lat_fit_accel, -mdm->fitment_angle_radians[X], &mdm->scaled_debounced_body_accel);
}

static void bsm_v5_update_mdm_positions(algo_mdm_t* mdm)
{
    uint8_t axis;
    for (axis = 0; axis < AXES; axis++) {
        mdm->previous_body_angle_radians[axis] = mdm->body_angle_radians[axis];
        //rfdapi_record_debug_point(mdm->body_gyro_dps[X], "%s_bgx", upper_lower_string(mdm));
        //rfdapi_record_debug_point(mdm->body_gyro_dps[Y], "%s_bgy", upper_lower_string(mdm));
        //rfdapi_record_debug_point(mdm->body_gyro_dps[Z], "%s_bgz", upper_lower_string(mdm));
        mdm->body_angle_radians[axis] += mdm->body_gyro_dps[axis] * D_TO_R / NOMINAL_ROW_SAMPLE_RATE;
        mdm->sensor_angle_radians[axis] += mdm->gyro_dps[axis] * D_TO_R / NOMINAL_ROW_SAMPLE_RATE; // todo: reset of this for various applications
    }

    if (mdm == &gi5_algo[LOWER]) {
        //rfdapi_record_debug_point(app_processed_data.bo_type, "boa");
    }

    float dipping_x_weight = 0.0f;
    float x_delta = 0.0f;
    float dipping_y_weight = 0.0f;
    float y_delta = 0.0f;
//    rfdapi_record_debug_point(mdm->body_angle_radians[X] * R_TO_D, "%s_pre_nudge_bax", upper_lower_string(mdm));
//    rfdapi_record_debug_point(mdm->body_angle_radians[Y] * R_TO_D, "%s_pre_nudge_bay", upper_lower_string(mdm));

    float ff = rfd_algorithm_calculate_forward_flexion(&mdm->scaled_debounced_body_accel);
    float lf = -rfd_algorithm_calculate_lateral_flexion(
                                           &mdm->scaled_debounced_body_accel,
                                           &mdm->scaled_debounced_accel,
                                           -mdm->body_angle_radians[Y], 0);
    //rfdapi_record_debug_point(ff * R_TO_D, "%s_nudge_x_ff", upper_lower_string(mdm));
    //rfdapi_record_debug_point(lf * R_TO_D, "%s_nudge_y_lf", upper_lower_string(mdm));
    float ff_used = 0.0f;
    float lf_used = 0.0f;

    if (!is_moving_accel(&mdm->scaled_debounced_body_accel, 0.1f)
        && !is_moving_gyro(&mdm->body_gyro_dps, 40.0f) 
        && (mdm->flags & FLAGS_IGNORE_ACCEL) == 0) {

        dipping_x_weight = 0.34202014f - rfdapi_math_abs(mdm->scaled_debounced_body_accel[X]); // sin(20)
        if (dipping_x_weight > 0.0f) {// && mdm->green_zone_counter > 0) {
            ff_used = ff;
            x_delta = wrap_at_pi(ff - mdm->body_angle_radians[X]) * dipping_x_weight * 0.1f;
            mdm->body_angle_radians[X] = wrap_at_pi(mdm->body_angle_radians[X] + x_delta);
            mdm->previous_body_angle_radians[X] = mdm->body_angle_radians[X];
            mdm->flags |= FLAGS_NUDGE_X;
        }

        dipping_y_weight = -rfdapi_math_abs(mdm->scaled_debounced_body_accel[Y]);
        if (mdm == &gi5_algo[LOWER] && app_processed_data.bo_type != APP_BO_STANDING) {
            dipping_y_weight += 0.64279761f; // sin(40)
        } else {
            dipping_y_weight += 0.34202014f; // sin(20)
        }
        if (dipping_y_weight > 0.0f) {// && mdm->green_zone_counter > 0) {
            lf_used = lf;
            y_delta = wrap_at_pi(lf - mdm->body_angle_radians[Y]) * dipping_y_weight * 0.1f;
            mdm->body_angle_radians[Y] = wrap_at_pi(mdm->body_angle_radians[Y] + y_delta);
//            mdm->previous_body_angle_radians[Y] = mdm->body_angle_radians[Y];
            mdm->flags |= FLAGS_NUDGE_Y;
        }
    }
#ifdef RFD_PA
    rfdapi_record_debug_point(ff_used * R_TO_D, "%s_nudge_x_ff_used", upper_lower_string(mdm));
    rfdapi_record_debug_point(lf_used * R_TO_D, "%s_nudge_y_lf_used", upper_lower_string(mdm));
    rfdapi_record_debug_point(mdm->scaled_debounced_body_accel[X], "%s_sdbax", upper_lower_string(mdm));
    rfdapi_record_debug_point(mdm->scaled_debounced_body_accel[Y], "%s_sdbay", upper_lower_string(mdm));
    rfdapi_record_debug_point(mdm->scaled_debounced_body_accel[Z], "%s_sdbaz", upper_lower_string(mdm));
    
#endif
    
//    rfdapi_record_debug_point(dipping_x_weight, "%s_nudge_dipping_x_weight", upper_lower_string(mdm));
//    rfdapi_record_debug_point(x_delta, "%s_nudge_x_delta", upper_lower_string(mdm));
//    rfdapi_record_debug_point(dipping_y_weight, "%s_nudge_dipping_y_weight", upper_lower_string(mdm));
//    rfdapi_record_debug_point(y_delta, "%s_nudge_y_delta", upper_lower_string(mdm));

    // very slow lateral drift back to 0 to accommodate rounding and other errors, especially when sitting
    {
        float y;
        y=mdm->body_angle_radians[Y];
        y = y - (0.0002f * gmos_math_sign(y));
        mdm->body_angle_radians[Y] = y;
    }

    // very slow twist drift back to 0 to accommodate rounding and other errors, especially drift when sitting
    {
        float z;
        z = mdm->body_angle_radians[Z];
        z = z - (0.0001 * gmos_math_sign(z));
        mdm->body_angle_radians[Z] = z;
    }

    if ( (mdm->flags & FLAGS_INIT_XY) != 0) {
        mdm->body_angle_radians[X] = 0.0f;
        mdm->body_angle_radians[Y] = 0.0f;
        mdm->previous_body_angle_radians[X] = 0.0f;
        mdm->previous_body_angle_radians[Y] = 0.0f;
        mdm->flags = (mdm->flags & ~FLAGS_INIT_XY) | FLAGS_RESET_XY;
    } else if ( (mdm->flags & FLAGS_INIT_Z) != 0) {
        mdm->body_angle_radians[Z] = 0.0f;
        mdm->previous_body_angle_radians[Z] = 0.0f;
        mdm->flags = (mdm->flags & ~FLAGS_INIT_Z) | FLAGS_RESET_Z;
    } else if (app_processed_data.bo_type == APP_BO_DYNAMIC
        && ((gi5_posalg.config_flags & GI5_IGNORE_ORIENTATION) == 0)) {
            mdm->body_angle_radians[Z] = 0.0f;
            mdm->previous_body_angle_radians[Z] = 0.0f;
            mdm->flags |= FLAGS_DYNAMIC_RESET_Z;
    //} else if (mdm->green_zone_counter == 22) {
    //    mdm->body_angle_radians[Z] = 0.0f;
    //    mdm->previous_body_angle_radians[Z] = 0.0f;
    //    mdm->flags |= FLAGS_RESET_Z;
    } else if (rfdapi_math_sign(mdm->diff_twist_correction) != 0) {
        if ((gi5_posalg.config_flags & GI5_ENABLE_NUDGE_Z) != 0) {
            mdm->body_angle_radians[Z] = wrap_at_pi(mdm->body_angle_radians[Z] + mdm->diff_twist_correction);
            mdm->previous_body_angle_radians[Z] = mdm->body_angle_radians[Z];
            mdm->flags |= FLAGS_NUDGE_Z;
        }
    }
}

static void bsm_v5_check_twist_reset_in_green_zone(algo_mdm_t* lower, algo_mdm_t* upper)
{
    const float green_zone_radians = 10.0f * D_TO_R;
    const float lateral_greenzone_y_limit = 0.5f; // sin(30)
    float dipping_y_weight = (lateral_greenzone_y_limit - rfdapi_math_abs(upper->scaled_debounced_body_accel[Y]))
        / lateral_greenzone_y_limit;
    float lower_weight = (green_zone_radians - rfdapi_math_abs(lower->dip_x)) / green_zone_radians;
    float upper_weight = (green_zone_radians - rfdapi_math_abs(upper->dip_x - lower->dip_x)) / green_zone_radians;
    uint8_t inGreenZone = 0;
    if (dipping_y_weight > 0.0f && lower_weight > 0.0f && upper_weight > 0.0f) {
        inGreenZone = 1;
        float weight = 0.01f;
        if (upper->green_zone_counter >= 10) {
            weight *= 10.0f;
        }
        upper->diff_twist_correction = -weight * dipping_y_weight * lower_weight * upper_weight * upper->body_angle_radians[Z]; // fixme: consider applying upper and lower weights separately
    } else {
        //upper->diff_twist_correction = 0.0f;
    }
    if (inGreenZone) {
        if (!is_moving_accel(&lower->scaled_accel, 0.05f) && !is_moving_accel(&upper->scaled_accel, 0.05f) ) {
            lower->flags |= FLAGS_IN_GREENZONE;
            upper->flags |= FLAGS_IN_GREENZONE;
            ++upper->green_zone_counter;
        } else {
            upper->green_zone_counter = 0;
        }
    } else {
        upper->green_zone_counter = 0;
    }
    lower->green_zone_counter = upper->green_zone_counter;
}

static float get_data(const rfdapi_measurement_data_t* data_vector, uint8_t channel, uint8_t stream)
{
    int8_t data_index = data_vector[channel].data_index[stream];
    if (data_index < 0) {
        rfdapi_record_debug("Data type %u not found in vector", (unsigned)stream);
        return 0.0f;
    }
    float scale = data_vector[channel].data_scales[data_index];
    int32_t raw_value = data_vector[channel].data[data_index];
    return (float)raw_value * scale;
}

static uint8_t get_data_changed(const rfdapi_measurement_data_t* data_vector, uint8_t channel, uint8_t stream)
{
    int8_t data_index = data_vector[channel].data_index[stream];
    if (data_index < 0) {
        rfdapi_record_debug("Data type %u not found in vector", (unsigned)stream);
        return 0;
    }
    return (data_vector[channel].data_changed_bits[data_index / 32] & (1 << (data_index % 32))) ? 1 : 0;
}

static uint8_t get_data_interpolated(const rfdapi_measurement_data_t* data_vector, uint8_t channel, uint8_t stream)
{
    int8_t data_index = data_vector[channel].data_index[stream];
    if (data_index < 0) {
        rfdapi_record_debug("Data type %u not found in vector", (unsigned)stream);
        return 0;
    }
    return (data_vector[channel].interpolated_bits[data_index / 32] & (1 << (data_index % 32))) ? 1 : 0;
}

static int8_t input_channel_lower(const rfdapi_measurement_data_t* data_vector, uint8_t length)
{
    if (length == 0) return -1;
    return 0;
}

static int8_t input_channel_upper(const rfdapi_measurement_data_t* data_vector, uint8_t length)
{
    if (length <= 1 || data_vector[1].data_index[MD_STREAM_GYROSCOPE_X] == -1) {
        if (length <= 2 || data_vector[2].data_index[MD_STREAM_GYROSCOPE_X] == -1) {
            rfdapi_record_debug("upper channel not found");
        } else {
            return 2;
        }
    } else {
        return 1;
    }
    return -1;
}

void gi5_get_mdm_input_channels(const rfdapi_measurement_data_t* data_vector, int8_t length, int8_t* lower_channel, int8_t* upper_channel)
{
    //rfdapi_assert(lower_channel != NULL);
    //rfdapi_assert(upper_channel != NULL);
    *lower_channel = input_channel_lower(data_vector, length);
    *upper_channel = input_channel_upper(data_vector, length);
}

void gi5_get_mdm_output_channels(const rfdapi_measurement_data_t* data_vector, int8_t length, int8_t* lower_channel, int8_t* upper_channel)
{
    //rfdapi_assert(lower_channel != NULL);
    //rfdapi_assert(upper_channel != NULL);
    *lower_channel = LOWER;
    *upper_channel = UPPER;
}

static void check_for_interpolated_gyro(const rfdapi_measurement_data_t* data_vector, uint8_t length, algo_mdm_t* lower, algo_mdm_t* upper)
{
    int8_t lower_channel = input_channel_lower(data_vector, length);
    int8_t upper_channel = input_channel_upper(data_vector, length);
    //rfdapi_assert(lower_channel != -1 && upper_channel != -1);
    if (get_data_interpolated(data_vector, lower_channel, MD_STREAM_GYROSCOPE_X)) {
        lower->flags |= FLAGS_INTERPOLATED_GYRO;
    }
    if (get_data_interpolated(data_vector, upper_channel, MD_STREAM_GYROSCOPE_X)) {
        upper->flags |= FLAGS_INTERPOLATED_GYRO;
    }
}

static uint8_t get_max_unchanged_ignore_gyro(void)
{
    // q.v. md_datasync.c
    uint8_t result = 255; // avoid compiler warning
    switch(rfdapi_get_system_config()) {
    case V5LUMBARSPINE_TWOMDM_3M8S12B_3A8S12B_3G8S12B_TWOMDE_1E20S10B:
        result = 5; // 5 unchanged data rows ~=2 missed gyro samples -- fixme: assumes regular EMG throughput
        //result = 11; // >11 unchanged data rows ~=5 missed gyro samples -- fixme: assumes regular EMG throughput
        break;
    case V5LUMBARSPINE_TWOMDM_3M10S12B_3A10S12B_3G20S12B:
        result = 3; // 3 unchanged data rows ~=2 missed gyro samples
        //result = 4; // >4 unchanged data rows = 5 missed gyro samples
        break;
    default:
        rfdapi_assert(0);
    }
    return result;
}

static float get_expected_gyro_samples_per_second(void)
{
    uint8_t result;
    //switch(rfdapi_get_system_config()) {
    switch(rfdapi_get_system_config()) {
    case V5LUMBARSPINE_TWOMDM_3M8S12B_3A8S12B_3G8S12B_TWOMDE_1E20S10B:
        result = 8.33333f;
        break;
    case V5LUMBARSPINE_TWOMDM_3M10S12B_3A10S12B_3G20S12B:
        result = 20.0f;
        break;
    default:
        rfdapi_assert(0);
    }
    return result;
}

static float get_expected_accel_samples_per_second(void)
{
    uint8_t result;
    switch(rfdapi_get_system_config()) {
    case V5LUMBARSPINE_TWOMDM_3M8S12B_3A8S12B_3G8S12B_TWOMDE_1E20S10B:
        result = 8.33333f;
        break;
    case V5LUMBARSPINE_TWOMDM_3M10S12B_3A10S12B_3G20S12B:
        result = 10.0f;
        break;
    default:
        rfdapi_assert(0);
    }
    return result;
}

static float get_expected_mag_samples_per_second(void)
{
    uint8_t result;
    switch(rfdapi_get_system_config()) {
    case V5LUMBARSPINE_TWOMDM_3M8S12B_3A8S12B_3G8S12B_TWOMDE_1E20S10B:
        result = 8.33333f;
        break;
    case V5LUMBARSPINE_TWOMDM_3M10S12B_3A10S12B_3G20S12B:
        result = 10.0f;
        break;
    default:
        rfdapi_assert(0);
    }
    return result;
}

static uint8_t save_data(const rfdapi_measurement_data_t* data_vector, uint8_t length)
{
    int8_t lower_channel = input_channel_lower(data_vector, length);
    int8_t upper_channel = input_channel_upper(data_vector, length);

    if ((lower_channel == -1) || (upper_channel == -1)) {
        rfdapi_record_debug("gi5_algo: incorrect input data size");
        return 0;
    }

    if (get_data_changed(data_vector, lower_channel, MD_STREAM_GYROSCOPE_X)) {
        gi5_algo[LOWER].unchanged_gyro_count = 0;
    } else if (gi5_algo[LOWER].unchanged_gyro_count < 255) {
        gi5_algo[LOWER].unchanged_gyro_count++;
    }
    if (get_data_changed(data_vector, upper_channel, MD_STREAM_GYROSCOPE_X)) {
        gi5_algo[UPPER].unchanged_gyro_count = 0;
    } else if (gi5_algo[UPPER].unchanged_gyro_count < 255) {
        gi5_algo[UPPER].unchanged_gyro_count++;
    }

    gmos_vector3* sensor;
    sensor = &gi5_algo[LOWER].gyro_dps;
    uint8_t max_unchanged_ignore_gyro = get_max_unchanged_ignore_gyro();

    if (gi5_algo[LOWER].unchanged_gyro_count > max_unchanged_ignore_gyro) {
        gi5_algo[LOWER].flags |= FLAGS_IGNORE_GYRO;
        float data_sum_count = (float)gi5_algo[LOWER].gyro_drift.data_sum_count;
        (*sensor)[X] = gi5_algo[LOWER].gyro_drift.data_sum[X] / data_sum_count;
        (*sensor)[Y] = gi5_algo[LOWER].gyro_drift.data_sum[Y] / data_sum_count;
        (*sensor)[Z] = gi5_algo[LOWER].gyro_drift.data_sum[Z] / data_sum_count;
    } else {
        (*sensor)[X] = -get_data(data_vector, lower_channel, MD_STREAM_GYROSCOPE_X);
        (*sensor)[Y] = +get_data(data_vector, lower_channel, MD_STREAM_GYROSCOPE_Y);
        (*sensor)[Z] = -get_data(data_vector, lower_channel, MD_STREAM_GYROSCOPE_Z);
    }

    sensor = &gi5_algo[UPPER].gyro_dps;
    if (gi5_algo[UPPER].unchanged_gyro_count > max_unchanged_ignore_gyro) {
        gi5_algo[UPPER].flags |= FLAGS_IGNORE_GYRO;
        float data_sum_count = (float)gi5_algo[UPPER].gyro_drift.data_sum_count;
        (*sensor)[X] = gi5_algo[UPPER].gyro_drift.data_sum[X] / data_sum_count;
        (*sensor)[Y] = gi5_algo[UPPER].gyro_drift.data_sum[Y] / data_sum_count;
        (*sensor)[Z] = gi5_algo[UPPER].gyro_drift.data_sum[Z] / data_sum_count;
    } else {
        (*sensor)[X] = +get_data(data_vector, upper_channel, MD_STREAM_GYROSCOPE_X);
        (*sensor)[Y] = +get_data(data_vector, upper_channel, MD_STREAM_GYROSCOPE_Y);
        (*sensor)[Z] = +get_data(data_vector, upper_channel, MD_STREAM_GYROSCOPE_Z);
    }


    sensor = &gi5_algo[LOWER].scaled_accel;
    (*sensor)[X] = +get_data(data_vector, lower_channel, MD_STREAM_ACCELEROMETER_X);
    (*sensor)[Y] = -get_data(data_vector, lower_channel, MD_STREAM_ACCELEROMETER_Y);
    (*sensor)[Z] = +get_data(data_vector, lower_channel, MD_STREAM_ACCELEROMETER_Z);

    sensor = &gi5_algo[UPPER].scaled_accel;
    (*sensor)[X] = -get_data(data_vector, upper_channel, MD_STREAM_ACCELEROMETER_X);
    (*sensor)[Y] = -get_data(data_vector, upper_channel, MD_STREAM_ACCELEROMETER_Y);
    (*sensor)[Z] = -get_data(data_vector, upper_channel, MD_STREAM_ACCELEROMETER_Z);


    sensor = &gi5_algo[LOWER].raw_mag;
    (*sensor)[X] = +get_data(data_vector, lower_channel, MD_STREAM_MAGNETOMETER_X);
    (*sensor)[Y] = -get_data(data_vector, lower_channel, MD_STREAM_MAGNETOMETER_Y);
    (*sensor)[Z] = +get_data(data_vector, lower_channel, MD_STREAM_MAGNETOMETER_Z);

    sensor = &gi5_algo[UPPER].raw_mag;
    (*sensor)[X] = -get_data(data_vector, upper_channel, MD_STREAM_MAGNETOMETER_X);
    (*sensor)[Y] = -get_data(data_vector, upper_channel, MD_STREAM_MAGNETOMETER_Y);
    (*sensor)[Z] = -get_data(data_vector, upper_channel, MD_STREAM_MAGNETOMETER_Z);

    return 1;
}

static float rfd_algorithm_apply_progressive_limit(float initial, float knee, float limit, float reduced_limit)
{
    // apply a soft rolloff to the calculated result angle as it increases, to allot
    // results according to body model
    float abs_result = rfdapi_math_abs(initial);
    float reduced;

    if (abs_result > limit) {
        reduced = reduced_limit;
    } else if (abs_result < knee) {
        reduced = abs_result;
    } else {
        float ratio = (abs_result - knee) / (limit - knee);
        float inv_ratio = 1.0f - ratio;
        float curved = 1.0f - (inv_ratio * inv_ratio);
        reduced = knee + curved * (reduced_limit - knee);
    }

    return (initial < 0.0f) ? -reduced : reduced;
}

static float get_filtered_diff_mag_twist(void)
{
    float result = 0.0;
    uint8_t index;
    rfdapi_assert(MAG_FILTER_LENGTH == sizeof(gi5_posalg.mag_diff_filter)/sizeof(gi5_posalg.mag_diff_filter[0]));
    for (index = 0; index < MAG_FILTER_LENGTH; index++) {
        result += gi5_posalg.mag_diff_filter[index];
    }
    return result / MAG_FILTER_LENGTH;
}

static void bsm_v5_update_diff_positions(const rfdapi_measurement_data_t* data_vector, uint8_t length, algo_mdm_t* lower, algo_mdm_t* upper)
{
    int8_t lower_channel;
    int8_t upper_channel;
    gi5_get_mdm_output_channels(data_vector, length, &lower_channel, &upper_channel);

    {
        float forward_lower;
        float forward_upper;
        {
            const float knee = 80.0f * D_TO_R;
            const float limit = 110.0f * D_TO_R;
            const float reduced_limit = 95.0f * D_TO_R;
            forward_lower = rfd_algorithm_apply_progressive_limit(lower->body_angle_radians[X], knee, limit, reduced_limit);
        }
        {
            const float knee = 150.0f * D_TO_R;
            const float limit = 170.0f * D_TO_R;
            const float reduced_limit = 160.0f * D_TO_R;
            forward_upper = rfd_algorithm_apply_progressive_limit(upper->body_angle_radians[X], knee, limit, reduced_limit);
        }
        float diff_forward = forward_upper - forward_lower;
        {
            const float knee = 60.0f * D_TO_R;
            const float limit = 120.0f * D_TO_R;
            const float reduced_limit = 90.0f * D_TO_R;
            diff_forward = rfd_algorithm_apply_progressive_limit(diff_forward, knee, limit, reduced_limit);
        }
        app_processed_data.pa_data[lower_channel][APP_PA_FORWARD] = forward_lower;
        app_processed_data.pa_data[upper_channel][APP_PA_FORWARD] = forward_upper;
        app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback.lumbar_forward = diff_forward;
    }

    {
        float lateral_lower;
        float lateral_upper;
        {
            const float knee = 45.0f * D_TO_R;
            const float limit = 90.0f * D_TO_R;
            const float reduced_limit = 30.0f * D_TO_R;
            lateral_lower = rfd_algorithm_apply_progressive_limit(lower->body_angle_radians[Y], knee, limit, reduced_limit);
        }
        {
            const float knee = 60.0f * D_TO_R;
            const float limit = 120.0f * D_TO_R;
            const float reduced_limit = 60.0f * D_TO_R;
            lateral_upper = rfd_algorithm_apply_progressive_limit(upper->body_angle_radians[Y], knee, limit, reduced_limit);
        }
        float diff_lateral = lateral_upper - lateral_lower;
        {
            const float knee = 40.0f * D_TO_R;
            const float limit = 70.0f * D_TO_R;
            const float reduced_limit = 50.0f * D_TO_R;
            diff_lateral = rfd_algorithm_apply_progressive_limit(diff_lateral, knee, limit, reduced_limit);
        }
        app_processed_data.pa_data[lower_channel][APP_PA_LATERAL] = lateral_lower;
        app_processed_data.pa_data[upper_channel][APP_PA_LATERAL] = lateral_upper;
        app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback.lumbar_lateral = diff_lateral;
    }

    {
        float diff_twist = upper->body_angle_radians[Z] - lower->body_angle_radians[Z];
        const float knee = 20.0f * D_TO_R;
        const float limit = 30.0f * D_TO_R;
        const float reduced_limit = 25.0f * D_TO_R;
        if (rfdapi_math_abs(diff_twist) > limit) { // cap body angles for feedback, don't save the soft limited version
            diff_twist = limit * rfdapi_math_sign(diff_twist);
            upper->flags |= FLAGS_LIMIT_Z;
        }

        const float magnetometer_tilt_limit = 0.1f; // insufficient power in the magnetometer - field lines too close to gravity
        {
            float diff_mag_twist = wrap_at_pi(upper->mag_ypr[YAW] - lower->mag_ypr[YAW] - lower->fitment_angle_radians[Z]);
//          rfdapi_record_debug_point(wrap_at_pi(diff_mag_twist)*R_TO_D, "diff_mag_twist");
            uint8_t index;
            for (index = 0; index < MAG_FILTER_LENGTH - 1; index++) {
                gi5_posalg.mag_diff_filter[index] = gi5_posalg.mag_diff_filter[index + 1];
            }
            gi5_posalg.mag_diff_filter[MAG_FILTER_LENGTH - 1] = diff_mag_twist;
            diff_mag_twist = get_filtered_diff_mag_twist();
            float diff_mag_twist_limit = rfdapi_math_abs(diff_mag_twist) + (1.0f * D_TO_R); //fixme: kalman
            //rfdapi_record_debug_point(diff_mag_twist*R_TO_D, "diff_mag_filt");
            
#ifdef RFD_PA
            
            rfdapi_record_debug_point(wrap_at_pi(upper->mag_ypr[YAW] - lower->mag_ypr[YAW])*R_TO_D, "diff_mag_yaw");
            rfdapi_record_debug_point(wrap_at_pi(upper->mag_ypr[PITCH] - lower->mag_ypr[PITCH])*R_TO_D, "diff_mag_pitch");
            rfdapi_record_debug_point(wrap_at_pi(upper->mag_ypr[ROLL] - lower->mag_ypr[ROLL])*R_TO_D, "diff_mag_roll");
            rfdapi_record_debug_point(wrap_at_pi(diff_mag_twist_limit)*R_TO_D, "diff_mag_twist_limit_pve");
            rfdapi_record_debug_point(-wrap_at_pi(diff_mag_twist_limit)*R_TO_D, "diff_mag_twist_limit_nve");
#endif
            
            if (upper->mag_h_magnitude > magnetometer_tilt_limit
                && lower->mag_h_magnitude > magnetometer_tilt_limit) {

                if ((gi5_posalg.config_flags & GI5_IGNORE_MAG_DIFF_TWIST_LIMIT) == 0
                    && rfdapi_math_abs(diff_twist) > diff_mag_twist_limit
                    && (lower->flags & FLAGS_IGNORE_MAG) == 0
                    && (upper->flags & FLAGS_IGNORE_MAG) == 0) { // cap body angles for feedback, don't save the soft limited version

                    diff_twist = diff_twist * ((upper->green_zone_counter >= 20) ? 0.98 : 0.998);
                    upper->flags |= FLAGS_LIMIT_MAG;
                }
            } else {
                upper->flags |= FLAGS_MAG_CLOSE_TO_GRAVITY;
            }
        }

        lower->body_angle_radians[Z] = 0.0f;
        upper->body_angle_radians[Z] = diff_twist;

        diff_twist = rfd_algorithm_apply_progressive_limit(diff_twist, knee, limit, reduced_limit);
        app_processed_data.pa_data[lower_channel][APP_PA_TWIST] = 0.0f;
        app_processed_data.pa_data[upper_channel][APP_PA_TWIST] = upper->body_angle_radians[Z];
        app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback.lumbar_twist = diff_twist;
    }
}

void gi5_calculate_fitment_angles()
{
    uint8_t position;
    for (position = 0; position < POSITIONS; position++) {
        algo_mdm_t* mdm = &gi5_algo[position];
        uint8_t axis;
        for (axis = 0; axis < AXES; axis++) {
            mdm->body_angle_radians[axis] = 0.0f;
            mdm->previous_body_angle_radians[axis] = 0.0f;
            mdm->sensor_angle_radians[axis] = 0.0f;
        }
        float forward = rfd_algorithm_calculate_forwardByOnlyY(&mdm->scaled_debounced_accel);
        float lateral = -rfd_algorithm_calculate_lateralByOnlyX(&mdm->scaled_debounced_accel);
        float scale_adjust = 1.0f / mdm->accel_debounced_magnitude;
        mdm->accel_scale *= scale_adjust;
        uint8_t idx = 0;
        for (idx = 0; idx < ACCEL_DEBOUNCE_LENGTH; idx++) {
            mdm->accel_debounce[idx][X] *= scale_adjust;
            mdm->accel_debounce[idx][Y] *= scale_adjust;
            mdm->accel_debounce[idx][Z] *= scale_adjust;
            mdm->accel_debounce_magnitude[idx] *= scale_adjust;
        }
        mdm->fitment_angle_radians[X] = forward;
        mdm->fitment_angle_radians[Y] = lateral;
        rfdapi_config_set_int(config_fitment_forward[position], (int)(forward * fitment_angle_scale));
        rfdapi_config_set_int(config_fitment_lateral[position], (int)(lateral * fitment_angle_scale));
        rfdapi_config_set_int(config_fitment_accel[position], (int)(mdm->accel_scale * fitment_angle_scale));
        rfdapi_record_debug("Fit%u:FF %f,LF %f,AS %f,sdZ %f GDA %f,%f,%f",
            (unsigned)position,
            forward * R_TO_D,
            lateral * R_TO_D,
            mdm->accel_scale,
            mdm->scaled_debounced_accel[Z] * scale_adjust,
            mdm->gyro_drift.data_sum[X]/mdm->gyro_drift.data_sum_count,
            mdm->gyro_drift.data_sum[Y]/mdm->gyro_drift.data_sum_count,
            mdm->gyro_drift.data_sum[Z]/mdm->gyro_drift.data_sum_count);
        mdm->flags |= FLAGS_FITMENT | FLAGS_INIT_XY | FLAGS_INIT_Z;
        // hack to update flags in reporting structure
        app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback_shoulder.output_quaternion_shoulder_right[position] = mdm->flags;

        if ((gi5_posalg.config_flags & GI5_ENABLE_HARDIRON_CORR) != 0) {
            uint8_t badcal = 0;
            float x_range = mdm->raw_mag_high_accumulated[0] - mdm->raw_mag_low_accumulated[0];
            for (axis = 0; axis < AXES; axis++) {
                float zero = (mdm->raw_mag_low_accumulated[axis] + mdm->raw_mag_high_accumulated[axis]) / 2.0f;
                if (zero < -0.2 || zero > 0.2) {
                    badcal = 1;
                }
                mdm->raw_mag_hardiron[axis] = -zero;
                if (axis > 0) {
                    float range = mdm->raw_mag_high_accumulated[axis] - mdm->raw_mag_low_accumulated[axis];
                    mdm->raw_mag_scale[axis] = x_range / range;
                }
            }

            if (badcal) {
                rfdapi_record_debug("Fit%u Mag hardiron calibration failed", (unsigned)position);
                for (axis = 0; axis < AXES; axis++) {
                    mdm->raw_mag_hardiron[axis] = 0.0;
                    mdm->raw_mag_scale[axis] = 1.0;
                }
            }
        }

        for (axis = 0; axis < AXES; axis++) {
            rfdapi_record_debug("Fit%u Mag%c %f...%f %f %f", (unsigned)position, 'X'+axis,
                mdm->raw_mag_low_accumulated[axis],
                mdm->raw_mag_high_accumulated[axis],
                mdm->raw_mag_hardiron[axis],
                mdm->raw_mag_scale[axis]);
        }
    }
//float diff_mag_twist = wrap_at_pi(upper->mag_ypr[YAW] - lower->mag_ypr[YAW] - lower->fitment_angle_radians[Z]);
    float diff_twist_corr = get_filtered_diff_mag_twist() + gi5_algo[LOWER].fitment_angle_radians[Z];
    diff_twist_corr = rfd_algorithm_apply_progressive_limit(diff_twist_corr, 5.0f * D_TO_R, 10.0f * D_TO_R, 6.0f * D_TO_R);
    gi5_algo[LOWER].fitment_angle_radians[Z] = diff_twist_corr;
    rfdapi_config_set_int(config_fitment_twist, (int)(diff_twist_corr * fitment_angle_scale));
    rfdapi_record_debug("FitTW: %f", diff_twist_corr * R_TO_D);
    //rfdapi_config_internal_persist(); // or call persist on fitment parameters only
}

static void debug_row_rate(uint32_t session_tick_count)
{
#ifdef __DLL_EXPORTS
    static uint32_t last_session_tick_count = 0;
    static float session_tick_count_filter = 0;
    uint32_t delta = session_tick_count - last_session_tick_count; // milliseconds
    last_session_tick_count = session_tick_count;
    session_tick_count_filter = ((session_tick_count_filter * 4.0f) + (float)delta) / 5.0f; // milliseconds
    //rfdapi_record_debug_point((session_tick_count_filter > 0.01f) ? (1000.0f/session_tick_count_filter) : 0.0f, "rows_per_second");
#endif
}

static void calculate_sample_rates(uint32_t session_tick_count, const rfdapi_measurement_data_t* data_vector, uint8_t length)
{
    int8_t channels[POSITIONS] = {
        [LOWER] = input_channel_lower(data_vector, length),
        [UPPER] = input_channel_upper(data_vector, length),
    };
    uint8_t position;
    static uint32_t last_gyro_session_tick_count[POSITIONS];
    static float gyro_session_tick_count_filter[POSITIONS];
    static uint32_t last_accel_session_tick_count[POSITIONS];
    static float accel_session_tick_count_filter[POSITIONS];
    static uint32_t last_mag_session_tick_count[POSITIONS];
    static float mag_session_tick_count_filter[POSITIONS];
    for (position = 0; position < POSITIONS; position++) {
        float factor_gyro;
        float expected_gyro = get_expected_gyro_samples_per_second();
        { // gyroscope
            uint32_t delta = session_tick_count - last_gyro_session_tick_count[position]; // milliseconds
            uint8_t changed =
                get_data_changed(data_vector, channels[position], MD_STREAM_GYROSCOPE_X)
                && get_data_changed(data_vector, channels[position], MD_STREAM_GYROSCOPE_Y)
                && get_data_changed(data_vector, channels[position], MD_STREAM_GYROSCOPE_Z);
            float current_estimate = ((gyro_session_tick_count_filter[position] * 4.0f) + (float)delta) / 5.0f; // milliseconds
            if (changed) {
                last_gyro_session_tick_count[position] = session_tick_count;
                gyro_session_tick_count_filter[position] = current_estimate;
            }
            float received_samples_per_second = (current_estimate > 0.01f) ? (1000.0f/current_estimate) : 0.0f;
            //rfdapi_record_debug_point(received_samples_per_second,"%s_gyro_samples_per_second",upper_lower_string(&gi5_algo[position]));
            factor_gyro = expected_gyro - MIN(expected_gyro, received_samples_per_second);
//            rfdapi_record_debug_point(factor_gyro/expected_gyro,"%s_missing_gyro_frac",upper_lower_string(&gi5_algo[position]));
        }
        float factor_accel;
        float expected_accel = get_expected_accel_samples_per_second();
        { // accelerometer
            uint32_t delta = session_tick_count - last_accel_session_tick_count[position]; // milliseconds
            uint8_t changed =
                get_data_changed(data_vector, channels[position], MD_STREAM_ACCELEROMETER_X)
                && get_data_changed(data_vector, channels[position], MD_STREAM_ACCELEROMETER_Y)
                && get_data_changed(data_vector, channels[position], MD_STREAM_ACCELEROMETER_Z);
            float current_estimate = ((accel_session_tick_count_filter[position] * 9.0f) + (float)delta) / 10.0f; // milliseconds
            static const uint32_t max_accel_age_ticks = 250;
            if (changed) {
                last_accel_session_tick_count[position] = session_tick_count;
                accel_session_tick_count_filter[position] = current_estimate;
            } else if (delta > max_accel_age_ticks) {
                gi5_algo[position].flags |= FLAGS_IGNORE_ACCEL;
            }
            float received_samples_per_second = (current_estimate > 0.01f) ? (1000.0f/current_estimate) : 0.0f;
            //rfdapi_record_debug_point(received_samples_per_second,"%s_accel_samples_per_second",upper_lower_string(&gi5_algo[position]));
            factor_accel = expected_accel - MIN(expected_accel, received_samples_per_second);
            //rfdapi_record_debug_point(factor_accel/expected_accel,"%s_missing_accel_frac",upper_lower_string(&gi5_algo[position]));
        }
        float factor_mag;
        float expected_mag = get_expected_mag_samples_per_second();
        { // magnetometer
            uint32_t delta = session_tick_count - last_mag_session_tick_count[position]; // milliseconds
            uint8_t changed =
                get_data_changed(data_vector, channels[position], MD_STREAM_MAGNETOMETER_X)
                && get_data_changed(data_vector, channels[position], MD_STREAM_MAGNETOMETER_Y)
                && get_data_changed(data_vector, channels[position], MD_STREAM_MAGNETOMETER_Z);
            float current_estimate = ((mag_session_tick_count_filter[position] * 9.0f) + (float)delta) / 10.0f; // milliseconds
            static const uint32_t max_mag_age_ticks = 250;
            if (changed) {
                last_mag_session_tick_count[position] = session_tick_count;
                mag_session_tick_count_filter[position] = current_estimate;
            } else if (delta > max_mag_age_ticks) {
                gi5_algo[position].flags |= FLAGS_IGNORE_MAG;
            }
            float received_samples_per_second = (current_estimate > 0.01f) ? (1000.0f/current_estimate) : 0.0f;
            //rfdapi_record_debug_point(received_samples_per_second,"%s_mag_samples_per_second",upper_lower_string(&gi5_algo[position]));
            factor_mag = expected_mag - MIN(expected_mag, received_samples_per_second);
            //rfdapi_record_debug_point(factor_mag/expected_mag,"%s_missing_mag_frac",upper_lower_string(&gi5_algo[position]));
        }
        const float weight_gyro = 3.0f;
        const float weight_accel = 2.0f;
        const float weight_mag = 1.0f;
        gi5_algo[position].confidence_indicator =
            1.0f
            - (weight_gyro * factor_gyro + weight_accel * factor_accel + weight_mag * factor_mag)
              / (weight_gyro * expected_gyro + weight_accel * expected_accel + weight_mag * expected_mag);
        //rfdapi_record_debug_point(gi5_algo[position].confidence_indicator,"%s_confidence_indicator",upper_lower_string(&gi5_algo[position]));
    }
}

static void debug_dip(const algo_mdm_t* lower, const algo_mdm_t* upper)
{
    //rfdapi_record_debug_point(upper->dip_x*R_TO_D, "upper_dip_x_1d");
    //rfdapi_record_debug_point(gmos_math_atan2(upper->scaled_body_accel[Y],upper->scaled_body_accel[Z])*R_TO_D, "upper_dip_y_2d");
    //rfdapi_record_debug_point(upper->scaled_body_accel[X],"upper_scaled_body_accel_x");
    //rfdapi_record_debug_point(upper->scaled_body_accel[Y],"upper_scaled_body_accel_y");
    //rfdapi_record_debug_point(upper->scaled_body_accel[Z],"upper_scaled_body_accel_z");
}

static void debug_mag(algo_mdm_t* lower, algo_mdm_t* upper)
{
    //rfdapi_record_debug_point(lower->mag_xh, "lower_mag_xh");
    //rfdapi_record_debug_point(lower->mag_yh, "lower_mag_yh");
    //rfdapi_record_debug_point(lower->mag_h_magnitude, "lower_mag_h_magnitude");
    //rfdapi_record_debug_point(upper->mag_xh, "upper_mag_xh");
    //rfdapi_record_debug_point(upper->mag_yh, "upper_mag_yh");
    //rfdapi_record_debug_point(upper->mag_h_magnitude, "upper_mag_h_magnitude");
    //rfdapi_record_debug_point(lower->mag_ypr[YAW]*R_TO_D, "lower_mag_yaw");
    //rfdapi_record_debug_point(lower->mag_ypr[PITCH]*R_TO_D, "lower_mag_pitch");
    //rfdapi_record_debug_point(lower->mag_ypr[ROLL]*R_TO_D, "lower_mag_roll");
    //rfdapi_record_debug_point(upper->mag_ypr[YAW]*R_TO_D, "upper_mag_yaw");
    //rfdapi_record_debug_point(upper->mag_ypr[PITCH]*R_TO_D, "upper_mag_pitch");
    //rfdapi_record_debug_point(upper->mag_ypr[ROLL]*R_TO_D, "upper_mag_roll");
    //rfdapi_record_debug_point(gmos_vector3_magnitude(&lower->raw_mag), "mag_norm1");
    //rfdapi_record_debug_point(gmos_vector3_magnitude(&upper->raw_mag), "mag_norm2");
#ifdef __DLL_EXPORTS
    gmos_vector3 lower_mag_hc;
    gmos_vector3 upper_mag_hc;
    gmos_vector3_add(&lower_mag_hc, &lower->raw_mag, &lower->raw_mag_hardiron);
    gmos_vector3_add(&upper_mag_hc, &upper->raw_mag, &upper->raw_mag_hardiron);
    
#ifdef RFD_PA
    rfdapi_record_debug_point(gmos_vector3_magnitude(&lower_mag_hc), "mag_norm1_hc");
    rfdapi_record_debug_point(gmos_vector3_magnitude(&upper_mag_hc), "mag_norm2_hc");
    
#endif
    //rfdapi_record_debug_point(lower_mag_hc[X], "lower_mag_x_hc");
    //rfdapi_record_debug_point(lower_mag_hc[Y], "lower_mag_y_hc");
    //rfdapi_record_debug_point(lower_mag_hc[Z], "lower_mag_z_hc");
    //rfdapi_record_debug_point(upper_mag_hc[X], "upper_mag_x_hc");
    //rfdapi_record_debug_point(upper_mag_hc[Y], "upper_mag_y_hc");
    //rfdapi_record_debug_point(upper_mag_hc[Z], "upper_mag_z_hc");
#endif
}

static void debug_gyro_pre(algo_mdm_t* lower, algo_mdm_t* upper)
{
#ifdef __DLL_EXPORTS
    static gmos_vector3 lower_raw_gyro;
    lower_raw_gyro[0] += lower->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[1] += lower->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    lower_raw_gyro[2] += lower->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
    //rfdapi_record_debug_point(lower_raw_gyro[0], "gyro_pre_x1");
    //rfdapi_record_debug_point(lower_raw_gyro[1], "gyro_pre_y1");
    //rfdapi_record_debug_point(lower_raw_gyro[2], "gyro_pre_z1");
    //rfdapi_record_debug_point(gmos_vector3_magnitude(&lower->gyro_dps), "gyro_pre_norm1");

    static gmos_vector3 upper_raw_gyro;
    upper_raw_gyro[0] += upper->gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[1] += upper->gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
    upper_raw_gyro[2] += upper->gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
    //rfdapi_record_debug_point(upper_raw_gyro[0], "gyro_pre_x2");
    //rfdapi_record_debug_point(upper_raw_gyro[1], "gyro_pre_y2");
    //rfdapi_record_debug_point(upper_raw_gyro[2], "gyro_pre_z2");
    //rfdapi_record_debug_point(gmos_vector3_magnitude(&upper->gyro_dps), "gyro_pre_norm2");

//    rfdapi_record_debug_point(lower->gyro_dps[0], "gyro_pre_x1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[1], "gyro_pre_y1_dps");
//    rfdapi_record_debug_point(lower->gyro_dps[2], "gyro_pre_z1_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[0], "gyro_pre_x2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[1], "gyro_pre_y2_dps");
//    rfdapi_record_debug_point(upper->gyro_dps[2], "gyro_pre_z2_dps");
#endif
}

static void debug_gyro_body(const algo_mdm_t* lower, const algo_mdm_t* upper)
{
#ifdef __DLL_EXPORTS
    static gmos_vector3 lower_raw_gyro;
//    lower_raw_gyro[0] += lower->body_gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
//    lower_raw_gyro[1] += lower->body_gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
//    lower_raw_gyro[2] += lower->body_gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(lower_raw_gyro[0], "gyro_body_x1");
//    rfdapi_record_debug_point(lower_raw_gyro[1], "gyro_body_y1");
//    rfdapi_record_debug_point(lower_raw_gyro[2], "gyro_body_z1");

    static gmos_vector3 upper_raw_gyro;
//    upper_raw_gyro[0] += upper->body_gyro_dps[0] / NOMINAL_ROW_SAMPLE_RATE;
//    upper_raw_gyro[1] += upper->body_gyro_dps[1] / NOMINAL_ROW_SAMPLE_RATE;
//    upper_raw_gyro[2] += upper->body_gyro_dps[2] / NOMINAL_ROW_SAMPLE_RATE;
//    rfdapi_record_debug_point(upper_raw_gyro[0], "gyro_body_x2");
//    rfdapi_record_debug_point(upper_raw_gyro[1], "gyro_body_y2");
//    rfdapi_record_debug_point(upper_raw_gyro[2], "gyro_body_z2");
#endif
}

void gi5_measurement_data_handler(uint32_t session_tick_count, const rfdapi_measurement_data_t* data_vector, uint8_t length)
{
    if (!save_data(data_vector, length)) return;

    //static int fitment_counter = 0;
    //fitment_counter = (fitment_counter+1) % 1000;
    //if (fitment_counter == 0)
    //{
    //    gi5_calculate_fitment_angles();
    //}

    debug_row_rate(session_tick_count);

    algo_mdm_t* lower = &gi5_algo[LOWER];
    algo_mdm_t* upper = &gi5_algo[UPPER];

//    lower->gyro_dps[X] += 1.5;
//    lower->gyro_dps[Y] += 1.5;
//    lower->gyro_dps[Z] += 1.5;
//    upper->gyro_dps[X] += 1.5;
//    upper->gyro_dps[Y] += 1.5;
//    upper->gyro_dps[Z] += 1.5;

    lower->flags &= FLAGS_INIT_GYRO_DRIFT | FLAGS_INIT_XY | FLAGS_INIT_Z | FLAGS_FITMENT | FLAGS_IGNORE_GYRO;
    upper->flags &= FLAGS_INIT_GYRO_DRIFT | FLAGS_INIT_XY | FLAGS_INIT_Z | FLAGS_FITMENT | FLAGS_IGNORE_GYRO;

    check_for_interpolated_gyro(data_vector, length, lower, upper);
    calculate_sample_rates(session_tick_count, data_vector, length);

    bsm_v5_receive_accel(lower);
    bsm_v5_receive_accel(upper);
    debug_dip(lower, upper);

    bsm_v5_receive_gyro(lower, upper);

    bsm_v5_receive_mag(lower);
    bsm_v5_receive_mag(upper);
    debug_mag(lower, upper);

    bsm_v5_update_mdm_positions(lower);
    bsm_v5_update_mdm_positions(upper);

    bsm_v5_update_diff_positions(data_vector, length, lower, upper);
    bsm_v5_check_twist_reset_in_green_zone(lower, upper);

    // hack to export flags:
    app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback_shoulder.output_quaternion_shoulder_right[0] = lower->flags;
    app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback_shoulder.output_quaternion_shoulder_right[1] = upper->flags;
    app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback_shoulder.output_quaternion_shoulder_right[2] = lower->confidence_indicator;
    app_processed_data.app_combination_relative_data.app_combination_relative_data_lowback_shoulder.output_quaternion_shoulder_right[3] = upper->confidence_indicator;

    upper->flags &= FLAGS_INIT_GYRO_DRIFT | FLAGS_INIT_XY | FLAGS_INIT_Z;
    lower->flags &= FLAGS_INIT_GYRO_DRIFT | FLAGS_INIT_XY | FLAGS_INIT_Z;
}

void gi5_reset_all_gyros()
{
    rfdapi_record_debug("gi5_reset_all_gyros");
    gi5_algo[LOWER].flags |= FLAGS_INIT_XY | FLAGS_INIT_Z;
    gi5_algo[UPPER].flags |= FLAGS_INIT_XY | FLAGS_INIT_Z;
}

void gi5_reset_differential_twist()
{
    rfdapi_record_debug("gi5_reset_differential_twist");
    gi5_algo[LOWER].flags |= FLAGS_INIT_Z;
    gi5_algo[UPPER].flags |= FLAGS_INIT_Z;
}

void gi5_algo_clear_magnetometer(algo_mdm_t* mdm)
{
    mdm->raw_mag_low_accumulated[X] = -0.15;
    mdm->raw_mag_low_accumulated[Y] = -0.15;
    mdm->raw_mag_low_accumulated[Z] = -0.15;
    mdm->raw_mag_high_accumulated[X] = 0.15;
    mdm->raw_mag_high_accumulated[Y] = 0.15;
    mdm->raw_mag_high_accumulated[Z] = 0.15;
    mdm->raw_mag_hardiron[X] = 0.0;
    mdm->raw_mag_hardiron[Y] = 0.0;
    mdm->raw_mag_hardiron[Z] = 0.0;
    mdm->raw_mag_scale[X] = 1.0;
    mdm->raw_mag_scale[Y] = 1.0;
    mdm->raw_mag_scale[Z] = 1.0;

    rfdapi_record_debug("gi5_reset_hardiron");
}

void gi5_algorithm_init()
{
    rfdapi_memset(&gi5_algo[0], 0, sizeof(gi5_algo));
    rfdapi_memset(&gi5_posalg, 0, sizeof(gi5_posalg));
    gi5_posalg.config_flags = rfdapi_config_int("Gi.Config.Flags");
    rfdapi_record_debug("gi5_algorithm_init() %u %u %u", (unsigned)gi5_posalg.config_flags, rfdapi_get_system_config(), get_max_unchanged_ignore_gyro());

    uint8_t position;
    for (position = 0; position < POSITIONS; position++) {
        algo_mdm_t* mdm = &gi5_algo[position];
        int accel_scale = rfdapi_config_int(config_fitment_accel[position]);
        mdm->accel_scale = (accel_scale == 0) ? 1.0f : ((float)accel_scale / fitment_angle_scale);
        mdm->fitment_angle_radians[X] = (float)rfdapi_config_int(config_fitment_forward[position]) / fitment_angle_scale;
        mdm->fitment_angle_radians[Y] = (float)rfdapi_config_int(config_fitment_lateral[position]) / fitment_angle_scale;
        mdm->flags = FLAGS_INIT_GYRO_DRIFT | FLAGS_INIT_XY | FLAGS_INIT_Z;
        uint8_t idx;
        for (idx = 0; idx < ACCEL_DEBOUNCE_LENGTH; idx++) {
            mdm->accel_debounce[idx][Z] = 1.0f;
            mdm->accel_debounce_magnitude[idx] = 1.0f;
        }
        mdm->gyro_drift.data_sum_count = 1; // avoid divide by zero before drift init on first drift sample

        gi5_algo_clear_magnetometer(mdm);
    }
    gi5_algo[LOWER].fitment_angle_radians[Z] = (float)rfdapi_config_int(config_fitment_twist) / fitment_angle_scale;
    // fixme: consider periodically saving output of gyro drift filters and any mag data for use on watchdog reset
}
/*
#else //#ifdef USE_GI5_POSITIONAL_ALGORITHM
void gi5_measurement_data_handler(uint32_t session_tick_count, const rfdapi_measurement_data_t* data_vector, uint8_t length)
{
}

void gi5_algo_clear_magnetometer()
{
}

void gi5_calculate_fitment_angles()
{
    rfdapi_record_debug("GI5 positional algorithm disabled.");
}

void gi5_reset_differential_twist()
{
}

void gi5_reset_all_gyros()
{
}*/
#endif //#ifdef USE_GI5_POSITIONAL_ALGORITHM

/* End of file */

