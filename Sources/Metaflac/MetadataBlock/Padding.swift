import Foundation

/// This block allows for an arbitrary amount of padding. The contents of a PADDING block have no meaning. This block is useful when it is known that metadata will be edited after encoding; the user can instruct the encoder to reserve a PADDING block of sufficient size so that when metadata is added, it will simply overwrite the padding (which is relatively quick) instead of having to insert it into the right place in the existing file (which would normally require rewriting the entire file).
public struct Padding: MetadataBlockData, Equatable {
    
    public var count: Int

    public init<D>(_ data: D) throws where D : DataProtocol {
        count = data.count
      assert(data.allSatisfy{$0 == 0}, "Padding block has non-zero data")
    }
    
    internal var length: Int {
        count
    }
    
    internal var data: Repeated<UInt8> {
        repeatElement(0, count: count)
    }
    
    public var description: String {
        """
        zero padding count: \(count) bytes
        """
    }
    
  public init(count: Int) {
    self.count = max(count, 0)
  }
    
}
