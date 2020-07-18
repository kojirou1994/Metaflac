import Foundation

public struct MetadataBlockHeader: CustomStringConvertible, Equatable {
    
    internal static let headerLength = 4
    
    internal static let maxBlockLength: UInt32 = 0xffffff

    /// Last-metadata-block flag: '1' if this block is the last metadata block before the audio blocks, '0' otherwise.
    public let lastMetadataBlockFlag: Bool
    
    public let blockType: BlockType
    
    /// Length (in bytes) of metadata to follow (does not include the size of the METADATA_BLOCK_HEADER)
    public let length: UInt32
    
  internal init<D: DataProtocol>(_ data: D) throws {
        let compressed = data.joined(UInt32.self)
        lastMetadataBlockFlag = compressed >> 31 == 1
        let btCode = UInt8.init(truncatingIfNeeded: (compressed << 1) >> 25)
        guard let blockType = BlockType.init(rawValue: btCode) else {
            throw MetaflacError.invalidBlockType(code: btCode)
        }
        self.blockType = blockType
        length = (compressed << 8) >> 8
    }
    
    internal init(lastMetadataBlockFlag: Bool, blockType: BlockType, length: UInt32) {
        precondition(length <= Self.maxBlockLength)
        self.lastMetadataBlockFlag = lastMetadataBlockFlag
        self.blockType = blockType
        self.length = length
    }
    
    internal func encode() -> Data {
        var compressed: UInt32 = 0
        let v1 = blockType.rawValue | ((lastMetadataBlockFlag ? 1 : 0 ) << 7)
        compressed |= UInt32(v1) << 24
        compressed |= length
        return Data(compressed.bytes)
    }
    
    public var description: String {
        """
        type: \(blockType.rawValue) (\(blockType))
        is last: \(lastMetadataBlockFlag)
        length: \(length)
        """
    }
    
}
