import Foundation

protocol LosslessDataConvertible {

    init(_ data: Data) throws

    var data: Data { get }

}

protocol MetadataBlockData: /*LosslessDataConvertible, */CustomStringConvertible {

    init(_ data: Data) throws

    associatedtype Encoded: DataProtocol

    var data: Encoded { get }
    
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
