//
//  MetadataBlockData.swift
//  Metaflac
//
//  Created by Kojirou on 2019/2/1.
//

import Foundation

public protocol MetadataBlockData: LosslessDataConvertible, CustomStringConvertible {
    
    /// length in bytes
    var length: Int { get }
    
}

extension MetadataBlockData {
    
    /// length in bytes, including the header
    var totalLength: Int {
        return length + 4
    }
    
}
