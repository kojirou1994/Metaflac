import XCTest
@testable import Metaflac

final class MetaflacTests: XCTestCase {
    
    var metaflac: Metaflac!

    let file = "/Users/kojirou/Projects/Metaflac/Examples/file.flac"
    
    override func setUp() {
        super.setUp()
        metaflac = try! Metaflac.init(filepath: file)
    }

    func testEncodeMetadataBlockData() {
        let streamInfo = metaflac.streamInfo
        print(streamInfo)
        let encoded = streamInfo.encode()
        let decoded = try! StreamInfo.init(data: encoded)
        XCTAssertEqual(streamInfo, decoded)
    }
    
    func testEncodePadding() {
        let padding = Padding.init(count: 1024)
        let encoded = padding.encode()
        let decoded = Padding.init(data: encoded)
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
                let encoded = s.encode()
                let decoded = try! SeekTable.init(data: encoded)
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
                let encoded = v.encode()
                let decoded = try! VorbisComment.init(data: encoded)
                XCTAssertEqual(v, decoded)
            default:
                break
            }
        }
        let my = VorbisComment.init(vendorString: "metaflac in swift", userComments: [
            "haha=1", "bb=2"
            ])
        let encoded = my.encode()
        let decoded = try! VorbisComment.init(data: encoded)
        XCTAssertEqual(my, decoded)
    }
    
    func testEncodePicture() {
        metaflac.blocks.forEach { (block) in
            switch block {
            case .picture(let v):
                print("testing picture")
                let encoded = v.encode()
                let decoded = try! Picture.init(data: encoded)
                XCTAssertEqual(v, decoded)
            default:
                break
            }
        }
    }
    
    func testRecalculateSize() {
        print(MemoryLayout<StreamInfo>.size)
    }
    
    func testSave() {
        metaflac.vorbisComment = .init(vendorString: "reference libFLAC 1.3.2 20170101", userComments: ["KEY=VALUE"])
        try! metaflac.save()
    }
    
    static var allTests = [
        ("testEncodeSeekTable", testEncodeSeekTable),
    ]
}
