import Metaflac
import Foundation

CommandLine.arguments[1...].forEach { path in
    do {
        let meta = try FlacMetadata.init(filepath: path)
        print(meta.streamInfo)
        print(meta.vorbisComment?.description ?? "No vorbis comments.")
    } catch {
        print("Can't read file: \(path)")
        print("Error: \(error)")
    }
}
