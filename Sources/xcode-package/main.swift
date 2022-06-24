
import Foundation
import ArgumentParser
import Rainbow

extension String: Error {}

struct Platform {
    var name: String
    var generic: String
}

extension Platform {
    static let ios_device = Platform(name: "iphoneos", generic: "generic/platform=iOS")
    static let ios_simulator = Platform(name: "iphonesimulator", generic: "generic/platform=iOS Simulator")
}

extension String {
    
    static let executable     = "mh_executable"
    static let bunlde         = "mh_bundle"
    static let object         = "mh_object"
    static let dynamicLibrary = "mh_dylib"
    static let staticLibray   = "staticlib"
    
    var isFramework: Bool {
        return self == .dynamicLibrary ||
        self == .staticLibray
    }
}

struct XcodebuildCommand {
    
    struct Params: Equatable {
        
        var key: String
        var value: String
        var kind: Kind
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.key == rhs.key
        }
        
        enum Kind {
            case option
            case argument
        }
        
        var cmd: String {
            let adjustValue = value.contains(" ") ? "\"\(value)\"" : value
            switch kind {
            case .option:
                return "-\(key) \(adjustValue)"
            case .argument:
                return "\(key)=\(adjustValue)"
            }
        }
    }
    
    private let main = "xcodebuild"
    var option: String
    var project: String
    var scheme: String
    
    var params: [Params] = []
    
    var executedCmd: String {
        var cmd = "\(main) \(option) "
        if project.hasSuffix(".xcodeproj") {
            cmd.append("-project \(project) ")
        } else if project.hasSuffix(".xcworkspace") {
            cmd.append("-workspace \(project) ")
        }
        cmd.append("-scheme \(scheme) ")
        if !params.isEmpty {
            let paramsCmd = params.map { $0.cmd }.joined(separator: " ")
            cmd.append(paramsCmd)
        }
        return cmd
    }
}

struct PackageHepler: ParsableCommand {
    
    @Option(name: .shortAndLong, help: "The xcode-package version")
    var version = "0.0.1"
    
    @Option(name: .shortAndLong, help: "The Products built with Debug or Release.")
    var release = true
    
    @Argument(help: "The Xcode '.xcodeproj' or '.xcworkspace' path.")
    var project: String
    
    @Argument(help: "The Xcode project scheme.")
    var scheme: String
    
    @Argument(help: "The Products output path.")
    var outputPath: String?
    
    mutating func run() throws {
        let result = createOutputDir()
        if !result.0 { return }
        let output = result.1
        cleanProject()
        let mach = checkProjectMachOType()
        if mach.isFramework {
            archiveXCFramework(to: output)
        }
    }
}

extension PackageHepler {
    
    private func createOutputDir() -> (Bool, String) {
        let fileMgr = FileManager.default
        var dir_url = ""
        if let url = fileMgr.urls(for: .desktopDirectory, in: .userDomainMask).first {
            dir_url = url.absoluteString + "auto_xcfrw_\(scheme)"
        } else {
            dir_url = project + "auto_xcfrw_\(scheme)"
        }
        if dir_url.hasPrefix("file://") {
            dir_url = dir_url.replacingOccurrences(of: "file://", with: "")
        }
        var fileExist = fileMgr.fileExists(atPath: dir_url)
        if fileExist {
            return (fileExist, dir_url)
        }
        let cmd = "mkdir -p \(dir_url)"
        let result = Process.process(cmd)
        if !result.isEmpty {
            log(message: .tips(content: result))
        }
        fileExist = fileMgr.fileExists(atPath: dir_url)
        return (fileExist, dir_url)
    }
    
    private func cleanProject() {
        let buildCmd = XcodebuildCommand(option: "clean",
                                         project: project,
                                         scheme: scheme).executedCmd
        let result = Process.process(buildCmd)
        if !result.contains("** CLEAN SUCCEEDED **") {
            PackageHepler.exit(withError: result.red)
        }
    }
    
    private func checkProjectMachOType() -> String {
        let cmd = "xcodebuild -project \(project) -showBuildSettings"
        let result = Process.process(cmd)
        let regexText = "MACH_O_TYPE = [0-9a-z-A-Z_]+"
        do {
            let regex = try NSRegularExpression(pattern: regexText, options: [.caseInsensitive])
            let results = regex.matches(in: result, range: NSRange(location: 0, length: result.count))
            guard let checkResult = results.first else { return "" }
            let ns_range = checkResult.range
            let range = (ns_range.location..<ns_range.length + ns_range.location)
            let index1 = result.index(result.startIndex, offsetBy: range.lowerBound)
            let index2 = result.index(result.startIndex, offsetBy: range.upperBound)
            let subText = String(result[index1..<index2]).replacingOccurrences(of: " ", with: "")
            guard let s = subText.split(separator: "=").last else { return "" }
            return String(s)
        } catch {
            log(message: .failure(content: error))
            return ""
        }
    }
    
    private func archiveXCFramework(to outputPath: String) {
        let config = release ? "Release" : "Debug"
        let archivePlatforms = [Platform.ios_device, Platform.ios_simulator]
        let frameworkPaths = archivePlatforms.map { archivePlatform -> String in
            let archivePath = "\(outputPath)/\(scheme)-\(archivePlatform.name).xcarchive"
            let archiveCmd = XcodebuildCommand(option: "archive",
                                               project: project,
                                               scheme: scheme,
                                               params: [
                                                .init(key: "configuration",
                                                      value: config,
                                                      kind: .option),
                                                .init(key: "destination",
                                                      value: archivePlatform.generic,
                                                      kind: .option),
                                                .init(key: "archivePath",
                                                      value: archivePath,
                                                      kind: .option),
                                                .init(key: "SKIP_INSTALL",
                                                      value: "NO",
                                                      kind: .argument),
                                                .init(key: "BUILD_LIBRARY_FOR_DISTRIBUTION",
                                                      value: "YES",
                                                      kind: .argument)
                                               ])
            let cmd = archiveCmd.executedCmd
            log(message: .tips(content: cmd))
            let result = Process.process(cmd)
            if !result.contains("** ARCHIVE SUCCEEDED **") {
                PackageHepler.exit(withError: result.red)
            }
            return "\(archivePath)/Products/Library/Frameworks/\(scheme).framework"
        }
        if frameworkPaths.isEmpty { return }
        createXCFramework(with: frameworkPaths, to: outputPath)
    }
    
    private func createXCFramework(with frameworkPaths: [String], to outputPath: String) {
        if frameworkPaths.isEmpty { return }
        let output = "\(outputPath)/\(scheme).xcframework"
        let fileMgr = FileManager.default
        if fileMgr.fileExists(atPath: output) {
            do {
                try fileMgr.removeItem(atPath: output)
            } catch {
                PackageHepler.exit(withError: error)
            }
        }
        var buildCmd = "xcodebuild -create-xcframework "
        frameworkPaths.forEach { frameworkPath in
            buildCmd.append("-framework \(frameworkPath) ")
        }
        buildCmd.append("-output \(output)")
        let result = Process.process(buildCmd)
        if !result.isEmpty && !result.contains("successfully") {
            PackageHepler.exit(withError: result)
        }
        log(message: .success(content: result))
    }
}

//PackageHepler.main()
PackageHepler.main(["/Users/cc/Desktop/LocalLab/TestXCFrw/TestXCFrw.xcodeproj", "TestXCFrw"])
//PackageHepler.main(["/Users/xiehongbiao123/Desktop/iOSDemo/TestFrw/TestFrw.xcodeproj", "TestFrw"])
