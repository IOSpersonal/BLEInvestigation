/**
\file data_streams.h

\brief Shared config header for PRO BSM data stream definitions

Copyright 2012 Grey Innovation Pty Ltd. All rights reserved.

*/

#ifndef __DATA_STREAMS_H
#define __DATA_STREAMS_H


#define DATASYNC_MAX_STREAM 60
#define RFD


//R.082 "potentially" - accommodate the same accelerometer at different bit depths/rates by adding streams and datatypes below
enum md_wireless_stream_id {
    MD_STREAM_BATTERY_CHARGE, // %
    MD_STREAM_BATTERY_VOLTAGE, // mV
    MD_STREAM_TEMPERATURE_C,
#if defined(MD_M) || defined(RFD) // fixme: RFD code assumes these are the same as MD_M code to support MDM flash recording/offload
    MD_STREAM_ACCELEROMETER_X,
    MD_STREAM_ACCELEROMETER_Y,
    MD_STREAM_ACCELEROMETER_Z,
    MD_STREAM_MAGNETOMETER_X,
    MD_STREAM_MAGNETOMETER_Y,
    MD_STREAM_MAGNETOMETER_Z,
    MD_STREAM_GYROSCOPE_X,
    MD_STREAM_GYROSCOPE_Y,
    MD_STREAM_GYROSCOPE_Z,
    MD_STREAM_LEGACY_ACCELEROMETER_X,
    MD_STREAM_LEGACY_ACCELEROMETER_Y,
    MD_STREAM_LEGACY_ACCELEROMETER_Z,
#endif
#if defined(MD_E) || defined(RFD)
    MD_STREAM_EMG_ENVELOPED,
    MD_STREAM_EMG_RAW,	
#endif
	MD_STREAM_MD_DOCK,
    MD_STREAM_NUM,
};

#endif

/* End of file. */
