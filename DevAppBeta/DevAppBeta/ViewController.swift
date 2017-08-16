//
//  ViewController.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 21/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var DeviceListTableView: UITableView!
    var targetDeviceIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.DeviceListTableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        globalVariables.BLEHandler.passMainView(view: self)
        globalVariables.appStatus = "initialised"
        self.updateStatus(value: globalVariables.appStatus)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //scan button click event
    @IBAction func scanBtnClk(_ sender: Any) {
        
        _ = globalVariables.BLEHandler.startScanning(timeout: 5)
    }
    
    //connect button click event
    @IBAction func connectBtnClk(_ sender: Any) {
        
        globalVariables.BLEHandler.stopScanning()
        let success = globalVariables.BLEHandler.connectToPeripheral(peripheral: globalVariables.BLEHandler.peripherals[self.targetDeviceIndex])
        if success {
            globalVariables.appStatus = "connecting to: \(globalVariables.BLEHandler.peripherals[self.targetDeviceIndex].name ?? "N/A")"
            
        }
        else {
            globalVariables.appStatus = "connection unsuccessful"
        }
    }

    //update status label
    func updateStatus(value: String){
        print("[DEBUG] updating Status: \(value)")
        statusLabel.text = value
    }
    
    //update sensor list table
    func reloadTable(){
        print("[DEBUG] reloading table view data")
        self.DeviceListTableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return globalVariables.allSensorList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.DeviceListTableView.dequeueReusableCell(withIdentifier: "cell") as UITableViewCell!
        cell.textLabel?.text = globalVariables.allSensorList[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.targetDeviceIndex = indexPath.row
        self.updateStatus(value: "selected: \(globalVariables.allSensorList[self.targetDeviceIndex])")
    }
}

