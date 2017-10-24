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

//extend data to get hex string value
extension Data{
    func hexEncodedString() -> String{
        return map { String(format: "%02hhx", $0)}.joined()
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

    var delegate: BLEDelegate?
    var mainViewController: ViewController?
    var BLEViewController: BLEViewController?
    var FWUpgradeViewController: FWUpgradeViewController?
    var attitudeEstimator: AttitudeEstimator?
    private      var lastStreamingTime      = 0.0
    private      var isInitialised          = false
    private      var centralManager:        CBCentralManager!
    private      var activePeripherals      = [CBPeripheral]()
    private      var characteristics        = [[String : CBCharacteristic]]()
    private      var data:                  NSMutableData?
    private(set) var peripherals            = [CBPeripheral]()
    private      var RSSICompletionHandler: ((NSNumber?, NSError?) -> ())?
    //time for checking reloading gragh
    private      var lastReloadTime:UInt32  = 0
    private      var reloadGap:UInt32       = 100
    //string for saving all offloaded data
    private      var offloadStrings         = [String]()
    //string for saving all streamed data
    // private      var streamStrings          = [String]()
    //for fetching specific lost packet
    private      var fetchIndices           = [Int]()
    //bool flag for checking offload finished for fetching lost data
    private      var isOffloadFinished      = [Bool]()
    //bool flag for checking offload all finished including getting lost data
    private      var isOffloadCompleted     = [Bool]()
    //var for calculating offload time
    private      var timeOffloadStarted     = 0.0
    //accelerometer scale
    private      var accScales              = [Double]()
    //current connected peripheral count
    private      var peripheralCount        = 0
    //for checking packet loss
    private      var lastSeqNums            = [UInt16]()
    private      var lostSeqNums            = [[UInt16]]()
    //file names for streaming and offloading
    private      var offloadFileNames       = [String]()
    private      var streamFileNames        = [String]()
    private      var timeCalLogFileNames    = [String]()
    //[DEV] temp variable for synchronised monitoring
    private      var syncTimeArray          = [UInt32]()
    //[DEV] temp variable for time Calibration
    private      var lastTimeCalStr         = [String]()
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
        
        // CBCentralManagerScanOptionAllowDuplicatesKey
        
        Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(BLEController.scanTimeout), userInfo: nil, repeats: false)
        
        //let services:[CBUUID] = [CBUUID(string: MDM_SERVICE_UUID)]
        //self.centralManager.scanForPeripherals(withServices: services, options: nil)
        self.centralManager.scanForPeripherals(withServices: nil, options: nil)
        
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
        if (self.centralManager.state != .poweredOn) || (self.activePeripherals.count == 0) {
            
            print("[ERROR] Couldn´t disconnect from peripheral")
            return false
        }
        for i in 0...self.activePeripherals.count-1{
            self.centralManager.cancelPeripheralConnection(self.activePeripherals[i])
        }
        return true
    }

    func enableNotificationsFor(Peripheral: CBPeripheral, enable: Bool) {
        print("[DEBUG] enable notification for sensor: \(Peripheral.name ?? "nil")")
        let targetDevice = (self.activePeripherals as AnyObject).index(of: Peripheral)
        guard let char_stream = self.characteristics[targetDevice][MDM_STREAMDATA_UUID] else { return }
        Peripheral.setNotifyValue(enable, for: char_stream)
        guard let char_offload = self.characteristics[targetDevice][MDM_OFFLOADDATA_UUID] else { return }
        Peripheral.setNotifyValue(enable, for: char_offload)
    }
 
    func readRSSI(completion: @escaping (_ RSSI: NSNumber?, _ error: NSError?) -> ()) {
        self.RSSICompletionHandler = completion
        for i in 0...self.activePeripherals.count-1{
            self.activePeripherals[i].readRSSI()
        }
    }
    
    func startStreaming(){
        let data = Data(bytes: [0x01])
        self.lastStreamingTime = CACurrentMediaTime()
        for i in 0...self.activePeripherals.count-1{
            guard let char = self.characteristics[i][MDM_COMMAND_UUID] else {return}
            self.activePeripherals[i].writeValue(data, for: char, type: .withResponse)
            let filename = (self.activePeripherals[i].name)! + "_stream.txt"
            self.streamFileNames.append(filename)
        }
    }
    
    func stopStreaming(){
        let data = Data(bytes: [0x02])
        for i in 0...self.activePeripherals.count-1{
            guard let char = self.characteristics[i][MDM_COMMAND_UUID] else {return}
            self.activePeripherals[i].writeValue(data, for: char, type: .withResponse)
            globalVariables.appStatus = "streamComplete"
            self.BLEViewController?.updateStatus(value: "streamComplete, writing to file")
            //switch to write file instantly when streaming
            //globalVariables.FileHandler.writeFile(filename: self.streamFileNames[i], text: self.streamStrings[i])
        }
        
    }
    
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
        let n = self.activePeripherals.count-1
        //check flag for running or normal monitoring
        var data = Data(bytes: [0x03])
        if !globalVariables.monitorTypeFlag {
            data = Data(bytes: [0x04])
        }
        for i in 0...n{
            //remove previous synch monitor results
            self.syncTimeArray.removeAll()
            guard let char = self.characteristics[i][MDM_SESSIONID_UUID] else {return false}
            self.activePeripherals[i].writeValue(sessionID, for: char, type: .withResponse)

            guard let charCommand = self.characteristics[i][MDM_COMMAND_UUID] else {return false}
            self.activePeripherals[i].writeValue(data, for: charCommand, type: .withResponse)
        }
        return true
    }
    
    func offloadCompressedData(){
        self.isOffloadFinished.removeAll(keepingCapacity: false)
        self.isOffloadCompleted.removeAll(keepingCapacity: false)
        self.lostSeqNums.removeAll(keepingCapacity: false)
        self.fetchIndices.removeAll(keepingCapacity: false)
        self.offloadFileNames.removeAll(keepingCapacity: false)
        self.timeOffloadStarted = CACurrentMediaTime()
        for i in 0...self.activePeripherals.count-1{
            self.isOffloadFinished.append(false)
            self.isOffloadCompleted.append(false)
            self.lostSeqNums.append([])
            self.fetchIndices.append(0)
            let filename = (self.activePeripherals[i].name)! + "_offload.txt"
            self.offloadFileNames.append(filename)
            let data = Data(bytes: [0x06])
            guard let char = self.characteristics[i][MDM_OFFLOAD_UUID] else {return}
            self.activePeripherals[i].writeValue(data, for: char, type: .withResponse)
            print("[DEBUG] start offloading")
        }
    }
    
    func eraseDevices() -> Bool{
    //erase device for FW Upgrade
        let data = Data(bytes: [0x00,0x00,0x00,0x02])
        for i in 0...self.activePeripherals.count-1{
            guard let char = self.characteristics[i][MDM_SESSIONID_UUID] else {return false}
            self.activePeripherals[i].writeValue(data, for: char, type: .withResponse)
        }
        return true
    }
    
    //start time calibration
    func startTimeCalibration() -> Bool{
        let data = Data(bytes: [0x06])
        for i in 0...self.activePeripherals.count-1{
            guard let char = self.characteristics[i][MDM_COMMAND_UUID] else {return false}
            self.activePeripherals[i].writeValue(data, for: char, type: .withResponse)
            let filename = (self.activePeripherals[i].name)! + "_timeCalLog.txt"
            self.timeCalLogFileNames.append(filename)
            self.lastTimeCalStr.append("")
            if globalVariables.FileHandler.fileExist(filename: filename){
                globalVariables.FileHandler.deleteFile(filename: filename)
            }
        }
        return true
    }
    
    //stop time calibration
    func stopTimeCalibration() -> Bool{
        //check Log file
        for i in 0...self.activePeripherals.count-1{
            let filename = (self.activePeripherals[i].name)! + "_timeCalLog.txt"
            if !globalVariables.FileHandler.fileExist(filename: filename){
                print("[DEBUG] error, the sensor connected does not match time calibration log")
                return false
            }
        }
        //check if app has restarted in between
        if self.timeCalLogFileNames.count == 0{
            for i in 0...self.activePeripherals.count-1{
                let filename = (self.activePeripherals[i].name)! + "_timeCalLog.txt"
                self.timeCalLogFileNames.append(filename)
            }
        }
        //calculate and write coeffs
        for i in 0...self.activePeripherals.count-1{
            let tempStrStart = globalVariables.FileHandler.readFileAsString(filename: self.timeCalLogFileNames[i])
            let APPTimeStart = Int(tempStrStart.substring(to: (tempStrStart.range(of: "+")?.lowerBound)!))
            let APPTimeEnd = Int(self.lastTimeCalStr[i].substring(to: (lastTimeCalStr[i].range(of: "+")?.lowerBound)!))
            let SensorTimeStart = Int(tempStrStart.substring(from: (tempStrStart.range(of: "+")?.upperBound)!))
            let SensorTimeEnd = Int(self.lastTimeCalStr[i].substring(from: (self.lastTimeCalStr[i].range(of: "+")?.upperBound)!))
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
            print("[DEBUG] time cal coeff is calculated as \(coeff) from startStr: \(tempStrStart) and endStr: \(self.lastTimeCalStr[i])")
            let coeffData = Data(bytes: coeff)
            guard let char = self.characteristics[i][MDM_TIMECALCOEFF_UUID] else {return false}
            self.activePeripherals[i].writeValue(coeffData, for: char, type: .withResponse)
        }
        
        //stop streaming for all
        let data = Data(bytes: [0x07])
        for i in 0...self.activePeripherals.count-1{
            guard let char = self.characteristics[i][MDM_COMMAND_UUID] else {return false}
            self.activePeripherals[i].writeValue(data, for: char, type: .withResponse)
        }
        return true
    }
    
    //update FW
    func startUpdateFWWithFile(filename: String){
        self.FWBuf = globalVariables.FileHandler.openFWBinFile(filename: filename)
        print("[DEBUG] read Firmware Bin file, length: \(FWBuf.count), first and last values: \(FWBuf[0]), \(FWBuf[FWBuf.count-1])")
        let crc32Calculator = CRC32.init(data: Data.init(bytes: FWBuf))
        print("[DEBUG] crc is calculated as \(crc32Calculator.hashValue)")
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
            if ((peripheral.name?.hasPrefix("MDM-"))! && !globalVariables.allSensorList.contains(peripheral.name!)) {
                print("[DEBUG] Found sensor: \(peripheral.name ?? "nil") RSSI: \(RSSI)")
                let index = peripherals.index { $0.identifier.uuidString == peripheral.identifier.uuidString }
                if let index = index {
                    peripherals[index] = peripheral
                } else {
                    peripherals.append(peripheral)
                }
                globalVariables.allSensorList.append(peripheral.name!)
                mainViewController?.reloadTable()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[DEBUG] Connected to peripheral \(peripheral.name ?? "nil")")
        //initialise variables for new peripheral
        globalVariables.currentNumOfDevice += 1
        self.activePeripherals.append(peripheral)
        self.activePeripherals[self.peripheralCount].delegate = self
        self.activePeripherals[self.peripheralCount].discoverServices([CBUUID(string: MDM_SERVICE_UUID)])
        //for failsafe sensors, discover update service
        self.activePeripherals[self.peripheralCount].discoverServices([CBUUID(string: FWUPDATE_SERVICE_UUID)])
        self.accScales.append(1.0)
        self.offloadStrings.append("")
        //self.streamStrings.append("")
        self.lastSeqNums.append(0)
        self.characteristics.append([:])
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
        let targetDevice = (self.activePeripherals as AnyObject).index(of: peripheral)
        self.activePeripherals[targetDevice].delegate = nil
        self.activePeripherals.remove(at: targetDevice)
        self.accScales.remove(at: targetDevice)
        //self.streamStrings.remove(at: targetDevice)
        self.offloadStrings.remove(at: targetDevice)
        self.lastSeqNums.remove(at: targetDevice)
        if self.offloadFileNames.count > 0{
            self.offloadFileNames.remove(at: targetDevice)
            self.lostSeqNums.remove(at: targetDevice)
            self.isOffloadFinished.remove(at: targetDevice)
        }
        if self.streamFileNames.count > 0{
            self.streamFileNames.remove(at: targetDevice)
        }
        if self.timeCalLogFileNames.count > 0{
            self.timeCalLogFileNames.remove(at: targetDevice)
        }
        self.peripheralCount -= 1
        self.characteristics.remove(at: targetDevice)
        //check if all sensors disconnected
        if self.activePeripherals.count == 0{
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
                //rescan
                globalVariables.allSensorList.removeAll()
                _ = self.startScanning(timeout: 5)
                
            }
            
        }
        self.delegate?.bleDidDisconenctFromPeripheral()
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
                                      CBUUID(string: FWUPDATE_CONTROL_POINT_UUID)
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
        let targetDevice = (self.activePeripherals as AnyObject).index(of: peripheral)
        for characteristic in service.characteristics! {
            self.characteristics[targetDevice][characteristic.uuid.uuidString] = characteristic
            //check scale
            if characteristic.uuid.uuidString == MDM_SCALE_UUID{
                if characteristic.value != nil{
                    
                    let charValue = [UInt8](characteristic.value!)
                    print("[DEBUG] accelerometer scale read success, value = \(charValue[3])")
                    switch charValue[3] {
                    case 1:
                        self.accScales[targetDevice] = 0.5
                        break
                    case 2:
                        self.accScales[targetDevice] = 1.0
                        break
                    case 3:
                        self.accScales[targetDevice] = 2.0
                        break
                    case 4:
                        self.accScales[targetDevice] = 4.0
                        break
                    default:
                        break
                    }
                }
            }
        }
        enableNotificationsFor(Peripheral: peripheral, enable: true)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {

        if characteristic.uuid.uuidString == MDM_COMMAND_UUID {
            print("[DEBUG] write response for ble command")
            if (self.BLEViewController?.isWaitingForStopStreaming)! {
                self.BLEViewController?.isWaitingForStopStreaming = false
            }
        }
        else if characteristic.uuid.uuidString == MDM_OFFLOADDATA_UUID {
            let targetDevice = (self.activePeripherals as AnyObject).index(of: peripheral)
            print("[DEBUG] write response for fetching lost data")
            self.activePeripherals[targetDevice].readValue(for: characteristic)
        }
        
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let timeIphone = UInt32(CACurrentMediaTime()*1000)
        print("[DEBUG] sensor: \(peripheral.name ?? "nil") did update value, at time: \(timeIphone)")
        if error != nil {
            
            print("[ERROR] Error updating value. \(error.debugDescription)")
            return
        }
        let targetDevice = (self.activePeripherals as AnyObject).index(of: peripheral)
        if characteristic.uuid.uuidString == MDM_STREAMDATA_UUID {
            self.delegate?.bleDidReceiveData(data: characteristic.value! as NSData)
            let datavalue = characteristic.value
            print("[DEBUG] streamed data length: \(datavalue?.count ?? 0)")
            
            if datavalue?.count == 20{
                //normal streaming
                //prompt for confirm streaming status on BLEViewController
                self.BLEViewController?.confirmStreamingState()
                if(!self.streamFileNames.contains(peripheral.name! + "_stream.txt")){
                    let filename = (peripheral.name)! + "_stream.txt"
                    self.streamFileNames.append(filename)
                }
                //get data
                let strvalue = datavalue?.hexEncodedString()
                //self.streamStrings[targetDevice] += strvalue!
                globalVariables.FileHandler.writeFile(filename: self.streamFileNames[targetDevice], text: strvalue!)
                //update status bar to see data coming, comment to accelerate offload
                self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
                let sensorData = [UInt8](datavalue!)
                
                //Process ACC
                let Ax = UInt16(sensorData[1]) << 8 | UInt16(sensorData[0])
                let Ax_signed:Int16 = Int16(bitPattern: Ax)
                let fax = Double(Ax_signed) / 8192.0 * self.accScales[targetDevice]
                let Ay = UInt16(sensorData[3]) << 8 | UInt16(sensorData[2])
                let Ay_signed:Int16 = Int16(bitPattern: Ay)
                let fay = Double(Ay_signed) / 8192.0 * self.accScales[targetDevice]
                let Az = UInt16(sensorData[5]) << 8 | UInt16(sensorData[4])
                let Az_signed:Int16 = Int16(bitPattern: Az)
                let faz = Double(Az_signed) / 8192.0 * self.accScales[targetDevice]
                print("[DEBUG] streaming accelerometer value: \(fax) \(fay) \(faz)")
                
                //Process GYRO
                let Gx = UInt16(sensorData[7]) << 8 | UInt16(sensorData[6])
                let Gx_signed:Int16 = Int16(bitPattern: Gx)
                let fgx = Double(Gx_signed) * 0.00762939453125
                let Gy = UInt16(sensorData[9]) << 8 | UInt16(sensorData[8])
                let Gy_signed:Int16 = Int16(bitPattern: Gy)
                let fgy = Double(Gy_signed) * 0.00762939453125
                let Gz = UInt16(sensorData[11]) << 8 | UInt16(sensorData[10])
                let Gz_signed:Int16 = Int16(bitPattern: Gz)
                let fgz = Double(Gz_signed) * 0.00762939453125
                print("[DEBUG] streaming gyroscope value: \(fgx) \(fgy) \(fgz)")
                
                //Process MAG
                let Mx = UInt16(sensorData[13]) << 8 | UInt16(sensorData[12])
                let Mx_signed:Int16 = Int16(bitPattern: Mx)
                let fmx = Double(Mx_signed)
                let My = UInt16(sensorData[15]) << 8 | UInt16(sensorData[14])
                let My_signed:Int16 = Int16(bitPattern: My)
                let fmy = Double(My_signed)
                let Mz = UInt16(sensorData[17]) << 8 | UInt16(sensorData[16])
                let Mz_signed:Int16 = Int16(bitPattern: Mz)
                let fmz = Double(Mz_signed)
                print("[DEBUG] streaming magnetometer value: \(fmx) \(fmy) \(fmz)")
                
                //Perform attitude estimate
                if true{
                    let deltaT = (CACurrentMediaTime() - self.lastStreamingTime)
                    self.lastStreamingTime = CACurrentMediaTime()
                    let q = self.attitudeEstimator?.EKFProcessStepWithData(accx: fax, accy: fay, accz: faz, gyrox: fgx, gyroy: fgy, gyroz: fgz, deltaT: deltaT)
                    print("[Attitude Estimate] \(q)")
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
                default:
                    fx = fax
                    fy = fay
                    fz = faz
                    break
                }
                //show plot only for first device
                if targetDevice == 0{
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
            else if datavalue?.count == 6{
                //monitor starting - V6b synchronised monitoring
                if self.activePeripherals.count == 2{
                    print("[DEBUG] synchronised monitoring streaming period")
                    let sensorValue = [UInt8](datavalue!)
                    var timeSensor = UInt32(sensorValue[3]) << 24 | UInt32(sensorValue[2]) << 16
                    timeSensor = timeSensor | (UInt32(sensorValue[1]) << 8 | UInt32(sensorValue[0]))
                    if (self.syncTimeArray.count==0 && peripheral.name == self.activePeripherals[0].name){
                        print("[DEBUG] timestamp from device 1 (\(peripheral.name ?? "nil")) streamed timestamp: \(timeSensor) iphone time: \(timeIphone)")
                        self.syncTimeArray.append(timeSensor)
                        self.syncTimeArray.append(timeIphone)
                    }
                    else if(self.syncTimeArray.count==2 && peripheral.name == self.activePeripherals[1].name){
                        print("[DEBUG] timestamp from device 2 (\(peripheral.name ?? "nil")) streamed timestamp: \(timeSensor) iphone time: \(timeIphone)")
                        self.syncTimeArray.append(timeSensor)
                        self.syncTimeArray.append(timeIphone)
                    }
                    else if(self.syncTimeArray.count==4){
                        let delay = Double(syncTimeArray[3]) - Double(syncTimeArray[1]) - (Double(syncTimeArray[2]) - Double(syncTimeArray[0]))
                        let delayStr = "end of time synchronisation, the second sensor (\(self.activePeripherals[1].name ?? "nil")) started \(delay)ms later than the first sensor (\(self.activePeripherals[0].name ?? "nil"))"
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
                    if(globalVariables.FileHandler.fileExist(filename: self.timeCalLogFileNames[targetDevice])){
                        //check if app restarted
                        if self.lastTimeCalStr.count == 0{
                            for _ in 0...self.activePeripherals.count-1{
                                self.lastTimeCalStr.append("")
                            }
                        }
                        let timeCalStr = "\(timeIphone)+\(timeSensor)"
                        lastTimeCalStr[targetDevice] = timeCalStr
                        
                    }
                    else{
                        print("[DEBUG] time calibration log file does not exist, creating...，iphone time: \(timeIphone), sensor time: \(timeSensor)")
                        let timeCalStr = "\(timeIphone)+\(timeSensor)"
                        globalVariables.FileHandler.writeFile(filename: self.timeCalLogFileNames[targetDevice], text: timeCalStr)
                        self.isServingStreamStart = false
                    }
                }
            }
        }
        else if characteristic.uuid.uuidString == MDM_OFFLOADDATA_UUID {
            self.delegate?.bleDidReceiveData(data: characteristic.value! as NSData)
            let datavalue = characteristic.value
            let strvalue = datavalue?.hexEncodedString()
            //update status bar to see data coming, comment to accelerate offload
            self.BLEViewController?.updateStreamDataLbl(value: strvalue! + ", from device: " + peripheral.name!)
            if(self.isOffloadFinished[targetDevice]) {
                //lost data fetched response
                print("[DEBUG] lost data resent")
                let datavalue = characteristic.value
                let strvalue = datavalue?.hexEncodedString()
                self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
                self.offloadStrings[targetDevice] += strvalue!
                if self.fetchIndices[targetDevice] <= self.lostSeqNums[targetDevice].count - 1 {
                    // not finished fetching
                    let i = self.lostSeqNums[targetDevice][self.fetchIndices[targetDevice]]
                    self.fetchIndices[targetDevice] += 1
                    var cmd_array = [UInt8]()
                    cmd_array.append(3)
                    cmd_array.append(UInt8(i / 256))
                    cmd_array.append(UInt8(i % 256))
                    let cmd = Data(bytes: cmd_array)
                    guard let char = self.characteristics[targetDevice][MDM_OFFLOADDATA_UUID] else {return}
                    self.activePeripherals[targetDevice].writeValue(cmd, for: char, type: .withResponse)
                }
                else {
                    //finished fetching, write to file
                    print("[DEBUG] data offload complete, lost packets: \(self.lostSeqNums.count), resend successful")
                    globalVariables.appStatus = "offloadComplete"
                    self.BLEViewController?.updateStatus(value: "offloadComplete, lost packets successfully collected")
                    globalVariables.FileHandler.writeFile(filename: self.offloadFileNames[targetDevice], text: self.offloadStrings[targetDevice])
                    self.isOffloadCompleted[targetDevice] = true
                    if !self.isOffloadCompleted.contains(false){
                        self.BLEViewController?.dismissOffloadSpinner()
                        let offloadEndTime = CACurrentMediaTime()
                        let offloadDuration = offloadEndTime - self.timeOffloadStarted
                        self.BLEViewController?.showOffloadCompleteAlertWithDuration(duration: offloadDuration)
                    }
                }
            }
            else if (strvalue?.hasPrefix("03ffff"))!{
                
                //end of offloading, get lost packets
                self.isOffloadFinished[targetDevice] = true
                if !self.lostSeqNums[targetDevice].isEmpty {
                    print("[DEBUG] end of offloading, lost packet fetching, total: \(self.lostSeqNums.count)")
                    print("[TEMP] \(targetDevice), \(self.lostSeqNums.count), \(self.fetchIndices.count)")
                    print("[TEMP] \(self.lostSeqNums[targetDevice].count), \(self.fetchIndices[targetDevice])")
                    let i = self.lostSeqNums[targetDevice][self.fetchIndices[targetDevice]]
                    self.fetchIndices[targetDevice] += 1
                    var cmd_array = [UInt8]()
                    cmd_array.append(3)
                    cmd_array.append(UInt8(i / 256))
                    cmd_array.append(UInt8(i % 256))
                    let cmd = Data(bytes: cmd_array)
                    guard let char = self.characteristics[targetDevice][MDM_OFFLOADDATA_UUID] else {return}
                    self.activePeripherals[targetDevice].writeValue(cmd, for: char, type: .withResponse)
                }
                else {
                    print("[DEBUG] offload completed with no lost packet")
                    //write to storage
                    globalVariables.appStatus = "offloadComplete"
                    self.BLEViewController?.updateStatus(value: "offloadComplete, no lost packets")
                    globalVariables.FileHandler.writeFile(filename: self.offloadFileNames[targetDevice], text: self.offloadStrings[targetDevice])
                    self.isOffloadCompleted[targetDevice] = true
                    if !self.isOffloadCompleted.contains(false){
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
                if ((currentSeqNum == 0) || ((currentSeqNum - self.lastSeqNums[targetDevice]) == 1)){
                    //no lost packet
                    self.lastSeqNums[targetDevice] = currentSeqNum
                }
                else{
                    var gap = UInt16(currentSeqNum) - UInt16(self.lastSeqNums[targetDevice])
                    gap -= 1
                    print("[DEBUG] lost packet detected: at index \(currentSeqNum), num: \(gap)")
                    for i in 1...gap {
                        self.lostSeqNums[targetDevice].append(currentSeqNum - i)
                    }
                    self.lastSeqNums[targetDevice] = currentSeqNum
                }
                //append offload string
                self.offloadStrings[targetDevice] += strvalue!
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        self.RSSICompletionHandler?(RSSI, error as NSError?)
        self.RSSICompletionHandler = nil
    }

}
