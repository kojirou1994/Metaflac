extension FixedWidthInteger {
    @inlinable
    var bytes: [UInt8] {
        let count = Self.bitWidth / 8
        return [UInt8].init(unsafeUninitializedCapacity: count) { ptr, initialized in
            initialized = count
            for i in 0...count - 1 {
                ptr[i] = UInt8(truncatingIfNeeded: self >> ((count - i - 1) * 8))
            }
        }
    }
}

extension Sequence where Element == UInt8 {
    func joined<T>(_ type: T.Type) -> T where T: FixedWidthInteger {
        let byteCount = T.bitWidth / 8
        var result = T()
        for element in enumerated() {
            if element.offset == byteCount {
                break
            }
            result = (result << 8) | T(truncatingIfNeeded: element.element)
        }
        return result
    }

    func joined<T>() -> T where T: FixedWidthInteger {
        joined(T.self)
    }
}
