//
//  MetadataBlock.swift
//  Metaflac
//
//  Created by Kojirou on 2019/2/1.
//

public enum MetadataBlock {
    case streamInfo(StreamInfo)
    case padding(Padding)
    case application(Application)
    case seekTable(SeekTable)
    case vorbisComment(VorbisComment)
    case cueSheet(CueSheet)
    case picture(Picture)
    
    var blockType: BlockType {
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
    
    var length: Int {
        return value.length
    }
    
    var totalLength: Int {
        return value.totalLength
    }
    
    var value: MetadataBlockData {
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
    
    var padding: Padding? {
        switch self {
        case .padding(let v): return v
        default: return nil
        }
    }
    
    var picture: Picture? {
        switch self {
        case .picture(let v): return v
        default: return nil
        }
    }
    
    var vorbisComment: VorbisComment? {
        switch self {
        case .vorbisComment(let v): return v
        default: return nil
        }
    }
    
    var streamInfo: StreamInfo? {
        switch self {
        case .streamInfo(let v): return v
        default: return nil
        }
    }
}

extension MetadataBlock: Equatable {
    
}
