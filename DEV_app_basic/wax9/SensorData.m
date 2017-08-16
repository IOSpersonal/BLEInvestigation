//
//  SensorData.m
//  Multiple WAX9
//
//  Created by Muhammad Umer on 3/08/2016.
//  Copyright © 2016 Gavin Wood. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SensorData.h" 

@implementation SensorData {
    double thing;
    
}

- (NSString *) FormattedStatus {
    
    return
     [NSString stringWithFormat: @"%@ %@\n%@ %@%@ %@ %@\n%@ %@\n%@ %@\n%@ %@\n\n",_SensorName,@" Connected", @"Packet Loss: ",_PacketLoss,@"%", @"RSSI: ", _RSSI,
            /*@"Data Rate: ", _DataRate, @"Data Packets: ",_DataPackets,*/
            @"Acc: ", _AccData,
            @"Gyro: ", _GyroData,
            @"Mag: ", _MagData
        ];

}


@end