//
//  BLEViewController.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 21/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit

class BLEViewController: UIViewController {
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var streamDataLbl: UILabel!
    @IBOutlet var streamBtn: UIButton!
    @IBOutlet var stopStreamBtn: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        globalVariables.BLEHandler.passBLEView(view: self)
        self.updateStatus(value: globalVariables.appStatus)
        self.stopStreamBtn.isEnabled = false
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func startStreamBtnClk(_ sender: Any) {
        globalVariables.BLEHandler.startStreaming()
        self.streamBtn.isEnabled = false
        self.stopStreamBtn.isEnabled = true
        self.updateStatus(value: "Streaming")
    }
    @IBAction func stopStreamBtnClk(_ sender: Any) {
        globalVariables.BLEHandler.stopStreaming()
        self.stopStreamBtn.isEnabled = false
        self.streamBtn.isEnabled = true
        self.updateStatus(value: "Connected")
    }
    @IBAction func compressedDataOffloadBtnClk(_ sender: Any) {
        globalVariables.BLEHandler.offloadCompressedData()
        self.updateStatus(value: "offloading")
    }
    
    
    //update status label
    func updateStatus(value: String){
        print("[DEBUG] updating Status: \(value)")
        statusLabel.text = value
    }
    
    //update status label
    func updateStreamDataLbl(value: String){
        print("[DEBUG] received streaming data: \(value)")
        streamDataLbl.text = value
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
