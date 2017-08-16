//
//  SensorData.h
//  Multiple WAX9
//
//  Created by Muhammad Umer on 3/08/2016.
//  Copyright © 2016 Gavin Wood. All rights reserved.
//


@interface SensorData : NSObject {
 
}


@property (copy) NSString *SensorName;
@property (copy) NSString *RSSI;
@property (copy) NSString *Throughput;
@property (copy) NSString *PacketLoss;
@property (copy) NSString *DataRate;
@property (copy) NSString *AccData;
@property (copy) NSString *GyroData;
@property (copy) NSString *MagData;
@property  (copy) NSString *DataPackets;


-(NSString *) FormattedStatus;


@end 