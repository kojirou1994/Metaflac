import Foundation
import URLFileManager

public enum MetaflacError: Error {
  case noFlacHeader
  case noStreamInfo
  case extraBlock(FlacMetadataType)
  case invalidBlockType(code: UInt8)
  case unSupportedBlockType(FlacMetadataType)
  case extraDataInMetadataBlock(data: [UInt8])
  case invalidPictureType(code: UInt32)
  case exceedMaxBlockLength
}

public struct FlacMetadata {

  /// 50 MB
  public static var maxBufferLength = 50_000_000

  public struct MetadataBlocks {

    public let streamInfo: FlacMetadataBlock.StreamInfo

    public var otherBlocks: [FlacMetadataBlock]

    internal var totalLength: Int {
      otherBlocks.reduce(streamInfo.totalLength,
                         {$0 + $1.totalLength})
    }

    internal var totalNonPaddingLength: Int {
      otherBlocks.reduce(streamInfo.totalLength,
                         {$0 + ($1.blockType == .padding ? 0 : $1.totalLength)})
    }

    internal var paddingLength: Int {
      otherBlocks.reduce( into: 0,{
        switch $1 {
        case .padding(let v): $0 += v.totalLength
        default: break
        }
      })
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
  public var streamInfo: FlacMetadataBlock.StreamInfo {
    blocks.streamInfo
  }

  @inlinable
  public mutating func append(_ application: FlacMetadataBlock.Application) {
    blocks.otherBlocks.append(.application(application))
  }

  @inlinable
  public mutating func append(_ picture: FlacMetadataBlock.Picture) {
    blocks.otherBlocks.append(.picture(picture))
  }

  @inlinable
  public mutating func removeBlocks(of types: FlacMetadataType...) {
    let newTail = blocks.otherBlocks.filter {!types.contains($0.blockType)}
    self.blocks.otherBlocks = newTail
  }

  public var vorbisComment: FlacMetadataBlock.VorbisComment? {
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

  @inline(__always)
  private func findFrameOffset(_ handle: FileHandle) throws -> Int {
    try Self.read(handle: handle, callback: {_,_ in}).offset
  }

  public enum PaddingMode {
    /// make sure padding length is the given value
    case exact(length: UInt32)
    /// auto resize file length to make sure padding length <= given value
    case autoResize(upTo: UInt32)

    @inlinable
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
  public func save(paddingMode: PaddingMode, atomic: Bool) throws {
    guard case let .file(sourceFile) = input else {
      return
    }
    try blocks.otherBlocks.forEach { try $0.checkLength() }
    try autoreleasepool {
      let totalWriteLength = blocks.totalNonPaddingLength + 4 // flac header
      let sourceFileHandle = try FileHandle(forUpdating: sourceFile)
      let currentHeadLength = try findFrameOffset(sourceFileHandle)
      let restAvailablePaddingLength = currentHeadLength - totalWriteLength - FlacMetadataBlockConstants.headerLength

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
      #if canImport(Darwin)
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
