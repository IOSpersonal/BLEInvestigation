/*
 * Copyright (c) 2013-2014, Newcastle University, UK.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
// ViewController.h
// Gavin Wood, 2014

#import <UIKit/UIKit.h>
@import CoreBluetooth;
@import QuartzCore;

@interface ViewController : UIViewController<CBCentralManagerDelegate, CBPeripheralDelegate>{
    //IBOutlet UILabel *displayRSSI0;
    //IBOutlet UILabel *displayThroughput;
    //IBOutlet UILabel *displayDataRates;
}

@property (nonatomic, strong) CBCentralManager          *centralManager;
@property (nonatomic, strong) UITextView                *deviceInfo;
@property (strong, nonatomic) IBOutlet UITextField *monitorTimeTextBox;
@property (strong, nonatomic) IBOutlet UIButton *monitorBtn;

@property (strong, nonatomic) IBOutlet UIButton *recordBtn;
@property (strong, nonatomic) IBOutlet UIButton *finishRecordBtn;
@property (strong, nonatomic) IBOutlet UIButton *lockDeviceBtn;
@property (strong, nonatomic) IBOutlet UIButton *unlockDeviceBtn;
@property (strong, nonatomic) IBOutlet UIButton *startStreamingBtn;
@property (strong, nonatomic) IBOutlet UIButton *stopStreamingBtn;

@property (nonatomic, strong) IBOutlet UILabel          *magnetometer;
@property (nonatomic, strong) IBOutlet UILabel          *accelerometer;
@property (nonatomic, strong) IBOutlet UILabel          *gyroscope;

@property (nonatomic, strong) IBOutlet UILabel          *RSSI;
@property (nonatomic, strong) IBOutlet UILabel          *throughput;
@property (nonatomic, strong) IBOutlet UILabel          *dataPackets;
@property (nonatomic, strong) IBOutlet UILabel          *dataRates;

@property (nonatomic, strong) IBOutlet UILabel          *battery;

@property (nonatomic, strong) IBOutlet UILabel          *device;

@property (nonatomic, strong) IBOutlet UILabel          *status;

@property (nonatomic, strong) IBOutlet UILabel          *deviceStatus;

@property (strong, nonatomic) IBOutlet UILabel          *device1;
@property (strong, nonatomic) IBOutlet UILabel          *device2;
@property (strong, nonatomic) IBOutlet UILabel          *device3;
@property (strong, nonatomic) IBOutlet UILabel          *device4;
@property (strong, nonatomic) IBOutlet UIButton *setMonitorTimeBtn;
- (IBAction)setMonitorTime:(id)sender;

- (IBAction)startMonitoring:(id)sender;
-(IBAction) flush:(id)sender;
-(IBAction) startRecording: (id) sender;
-(IBAction) endRecording: (id) sender;
-(IBAction) lockDevices:(id)sender;
-(IBAction) unlockDevices:(id)sender;
-(IBAction) startStreaming:(id)sender;
-(IBAction) stopStreaming:(id)sender;
-(bool) checkMonitoringTime:(NSString*)str;



// Instance method to perform heart beat animations

@end

