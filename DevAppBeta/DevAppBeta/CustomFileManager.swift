//
//  FileManager.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 26/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit

class CustomFileManager: NSObject {
    var filename: String?
    
    override init(){
        super.init()
    }
    
    func setFileName(filename: String) {
        print("[DEBUG] filename is set to \(filename)")
        self.filename = filename
    }
    
    func writeFile(filename: String, text: String) {
        let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let path = dir.appendingPathComponent(filename)
        do {
            print("[DEBUG] writing to file: \(filename)")
            try text.write(to: path, atomically: true, encoding: .utf8)
        } catch {
            print("[DEBUG] file write error, for filename: \(filename)")
        }
        
        
    }
    
}
