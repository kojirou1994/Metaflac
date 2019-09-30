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
    
    public var length: Int {
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

    public var totalLength: Int {
        return length + MetadataBlockHeader.headerLength
    }
    
    public var data: Data {
        switch self {
        case .application(let v): return v.data
        case .cueSheet(let v): return v.data
        case .padding(let v): return v.data
        case .picture(let v): return v.data
        case .seekTable(let v): return v.data
        case .streamInfo(let v): return v.data
        case .vorbisComment(let v): return v.data
        }
    }
    
//    public var value: MetadataBlockData {
//        switch self {
//        case .application(let v): return v
//        case .cueSheet(let v): return v
//        case .padding(let v): return v
//        case .picture(let v): return v
//        case .seekTable(let v): return v
//        case .streamInfo(let v): return v
//        case .vorbisComment(let v): return v
//        }
//    }
    
    internal func header(lastMetadataBlockFlag: Bool) -> MetadataBlockHeader {
        return .init(lastMetadataBlockFlag: lastMetadataBlockFlag, blockType: blockType, length: UInt32(length))
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
