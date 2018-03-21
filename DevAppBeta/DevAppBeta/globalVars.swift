//
//  globalVars.swift
//  DevAppBeta
//  All global variables and Object reference
//  Created by Weihang Liu on 25/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import Foundation

// global variables that saves all static variables/objectsxs
struct globalVariables {
    static var appStatus = "uninitialised"
    static let BLEHandler = BLEController()
    static var allSensorList = [String]()
    static let FileHandler = CustomFileManager()
    //maximum device to pair with
    static let MaxNumOfDevice = 5
    //monitor type - true for normal, false for running
    static var monitorTypeFlag = true
    static var EKFshouldPerformAttitudeEstimate = false
    //FW update variables
    //FIXME*: currently I did not find a way to load bin file with 
    static let firmwareFileName = "FW6c.bin"
    static let firmwareBufferLen = 135748
    static let maxTransferUnit = 63
    static var currentNumOfDevice = 0
    //configs
    static let accFreqArray = ["10Hz","20Hz", "50Hz", "100Hz","200Hz","225Hz"]
    static let accScaleArray = ["0","2", "4", "8","16"]
    static let gyroScaleArray = ["0","250", "500","1000","2000","4000"]
    static let magFreqArray = ["STAND BY", "SINGLE","10Hz","20Hz", "50Hz", "100Hz"]
    static let emgFreqArray = ["STAND BY","1000Hz", "500Hz"]
}
