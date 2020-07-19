import Foundation

extension FlacMetadataBlock {
  /// This block has information about the whole stream, like sample rate, number of channels, total number of samples, etc. It must be present as the first metadata block in the stream. Other metadata blocks may follow, and ones that the decoder doesn't understand, it will skip.
  public struct StreamInfo: FlacMetadataBlockProtocol {

    // 16bits
    public let minimumBlockSize: UInt16
    // 16bits
    public let maximumBlockSize: UInt16
    // 24bits
    public let minimumFrameSize: UInt32
    // 24bits
    public let maximumFrameSize: UInt32

    // 20bits
    public let sampleRate: UInt64
    // 3bits
    public let channelCount: UInt64
    // 5bits
    public let bitsPerSample: UInt64
    // 36bits
    public let sampleCount: UInt64
    // 128bits
    public let md5Signature: [UInt8]

    public init(minimumBlockSize: UInt16, maximumBlockSize: UInt16, minimumFrameSize: UInt32, maximumFrameSize: UInt32, sampleRate: UInt64, channelCount: UInt64, bitsPerSample: UInt64, sampleCount: UInt64, md5Signature: [UInt8]) {
      precondition(md5Signature.count == 16)
      self.minimumBlockSize = minimumBlockSize
      self.maximumBlockSize = maximumBlockSize
      self.minimumFrameSize = minimumFrameSize
      self.maximumFrameSize = maximumFrameSize
      self.sampleRate = sampleRate
      self.channelCount = channelCount
      self.bitsPerSample = bitsPerSample
      self.sampleCount = sampleCount
      self.md5Signature = md5Signature
    }

    public init<D>(_ data: D) throws where D : DataProtocol {
      var reader = ByteReader(data)
      minimumBlockSize = try reader.readInteger() as UInt16
      maximumBlockSize = try reader.readInteger() as UInt16
      minimumFrameSize = try reader.read(3).joined(UInt32.self)
      maximumFrameSize = try reader.read(3).joined(UInt32.self)
      //sampleRate numberOfChannels bitsPerSample totalSamples
      var fourElements = BitReader(try reader.readInteger() as UInt64)
      sampleRate = fourElements.read(20).unsafelyUnwrapped
      channelCount = fourElements.read(3).unsafelyUnwrapped + 1
      bitsPerSample = fourElements.read(5).unsafelyUnwrapped + 1
      sampleCount = fourElements.readAll().unsafelyUnwrapped
      md5Signature = .init(try reader.read(16))
      try reader.checkIfAllBytesUsed()
    }

    public var blockLength: Int {
      34
    }

    public var encodedBytes: Data {
      var result = Data(capacity: blockLength)
      result += minimumBlockSize.bytes
      result += maximumBlockSize.bytes
      result += minimumFrameSize.bytes[1...]
      result += maximumFrameSize.bytes[1...]
      var fourElements: UInt64 = 0
      fourElements |= sampleRate << 44
      fourElements |= (channelCount - 1) << 41
      fourElements |= (bitsPerSample - 1) << 36
      fourElements |= sampleCount
      result += fourElements.bytes
      result += md5Signature

      precondition(result.count == blockLength)
      return result
    }

    public var description: String {
      """
      minimumBlockSize: \(minimumBlockSize) samples
      maximumBlockSize: \(maximumBlockSize) samples
      minimumFrameSize: \(minimumFrameSize) bytes
      maximumFrameSize: \(maximumFrameSize) bytes
      sample_rate: \(sampleRate) Hz
      channels: \(channelCount)
      bits-per-sample: \(bitsPerSample)
      total samples: \(sampleCount)
      MD5 signature: \(md5Signature.map {$0.description}.joined(separator: " "))
      """
    }

  }
}
