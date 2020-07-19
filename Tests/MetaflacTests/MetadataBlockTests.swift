import XCTest
@testable import Metaflac

final class MetadataBlockTests: XCTestCase {

  func testBlockHeader() {
    func check(lastMetadataBlockFlag: Bool) {
      for type in FlacMetadataType.allCases {
        //      print("\(type) = \(type.rawValue)")
        let header = FlacMetadataBlockHeader(lastMetadataBlockFlag: lastMetadataBlockFlag, blockType: type, length: 1586784)
        let encoded = header.encode()
        let decoded = try! FlacMetadataBlockHeader(encoded)
        XCTAssertEqual(header, decoded)
      }
    }
    check(lastMetadataBlockFlag: true)
    check(lastMetadataBlockFlag: false)
  }

  func assertDecodedEqual<T: FlacMetadataBlockProtocol>(_ block: T) {
    let encoded = block.encodedBytes
    let decoded = try! T(encoded)
    XCTAssertEqual(block, decoded)
    print(decoded)
    measure {
      _ = try! T(encoded)
    }
  }

  func testStreamInfo() {
    assertDecodedEqual(
      FlacMetadataBlock.StreamInfo(
        minimumBlockSize: 1024, maximumBlockSize: 1024, minimumFrameSize: 1024, maximumFrameSize: 1024,
        sampleRate: 44100, numberOfChannels: 2, bitsPerSampe: 16, totalSamples: 1_000_000,
        md5Signature: .init(repeating: 0, count: 16)
      )
    )
  }

  func testPadding() {
    let count = 1024
    assertDecodedEqual(FlacMetadataBlock.Padding(count: count))
  }

  func testApplication() {
    assertDecodedEqual(FlacMetadataBlock.Application(id: .init("FLAC".utf8), applicationData: .init(repeating: 1, count: 100)))
  }

  func testSeekTable() {
    assertDecodedEqual(FlacMetadataBlock.SeekTable(seekPoints: .init(repeating: .init(sampleNumber: 0x1234, offset: 0x5678, frameSample: 0x9abc), count: 20)))
  }

  func testVorbisComment() {
    assertDecodedEqual(
      FlacMetadataBlock.VorbisComment(
        vendorString: "Metaflac Swift",
        userComments: [
          "haha=1", "bb=2"
      ])
    )
  }

  func testPicture() {
    assertDecodedEqual(try! FlacMetadataBlock.Picture(pictureType: .coverFront, mimeType: "image/png", description: "", width: 1_000, height: 1_000,
                                    colorDepth: 8, numberOfColors: 0, pictureData: .init(repeating: 0, count: 1_000)))
  }
}
