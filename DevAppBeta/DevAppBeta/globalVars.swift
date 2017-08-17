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
    static let MaxNumOfDevice = 4 // maximum device to pair with
    
}
