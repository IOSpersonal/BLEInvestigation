//
//  BLEViewController.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 21/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit
import CorePlot

class BLEViewController: UIViewController, CPTScatterPlotDataSource{
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var streamDataLbl: UILabel!
    @IBOutlet var streamBtn: UIButton!
    @IBOutlet var stopStreamBtn: UIButton!
    @IBOutlet var graphView: CPTGraphHostingView!
    
    var graph = CPTXYGraph(frame: CGRect.zero)
    var Ax_plot = Array(repeating: 0.0, count: 40)
    var Ay_plot = Array(repeating: 0.0, count: 40)
    var Az_plot = Array(repeating: 0.0, count: 40)
    var arrayCounter = 0;
    private var offloadAlert = UIAlertController()

    override func viewDidLoad() {
        super.viewDidLoad()
        globalVariables.BLEHandler.passBLEView(view: self)
        self.updateStatus(value: globalVariables.appStatus)
        self.stopStreamBtn.isEnabled = false
        // Do any additional setup after loading the view.
        //init alertview
        self.offloadAlert = UIAlertController(title: nil, message: "Offloading, Please wait...\n\n\n", preferredStyle: UIAlertControllerStyle.alert)
        let spinner = UIActivityIndicatorView.init(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
        spinner.center = CGPoint(x: 130.5, y: 65.5)
        spinner.color = UIColor.black
        spinner.startAnimating()
        offloadAlert.view.addSubview(spinner)
        
        //init graph view
        self.graph.paddingLeft = 10.0
        self.graph.paddingTop = 10.0
        self.graph.paddingRight = 10.0
        self.graph.paddingBottom = 10.0
        let axes = graph.axisSet as! CPTXYAxisSet
        let lineStyle = CPTMutableLineStyle()
        lineStyle.lineWidth = 2
        axes.xAxis?.axisLineStyle = lineStyle
        axes.yAxis?.axisLineStyle = lineStyle
        self.graphView.hostedGraph = graph
        
        //init plot space
        let plotSpace = graph.defaultPlotSpace as! CPTXYPlotSpace
        plotSpace.allowsUserInteraction = false
        plotSpace.yRange = CPTPlotRange(location: -5.0, length: 10.0)
        plotSpace.xRange = CPTPlotRange(location: -5.0, length: 32.0)
        
        
        
        if let x = axes.xAxis{
            x.majorIntervalLength = 5.0
            x.orthogonalPosition = 0.0
            x.minorTicksPerInterval = 4
            x.minorTickLineStyle = lineStyle
            x.labelExclusionRanges = [
                CPTPlotRange(location: -0.01, length: 0.02),
            ]
 
        }
        
        if let y = axes.yAxis{
            y.majorIntervalLength = 1.0
            y.orthogonalPosition = 0.0
            y.minorTicksPerInterval = 1
            y.minorTickLineStyle = lineStyle
            y.labelExclusionRanges = [
                CPTPlotRange(location: -0.01, length: 0.02)
            ]
            y.delegate = graphView
        }
        //accelerometer x curve
        let curve_accx = CPTScatterPlot(frame: .zero)
        let blueLineStyle = CPTMutableLineStyle()
        blueLineStyle.lineWidth = 3.0
        blueLineStyle.lineColor = .blue()
        curve_accx.dataLineStyle = blueLineStyle
        curve_accx.identifier = NSString.init(string: "Ax")
        curve_accx.dataSource = self
        self.graph.add(curve_accx, to: graph.defaultPlotSpace)
        
        //accelerometer y curve
        let curve_accy = CPTScatterPlot(frame: .zero)
        let greenLineStyle = CPTMutableLineStyle()
        greenLineStyle.lineWidth = 3.0
        greenLineStyle.lineColor = .green()
        curve_accy.dataLineStyle = greenLineStyle
        curve_accy.identifier = NSString.init(string: "Ay")
        curve_accy.dataSource = self
        self.graph.add(curve_accy, to: graph.defaultPlotSpace)
        
        //accelerometer z curve
        let curve_accz = CPTScatterPlot(frame: .zero)
        let redLineStyle = CPTMutableLineStyle()
        redLineStyle.lineWidth = 3.0
        redLineStyle.lineColor = .red()
        curve_accz.dataLineStyle = redLineStyle
        curve_accz.identifier = NSString.init(string: "Az")
        curve_accz.dataSource = self
        self.graph.add(curve_accz, to: graph.defaultPlotSpace)
        
        //add title
        print("[DEBUG] add graph title")
        let titleString = "accelerometer data"
        let titleFont = UIFont(name: "Helvetica-Bold", size: 16.0)
        let graphTitle = NSMutableAttributedString(string: titleString)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        graphTitle.addAttribute(NSForegroundColorAttributeName, value: UIColor.white, range: NSRange(location: 0, length: titleString.utf16.count))
        graphTitle.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSRange(location: 0, length: graphTitle.length))
        graphTitle.addAttribute(NSFontAttributeName, value: titleFont!, range: NSRange(location: 0, length: titleString.utf16.count))
        
        self.graph.attributedTitle = graphTitle
        
        //add legend
        let accLegend = CPTLegend(graph: self.graph)
        let legendLineStyle = CPTMutableLineStyle()
        legendLineStyle.lineColor = CPTColor.white()
        accLegend.numberOfRows = 3
        accLegend.numberOfColumns = 1
        accLegend.borderLineStyle = legendLineStyle
        accLegend.cornerRadius = 2.0
        accLegend.swatchSize = CGSize(width: 15.0, height: 15.0)
        self.graph.legend = accLegend
        self.graph.legendAnchor = CPTRectAnchor.bottomRight
    }
    
    func numberOfRecords(for plot: CPTPlot) -> UInt {
        //plot length
        return 30;
    }
    
    func number(for plot: CPTPlot, field fieldEnum: UInt, record idx: UInt) -> Any? {
        //set value for plots
        let plotfield = CPTScatterPlotField(rawValue: Int(fieldEnum))
        let plotID = plot.identifier as! String
        if (plotfield == .Y) && (plotID == "Ax"){
            if( idx>=0 )&&( idx<40 ){
                return self.Ax_plot[Int(idx)]
            }
            else{
                return 0
            }
        }
        else if(plotfield == .Y) && (plotID == "Ay"){
            if( idx>=0 )&&( idx<40 ){
                return self.Ay_plot[Int(idx)]
            }
            else{
                return 0
            }
        }else if(plotfield == .Y) && (plotID == "Az"){
            if( idx>=0 )&&( idx<40 ){
                return self.Az_plot[Int(idx)]
            }
            else{
                return 0
            }
        }
        else{
            return idx as NSNumber
        }
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
        self.present(offloadAlert, animated: false, completion: nil)
    }
    
    func dismissOffloadSpinner() {
        //function for dismiss alert view and spinner for offload
        print("[DEBUG] offload complete, dismiss alert")
        self.offloadAlert.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func flushBtnClk(_ sender: Any) {
        let alert = UIAlertController(title: "confirm flush", message: "are you sure to delete all files from document folder?", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "confirm", style: UIAlertActionStyle.default, handler: { action in
            switch action.style{
                case.default:
                    globalVariables.FileHandler.flushDocDir()
                    print("[DEBUG] flush document directory")
                    break
                case.cancel:
                    print("[DEBUG] flush document canceled")
                    break
                case.destructive:
                    print("[DEBUG] destructed")
                    break
            }
        }))
        alert.addAction(UIAlertAction(title: "cancel", style: UIAlertActionStyle.cancel, handler: { action in
            switch action.style{
            case.default:
                globalVariables.FileHandler.flushDocDir()
                print("[DEBUG] flush document directory")
                break
            case.cancel:
                print("[DEBUG] flush document canceled")
                break
            case.destructive:
                print("[DEBUG] destructed")
                break
            }
        }))
        print("[DEBUG] show alert view controller")
        self.present(alert, animated: true, completion: nil)
        self.updateStatus(value: "document folder flushed")
    }
    @IBAction func backBtnClk(_ sender: Any) {
        print("[DEBUG] back button pressed: return to main ViewController")
        _ = globalVariables.BLEHandler.disconnectAllPeripheral()
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
