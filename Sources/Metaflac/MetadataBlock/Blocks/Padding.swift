import Foundation

extension FlacMetadataBlock {
  /// This block allows for an arbitrary amount of padding. The contents of a PADDING block have no meaning. This block is useful when it is known that metadata will be edited after encoding; the user can instruct the encoder to reserve a PADDING block of sufficient size so that when metadata is added, it will simply overwrite the padding (which is relatively quick) instead of having to insert it into the right place in the existing file (which would normally require rewriting the entire file).
  public struct Padding: FlacMetadataBlockProtocol {

    public var count: Int

    public init<D>(_ data: D) throws where D : DataProtocol {
      count = data.count
      assert(data.allSatisfy{$0 == 0}, "Padding block has non-zero data")
    }

    public init(count: Int) {
      self.count = max(count, 0)
    }

    public var blockLength: Int {
      count
    }

    #warning("use big buffer")
//    public func write(to fileHandle: FileHandle) throws {
//
    // if count == 0 { return }

//    }

    public var encodedBytes: Repeated<UInt8> {
      repeatElement(0, count: count)
    }

    public var description: String {
      """
      zero padding count: \(count)
      """
    }

  }
}
