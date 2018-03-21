//
//  FWUpgradeViewController.swift
//  DevAppBeta
//  Advanced function view: advanced opertaiton of dsvSensor object, including: synchronised monitoring/erase device/revert device/attitude estimation/time calibration (depreciated)/FW upgrade
//  Created by Weihang Liu on 30/8/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit
import SceneKit

class FWUpgradeViewController: UIViewController {

    @IBOutlet var AEBtn: UIButton!
    @IBOutlet var AESceneView: SCNView!
    @IBOutlet var updateFWProgressPercentageLabel: UILabel!
    @IBOutlet var updateFWProgressBar: UIProgressView!
    @IBOutlet var stopTimeCalBtn: UIButton!
    @IBOutlet var startTimeCalBtn: UIButton!
    @IBOutlet var statusLabel: UILabel!
    // if this view is initialised
    private var isInitialsed = false
    private var boxscene = PrimitivesScene()
    // UIAlert views
    private let monitorAlert = UIAlertController(title: "Synchronised Monitoring", message: "\nInput a monitor time in minutes (1-4320). \nsynchronised monitoring current supports two sensors only", preferredStyle: UIAlertControllerStyle.alert)
    private let voidAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if(!self.isInitialsed){
            self.initialiseFWUpgradeViewController()
            self.isInitialsed = true
        }
        // time calibrations depreciated - UICurrentMediaTime() not accurate enough
        self.stopTimeCalBtn.isEnabled = false
        self.startTimeCalBtn.isEnabled = false
    }
    func configurationTextField(textField: UITextField!)
    {
        //text field for monitor alert
        textField.keyboardType = UIKeyboardType.numberPad
    }
    
    func initialiseFWUpgradeViewController(){
        //do this after there is default files available
        //setup scene
        self.AESceneView.scene = boxscene
        self.AESceneView.backgroundColor = UIColor.black
        self.AESceneView.autoenablesDefaultLighting = true
        self.AESceneView.allowsCameraControl = true
        //setup FWUpgrade
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
        // synchronised monitoring delay calculated
        self.statusLabel.text = "Status: sync delay: \(delay)ms"
        let monitorSuccessAlert = UIAlertController(title: "started monitoring", message: message, preferredStyle: UIAlertControllerStyle.alert)
        monitorSuccessAlert.addAction(self.voidAction)
        self.present(monitorSuccessAlert, animated: false, completion: nil)
    }
    
    func updateSceneWithQuat(Quat: [Double]){
        self.boxscene.rotateNodeWithQuat(quat: Quat)
    }
    
    @IBAction func syncMonitorBtnClk(_ sender: Any) {
        // synchronised monitoring supports 2 sensor only
        print("[DEBUG] synchronised monitoring button click event")
        self.present(self.monitorAlert, animated: true, completion: nil)
    }
    @IBAction func revertBtnClk(_ sender: Any) {
        // revert sensor in failsafe to application
        print("[DEBUG] revert device button click event")
        let success = globalVariables.BLEHandler.revertDevices()
        if success{
            _ = globalVariables.BLEHandler.disconnectAllPeripheral()
        }
    }
    @IBAction func eraseDeviceBtnClk(_ sender: Any) {
        // reboot sensor into failsafe
        print("[DEBUG] erase device button click event")
        let success = globalVariables.BLEHandler.eraseDevices()
        if(success){
            globalVariables.allSensorList.removeAll()
        }
    }
    @IBAction func stopTimeCalBtnClk(_ sender: Any) {
        // depreciated
        print("[DEBUG] stop time calibration button click event")
        let success = globalVariables.BLEHandler.stopTimeCalibration()
        if(success){
            self.stopTimeCalBtn.isEnabled = false
        }
    }
    @IBAction func startTimeCalBtnClk(_ sender: Any) {
        // depreciated
        print("[DEBUG] start time calibration button click event")
        let success = globalVariables.BLEHandler.startTimeCalibration()
        if success{
            self.startTimeCalBtn.isEnabled = false
        }
    }
    @IBAction func upgradeFWBtnClk(_ sender: Any) {
        // start FW UPgrade with prestored file
        print("[DEBUG] update FW button click event")
        self.updateFWProgressBar.setProgress(0.0, animated: false)
        self.updateFWProgressPercentageLabel.text = "0%"
        _ = globalVariables.BLEHandler.startUpdateFWWithFile(filename: globalVariables.firmwareFileName)
    }
    @IBAction func AttitudeEstimationBtnClk(_ sender: Any) {
        // enable attitude estimation and 3D display
        if globalVariables.EKFshouldPerformAttitudeEstimate{
            globalVariables.EKFshouldPerformAttitudeEstimate = false
            self.AEBtn.setTitle("Enable Attitude Estimate", for: .normal)
        }
        else{
            globalVariables.EKFshouldPerformAttitudeEstimate = true
            self.AEBtn.setTitle("Disable Attitude Estimate", for: .normal)
        }
    }
    
}
