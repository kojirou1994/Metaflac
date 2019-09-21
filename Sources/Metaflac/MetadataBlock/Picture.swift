import Foundation
import KwiftUtility

/// This block is for storing pictures associated with the file, most commonly cover art from CDs. There may be more than one PICTURE block in a file. The picture format is similar to the APIC frame in ID3v2. The PICTURE block has a type, MIME type, and UTF-8 description like ID3v2, and supports external linking via URL (though this is discouraged). The differences are that there is no uniqueness constraint on the description field, and the MIME type is mandatory. The FLAC PICTURE block also includes the resolution, color depth, and palette size so that the client can search for a suitable picture without having to scan them all.
public struct Picture: MetadataBlockData, Equatable {
    
    public enum PictureType: UInt32, CustomStringConvertible {
        case other = 0
        case fileIcon
        case otherFileIcon
        case coverFront
        case coverBack
        case leafletPage
        case media
        case leadArtist
        case artist
        case conductor
        case band
        case composer
        case lyricist
        case recordingLocation
        case duringRecording
        case duringPerformance
        case movieScreenCapture
        case aBrightColouredFish
        case illustration
        case bandLogotype
        case publisherLogotype
        
        public var single: Bool {
            switch self {
            case .otherFileIcon, .fileIcon:
                return true
            default:
                return false
            }
        }
        
        public var description: String {
            switch self {
            case .other:
                return "Other"
            case .fileIcon:
                return "32x32 pixels 'file icon' (PNG only)"
            case .otherFileIcon:
                return "Other file icon"
            case .coverFront:
                return "Cover (front)"
            case .coverBack:
                return "Cover (back)"
            case .leafletPage:
                return "Leaflet page"
            case .media:
                return "Media (e.g. label side of CD)"
            case .leadArtist:
                return "Lead artist/lead performer/soloist"
            case .artist:
                return "Artist/performer"
            case .conductor:
                return "Conductor"
            case .band:
                return "Band/Orchestra"
            case .composer:
                return "Composer"
            case .lyricist:
                return "Lyricist/text writer"
            case .recordingLocation:
                return "Recording Location"
            case .duringRecording:
                return "During recording"
            case .duringPerformance:
                return "During performance"
            case .movieScreenCapture:
                return "Movie/video screen capture"
            case .aBrightColouredFish:
                return "A bright coloured fish"
            case .illustration:
                return "Illustration"
            case .bandLogotype:
                return "Band/artist logotype"
            case .publisherLogotype:
                return "Publisher/Studio logotype"
            }
        }
    }
    
    public let pictureType: PictureType
    
    public let mimeType: String
    
    public let descriptionString: String
    
    public let width: UInt32
    
    public let height: UInt32
    
    public let colorDepth: UInt32
    
    public let numberOfColors: UInt32
    
    public let pictureData: Data
    
    public init(pictureType: PictureType, mimeType: String, description: String,
                width: UInt32, height: UInt32, colorDepth: UInt32, numberOfColors: UInt32,
                pictureData: Data) throws {
        self.pictureType = pictureType
        self.mimeType = mimeType
        self.descriptionString = description
        self.width = width
        self.height = height
        self.colorDepth = colorDepth
        self.numberOfColors = numberOfColors
        self.pictureData = pictureData
        try checkLength()
    }
    
    public init?(file: URL) {
        guard let pictureData = try? Data.init(contentsOf: file),
              let imageInfo = ImageInfo.init(data: pictureData) else {
            return nil
        }
        self.pictureType = .coverFront
        self.mimeType = imageInfo.format.mimeType
        self.descriptionString = ""
        self.width = imageInfo.width
        self.height = imageInfo.height
        self.colorDepth = UInt32(imageInfo.depth)
        self.numberOfColors = imageInfo.colors
        self.pictureData = pictureData
    }
    
    public init(_ data: Data) throws {
        let reader = DataHandle.init(data: data)
        let ptValue = reader.read(4).joined(UInt32.self)
        guard let pictureType = PictureType.init(rawValue: ptValue)  else {
            throw MetaflacError.invalidPictureType(code: ptValue)
        }
        self.pictureType = pictureType
        let mimeTypeLength = reader.read(4).joined(UInt32.self)
        mimeType = String.init(decoding: reader.read(Int(mimeTypeLength)), as: UTF8.self)
        let descriptionLength = reader.read(4).joined(UInt32.self)
        descriptionString = String.init(decoding: reader.read(Int(descriptionLength)), as: UTF8.self)
        width = reader.read(4).joined(UInt32.self)
        height = reader.read(4).joined(UInt32.self)
        colorDepth = reader.read(4).joined(UInt32.self)
        numberOfColors = reader.read(4).joined(UInt32.self)
        let pictureDataLength = reader.read(4).joined(UInt32.self)
        pictureData = reader.read(Int(pictureDataLength))
        try reader.check()
    }
    
    public var length: Int {
        return 32 + mimeType.utf8.count + descriptionString.utf8.count + pictureData.count
    }
    
    public var data: Data {
//        let capacity = length - pictureData.count
        var result = Data.init(capacity: length)
        result.append(contentsOf: pictureType.rawValue.splited)
        result.append(contentsOf: UInt32(mimeType.utf8.count).splited)
        result.append(contentsOf: Data(mimeType.utf8))
        result.append(contentsOf: UInt32(descriptionString.utf8.count).splited)
        result.append(contentsOf: Data(descriptionString.utf8))
        result.append(contentsOf: width.splited)
        result.append(contentsOf: height.splited)
        result.append(contentsOf: colorDepth.splited)
        result.append(contentsOf: numberOfColors.splited)
        result.append(contentsOf: UInt32(pictureData.count).splited)
//        precondition(capacity == result.count)
        result += pictureData
        return result
    }
    
    public var description: String {
        return """
        type: \(pictureType.rawValue) \(pictureType)
        MIME type: \(mimeType)
        description: \(descriptionString)
        width: \(width)
        height: \(height)
        colorDepth: \(colorDepth)
        colors: \(numberOfColors)
        data length: \(pictureData.count)
        """
    }
    
}
