import Foundation
import NonEmpty
import URLFileManager

public enum MetaflacError: Error {
    case noFlacHeader
    case noStreamInfo
    case extraBlock(BlockType)
    case invalidBlockType(code: UInt8)
    case unSupportedBlockType(BlockType)
    case extraDataInMetadataBlock(data: Data)
    case invalidPictureType(code: UInt32)
}

extension NonEmpty where Element == MetadataBlock {
    
    var paddingLength: Int {
        return lazy.compactMap {$0.toPadding}.reduce(0, { $0 + $1.count + 4 })
    }
    
    var totalLength: Int {
        return reduce(0, {$0 + $1.totalLength})
    }
}

public struct FlacMetadata {
    
    public private(set) var blocks: NonEmptyArray<MetadataBlock> = .init(.padding(.init(count: 0)), [])
    
    /// "fLaC", the FLAC stream marker in ASCII, meaning byte 0 of the stream is 0x66, followed by 0x4C 0x61 0x43
    private static let flacHeader: [UInt8] = [0x66, 0x4c, 0x61, 0x43]
    
    private let input: Input
    
    private enum Input {
        case file(URL)
        case binary(Data)
    }
    
    public init(file: URL) throws {
        try self.init(input: .file(file))
    }
    
    public init(filepath: String) throws {
        try self.init(input: .file(URL(fileURLWithPath: filepath)))
    }
    
    public init(binary data: Data) throws {
        try self.init(input: .binary(data))
    }
    
    private init(input: Input) throws {
        self.input = input
        try reload()
    }
    
    public mutating func reload() throws {
        switch input {
        case .binary(let data):
            try read(handle: DataHandle.init(data: data))
        case .file(let url):
            try read(handle: FileHandle.init(forReadingFrom: url))
        }
    }
    
    private mutating func read<H: ReadHandle>(handle: H) throws {
        
        guard handle.read(4).elementsEqual(FlacMetadata.flacHeader) else {
            throw MetaflacError.noFlacHeader
        }
        
        let streamInfo: MetadataBlock
        let streamInfoBlockHeader = try MetadataBlockHeader.init(data: handle.read(32/8))
        guard streamInfoBlockHeader.blockType == .streamInfo else {
            throw MetaflacError.noStreamInfo
        }
        streamInfo = try .streamInfo(.init(handle.read(Int(streamInfoBlockHeader.length))))
        
        if streamInfoBlockHeader.lastMetadataBlockFlag {
            // no other blocks
            blocks = .init(streamInfo, [])
        } else {
            var otherBlocks = [MetadataBlock]()
            
            var lastMeta = false
            while !lastMeta {
                let blockHeader = try MetadataBlockHeader.init(data: handle.read(32/8))
                lastMeta = blockHeader.lastMetadataBlockFlag
                let metadata = handle.read(Int(blockHeader.length))
                let block: MetadataBlock
                switch blockHeader.blockType {
                case .streamInfo:
                    throw MetaflacError.extraBlock(.streamInfo)
                case .vorbisComment:
                    // There may be only one VORBIS_COMMENT block in a stream
                    if otherBlocks.contains(where: {$0.blockType == .vorbisComment}) {
                        throw MetaflacError.extraBlock(.vorbisComment)
                    }
                    block = .vorbisComment(try VorbisComment.init(metadata))
                    otherBlocks.append(block)
                case .picture:
                    block = .picture(try Picture.init(metadata))
                    otherBlocks.append(block)
                case .padding:
                    otherBlocks.append(.padding(.init(metadata)))
                case .seekTable:
                    if otherBlocks.contains(where: {$0.blockType == .seekTable}) {
                        throw MetaflacError.extraBlock(.seekTable)
                    }
                    block = .seekTable(try SeekTable.init(metadata))
                    otherBlocks.append(block)
                case .cueSheet:
                    throw MetaflacError.unSupportedBlockType(.cueSheet)
                case .invalid:
                    throw MetaflacError.unSupportedBlockType(blockHeader.blockType)
                case .application:
                    block = try .application(.init(metadata))
                    otherBlocks.append(block)
                }
            }
            self.blocks = .init(streamInfo, otherBlocks)
        }
        precondition(handle.currentIndex == (blocks.totalLength+4))
    }
    
    public var streamInfo: StreamInfo {
        if case let MetadataBlock.streamInfo(s) = blocks.head {
            return s
        } else {
            fatalError("Missing stream info block")
        }
    }
    
    public mutating func append(_ application: Application) {
        blocks.append(.application(application))
    }
    
    public mutating func append(_ picture: Picture) {
        blocks.append(.picture(picture))
    }
    
    public mutating func removeBlocks(of types: BlockType...) {
        let newTail = blocks.tail.filter {!types.contains($0.blockType)}
        let head = blocks.head
        self.blocks = .init(head, newTail)
    }
    
    public var vorbisComment: VorbisComment? {
        get {
            for block in blocks {
                if case let .vorbisComment(v) = block {
                    return v
                }
            }
            return nil
        }
        set {
            if let index = blocks.firstIndex(where: { $0.blockType == .vorbisComment }) {
                if let value = newValue {
                    blocks[index] = .vorbisComment(value)
                } else {
                    // remove this block, set to padding
                    let oldLength = blocks[index].length
                    blocks[index] = .padding(.init(count: oldLength))
                }
            } else {
                if let value = newValue {
                    blocks.append(.vorbisComment(value))
                }
            }
        }
    }
    
    private func findFrameOffset(handle: FileHandle) throws -> Int {
//        handle.seek(toFileOffset: 0)
        guard handle.read(4).elementsEqual(FlacMetadata.flacHeader) else {
            throw MetaflacError.noFlacHeader
        }
        
        let streamInfoBlockHeader = try MetadataBlockHeader.init(data: handle.read(32/8))
        guard streamInfoBlockHeader.blockType == .streamInfo else {
            throw MetaflacError.noStreamInfo
        }
        handle.skip(Int(streamInfoBlockHeader.length))
        if streamInfoBlockHeader.lastMetadataBlockFlag {
            // no other blocks
        } else {
            var lastMeta = false
            while !lastMeta {
                let blockHeader = try MetadataBlockHeader.init(data: handle.read(32/8))
                lastMeta = blockHeader.lastMetadataBlockFlag
                handle.skip(Int(blockHeader.length))
            }
        }
        return handle.currentIndex
    }
    
    /// if the input is binary input, it won't save
    ///
    /// - Throws: NSError from FileHandle
    public func save(newPaddingLength: Int = 4000, tempPath: URL? = nil) throws {
        guard case let Input.file(sourceFile) = input else {
            return
        }
        let blocks = self.blocks
        let writeLength = blocks.totalLength + 4 - blocks.paddingLength
        let sourceFileHandle = try FileHandle.init(forUpdating: sourceFile)
        let frameOffset = try findFrameOffset(handle: sourceFileHandle)
        let paddingLength = frameOffset - writeLength
        if frameOffset < writeLength || paddingLength < 4 {
            // MARK: create a new file
            let tempFilepath = (tempPath ?? sourceFile.deletingLastPathComponent())
                .appendingPathComponent("\(UUID().uuidString).flac")
//                filepath.appendingPathExtension("metaflac_edit")
            if URLFileManager.default.fileExistance(at: tempFilepath).exists {
                try URLFileManager.default.removeItem(at: tempFilepath)
            }
            _ = URLFileManager.default.createFile(at: tempFilepath)
            
            let tempFileHandle = try FileHandle.init(forWritingTo: tempFilepath)
            tempFileHandle.write(.init(FlacMetadata.flacHeader))
            tempFileHandle.write(blocks: blocks)
            tempFileHandle.write(block: .padding(Padding.init(count: newPaddingLength)), isLastMetadataBlock: true)
            tempFileHandle.write(sourceFileHandle.readDataToEndOfFile())
            tempFileHandle.closeFile()
            sourceFileHandle.closeFile()
            _ = try URLFileManager.default.replaceItemAt(sourceFile, withItemAt: tempFilepath, options: .usingNewMetadataOnly)
        } else {
            sourceFileHandle.seek(toFileOffset: 4)
            sourceFileHandle.write(blocks: blocks)
            precondition(writeLength == sourceFileHandle.offsetInFile)
            sourceFileHandle.write(block: .padding(Padding.init(count: paddingLength - 4)), isLastMetadataBlock: true)
            sourceFileHandle.closeFile()
        }
    }
    
}

private extension FileHandle {
    
    func write(blocks: NonEmptyArray<MetadataBlock>) {
        for block in blocks {
            if block.blockType == .padding {
                continue
            }
            write(block.header(lastMetadataBlockFlag: false).encode())
            write(block.value.data)
        }
    }
    
    func write(block: MetadataBlock, isLastMetadataBlock: Bool) {
        write(block.header(lastMetadataBlockFlag: isLastMetadataBlock).encode())
        write(block.value.data)
    }
    
}
