//
//  MetadataBlockHeader.swift
//  Metaflac
//
//  Created by Kojirou on 2019/2/1.
//

import Foundation

public struct MetadataBlockHeader: CustomStringConvertible, Equatable {
    public var description: String {
        return """
        type: \(blockType.rawValue) (\(blockType))
        is last: \(lastMetadataBlockFlag)
        length: \(length)
        """
    }
    
    public let lastMetadataBlockFlag: Bool
    public let blockType: BlockType
    public let length: UInt32
    
    init(data: Data) throws {
        let compressed = data.joined(UInt32.self)
        //    Last-metadata-block flag: '1' if this block is the last metadata block before the audio blocks, '0' otherwise.
        lastMetadataBlockFlag = compressed >> 31 == 1
        //        print(lastMetadataBlockFlag)
        let btCode = UInt8.init(truncatingIfNeeded: (compressed << 1) >> 25)
        guard let blockType = BlockType.init(rawValue: btCode) else {
            throw MetaflacError.invalidBlockType(code: btCode)
        }
        self.blockType = blockType
        //        print(blockType)
        //Length (in bytes) of metadata to follow (does not include the size of the METADATA_BLOCK_HEADER)
        length = (compressed << 8) >> 8
        //        print("length: \(length)")
    }
    
    public init(lastMetadataBlockFlag: Bool, blockType: BlockType, length: UInt32) {
//        precondition((0...2^24).contains(length))
        self.lastMetadataBlockFlag = lastMetadataBlockFlag
        self.blockType = blockType
        self.length = length
    }
    
    public func encode() -> Data {
        var compressed: UInt32 = 0
        compressed |= (lastMetadataBlockFlag ? 1 : 0 ) << 31
        compressed |= UInt32(blockType.rawValue) << 24
        compressed |= length
        return Data.init(compressed.splited)
    }
    
}
