import Foundation

/// This block is for use by third-party applications. The only mandatory field is a 32-bit identifier. This ID is granted upon request to an application by the FLAC maintainers. The remainder is of the block is defined by the registered application. Visit the registration page if you would like to register an ID for your application with FLAC.
public struct Application: MetadataBlockData, Equatable {
    
    /// Registered application ID. (Visit the registration page to register an ID with FLAC.)
    public let id: String
    
    public let applicationData: Data
    
    public init(_ data: Data) throws {
        let reader = DataHandle.init(data: data)
        id = .init(decoding: reader.read(4), as: UTF8.self)
        self.applicationData = Data(reader.readToEnd())
        try reader.check()
    }
    
    public var length: Int {
        return 32/8 + applicationData.count
    }
    
    public var data: Data {
        var result = Data(id.utf8)
        result += applicationData
        return result
    }
    
    public init(id: String, applicationData: Data) {
        precondition(id.utf8.count == 4)
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
