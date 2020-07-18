import Foundation
@_exported import KwiftUtility

extension ByteReader {
    
  mutating func checkIfAllBytesUsed() throws {
    if !isAtEnd {
      assertionFailure("Block has unused data")
      throw MetaflacError.extraDataInMetadataBlock(data: .init(try! readAll()!))
    }
  }
    
}
