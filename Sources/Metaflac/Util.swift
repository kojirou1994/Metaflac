//
//  MetadataBlockHeader.swift
//  Metaflac
//
//  Created by Kojirou on 2019/1/28.
//

import Foundation
@_exported import Kwift

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
