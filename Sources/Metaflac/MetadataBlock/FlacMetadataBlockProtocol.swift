import Foundation
import KwiftExtension

public protocol FlacMetadataBlockProtocol: CustomStringConvertible, Equatable {

  init<D: DataProtocol>(_ data: D) throws

  associatedtype Encoded: DataProtocol

  var encodedBytes: Encoded { get }

  /// length in bytes
  var blockLength: Int { get }

  /// write encodedBytes by default
  func write(to fileHandle: FileHandle) throws

}

extension FlacMetadataBlockProtocol {

  @inlinable
  public func write(to fileHandle: FileHandle) throws {
    try fileHandle.kwiftWrite(contentsOf: encodedBytes)
  }
  
  /// length in bytes, including the header
  @inlinable
  public var totalLength: Int {
    blockLength + FlacMetadataBlockConstants.headerLength
  }

  @inlinable
  public func checkLength() throws {
    try preconditionOrThrow(blockLength <= FlacMetadataBlockConstants.maxBlockLength, MetaflacError.exceedMaxBlockLength)
  }
  
}
