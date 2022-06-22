
import Foundation
import ArgumentParser
import Rainbow

let version = "0.0.1"
let iphoneos = "iphoneos"
let iphonesimulator = "iphonesimulator"

extension String: Error {}

extension String {
    static let i386   = "i386"
    static let x86_64 = "x86_64"
    static let armv7  = "armv7"
    static let armv7s = "armv7s"
    static let arm64  = "arm64"
    static let arm64e = "arm64e"
    
    static let allArchives: [String] = [
        .i386,
        .x86_64,
        .armv7,
        .armv7s,
        .arm64,
        .arm64e
    ]
    
    static let archives: [String] = [
        .armv7,
        .armv7s,
        .arm64,
        .arm64e
    ]
    
    static let simArchives: [String] = [
        .i386,
        .x86_64
    ]
}

extension String {
    static let platform_iOS = "generic/platform=iOS"
    static let platform_iOS_Simulator = "generic/platform=iOS Simulator"
}

struct Framework {
    var project: String
    var scheme: String
    var archives = [String]()
    var destination: String
    var archivePath: String
    var configuration = "Debug"
    var skipInstall = "NO"
    var buildLibForDist = "YES"
    
    var archiveCmd: String {
        var buildCmd = "xcodebuild archive "
        if project.hasSuffix(".xcodeproj") {
            buildCmd.append("-project \(project) ")
        } else if project.hasSuffix(".xcworkspace") {
            buildCmd.append("-workspace \(project) ")
        }
        buildCmd.append("-scheme \(scheme) ")
        buildCmd.append("-configuration \(configuration) ")
        buildCmd.append("-destination \"\(destination)\" ")
        buildCmd.append("-archivePath \(archivePath) ")
        if !archives.isEmpty {
            buildCmd.append("VALID_ARCHS=\"\(archives.joined(separator: " "))\" ")
        }
        buildCmd.append("SKIP_INSTALL=\(skipInstall) ")
        buildCmd.append("BUILD_LIBRARY_FOR_DISTRIBUTION=\(buildLibForDist)")
        return buildCmd
    }
}

struct PackageHepler: ParsableCommand {
    
    @Option(name: .shortAndLong, help: "The Products built with Debug or Release.")
    var release = true
    
    @Argument(help: "The Xcode framework '.xcodeproj' or '.xcworkspace' path.")
    var project: String
    
    @Argument(help: "The Xcode framework project scheme.")
    var scheme: String
    
    @Argument(help: "The XCFramework output path.")
    var outputPath: String?
    
    mutating func run() throws {
        let result = createOutputDir()
        if !result.0 { return }
        let output = result.1
        cleanProject()
        archiveXCFramework(to: output)
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
        let cmd = "mkdir -p \(dir_url)"
        let result = Process.process(cmd)
        if !result.isEmpty {
            log(message: .tips(content: result))
        }
        return (fileMgr.fileExists(atPath: dir_url), dir_url)
    }
    
    private func cleanProject() {
        var buildCmd = "xcodebuild clean "
        if project.hasSuffix(".xcodeproj") {
            buildCmd.append("-project \(project) ")
        } else if project.hasSuffix(".xcworkspace") {
            buildCmd.append("-workspace \(project) ")
        }
        buildCmd.append("-scheme \(scheme)")
        let result = Process.process(buildCmd)
        if !result.contains("** CLEAN SUCCEEDED **") {
            PackageHepler.exit(withError: result.red)
        }
    }
    
    private func archiveXCFramework(to outputPath: String) {
        let config = release ? "Release" : "Debug"
        let frw = Framework(project: project,
                            scheme: scheme,
                            destination: .platform_iOS,
                            archivePath: "\(outputPath)/\(scheme)-\(iphoneos).xcarchive",
                            configuration: config)
        let simFrw = Framework(project: project,
                               scheme: scheme,
                               destination: .platform_iOS_Simulator,
                               archivePath: "\(outputPath)/\(scheme)-\(iphonesimulator).xcarchive",
                               configuration: config)
        let frameworks = [frw, simFrw]
        var frameworkPaths = Array<String>()
        frameworks.forEach { framework in
            let buildCmd = framework.archiveCmd
            log(message: .tips(content: buildCmd))
            let result = Process.process(buildCmd)
            if !result.contains("** ARCHIVE SUCCEEDED **") {
                PackageHepler.exit(withError: result.red)
            }
            let frameworkPath = "\(framework.archivePath)/Products/Library/Frameworks/\(framework.scheme).framework"
            frameworkPaths.append(frameworkPath)
        }
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

PackageHepler.main(["/Users/cc/Desktop/LocalLab/TestXCFrw/TestXCFrw.xcodeproj", "TestXCFrw"])
//PackageHepler.main(["/Users/xiehongbiao123/Desktop/iOSDemo/TestFrw/TestFrw.xcodeproj", "TestFrw"])
