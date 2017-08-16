/**
\file gi5_positional_algorithm.h

\brief Grey Innovation BSMv5 Positional Algorithm header

\note Define USE_GI5_POSITIONAL_ALGORITHM in order to use these functions, otherwise they have no effect.

Copyright 2012 Grey Innovation Pty Ltd. All rights reserved.

*/

#ifndef _GI5_POS_ALGO_H_
#define _GI5_POS_ALGO_H_

#include <stdint.h>
#include "app_measurement.h"
//#include "rfdapi.h"

/* Initialisation. */
void gi5_algorithm_init(void);

/* Zero differential twist. */
void gi5_reset_differential_twist(void);

/* Reset positional filters and outputs. */
void gi5_reset_all_gyros(void);

/* Fitment angle calculation.  Call at least once when subject is in the fitment position. */
void gi5_calculate_fitment_angles(void);

/* Receive measurement data.
   Register with rfdapi_register_on_data_received() or call on every measurement callback from rfdapi. */
void gi5_measurement_data_handler(uint32_t session_tick_count, const rfdapi_measurement_data_t* data_vector, uint8_t length);

/* Get the input channels used for lower/upper. */
void gi5_get_mdm_input_channels(const rfdapi_measurement_data_t* data_vector, int8_t length, int8_t* lower_channel, int8_t* upper_channel);

/* Get the output channels used for lower/upper. */
void gi5_get_mdm_output_channels(const rfdapi_measurement_data_t* data_vector, int8_t length, int8_t* lower_channel, int8_t* upper_channel);

/* Algorithm results are placed here. */
//extern app_processed_data_t app_processed_data;

#endif

/* End of file. */
