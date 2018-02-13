//
//  BLEConfigViewController.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 8/2/18.
//  Copyright © 2018 Weihang Liu. All rights reserved.
//

import UIKit

class BLEConfigViewController: UIViewController,UIPickerViewDelegate,UIPickerViewDataSource {
    @IBOutlet var accFreqPV: UIPickerView!
    @IBOutlet var accScalePV: UIPickerView!
    @IBOutlet var gyroScalePV: UIPickerView!
    @IBOutlet var magFreqPV: UIPickerView!
    @IBOutlet var emgFreqPV: UIPickerView!
    
    private var initialsed = false
    private var acc_gyro_freq_cmdArr:[UInt8] = [0x6F, 0x37, 0x15, 0x0A, 0x05, 0x04]
    private var mag_freq_cmdArr:[UInt8] = [0x01, 0x02, 0x04, 0x08, 0x0C, 0x10]
    private let voidAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
    
    @IBAction func applyConfigBtnClk(_ sender: Any) {
        let acc_gyro_freq_cmd = self.acc_gyro_freq_cmdArr[self.accScalePV.selectedRow(inComponent: 0)]
        let magFreq_cmd = self.mag_freq_cmdArr[self.magFreqPV.selectedRow(inComponent: 0)]
        let accScale_cmd = UInt8(self.accScalePV.selectedRow(inComponent: 0))
        let gyroScale_cmd = UInt8(self.gyroScalePV.selectedRow(inComponent: 0))
        let emgFreq_cmd = UInt8(self.emgFreqPV.selectedRow(inComponent: 0))
        let data = Data(bytes: [acc_gyro_freq_cmd,magFreq_cmd,0x01,accScale_cmd,gyroScale_cmd,0x00,0x00,emgFreq_cmd])
        //print("[TEMP] \(magFreq_cmd),\(self.magFreqPV.selectedRow(inComponent: 0))")
        let success = globalVariables.BLEHandler.writeBLEConfigWithData(data:data)
        var message = "failed"
        if(success){
            message = "success"
        }
        let monitorSuccessAlert = UIAlertController(title: "apply config", message: message, preferredStyle: UIAlertControllerStyle.alert)
        monitorSuccessAlert.addAction(self.voidAction)
        self.present(monitorSuccessAlert, animated: false, completion: nil)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        var ret = 0
        switch pickerView.tag {
        case 0:
            ret = globalVariables.accFreqArray.count
            break
        case 1:
            ret = globalVariables.accScaleArray.count
            break
        case 2:
            ret = globalVariables.gyroScaleArray.count
            break
        case 3:
            ret = globalVariables.magFreqArray.count
            break
        case 4:
            ret = globalVariables.emgFreqArray.count
            break
        default:
            break
        }
        return ret
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        var ret = "nil"
        switch pickerView.tag {
        case 0:
            ret = globalVariables.accFreqArray[row]
            break
        case 1:
            ret = globalVariables.accScaleArray[row]
            break
        case 2:
            ret = globalVariables.gyroScaleArray[row]
            break
        case 3:
            ret = globalVariables.magFreqArray[row]
            break
        case 4:
            ret = globalVariables.emgFreqArray[row]
            break
        default:
            break
        }
        return ret
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if(!self.initialsed){
            self.initisalise()
        }
        self.readInitialSelection()
    }
    private func initisalise(){
        self.accFreqPV.tag = 0;
        self.accScalePV.tag = 1;
        self.gyroScalePV.tag = 2;
        self.magFreqPV.tag = 3;
        self.emgFreqPV.tag = 4;
        self.accFreqPV.delegate = self
        self.accFreqPV.dataSource = self
        self.accScalePV.delegate = self
        self.accScalePV.dataSource = self
        self.gyroScalePV.delegate = self
        self.gyroScalePV.dataSource = self
        self.magFreqPV.delegate = self
        self.magFreqPV.dataSource = self
        self.emgFreqPV.delegate = self
        self.emgFreqPV.dataSource = self

    }
    
    private func readInitialSelection()
    {
        self.accFreqPV.selectRow(globalVariables.BLEHandler.connectedSensors[0].acc_gyro_freq, inComponent: 0, animated: true)
        self.accScalePV.selectRow(globalVariables.BLEHandler.connectedSensors[0].accScales, inComponent: 0, animated: true)
        self.gyroScalePV.selectRow(globalVariables.BLEHandler.connectedSensors[0].gyroScales, inComponent: 0, animated: true)
        self.magFreqPV.selectRow(globalVariables.BLEHandler.connectedSensors[0].magFreq, inComponent: 0, animated: true)
        self.emgFreqPV.selectRow(globalVariables.BLEHandler.connectedSensors[0].emgFreq, inComponent: 0, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    


}
