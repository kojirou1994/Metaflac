import Foundation

extension FlacMetadataBlock {
  /// This is an optional block for storing seek points. It is possible to seek to any given sample in a FLAC stream without a seek table, but the delay can be unpredictable since the bitrate may vary widely within a stream. By adding seek points to a stream, this delay can be significantly reduced. Each seek point takes 18 bytes, so 1% resolution within a stream adds less than 2k. There can be only one SEEKTABLE in a stream, but the table can have any number of seek points. There is also a special 'placeholder' seekpoint which will be ignored by decoders but which can be used to reserve space for future seek point insertion.
  public struct SeekTable: FlacMetadataBlockProtocol {
    
    /// One or more seek points.
    public var seekPoints: [SeekPoint]
    
    public struct SeekPoint: CustomStringConvertible, Equatable {
      
      /// Sample number of first sample in the target frame, or 0xFFFFFFFFFFFFFFFF for a placeholder point.
      public var sampleNumber: UInt64
      
      /// Offset (in bytes) from the first byte of the first frame header to the first byte of the target frame's header.
      public var offset: UInt64
      
      /// Number of samples in the target frame.
      public var frameSample: UInt16
      
      public init(sampleNumber: UInt64, offset: UInt64, frameSample: UInt16) {
        self.sampleNumber = sampleNumber
        self.offset = offset
        self.frameSample = frameSample
      }

      public var description: String {
        "sample_number=\(sampleNumber), stream_offset=\(offset), frame_samples=\(frameSample)"
      }
    }
    
    public init<D>(_ data: D) throws where D : DataProtocol {
      let count = data.count/18
      var reader = ByteReader(data)
      seekPoints = try (1...count).map { _ in
        try .init(sampleNumber: reader.readInteger(), offset: reader.readInteger(),
                  frameSample: reader.readInteger())
      }
      
      try reader.checkIfAllBytesUsed()
    }
    
    public init(seekPoints: [SeekPoint]) {
      self.seekPoints = seekPoints
    }
    
    public var blockLength: Int {
      seekPoints.count * 18
    }
    
    public var encodedBytes: Data {
      var result = Data(capacity: blockLength)
      for seekPoint in seekPoints {
        result += seekPoint.sampleNumber.bytes
        result += seekPoint.offset.bytes
        result += seekPoint.frameSample.bytes
      }
      precondition(result.count == blockLength)
      return result
    }

    public var description: String {
      """
      seek points: \(seekPoints.count)
      \(seekPoints.enumerated().map {"point \($0.offset): \($0.element)"}.joined(separator: "\n"))
      """
    }
    
  }
  
}
