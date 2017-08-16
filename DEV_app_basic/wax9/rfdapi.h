/**
\file rfdapi.h

\brief Header file for RFD system firmware API

Copyright 2011 Grey Innovation Pty Ltd. All rights reserved.

*/

#ifndef _RFD_API_H
#define _RFD_API_H

#include <stdint.h>

#ifdef RFD_PA

#include "../shared/data_streams.h"
#include <gmos_assert.h>
#ifndef __SYSTEM_CONFIG_CS__
    #define public
    #include "../shared/system_config.cs"
    #undef public
    #define __SYSTEM_CONFIG_CS__
#endif

#endif

#define PACKED  __attribute__ ((__packed__))

#ifndef NULL
    #define NULL 0
#endif

/*
 * Initialisation:
 *
 * app_init() is called on startup and should be used to register callbacks.
 */


/*
 * rfdapi_config_get_binary_data - find config item containing binary data (image, audio)
 * Inputs:
 *  key        : string key to search for
 * Outputs:
 *  config_data: pointer to config item
 */
typedef struct {
    const uint8_t* data;
    uint32_t length;
} rfdapi_config_data_t;

void rfdapi_config_get_binary_data(const char* key, rfdapi_config_data_t* config_data);

/*
 * rfdapi_config_int - read config value of a given key
 * Inputs:
 *  key     : string key to search for
 * Return:
 *  config integer value
 */
int rfdapi_config_int(const char* key);

/*
 * rfdapi_config_set_int - set config value of a given key, in RAM (non-persistent)
 * Inputs:
 *  key     : string key to search for
 *  value   : integer value to set
 */
void rfdapi_config_set_int(const char* key, int value);

/*
 * rfdapi_config_internal_persist - updates the key's value in flash with the
 *                                  current key's value from RAM.
 *  key      : string key to persist to flash.  set to NULL to persist entire
 *             configuration map into internal flash.
 * Outputs:
 *  success : 0 - write to internal flash failed
 *            1 - write to internal flash passed
 */
uint8_t rfdapi_config_internal_persist(const char* key);

/*
 * rfdapi_register_on_config_changed - register callback function to be executed
 *                                     when a configuration item is changed by the
 *                                     PC interface.  Note: can be chained.
 * Inputs:
 *  config_callback_fn : user defined function, called when configuration changed
 *
 * Note:
 *  An assert will trigger if the chain is broken.
 *  Callback function should be defined as follows:
 *
 *  rfdapi_config_changed_callbackfn_t prev_config_callbackfn =
 *                                  rfdapi_register_on_config_changed(config_cbk);
 *
 *  static void config_cbk(void)
 *  {
 *      // handle configuration update here...
 *
 *      // chain next callback
 *      if (prev_config_callbackfn != NULL) {
 *          prev_config_callbackfn();
 *      }
 *  }
 */
typedef void (*rfdapi_config_changed_callbackfn_t)(void);

rfdapi_config_changed_callbackfn_t rfdapi_register_on_config_changed(
                                rfdapi_config_changed_callbackfn_t config_callback_fn);

/*
 * rfdapi_lcd_backlight - soft ramp the backlight between the on and off states
 * Inputs: 
 *  on: 1 for on, 0 for off.
 */
void rfdapi_lcd_backlight(uint8_t on);


/*
 * rfdapi_audio_beep - provide beep through buzzer
 * Inputs:
 *  mode       : off, 2.7kHz, 2.9kHz, 3.1kHz
 *  duration_ms: beep duration (in milliseconds)
 */
typedef enum {
    RFDAPI_BEEP_OFF    = 0,
    RFDAPI_BEEP_2_7KHZ = 1,
    RFDAPI_BEEP_2_9KHZ = 2,
    RFDAPI_BEEP_3_1KHZ = 3
} rfdapi_beep_mode_t;
void rfdapi_audio_beep(rfdapi_beep_mode_t mode, uint32_t duration_ms);


/*
 * rfdapi_audio_play - play an ADPCM file (stored in flash) through buzzer
 * Inputs:
 *  config_data : the pointer returned by rfdapi_config_get(<adpcm_filename>, )
 */
void rfdapi_audio_play(const rfdapi_config_data_t* const config_data);

/*
 * rfdapi_vibrate - provide vibration motor control
 * Inputs:
 *  repeat_count : number of repeats (with 1/4 sec off between each)
 *  duration_ms  : motor on period (in milliseconds)
 */
void rfdapi_vibrate(uint8_t repeat_count, uint32_t on_duration_ms);

/*
 * rfdapi_register_on_button_press - register callback function to be executed
 *                                  on any button press.  Note: can be chained.
 * Inputs:
 *  button_callback_fn : user defined function, called when button pressed
 *
 * Note:
 *  An assert will trigger if chain is broken.
 *  Callback function should be defined as follows:
 *
 *  rfdapi_button_callbackfn_t prev_callbackfn =
 *                                  rfdapi_register_on_button_press(my_cbk1);
 *
 *  void my_cbk1(gmos_event_t button_event)
 *  {
 *    // handle button press here...
 *
 *    // chain next callback
 *    if (prev_callbackfn != NULL) {
 *      prev_callbackfn(button_event);
 *    }
 *  }
 */
typedef enum {
    RFDAPI_BUTTON_YES   = 0,
    RFDAPI_BUTTON_NO    = 1,
    RFDAPI_BUTTON_MODE  = 2,
    RFDAPI_BUTTON_EVENT = 3
} rfdapi_button_t;

typedef void (*rfdapi_button_callbackfn_t)(rfdapi_button_t button_event);

rfdapi_button_callbackfn_t rfdapi_register_on_button_press(
                                rfdapi_button_callbackfn_t button_callback_fn);

/*
 * rfdapi_register_on_ui_timer - register callback function to be executed
 *                               on ui refresh timer.  Note: can be chained.
 * Inputs:
 *  ui_timer_callback_fn : user defined function, called every ui timer tick
 *  
 * Note:
 *  An assert will trigger if chain is broken.
 *  Callback function should be defined as follows:
 *
 *  rfdapi_ui_timer_callbackfn_t prev_callbackfn =
 *                                  rfdapi_register_on_ui_timer(my_cbk1);
 *
 *  void my_cbk1(gmos_event_t button_event)
 *  {
 *    // handle ui timer tick here...
 *
 *    // chain next callback
 *    if (prev_callbackfn != NULL) {
 *      prev_callbackfn(button_event);
 *    }
 *  }
 */
typedef void (*rfdapi_ui_timer_callbackfn_t)();

rfdapi_ui_timer_callbackfn_t rfdapi_register_on_ui_timer(
                                rfdapi_ui_timer_callbackfn_t ui_timer_callback_fn);


/*
 * rfdapi_register_on_data_received - register callback function to be executed
 *                               when data received.  Note: can be chained.
 * Inputs:
 *  ui_data_callback_fn : user defined function, called every time a data row
 *                        is received
 *  
 * Note:
 *  An assert will trigger if chain is broken.
 *  Callback function should be defined as follows:
 *
 *  rfdapi_data_callbackfn_t prev_callbackfn =
 *                                  rfdapi_register_on_data_received(my_cbk2);
 *
 *  void my_cbk2(const int16_t* data_vector)
 *  {
 *    // process data vector here...
 *
 *    // chain next callback
 *    if (prev_callbackfn != NULL) {
 *      prev_callbackfn(data_vector);
 *    }
 *  }
 */

typedef struct rfdapi_measurement_data {
    const int32_t* data;
    const float* data_scales;
    const uint32_t* data_changed_bits;
    const uint32_t* interpolated_bits;
    int8_t data_index[MD_STREAM_NUM]; // int8_t[md_wireless_stream_id] (rfd_channel_wireless_stream_to_datasync_stream[ch])
} rfdapi_measurement_data_t;
//Note: rfdapi_sensor_type_t has become md_wireless_stream_id
typedef void (*rfdapi_data_received_callbackfn_t)(uint32_t session_tick_count, const rfdapi_measurement_data_t* data_vector, uint8_t length);

rfdapi_data_received_callbackfn_t rfdapi_register_on_data_received(
                                rfdapi_data_received_callbackfn_t data_callback_fn);


/*
 * rfdapi_set_md_led - set the LED flash cadence on a paired MDv5
 * Inputs:
 *  channel   : MD wireless channel number
 *  led_state : one of the predefined LED states
 */
typedef enum {
    RFDAPI_MD_LED_OFF   = 0,
    RFDAPI_MD_LED_ON    = 1,
    RFDAPI_MD_LED_FLASH = 2,
    RFDAPI_MD_LED_BLIP  = 3
} rfdapi_md_led_state_t;

void rfdapi_set_md_led(uint8_t channel, rfdapi_md_led_state_t led_state);

/*
 * rfdapi_set_md_emg_gain - set the EMG gain on a paired MDEv5
 * Inputs:
 *  channel   : MD wireless channel number
 *  gain      : MD-E analogue front-end gain setting (0 to 127)
 */
void rfdapi_set_md_emg_gain(uint8_t channel, uint8_t gain);

/*
 * rfdapi_get_md_upgraded_flag - return 1 if all MDs firmware are upgraded
 */
uint8_t rfdapi_get_md_upgraded_flag(void);

/*
 * rfdapi_get_md_connected_flag - return 1 if all MDs are connected
 */
uint8_t rfdapi_get_md_connected_flag(void);

/*
 * rfdapi_get_system_config - get the system configuration
 */
enum system_config_id rfdapi_get_system_config(void);

/*
 * rfdapi_get_rfd_state - get rfd wireless mode
 */
typedef enum {
    RFDAPI_WIRELESS_OPERATING_MODE_INVALID = 0, // 0
    RFDAPI_WIRELESS_FIRMWARE_UPGRADE, // 1
    RFDAPI_WIRELESS_OPERATING, // 2
    RFDAPI_WIRELESS_NOT_CONFIGURED, // 3
    RFDAPI_WIRELESS_OPERATING_REPROGRAM, // 4
    RFDAPI_WIRELESS_OPERATING_MODE_NUM // 5
} rfdapi_wireless_operating_mode_t;
rfdapi_wireless_operating_mode_t rfdapi_get_rfd_state(void);

/*
 * rfdapi_unpair - unpair current set of MDs
 */
void rfdapi_unpair(void);

/*
 * rfdapi_register_on_battery_status - register callback function to be executed
 *                                     when battery status changes by a
 *                                     reasonable amount.  Note: can be chained.
 * Inputs:
 *  battery_status_callback_fn : user defined function, called when battery
 *                               state changes.
 *
 * Note:
 *  An assert will trigger if chain is broken.
 *  Callback function should be defined as follows:
 *
 *  rfdapi_battery_status_callbackfn_t prev_callbackfn =
 *                                  rfdapi_register_on_battery_status(my_cbk1);
 *
 *  void my_cbk1(const rfdapi_rfd_battery_status_t* battery_status)
 *  {
 *    // handle status update here...
 *
 *    // chain next callback
 *    if (prev_callbackfn != NULL) {
 *      prev_callbackfn(battery_status);
 *    }
 *  }
 */
typedef enum {
    RFDAPI_BATTERY_DISCHARGING  = 0,
    RFDAPI_BATTERY_CHARGING     = 1,
    RFDAPI_BATTERY_FULL         = 2,
    RFDAPI_BATTERY_LOW          = 3
} rfdapi_battery_state_t;

typedef struct {
    rfdapi_battery_state_t battery_state;   // one of rfdapi_battery_state_t
    uint8_t charge_percentage;              // percent of fully charged
} rfdapi_rfd_battery_status_t;

typedef void (*rfdapi_battery_status_callbackfn_t)(
                            const rfdapi_rfd_battery_status_t* battery_status);

rfdapi_battery_status_callbackfn_t rfdapi_register_on_battery_status(
                rfdapi_battery_status_callbackfn_t battery_status_callback_fn);


/*
 * rfdapi_register_on_usb_status - register callback function to be executed
 *                                 when usb status changes.
 *                                 Note: can be chained.
 * Inputs:
 *  usb_status_callback_fn : user defined function, called when USB
 *                           state changes.
 *
 * Note:
 *  An assert will trigger if chain is broken.
 *  Callback function should be defined as follows:
 *
 *  rfdapi_usb_status_callbackfn_t prev_callbackfn =
 *                                  rfdapi_register_on_usb_status(my_cbk1);
 *
 *  void my_cbk1(rfdapi_usb_state_t usb_state)
 *  {
 *    // handle status update here...
 *
 *    // chain next callback
 *    if (prev_callbackfn != NULL) {
 *      prev_callbackfn(usb_state);
 *    }
 *  }
 */
typedef enum {
    RFDAPI_USB_DISCONNECTED     = 0x00,
    RFDAPI_USB_HAS_POWER        = 0x01,
    RFDAPI_USB_IS_ENUMERATED    = 0x02,
    RFDAPI_USB_COMMUNICATING    = 0x04,
    RFDAPI_USB_UNKNOWN          = 0x80
} rfdapi_usb_state_t;

typedef void (*rfdapi_usb_status_callbackfn_t)(rfdapi_usb_state_t usb_state);

rfdapi_usb_status_callbackfn_t rfdapi_register_on_usb_status(
                    rfdapi_usb_status_callbackfn_t usb_status_callback_fn);


/*
 * rfdapi_register_on_md_status - register callback function to be executed
 *                                when MD reports its status.
 *                                Note: can be chained.
 * Inputs:
 *  md_status_callback_fn : user defined function, called when an MD reports
 *                          its status.
 *
 * Note:
 *  An assert will trigger if chain is broken.
 *  Callback function should be defined as follows:
 *
 *  rfdapi_md_status_callbackfn_t prev_callbackfn =
 *                                      rfdapi_register_on_md_status(my_cbk1);
 *
 *  void my_cbk1(const rfdapi_md_status_t* md_status)
 *  {
 *    // handle status update here...
 *
 *    // chain next callback
 *    if (prev_callbackfn != NULL) {
 *      prev_callbackfn(md_status);
 *    }
 *  }
 */
typedef enum {
    RFDAPI_MD_STATE_UNUSED = 0x00,
    RFDAPI_MD_STATE_DISCONNECTED = 0x01,
    RFDAPI_MD_STATE_PAIRING = 0x02,
    RFDAPI_MD_STATE_PROGRAMMING = 0x03,
    RFDAPI_MD_STATE_PROGRAMMED = 0x04,
    RFDAPI_MD_STATE_CONNECTED = 0x05
} rfdapi_md_connection_state_t;

typedef enum {
	RFDAPI_MD_DOCK_OUT = 0x00,
	RFDAPI_MD_DOCK_IN = 0x01,	 
}
rfdapi_md_dock_state_t;

typedef struct {
    uint8_t channel;                    // MD wireless channel number
    rfdapi_md_connection_state_t state; // one of the predefined connection states
    rfdapi_md_led_state_t led_state;    // one of the predefined LED states
    uint8_t emg_gain;                   // electromyography gain
    uint16_t flash_highwater;           // MDM flash highwater mark
    uint8_t flash_recording;            // MDM flash recording enabled
    uint8_t battery_charge_percentage;  // MD's battery %
    uint8_t firmware_percentage_complete; //firmware upgrade % completion
	rfdapi_md_dock_state_t md_dock_state; //firmware upgrade % completion
} rfdapi_md_status_t;

typedef void (*rfdapi_md_status_callbackfn_t)(
                                        const rfdapi_md_status_t* md_status);

rfdapi_md_status_callbackfn_t rfdapi_register_on_md_status(
                    rfdapi_md_status_callbackfn_t md_status_callback_fn);


/*
 * rfdapi_set_sprite_chain - set head of sprite chain
 * Inputs:
 *  head : first (i.e. backmost) sprite with links to the other sprites.
 *
 * Note:
 *  The LCD will only be updated when the device is in the Idle state, and
 *  only if a linked sprite has been marked as ready (via rfdapi_sprite_ready).
 *
 *  Example usage is as follows:
 *
 *  static rfdapi_sprite_t background = {
 *      .x = 0, .y = 0, .visible = 1, .dirty = 1,
 *      .type = RFDAPI_SPRITE_TYPE_FILL,
 *      .data.fill = {
 *          .width = RFDAPI_LCD_WIDTH,
 *          .height = RFDAPI_LCD_HEIGHT,
 *          .colour = { .red = 0xff, .green = 0xee, .blue = 0xdd }
 *      },
 *      .next = NULL
 *  };
 *
 *  static rfdapi_sprite_t my_text = {
 *      .x = 10, .y = 110, .visible = 1, .dirty = 1,
 *      .type = RFDAPI_SPRITE_TYPE_TEXT,
 *      .data.text = {
 *          .font = RFDAPI_SPRITE_FONT_LARGE,
 *          .bg_colour = { .red = 0x01, .green = 0x02, .blue = 0x03 },
 *          .fg_colour = { .red = 0xF1, .green = 0xF2, .blue = 0xF3 },
 *          .string = "hello world"
 *      },
 *      .next = NULL
 *  };
 *
 *  // configure sprite chain
 *  background.next = &my_text;
 *  rfdapi_set_sprite_chain(&background);
 *
 *  // at a future point in time, move text to new position
 *  my_text.x = 40;
 *  rfdapi_sprite_ready(&my_text);  // indicate to redraw this sprite
 *
 *  // at a future point in time, change background colour
 *  background.data.fill.colour.green = 0x00;
 *  rfdapi_sprite_ready(&background);   // indicate to redraw this sprite
 */
#define RFDAPI_LCD_WIDTH    128
#define RFDAPI_LCD_HEIGHT   160

typedef enum {
    RFDAPI_SPRITE_TYPE_FILL     = 1,
    RFDAPI_SPRITE_TYPE_TEXT     = 2,
    RFDAPI_SPRITE_TYPE_IMAGE    = 3
} PACKED rfdapi_sprite_type_t;

typedef enum {
    RFDAPI_SPRITE_FONT_SMALL    = 8,    // 5x8  font
    RFDAPI_SPRITE_FONT_LARGE    = 16    //  x16 font (variable width)
} PACKED rfdapi_sprite_font_t;

/* some predefined colours */
#define COLOUR_BLACK    { 0x00,0x00,0x00 }
#define COLOUR_WHITE    { 0xFF,0xFF,0xFF }
#define COLOUR_GREY     { 0xDF,0xDF,0xDF }
#define COLOUR_RED      { 0xFF,0x00,0x00 }
#define COLOUR_GREEN    { 0x00,0xFF,0x00 }
#define COLOUR_BLUE     { 0x00,0x00,0xFF }
#define COLOUR_CYAN     { 0x00,0xFF,0xFF }
#define COLOUR_YELLOW   { 0xFF,0xFF,0x00 }
#define COLOUR_MAGENTA  { 0xFF,0x00,0xFF }
#define COLOUR_PURPLE   { 0x80,0x00,0x80 }
#define COLOUR_ORANGE   { 0xFF,0x80,0x00 }
#define COLOUR_PINK     { 0xFF,0xC0,0xCB }
#define COLOUR_BROWN    { 0x98,0x3C,0x30 }

#define rfdapi_set_colour(destination, colour) {  \
    rfdapi_colour_t col = colour; \
    destination.red = col.red; \
    destination.green = col.green; \
    destination.blue = col.blue; \
}
typedef struct {
    uint8_t red;    // 0-255, but only 5 MSBs are used by LCD
    uint8_t green;  // 0-255, but only 6 MSBs are used by LCD
    uint8_t blue;   // 0-255, but only 5 MSBs are used by LCD
} PACKED rfdapi_colour_t;


typedef struct {
    uint8_t old_x;      // 0 to RFDAPI_LCD_WIDTH - 1
    uint8_t old_y;      // 0 to RFDAPI_LCD_HEIGHT - 1
    uint8_t old_width;  // (0=invisible) window width in pixels
    uint8_t old_height; // (0=invisible) window height in pixels
    const uint8_t *old_image;
} rfdapi_sprite_priv_t; // not for user access

/* Note: most fields are word-aligned ordered to avoid requiring PACKED */
typedef struct rfdapi_sprite {
    struct rfdapi_sprite* next; // next higher layered sprite to display
    rfdapi_sprite_priv_t priv;  // to be maintained by the Display Manager

    uint8_t x;                  // 0 to RFDAPI_LCD_WIDTH - 1
    uint8_t y;                  // 0 to RFDAPI_LCD_HEIGHT - 1
    uint8_t visible;            // 0: sprite disabled, 1: enabled
    rfdapi_sprite_type_t type;  // one of RFDAPI_SPRITE_TYPE_XXX

    union {

        /* applicable for type RFDAPI_SPRITE_TYPE_IMAGE */
        const uint8_t* image;   // the image data, including it's dimensions

        /* applicable for type RFDAPI_SPRITE_TYPE_FILL */
        struct {
            uint8_t width;  // window width in pixels (1 to RFDAPI_LCD_WIDTH-x)
            uint8_t height; // window height in pixels
            rfdapi_colour_t colour;
        } fill;

        /* applicable for type RFDAPI_SPRITE_TYPE_TEXT */
        struct {
            const char* string;
            rfdapi_colour_t bg_colour;  // RGB for font background
            rfdapi_sprite_font_t font;  // one of RFDAPI_SPRITE_FONT_XXX
            rfdapi_colour_t fg_colour;  // RGB for font foreground
            // 1 byte padding
        } text;

    } data; // identified by type

    uint8_t dirty;              // 0: sprite unchanged, 1: sprite changed
    // 3 bytes padding
} rfdapi_sprite_t;

void rfdapi_set_sprite_chain(rfdapi_sprite_t* const head);

/* rfdapi_refresh_page - Force refresh of entire page */
void rfdapi_refresh_page(void);

/*
 * rfdapi_sprite_ready - mark the given sprite as 'dirty', i.e. so that
 *                       the Display Manager knows it needs to redisplay it.
 * Inputs:
 *  sprite : the sprite which has been updated
 *
 */
void rfdapi_sprite_ready(rfdapi_sprite_t* sprite);

/*
 * rfdapi_record_data_columns - set the column titles for recording
 * Inputs:
 *  titles: comma-separated list of column titles (no trailing comma)
 *  scales: multiplier to apply to int16_t data (per column)
 *  length: total columns
 */
void rfdapi_record_data_columns(const char* titles, float* scales, uint8_t length);

/*
 * rfdapi_record_data - record a data row, based on the columns set earlier
 * Inputs:
 *  data    : pointer to the row of data
 *  length  : total columns
 */
void rfdapi_record_data(const int32_t* data, uint8_t length);

/*
 * rfdapi_stream_data_columns - set the column titles for streaming to PC
 * Inputs:
 *  titles: comma-separated list of column titles (no trailing comma)
 *  scales: multiplier to apply to int16_t data (per column)
 *  length: total columns
 */
void rfdapi_stream_data_columns(const char* titles, float* scales, uint8_t length);

/*
 * rfdapi_stream_data - stream a data row to the PC
 * Inputs:
 *  data    : pointer to the row of data
 *  length  : total columns
 */
void rfdapi_stream_data(const int32_t* data, uint8_t length);

/*
 * rfdapi_record_event - record an event (i.e. an immediate alarm)
 * Inputs:
 *  event_string    : a string indicating occurred event
 */
void rfdapi_record_event(char* event_string);

/*
 * rfdapi_record_debug_point - record a data point for devtest
 * Inputs:
 *  value    : data point
 *  format   : description and additional format string
 */
#ifdef __DLL_EXPORTS
void rfdapi_record_debug_point(float value, const char* format, ...);
#else
#define rfdapi_record_debug_point(value, formmat, ...)
#endif

/*
 * rfdapi_record_debug - record a debug string
 * Inputs:
 *  string    : free-form text
 */
void rfdapi_record_debug(const char* format, ...);

/*
 * rfdapi_assert - assert that predicate is true
 * Inputs:
 *   predicate : halt programme if zero
 */
#define rfdapi_assert(predicate) assert(predicate)

/*
 * rfdapi string manipulation functions
 */
uint16_t rfdapi_snprintf(char* buf, uint16_t n, const char* format, ...);
int rfdapi_strcmp(const char *s1, const char *s2);
void* rfdapi_memset(void* t, int c, uint16_t n);
void* rfdapi_memcpy(void* to, const void* from, uint16_t n);

/*
 * rfdapi math functions
 */
#define RFDAPI_MATH_PI 3.14159265358979323846f
float rfdapi_math_floor(float x);
float rfdapi_math_ceil(float x);
int   rfdapi_math_sign(float x);
float rfdapi_math_abs(float x);
float rfdapi_math_sqrt(float x);
float rfdapi_math_atan(float x);
float rfdapi_math_asin(float x);
float rfdapi_math_acos(float x);
float rfdapi_math_tan(float x);
float rfdapi_math_sin(float x);
float rfdapi_math_cos(float x);
float rfdapi_math_expf(float x);
float rfdapi_math_powf(float x, float y);
float rfdapi_math_atan2f(float x, float y);
float rfdapi_math_log(float x);
float rfdapi_math_fmod(float x, float y);
#endif  /* _RFD_API_H */

/* End of file. */

