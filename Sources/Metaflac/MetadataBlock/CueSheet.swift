import Foundation

/// This block is for storing various information that can be used in a cue sheet. It supports track and index points, compatible with Red Book CD digital audio discs, as well as other CD-DA metadata such as media catalog number and track ISRCs. The CUESHEET block is especially useful for backing up CD-DA discs, but it can be used as a general purpose cueing mechanism for playback.
public struct CueSheet: MetadataBlockData, Equatable {
    
    /// Media catalog number, in ASCII printable characters 0x20-0x7e. In general, the media catalog number may be 0 to 128 bytes long; any unused characters should be right-padded with NUL characters. For CD-DA, this is a thirteen digit number, followed by 115 NUL bytes.
    public let mediaCatalogNumber: [UInt8]
    
    /// The number of lead-in samples. This field has meaning only for CD-DA cuesheets; for other uses it should be 0. For CD-DA, the lead-in is the TRACK 00 area where the table of contents is stored; more precisely, it is the number of samples from the first sample of the media to the first sample of the first index point of the first track. According to the Red Book, the lead-in must be silence and CD grabbing software does not usually store it; additionally, the lead-in must be at least two seconds but may be longer. For these reasons the lead-in length is stored here so that the absolute position of the first track can be computed. Note that the lead-in stored here is the number of samples up to the first index point of the first track, not necessarily to INDEX 01 of the first track; even the first track may have INDEX 00 data.
    public let numberOfLeadinSamples: UInt64
    
    /// 1 if the CUESHEET corresponds to a Compact Disc, else 0.
    public let compactDisc: Bool
    
    /// The number of tracks. Must be at least 1 (because of the requisite lead-out track). For CD-DA, this number must be no more than 100 (99 regular tracks and one lead-out track).
    public let trackCount: UInt8
    
    /// One or more tracks. A CUESHEET block is required to have a lead-out track; it is always the last track in the CUESHEET. For CD-DA, the lead-out track number must be 170 as specified by the Red Book, otherwise is must be 255.
    public let tracks: [Track]
    
    public init(mediaCatalogNumber: String, numberOfLeadinSamples: UInt64,
                compactDisc: Bool, tracks: [Track]) {
        precondition(mediaCatalogNumber.count <= 128)
        precondition(mediaCatalogNumber.allSatisfy {$0.isASCII && (0x20...0x7e).contains($0.utf8.first!) })
        var tempD = Data(capacity: 128)
        tempD.append(contentsOf: mediaCatalogNumber.utf8)
        let nullByte = 128 - tempD.count
        if nullByte > 0 {
            for _ in 1...nullByte {
                tempD.append(0)
            }
        }
      self.mediaCatalogNumber = .init()
        self.numberOfLeadinSamples = numberOfLeadinSamples
        self.compactDisc = compactDisc
      self.trackCount = numericCast(tracks.count)
        self.tracks = tracks
    }
    
  public init<D>(_ data: D) throws where D : DataProtocol {
    var reader = ByteReader(data)
    mediaCatalogNumber = .init(try reader.read(128))
    numberOfLeadinSamples = try reader.readInteger()
    let flag = try reader.readByte()
    compactDisc = (flag >> 7) == 1
    /// Reserved. All bits must be set to zero.
    try reader.skip(258)
    trackCount = try reader.readByte()
    tracks = try (1...trackCount).map { _ in
      let trackOffsetInSamples = try reader.readInteger() as UInt64
      let trackNumber = try reader.readByte()
      let trackISRC = Array(try reader.read(12))
      let flag = try reader.readByte()
      let isAudio = (flag >> 7) == 0
      let preEmphasis = (flag & 0b01000000) != 0
      // Reserved. All bits must be set to zero.
      try reader.skip(13)
      let numberOfTrackIndexPoints = try reader.readByte()

      let indexes = try (1...numberOfTrackIndexPoints).map { _ -> Track.Index in
        let offsetInSample = try reader.readInteger() as UInt64
        let indexPointNumber = try reader.readByte()
        // Reserved. All bits must be set to zero.
        try reader.skip(3)
        return .init(offsetInSample: offsetInSample, indexPointNumber: indexPointNumber)
      }

      return .init(trackOffsetInSamples: trackOffsetInSamples, trackNumber: trackNumber, trackISRC: trackISRC, isAudio: isAudio, preEmphasis: preEmphasis, numberOfTrackIndexPoints: numberOfTrackIndexPoints, indexes: indexes)
    }
  }
    
    public var length: Int {
        396 + tracks.reduce(0, {$0 + 36 + $1.indexes.count * 12})
    }
    
    public var data: Data {
      var result = Data(capacity: length)
      result += mediaCatalogNumber
      result += repeatElement(0, count: 128-mediaCatalogNumber.count)
      result += numberOfLeadinSamples.bytes
      let flag: UInt8 = compactDisc ? 0b10000000 : 0
      result.append(flag)
      result += repeatElement(0, count: 258)

        result.append(trackCount)
        for track in tracks {
            result.append(contentsOf: track.trackOffsetInSamples.bytes)
            result.append(track.trackNumber)
            result.append(contentsOf: track.trackISRC)
            var flag: UInt8 = track.isAudio ? 0 : 1
            flag = flag << 7
            flag = flag | (track.preEmphasis ? 0b01000000 : 0b00000000)
            result.append(flag)
            for _ in 1...13 {
                result.append(0)
            }
            result.append(track.numberOfTrackIndexPoints)
            for index in track.indexes {
                result.append(contentsOf: index.offsetInSample.bytes)
                result.append(index.indexPointNumber)
                for _ in 1...3 {
                    result.append(0)
                }
            }
        }
        return result
    }
    
    public var description: String {
        return """
        """
    }
    
    public struct Track: Equatable {
        
        /// Track offset in samples, relative to the beginning of the FLAC audio stream. It is the offset to the first index point of the track. (Note how this differs from CD-DA, where the track's offset in the TOC is that of the track's INDEX 01 even if there is an INDEX 00.) For CD-DA, the offset must be evenly divisible by 588 samples (588 samples = 44100 samples/sec * 1/75th of a sec).
        public let trackOffsetInSamples: UInt64
        
        /// Track number. A track number of 0 is not allowed to avoid conflicting with the CD-DA spec, which reserves this for the lead-in. For CD-DA the number must be 1-99, or 170 for the lead-out; for non-CD-DA, the track number must for 255 for the lead-out. It is not required but encouraged to start with track 1 and increase sequentially. Track numbers must be unique within a CUESHEET.
        public let trackNumber: UInt8
        
        /// Track ISRC. This is a 12-digit alphanumeric code; see here and here. A value of 12 ASCII NUL characters may be used to denote absence of an ISRC.
        public let trackISRC: [UInt8]
        
        /// The track type: 0 for audio, 1 for non-audio. This corresponds to the CD-DA Q-channel control bit 3.
        public let isAudio: Bool
        
        ///     The pre-emphasis flag: 0 for no pre-emphasis, 1 for pre-emphasis. This corresponds to the CD-DA Q-channel control bit 5; see here.
        public let preEmphasis: Bool
        
        /// The number of track index points. There must be at least one index in every track in a CUESHEET except for the lead-out track, which must have zero. For CD-DA, this number may be no more than 100.
        public let numberOfTrackIndexPoints: UInt8
        
        /// For all tracks except the lead-out track, one or more track index points.
        public let indexes: [Index]
        
        public struct Index: Equatable {
            
            /// Offset in samples, relative to the track offset, of the index point. For CD-DA, the offset must be evenly divisible by 588 samples (588 samples = 44100 samples/sec * 1/75th of a sec). Note that the offset is from the beginning of the track, not the beginning of the audio data.
            public let offsetInSample: UInt64
            
            /// The index point number. For CD-DA, an index number of 0 corresponds to the track pre-gap. The first index in a track must have a number of 0 or 1, and subsequently, index numbers must increase by 1. Index numbers must be unique within a track.
            public let indexPointNumber: UInt8
            
            public init(offsetInSample: UInt64, indexPointNumber: UInt8) {
                self.offsetInSample = offsetInSample
                self.indexPointNumber = indexPointNumber
            }
            
        }
        
        public init(trackOffsetInSamples: UInt64, trackNumber: UInt8, trackISRC: [UInt8],
                    isAudio: Bool, preEmphasis: Bool, numberOfTrackIndexPoints: UInt8, indexes: [Index]) {
            self.trackOffsetInSamples = trackOffsetInSamples
            self.trackNumber = trackNumber
            precondition(trackISRC.count == 12)
            self.trackISRC = trackISRC
            self.isAudio = isAudio
            self.preEmphasis = preEmphasis
            self.numberOfTrackIndexPoints = numberOfTrackIndexPoints
            self.indexes = indexes
        }
    }
    
}

