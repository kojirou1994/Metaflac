//
//  Metaflac.swift
//  Metaflac
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
        return lazy.compactMap {$0.padding}.reduce(0, { $0 + $1.count + 4 })
    }
    
    var totalLength: Int {
        return reduce(0, {$0 + $1.totalLength})
    }
}

public struct Metaflac {
    
    public private(set) var blocks: NonEmptyArray<MetadataBlock>
    
    /// "fLaC", the FLAC stream marker in ASCII, meaning byte 0 of the stream is 0x66, followed by 0x4C 0x61 0x43
    static let flacHeader: [UInt8] = [0x66, 0x4c, 0x61, 0x43]
    
//    private let filepath: String
    
    private let input: Input
    
    private enum Input {
        case file(String)
        case binary(Data)
    }
    
    private var frameOffset: Int
    
//    var metaSizeOverflow: Bool {
//        return frameOffset < (blocks.totalLength + 4 - blocks.paddingLength)
//    }
    
    public init(filepath: String) throws {
        input = .file(filepath)
        frameOffset = 0
        blocks = .init(.padding(.init(count: 0)), [])
        try reload()
    }
    
    public mutating func reload() throws {
        switch input {
        case .binary(let data):
            try read(data: data)
        case .file(let filepath):
            let data = try Data.init(contentsOf: .init(fileURLWithPath: filepath), options: [.alwaysMapped])
            try read(data: data)
        }
    }
    
    private mutating func read(data: Data) throws {
        let reader = DataHandle.init(data: data)
        
        guard reader.read(4).elementsEqual(Metaflac.flacHeader) else {
            throw MetaflacError.noFlacHeader
        }
        
        let streamInfo: MetadataBlock
        let streamInfoBlockHeader = try MetadataBlockHeader.init(data: reader.read(32/8))
        guard streamInfoBlockHeader.blockType == .streamInfo else {
            throw MetaflacError.noStreamInfo
        }
        streamInfo = try .streamInfo(.init(reader.read(Int(streamInfoBlockHeader.length))))
        
        if streamInfoBlockHeader.lastMetadataBlockFlag {
            // no other blocks
            blocks = .init(streamInfo, [])
        } else {
            var otherBlocks = [MetadataBlock]()
            
            var lastMeta = false
            while !lastMeta {
                let blockHeader = try MetadataBlockHeader.init(data: reader.read(32/8))
                lastMeta = blockHeader.lastMetadataBlockFlag
                let metadata = reader.read(Int(blockHeader.length))
                let block: MetadataBlock
                switch blockHeader.blockType {
                case .streamInfo:
                    throw MetaflacError.extraBlock(.streamInfo)
                //                    block = .streamInfo(try StreamInfo.init(data: metadata))
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
        self.frameOffset = reader.currentIndex
        precondition(frameOffset == (blocks.totalLength+4))
    }
    
    public var streamInfo: StreamInfo {
        if case let MetadataBlock.streamInfo(s) = blocks.first {
            return s
        } else {
            fatalError()
        }
    }
    
    public mutating func append(_ application: Application) {
        blocks.append(.application(application))
    }
    
    public mutating func append(_ picture: Picture) {
        blocks.append(.picture(picture))
    }
    
    public var vorbisComment: VorbisComment? {
        get {
            return blocks.lazy.compactMap {$0.vorbisComment}.first
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
    
    public func save() throws {
        guard case let Input.file(filepath) = input else {
            return
        }
        let blocks = self.blocks
        let writeLength = blocks.totalLength + 4 - blocks.paddingLength
        let paddingLength = frameOffset - writeLength
        if frameOffset < writeLength || paddingLength < 4 {
            // TODO: create a new file
            let tempFilepath = filepath.appendingPathExtension("metaflac_edit")
            let newPaddingLength = 4000
            try? FileManager.default.removeItem(atPath: tempFilepath)
            FileManager.default.createFile(atPath: tempFilepath, contents: nil, attributes: nil)
            let fh = try FileHandle.init(forWritingTo: .init(fileURLWithPath: tempFilepath))
            fh.write(.init(Metaflac.flacHeader))
            fh.write(blocks: blocks)
            fh.write(MetadataBlockHeader.init(lastMetadataBlockFlag: true, blockType: .padding, length: UInt32(newPaddingLength)).encode())
            fh.write(Padding.init(count: newPaddingLength).data)
            fh.write(try Data.init(contentsOf: .init(fileURLWithPath: filepath), options: [.alwaysMapped])[4...])
            fh.closeFile()
            try FileManager.default.removeItem(atPath: filepath)
            try FileManager.default.moveItem(atPath: tempFilepath, toPath: filepath)
        } else {
            let fh = try FileHandle.init(forWritingTo: .init(fileURLWithPath: filepath))
            print(fh.offsetInFile)
            fh.seek(toFileOffset: 4)
            fh.write(blocks: blocks)
            precondition(writeLength == fh.offsetInFile)
            fh.write(MetadataBlockHeader.init(lastMetadataBlockFlag: true, blockType: .padding, length: UInt32(paddingLength - 4)).encode())
            fh.write(Padding.init(count: paddingLength - 4).data)
            fh.closeFile()
        }
    }
    
}

private extension FileHandle {
    
    func write(blocks: NonEmptyArray<MetadataBlock>) {
        let writeBlocks = blocks.filter { $0.blockType != .padding }
        for block in writeBlocks.enumerated() {
            write(block.element.header(lastMetadataBlockFlag: false).encode())
            write(block.element.value.data)
        }
    }
    
}
