import XCTest
@testable import Metaflac

final class MetadataBlockTests: XCTestCase {

  func assertDecodedEqual<T: MetadataBlockData & Equatable>(_ block: T) {
    let encoded = block.data
    let decoded = try! T(encoded)
    XCTAssertEqual(block, decoded)
    print(decoded)
  }

  func testStreamInfo() {
    assertDecodedEqual(
      StreamInfo(
        minimumBlockSize: 1024, maximumBlockSize: 1024, minimumFrameSize: 1024, maximumFrameSize: 1024,
        sampleRate: 44100, numberOfChannels: 2, bitsPerSampe: 16, totalSamples: 1_000_000,
        md5Signature: .init(repeating: 0, count: 16)
      )
    )
  }

  func testPadding() {
    let count = 1024
    assertDecodedEqual(Padding(count: count))
  }

  func testApplication() {
    assertDecodedEqual(Application(id: .init("FLAC".utf8), applicationData: .init(repeating: 1, count: 100)))
  }

  func testSeekTable() {
    assertDecodedEqual(SeekTable(seekPoints: .init(repeating: .init(sampleNumber: 0x1234, offset: 0x5678, frameSample: 0x9abc), count: 20)))
  }

  func testVorbisComment() {
    assertDecodedEqual(
      VorbisComment(
        vendorString: "Metaflac Swift",
        userComments: [
          "haha=1", "bb=2"
      ])
    )
  }
  static var allTests = [
    ("testStreamInfo", testStreamInfo),
  ]
}
