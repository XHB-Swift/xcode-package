
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
    var skipInstall = "NO"
    var buildLibForDist = "YES"
    
    var archiveCmd: String {
        var buildCmd = "xcodebuild archive "
        buildCmd.append("-project \(project) ")
        buildCmd.append("-scheme \(scheme) ")
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
    
    @Argument(help: "The Xcode framework project path.")
    var project: String
    
    @Argument(help: "The Xcode framework project scheme.")
    var scheme: String
    
    @Argument(help: "The XCFramework output path.")
    var outputPath: String?
    
    mutating func run() throws {
        let outputPath = self.outputPath ?? self.defaultOutputPath(project, scheme)
        createOutputDir(outputPath)
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: outputPath) { return }
        let frw = Framework(project: project,
                            scheme: scheme,
                            destination: .platform_iOS,
                            archivePath: "\(outputPath)/\(scheme)-\(iphoneos).xcarchive")
        let simFrw = Framework(project: project,
                               scheme: scheme,
                               destination: .platform_iOS_Simulator,
                               archivePath: "\(outputPath)/\(scheme)-\(iphonesimulator).xcarchive")
        [frw, simFrw].forEach { f in
            self.archive(framework: f)
        }
    }
}

extension PackageHepler {
    
    private func defaultOutputPath(_ projectPath: String, _ scheme: String) -> String {
        let fileMgr = FileManager.default
        guard let url = fileMgr.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            return projectPath.replacingOccurrences(of: ".xcodeproj", with: "") + "auto_xcfrw_\(scheme)"
        }
        var dir_url = url.absoluteString + "auto_xcfrw_\(scheme)"
        if dir_url.hasPrefix("file://") {
            dir_url = dir_url.replacingOccurrences(of: "file://", with: "")
        }
        return dir_url
    }
    
    private func createOutputDir(_ outputPath: String) {
        let cmd = "mkdir -p \(outputPath)"
        let result = Process.process(cmd)
        log(message: result)
    }
    
    private func archive(framework: Framework) {
        let buildCmd = framework.archiveCmd
        log(message: buildCmd)
        let result = Process.process(buildCmd)
        if !result.contains("** ARCHIVE SUCCEEDED **") {
            PackageHepler.exit(withError: result.red)
        }
    }
}

PackageHepler.main(["/Users/cc/Desktop/LocalLab/TestXCFrw/TestXCFrw.xcodeproj", "TestXCFrw"])
