//
//  VorbisComment.swift
//  Metaflac
//
//  Created by Kojirou on 2019/2/1.
//

import Foundation

/// This block is for storing a list of human-readable name/value pairs. Values are encoded using UTF-8. It is an implementation of the Vorbis comment specification (without the framing bit). This is the only officially supported tagging mechanism in FLAC. There may be only one VORBIS_COMMENT block in a stream. In some external documentation, Vorbis comments are called FLAC tags to lessen confusion.
public struct VorbisComment: MetadataBlockData, Equatable {
    
    public var data: Data {
        let capacity = length
        var result = Data.init(capacity: capacity)
        result.append(contentsOf: UInt32(vendorString.utf8.count).byteSwapped.splited)
        result.append(contentsOf: vendorString.data(using: .utf8)!)
        result.append(contentsOf: UInt32(userComments.count).byteSwapped.splited)
        for comment in userComments {
            result.append(contentsOf: UInt32(comment.utf8.count).byteSwapped.splited)
            result.append(contentsOf: comment.data(using: .utf8)!)
        }
        precondition(capacity == result.count)
        return result
    }
    
    public var length: Int {
        return 32/8 + vendorString.utf8.count + 32/8 + 32/8*userComments.count + userComments.reduce(0, {$0 + $1.utf8.count})
    }
    
    public var description: String {
        return """
        vendor string: \(vendorString)
        comments: \(userComments.count)
        \(userComments.enumerated().map {"comment[\($0.offset)]: \($0.element)"}.joined(separator: "\n"))
        """
    }
    public var vendorString: String
    
    public var userComments: [String]
    
    public init(_ data: Data) throws {
        let reader = DataHandle.init(data: data)
        let vendorLength = reader.read(4).joined(UInt32.self).byteSwapped
        vendorString = String.init(decoding: reader.read(Int(vendorLength)), as: UTF8.self)
        let userCommentListLength = reader.read(4).joined(UInt32.self).byteSwapped
        var userComments = [String]()
        for _ in 0..<userCommentListLength {
            let length = reader.read(4).joined(UInt32.self).byteSwapped
            let userComment = String.init(decoding: reader.read(Int(length)), as: UTF8.self)
            userComments.append(userComment)
        }
        try reader.check()
        self.userComments = userComments
    }
    
    public init(vendorString: String, userComments: [String]) {
        self.vendorString = vendorString
        self.userComments = userComments
    }
    
}
