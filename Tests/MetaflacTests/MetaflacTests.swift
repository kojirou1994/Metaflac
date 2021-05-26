import XCTest
@testable import Metaflac

final class MetaflacTests: XCTestCase {

  //    var metaflac: FlacMetadata!
  //
  //    let sampleFile = "/Users/kojirou/Projects/Metaflac/Tests/Sample_BeeMoved_96kHz24bit.flac"
  //
  //    let testFilePath = "/Users/kojirou/Projects/Metaflac/Tests/testing.flac"

  override func setUp() {
    super.setUp()
    //        if FileManager.default.fileExists(atPath: testFilePath) {
    //            try! FileManager.default.removeItem(atPath: testFilePath)
    //        }
    //        try! FileManager.default.copyItem(atPath: sampleFile, toPath: testFilePath)
    //        metaflac = try! .init(filepath: testFilePath)
    //        print(metaflac.blocks)
    //        print(Bundle.main.bundlePath)
  }

  func testSave() {
    //        let v = VorbisComment.init(vendorString: "reference libFLAC 1.3.2 20170101", userComments: ["KEY=VALUE"])
    //        metaflac.vorbisComment = v
    //        try! metaflac.save(paddingMode: .autoResize(upTo: 1000), atomic: false)
    //        try! metaflac.reload()
    //        XCTAssertEqual(v, metaflac.vorbisComment)
  }

  func testAddLength() {
    //        metaflac.append(Application.init(id: "ABCD".data(using: .ascii)!, applicationData: Data.init(repeating: 0, count: 10_000_000)))
    //        try! metaflac.save(paddingMode: .autoResize(upTo: 1000), atomic: false)
    //        try! metaflac.reload()
  }

  func testAddPicture() {
    //        let pictureBlock = Metaflac.Picture.init(file: .init(fileURLWithPath: "/Users/kojirou/Projects/Metaflac/Examples/cover.jpg"))!
    //        metaflac.append(pictureBlock)
    //        try! metaflac.save(paddingMode: .autoResize(upTo: 1000), atomic: false)
    //        try! metaflac.reload()
  }

  func testExactPaddingMode() throws {
    //        let file = "/Volumes/GLOWAY_720G/FoundationTest/backup的副本.flac"
    //        var meta = try FlacMetadata(filepath: file)
    ////        let length = UInt32.random(in: 0...UInt32.max)
    //        for length in 1...UInt32(100_000) {
    //            try meta.save(paddingMode: .exact(length: length), atomic: true)
    //            try meta.reload()
    //            XCTAssertEqual(meta.blocks.paddingLength, Int(length) + 4)
    //        }

  }

  func testAutoResizePaddingMode() throws {
    //        let file = "/Volumes/GLOWAY_720G/FoundationTest/backup的副本.flac"
    //        var meta = try FlacMetadata(filepath: file)
    //        try meta.save(paddingMode: .exact(length: 100_000), atomic: true)
    //        try meta.reload()
    ////        let length = UInt32.random(in: 0...UInt32.max)
    //        for length in 0...UInt32(100_000) {
    //            XCTAssertEqual(meta.blocks.paddingLength, Int(length) + 4)
    //        }
  }

}
