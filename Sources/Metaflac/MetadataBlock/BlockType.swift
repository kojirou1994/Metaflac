public enum BlockType: UInt8, CaseIterable, CustomStringConvertible {
    
    case streamInfo = 0
    case padding
    case application
    case seekTable
    case vorbisComment
    case cueSheet
    case picture
    case invalid = 127
    
    public var description: String {
        switch self {
        case .application: return "APPLICATION"
        case .cueSheet: return "CUESHEET"
        case .invalid: return "INVALID"
        case .padding: return "PADDING"
        case .picture: return "PICTURE"
        case .seekTable: return "SEEKTABLE"
        case .streamInfo: return "STREAMINFO"
        case .vorbisComment: return "VORBIS_COMMENT"
        }
    }
    
}
