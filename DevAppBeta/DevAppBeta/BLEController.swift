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
    let MDM_STREAMDATA_UUID         = "00000010-0008-A8BA-E311-F48C90364D99"
    let MDM_SCALE_UUID              = "0000000A-0008-A8BA-E311-F48C90364D99"
    let MDM_OFFLOAD_UUID            = "00000011-0008-A8BA-E311-F48C90364D99"
    let MDM_OFFLOADDATA_UUID        = "00000012-0008-A8BA-E311-F48C90364D99"
    
    //let MDM_FETCHLOSTDATA_UUID = "00000013-0008-A8BA-E311-F48C90364D99" //DEPRECIATED
    
    var delegate: BLEDelegate?
    var mainViewController: ViewController?
    var BLEViewController: BLEViewController?
    
    //for checking packet loss
    var lastSeqNum: UInt16 = 0
    var lostSeqNums = [UInt16]()
    
    private      var centralManager:   CBCentralManager!
    private      var activePeripheral: CBPeripheral?
    private      var characteristics = [String : CBCharacteristic]()
    private      var data:             NSMutableData?
    private(set) var peripherals     = [CBPeripheral]()
    private      var RSSICompletionHandler: ((NSNumber?, NSError?) -> ())?
    //string for saving all offloaded data
    private      var offloadString = ""
    private      var streamString = ""
    //for fetching specific lost packet
    private      var fetchIndex = 0
    //bool flag for checking offload finished for fetching lost data
    private      var isOffloadFinished = false
    //accelerometer scale
    private      var accScale = 1.0
    
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
        if self.centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t disconnect from peripheral")
            return false
        }
        
        self.centralManager.cancelPeripheralConnection(self.activePeripheral!)
        
        return true
    }

    func enableNotifications(enable: Bool) {
        print("[DEBUG] enable notification for sensor")
        guard let char_stream = self.characteristics[MDM_STREAMDATA_UUID] else { return }
        self.activePeripheral?.setNotifyValue(enable, for: char_stream)
        guard let char_offload = self.characteristics[MDM_OFFLOADDATA_UUID] else { return }
        self.activePeripheral?.setNotifyValue(enable, for: char_offload)
        //guard let char_fetch = self.characteristics[MDM_FETCHLOSTDATA_UUID] else { return }
        //self.activePeripheral?.setNotifyValue(enable, for: char_fetch)
    }
 
    func readRSSI(completion: @escaping (_ RSSI: NSNumber?, _ error: NSError?) -> ()) {
        
        self.RSSICompletionHandler = completion
        self.activePeripheral?.readRSSI()
    }
    
    func startStreaming(){
        let data = Data(bytes: [0x01])
        guard let char = self.characteristics[MDM_COMMAND_UUID] else {return}
        self.activePeripheral?.writeValue(data, for: char, type: .withResponse)
        let filename = (self.activePeripheral?.name!)! + "_stream.txt"
        globalVariables.FileHandler.setFileName(filename: filename)
    }
    
    func stopStreaming(){
        let data = Data(bytes: [0x02])
        guard let char = self.characteristics[MDM_COMMAND_UUID] else {return}
        self.activePeripheral?.writeValue(data, for: char, type: .withResponse)
        globalVariables.appStatus = "streamComplete"
        self.BLEViewController?.updateStatus(value: "streamComplete, writing to file")
        globalVariables.FileHandler.writeFile(filename: globalVariables.FileHandler.filename!, text: self.streamString)
    }
    
    func offloadCompressedData(){
        self.isOffloadFinished = false
        let filename = (self.activePeripheral?.name!)! + "_offload.txt"
        globalVariables.FileHandler.setFileName(filename: filename)
        let data = Data(bytes: [0x06])
        guard let char = self.characteristics[MDM_OFFLOAD_UUID] else {return}
        self.activePeripheral?.writeValue(data, for: char, type: .withResponse)
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
        
        globalVariables.appStatus = "connected to \(peripheral.name ?? "nil")"
        self.BLEViewController?.updateStatus(value: globalVariables.appStatus)
        self.activePeripheral = peripheral
        
        self.activePeripheral?.delegate = self
        self.activePeripheral?.discoverServices([CBUUID(string: MDM_SERVICE_UUID)])
        
        self.delegate?.bleDidConnectToPeripheral()
    }

    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        var text = "[DEBUG] Disconnected from peripheral: \(peripheral.name ?? "nil")"
        
        if error != nil {
            text += ". Error: \(error.debugDescription)"
        }
        
        print(text)
        
        self.activePeripheral?.delegate = nil
        self.activePeripheral = nil
        self.characteristics.removeAll(keepingCapacity: false)
        
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
                                      CBUUID(string: MDM_SCALE_UUID)]//,CBUUID(string: MDM_FETCHLOSTDATA_UUID)]
            
            peripheral.discoverCharacteristics(theCharacteristics, for: service)
        }
 

    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if error != nil {
            print("[ERROR] Error discovering characteristics. \(error.debugDescription)")
            return
        }
        
        print("[DEBUG] Found characteristics for peripheral: \(peripheral.name ?? "nil")")
        
        for characteristic in service.characteristics! {
            self.characteristics[characteristic.uuid.uuidString] = characteristic
            //check scale
            if characteristic.uuid.uuidString == MDM_SCALE_UUID{
                let charValue = [UInt8](characteristic.value!)
                print("[DEBUG] accelerometer scale read success, value = \(charValue[3])")
                switch charValue[3] {
                case 1:
                    self.accScale = 0.5
                    break
                case 2:
                    self.accScale = 1.0
                    break
                case 3:
                    self.accScale = 2.0
                    break
                case 4:
                    self.accScale = 4.0
                    break
                default:
                    break
                }
            }
        }
        
        enableNotifications(enable: true)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        /*
        if characteristic.uuid.uuidString == MDM_FETCHLOSTDATA_UUID {
            print("[DEBUG] write response for fetching lost data")
            //[DEPRECIATED] no need for reading, this migrated to MDM_OFFLOADDATA_UUID
            //self.activePeripheral?.readValue(for: characteristic)
        }*/
        if characteristic.uuid.uuidString == MDM_COMMAND_UUID {
            print("[DEBUG] write response for ble command")
        }
        else if characteristic.uuid.uuidString == MDM_OFFLOADDATA_UUID {
            print("[DEBUG] write response for fetching lost data")
            self.activePeripheral?.readValue(for: characteristic)
        }
        
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("[DEBUG] sensor: \(peripheral.name ?? "nil") did update value")
        if error != nil {
            
            print("[ERROR] Error updating value. \(error.debugDescription)")
            return
        }
        
        if characteristic.uuid.uuidString == MDM_STREAMDATA_UUID {
            self.delegate?.bleDidReceiveData(data: characteristic.value! as NSData)
            let datavalue = characteristic.value
            let strvalue = datavalue?.hexEncodedString()
            self.streamString += strvalue!
            //update status bar to see data coming, comment to accelerate offload
            self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
            let sensorData = [UInt8](datavalue!)
            let Ax = UInt16(sensorData[1]) << 8 | UInt16(sensorData[0])
            let Ax_signed:Int16 = Int16(bitPattern: Ax)
            let fax = Double(Ax_signed) / 8192.0 * self.accScale
            let Ay = UInt16(sensorData[3]) << 8 | UInt16(sensorData[2])
            let Ay_signed:Int16 = Int16(bitPattern: Ay)
            let fay = Double(Ay_signed) / 8192.0 * self.accScale
            let Az = UInt16(sensorData[5]) << 8 | UInt16(sensorData[4])
            let Az_signed:Int16 = Int16(bitPattern: Az)
            let faz = Double(Az_signed) / 8192.0 * self.accScale
            print("[DEBUG] streaming accelerometer value: \(fax) \(fay) \(faz)")
            if (self.BLEViewController?.arrayCounter)! < 40 {
                self.BLEViewController?.Ax_plot[(self.BLEViewController?.arrayCounter)!] = fax
                self.BLEViewController?.Ay_plot[(self.BLEViewController?.arrayCounter)!] = fay
                self.BLEViewController?.Az_plot[(self.BLEViewController?.arrayCounter)!] = faz
                self.BLEViewController?.arrayCounter += 1
            }
            else{
                for i in 0...38{
                    self.BLEViewController?.Ax_plot[i] = (self.BLEViewController?.Ax_plot[i + 1])!
                    self.BLEViewController?.Ay_plot[i] = (self.BLEViewController?.Ay_plot[i + 1])!
                    self.BLEViewController?.Az_plot[i] = (self.BLEViewController?.Az_plot[i + 1])!
                }
                self.BLEViewController?.Ax_plot[39] = fax
                self.BLEViewController?.Ay_plot[39] = fay
                self.BLEViewController?.Az_plot[39] = faz
            }
            self.BLEViewController?.graph.reloadData()
            
        }
        else if characteristic.uuid.uuidString == MDM_OFFLOADDATA_UUID {
            self.delegate?.bleDidReceiveData(data: characteristic.value! as NSData)
            let datavalue = characteristic.value
            let strvalue = datavalue?.hexEncodedString()
            //update status bar to see data coming, comment to accelerate offload
            self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
            
            if(self.isOffloadFinished) {
                //lost data fetched response
                print("[DEBUG] lost data resent")
                let datavalue = characteristic.value
                let strvalue = datavalue?.hexEncodedString()
                self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
                self.offloadString += strvalue!
                if self.fetchIndex <= self.lostSeqNums.count - 1 {
                    // not finished fetching
                    let i = self.lostSeqNums[self.fetchIndex]
                    self.fetchIndex += 1
                    var cmd_array = [UInt8]()
                    cmd_array.append(3)
                    cmd_array.append(UInt8(i / 256))
                    cmd_array.append(UInt8(i % 256))
                    let cmd = Data(bytes: cmd_array)
                    guard let char = self.characteristics[MDM_OFFLOADDATA_UUID] else {return}
                    self.activePeripheral?.writeValue(cmd, for: char, type: .withResponse)
                }
                else {
                    //finished fetching, write to file
                    print("[DEBUG] data offload complete, lost packets: \(self.lostSeqNums.count), resend successful")
                    globalVariables.appStatus = "offloadComplete"
                    self.BLEViewController?.updateStatus(value: "offloadComplete, lost packets successfully collected")
                    globalVariables.FileHandler.writeFile(filename: globalVariables.FileHandler.filename!, text: self.offloadString)
                }
            }
            else if (strvalue?.hasPrefix("03ffff"))!{
                //end of offloading, get lost packets
                self.isOffloadFinished = true
                if !self.lostSeqNums.isEmpty {
                    print("[DEBUG] end of offloading, lost packet fetching, total: \(self.lostSeqNums.count)")
                    let i = self.lostSeqNums[self.fetchIndex]
                    self.fetchIndex += 1
                    var cmd_array = [UInt8]()
                    cmd_array.append(3)
                    cmd_array.append(UInt8(i / 256))
                    cmd_array.append(UInt8(i % 256))
                    let cmd = Data(bytes: cmd_array)
                    guard let char = self.characteristics[MDM_OFFLOADDATA_UUID] else {return}
                    self.activePeripheral?.writeValue(cmd, for: char, type: .withResponse)
                }
                else {
                    print("[DEBUG] offload completed with no lost packet")
                    //write to storage
                    globalVariables.appStatus = "offloadComplete"
                    self.BLEViewController?.updateStatus(value: "offloadComplete, no lost packets")
                    globalVariables.FileHandler.writeFile(filename: globalVariables.FileHandler.filename!, text: self.offloadString)
                }
                
            }
            else{
                //check if lost packet
                let currentSeqNum: UInt16 = UInt16((datavalue?[1])!) * 256 + UInt16((datavalue?[2])!)
                if ((currentSeqNum == 0) || ((currentSeqNum - self.lastSeqNum) == 1)){
                    //this is okay
                    self.lastSeqNum = currentSeqNum
                }
                else{
                    var gap = UInt16(currentSeqNum) - UInt16(self.lastSeqNum)
                    gap -= 1
                    print("[DEBUG] lost packet detected: at index \(currentSeqNum), num: \(gap)")
                    for i in 1...gap {
                        self.lostSeqNums.append(currentSeqNum - i)
                    }
                    self.lastSeqNum = currentSeqNum
                }
                //append offload string
                self.offloadString += strvalue!
            }
        }
        //else if characteristic.uuid.uuidString == MDM_FETCHLOSTDATA_UUID {
            // migrated to MDM_OFFLOADDATA_UUID
            
            /*
            //lost data fetched response
            print("[DEBUG] lost data resent")
            let datavalue = characteristic.value
            let strvalue = datavalue?.hexEncodedString()
            self.BLEViewController?.updateStreamDataLbl(value: strvalue!)
            self.offloadString += strvalue!
            if self.fetchIndex <= self.lostSeqNums.count - 1 {
                // not finished fetching
                let i = self.lostSeqNums[self.fetchIndex]
                self.fetchIndex += 1
                print("[TEMPDEBUG] fetching ind: \(i)")
                var cmd_array = [UInt8]()
                cmd_array.append(3)
                cmd_array.append(UInt8(i / 256))
                cmd_array.append(UInt8(i % 256))
                let cmd = Data(bytes: cmd_array)
                print("[TEMPDEBUG] sending cmd: \(cmd_array)")
                guard let char = self.characteristics[MDM_FETCHLOSTDATA_UUID] else {return}
                self.activePeripheral?.writeValue(cmd, for: char, type: .withResponse)
            }
            else {
                //finished fetching, write to file
                print("[DEBUG] data offload complete, lost packets: \(self.lostSeqNums.count), resend successful")
                globalVariables.appStatus = "offloadComplete"
                self.BLEViewController?.updateStatus(value: "offloadComplete, no lost packets")
                globalVariables.FileHandler.writeFile(filename: globalVariables.FileHandler.filename!, text: self.offloadString)
            }*/
        //}
 
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        self.RSSICompletionHandler?(RSSI, error as NSError?)
        self.RSSICompletionHandler = nil
    }

}
