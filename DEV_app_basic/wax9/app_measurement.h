/**
\file app_measurement.h

\brief Measurement UI header file

Copyright 2011 dorsaVi Pty Ltd.  All rights reserved.
*/

#ifndef _APP_MEASUREMENT_H
#define _APP_MEASUREMENT_H
#ifndef NULL
#define NULL 0
#endif

#define APP_MAX_NUM_MDs 4
#define APP_MD_CHANNELS_MASK 0xFF


typedef enum {
	APP_SENSORS_ORDER_DEFAULT = 0 ,
	APP_SENSORS_ORDER_XSENS	
} app_sensors_axes_order_t;

typedef enum { 
	APP_SENSORS_TYPE_ACCELEROMETER = 0 ,
	APP_SENSORS_TYPE_GYROSCOPE ,
	APP_SENSORS_TYPE_MAGNETOMETER 
} app_sensor_type_t;

typedef enum {
	APP_ADJUSTED_ORIENTATION_X = 0, 
	APP_ADJUSTED_ORIENTATION_Y,
	APP_ADJUSTED_ORIENTATION_Z
}app_adjusted_axis_orientation_t; 

typedef enum { 
 APP_BO_STANDING = 0, 
APP_BO_SITTING, 
APP_BO_LYING, 
APP_BO_DYNAMIC, 
APP_BO_UNKNOWN
} app_bo_type_t; 

typedef enum { 
	APP_ALERT_TYPE_NONE = 0,
	APP_ALERT_TYPE_REMINDER, // UI map:
	APP_ALERT_TYPE_END_RANGE,  // UI map:
	APP_ALERT_TYPE_PELVIC_TILT_SITTING, // UI map:
	APP_ALERT_TYPE_SLOUCHED_SITTING, // UI map:
	APP_ALERT_TYPE_STATIC_POSTURE_SITTING,// UI map:
	APP_ALERT_TYPE_STATIC_POSTURE_STANDING, // UI map:
	APP_ALERT_TYPE_UPRIGHT_SITTING, // UI map:
	APP_ALERT_TYPE_PELVIC_TILT_STANDING,// UI map:
	APP_ALERT_TYPE_MAX
} app_alert_type_t; 

typedef enum {
	APP_PA_FORWARD = 0, 
    APP_PA_LATERAL, 
    APP_PA_TWIST,
	APP_PROCESSED_EMG,
	APP_PROCESSED_DATA_TYPES
} app_processed_data_type_t;

typedef struct {
	float lumbar_forward;
	float lumbar_lateral;
	float lumbar_twist;
	float calibrated_quaternion_lumbar[4];
	float output_quaternion_lumbar[4];
} app_combination_lowback_relative_t;

typedef struct {
	float right_forward;
	float right_lateral;
	float right_twist; 
	float left_forward;
	float left_lateral;
	float left_twist; 
	float calibrated_quaternion_shoulder_left[4];
	float calibrated_quaternion_shoulder_right[4];
	float output_quaternion_shoulder_left[4];
	float output_quaternion_shoulder_right[4];
} app_combination_shoulder_relative_t;

typedef struct {
	float lumbar_forward;
	float lumbar_lateral;
	float lumbar_twist; 
	float right_forward;
	float right_lateral;
	float right_twist; 
	float left_forward;
	float left_lateral;
	float left_twist;
	float calibrated_quaternion_lumbar[4];
	float output_quaternion_lumbar[4];
	float calibrated_quaternion_shoulder_left[4];
    float calibrated_quaternion_shoulder_right[4];
    float output_quaternion_shoulder_left[4];
    float output_quaternion_shoulder_right[4];
 } app_combination_back_shoulder_relative_t;
// define other app combinations to hold relative data here

typedef struct {
	/* FIXME: add union for queternion support 
	*/
  float pa_data[APP_MAX_NUM_MDs][APP_PROCESSED_DATA_TYPES];

  //float pa_data[APP_MAX_NUM_MDs][4];
  app_alert_type_t alert_type;
  app_bo_type_t bo_type;  

  union {
	app_combination_lowback_relative_t app_combination_relative_data_lowback;
	app_combination_shoulder_relative_t app_combination_relative_data_shoulder;
	app_combination_back_shoulder_relative_t app_combination_relative_data_lowback_shoulder;
  // addother app combinations to hold relative data here
  }app_combination_relative_data;
} app_processed_data_t;

//extern app_processed_data_t app_processed_data;
extern app_alert_type_t app_current_alert; // holds the value of current alert until it is displayed by UI. 

typedef enum {
	APP_MEASUREMENT_SUBSTATE_UNKNOWN = 0,
	APP_MEASUREMENT_SUBSTATE_CUSTOMIZED_BIOFEEDBACK = 1,
	APP_MEASUREMENT_SUBSTATE_MEASUREMENT_ONLY = 2,
	APP_MEASUREMENT_SUBSTATE_OHS = 3,
	APP_MEASUREMENT_SUBSTATE_GENERIC = 4,
	APP_MEASUREMENT_SUBSTATE_INTERACTIVE = 5,
	APP_MEASUREMENT_SUBSTATE_STREAMING = 6,
	APP_MEASUREMENT_SUBSTATE_DEBUG = 7,
	APP_MEASUREMENT_SUBSTATE_RUNNING_SYMMETRY = 8,
	APP_MEASUREMENT_SUBSTATE_RETURN_TO_PLAY = 9,
    APP_MEASUREMENT_SUBSTATE_INVALID = 10,
	APP_MEASUREMENT_SUBSTATE_TOTAL
} app_measurement_substates_t;

// ui trigger funtions
void app_activate_out_of_range_screen(uint8_t activate);
void app_measurement_config_changed_handler(void);

// substate ui trigger funtions 

void app_activate_monitoring_screen(uint8_t activate);
void app_activate_ohs_screen(uint8_t activate);
void app_activate_generic_screen(uint8_t activate);
void app_activate_interactive_screen(uint8_t activate);

#if defined(RUNNING_LIVE_RFD)
void app_activate_running_symmetry_screen(uint8_t activate);
void app_activate_rtp_screen(uint8_t activate);
#endif 

#if defined(USE_PA5_ALERTS) || defined(USE_GI5_POSITIONAL_ALGORITHM)
void app_activate_debug_screen(uint8_t activate);
void app_activate_biofeedback_screen(uint8_t activate);
#endif

//static void pro_measuring_bsmv4_data_processing(const rfdapi_measurement_data_t* data_vector, uint8_t length);

#endif
