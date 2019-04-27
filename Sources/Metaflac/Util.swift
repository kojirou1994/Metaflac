//
//  MetadataBlockHeader.swift
//  Metaflac
//
//  Created by Kojirou on 2019/1/28.
//

import Foundation
@_exported import KwiftUtility
@_exported import SwiftEnhancement

protocol ReadHandle {
    func read(_ count: Int) -> Data
    
    func skip(_ count: Int)
    
    var currentIndex: Int {get}
}

extension FileHandle: ReadHandle {
    
    func read(_ count: Int) -> Data {
        return readData(ofLength: count)
    }
    
    var currentIndex: Int {
        return Int(offsetInFile)
    }
    
    func skip(_ count: Int) {
        seek(toFileOffset: offsetInFile + UInt64(count))
    }
    
}
extension DataHandle: ReadHandle {
    
}

extension DataHandle {
    
    func check() throws {
        if isAtEnd {
//            print("finished")
        } else {
//            print("there is unused data")
            throw MetaflacError.extraDataInMetadataBlock(data: readToEnd())
        }
    }
    
}
