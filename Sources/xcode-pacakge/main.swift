
import Foundation
import ArgumentParser
import Rainbow


struct VersionControl {
    static let version = "0.0.1"
}

struct PackageHepler: ParsableCommand {
    
    static let configuration = CommandConfiguration(
        abstract: "Xcode Package Helper",
        version: "xcode-helper version \(VersionControl.version)"
    )
}
