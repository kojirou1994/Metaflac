import Foundation
import protocol KwiftUtility.LosslessDataConvertible

public protocol MetadataBlockData: LosslessDataConvertible, CustomStringConvertible {
    
    /// length in bytes
    var length: Int { get }
    
}

extension MetadataBlockData {
    
    /// length in bytes, including the header
    var totalLength: Int {
        return length + 4
    }
    
}
