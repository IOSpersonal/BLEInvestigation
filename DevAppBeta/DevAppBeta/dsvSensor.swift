//
//  dsvSensor.swift
//  DevAppBeta
//  dsvSensor object saves reference of a connected sensor, include some initialisers for certain sensor functions
//  Created by Weihang Liu on 12/2/18.
//  Copyright © 2018 Weihang Liu. All rights reserved.
//

import UIKit
import CoreBluetooth

class dsvSensor: NSObject {
    public      var name                   :String
    public      var peripheralRef          :CBPeripheral
    //string for saving all offloaded data
    public      var offloadStrings         :String = ""
    //for fetching specific lost packet
    public      var fetchIndices           :Int    = 0
    //bool flag for checking offload finished for fetching lost data
    public      var isOffloadFinished      :Bool   = false
    //bool flag for checking offload all finished including getting lost data
    public      var isOffloadCompleted     :Bool   = false
    
    //config as indices - check global variables for config values
    public      var accScales              :Int    = 1
    public      var gyroScales             :Int    = 1
    public      var acc_gyro_freq          :Int    = 1
    public      var magFreq                :Int    = 1
    public      var emgFreq                :Int    = 1
    //for checking packet loss
    public      var lastSeqNums            :UInt16 = 0
    public      var lostSeqNums            = [UInt16]()
    //file names for streaming and offloading
    public      var offloadFileNames       :String = ""
    public      var streamFileNames        :String = ""
    public      var timeCalLogFileNames    :String = ""
    //[DEV] temp variable for time Calibration
    public      var lastTimeCalStr         :String = ""
    //buffer for updating firmware binary
    public      var upCounters             :Int    = 1
    public      var FWWriteCounter         :Int    = 0
    public      var FWUpgradeShouldSendCRC :Bool   = false
    public      var FWUpgradeCompleted     :Bool   = false
    public      var characteristics        = [String : CBCharacteristic]()
    
    init(peripheral: CBPeripheral){
        //initialisers for sensor object
        self.name = peripheral.name!
        self.peripheralRef = peripheral
        self.streamFileNames = self.name + "_stream.txt"
        self.offloadFileNames = self.name + "_offload.txt"
        self.timeCalLogFileNames = self.name + "_timeCalLog.txt"
    }
    
    public func initOffload(){
        //reset offload variables
        self.isOffloadFinished = false
        self.isOffloadCompleted = false
        self.lostSeqNums = [UInt16]()
        self.fetchIndices = 0

    }
    
    public func initFWUpgrade(){
        //reset FW update variables
        self.upCounters = 1
        self.FWWriteCounter = 0
        self.FWUpgradeShouldSendCRC = false
        self.FWUpgradeCompleted = false
    }
}
