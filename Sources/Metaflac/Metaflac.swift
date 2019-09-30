import Foundation
import URLFileManager

public enum MetaflacError: Error {
    case noFlacHeader
    case noStreamInfo
    case extraBlock(BlockType)
    case invalidBlockType(code: UInt8)
    case unSupportedBlockType(BlockType)
    case extraDataInMetadataBlock(data: Data)
    case invalidPictureType(code: UInt32)
    case exceedMaxBlockLength
}

public struct FlacMetadata {
    
    public struct MetadataBlocks {
        
        public let streamInfo: StreamInfo
        
        public var otherBlocks: [MetadataBlock]
        
        internal var totalLength: Int {
            otherBlocks.reduce(streamInfo.totalLength,
                               {$0 + $1.totalLength})
        }
        
        internal var totalNonPaddingLength: Int {
            otherBlocks.reduce(streamInfo.totalLength,
                               {$0 + ($1.blockType == .padding ? 0 : $1.totalLength)})
        }
        
        var paddingLength: Int {
            otherBlocks.reduce(0, { $0 + ($1.toPadding?.totalLength ?? 0) })
        }
    }
    
    public var blocks: MetadataBlocks
    
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
        self.blocks = .init(streamInfo: StreamInfo(minimumBlockSize: 0, maximumBlockSize: 0, minimumFrameSize: 0, maximumFrameSize: 0, sampleRate: 0, numberOfChannels: 0, bitsPerSampe: 0, totalSamples: 0, md5Signature: .init(count: 16)), otherBlocks: [])
        try reload()
    }
    
    public mutating func reload() throws {
        switch input {
        case .binary(let data):
            try read(handle: DataHandle.init(data: data))
        case .file(let url):
            try autoreleasepool {
                try read(handle: FileHandle.init(forReadingFrom: url))
            }
        }
    }
    
    private mutating func read<H: ReadHandle>(handle: H) throws {
        
        guard handle.read(4).elementsEqual(FlacMetadata.flacHeader) else {
            throw MetaflacError.noFlacHeader
        }
        
        let streamInfo: StreamInfo
        let streamInfoBlockHeader = try MetadataBlockHeader.init(data: handle.read(4))
        guard streamInfoBlockHeader.blockType == .streamInfo else {
            throw MetaflacError.noStreamInfo
        }
        streamInfo = try .init(handle.read(Int(streamInfoBlockHeader.length)))
        
        if streamInfoBlockHeader.lastMetadataBlockFlag {
            // no other blocks
            blocks = .init(streamInfo: streamInfo, otherBlocks: [])
        } else {
            var otherBlocks = [MetadataBlock]()
            
            var lastMeta = false
            while !lastMeta {
                let blockHeader = try MetadataBlockHeader.init(data: handle.read(4))
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
                    block = .vorbisComment(try .init(metadata))
                    otherBlocks.append(block)
                case .picture:
                    block = .picture(try .init(metadata))
                    otherBlocks.append(block)
                case .padding:
                    otherBlocks.append(.padding(.init(metadata)))
                case .seekTable:
                    if otherBlocks.contains(where: {$0.blockType == .seekTable}) {
                        throw MetaflacError.extraBlock(.seekTable)
                    }
                    block = .seekTable(try .init(metadata))
                    otherBlocks.append(block)
                case .cueSheet:
                    throw MetaflacError.unSupportedBlockType(.cueSheet)
                case .invalid:
                    throw MetaflacError.unSupportedBlockType(.invalid)
                case .application:
                    block = try .application(.init(metadata))
                    otherBlocks.append(block)
                }
            }
            self.blocks = .init(streamInfo: streamInfo, otherBlocks: otherBlocks)
        }
        precondition(handle.currentIndex == (blocks.totalLength+4))
        precondition(blocks.totalLength == blocks.totalNonPaddingLength + blocks.paddingLength)
    }
    
    public var streamInfo: StreamInfo {
        blocks.streamInfo
    }
    
    public mutating func append(_ application: Application) {
        blocks.otherBlocks.append(.application(application))
    }
    
    public mutating func append(_ picture: Picture) {
        blocks.otherBlocks.append(.picture(picture))
    }
    
    public mutating func removeBlocks(of types: BlockType...) {
        let newTail = blocks.otherBlocks.filter {!types.contains($0.blockType)}
        self.blocks.otherBlocks = newTail
    }
    
    public var vorbisComment: VorbisComment? {
        get {
            for block in blocks.otherBlocks {
                if case let .vorbisComment(v) = block {
                    return v
                }
            }
            return nil
        }
        set {
            if let index = blocks.otherBlocks.firstIndex(where: { $0.blockType == .vorbisComment }) {
                if let value = newValue {
                    blocks.otherBlocks[index] = .vorbisComment(value)
                } else {
                    // remove this block, set to padding
                    let oldLength = blocks.otherBlocks[index].length
                    blocks.otherBlocks[index] = .padding(.init(count: oldLength))
                }
            } else {
                if let value = newValue {
                    blocks.otherBlocks.append(.vorbisComment(value))
                }
            }
        }
    }
    
    private func findFrameOffset(_ handle: FileHandle) throws -> Int {
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
    /// - Parameter newPaddingLength: the new created file's padding length
    /// - Parameter atomic: A hint to force write data to an auxiliary file first and then exchange the files.
    public func save(newPaddingLength: Int = 4000,
                     atomic: Bool) throws {
        guard case let Input.file(sourceFile) = input else {
            return
        }
        try blocks.otherBlocks.forEach { try $0.checkLength() }
        try autoreleasepool {
            let blocks = self.blocks
            let totalWriteLength = blocks.totalNonPaddingLength + 4
            let sourceFileHandle = try FileHandle.init(forUpdating: sourceFile)
            let currentHeadLength = try findFrameOffset(sourceFileHandle)
            let restAvailableLength = currentHeadLength - totalWriteLength - MetadataBlockHeader.headerLength
            let needNewFile = restAvailableLength < 0 || atomic
            if needNewFile {
                // MARK: create a new file
                let tempFileURL = sourceFile.deletingLastPathComponent()
                    .appendingPathComponent("\(UUID().uuidString).flac")
                do {
                    if URLFileManager.default.fileExistance(at: tempFileURL).exists {
                        try URLFileManager.default.removeItem(at: tempFileURL)
                    }
                    _ = URLFileManager.default.createFile(at: tempFileURL)
                    
                    let tempFileHandle = try FileHandle(forWritingTo: tempFileURL)
                    // flac header
                    tempFileHandle.write(.init(FlacMetadata.flacHeader))
                    // meta blocks
                    if newPaddingLength <= 0 {
                        // no padding
                        tempFileHandle.write(blocks: blocks, containLastMetadataBlock: true)
                        precondition(totalWriteLength == tempFileHandle.offsetInFile)
                    } else {
                        tempFileHandle.write(blocks: blocks, containLastMetadataBlock: false)
                        precondition(totalWriteLength == tempFileHandle.offsetInFile)
                        tempFileHandle.writeLastPadding(count: newPaddingLength)
                    }
                    // frames
                    let restData = sourceFileHandle.readDataToEndOfFile()
                    tempFileHandle.write(restData)
                    tempFileHandle.closeFile()
                    sourceFileHandle.closeFile()
                    _ = try URLFileManager.default.replaceItemAt(sourceFile, withItemAt: tempFileURL, options: [])
                } catch {
                    try? URLFileManager.default.removeItem(at: tempFileURL)
                    throw error
                }
            } else {
                sourceFileHandle.seek(toFileOffset: 4)
                if restAvailableLength == 0 {
                    sourceFileHandle.write(blocks: blocks, containLastMetadataBlock: true)
                    precondition(totalWriteLength == sourceFileHandle.offsetInFile)
                } else {
                    sourceFileHandle.write(blocks: blocks, containLastMetadataBlock: false)
                    precondition(totalWriteLength == sourceFileHandle.offsetInFile)
                    sourceFileHandle.writeLastPadding(count: restAvailableLength)
                }
                sourceFileHandle.closeFile()
            }
        }
        
    }
    
}

extension FileHandle {
    
    fileprivate func write(blocks: FlacMetadata.MetadataBlocks, containLastMetadataBlock: Bool) {
        let nonPaddingBlocks = blocks.otherBlocks.filter {$0.blockType != .padding}
        if nonPaddingBlocks.isEmpty {
            // only a StreamInfo block
            write(block: .streamInfo(blocks.streamInfo), isLastMetadataBlock: containLastMetadataBlock)
        } else {
            write(block: .streamInfo(blocks.streamInfo), isLastMetadataBlock: false)
            for (offset, element) in nonPaddingBlocks.enumerated() {
                if offset == nonPaddingBlocks.count - 1 {
                    write(block: element,
                          isLastMetadataBlock: containLastMetadataBlock)
                } else {
                    write(block: element, isLastMetadataBlock: false)
                }
            }
        }
    }
    
    fileprivate func writeLastPadding(count: Int) {
        write(block: .padding(.init(count: count)), isLastMetadataBlock: true)
    }
    
    private func write(block: MetadataBlock, isLastMetadataBlock: Bool) {
        let header = block.header(lastMetadataBlockFlag: isLastMetadataBlock)
        let decoded = try! MetadataBlockHeader.init(data: header.encode())
        precondition(header == decoded)
        write(header.encode())
        write(block.data)
    }
    
}
