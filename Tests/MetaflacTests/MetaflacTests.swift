import XCTest
@testable import Metaflac

final class MetaflacTests: XCTestCase {
    
    var metaflac: FlacMetadata!

    let file = "/Users/kojirou/Projects/Metaflac/Examples/file.flac"
    
    override func setUp() {
        super.setUp()
        metaflac = try! .init(filepath: file)
    }

    func testEncodeMetadataBlockData() {
        let streamInfo = metaflac.streamInfo
        print(streamInfo)
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
            let header = MetadataBlockHeader.init(lastMetadataBlockFlag: true, blockType: type, length: UInt32.random(in: .min...2^24))
            let encoded = header.encode()
            let decoded = try! MetadataBlockHeader.init(data: encoded)
            XCTAssertEqual(header, decoded)
        }
        
    }
    
    func testEncodeSeekTable() {
        metaflac.blocks.forEach { (block) in
            switch block {
            case .seekTable(let s):
                let encoded = s.data
                let decoded = try! SeekTable.init(encoded)
                XCTAssertEqual(s, decoded)
            default:
                break
            }
        }
    }
    
    func testEncodeVorbisComment() {
        metaflac.blocks.forEach { (block) in
            switch block {
            case .vorbisComment(let v):
                let encoded = v.data
                let decoded = try! VorbisComment.init(encoded)
                XCTAssertEqual(v, decoded)
            default:
                break
            }
        }
        let my = VorbisComment.init(vendorString: "metaflac in swift", userComments: [
            "haha=1", "bb=2"
            ])
        let encoded = my.data
        let decoded = try! VorbisComment.init(encoded)
        XCTAssertEqual(my, decoded)
    }
    
    func testEncodePicture() {
        metaflac.blocks.forEach { (block) in
            switch block {
            case .picture(let v):
                print("testing picture")
                let encoded = v.data
                let decoded = try! Picture.init(encoded)
                XCTAssertEqual(v, decoded)
            default:
                break
            }
        }
    }
    
    func testRecalculateSize() {
        print(MemoryLayout<FlacMetadata>.size)
    }
    
    func testSave() {
        metaflac.vorbisComment = .init(vendorString: "reference libFLAC 1.3.2 20170101", userComments: ["KEY=VALUE"])
        try! metaflac.save()
    }
    
    func testAddLength() {
        metaflac.append(Application.init(id: "ABCD", applicationData: Data.init(repeating: 0, count: 10_000_000)))
        try! metaflac.save()
    }
    
    func testAddPicture() {
        metaflac.append(Metaflac.Picture.init(file: .init(fileURLWithPath: "/Users/kojirou/Projects/Metaflac/Examples/cover.jpg"))!)
        try! metaflac.save()
        
    }
    
    static var allTests = [
        ("testEncodeSeekTable", testEncodeSeekTable),
    ]
}
