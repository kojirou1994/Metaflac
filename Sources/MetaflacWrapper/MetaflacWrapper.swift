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
    
    ///
    ///
    /// - Parameters:
    ///   - file:
    ///   - tagFile:
    ///   - exportPicture:
    /// - Returns: (sample-rate, bps)
    /// - Throws:
    public static func exportTag(file: String, tagFile: String, exportPicture: String?) throws -> (Int, Int) {
        let pipe = Pipe.init()
        var arguments: [String] = ["metaflac", "--no-utf8-convert",
                                   "--show-sample-rate", "--show-bps",
                                   "--export-tags-to=\(tagFile)"]
        if exportPicture != nil {
            arguments.append("--export-picture-to=\(exportPicture!)")
        }
        arguments.append(file)
        let p = try Process.run(arguments,
                                wait: true,
                                prepare: {
                                    p in
            p.standardOutput = pipe
        })
        if p.terminationStatus != 0 {
//            throw ExitError.init(terminationStatus: p.terminationStatus)
        }
        let comps = String.init(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).components(separatedBy: "\n").filter({!$0.isEmpty}).map({ Int($0)! })
        return (comps[0], comps[1])
    }
    
    public static func importTag(file: String, tagFile: String) throws {
        let p = try Process.run(["metaflac","--no-utf8-convert",
                                 "--remove-all-tags", "--import-tags-from=\(tagFile)",
                                 file], wait: true)
        if p.terminationStatus != 0 {
            throw ExitError.init(terminationStatus: p.terminationStatus)
        }
    }
    
    public static func removeBlock(file: String, type: String) throws {
        let p = try Process.run(["metaflac",
                                 "--remove", "--block-type=\(type)", file],
                                wait: true)
        if p.terminationStatus != 0 {
            throw ExitError.init(terminationStatus: p.terminationStatus)
        }
    }
    
    public static func importPicture(file: String, picture: String,
                                     pictureType: UInt32) throws {
        let p = try Process.run(["metaflac",
                                  "--import-picture-from=\(pictureType)||||\(picture)",
                                  file],
                                 wait: true)
        if p.terminationStatus != 0 {
            throw ExitError.init(terminationStatus: p.terminationStatus)
        }
    }
    
}
