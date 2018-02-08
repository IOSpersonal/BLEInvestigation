//
//  FWUpgradeViewController.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 30/8/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit

class FWUpgradeViewController: UIViewController {

    @IBOutlet var updateFWProgressPercentageLabel: UILabel!
    @IBOutlet var updateFWProgressBar: UIProgressView!
    @IBOutlet var stopTimeCalBtn: UIButton!
    @IBOutlet var startTimeCalBtn: UIButton!
    @IBOutlet var statusLabel: UILabel!
    private var isInitialsed = false
    private let monitorAlert = UIAlertController(title: "Synchronised Monitoring", message: "\nInput a monitor time in minutes (1-4320). \nsynchronised monitoring current supports two sensors only", preferredStyle: UIAlertControllerStyle.alert)
    private let voidAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if(!self.isInitialsed){
            self.initialiseFWUpgradeViewController()
            self.isInitialsed = true
        }
        // Do any additional setup after loading the view.
        self.stopTimeCalBtn.isEnabled = true
        self.startTimeCalBtn.isEnabled = true
    }
    func configurationTextField(textField: UITextField!)
    {
        //text field for monitor alert
        textField.keyboardType = UIKeyboardType.numberPad
    }
    
    func initialiseFWUpgradeViewController(){
        //do this after there is default files available
        globalVariables.FileHandler.copyDefaultFile()
        self.updateFWProgressBar.setProgress(0.0, animated: false)
        globalVariables.BLEHandler.passFWUpgradeView(view: self)
        self.monitorAlert.addTextField(configurationHandler: configurationTextField)
        self.monitorAlert.addAction(voidAction)
        self.monitorAlert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ (UIAlertAction)in
            let monitorTimeDec = Int((self.monitorAlert.textFields?[0].text)!)!
            if (monitorTimeDec > 4320) || (monitorTimeDec > 120 && !globalVariables.monitorTypeFlag) {
                let notValidTimeAlert = UIAlertController(title: "ERROR", message: "The time you entered is not Valid", preferredStyle: UIAlertControllerStyle.alert)
                notValidTimeAlert.addAction(self.voidAction)
                self.present(notValidTimeAlert, animated: false, completion: nil)
            }
            else if globalVariables.currentNumOfDevice != 2{
                let notValidTimeAlert = UIAlertController(title: "ERROR", message: "Current connected device number is not 2", preferredStyle: UIAlertControllerStyle.alert)
                notValidTimeAlert.addAction(self.voidAction)
                self.present(notValidTimeAlert, animated: false, completion: nil)
            }
            else{
                print("[DEBUG] user input monitor time: \(monitorTimeDec) minutes")
                globalVariables.BLEHandler.isServingStreamStart = true
                let success = globalVariables.BLEHandler.startMonitoring(time: monitorTimeDec)
                if !success{
                    globalVariables.BLEHandler.isServingStreamStart = false
                    let monitorFailAlert = UIAlertController(title: "ERROR", message: "start monitoring failed", preferredStyle: UIAlertControllerStyle.alert)
                    monitorFailAlert.addAction(self.voidAction)
                    self.present(monitorFailAlert, animated: false, completion: nil)
                }
            }
        }))

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //below three overriden var for disabling landscape in this viewController
    override var shouldAutorotate: Bool{
        print("[DEBUG] user rotate device event blocked!")
        return false
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        return UIInterfaceOrientationMask.portrait
    }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation{
        return UIInterfaceOrientation.portrait
    }
    func syncMonitorDidCalculateDelay(delay: Double, message: String){
        self.statusLabel.text = "Status: sync delay: \(delay)ms"
        let monitorSuccessAlert = UIAlertController(title: "started monitoring", message: message, preferredStyle: UIAlertControllerStyle.alert)
        monitorSuccessAlert.addAction(self.voidAction)
        self.present(monitorSuccessAlert, animated: false, completion: nil)
    }
    
    @IBAction func syncMonitorBtnClk(_ sender: Any) {
        print("[DEBUG] synchronised monitoring button click event")
        self.present(self.monitorAlert, animated: true, completion: nil)
    }
    @IBAction func revertBtnClk(_ sender: Any) {
        print("[DEBUG] revert device button click event")
        let success = globalVariables.BLEHandler.revertDevices()
        if success{
            globalVariables.BLEHandler.disconnectAllPeripheral()
        }
    }
    @IBAction func eraseDeviceBtnClk(_ sender: Any) {
        print("[DEBUG] erase device button click event")
        let success = globalVariables.BLEHandler.eraseDevices()
        if(success){
            globalVariables.allSensorList.removeAll()
        }
    }
    @IBAction func stopTimeCalBtnClk(_ sender: Any) {
        print("[DEBUG] stop time calibration button click event")
        let success = globalVariables.BLEHandler.stopTimeCalibration()
        if(success){
            self.stopTimeCalBtn.isEnabled = false
        }
    }
    @IBAction func startTimeCalBtnClk(_ sender: Any) {
        print("[DEBUG] start time calibration button click event")
        let success = globalVariables.BLEHandler.startTimeCalibration()
        if success{
            self.startTimeCalBtn.isEnabled = false
        }
    }
    @IBAction func upgradeFWBtnClk(_ sender: Any) {
        print("[DEBUG] update FW button click event")
        self.updateFWProgressBar.setProgress(0.0, animated: false)
        self.updateFWProgressPercentageLabel.text = "0%"
        globalVariables.BLEHandler.startUpdateFWWithFile(filename: "FW_TZ1011_6_5_12279.bin")
    }


}
