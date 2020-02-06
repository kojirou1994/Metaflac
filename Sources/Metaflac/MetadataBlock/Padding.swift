import Foundation

/// This block allows for an arbitrary amount of padding. The contents of a PADDING block have no meaning. This block is useful when it is known that metadata will be edited after encoding; the user can instruct the encoder to reserve a PADDING block of sufficient size so that when metadata is added, it will simply overwrite the padding (which is relatively quick) instead of having to insert it into the right place in the existing file (which would normally require rewriting the entire file).
public struct Padding: MetadataBlockData, Equatable {
    
    public var count: Int
    
    public init(_ data: Data) {
        count = data.count
        if !data.allSatisfy({$0 == 0}) {
            print("[warning] padding block has non-zero data")
        }
    }
    
    internal var length: Int {
        count
    }
    
    internal var data: Repeated<UInt8> {
        repeatElement(0, count: count)
    }
    
    public var description: String {
        return """
        zero padding count: \(count) bytes
        """
    }
    
    public init(count: Int) {
        self.count = count
    }
    
}
