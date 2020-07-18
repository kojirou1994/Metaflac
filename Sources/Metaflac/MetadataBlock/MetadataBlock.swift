import Foundation

public enum MetadataBlock {
  case streamInfo(StreamInfo)
  case padding(Padding)
  case application(Application)
  case seekTable(SeekTable)
  case vorbisComment(VorbisComment)
  case cueSheet(CueSheet)
  case picture(Picture)
  
  public var blockType: BlockType {
    switch self {
    case .application(_): return .application
    case .cueSheet(_): return .cueSheet
    case .padding(_): return .padding
    case .picture(_): return .picture
    case .seekTable(_): return .seekTable
    case .streamInfo(_): return .streamInfo
    case .vorbisComment(_): return .vorbisComment
    }
  }
  
  internal var length: Int {
    switch self {
    case .application(let v): return v.length
    case .cueSheet(let v): return v.length
    case .padding(let v): return v.length
    case .picture(let v): return v.length
    case .seekTable(let v): return v.length
    case .streamInfo(let v): return v.length
    case .vorbisComment(let v): return v.length
    }
  }
  
  internal func checkLength() throws {
    switch self {
    case .application(let v): try v.checkLength()
    case .cueSheet(let v): try v.checkLength()
    case .padding(let v): try v.checkLength()
    case .picture(let v): try v.checkLength()
    case .seekTable(let v): try v.checkLength()
    case .streamInfo(let v): try v.checkLength()
    case .vorbisComment(let v): try v.checkLength()
    }
  }
  
  internal var totalLength: Int {
    length + MetadataBlockHeader.headerLength
  }
  
  internal func header(lastMetadataBlockFlag: Bool) -> MetadataBlockHeader {
    .init(lastMetadataBlockFlag: lastMetadataBlockFlag, blockType: blockType, length: UInt32(length))
  }
  
  var toPadding: Padding? {
    switch self {
    case .padding(let v): return v
    default: return nil
    }
  }
  
  var toPicture: Picture? {
    switch self {
    case .picture(let v): return v
    default: return nil
    }
  }
  
  var toVorbisComment: VorbisComment? {
    switch self {
    case .vorbisComment(let v): return v
    default: return nil
    }
  }
  
  var toStreamInfo: StreamInfo? {
    switch self {
    case .streamInfo(let v): return v
    default: return nil
    }
  }
}

extension MetadataBlock: Equatable { }

extension FileHandle {
  internal func write(block: MetadataBlock) throws {
    switch block {
    case .application(let v): write(v.data)
    case .cueSheet(let v): write(v.data)
    case .padding(let v):
      #if swift(>=5.2)
      if #available(OSX 10.15.4, *) {
        try write(contentsOf: v.data)
      } else {
        metaflacWrite(contentsOf: v.data)
      }
      #else
      metaflacWrite(contentsOf: v.data)
      #endif
    case .picture(let v): write(v.data)
    case .seekTable(let v): write(v.data)
    case .streamInfo(let v): write(v.data)
    case .vorbisComment(let v): write(v.data)
    }
  }
  
  private func metaflacWrite<T: DataProtocol>(contentsOf data: T) {
    for region in data.regions {
      region.withUnsafeBytes { (bytes) in
        if let baseAddress = bytes.baseAddress, bytes.count > 0 {
          let d = Data(bytesNoCopy: .init(mutating: baseAddress), count: bytes.count, deallocator: .none)
          self.write(d)
        }
      }
    }
  }
}
