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
        return value.length
    }
    
    public var totalLength: Int {
        return value.totalLength
    }
    
    public var value: MetadataBlockData {
        switch self {
        case .application(let v): return v
        case .cueSheet(let v): return v
        case .padding(let v): return v
        case .picture(let v): return v
        case .seekTable(let v): return v
        case .streamInfo(let v): return v
        case .vorbisComment(let v): return v
        }
    }
    
    
    func header(lastMetadataBlockFlag: Bool) -> MetadataBlockHeader {
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
