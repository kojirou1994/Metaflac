import Foundation

extension FlacMetadataBlock {
  /// This block is for storing a list of human-readable name/value pairs. Values are encoded using UTF-8. It is an implementation of the Vorbis comment specification (without the framing bit). This is the only officially supported tagging mechanism in FLAC. There may be only one VORBIS_COMMENT block in a stream. In some external documentation, Vorbis comments are called FLAC tags to lessen confusion.
  public struct VorbisComment: FlacMetadataBlockProtocol, Equatable {

    public let vendorString: String

    public let userComments: [String]

    public init(vendorString: String, userComments: [String]) {
      self.vendorString = vendorString
      self.userComments = userComments
    }

    public init<D>(_ data: D) throws where D : DataProtocol {
      var reader = ByteReader(data)
      let vendorLength = try reader.readInteger(endian: .little) as UInt32
      vendorString = try reader.readString(numericCast(vendorLength))
      let userCommentCount = try reader.readInteger(endian: .little) as UInt32
      userComments = try (1...userCommentCount).map { _ in
        let length = try reader.readInteger(endian: .little) as UInt32
        return try reader.readString(numericCast(length))
      }

      try reader.checkIfAllBytesUsed()
    }

    public var blockLength: Int {
      4 // vendor length
        + vendorString.utf8.count //vendor
        + 4 // user comment count
        + 4 * userComments.count // each user comment length
        + userComments.reduce(0, {$0 + $1.utf8.count}) // each user comment
    }

    public var encodedBytes: Data {
      let capacity = blockLength
      var result = Data(capacity: capacity)
      result += UInt32(vendorString.utf8.count).toBytes(endian: .little)
      result += vendorString.utf8
      result += UInt32(userComments.count).toBytes(endian: .little)
      for comment in userComments {
        result += UInt32(comment.utf8.count).toBytes(endian: .little)
        result += comment.utf8
      }
      precondition(capacity == result.count, "Vorbis Comment block's length is not same as desired!")
      return result
    }

    public var description: String {
      """
      vendor string: \(vendorString)
      comments: \(userComments.count)
      \(userComments.enumerated().map {"comment[\($0.offset)]: \($0.element)"}.joined(separator: "\n"))
      """
    }

  }
}
