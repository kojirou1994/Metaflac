import Foundation

/// This block has information about the whole stream, like sample rate, number of channels, total number of samples, etc. It must be present as the first metadata block in the stream. Other metadata blocks may follow, and ones that the decoder doesn't understand, it will skip.
public struct StreamInfo: MetadataBlockData, Equatable {
    
    public let minimumBlockSize: UInt16
    public let maximumBlockSize: UInt16
    public let minimumFrameSize: UInt32
    public let maximumFrameSize: UInt32
    
    /// 20bits
    public let sampleRate: UInt64
    /// 3bits
    public let numberOfChannels: UInt64
    /// 5bits
    public let bitsPerSampe: UInt64
    /// 36bits
    public let totalSamples: UInt64
    /// 128bits
    public let md5Signature: Data
    
    public init(minimumBlockSize: UInt16, maximumBlockSize: UInt16,
                minimumFrameSize: UInt32, maximumFrameSize: UInt32,
                sampleRate: UInt64, numberOfChannels: UInt64,
                bitsPerSampe: UInt64, totalSamples: UInt64,
                md5Signature: Data) {
        precondition(md5Signature.count == 128/8)
        self.minimumBlockSize = minimumBlockSize
        self.maximumBlockSize = maximumBlockSize
        self.minimumFrameSize = minimumFrameSize
        self.maximumFrameSize = maximumFrameSize
        self.sampleRate = sampleRate
        self.numberOfChannels = numberOfChannels
        self.bitsPerSampe = bitsPerSampe
        self.totalSamples = totalSamples
        self.md5Signature = md5Signature
    }
    
    public init(_ data: Data) throws {
        let reader = ByteReader.init(data: data)
        minimumBlockSize = reader.read(2).joined(UInt16.self)
        maximumBlockSize = reader.read(2).joined(UInt16.self)
        minimumFrameSize = reader.read(3).joined(UInt32.self)
        maximumFrameSize = reader.read(3).joined(UInt32.self)
        //sampleRate numberOfChannels bitsPerSample totalSamples
        let fourElements = reader.read(8).joined(UInt64.self)
        sampleRate = fourElements >> 44
        numberOfChannels = ((fourElements << 20) >> 61) + 1
        bitsPerSampe = ((fourElements << 23) >> 59) + 1
        totalSamples = (fourElements << 28) >> 28
        md5Signature = reader.read(128/8)
        try reader.check()
    }
    
    internal var length: Int {
        34
    }
    
    internal var data: Data {
        var result = Data(capacity: length)
        result.append(contentsOf: minimumBlockSize.bytes)
        result.append(contentsOf: maximumBlockSize.bytes)
        result.append(contentsOf: minimumFrameSize.bytes[1...])
        result.append(contentsOf: maximumFrameSize.bytes[1...])
        var fourElements = UInt64.init()
        fourElements |= sampleRate << 44
        fourElements |= (numberOfChannels - 1) << 41
        fourElements |= (bitsPerSampe - 1) << 36
        fourElements |= totalSamples
        result.append(contentsOf: fourElements.bytes)
        result.append(contentsOf: md5Signature)
        return result
    }
    
    public var description: String {
        return """
        minimumBlockSize: \(minimumBlockSize) samples
        maximumBlockSize: \(maximumBlockSize) samples
        minimumFrameSize: \(minimumFrameSize) bytes
        maximumFrameSize: \(maximumFrameSize) bytes
        sample_rate: \(sampleRate) Hz
        channels: \(numberOfChannels)
        bits-per-sample: \(bitsPerSampe)
        total samples: \(totalSamples)
        MD5 signature: \(md5Signature.hexString(prefix: ""))
        """
    }
    
}
