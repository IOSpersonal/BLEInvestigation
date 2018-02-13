//
//  BLEController.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 21/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit
import Foundation
import CoreBluetooth

protocol BLEDelegate {
    func bleDidUpdateState()
    func bleDidConnectToPeripheral()
    func bleDidDisconenctFromPeripheral()
    func bleDidReceiveData(data: NSData?)
}
protocol UIntToByteConvertable{
    var toBytes: [UInt8] {get}
}

//extend data to get hex string value
extension Data{
    func hexEncodedString() -> String{
        return map { String(format: "%02hhx", $0)}.joined()
    }
}

extension String:Error{}

extension UIntToByteConvertable{
    func toByteArr<T: BinaryInteger>(endian: T, count: Int) -> [UInt8]{
        var _endian = endian
        let bytePtr = withUnsafePointer(to: &_endian){
            $0.withMemoryRebound(to: UInt8.self, capacity: count){
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return [UInt8](bytePtr)
    }
}

extension UInt32: UIntToByteConvertable{
    var toBytes: [UInt8]{
        return toByteArr(endian: self.littleEndian, count: MemoryLayout<UInt32>.size)
    }
}

class BLEController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    //TZ Custom UUIDs
    private let MDM_SERVICE_UUID            = "00000005-0008-A8BA-E311-F48C90364D99"
    private let MDM_COMMAND_UUID            = "00000006-0008-A8BA-E311-F48C90364D99"
    private let MDM_SCALE_UUID              = "0000000A-0008-A8BA-E311-F48C90364D99"
    private let MDM_SESSIONID_UUID          = "0000000C-0008-A8BA-E311-F48C90364D99"
    private let MDM_TIMECALCOEFF_UUID       = "0000000F-0008-A8BA-E311-F48C90364D99"
    private let MDM_STREAMDATA_UUID         = "00000010-0008-A8BA-E311-F48C90364D99"
    private let MDM_OFFLOAD_UUID            = "00000011-0008-A8BA-E311-F48C90364D99"
    private let MDM_OFFLOADDATA_UUID        = "00000012-0008-A8BA-E311-F48C90364D99"
    //FW Upgrade UUIDs
    private let FWUPDATE_SERVICE_UUID       = "ECA95120-F940-11E4-9ED0-0002A5D5C51B"
    private let FWUPDATE_CONTROL_POINT_UUID = "4D294BE0-F941-11E4-BCCE-0002A5D5C51B"
    private let FWUPDATE_INPUT_CHAR_UUID    = "C1C8A4A0-F941-11E4-A534-0002A5D5C51B"
    private let FWUPDATE_CRC_INPUT_UUID     = "173710C0-F942-11E4-9B99-0002A5D5C51B"
    private let FWUPDATE_CCC_DESC_UUID      = "2902"
    private let FWUPDATE_REVERT_UUID        = "10000000-F942-11E4-8000-0002A5D5C51B"

    var delegate: BLEDelegate?
    var mainViewController: ViewController?
    var BLEViewController: BLEViewController?
    var FWUpgradeViewController: FWUpgradeViewController?
    var attitudeEstimator: AttitudeEstimator?
    private      var lastStreamingTime      = 0.0
    private      var isInitialised          = false
    private      var centralManager:        CBCentralManager!
    public       var connectedSensors      = [dsvSensor]()
    private      var data:                  NSMutableData?
    private(set) var peripherals            = [CBPeripheral]()
    private      var RSSICompletionHandler: ((NSNumber?, NSError?) -> ())?
    //time for checking reloading gragh
    private      var lastReloadTime:UInt32  = 0
    private      var reloadGap:UInt32       = 100

    //var for calculating offload time
    private      var timeOffloadStarted     = 0.0

    //current connected peripheral count
    private      var peripheralCount        = 0
    //[DEV] temp variable for synchronised monitoring
    private      var syncTimeArray          = [UInt32]()
    //[DEV] bool for checking if should response stream start
    public       var isServingStreamStart   = false
    //buffer for updating firmware binary
    private      var FWBuf                  = [UInt8]()
    
    override init() {
        if !self.isInitialised{
            self.lastReloadTime = UInt32(CACurrentMediaTime()*1000)
            self.attitudeEstimator = AttitudeEstimator.init()
            self.lastStreamingTime = CACurrentMediaTime()
            super.init()
            self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
            self.data = NSMutableData()
            self.isInitialised = true
        }
        else{
            super.init()
        }
        
    }
    
    func passMainView(view: ViewController){
        print("[DEBUG] passMainView is called")
        self.mainViewController = view
    }
    
    func passBLEView(view: BLEViewController){
        print("[DEBUG] passBLEView is called")
        self.BLEViewController = view
    }
    func passFWUpgradeView(view: FWUpgradeViewController){
        print("[DEBUG] passBLEView is called")
        self.FWUpgradeViewController = view
    }
    

    func getSensorByName(name: String) throws -> dsvSensor{
        if self.connectedSensors.count>0
        {
            for sensor in self.connectedSensors{
                if sensor.name == name{
                    return sensor
                }
            }
        }
        throw "sensor not found exception"
    }
    
    @objc private func scanTimeout() {
        
        print("[DEBUG] Scanning stopped")
        self.centralManager.stopScan()
    }
    
    // MARK: Public methods
    func startScanning(timeout: Double) -> Bool {
        self.peripherals.removeAll()
        if self.centralManager.state != .poweredOn {
            print("[ERROR] Couldn´t start scanning")
            return false
        }
        print("[DEBUG] Scanning started")
        Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(BLEController.scanTimeout), userInfo: nil, repeats: false)
        //allow duplicated key for update rssi
        self.centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        
        return true
    }
    func stopScanning(){
        if self.centralManager.state != .poweredOn {
            print("[ERROR] Couldn´t stop scanning")
        }
        print("[DEBUG] Stop Scanning")
        self.centralManager.stopScan()
    }
    
    func connectToPeripheral(peripheral: CBPeripheral) -> Bool {
        
        if self.centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t connect to peripheral")
            return false
        }
        
        print("[DEBUG] Connecting to peripheral: \(peripheral.name ?? "nil")")
        
        self.centralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
        
        return true
    }
    
    func disconnectFromPeripheral(peripheral: CBPeripheral) -> Bool {
        
        if self.centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t disconnect from peripheral")
            return false
        }
        
        self.centralManager.cancelPeripheralConnection(peripheral)
        
        return true
    }
    
    func disconnectAllPeripheral() -> Bool {
        print("[DEBUG] disconnect from all peripheral")
        if (self.centralManager.state != .poweredOn) || (self.connectedSensors.count == 0) {
            
            print("[ERROR] Couldn´t disconnect from peripheral")
            return false
        }
        for sensor in self.connectedSensors{
            self.centralManager.cancelPeripheralConnection(sensor.peripheralRef)
        }
        return true
    }

    func enableNotificationsFor(Peripheral: CBPeripheral, enable: Bool) {
        print("[DEBUG] enable notification for sensor: \(Peripheral.name ?? "nil")")
        do {let sensor = try getSensorByName(name: Peripheral.name!)
        guard let char_stream = sensor.characteristics[MDM_STREAMDATA_UUID] else { return }
        Peripheral.setNotifyValue(enable, for: char_stream)
        guard let char_offload = sensor.characteristics[MDM_OFFLOADDATA_UUID] else { return }
            Peripheral.setNotifyValue(enable, for: char_offload)}
        catch{return}
    }
 
    func readRSSI(completion: @escaping (_ RSSI: NSNumber?, _ error: NSError?) -> ()) {
        self.RSSICompletionHandler = completion
        for sensor in self.connectedSensors{
            sensor.peripheralRef.readRSSI()
        }
    }
    
    func startStreaming(){
        let data = Data(bytes: [0x01])
        self.lastStreamingTime = CACurrentMediaTime()
        for sensor in self.connectedSensors{
            guard let char = sensor.characteristics[MDM_COMMAND_UUID] else {return}
            sensor.peripheralRef.writeValue(data, for: char, type: .withResponse)
        }
    }
    
    func stopStreaming(){
        let data = Data(bytes: [0x02])
        for sensor in self.connectedSensors{
            guard let char = sensor.characteristics[MDM_COMMAND_UUID] else {return}
            sensor.peripheralRef.writeValue(data, for: char, type: .withResponse)
        }
        self.BLEViewController?.updateStatus(value: "streamComplete, writing to file")
    }
    //generate session ID from minutes
    func generateSessionID(intValue: Int) -> Data {
        var profileID:UInt8 = UInt8(0x00)
        if intValue>3000{
            //change to 20/20/0 Hz if > 50 hours
            print("[DEBUG] long monitor: change profile")
            profileID = UInt8(0x05)
        }
        else if !globalVariables.monitorTypeFlag{
            print("[DEBUG] enter running session")
            profileID = UInt8(0x02)
        }
        var sessionTimeBytes = [UInt8]()
        sessionTimeBytes.append(UInt8(UInt16(intValue) >> 8))
        sessionTimeBytes.append(UInt8(UInt16(intValue) & 0x00ff))
        sessionTimeBytes.append(profileID)
        sessionTimeBytes.append(UInt8(0x00))
        let dataValue = Data.init(bytes: sessionTimeBytes)
        print("[DEBUG] session id is calculated as: \(dataValue)")
        return dataValue
    }
    
    func startMonitoring(time: Int) -> Bool {
        //go to monitoring, generate session id
        let sessionID:Data = self.generateSessionID(intValue: time)
        //start monitoring will disconnect from peripheral, store num of peripheral in advance
        //check flag for running or normal monitoring
        var data = Data(bytes: [0x03])
        if !globalVariables.monitorTypeFlag {
            data = Data(bytes: [0x04])
        }
        for sensor in self.connectedSensors{
            //remove previous synch monitor results
            self.syncTimeArray.removeAll()
            guard let char = sensor.characteristics[MDM_SESSIONID_UUID] else {return false}
            sensor.peripheralRef.writeValue(sessionID, for: char, type: .withResponse)
            guard let charCommand = sensor.characteristics[MDM_COMMAND_UUID] else {return false}
            sensor.peripheralRef.writeValue(data, for: charCommand, type: .withResponse)
        }
        return true
    }
    
    func offloadCompressedData(){
        self.timeOffloadStarted = CACurrentMediaTime()
        for sensor in self.connectedSensors{
            sensor.initOffload()
            let data = Data(bytes: [0x06])
            guard let char = sensor.characteristics[MDM_OFFLOAD_UUID] else {return}
            sensor.peripheralRef.writeValue(data, for: char, type: .withResponse)
            print("[DEBUG] start offloading")
        }
    }
    
    func eraseDevices() -> Bool{
    //erase device for FW Upgrade
        let data = Data(bytes: [0x00,0x00,0x00,0x02])
        for sensor in self.connectedSensors{
            guard let char = sensor.characteristics[MDM_SESSIONID_UUID] else {return false}
            sensor.peripheralRef.writeValue(data, for: char, type: .withResponse)
        }
        return true
    }
    
    func revertDevices() -> Bool{
        //erase device for FW Upgrade
        let data = Data(bytes: [0x01])
        for sensor in self.connectedSensors{
            guard let char = sensor.characteristics[FWUPDATE_REVERT_UUID] else {return false}
            sensor.peripheralRef.writeValue(data, for: char, type: .withResponse)
        }
        return true
    }
    
    //start time calibration
    func startTimeCalibration() -> Bool{
        let data = Data(bytes: [0x06])
        for sensor in self.connectedSensors{
            guard let char = sensor.characteristics[MDM_COMMAND_UUID] else {return false}
            sensor.peripheralRef.writeValue(data, for: char, type: .withResponse)
            let filename = sensor.timeCalLogFileNames
            if globalVariables.FileHandler.fileExist(filename: filename){
                globalVariables.FileHandler.deleteFile(filename: filename)
            }
        }
        return true
    }
    
    //stop time calibration
    //NB: time calibration in IOS system is inaccurate, coeff calculated unreliable.
    func stopTimeCalibration() -> Bool{
        //check Log file
        for sensor in self.connectedSensors{
            let filename = sensor.timeCalLogFileNames
            if !globalVariables.FileHandler.fileExist(filename: filename){
                print("[DEBUG] error, the sensor connected does not match time calibration log")
                return false
            }
        }
        //calculate and write coeffs
        for sensor in self.connectedSensors{
            let tempStrStart = globalVariables.FileHandler.readFileAsString(filename: sensor.timeCalLogFileNames)
            let APPTimeStart = Int(tempStrStart[..<(tempStrStart.range(of: "+")?.lowerBound)!])
            let APPTimeEnd = Int(sensor.lastTimeCalStr[..<(sensor.lastTimeCalStr.range(of: "+")?.lowerBound)!])
            let SensorTimeStart = Int(tempStrStart[(tempStrStart.range(of: "+")?.upperBound)!...])
            let SensorTimeEnd = Int(sensor.lastTimeCalStr[(sensor.lastTimeCalStr.range(of: "+")?.upperBound)!...])
            let sensorTimeDuration = UInt32(SensorTimeEnd! - SensorTimeStart!)
            let timeDifference = UInt32(bitPattern: Int32(APPTimeEnd! - APPTimeStart!) - Int32(sensorTimeDuration))
            var coeff = [UInt8]()
            coeff.append(UInt8(0x01))
            coeff.append(UInt8(timeDifference&0x000000ff))
            coeff.append(UInt8((timeDifference>>8)&0x000000ff))
            coeff.append(UInt8((timeDifference>>16)&0x000000ff))
            coeff.append(UInt8((timeDifference>>24)&0x000000ff))
            coeff.append(UInt8(sensorTimeDuration&0x000000ff))
            coeff.append(UInt8((sensorTimeDuration>>8)&0x000000ff))
            coeff.append(UInt8((sensorTimeDuration>>16)&0x000000ff))
            coeff.append(UInt8((sensorTimeDuration>>24)&0x000000ff))
            print("[DEBUG] time cal coeff is calculated as \(coeff) from startStr: \(tempStrStart) and endStr: \(sensor.lastTimeCalStr)")
            let coeffData = Data(bytes: coeff)
            guard let char = sensor.characteristics[MDM_TIMECALCOEFF_UUID] else {return false}
            sensor.peripheralRef.writeValue(coeffData, for: char, type: .withResponse)
        }
        
        //stop streaming for all
        let data = Data(bytes: [0x07])
        for sensor in self.connectedSensors{
            guard let char = sensor.characteristics[MDM_COMMAND_UUID] else {return false}
            sensor.peripheralRef.writeValue(data, for: char, type: .withResponse)
        }
        return true
    }
    
    //update FW
    func startUpdateFWWithFile(filename: String) -> Bool{

        //open fw file
        self.FWBuf = globalVariables.FileHandler.openFWBinFile(filename: filename)
        print("[DEBUG] read Firmware Bin file, length: \(FWBuf.count), first and last values: \(FWBuf[0]), \(FWBuf[FWBuf.count-1])")
        let cmd = Data.init(bytes: [0x02, 0x00, 0x00])
        for sensor in self.connectedSensors{
            guard let char = sensor.characteristics[FWUPDATE_CONTROL_POINT_UUID] else {return false}
            print("[DEBUG] writing control point for \(sensor.name)")
            sensor.peripheralRef.writeValue(cmd, for: char, type: .withResponse)
        }
        return true
    }
    // write ble config
    func writeBLEConfigWithData(data: Data) -> Bool{
        guard let char = self.connectedSensors[0].characteristics[MDM_SCALE_UUID] else {return false}
        self.connectedSensors[0].peripheralRef.writeValue(data, for: char, type: .withResponse)
        return true
    }
    
    // MARK: CBCentralManager delegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .unknown:
            print("[DEBUG] Central manager state: Unknown")
            break
            
        case .resetting:
            print("[DEBUG] Central manager state: Resseting")
            break
            
        case .unsupported:
            print("[DEBUG] Central manager state: Unsopported")
            break
            
        case .unauthorized:
            print("[DEBUG] Central manager state: Unauthorized")
            break
            
        case .poweredOff:
            print("[DEBUG] Central manager state: Powered off")
            break
            
        case .poweredOn:
            print("[DEBUG] Central manager state: Powered on")
            break
        }
        
        self.delegate?.bleDidUpdateState()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("[DEBUG] Found peripheral: \(peripheral.name ?? "nil") RSSI: \(RSSI)")
        
        if peripheral.name != nil{
            if (peripheral.name?.hasPrefix("MDM-"))!{
                var tableViewShouldUpdateRSSI = false
                for strValue in globalVariables.allSensorList{
                    if strValue.hasPrefix(peripheral.name!){
                        tableViewShouldUpdateRSSI = true
                        break
                    }
                }
                if !tableViewShouldUpdateRSSI {
                    print("[DEBUG] Found sensor: \(peripheral.name ?? "nil") RSSI: \(RSSI)")
                    let index = peripherals.index { $0.identifier.uuidString == peripheral.identifier.uuidString }
                    if let index = index {
                        peripherals[index] = peripheral
                    } else {
                        peripherals.append(peripheral)
                    }
                    let tableRowStr = peripheral.name! + " rssi: " + RSSI.stringValue
                    globalVariables.allSensorList.append(tableRowStr)
                    mainViewController?.reloadTable()
                }
                else{
                    //sensor already in list, update rssi
                    print("[DEBUG] listed sensor \(peripheral.name ?? "nil") updated rssi: \(RSSI)");
                    let index = peripherals.index { $0.identifier.uuidString == peripheral.identifier.uuidString }
                    let tableRowStr = peripheral.name! + " rssi: " + RSSI.stringValue
                    globalVariables.allSensorList[index!] = tableRowStr
                    mainViewController?.reloadTable()
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[DEBUG] Connected to peripheral \(peripheral.name ?? "nil")")
        //initialise variables for new peripheral
        globalVariables.currentNumOfDevice += 1
        let sensor = dsvSensor.init(peripheral: peripheral)
        self.connectedSensors.append(sensor)
        sensor.peripheralRef.delegate = self
        sensor.peripheralRef.discoverServices([CBUUID(string: MDM_SERVICE_UUID)])
        //for failsafe sensors, discover update service
        sensor.peripheralRef.discoverServices([CBUUID(string: FWUPDATE_SERVICE_UUID)])
        self.peripheralCount += 1
        self.delegate?.bleDidConnectToPeripheral()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        var text = "[DEBUG] Disconnected from peripheral: \(peripheral.name ?? "nil")"
        
        if error != nil {
            text += ". Error: \(error.debugDescription)"
        }
        print(text)
        //remove all references
        globalVariables.currentNumOfDevice -= 1
        let targetDeviceInAllSensorList = (self.peripherals as AnyObject).index(of: peripheral)
        self.peripherals.remove(at: targetDeviceInAllSensorList)
        do{let sensor = try getSensorByName(name: peripheral.name!)
        if let index = self.connectedSensors.index(of: sensor){
            self.connectedSensors.remove(at: index)
        }
        self.peripheralCount -= 1
        //check if all sensors disconnected
        if self.connectedSensors.count == 0{
            print("[DEBUG] all sensors disconnected, navigate to main view")
            if var topController = UIApplication.shared.keyWindow?.rootViewController{
                while let presentedViewController = topController.presentedViewController{
                    topController = presentedViewController
                }
                let viewName = NSStringFromClass(topController.classForCoder)
                print("[DEBUG] current view: \(viewName), will push to mainView")
                switch viewName {
                case "DevAppBeta.BLEViewController":
                    topController.performSegue(withIdentifier: "BLEViewToMainView", sender: nil)
                    break
                case "DevAppBeta.FWUpgradeViewController":
                    topController.performSegue(withIdentifier: "updateViewToMainView", sender: nil)
                    break
                default:
                    break
                }
                globalVariables.allSensorList.removeAll()
                //uncomment next line to enable rescan
                //_ = self.startScanning(timeout: 5)
            }
            
        }
        self.delegate?.bleDidDisconenctFromPeripheral()}catch{return}
    }

    
    // MARK: CBPeripheral delegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print("[ERROR] Error discovering services. \(error.debugDescription)")
            return
        }
        
        print("[DEBUG] Found services for peripheral: \(peripheral.name ?? "nil")")
        for service in peripheral.services! {
            let theCharacteristics = [CBUUID(string: MDM_COMMAND_UUID),
                                      CBUUID(string: MDM_STREAMDATA_UUID),
                                      CBUUID(string: MDM_OFFLOAD_UUID),
                                      CBUUID(string: MDM_OFFLOADDATA_UUID),
                                      CBUUID(string: MDM_SESSIONID_UUID),
                                      CBUUID(string: MDM_SCALE_UUID),
                                      CBUUID(string: MDM_TIMECALCOEFF_UUID),
                                      CBUUID(string: FWUPDATE_CRC_INPUT_UUID),
                                      CBUUID(string: FWUPDATE_INPUT_CHAR_UUID),
                                      CBUUID(string: FWUPDATE_CONTROL_POINT_UUID),
                                      CBUUID(string: FWUPDATE_REVERT_UUID)
                                      ]
            peripheral.discoverCharacteristics(theCharacteristics, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if error != nil {
            print("[ERROR] Error discovering characteristics. \(error.debugDescription)")
            return
        }
        
        print("[DEBUG] Found characteristics for peripheral: \(peripheral.name ?? "nil")")
        do{let sensor = try getSensorByName(name: peripheral.name!)
        for characteristic in service.characteristics! {
            sensor.characteristics[characteristic.uuid.uuidString] = characteristic
            //check scale
            if characteristic.uuid.uuidString == MDM_SCALE_UUID{
                peripheral.readValue(for: characteristic)
            }
        }
        enableNotificationsFor(Peripheral: peripheral, enable: true)}catch{return}
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        do{let sensor = try getSensorByName(name: peripheral.name!)
        if characteristic.uuid.uuidString == MDM_COMMAND_UUID {
            print("[DEBUG] write response for ble command")
            if (self.BLEViewController?.isWaitingForStopStreaming)! {
                self.BLEViewController?.isWaitingForStopStreaming = false
            }
        }
        else if characteristic.uuid.uuidString == MDM_SCALE_UUID {
            print("[DEBUG] write response for ble config")
            sensor.peripheralRef.readValue(for: characteristic)
        }
        else if characteristic.uuid.uuidString == MDM_OFFLOADDATA_UUID {
            print("[DEBUG] write response for fetching lost data")
            sensor.peripheralRef.readValue(for: characteristic)
        }
        else if characteristic.uuid.uuidString == FWUPDATE_CONTROL_POINT_UUID {
            if sensor.FWUpgradeCompleted{
                print("[DEBUG] end of FWUpgrade")
                /* skip write descriptor for avoid crash
                let desc = CBMutableDescriptor.init(type: CBUUID.init(string: FWUPDATE_CCC_DESC_UUID), value: nil)
                let cmd = Data.init(bytes: [0x01])
                sensor.peripheralRef.writeValue(cmd, for: desc)*/
            }
            else{
                /*
                print("[DEBUG] start FW upgrade! write descriptor")
                let desc = CBMutableDescriptor.init(type: CBUUID.init(string: FWUPDATE_CCC_DESC_UUID), value: nil)
                let cmd = Data.init(bytes: [0x02, 0x00])
                sensor.peripheralRef.writeValue(cmd, for: desc)*/
                print("[DEBUG] start FW upgrade, sending start packet")
                let packet = Data.init(bytes: [0x00])
                let char = sensor.characteristics[FWUPDATE_INPUT_CHAR_UUID]
                peripheral.writeValue(packet, for: char!, type: .withResponse)
            }
        }
        else if characteristic.uuid.uuidString == FWUPDATE_CRC_INPUT_UUID {
            print("[DEBUG] write response for CRC, sleeping 3 secs")
            sleep(3)
            print("[DEBUG] sleep ends, write Control point")
            sensor.FWUpgradeCompleted = true
            let data = Data.init(bytes: [0x00, 0x00, 0x00])
            let char = sensor.characteristics[FWUPDATE_CONTROL_POINT_UUID]
            peripheral.writeValue(data, for: char!, type: .withResponse)
        }
        else if characteristic.uuid.uuidString == FWUPDATE_INPUT_CHAR_UUID {
            print("[DEBUG] write response for packet sent success")
            if sensor.upCounters == 256{
                sensor.upCounters = 1
            }
            if sensor.FWWriteCounter + globalVariables.maxTransferUnit > FWBuf.count{
                if sensor.FWUpgradeShouldSendCRC{
                    sensor.FWUpgradeShouldSendCRC = false
                    let crc32Calculator = CRC32.init(data: Data.init(bytes: FWBuf))
                    print("[DEBUG] sending crc, calculated as \(crc32Calculator.hashValue)")
                    let data = Data.init(bytes: crc32Calculator.crc.toBytes)
                    let char = sensor.characteristics[FWUPDATE_CRC_INPUT_UUID]
                    peripheral.writeValue(data, for: char!, type: .withResponse)
                    
                }
                else{
                    print("[DEBUG] sending last byte")
                    var packet_array = Array.init(repeating: UInt8(0), count: globalVariables.maxTransferUnit + 1)
                    let len = FWBuf.count - sensor.FWWriteCounter
                    packet_array[0] = UInt8(sensor.upCounters)
                    packet_array[1...len] = FWBuf[sensor.FWWriteCounter...FWBuf.count - 1]
                    let packet = Data.init(bytes: packet_array)
                    peripheral.writeValue(packet, for: characteristic, type: .withResponse)
                    sensor.FWUpgradeShouldSendCRC = true

                }
            }
            else {
                let packet_array = [UInt8(sensor.upCounters)] + FWBuf[sensor.FWWriteCounter...sensor.FWWriteCounter + globalVariables.maxTransferUnit - 1]
                let packet = Data.init(bytes: packet_array)
                let percentageValue = Float(sensor.FWWriteCounter/self.FWBuf.count)
                self.FWUpgradeViewController?.updateFWProgressBar.setProgress(percentageValue, animated: true)
                self.FWUpgradeViewController?.updateFWProgressPercentageLabel.text = String(Int(percentageValue)) + "%"
                print("[DEBUG] FWUpgradeStep: \(sensor.FWWriteCounter)/\(self.FWBuf.count), upCounter: \(sensor.upCounters), length: \(packet.count)")
                peripheral.writeValue(packet, for: characteristic, type: .withResponse)
                sensor.upCounters += 1
                sensor.FWWriteCounter += globalVariables.maxTransferUnit
            }
        }}catch{return}
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let timeIphone = UInt32(CACurrentMediaTime()*1000)
        print("[DEBUG] sensor: \(peripheral.name ?? "nil") did update value, at time: \(timeIphone)")
        if error != nil {
            print("[ERROR] Error updating value. \(error.debugDescription)")
            return
        }
        do{let sensor = try getSensorByName(name: peripheral.name!)
        if characteristic.uuid.uuidString == MDM_STREAMDATA_UUID {
            self.bleStreamingHandler(peripheral: peripheral, characteristic: characteristic, timeIphone: timeIphone)
        }
        else if characteristic.uuid.uuidString == FWUPDATE_INPUT_CHAR_UUID{
            if(characteristic.value?.count == 5){
                if(characteristic.value![0] != 0){
                    print("[DEBUG] transfer error code 0 received")
                }
            }
        }
        else if characteristic.uuid.uuidString == MDM_OFFLOADDATA_UUID {
            bleOffloadingHandler(peripheral: peripheral, characteristic: characteristic)
        }
        else if characteristic.uuid.uuidString == MDM_SCALE_UUID {
            if characteristic.value != nil{
                let charValue = [UInt8](characteristic.value!)
                print("[DEBUG] accelerometer scale read success, value = \(charValue[3]), mag freq \(charValue[2])")
                if charValue.count >= 8{
                    switch charValue[0] {
                    case 4:
                        sensor.acc_gyro_freq = 5
                        break
                    case 5:
                        sensor.acc_gyro_freq = 4
                        break
                    case 10:
                        sensor.acc_gyro_freq = 3
                        break
                    case 21:
                        sensor.acc_gyro_freq = 2
                        break
                    case 55:
                        sensor.acc_gyro_freq = 1
                        break
                    case 111:
                        sensor.acc_gyro_freq = 0
                        break
                    default:
                        break
                    }
                    switch charValue[1] {
                    case 1:
                        sensor.magFreq = 0
                        break
                    case 2:
                        sensor.magFreq = 1
                        break
                    case 4:
                        sensor.magFreq = 2
                        break
                    case 8:
                        sensor.magFreq = 3
                        break
                    case 12:
                        sensor.magFreq = 4
                        break
                    case 16:
                        sensor.magFreq = 5
                        break
                    default:
                        break
                    }
                    switch charValue[3] {
                    case 1:
                        sensor.accScales = 1
                        break
                    case 2:
                        sensor.accScales = 2
                        break
                    case 3:
                        sensor.accScales = 3
                        break
                    case 4:
                        sensor.accScales = 4
                        break
                    default:
                        break
                    }
                    switch charValue[7] {
                    case 1:
                        sensor.emgFreq = 1
                        break
                    case 2:
                        sensor.emgFreq = 2
                        break
                    case 0:
                        sensor.emgFreq = 0
                        break
                    default:
                        break
                    }
                }
                
            }
        }}catch{return}
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        self.RSSICompletionHandler?(RSSI, error as NSError?)
        self.RSSICompletionHandler = nil
    }
    
    //ble update value handlers
    func bleOffloadingHandler(peripheral: CBPeripheral, characteristic: CBCharacteristic){
        
        self.delegate?.bleDidReceiveData(data: characteristic.value! as NSData)
        let datavalue = characteristic.value
        let strvalue = datavalue?.hexEncodedString()
        //update status bar to see data coming, comment to accelerate offload
        self.BLEViewController?.updateStreamDataLbl(value: strvalue! + ", from device: " + peripheral.name!)
        do{let sensor = try getSensorByName(name: peripheral.name!)
        if(sensor.isOffloadFinished) {
            //lost data fetched response
            print("[DEBUG] lost data resent")
            let datavalue = characteristic.value
            let strvalue = datavalue?.hexEncodedString()
            self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
            sensor.offloadStrings += strvalue!
            if sensor.fetchIndices <= sensor.lostSeqNums.count - 1 {
                // not finished fetching
                let i = sensor.lostSeqNums[sensor.fetchIndices]
                sensor.fetchIndices += 1
                var cmd_array = [UInt8]()
                cmd_array.append(3)
                cmd_array.append(UInt8(i / 256))
                cmd_array.append(UInt8(i % 256))
                let cmd = Data(bytes: cmd_array)
                guard let char = sensor.characteristics[MDM_OFFLOADDATA_UUID] else {return}
                sensor.peripheralRef.writeValue(cmd, for: char, type: .withResponse)
            }
            else {
                //finished fetching, write to file
                print("[DEBUG] data offload complete, lost packets: \(sensor.lostSeqNums.count), resend successful")
                globalVariables.appStatus = "offloadComplete"
                self.BLEViewController?.updateStatus(value: "offloadComplete, lost packets successfully collected")
                globalVariables.FileHandler.writeFile(filename: sensor.offloadFileNames, text: sensor.offloadStrings)
                sensor.isOffloadCompleted = true
                var completed = true
                for sensor in self.connectedSensors{
                    if !sensor.isOffloadCompleted{
                        completed = false
                        break
                    }
                }
                if completed{
                    self.BLEViewController?.dismissOffloadSpinner()
                    let offloadEndTime = CACurrentMediaTime()
                    let offloadDuration = offloadEndTime - self.timeOffloadStarted
                    self.BLEViewController?.showOffloadCompleteAlertWithDuration(duration: offloadDuration)
                }
            }
        }
        else if (strvalue?.hasPrefix("03ffff"))!{
            
            //end of offloading, get lost packets
            sensor.isOffloadFinished = true
            if !sensor.lostSeqNums.isEmpty {
                print("[DEBUG] end of offloading, lost packet fetching, total: \(sensor.lostSeqNums.count)")
                let i = sensor.lostSeqNums[sensor.fetchIndices]
                sensor.fetchIndices += 1
                var cmd_array = [UInt8]()
                cmd_array.append(3)
                cmd_array.append(UInt8(i / 256))
                cmd_array.append(UInt8(i % 256))
                let cmd = Data(bytes: cmd_array)
                guard let char = sensor.characteristics[MDM_OFFLOADDATA_UUID] else {return}
                sensor.peripheralRef.writeValue(cmd, for: char, type: .withResponse)
            }
            else {
                print("[DEBUG] offload completed with no lost packet")
                //write to storage
                globalVariables.appStatus = "offloadComplete"
                self.BLEViewController?.updateStatus(value: "offloadComplete, no lost packets")
                globalVariables.FileHandler.writeFile(filename: sensor.offloadFileNames, text: sensor.offloadStrings)
                sensor.isOffloadCompleted = true
                var completed = true
                for sensor in self.connectedSensors{
                    if !sensor.isOffloadCompleted{
                        completed = false
                        break
                    }
                }
                if completed{
                    self.BLEViewController?.dismissOffloadSpinner()
                    let offloadEndTime = CACurrentMediaTime()
                    let offloadDuration = offloadEndTime - self.timeOffloadStarted
                    self.BLEViewController?.showOffloadCompleteAlertWithDuration(duration: offloadDuration)
                }
            }
            
        }
        else{
            //check if lost packet
            let currentSeqNum: UInt16 = UInt16((datavalue?[1])!) * 256 + UInt16((datavalue?[2])!)
            if ((currentSeqNum == 0) || ((currentSeqNum - sensor.lastSeqNums) == 1)){
                //no lost packet
                sensor.lastSeqNums = currentSeqNum
            }
            else{
                var gap = UInt16(currentSeqNum) - UInt16(sensor.lastSeqNums)
                gap -= 1
                print("[DEBUG] lost packet detected: at index \(currentSeqNum), num: \(gap)")
                for i in 1...gap {
                    sensor.lostSeqNums.append(currentSeqNum - i)
                }
                sensor.lastSeqNums = currentSeqNum
            }
            //append offload string
            sensor.offloadStrings += strvalue!
        }}catch{return}
    }
    
    func bleStreamingHandler(peripheral: CBPeripheral,characteristic: CBCharacteristic, timeIphone: UInt32){
        self.delegate?.bleDidReceiveData(data: characteristic.value! as NSData)
        do{let sensor = try getSensorByName(name: peripheral.name!)
        let datavalue = characteristic.value
        print("[DEBUG] streamed data length: \(datavalue?.count ?? 0)")
        if ((datavalue?.count == 23 || datavalue?.count == 20) && self.BLEViewController != nil){
            //normal streaming
            //prompt for confirm streaming status on BLEViewController
            self.BLEViewController?.confirmStreamingState()
            //get data
            let strvalue = datavalue?.hexEncodedString()
            //self.streamStrings[targetDevice] += strvalue!
            globalVariables.FileHandler.writeFile(filename: sensor.streamFileNames, text: strvalue! + String(timeIphone))
            //update status bar to see data coming, comment to accelerate offload
            self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
            
            if (self.BLEViewController?.viewcontrollerShouldShowPlot)!{
                //process and plot
                let sensorData = [UInt8](datavalue!)
                
                let offset = 0 //2 for v6c
                //Process ACC
                let Ax = UInt16(sensorData[1+offset]) << 8 | UInt16(sensorData[0+offset])
                let Ax_signed:Int16 = Int16(bitPattern: Ax)
                let fax = Double(Ax_signed) / 8192.0 * Double(globalVariables.accScaleArray[sensor.accScales])!
                let Ay = UInt16(sensorData[3+offset]) << 8 | UInt16(sensorData[2+offset])
                let Ay_signed:Int16 = Int16(bitPattern: Ay)
                let fay = Double(Ay_signed) / 8192.0 * Double(globalVariables.accScaleArray[sensor.accScales])!
                let Az = UInt16(sensorData[5+offset]) << 8 | UInt16(sensorData[4+offset])
                let Az_signed:Int16 = Int16(bitPattern: Az)
                let faz = Double(Az_signed) / 8192.0 * Double(globalVariables.accScaleArray[sensor.accScales])!
                //print("[DEBUG] streaming accelerometer value: \(fax) \(fay) \(faz)")
                
                //Process GYRO
                let Gx = UInt16(sensorData[7+offset]) << 8 | UInt16(sensorData[6+offset])
                let Gx_signed:Int16 = Int16(bitPattern: Gx)
                let fgx = Double(Gx_signed) * 0.00762939453125
                let Gy = UInt16(sensorData[9+offset]) << 8 | UInt16(sensorData[8+offset])
                let Gy_signed:Int16 = Int16(bitPattern: Gy)
                let fgy = Double(Gy_signed) * 0.00762939453125
                let Gz = UInt16(sensorData[11+offset]) << 8 | UInt16(sensorData[10+offset])
                let Gz_signed:Int16 = Int16(bitPattern: Gz)
                let fgz = Double(Gz_signed) * 0.00762939453125
                //print("[DEBUG] streaming gyroscope value: \(fgx) \(fgy) \(fgz)")
                
                //Process MAG
                var fmx = 0.0
                var fmy = 0.0
                var fmz = 0.0
                var femg = 0.0
                if(sensorData[0] == 0){
                    let Mx = UInt16(sensorData[13+offset]) << 8 | UInt16(sensorData[12+offset])
                    let Mx_signed:Int16 = Int16(bitPattern: Mx)
                    fmx = Double(Mx_signed)
                    let My = UInt16(sensorData[15+offset]) << 8 | UInt16(sensorData[14+offset])
                    let My_signed:Int16 = Int16(bitPattern: My)
                    fmy = Double(My_signed)
                    let Mz = UInt16(sensorData[17+offset]) << 8 | UInt16(sensorData[16+offset])
                    let Mz_signed:Int16 = Int16(bitPattern: Mz)
                    fmz = Double(Mz_signed)
                    //print("[DEBUG] streaming magnetometer value: \(fmx) \(fmy) \(fmz)")
                }
                else if(sensorData.count == 14+offset+1){
                    //Process EMG
                    let EMG = UInt32(sensorData[14+offset]) << 16 | UInt32(sensorData[13+offset]) << 8 | UInt32(sensorData[12+offset])
                    let EMG_signed:Int32 = Int32(bitPattern: EMG)
                    femg = Double(EMG_signed)/16777216*1.6
                    print("[DEBUG] streaming EMG value: \(femg)")
                }
                //Perform attitude estimate
                
                if globalVariables.EKFshouldPerformAttitudeEstimate{
                    let deltaT = (CACurrentMediaTime() - self.lastStreamingTime)
                    self.lastStreamingTime = CACurrentMediaTime()
                    //let time1 = CACurrentMediaTime()
                    let q = self.attitudeEstimator?.EKFProcessStepWithData(accx: fax, accy: fay, accz: faz, gyrox: fgx, gyroy: fgy, gyroz: fgz, deltaT: deltaT)
                    let euler = self.attitudeEstimator?.quat2euler(quat:q!)
                    print("[Attitude Estimate] \(q ?? [1.0, 0.0, 0.0, 0.0]) deltaT: \(deltaT),euler: \(euler ?? [0.0, 0.0, 0.0])")
                    self.FWUpgradeViewController?.updateSceneWithQuat(Quat:q!)
                    //let duration = CACurrentMediaTime() - time1
                    //print("[TEMPDEBUG] timeElapsed: \(duration * 1000) ms")
                }
                
                //check data source type
                var fx:Double
                var fy:Double
                var fz:Double
                switch self.BLEViewController!.graphViewDataType {
                case 1:
                    fx = fgx
                    fy = fgy
                    fz = fgz
                    break
                case 2:
                    fx = fmx
                    fy = fmy
                    fz = fmz
                    break
                case 3:
                    fx = femg
                    fy = 0.0
                    fz = 0.0
                    break
                default:
                    fx = fax
                    fy = fay
                    fz = faz
                    break
                }
                //show plot only for first device
                if sensor == self.connectedSensors[0]{
                    if (self.BLEViewController?.arrayCounter)! < 40 {
                        self.BLEViewController?.Ax_plot[(self.BLEViewController?.arrayCounter)!] = fx
                        self.BLEViewController?.Ay_plot[(self.BLEViewController?.arrayCounter)!] = fy
                        self.BLEViewController?.Az_plot[(self.BLEViewController?.arrayCounter)!] = fz
                        self.BLEViewController?.arrayCounter += 1
                    }
                    else{
                        for i in 0...38{
                            self.BLEViewController?.Ax_plot[i] = (self.BLEViewController?.Ax_plot[i + 1])!
                            self.BLEViewController?.Ay_plot[i] = (self.BLEViewController?.Ay_plot[i + 1])!
                            self.BLEViewController?.Az_plot[i] = (self.BLEViewController?.Az_plot[i + 1])!
                        }
                        self.BLEViewController?.Ax_plot[39] = fx
                        self.BLEViewController?.Ay_plot[39] = fy
                        self.BLEViewController?.Az_plot[39] = fz
                    }
                    let curTime = UInt32(CACurrentMediaTime()*1000)
                    let gap = curTime - self.lastReloadTime
                    if (gap > self.reloadGap){
                        //reload graph every 100ms
                        self.lastReloadTime = curTime
                        self.BLEViewController?.graph.reloadData()
                    }
                }
            }
        }
        else if datavalue?.count == 6{
            //monitor starting - V6b synchronised monitoring
            if self.connectedSensors.count == 2{
                print("[DEBUG] synchronised monitoring streaming period")
                let sensorValue = [UInt8](datavalue!)
                var timeSensor = UInt32(sensorValue[3]) << 24 | UInt32(sensorValue[2]) << 16
                timeSensor = timeSensor | (UInt32(sensorValue[1]) << 8 | UInt32(sensorValue[0]))
                if (self.syncTimeArray.count==0 && peripheral.name == self.connectedSensors[0].name){
                    print("[DEBUG] timestamp from device 1 (\(peripheral.name ?? "nil")) streamed timestamp: \(timeSensor) iphone time: \(timeIphone)")
                    self.syncTimeArray.append(timeSensor)
                    self.syncTimeArray.append(timeIphone)
                }
                else if(self.syncTimeArray.count==2 && peripheral.name == self.connectedSensors[1].name){
                    print("[DEBUG] timestamp from device 2 (\(peripheral.name ?? "nil")) streamed timestamp: \(timeSensor) iphone time: \(timeIphone)")
                    self.syncTimeArray.append(timeSensor)
                    self.syncTimeArray.append(timeIphone)
                }
                else if(self.syncTimeArray.count==4){
                    let delay = Double(syncTimeArray[3]) - Double(syncTimeArray[1]) - (Double(syncTimeArray[2]) - Double(syncTimeArray[0]))
                    let delayStr = "end of time synchronisation, the second sensor (\(self.connectedSensors[1].name)) started \(delay)ms later than the first sensor (\(self.connectedSensors[0].name))"
                    print("[DEBUG] \(delayStr)")
                    if(self.FWUpgradeViewController != nil){
                        if ((self.FWUpgradeViewController?.isViewLoaded)! && ((self.FWUpgradeViewController?.view.window) != nil)) {
                            // viewController is visible
                            self.FWUpgradeViewController?.syncMonitorDidCalculateDelay(delay: delay, message: delayStr)
                        }
                    }
                    self.syncTimeArray.append(0)
                }
            }
        }
        else if datavalue?.count == 4{
            if self.isServingStreamStart{
                //time calibration streamming period
                print("[DEBUG] streaming for time calibration")
                let sensorValue = [UInt8](datavalue!)
                var timeSensor = UInt32(sensorValue[3]) << 24 | UInt32(sensorValue[2]) << 16
                timeSensor = timeSensor | (UInt32(sensorValue[1]) << 8 | UInt32(sensorValue[0]))
                if(globalVariables.FileHandler.fileExist(filename: sensor.timeCalLogFileNames)){
                    //check if app restarted
                    let timeCalStr = "\(timeIphone)+\(timeSensor)"
                    sensor.lastTimeCalStr = timeCalStr
                }
                else{
                    print("[DEBUG] time calibration log file does not exist, creating...，iphone time: \(timeIphone), sensor time: \(timeSensor)")
                    let timeCalStr = "\(timeIphone)+\(timeSensor)"
                    globalVariables.FileHandler.writeFile(filename: sensor.timeCalLogFileNames, text: timeCalStr)
                    self.isServingStreamStart = false
                }
            }
        }}catch{return}
    }
}
