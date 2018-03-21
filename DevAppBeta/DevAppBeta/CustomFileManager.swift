//
//  FileManager.swift
//  DevAppBeta
//  FileManager Customised for basic IO functions to help sensor with saving streamed data/offloaded data/time calibration (depreciated)/FW update
//  Created by Weihang Liu on 26/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import UIKit

extension String{
    func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL:fileURL)
    }
    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
}
extension Data{
    func append(fileURL: URL) throws{
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path){
            defer{
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else{
            try write(to: fileURL, options: .atomic)
        }
    }
}

class CustomFileManager: NSObject {


    override init(){
        super.init()
    }
    
    func writeFile(filename: String, text: String) {
        // append text to file
        let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let path = dir.appendingPathComponent(filename)
        do {
            print("[DEBUG] writing to file: \(filename)")
            try (text + "\n").appendToURL(fileURL: path)
        } catch {
            print("[DEBUG] file write error, for filename: \(filename)")
        }
        
        
    }
    //delete one file
    func deleteFile(filename: String){
        let fileManager = FileManager.default
        let dirpaths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docsURL = dirpaths[0]
        let filePath = docsURL.appendingPathComponent(filename).path
        do{
            try fileManager.removeItem(atPath: filePath)
        }
        catch let error as NSError {
            print("[DEBUG] file remove failed \(error)")
        }
    }
    
    //delete everything in document folder
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
    // function for copying default file to document folder
    func copyDefaultFile(){
        // copy prestored firmware binary to doc folder
        print("[DEBUG] copy files to document folder")
        let fileManager = FileManager.default
        let dirpaths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docsURL = dirpaths[0]
        let folderPath = Bundle.main.resourceURL!.appendingPathComponent("firmware").path
        let docsFolder = docsURL.appendingPathComponent("firmware").path
        do{
            let filelist = try fileManager.contentsOfDirectory(atPath: folderPath)
            try? fileManager.copyItem(atPath: folderPath, toPath: docsFolder)
            for filename in filelist{
                try? fileManager.copyItem(atPath: "\(folderPath)/\(filename)", toPath: "\(docsFolder)/\(filename)")
            }
        }
        catch{
            print("[DEBUG] copy default files failed")
        }
    }
    
    // function for read FW file into byte array
    func openFWBinFile(filename: String) -> [UInt8] {
        // read firmware binary into memory for update
        let fileManager = FileManager.default
        let dirpaths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docsURL = dirpaths[0]
        let docsFolder = docsURL.appendingPathComponent("firmware").path
        let path = docsFolder + "/" + filename
        var inputBuffer = [UInt8]()
        if fileManager.fileExists(atPath: path){
            print("[DEBUG] reading firmware file (\(filename) into UInt8 array, from path: \(path)")
            let inputStream = InputStream(fileAtPath: path)
            inputStream?.open()
            inputBuffer = [UInt8](repeating: 0, count: globalVariables.firmwareBufferLen)
            inputStream?.read(&inputBuffer, maxLength: inputBuffer.count)
            inputStream?.close()
        }
        else{
            print("[DEBUG] file does not exist")
        }
        return inputBuffer
    }
    
    // function for read file as String
    func readFileAsString(filename: String) -> String{
        let fileManager = FileManager.default
        let dirpaths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docsURL = dirpaths[0]
        let filePath = docsURL.appendingPathComponent(filename)
        var text = ""
        do{
            text += try String(contentsOf: filePath, encoding: String.Encoding.utf8)
        }
        catch{
            print("[DEBUG] read file as string failed")
        }
        return text
    }
    
    // function for checking if file exist
    func fileExist(filename: String) -> Bool {
        let fileManager = FileManager.default
        let dirpaths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docsURL = dirpaths[0]
        let filePath = docsURL.appendingPathComponent(filename).path
        return fileManager.fileExists(atPath: filePath)
    }
    
}
