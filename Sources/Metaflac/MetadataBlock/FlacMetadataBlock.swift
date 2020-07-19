import Foundation

public enum FlacMetadataBlock: Equatable {
  case streamInfo(StreamInfo)
  case padding(Padding)
  case application(Application)
  case seekTable(SeekTable)
  case vorbisComment(VorbisComment)
  case cueSheet(CueSheet)
  case picture(Picture)
  
  public var blockType: FlacMetadataType {
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
    case .application(let v): return v.blockLength
    case .cueSheet(let v): return v.blockLength
    case .padding(let v): return v.blockLength
    case .picture(let v): return v.blockLength
    case .seekTable(let v): return v.blockLength
    case .streamInfo(let v): return v.blockLength
    case .vorbisComment(let v): return v.blockLength
    }
  }

  @inlinable
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
    length + FlacMetadataBlockConstants.headerLength
  }

  public func header(lastMetadataBlockFlag: Bool) -> FlacMetadataBlockHeader {
    .init(lastMetadataBlockFlag: lastMetadataBlockFlag, blockType: blockType, length: UInt32(length))
  }
  
}
