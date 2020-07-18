import Foundation

/// This block is for use by third-party applications. The only mandatory field is a 32-bit identifier. This ID is granted upon request to an application by the FLAC maintainers. The remainder is of the block is defined by the registered application. Visit the registration page if you would like to register an ID for your application with FLAC.
public struct Application: MetadataBlockData, Equatable {
  
  /// Registered application ID. (Visit the registration page to register an ID with FLAC.)
  public let id: [UInt8]
  
  public let applicationData: [UInt8]
  
  public init<D>(_ data: D) throws where D : DataProtocol {
    var reader = ByteReader(data)
    id = .init(try reader.read(4))
    self.applicationData = try reader.readAll().map(Array.init) ?? []
    try reader.checkIfAllBytesUsed()
  }
  
  internal var length: Int {
    4 + applicationData.count
  }
  
  internal var data: Data {
    var result = Data(capacity: length)
    result += id
    result += applicationData
    return result
  }
  
  /// Create Application block
  /// - Parameters:
  ///   - id: id's count must be 4
  ///   - applicationData: binary data
  public init(id: [UInt8], applicationData: [UInt8]) {
    precondition(id.count == 4)
    self.id = id
    self.applicationData = applicationData
  }
  
  public var description: String {
    """
    id: \(id)
    idString: \(String(decoding: id, as: UTF8.self))
    application data: \(applicationData.count) bytes
    """
  }
  
}
