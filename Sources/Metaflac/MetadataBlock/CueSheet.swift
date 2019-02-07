//
//  CueSheet.swift
//  Metaflac
//
//  Created by Kojirou on 2019/2/1.
//

import Foundation


/// This block is for storing various information that can be used in a cue sheet. It supports track and index points, compatible with Red Book CD digital audio discs, as well as other CD-DA metadata such as media catalog number and track ISRCs. The CUESHEET block is especially useful for backing up CD-DA discs, but it can be used as a general purpose cueing mechanism for playback.
public struct CueSheet: MetadataBlockData, Equatable {
    
    public var data: Data {
        fatalError()
    }
    
    public var length: Int {
        fatalError()
    }
    
    
    public init(_ data: Data) throws {
        fatalError()
//        let reader = DataReader.init(data: data)
//        let mediaCatalogNumber = reader.read(128)
//        let number = reader.read(64/8)
//        let flag = reader.read(259)
//        let trackNumber = reader.read(1)
        
    }
    
    public var description: String {
        return """
        """
    }
    
}

