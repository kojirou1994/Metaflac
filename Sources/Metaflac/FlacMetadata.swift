import Foundation
import URLFileManager

public enum MetaflacError: Error {
    case noFlacHeader
    case noStreamInfo
    case extraBlock(BlockType)
    case invalidBlockType(code: UInt8)
    case unSupportedBlockType(BlockType)
    case extraDataInMetadataBlock(data: [UInt8])
    case invalidPictureType(code: UInt32)
    case exceedMaxBlockLength
}

public struct FlacMetadata {
    
    /// 50 MB
    public static var maxBufferLength = 50_000_000
    
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
        
        internal var paddingLength: Int {
            otherBlocks.reduce(0, { $0 + ($1.toPadding?.totalLength ?? 0) })
        }
    }
    
    public var blocks: MetadataBlocks
    
    /// "fLaC", the FLAC stream marker in ASCII, meaning byte 0 of the stream is 0x66, followed by 0x4C 0x61 0x43
    public static let flacHeader: [UInt8] = [0x66, 0x4c, 0x61, 0x43]
    
    private let input: Input
    
    internal enum Input {
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
        self.blocks = try Self.read(input: input)
    }
    
    public mutating func reload() throws {
        self.blocks = try Self.read(input: self.input)
    }
    
    private static func read(input: Input) throws -> MetadataBlocks {
        switch input {
        case .binary(let data):
            return try readBlocks(handle: ByteReader(data))
        case .file(let url):
            return try autoreleasepool {
                try readBlocks(handle: FileHandle(forReadingFrom: url))
            }
        }
    }

    @inlinable
    public var streamInfo: StreamInfo {
        blocks.streamInfo
    }
    
    @inlinable
    public mutating func append(_ application: Application) {
        blocks.otherBlocks.append(.application(application))
    }
    
    @inlinable
    public mutating func append(_ picture: Picture) {
        blocks.otherBlocks.append(.picture(picture))
    }
    
    @inlinable
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
        try Self.read(handle: handle, callback: {_,_ in}).offset
    }
    
    public enum PaddingMode {
        /// make sure padding length is the given value
        case exact(length: UInt32)
        /// auto resize file length to make sure padding length <= given value
        case autoResize(upTo: UInt32)
        
        var number: UInt32 {
            switch self {
            case .exact(length: let v):
                return v
            case .autoResize(upTo: let v):
                return v
            }
        }
    }
    
    /// if the input is binary input, it won't save
    ///
    /// - Throws: NSError from FileHandle
    /// - Parameter newPaddingLength: the new created file's padding length
    /// - Parameter atomic: A hint to force write data to an auxiliary file first and then exchange the files.
    public func save(paddingMode: PaddingMode,
                     atomic: Bool) throws {
        guard case let .file(sourceFile) = input else {
            return
        }
        let blocks = self.blocks
        try blocks.otherBlocks.forEach { try $0.checkLength() }
        try autoreleasepool {
            let totalWriteLength = blocks.totalNonPaddingLength + 4 // flac header
            let sourceFileHandle = try FileHandle(forUpdating: sourceFile)
            let currentHeadLength = try findFrameOffset(sourceFileHandle)
            let restAvailablePaddingLength = currentHeadLength - totalWriteLength - MetadataBlockHeader.headerLength
            
            var useTempFile: Bool
            let tempFilePaddingLength: Int
            if restAvailablePaddingLength < 0 {
                useTempFile = true
                tempFilePaddingLength = Int(paddingMode.number)
            } else {
                switch paddingMode {
                case .autoResize(upTo: let limit):
                    useTempFile = restAvailablePaddingLength > limit
                    tempFilePaddingLength = Int(limit)
                case .exact(length: let length):
                    useTempFile = restAvailablePaddingLength != length
                    tempFilePaddingLength = Int(length)
                }
            }
            #if os(macOS) || os(iOS)
            let useAPFS = atomic
            #else
            useTempFile = useTempFile || atomic
            let useAPFS = false
            #endif
            
            if useTempFile {
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
                    if tempFilePaddingLength <= 0 {
                        // no padding
                        try tempFileHandle.write(blocks: blocks, containLastMetadataBlock: true)
                        precondition(totalWriteLength == tempFileHandle.offsetInFile)
                    } else {
                        try tempFileHandle.write(blocks: blocks, containLastMetadataBlock: false)
                        precondition(totalWriteLength == tempFileHandle.offsetInFile)
                        try tempFileHandle.writeLastPadding(count: tempFilePaddingLength)
                    }
                    // frames
                    while case let buffer = try sourceFileHandle.read(Self.maxBufferLength),
                        !buffer.isEmpty {
                        tempFileHandle.write(buffer)
                    }
                    tempFileHandle.closeFile()
                    sourceFileHandle.closeFile()
                    _ = try URLFileManager.default.replaceItemAt(sourceFile, withItemAt: tempFileURL, options: [])
                } catch {
                    try? URLFileManager.default.removeItem(at: tempFileURL)
                    throw error
                }
            } else {
                // MARK: use APFS feature on apple devices
                if useAPFS {
                    #if DEBUG
                    print("Using APFS to speed up")
                    #endif
                    let tempFileURL = sourceFile.deletingLastPathComponent()
                        .appendingPathComponent("\(UUID().uuidString).flac")
                    do {
                        if URLFileManager.default.fileExistance(at: tempFileURL).exists {
                            try URLFileManager.default.removeItem(at: tempFileURL)
                        }
                        try URLFileManager.default.copyItem(at: sourceFile, to: tempFileURL)
                        
                        let tempFileHandle = try FileHandle(forWritingTo: tempFileURL)
                        
                        tempFileHandle.seek(toFileOffset: 4)
                        if restAvailablePaddingLength == 0 {
                            try tempFileHandle.write(blocks: blocks, containLastMetadataBlock: true)
                            precondition(totalWriteLength == tempFileHandle.offsetInFile)
                        } else {
                            try tempFileHandle.write(blocks: blocks, containLastMetadataBlock: false)
                            precondition(totalWriteLength == tempFileHandle.offsetInFile)
                            try tempFileHandle.writeLastPadding(count: restAvailablePaddingLength)
                        }
                        
                        tempFileHandle.closeFile()
                        sourceFileHandle.closeFile()
                        
                        _ = try URLFileManager.default.replaceItemAt(sourceFile, withItemAt: tempFileURL, options: [])
                    } catch {
                        try? URLFileManager.default.removeItem(at: tempFileURL)
                        throw error
                    }
                } else {
                    sourceFileHandle.seek(toFileOffset: 4)
                    if restAvailablePaddingLength == 0 {
                        try sourceFileHandle.write(blocks: blocks, containLastMetadataBlock: true)
                        precondition(totalWriteLength == sourceFileHandle.offsetInFile)
                    } else {
                        try sourceFileHandle.write(blocks: blocks, containLastMetadataBlock: false)
                        precondition(totalWriteLength == sourceFileHandle.offsetInFile)
                        try sourceFileHandle.writeLastPadding(count: restAvailablePaddingLength)
                    }
                    sourceFileHandle.closeFile()
                }
            }
        }
        
    }
    
}

extension FileHandle {
    
    fileprivate func write(blocks: FlacMetadata.MetadataBlocks, containLastMetadataBlock: Bool) throws {
        let nonPaddingBlocks = blocks.otherBlocks.filter {$0.blockType != .padding}
        if nonPaddingBlocks.isEmpty {
            // only a StreamInfo block
            try write(block: .streamInfo(blocks.streamInfo), isLastMetadataBlock: containLastMetadataBlock)
        } else {
            try write(block: .streamInfo(blocks.streamInfo), isLastMetadataBlock: false)
            for (offset, element) in nonPaddingBlocks.enumerated() {
                if offset == nonPaddingBlocks.count - 1 {
                    try write(block: element,
                          isLastMetadataBlock: containLastMetadataBlock)
                } else {
                    try write(block: element, isLastMetadataBlock: false)
                }
            }
        }
    }
    
    fileprivate func writeLastPadding(count: Int) throws {
        
        let maxPaddingLength = Int(MetadataBlockHeader.maxBlockLength)
        if count <= maxPaddingLength {
            try write(block: .padding(.init(count: count)), isLastMetadataBlock: true)
        } else {
            var rest = count + 4
            while rest >= (8 + maxPaddingLength) {
                try write(block: .padding(.init(count: maxPaddingLength)), isLastMetadataBlock: false)
                rest -= maxPaddingLength + 4
            }
            try write(block: .padding(.init(count: rest-4)), isLastMetadataBlock: true)
        }
    }
    
    private func write(block: MetadataBlock, isLastMetadataBlock: Bool) throws {
        let header = block.header(lastMetadataBlockFlag: isLastMetadataBlock)
//        let decoded = try! MetadataBlockHeader.init(data: header.encode())
//        precondition(header == decoded)
        write(header.encode())
        try write(block: block)
    }
    
}
