import Foundation
@_exported import KwiftUtility

extension ByteReader {

  @inlinable
  mutating func checkIfAllBytesUsed() throws {
    if !isAtEnd {
      assertionFailure("Block has unused data")
      throw MetaflacError.extraDataInMetadataBlock(data: .init(try! readAll()!))
    }
  }

  @inlinable
  mutating func skipReservedBytes(_ count: Int) throws {
    #if DEBUG
    let reserved = try read(count)
    precondition(reserved.allSatisfy { $0 == 0 })
    #else
    try skip(count)
    #endif
  }

}
