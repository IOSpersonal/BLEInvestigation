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
    
    let MDM_SERVICE_UUID            = "00000005-0008-A8BA-E311-F48C90364D99"
    let MDM_COMMAND_UUID            = "00000006-0008-A8BA-E311-F48C90364D99"
    let MDM_SCALE_UUID              = "0000000A-0008-A8BA-E311-F48C90364D99"
    let MDM_SESSIONID_UUID          = "0000000C-0008-A8BA-E311-F48C90364D99"
    let MDM_STREAMDATA_UUID         = "00000010-0008-A8BA-E311-F48C90364D99"
    let MDM_OFFLOAD_UUID            = "00000011-0008-A8BA-E311-F48C90364D99"
    let MDM_OFFLOADDATA_UUID        = "00000012-0008-A8BA-E311-F48C90364D99"

    var delegate: BLEDelegate?
    var mainViewController: ViewController?
    var BLEViewController: BLEViewController?
    
    private      var centralManager:        CBCentralManager!
    private      var activePeripherals      = [CBPeripheral]()
    private      var characteristics        = [[String : CBCharacteristic]]()
    private      var data:                  NSMutableData?
    private(set) var peripherals            = [CBPeripheral]()
    private      var RSSICompletionHandler: ((NSNumber?, NSError?) -> ())?
    //string for saving all offloaded data
    private      var offloadStrings         = [String]()
    //string for saving all streamed data
    private      var streamStrings          = [String]()
    //for fetching specific lost packet
    private      var fetchIndices           = [Int]()
    //bool flag for checking offload finished for fetching lost data
    private      var isOffloadFinished      = [Bool]()
    //bool flag for checking offload all finished including getting lost data
    private      var isOffloadCompleted      = [Bool]()
    //accelerometer scale
    private      var accScales              = [Double]()
    private      var peripheralCount        = 0
    //for checking packet loss
    private      var lastSeqNums            = [UInt16]()
    private      var lostSeqNums            = [[UInt16]]()
    //file names for streaming and offloading
    private      var offloadFileNames       = [String]()
    private      var streamFileNames        = [String]()
    
    
    override init() {
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        self.data = NSMutableData()
    }
    
    func passMainView(view: ViewController){
        print("[DEBUG] passMainView is called")
        self.mainViewController = view
    }
    
    func passBLEView(view: BLEViewController){
        print("[DEBUG] passBLEView is called")
        self.BLEViewController = view
    }
    
    @objc private func scanTimeout() {
        
        print("[DEBUG] Scanning stopped")
        self.centralManager.stopScan()
    }
    
    // MARK: Public methods
    func startScanning(timeout: Double) -> Bool {
        
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
            globalVariables.FileHandler.writeFile(filename: self.streamFileNames[i], text: self.streamStrings[i])
        }
        
    }
    
    func generateSessionID(intValue: Int) -> Data {
        var profileID:UInt8 = UInt8(0x02)
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
        }
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
        self.activePeripherals.append(peripheral)
        self.activePeripherals[self.peripheralCount].delegate = self
        self.activePeripherals[self.peripheralCount].discoverServices([CBUUID(string: MDM_SERVICE_UUID)])
        self.accScales.append(1.0)
        self.offloadStrings.append("")
        self.streamStrings.append("")
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
        let targetDevice = (self.activePeripherals as AnyObject).index(of: peripheral)
        self.activePeripherals[targetDevice].delegate = nil
        self.activePeripherals.remove(at: targetDevice)
        self.accScales.remove(at: targetDevice)
        self.streamStrings.remove(at: targetDevice)
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
        self.peripheralCount -= 1
        self.characteristics.remove(at: targetDevice)
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
                                      CBUUID(string: MDM_SCALE_UUID)]
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
        }
        else if characteristic.uuid.uuidString == MDM_OFFLOADDATA_UUID {
            let targetDevice = (self.activePeripherals as AnyObject).index(of: peripheral)
            print("[DEBUG] write response for fetching lost data")
            self.activePeripherals[targetDevice].readValue(for: characteristic)
        }
        
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("[DEBUG] sensor: \(peripheral.name ?? "nil") did update value")
        if error != nil {
            
            print("[ERROR] Error updating value. \(error.debugDescription)")
            return
        }
        let targetDevice = (self.activePeripherals as AnyObject).index(of: peripheral)
        if characteristic.uuid.uuidString == MDM_STREAMDATA_UUID {
            //prompt for confirm streaming status on BLEViewController
            let isAlreadyStreaming = self.BLEViewController?.confirmStreamingState()
            if isAlreadyStreaming!{
                for i in 0...self.activePeripherals.count-1{
                    let filename = (self.activePeripherals[i].name)! + "_stream.txt"
                    self.streamFileNames.append(filename)
                }
            }
            //get data
            self.delegate?.bleDidReceiveData(data: characteristic.value! as NSData)
            let datavalue = characteristic.value
            let strvalue = datavalue?.hexEncodedString()
            self.streamStrings[targetDevice] += strvalue!
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
                print("[TEMP DEBUG] reload graph")
                self.BLEViewController?.graph.reloadData()
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
                    }
                }
                
            }
            else{
                //check if lost packet
                let currentSeqNum: UInt16 = UInt16((datavalue?[1])!) * 256 + UInt16((datavalue?[2])!)
                if ((currentSeqNum == 0) || ((currentSeqNum - self.lastSeqNums[targetDevice]) == 1)){
                    //this is okay
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
