import Foundation
import protocol KwiftUtility.LosslessDataConvertible

protocol MetadataBlockData: LosslessDataConvertible, CustomStringConvertible {
    
    /// length in bytes
    var length: Int { get }
    
}

extension MetadataBlockData {
    
    /// length in bytes, including the header
    var totalLength: Int {
        return length + MetadataBlockHeader.headerLength
    }
    
    public func checkLength() throws {
        if length > MetadataBlockHeader.maxBlockLength {
            throw MetaflacError.exceedMaxBlockLength
        }
    }
    
}
