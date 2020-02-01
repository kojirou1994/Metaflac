import Foundation

#if os(Linux)
@inline(__always)
public func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
    try body()
}
#endif

public protocol ByteReaderProtocol {
    func read(_ count: Int) -> Data
    
    func skip(_ count: Int)
    
    var currentIndex: Int {get}
}

extension FileHandle: ByteReaderProtocol {
    
    public func read(_ count: Int) -> Data {
        readData(ofLength: count)
    }
    
    public var currentIndex: Int {
        Int(offsetInFile)
    }
    
    public func skip(_ count: Int) {
        seek(toFileOffset: offsetInFile + UInt64(count))
    }
    
}

extension DataReader: ByteReaderProtocol {
    
}

extension DataReader {
    
    func check() throws {
        #if DEBUG
        if isAtEnd {
            print("Block read finished")
        } else {
            print("Block has unused data")
            throw MetaflacError.extraDataInMetadataBlock(data: readToEnd())
        }
        #endif
    }
    
}
