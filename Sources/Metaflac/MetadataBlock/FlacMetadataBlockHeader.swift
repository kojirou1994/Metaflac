import Foundation

public struct FlacMetadataBlockHeader: CustomStringConvertible, Equatable {
  
  /// Last-metadata-block flag: '1' if this block is the last metadata block before the audio blocks, '0' otherwise.
  public let lastMetadataBlockFlag: Bool
  
  public let blockType: FlacMetadataType
  
  /// Length (in bytes) of metadata to follow (does not include the size of the METADATA_BLOCK_HEADER)
  public let length: UInt32
  
  public init<D: DataProtocol>(_ data: D) throws {
    assert(data.count == 4)
    let compressed = data.joined(UInt32.self)
    lastMetadataBlockFlag = compressed >> 31 == 1
    let btCode = UInt8(truncatingIfNeeded: (compressed << 1) >> 25)
    self.blockType = try FlacMetadataType(rawValue: btCode).unwrap(MetaflacError.invalidBlockType(code: btCode))
    length = (compressed << 8) >> 8
  }
  
  public init(lastMetadataBlockFlag: Bool, blockType: FlacMetadataType, length: UInt32) {
    precondition(length <= FlacMetadataBlockConstants.maxBlockLength)
    self.lastMetadataBlockFlag = lastMetadataBlockFlag
    self.blockType = blockType
    self.length = length
  }
  
  public func encode() -> [UInt8] {
    var compressed: UInt32 = 0
    let v1 = blockType.rawValue | ((lastMetadataBlockFlag ? 1 : 0 ) << 7)
    compressed |= UInt32(v1) << 24
    compressed |= length
    return compressed.bytes
  }
  
  public var description: String {
    """
    type: \(blockType.rawValue) (\(blockType))
    is last: \(lastMetadataBlockFlag)
    length: \(length)
    """
  }
  
}
