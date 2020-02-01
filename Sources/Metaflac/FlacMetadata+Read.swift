import Foundation

extension FlacMetadata {

    public typealias BlockReadCallback = (_ header: MetadataBlockHeader, _ blockData: Data) throws -> Void

    public struct FlacMetadataReaderResult {
        public let streamInfo: StreamInfo
        public let offset: Int
    }

    public static func read<H: ByteReaderProtocol>(handle: H, callback: BlockReadCallback) throws -> FlacMetadataReaderResult {
        guard handle.read(4).elementsEqual(FlacMetadata.flacHeader) else {
            throw MetaflacError.noFlacHeader
        }

        let streamInfoBlockHeader = try MetadataBlockHeader(data: handle.read(4))
        guard streamInfoBlockHeader.blockType == .streamInfo else {
            throw MetaflacError.noStreamInfo
        }
        let streamInfo = try StreamInfo(handle.read(Int(streamInfoBlockHeader.length)))

        if streamInfoBlockHeader.lastMetadataBlockFlag {
            // no other blocks
            return .init(streamInfo: streamInfo, offset: handle.currentIndex)
        }

        var lastMeta = false
        while !lastMeta {
            let blockHeader = try MetadataBlockHeader(data: handle.read(4))
            lastMeta = blockHeader.lastMetadataBlockFlag
            let blockData = handle.read(Int(blockHeader.length))
            try callback(blockHeader, blockData)
        }

        return .init(streamInfo: streamInfo, offset: handle.currentIndex)
    }

    internal static func readBlocks<H: ByteReaderProtocol>(handle: H) throws -> MetadataBlocks {

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
                otherBlocks.append(.padding(.init(blockData)))
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
