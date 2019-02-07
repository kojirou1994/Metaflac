//
//  MetadataBlockData.swift
//  Metaflac
//
//  Created by Kojirou on 2019/2/1.
//

import Foundation

public protocol MetadataBlockData: LosslessDataConvertible, CustomStringConvertible {
    
    /// in bytes
    var length: Int { get }
    
}

extension MetadataBlockData {
    
    var totalLength: Int {
        return length + 4
    }
    
}
