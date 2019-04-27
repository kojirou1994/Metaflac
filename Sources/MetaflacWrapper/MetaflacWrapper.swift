//
//  MetaflacWrapper.swift
//  Metaflac
//
//  Created by Kojirou on 2019/2/2.
//

import Foundation
@_exported import Executable

/// A wrapper for metaflac cli.
public struct MetaflacWrapper {
    
    public struct ExitError: Error {
        let terminationStatus: Int32
        
        public var localizedDescription: String {
            return "metaflac exit code: \(terminationStatus)"
        }
    }
    
    struct Metaflac: Executable {
        static let executableName = "metaflac"
        let arguments: [String]
    }
    
    ///
    ///
    /// - Parameters:
    ///   - file:
    ///   - tagFile:
    ///   - exportPicture:
    /// - Returns: (sample-rate, bps)
    /// - Throws:
    public static func exportTag(file: String, tagFile: String, exportPicture: String?) throws -> (Int, Int) {
        var arguments: [String] = ["--no-utf8-convert",
                                   "--show-sample-rate", "--show-bps",
                                   "--export-tags-to=\(tagFile)"]
        if exportPicture != nil {
            arguments.append("--export-picture-to=\(exportPicture!)")
        }
        arguments.append(file)
        
        let metaflac = Metaflac(arguments: arguments)
        let result = try metaflac.runAndCatch(checkNonZeroExitCode: false)
        
        let comps = String.init(decoding: result.stdout, as: UTF8.self).components(separatedBy: "\n").filter({!$0.isEmpty}).map({ Int($0)! })
        return (comps[0], comps[1])
    }
    
    public static func importTag(file: String, tagFile: String) throws {
        try Metaflac(arguments: ["--no-utf8-convert",
                                 "--remove-all-tags", "--import-tags-from=\(tagFile)",
            file]).runAndWait(checkNonZeroExitCode: true)
    }
    
    public static func removeBlock(file: String, type: String) throws {
        try Metaflac(arguments: ["--remove", "--block-type=\(type)", file]).runAndWait(checkNonZeroExitCode: true)
    }
    
    public static func importPicture(file: String, picture: String,
                                     pictureType: UInt32) throws {
        try Metaflac(arguments: ["--import-picture-from=\(pictureType)||||\(picture)",
            file]).runAndWait(checkNonZeroExitCode: true)
    }
    
}
