//
//  FlacMetadata.swift
//  FlacMetadata
//
//  Created by Kojirou on 2019/2/1.
//

import Foundation
import NonEmpty

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
        case file(String)
        case binary(Data)
    }
    
//    private var frameOffset = 0
    
    public init(filepath: String) throws {
        input = .file(filepath)
        try reload()
    }
    
    public init(binary data: Data) throws {
        input = .binary(data)
        try reload()
    }
    
    public mutating func reload() throws {
        switch input {
        case .binary(let data):
            try read(handle: DataHandle.init(data: data))
        case .file(let filepath):
            try read(handle: FileHandle.init(forReadingFrom: .init(fileURLWithPath: filepath)))
        }
    }
    
    private mutating func read(handle: ReadHandle) throws {
        
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
//        self.frameOffset = handle.currentIndex
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
    public func save(newPaddingLength: Int = 4000) throws {
        guard case let Input.file(sourceFile) = input else {
            return
        }
        let blocks = self.blocks
        let writeLength = blocks.totalLength + 4 - blocks.paddingLength
        let sourceFileHandle = try FileHandle.init(forUpdating: .init(fileURLWithPath: sourceFile))
        let frameOffset = try findFrameOffset(handle: sourceFileHandle)
        let paddingLength = frameOffset - writeLength
        if frameOffset < writeLength || paddingLength < 4 {
            // MARK: create a new file
            let tempFilepath = UUID.init().uuidString.appendingPathExtension("flac")
//                filepath.appendingPathExtension("metaflac_edit")
            try? FileManager.default.removeItem(atPath: tempFilepath)
            FileManager.default.createFile(atPath: tempFilepath, contents: nil, attributes: nil)
            let fh = try FileHandle.init(forWritingTo: .init(fileURLWithPath: tempFilepath))
            fh.write(.init(FlacMetadata.flacHeader))
            fh.write(blocks: blocks)
            fh.write(block: .padding(Padding.init(count: newPaddingLength)), isLastMetadataBlock: true)
            fh.write(sourceFileHandle.readDataToEndOfFile())
            fh.closeFile()
            sourceFileHandle.closeFile()
            try FileManager.default.removeItem(atPath: sourceFile)
            try FileManager.default.moveItem(atPath: tempFilepath, toPath: sourceFile)
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
