public enum FlacMetadataType: UInt8, CaseIterable, CustomStringConvertible {
  
  case streamInfo = 0
  case padding = 1
  case application = 2
  case seekTable = 3
  case vorbisComment = 4
  case cueSheet = 5
  case picture = 6
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
