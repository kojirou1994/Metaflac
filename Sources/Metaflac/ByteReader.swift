import Foundation

typealias DataReader = ByteReader<Data>

class ByteReader<C> where C: Collection, C.Element == UInt8, C.Index == Int {
    
    private(set) var currentIndex: Int
    
    func seek(to offset: Int) {
        precondition((data.startIndex + offset)<=data.endIndex)
        currentIndex = offset
    }
    
    let data: C
    
    init(data: C) {
        self.data = data
        currentIndex = data.startIndex
    }
    
    func read(_ count: Int) -> C.SubSequence {
        precondition((currentIndex + count)<=data.endIndex)
        defer {
            currentIndex += count
        }
        return data[currentIndex..<(currentIndex + count)]
    }
    
    func readByte() -> UInt8 {
        precondition((currentIndex + 1)<=data.endIndex)
        defer {
            currentIndex += 1
        }
        return data[currentIndex]
    }
    
    var currentByte: UInt8 {
        data[currentIndex]
    }
    
    func skip(_ count: Int) {
        precondition((currentIndex + count)<=data.endIndex)
        currentIndex += count
    }
    
    func readToEnd() -> C.SubSequence {
        if isAtEnd {
            return data[data.endIndex..<data.endIndex]
        } else {
            defer { currentIndex = data.endIndex }
            return data[currentIndex..<data.endIndex]
        }
    }
    
    var isAtEnd: Bool {
        currentIndex == (data.endIndex)
    }
    
    var restBytesCount: Int {
        data.endIndex - currentIndex
    }
    
}
