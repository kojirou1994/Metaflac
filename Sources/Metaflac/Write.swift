import Foundation
extension FileHandle {

  @inline(__always)
  func write(blocks: FlacMetadata.MetadataBlocks, containLastMetadataBlock: Bool) throws {
    let nonPaddingBlocks = blocks.otherBlocks.filter {$0.blockType != .padding}
    if nonPaddingBlocks.isEmpty {
      // only a StreamInfo block
      try write(block: .streamInfo(blocks.streamInfo), isLastMetadataBlock: containLastMetadataBlock)
    } else {
      try write(block: .streamInfo(blocks.streamInfo), isLastMetadataBlock: false)
      for (offset, element) in nonPaddingBlocks.enumerated() {
        if offset == nonPaddingBlocks.count - 1 {
          try write(block: element,
                    isLastMetadataBlock: containLastMetadataBlock)
        } else {
          try write(block: element, isLastMetadataBlock: false)
        }
      }
    }
  }

  @inline(__always)
  func writeLastPadding(count: Int) throws {
    struct Once {
      static let maxPaddingLength = Int(FlacMetadataBlockConstants.maxBlockLength)

      static let limit = 8 + maxPaddingLength
    }
    if count <= Once.maxPaddingLength {
      try write(block: .padding(.init(count: count)), isLastMetadataBlock: true)
    } else {
      var rest = count + 4
      while rest >= Once.limit {
        try write(block: .padding(.init(count: Once.maxPaddingLength)), isLastMetadataBlock: false)
        rest -= Once.maxPaddingLength + 4
      }
      try write(block: .padding(.init(count: rest-4)), isLastMetadataBlock: true)
    }
  }

  @inline(__always)
  private func write(block: FlacMetadataBlock, isLastMetadataBlock: Bool) throws {
    let header = block.header(lastMetadataBlockFlag: isLastMetadataBlock)
    try kwiftWrite(contentsOf: header.encode())
    switch block {
    case .application(let v): try v.write(to: self)
    case .cueSheet(let v): try v.write(to: self)
    case .padding(let v): try v.write(to: self)
    case .picture(let v): try v.write(to: self)
    case .seekTable(let v): try v.write(to: self)
    case .streamInfo(let v): try v.write(to: self)
    case .vorbisComment(let v): try v.write(to: self)
    }
  }

}
