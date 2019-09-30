import XCTest
@testable import Metaflac

final class MetaflacTests: XCTestCase {
    
    var metaflac: FlacMetadata!

    let originalFile = "/Users/kojirou/Projects/Metaflac/Examples/backup.flac"
    
    let testFile = "/Users/kojirou/Projects/Metaflac/Examples/file.flac"
    
    override func setUp() {
        super.setUp()
//        if FileManager.default.fileExists(atPath: testFile) {
//            try! FileManager.default.removeItem(atPath: testFile)
//        }
//        try! FileManager.default.copyItem(atPath: originalFile, toPath: testFile)
//        metaflac = try! .init(filepath: testFile)
//        print(metaflac.blocks)
    }

    func testEncodeMetadataBlockData() {
        let streamInfo = metaflac.streamInfo
//        print(streamInfo)
        let encoded = streamInfo.data
        let decoded = try! StreamInfo.init(encoded)
        XCTAssertEqual(streamInfo, decoded)
    }
    
    func testEncodePadding() {
        let padding = Padding.init(count: 1024)
        let encoded = padding.data
        let decoded = Padding.init(encoded)
        XCTAssertEqual(padding, decoded)
    }
    
    func testEncodeHeader() {
        for type in BlockType.allCases {
            print("\(type) = \(type.rawValue)")
            let header = MetadataBlockHeader.init(lastMetadataBlockFlag: false, blockType: type, length: 1586784)
            let encoded = header.encode()
            let decoded = try! MetadataBlockHeader.init(data: encoded)
            XCTAssertEqual(header, decoded)
        }
        
    }
    
    func testEncodeSeekTable() {
//        metaflac.blocks.forEach { (block) in
//            switch block {
//            case .seekTable(let s):
//                let encoded = s.data
//                let decoded = try! SeekTable.init(encoded)
//                XCTAssertEqual(s, decoded)
//            default:
//                break
//            }
//        }
    }
    
    func testEncodeVorbisComment() {
//        metaflac.blocks.forEach { (block) in
//            switch block {
//            case .vorbisComment(let v):
//                let encoded = v.data
//                let decoded = try! VorbisComment.init(encoded)
//                XCTAssertEqual(v, decoded)
//            default:
//                break
//            }
//        }
//        let my = VorbisComment.init(vendorString: "metaflac in swift", userComments: [
//            "haha=1", "bb=2"
//            ])
//        let encoded = my.data
//        let decoded = try! VorbisComment.init(encoded)
//        XCTAssertEqual(my, decoded)
    }
    
    func testEncodePicture() {
//        metaflac.blocks.forEach { (block) in
//            switch block {
//            case .picture(let v):
//                print("testing picture")
//                let encoded = v.data
//                let decoded = try! Picture.init(encoded)
//                XCTAssertEqual(v, decoded)
//            default:
//                break
//            }
//        }
    }
    
    func testEncodeCueSheet() {
        let original = CueSheet.init(mediaCatalogNumber: "ABCDEO:NALS", numberOfLeadinSamples: 14354325, compactDisc: true, trackNumber: 5, tracks: [CueSheet.Track].init(repeating: CueSheet.Track.init(trackOffsetInSamples: 434, trackNumber: 4, trackISRC: [UInt8].init(repeating: 0, count: 12), isAudio: .random(), preEmphasis: .random(), numberOfTrackIndexPoints: 3, indexes: [CueSheet.Track.Index].init(repeating: CueSheet.Track.Index.init(offsetInSample: 32144, indexPointNumber: 6), count: 3)), count: 5))
        let encoded = original.data
        let decoded = try! CueSheet.init(encoded)
        let encoded2 = decoded.data
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(encoded, encoded2)
    }
    
    func testRecalculateSize() {
        print(MemoryLayout<FlacMetadata>.size)
    }
    
    func testSave() {
        let v = VorbisComment.init(vendorString: "reference libFLAC 1.3.2 20170101", userComments: ["KEY=VALUE"])
        metaflac.vorbisComment = v
        try! metaflac.save(atomic: false)
        try! metaflac.reload()
        XCTAssertEqual(v, metaflac.vorbisComment)
    }
    
    func testAddLength() {
        metaflac.append(Application.init(id: "ABCD".data(using: .ascii)!, applicationData: Data.init(repeating: 0, count: 10_000_000)))
        try! metaflac.save(atomic: false)
        try! metaflac.reload()
    }
    
    func testAddPicture() {
        let pictureBlock = Metaflac.Picture.init(file: .init(fileURLWithPath: "/Users/kojirou/Projects/Metaflac/Examples/cover.jpg"))!
        metaflac.append(pictureBlock)
        try! metaflac.save(atomic: false)
        try! metaflac.reload()
    }
    
    static var allTests = [
        ("testEncodeSeekTable", testEncodeSeekTable),
    ]
}
