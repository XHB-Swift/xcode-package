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
        process.arguments = ["-c", cmd]
        let pipe = Pipe()
        process.standardOutput = pipe
        if #available(macOS 10.13, *) {
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
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

enum MessageLevel {
    case tips(content: Any?)
    case success(content: Any?)
    case warning(content: Any?)
    case failure(content: Any?)
    
    var messageText: String {
        var printedMessage = ""
        switch self {
        case .tips(let content):
            printedMessage.append("\(content ?? "")".lightYellow)
        case .success(let content):
            printedMessage.append("\(content ?? "")".green)
        case .warning(let content):
            printedMessage.append("\(content ?? "")".yellow)
        case .failure(let content):
            printedMessage.append("\(content ?? "")".red)
        }
        return printedMessage
    }
}

func log(file: String = #file,
         function: String = #function,
         line: Int = #line,
         message: MessageLevel,
         title: String = "") {
    var content = "----------\(title)-----------\n"
    content.append("file: \(file)\n")
    content.append("function: \(function)\n")
    content.append("line: \(line)\n")
    content.append("content: \(message.messageText)\n")
    content.append("----------------------------")
    Swift.print(content)
}

