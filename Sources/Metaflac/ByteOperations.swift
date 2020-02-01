extension FixedWidthInteger {
    
    public var binaryString: String {
        var result: [String] = []
        let count = Self.bitWidth / 8
        for i in 1...count {
            let byte = UInt8(truncatingIfNeeded: self >> ((count - i) * 8))
            let byteString = String(byte, radix: 2)
            let padding = String(repeating: "0", count: 8 - byteString.count)
            result.append(padding + byteString)
        }
        return "0b" + result.joined(separator: "_")
    }
    
    public func hexString(uppercase: Bool = false, prefix: String = "0x") -> String {
        var result: [String] = []
        let count = Self.bitWidth / 8
        for i in 1...count {
            let byte = UInt8(truncatingIfNeeded: self >> ((count - i) * 8))
            let byteString = String(byte, radix: 16, uppercase: uppercase)
            let padding = String(repeating: "0", count: 2 - byteString.count)
            result.append(padding + byteString)
        }
        return prefix + result.joined(separator: "")
    }
    
    @inlinable
    public var bytes: [UInt8] {
//        withUnsafeBytes(of: self) { (bytes) -> [UInt8] in
//            return bytes.reversed()
            let count = Self.bitWidth / 8
            return [UInt8].init(unsafeUninitializedCapacity: count) { (ptr, initialized) in
                    initialized = count
                for i in 0...count-1 {
                    ptr[i] = UInt8.init(truncatingIfNeeded: self >> ( (count - i - 1) * 8))
//                        bytes[count-1-i]
                }
            }
//        }
    }
    
}

extension Sequence where Element == UInt8 {
    
    public func joined<T>(_ type: T.Type) -> T where T : FixedWidthInteger {
        let byteCount = T.bitWidth / 8
        var result = T.init()
        for element in enumerated() {
            if element.offset == byteCount {
                break
            }
            result = (result << 8) | T(truncatingIfNeeded: element.element)
        }
        return result
    }
    
    public func joined<T>() -> T where T : FixedWidthInteger {
        joined(T.self)
    }
    
    public func hexString(uppercase: Bool = false, prefix: String = "0x") -> String {
        prefix + map {$0.hexString(uppercase: uppercase, prefix: "")}.joined()
    }
    
}
