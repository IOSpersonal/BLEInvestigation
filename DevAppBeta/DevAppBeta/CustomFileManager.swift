//
//  FileManager.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 26/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit

class CustomFileManager: NSObject {

    override init(){
        super.init()
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
    
    func flushDocDir(){
        let fileManager = FileManager.default
        let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        do{
            let filePaths = try fileManager.contentsOfDirectory(atPath: dirPath)
            for filePath in filePaths{
                try fileManager.removeItem(atPath: dirPath + "/" + filePath)
            }
        } catch let error as NSError {
            print("[DEBUG] file remove failed with error \(error)")
        }
        
        
    }
    
}
