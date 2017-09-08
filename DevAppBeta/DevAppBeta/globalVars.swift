//
//  globalVars.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 25/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import Foundation

struct globalVariables {
    static var appStatus = "uninitialised"
    static let BLEHandler = BLEController()
    static var allSensorList = [String]()
    static let FileHandler = CustomFileManager()
    //maximum device to pair with
    static let MaxNumOfDevice = 4
    //monitor type - true for normal, false for running
    static var monitorTypeFlag = true
    //FW update maximum transfer size
    static let maxTransferUnit = 19
    static var currentNumOfDevice = 0
}
