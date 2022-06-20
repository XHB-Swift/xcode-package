//
//  Utils.swift
//  
//
//  Created by xiehongbiao on 2022/6/20.
//

import Foundation
import ArgumentParser
import Rainbow

extension Process {
    
    @discardableResult
    static func process(_ cmd: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        if #available(macOS 10.13, *) {
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            do {
                try process.run()
            } catch {
                return "error = \(error)"
            }
        } else {
            process.launchPath = "/bin/bash"
            process.launch()
        }
        
        let file = pipe.fileHandleForReading
        if #available(macOS 10.15.4, *) {
            do {
                guard let data = try file.readToEnd() else { return "" }
                return String(data: data, encoding: .utf8) ?? ""
            } catch {
                return "error = \(error)"
            }
        } else {
            let data = file.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}

