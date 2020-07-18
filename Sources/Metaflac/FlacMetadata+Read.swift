import Foundation

extension FlacMetadata {

  public typealias BlockReadCallback<T> = (_ header: MetadataBlockHeader, _ blockData: T) throws -> Void

  public struct FlacMetadataReaderResult {
    public let streamInfo: StreamInfo
    public let offset: Int
  }

  public static func read<H: ByteRegionReaderProtocol>(handle: H, callback: BlockReadCallback<H.ByteRegion>) throws -> FlacMetadataReaderResult where H.ByteRegion.Index == Int {
    var handle = handle
    guard try handle.readInteger(endian: .big, as: UInt32.self) == 0x664c6143 else {
      throw MetaflacError.noFlacHeader
    }

    let streamInfoBlockHeader = try MetadataBlockHeader(handle.read(4))
    guard streamInfoBlockHeader.blockType == .streamInfo else {
      throw MetaflacError.noStreamInfo
    }
    let streamInfo = try StreamInfo(handle.read(Int(streamInfoBlockHeader.length)))

    if streamInfoBlockHeader.lastMetadataBlockFlag {
      // no other blocks
      return .init(streamInfo: streamInfo, offset: handle.readerOffset)
    }

    var lastMeta = false
    while !lastMeta {
      let blockHeader = try MetadataBlockHeader(handle.read(4))
      lastMeta = blockHeader.lastMetadataBlockFlag
      let blockData = try handle.read(Int(blockHeader.length))
      try callback(blockHeader, blockData)
    }

    return .init(streamInfo: streamInfo, offset: handle.readerOffset)
  }

  internal static func readBlocks<H: ByteRegionReaderProtocol>(handle: H) throws -> MetadataBlocks where H.ByteRegion.Index == Int {

    var otherBlocks = [MetadataBlock]()

    let parseResult = try Self.read(handle: handle, callback: { (blockHeader, blockData) in
      let block: MetadataBlock
      switch blockHeader.blockType {
      case .streamInfo:
        throw MetaflacError.extraBlock(.streamInfo)
      case .vorbisComment:
        // There may be only one VORBIS_COMMENT block in a stream
        if otherBlocks.contains(where: {$0.blockType == .vorbisComment}) {
          throw MetaflacError.extraBlock(.vorbisComment)
        }
        block = .vorbisComment(try .init(blockData))
        otherBlocks.append(block)
      case .picture:
        block = .picture(try .init(blockData))
        otherBlocks.append(block)
      case .padding:
        otherBlocks.append(.padding(try .init(blockData)))
      case .seekTable:
        if otherBlocks.contains(where: {$0.blockType == .seekTable}) {
          throw MetaflacError.extraBlock(.seekTable)
        }
        block = .seekTable(try .init(blockData))
        otherBlocks.append(block)
      case .cueSheet:
        throw MetaflacError.unSupportedBlockType(.cueSheet)
      case .invalid:
        throw MetaflacError.unSupportedBlockType(.invalid)
      case .application:
        block = try .application(.init(blockData))
        otherBlocks.append(block)
      }
    })
    return .init(streamInfo: parseResult.streamInfo, otherBlocks: otherBlocks)

    //            precondition(handle.currentIndex == (blocks.totalLength+4))
    //            precondition(blocks.totalLength == blocks.totalNonPaddingLength + blocks.paddingLength)
  }
}
