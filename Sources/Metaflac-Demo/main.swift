import Metaflac
import Foundation

CommandLine.arguments[1...].forEach { path in
    do {
        let meta = try Metaflac.init(filepath: path)
        print(meta.streamInfo)
    } catch {
        print("Can't read file: \(path)")
        print("Error: \(error)")
    }
}
