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
// ViewController.m
// Gavin Wood, 2014

// http://stackoverflow.com/questions/19928623/read-data-from-ble-device

#import "ViewController.h"

@interface ViewController ()
@end

@interface NSString (NSStringHexToBytes)
-(NSData*) hexToBytes ;
@end

@implementation NSString (NSStringHexToBytes)
-(NSData*) hexToBytes {
    const char *chars = [self UTF8String];
    int i = 0, len = self.length;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte;
    
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    
    return data;
}
@end

@implementation ViewController

// HRTZ1000 UUIDs
// Services
#define HRTZ1000_DEVICE_INFO_UUID                @"180A"
#define HRTZ1000_HEART_RATE_UUID                 @"180D"
//23/11/2016 new version heart rate UUID under Device Config
#define HRTZ1000_DEVICE_CONFIG_UUID              @"00000005-0008-A8BA-E311-F48C90364D99"

//Characteristics
#define HRTZ1000_UUID_DI_MANUFACTURER_NAME	     @"2A29"
#define HRTZ1000_UUID_DI_MODEL_NUMBER            @"2A24"
#define HRTZ1000_UUID_DI_SERIAL_NUMBER           @"2A25" //NOT USED
#define HRTZ1000_UUID_DI_HARDWARE_REVISION       @"2A27" //NOT USED
#define HRTZ1000_UUID_DI_FIRMWARE_REVISION       @"2A26"
#define HRTZ1000_UUID_DI_SOFTWARE_REVISION       @"2A28"

#define HRTZ1000_UUID_HR_MEASUREMENTS            @"2A37" // Via Notify Byte
#define HRTZ1000_UUID_HR_MEASUREMENTS_NEW        @"00000010-0008-A8BA-E311-F48C90364D99" // Via Notify Byte

#define HRTZ1000_UUID_HR_BODY_SENSOR_LOCATION    @"2A38" // 03 = Finger (Via Notify Byte)
#define HRTZ1000_UUID_HR_CONTROL_POINT           @"2A39" // Doesn't work with "Notify" or "WriteNR" - Check FW
#define HRTZ1000_SESSIONID_UUID                  @"0000000C-0008-A8BA-E311-F48C90364D99"
#define HRTZ1000_START_STREAMING_UUID            @"00000006-0008-A8BA-E311-F48C90364D99"
#define HRTZ1000_SAMPLERATE_UUID                 @"0000000A-0008-A8BA-E311-F48C90364D99"

const int MaxDevicesToPair = 4;
//the boolean that tells if found an existing device from list
bool isAlreadyConnected=false;
//the boolean that tells if the device list is full, if true the app will not connect to new devices
bool deviceListFull=false;
//indexBegin increases when new connections are established
int indexBegin=0;
//const int MaxDevicesToPair = 2;
//NSString *devices[MaxDevicesToPair] = {@"HRTZ1000-07", @"HRTZ1000-47"};
NSString *devices[MaxDevicesToPair] = { };
//NSString *devices[MaxDevicesToPair] = { @"MDM-01", @"MDM-03" };
//NSString *devices[MaxDevicesToPair] = { @"HRTZ1000-47", @"HRTZ1000-43" };
//NSString *devices[MaxDevicesToPair] = { @"WAX9-CA9F", @"HRTZ1000-43" };

bool ConnectionLost[4]={false,false,false,false};
NSTimer *timerMDM1;
NSTimer *timerMDM2;
NSTimer *timerMDM3;
NSTimer *timerMDM4;
CBPeripheral* peripheralMDM1;
CBPeripheral* peripheralMDM2;
CBPeripheral* peripheralMDM3;
CBPeripheral* peripheralMDM4;

NSMutableDictionary *peripheralDictionary;
NSMutableDictionary *indexDictionary;
float mag[MaxDevicesToPair][3];
float acc[MaxDevicesToPair][3];
float rot[MaxDevicesToPair][3];
float rss[MaxDevicesToPair];
short counter[MaxDevicesToPair];

int bytesReceived = 0;
bool isRecording = false;
bool isLocked = false;
bool isStreaming = false;
#define OUTPUT_BUFFER 40
static int counterFS[MaxDevicesToPair];
int fsFilt[MaxDevicesToPair]; int dataRates[MaxDevicesToPair];
float packetLoss[MaxDevicesToPair]; int tempCounter[MaxDevicesToPair];
double filterFS[OUTPUT_BUFFER][MaxDevicesToPair];
double filterCounter[OUTPUT_BUFFER][MaxDevicesToPair];


double tempFS[MaxDevicesToPair];

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //private/var/folders/vg/2hltpvqj4_932fmp3mb_myzc0000gp/T/temp.zKEJCc/WAX9WAX9-DF96.txt/ Setup
    _status.text = @"Waiting on name";
    _gyroscope.text = @"gx,gy,gz";
    _magnetometer.text = @"mx,my,mz";
    _accelerometer.text = @"ax,ay,az";
    _RSSI.text = @"RSSI";
    _device.text = [[[devices[0] stringByAppendingString:devices[1]] stringByAppendingString:devices[2]] stringByAppendingString:devices[3]];
    _throughput.text = @"thru";
    _dataRates.text = @"kbytes/s";
    _dataPackets.text = @"packets/s";
    peripheralDictionary = [[NSMutableDictionary alloc] init];
    indexDictionary = [[NSMutableDictionary alloc] init];
    _finishRecordBtn.enabled = NO;
    _recordBtn.enabled = NO;
    _stopStreamingBtn.enabled=NO;
    _monitorBtn.enabled = NO;
    // Start scanning for the devices after the GUI has loaded
    [self startScanningForDevice];
}
-(void)initDeviceList
{
    deviceListFull = false;
    _device1.text = @"not found";
    _device2.text = @"not found";
    _device3.text = @"not found";
    _device4.text = @"not found";
    for(int i = 0; i<indexBegin;i++){
        ConnectionLost[i] = false;
        devices[i] = @"";
        
    }
    [peripheralDictionary removeAllObjects];
    [indexDictionary removeAllObjects];
    indexBegin = 0;
    
    
}

-(void)startScanningForDevice
{
    // Stop the current version
    self.centralManager = NULL;
    isRecording = false;
    
    // Start the manager again
    CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.centralManager = centralManager;
    
    NSLog( @"Started scanning for devices" );
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CBCentralManagerDelegate

// method called whenever you have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral=%@",[peripheral name]);
    
    // Set the delegate to itself
    peripheral.delegate = self;
    
    // Discover the services
    [peripheral discoverServices:nil];
}

// method called whenever a BLE peripheral is disconnected
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSString *DisconnectedDevice = [peripheral name];
    if (error) {
        NSLog(@"Peripheral %@ is Disconnected, error: %@", DisconnectedDevice, error.localizedDescription);
    }
    
    //add one slot to the list for disconnected device only
    indexBegin--;
    
    //look for Index value for disconnected device
    NSNumber *DisconnectedIndex = [indexDictionary objectForKey:DisconnectedDevice];
    int deviceIndex = [DisconnectedIndex intValue];
    
    //set lost connection flag for this index
    ConnectionLost[deviceIndex]=true;
    
    switch(deviceIndex){
        case 0:
            _device1.text = @"Lost";
            break;
        case 1:
            _device2.text = @"Lost";
            break;
        case 2:
            _device3.text = @"Lost";
            break;
        case 3:
            _device4.text = @"Lost";
            break;
        default:
            break;
    }
    
    //remove object from dictionary
    [peripheralDictionary removeObjectForKey:DisconnectedDevice];
    [indexDictionary removeObjectForKey:DisconnectedDevice];
    
    //restart scanning if scanning disabled
    if(![self.centralManager isScanning]){
        NSLog( @"restart scanning for lost connection");
        NSDictionary * dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@YES, CBCentralManagerScanOptionAllowDuplicatesKey, nil];
        [self.centralManager scanForPeripheralsWithServices:nil options:dictionary];
    }
}

// method called whenever the device state changes.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"centralManagerDidUpdateState=");
    
    // Determine the state of the peripheral
    if ([central state] == CBCentralManagerStatePoweredOff)
    {
        NSLog(@"CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn)
    {
        NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
        NSLog(@"scanForPeripheralsWithServices");
        //NSArray *services = @[[CBUUID UUIDWithString:HRTZ1000_HEART_RATE_UUID]];
        //(void)services;
        
        //[self.centralManager scanForPeripheralsWithServices:services options:nil];
        
        NSDictionary * dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@YES, CBCentralManagerScanOptionAllowDuplicatesKey, nil];
        
        //[self.centralManager scanForPeripheralsWithServices:nil options:nil];
        [self.centralManager scanForPeripheralsWithServices:nil options:dictionary];
        
    }
    else if ([central state] == CBCentralManagerStateUnauthorized)
    {
        NSLog(@"CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown)
    {
        NSLog(@"CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported)
    {
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSString *localName = [peripheral name];
    NSLog(@"Name: %@",localName);
    
    if ([localName length] > 0)
    {
        //detect all sensors or ones with specific name
        if( [localName hasPrefix:@"MDM"]){
        //if( [localName hasPrefix:@"MDM-DA"] || [localName hasPrefix:@"MDM-4E"])  {
            //if( [localName hasPrefix:@"WAX9"] )  {
            NSLog(@"Found Sensor(%@) with UUID (%@)", localName,peripheral.identifier.UUIDString);
            
            bool paired = false;
            
            for( int i=indexBegin; i<MaxDevicesToPair; i++ )
            {
                //NSString *device = devices[i];
                
                //if( [localName isEqualToString:device ] )
            
                for( int j=0; j<MaxDevicesToPair; j++)
                {
                    //if the device is already in the list
                    if([localName isEqualToString:devices[j]] ){
                        isAlreadyConnected=true;
                        
                        //reconnect if found a lost connection, otherwise ignore
                        if(ConnectionLost[j]==true){
                            NSLog( @"Lost Device %@ reconnecting", localName);
                            
                            // Keep track of this peripheral by its name
                            [peripheralDictionary setObject:peripheral forKey:localName];
                            
                            // Make a record of our index for this peripheral
                            NSNumber* myAutoreleasedNumber = nil;
                            myAutoreleasedNumber = [NSNumber numberWithInt:j];
                            [indexDictionary setObject:myAutoreleasedNumber forKey:localName];
                            
                            // Connect to this peripheral
                            peripheral.delegate = self;
                            [self.centralManager connectPeripheral:peripheral options:nil];
                            _status.text = @"Found";
                            switch(j){
                                case 0:
                                    _device1.text = devices[j];
                                    break;
                                case 1:
                                    _device2.text = devices[j];
                                    break;
                                case 2:
                                    _device3.text = devices[j];
                                    break;
                                case 3:
                                    _device4.text = devices[j];
                                    break;
                                default:
                                    break;
                            }

                            // Flag that we paired against this device
                            paired= true;
                            NSLog( @"Lost device (%@) index (%d) reconnected",localName,j);
                            indexBegin++;
                            ConnectionLost[j]=false;
                        }
                        
                        else{
                             NSLog( @"Device %@ is already connected", localName);
                        }
                    }
                }
                if( !isAlreadyConnected && !deviceListFull )
                {
                    devices[i]=localName;
                    NSLog( @"Pairing to device %@:",devices[i]);
                    
                    // Keep track of this peripheral by its name
                    [peripheralDictionary setObject:peripheral forKey:localName];
                    
                    // Make a record of our index for this peripheral
                    NSNumber* myAutoreleasedNumber = nil;
                    myAutoreleasedNumber = [NSNumber numberWithInt:i];
                    [indexDictionary setObject:myAutoreleasedNumber forKey:localName];
                    
                    // Connect to this peripheral
                    peripheral.delegate = self;
                    [self.centralManager connectPeripheral:peripheral options:nil];
                    _status.text = @"Found";
                    switch(i){
                        case 0:
                            _device1.text = devices[i];
                            break;
                        case 1:
                            _device2.text = devices[i];
                            break;
                        case 2:
                            _device3.text = devices[i];
                            break;
                        case 3:
                            _device4.text = devices[i];
                            break;
                        default:
                            break;
                    }
                    // Flag that we paired against this device
                    paired= true;
                    indexBegin++;

                }
            }
            if( !paired )
            {
                NSLog( @"Did not pair to WAX9(%@)", localName );
            }
            
            if( [indexDictionary count] == MaxDevicesToPair )//was 2, now 4
            {
                deviceListFull=true;
                [self.centralManager stopScan];
                NSLog( @"Stopped Scanning");
            }
            // flag that shows the current device is already connected
            isAlreadyConnected=false;
        }
    }
}

- (bool)checkMonitoringTime:(NSString *)str{
    NSScanner* scan = [NSScanner scannerWithString:str];
    int val;
    return([scan scanInt:&val] && [scan isAtEnd]);
}
- (NSData*) getMonitorCoeff:(int)hours{
    int minutes = hours*60;
    NSString * hex = [NSString stringWithFormat:@"%x",minutes];
    int len = [hex length];
    if (len<4) {
        for(int i =0;i<4-len;i++)
        {
            hex = [@"0" stringByAppendingString:hex];
        }
    }
    if(hours > 50){
        hex = [hex stringByAppendingString:@"0500"];
    }
    else{
        hex = [hex stringByAppendingString:@"0200"];
    }
    
    NSLog(@"Derek: monitor time: %d hours, coeff %@",hours,hex);
    NSData *data = [hex hexToBytes];
    return data;
}
- (IBAction)setMonitorTime:(id)sender {
    NSString *monitorTimeStr = _monitorTimeTextBox.text;
    bool success = [self checkMonitoringTime:monitorTimeStr];
    int monitorTime = [monitorTimeStr intValue];
    if(success && monitorTime>0 && monitorTime<=72)
    {
        NSData *data = [self getMonitorCoeff:monitorTime];
        for(int i=0; i<MaxDevicesToPair; i++){
            if( [devices[i] hasPrefix:@"MDM"] && !ConnectionLost[i]){
                CBPeripheral *peripheral = [peripheralDictionary objectForKey:devices[i]];
                for( CBService *service in peripheral.services){
                    if([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_DEVICE_CONFIG_UUID]]){
                        for( CBCharacteristic *aChar in service.characteristics){
                            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_SESSIONID_UUID]]){
                                //NSData *data = [NSData dataWithBytes:(Byte[]){0x00,0x01} length:2];
                                [peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
                            }
                        }
                    }
                }
            }
        }
        self.setMonitorTimeBtn.enabled = false;
        self.monitorBtn.enabled = true;
    }
    else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"ERROR"
                                                            message:@"The time you input is not valid, please input integer from 1 to 72"
                                                           delegate:nil
                                                  cancelButtonTitle:@"cancel"
                                                  otherButtonTitles:nil];
        [alert show];
    }
}

- (IBAction)startMonitoring:(id)sender {
    
        for(int i=0; i<MaxDevicesToPair; i++){
            if( [devices[i] hasPrefix:@"MDM"] && !ConnectionLost[i]){
                CBPeripheral *peripheral = [peripheralDictionary objectForKey:devices[i]];
                for( CBService *service in peripheral.services){
                    if([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_DEVICE_CONFIG_UUID]]){
                        for( CBCharacteristic *aChar in service.characteristics){
                            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_START_STREAMING_UUID]]){
                                //[peripheral setNotifyValue:true forCharacteristic:aChar];
                                //0x03 for normal monitoring, 0x04 for running compression
                                NSData *data = [NSData dataWithBytes:(Byte[]){0x03} length:1];
                                [peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
                                NSLog(@"start monitoring: for device: %@, write data: %@, to uuid: %@", peripheral.name,data,aChar.UUID.UUIDString);
                            }
                        }
                    }
                }
            }
        }
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"success"
                                                        message:@"monitoring started!"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    self.setMonitorTimeBtn.enabled = true;
    self.monitorBtn.enabled = false;
    [[self centralManager] stopScan];
    [self initDeviceList];
    [self startScanningForDevice];
    

}

-(IBAction) flush:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"erasing data" message:@"Are you sure to erase all container data?" delegate:self cancelButtonTitle:@"cancel" otherButtonTitles:@"erase", nil];
    [alert setTag:1];
    [alert show];

}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(alertView.tag == 1){
        if(buttonIndex == 0){
            NSLog(@"canceled");
        }
        else{
            NSLog(@"erased");
            bytesReceived = 0;
            NSFileManager *fileMgr = [[NSFileManager alloc] init];
            NSError *error = nil;
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentDirectory = [paths objectAtIndex:0];
            NSArray *directoryContent = [fileMgr contentsOfDirectoryAtPath:documentDirectory error:&error];
            if(error == nil){
                for(NSString *path in directoryContent){
                    NSString *fullPath = [documentDirectory stringByAppendingPathComponent:path];
                    BOOL removeSuccess = [fileMgr removeItemAtPath:fullPath error:&error];
                    if(!removeSuccess){
                        NSLog(@"derek: remove file failed for '%@'",fullPath);
                    }
                }
            }
            else{
                NSLog(@"derek: failed to find directory content");
            }
            _status.text = @"data erased";
        }
    }
}

-(IBAction) startRecording: (id) sender
{
    isRecording = true;
    //bytesReceived = 0;
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    _status.text = @"Recording";
    _recordBtn.enabled = NO;
    _finishRecordBtn.enabled = YES;
    
}

-(IBAction) endRecording: (id) sender
{
    isRecording = false;
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    _status.text = @"Not recording";
    _recordBtn.enabled = YES;
    _finishRecordBtn.enabled = NO;
}

-(IBAction) lockDevices: (id)sender
{
    if(isStreaming){
        _deviceStatus.text = @"Streaming !";
    }
    else{
        if(!isLocked){
            for(int i=0; i<MaxDevicesToPair; i++){
                if( [devices[i] hasPrefix:@"MDM"] && !ConnectionLost[i]){
                    CBPeripheral *peripheral = [peripheralDictionary objectForKey:devices[i]];
                    for( CBService *service in peripheral.services){
                        if([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_DEVICE_CONFIG_UUID]]){
                            for( CBCharacteristic *aChar in service.characteristics){
                                if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_SESSIONID_UUID]]){
                                    NSData *data = [NSData dataWithBytes:(Byte[]){0x00,0x01} length:2];
                                    [peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
                                }
                            }
                        }
                    }
                }
            }
        }
        isLocked = true;
        _deviceStatus.text = @"locked";
        _lockDeviceBtn.enabled = NO;
        _unlockDeviceBtn.enabled=YES;
    }
}

-(IBAction) unlockDevices: (id)sender
{
    if(isStreaming){
    _deviceStatus.text=@"Streaming !";
    }
    else{
        if(isLocked){
            for(int i=0; i<MaxDevicesToPair; i++){
                if( [devices[i] hasPrefix:@"MDM"] && !ConnectionLost[i]){
                    CBPeripheral *peripheral = [peripheralDictionary objectForKey:devices[i]];
                    for( CBService *service in peripheral.services){
                        if([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_DEVICE_CONFIG_UUID]]){
                            for( CBCharacteristic *aChar in service.characteristics){
                                if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_SESSIONID_UUID]]){
                                    NSData *data = [NSData dataWithBytes:(Byte[]){0x00,0x00} length:2];
                                    [peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
                                }
                            }
                        }
                    }
                }
            }
        }
        isLocked = false;
        _deviceStatus.text = @"unlocked";
        _lockDeviceBtn.enabled = YES;
        _unlockDeviceBtn.enabled=NO;
    }
    
}

- (IBAction)startStreaming:(id)sender {
    if(!isStreaming){
        for(int i=0; i<MaxDevicesToPair; i++){
            if( [devices[i] hasPrefix:@"MDM"] && !ConnectionLost[i]){
                CBPeripheral *peripheral = [peripheralDictionary objectForKey:devices[i]];
                for( CBService *service in peripheral.services){
                    if([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_DEVICE_CONFIG_UUID]]){
                        for( CBCharacteristic *aChar in service.characteristics){
                            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_START_STREAMING_UUID]]){
                                [peripheral setNotifyValue:true forCharacteristic:aChar];
                                NSData *data = [NSData dataWithBytes:(unsigned char[]){0x01} length:1];
                                [peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
                                NSLog(@"start streaming");
                                
                    
                            }
                        }
                    }
                }
            }
        }
    }
    isStreaming = true;
    _startStreamingBtn.enabled = NO;
    _stopStreamingBtn.enabled=YES;
    _lockDeviceBtn.enabled=NO;
    _unlockDeviceBtn.enabled=NO;
    _recordBtn.enabled=YES;
    _monitorBtn.enabled = NO;
}

- (IBAction)stopStreaming:(id)sender {
    if(isStreaming){
        for(int i=0; i<MaxDevicesToPair; i++){
            if( [devices[i] hasPrefix:@"MDM"] && !ConnectionLost[i]){
                CBPeripheral *peripheral = [peripheralDictionary objectForKey:devices[i]];
                for( CBService *service in peripheral.services){
                    if([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_DEVICE_CONFIG_UUID]]){
                        for( CBCharacteristic *aChar in service.characteristics){
                            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_START_STREAMING_UUID]]){
                                [peripheral setNotifyValue:true forCharacteristic:aChar];
                                NSData *data = [NSData dataWithBytes:(unsigned char[]){0x00} length:1];
                                [peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
                                NSLog(@"stop streaming");
                            }
                        }
                    }
                }
            }
        }
    }
    isStreaming = false;
    _startStreamingBtn.enabled = YES;
    _stopStreamingBtn.enabled=NO;
    _lockDeviceBtn.enabled=YES;
    _unlockDeviceBtn.enabled=YES;
    _monitorBtn.enabled = YES;
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"didDiscoverServices");
    
    for (CBService *service in peripheral.services)
    {
        NSLog(@"Discovered service: %@", service.UUID);
        
        NSLog(@"peripheral discoverCharacteristics for %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

-(void) startScanForRSSIMDM1{
    
    timerMDM1 = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(detectRSSIMDM1) userInfo:nil repeats:YES];
    
}

-(void) startScanForRSSIMDM2{
    
    timerMDM2 = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(detectRSSIMDM2) userInfo:nil repeats:YES];
    
}
-(void) startScanForRSSIMDM3{
    
    timerMDM3 = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(detectRSSIMDM3) userInfo:nil repeats:YES];
    
}
-(void) startScanForRSSIMDM4{
    
    timerMDM4 = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(detectRSSIMDM4) userInfo:nil repeats:YES];
    
}

- (void)detectRSSIMDM1 {
    peripheralMDM1.delegate = self;
    [peripheralMDM1 readRSSI];
}

- (void)detectRSSIMDM2 {
    peripheralMDM2.delegate = self;
    [peripheralMDM2 readRSSI];
}
- (void)detectRSSIMDM3 {
    peripheralMDM3.delegate = self;
    [peripheralMDM3 readRSSI];
}
- (void)detectRSSIMDM4 {
    peripheralMDM4.delegate = self;
    [peripheralMDM4 readRSSI];
}



- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    //NSLog(@"Adil: Inside didDiscoverCharacteristicsForService: %@",service.UUID);
    int count = (int)[service.characteristics count];
    NSLog( @"Number of service characteristics = %d", count );
    
    // https://github.com/timburks/iOSHeartRateMonitor/blob/master/HRM/HeartRateViewController.m
    // TZ1011
    // Service HR
    //old binary
    if ([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_HEART_RATE_UUID]])
    {
        //NSLog(@"Adil: Inside First if Statement ");
        
        for (CBCharacteristic *aChar in service.characteristics)
        {
            //NSLog(@"Adil: Inside First if Statement: for loop");
            
            //NSLog( @"Characteristics for service %@ are %@", service.UUID, aChar.UUID);
            
            // Notify Byte
            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_UUID_HR_MEASUREMENTS]])
            {
                //NSLog(@"Adil: Inside First if Statement: for loop:if statement");
                
                [peripheral setNotifyValue:true forCharacteristic:aChar];
            }
        }
        if([peripheral.name isEqualToString:devices[0]]){
            peripheralMDM1 = peripheral;
            [self startScanForRSSIMDM1];
        }
        else if([peripheral.name isEqualToString:devices[1]]){
            peripheralMDM2 = peripheral;
            [self startScanForRSSIMDM2];
        }
        else if([peripheral.name isEqualToString:devices[2]]){
            peripheralMDM3 = peripheral;
            [self startScanForRSSIMDM3];
        }
        else{peripheralMDM4 = peripheral;
            [self startScanForRSSIMDM4];
        }
    }
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_DEVICE_CONFIG_UUID]])
    {
        //NSLog(@"Adil: Inside Second if Statement ");
        
        for (CBCharacteristic *aChar in service.characteristics)
        {
            //NSLog(@"Adil: Inside Second if Statement: for loop");
            
            //NSLog( @"Characteristics for service %@ are %@", service.UUID, aChar.UUID);
            
            // Notify Byte
            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_SAMPLERATE_UUID]])
            {
                
                NSLog(@"Derek: set sampling rate to 100Hz");
                [peripheral setNotifyValue:true forCharacteristic:aChar];
                NSData *data = [NSData dataWithBytes:(unsigned char[]){0x0A, 0x10, 0x01, 0x02, 0x01} length:5];
                //[peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
                
            }
            
            if(isLocked && [aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_START_STREAMING_UUID]])
            {
                isStreaming=true;
                [peripheral setNotifyValue:true forCharacteristic:aChar];
                NSData *data = [NSData dataWithBytes:(unsigned char[]){0x01} length:1];
                [peripheral writeValue:data forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
            }
            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_SESSIONID_UUID]])
            {
                NSLog( @"Current Session ID: %@", aChar.value);
            }
            
            //new binary
            if([aChar.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_UUID_HR_MEASUREMENTS_NEW]])
            {
                NSLog(@"Derek: streaming data");
                
                [peripheral setNotifyValue:true forCharacteristic:aChar];
            }

        }
        if([peripheral.name isEqualToString:devices[0]]){
            peripheralMDM1 = peripheral;
            [self startScanForRSSIMDM1];
        }
        else if([peripheral.name isEqualToString:devices[1]]){
            peripheralMDM2 = peripheral;
            [self startScanForRSSIMDM2];
        }
        else if([peripheral.name isEqualToString:devices[2]]){
            peripheralMDM3 = peripheral;
            [self startScanForRSSIMDM3];
        }
        else{peripheralMDM4 = peripheral;
            [self startScanForRSSIMDM4];
        }
    }
}

-(void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_SESSIONID_UUID]]){
        NSLog( @"write to peripheral (%@) error (%@)", [peripheral name], error);
        // disabled reading for monitoring: reading immediately after monitoring started will cause the device to reboot. This happened when setting session id and start monitoring at the same time.
        //[peripheral readValueForCharacteristic:characteristic];
        //NSLog( @"Session id of (%@) is %@", [peripheral name], characteristic.value);
    }
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_SAMPLERATE_UUID]]){
        NSLog( @"write to peripheral (%@) error (%@)", [peripheral name], error);
        [peripheral readValueForCharacteristic:characteristic];
        NSLog( @"sample rate coeff of (%@) is %@", [peripheral name], characteristic.value);
    }
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_START_STREAMING_UUID]]){
        NSLog( @"write to peripheral (%@) error (%@)", [peripheral name], error);
    }
}

-(void) peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    
    // Cache the device name
    NSString *deviceName = [peripheral name];
    // Get our index for the device
    NSNumber *deviceIndexKeyPair = [indexDictionary objectForKey:deviceName];
    int deviceIndex = [deviceIndexKeyPair intValue];
    rss[deviceIndex] = [RSSI doubleValue];
    
    //NSLog(@"Got RSSI update in didReadRSSI from Device: %4.1f, %d", rss[deviceIndex],deviceIndex);
    _RSSI.text = [NSString stringWithFormat:@"%4.1f,%4.1f,%4.1f,%4.1f",rss[0],rss[1],rss[2],rss[3]];
    
    // Create a filename for this info
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    //make a file name to write the data to using the documents directory:
    NSString *fileName = [NSString stringWithFormat:@"%@/TZ1011_RSSI_%@.txt", documentsDirectory, deviceName];
    
    // Get the timestamp
    NSDate *myDate = [[NSDate alloc] init];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *formattedDate = [dateFormat stringFromDate:myDate];
    const char *strDate = [formattedDate cStringUsingEncoding:NSASCIIStringEncoding];
    
    if( isRecording )
    {
        const char *strFilename = [fileName cStringUsingEncoding:NSASCIIStringEncoding];
        
        FILE *f = fopen( strFilename, "a" );
        if( f )
        {
            fprintf(f, "%s,", strDate );
            fprintf(f, "%4.1f\n", rss[deviceIndex]);
            fclose(f);
            
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *) error
{
    //NSLog(@"Adil: Inside didUpdateValueForCharacteristic");
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_UUID_HR_MEASUREMENTS]]||[characteristic.UUID isEqual:[CBUUID UUIDWithString:HRTZ1000_UUID_HR_MEASUREMENTS_NEW]]){
       // NSLog(@"Adil: Inside didUpdateValueForCharacteristic HRTZ1000_UUID_HR_MEASUREMENTS");
        
        if(characteristic.value || !error) {
            
            // Read the data in
            NSData *data = [characteristic value];
            int length = (int)[data length];
            NSLog(@"TZ1011 Heart Rate Measurements %@, Length: %d", characteristic.UUID, length);
            
            if (length == 20) {
                
                // Cache the device name
                NSString *deviceName = [peripheral name];
                
                // Get at the bytes
                const uint8_t *sensorData = [data bytes];
                
                short ax = ((short)sensorData[1] << 8) | sensorData[0];
                short ay = ((short)sensorData[3] << 8) | sensorData[2];
                short az = ((short)sensorData[5] << 8) | sensorData[4];
                
                short gx = ((short)sensorData[7] << 8) | sensorData[6];
                short gy = ((short)sensorData[9] << 8) | sensorData[8];
                short gz = ((short)sensorData[11] << 8) | sensorData[10];
                
                short mx = ((short)sensorData[13] << 8) | sensorData[12];
                short my = ((short)sensorData[15] << 8) | sensorData[14];
                short mz = ((short)sensorData[17] << 8) | sensorData[16];
                
                short upCounter = ((short)sensorData[19] << 8) | sensorData[18];
                
                float fax = (float) ax;
                float fay = (float) ay;
                float faz = (float) az;
                
                fax = fax / 8192.0f;
                fay = fay / 8192.0f;
                faz = faz / 8192.0f;
                
                float fgx = (float) gx;
                float fgy = (float) gy;
                float fgz = (float) gz;
                
                fgx = fgx * 0.00762939453125f;
                fgy = fgy * 0.00762939453125f;
                fgz = fgz * 0.00762939453125f;
                
                float fmx = (float) mx;
                float fmy = (float) my;
                float fmz = (float) mz;
                
                
                // Cache the device name
                
                // Get our index for the device
                NSNumber *deviceIndexKeyPair = [indexDictionary objectForKey:deviceName];
                int deviceIndex = [deviceIndexKeyPair intValue];
                //NSLog( @"Data %d: %d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n", deviceIndex, ax,ay,az,gx,gy,gz,mx,my,mz,upCounter);
                
                // Setup our global variables
                acc[deviceIndex][0] = fax; acc[deviceIndex][1] = fay; acc[deviceIndex][2] = faz;
                mag[deviceIndex][0] = fmx; mag[deviceIndex][1] = fmy; mag[deviceIndex][2] = fmz;
                rot[deviceIndex][0] = fgx; rot[deviceIndex][1] = fgy; rot[deviceIndex][2] = fgz;
                
                counter[deviceIndex] = upCounter;
                
                // Update the screen
                _status.text         = [NSString stringWithFormat:@"Bytes recorded %d", bytesReceived];
                _accelerometer.text  = [NSString stringWithFormat:@"%.2f %.2f %.2f\n%.2f %.2f %.2f\n%.2f %.2f %.2f\n%.2f %.2f %.2f",
                                        acc[0][0], acc[0][1], acc[0][2],
                                        acc[1][0], acc[1][1], acc[1][2],
                                        acc[2][0], acc[2][1], acc[2][2],
                                        acc[3][0], acc[3][1], acc[3][2]
                                        ];
                
                _magnetometer.text  = [NSString stringWithFormat:@"%.2f %.2f %.2f\n%.2f %.2f %.2f\n%.2f %.2f %.2f\n%.2f %.2f %.2f",
                                       mag[0][0], mag[0][1], mag[0][2],
                                       mag[1][0], mag[1][1], mag[1][2],
                                       mag[2][0], mag[2][1], mag[2][2],
                                       mag[3][0], mag[3][1], mag[3][2]
                                       ];
                
                _gyroscope.text  = [NSString stringWithFormat:@"%.2f %.2f %.2f\n%.2f %.2f %.2f\n%.2f %.2f %.2f\n%.2f %.2f %.2f",
                                    rot[0][0], rot[0][1], rot[0][2],
                                    rot[1][0], rot[1][1], rot[1][2],
                                    rot[2][0], rot[2][1], rot[2][2],
                                    rot[3][0], rot[3][1], rot[3][2]
                                    ];
                
                
                // Create a filename for this info
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                
                //make a file name to write the data to using the documents directory:
                NSString *fileName = [NSString stringWithFormat:@"%@/TZ1011%@.txt", documentsDirectory, deviceName ];
                
                // Get the timestamp
                NSDate *myDate = [[NSDate alloc] init];
                NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
                //[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
                [dateFormat setDateFormat:@"HH:mm:ss.SSS"];
                
                NSString *formattedDate = [dateFormat stringFromDate:myDate];
                const char *strDate = [formattedDate cStringUsingEncoding:NSASCIIStringEncoding];
                
                NSString *dateStr = [NSString stringWithCString:strDate encoding:NSASCIIStringEncoding];
                
                NSDate *timeDate = [dateFormat dateFromString:dateStr];
                dateFormat.dateFormat = @"HH";
                int hours = [[dateFormat stringFromDate:timeDate] intValue];
                dateFormat.dateFormat = @"mm";
                int minutes = [[dateFormat stringFromDate:timeDate] intValue];
                dateFormat.dateFormat = @"ss";
                int seconds = [[dateFormat stringFromDate:timeDate	] intValue];
                dateFormat.dateFormat = @"SSS";
                int miliseconds = [[dateFormat stringFromDate:timeDate] intValue];
                
                double totalTime = hours*3600 + minutes*60 + seconds + ((float)miliseconds)/1000.0;
                
                // Estimate sampling rate, estimate packet loss and total packet loss
                filterFS[counterFS[deviceIndex] % OUTPUT_BUFFER][deviceIndex] = totalTime;
                filterCounter[counterFS[deviceIndex] % OUTPUT_BUFFER][deviceIndex] = counter[deviceIndex];
                counterFS[deviceIndex]++;
                
                //if (counterFS >= OUTPUT_BUFFER ) {
                if (counterFS[deviceIndex] % OUTPUT_BUFFER == 0 ) {
                    for (int i = 0; i < OUTPUT_BUFFER-1; i++) {
                        //tempFS += filterFS[i];
                        tempFS[deviceIndex] = tempFS[deviceIndex] + (filterFS[i+1][deviceIndex]-filterFS[i][deviceIndex]);
                    }
                    
                    fsFilt[deviceIndex] = (OUTPUT_BUFFER-1)/tempFS[deviceIndex];
                    dataRates[deviceIndex] = fsFilt[deviceIndex]*length;
                    tempFS[deviceIndex] = 0;
                    _dataRates.text = [NSString stringWithFormat:@"%d,%d,%d,%d",dataRates[0],dataRates[1],dataRates[2],dataRates[3]];
                    _dataPackets.text = [NSString stringWithFormat:@"%d,%d,%d,%d",fsFilt[0],fsFilt[1],fsFilt[2],fsFilt[3]];
                    
                }
                
                if (counterFS[deviceIndex] % OUTPUT_BUFFER == 0 ) {
                    for (int i = 0; i < OUTPUT_BUFFER-1; i++) {
                        tempCounter[deviceIndex] = tempCounter[deviceIndex] + (filterCounter[i+1][deviceIndex]-filterCounter[i][deviceIndex]-1);
                    }
                    
                    packetLoss[deviceIndex] = 100.0-100.0*(((float)tempCounter[deviceIndex])/(float)(OUTPUT_BUFFER));
                    _throughput.text = [NSString stringWithFormat:@"%d,%d,%d,%d",(int)packetLoss[0],(int)packetLoss[1],(int)packetLoss[2],(int)packetLoss[3]];
                    tempCounter[deviceIndex] = 0;
                }
                
                //NSLog( @"%s, %d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n", strDate, ax,ay,az,gx,gy,gz,mx,my,mz,upCounter);
                //NSLog( @"%s, %d, %d, %d, %d, %d, %d, %d: %d\n",strDate, hours, minutes, seconds, miliseconds, fsFilt[deviceIndex], dataRates[deviceIndex], (int)packetLoss[deviceIndex],deviceIndex);
                
                if( isRecording )
                {
                    const char *strFilename = [fileName cStringUsingEncoding:NSASCIIStringEncoding];
                    FILE *f = fopen( strFilename, "a" );
                    if( f )
                    {
                        fprintf(f, "%s,", strDate );
                        fprintf(f, "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
                                ax,ay,az,gx,gy,gz,mx,my,mz,upCounter);
                        
                        fclose(f);
                        
                        bytesReceived += length;
                    }
                }
            }
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *) error
{
    if (error) {
        //NSLog(@"Adil: Error changing notification state: %@", error.localizedDescription);
    }
    
    //NSLog( @"didUpdateNotificationStateForCharacteristic from %@", characteristic.UUID );
    if ( characteristic.isNotifying )
    {
//        NSLog(@"Adil: Inside didUpdateNotificationStateForCharacteristic");
//        
//        // Code to check if our devices are notifying
//        
//        // Cache the device name
//        NSString *deviceName = [peripheral name];
//        
//        // Get our index for the device
//        NSNumber *deviceIndexKeyPair = [indexDictionary objectForKey:deviceName];
//        int deviceIndex = [deviceIndexKeyPair intValue];
//        (void)deviceIndex;
        
        //[peripheral readValueForCharacteristic:characteristic];
    }
}

@end
