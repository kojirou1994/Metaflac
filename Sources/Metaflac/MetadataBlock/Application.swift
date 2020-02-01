import Foundation

/// This block is for use by third-party applications. The only mandatory field is a 32-bit identifier. This ID is granted upon request to an application by the FLAC maintainers. The remainder is of the block is defined by the registered application. Visit the registration page if you would like to register an ID for your application with FLAC.
public struct Application: MetadataBlockData, Equatable {
    
    /// Registered application ID. (Visit the registration page to register an ID with FLAC.)
    public let id: Data
    
    public let applicationData: Data
    
    public init(_ data: Data) throws {
        let reader = ByteReader.init(data: data)
        id = Data(reader.read(4))
        self.applicationData = Data(reader.readToEnd())
        try reader.check()
    }
    
    internal var length: Int {
        4 + applicationData.count
    }
    
    internal var data: Data {
        var result = Data(capacity: length)
        result.append(id)
        result += applicationData
        return result
    }
    
    public init(id: Data, applicationData: Data) {
        precondition(id.count == 4)
        self.id = id
        self.applicationData = applicationData
    }
    
    public var description: String {
        return """
        id: \(id)
        application data: \(applicationData)
        """
    }
    
}
