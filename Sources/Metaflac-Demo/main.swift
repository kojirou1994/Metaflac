import Metaflac
import Foundation

let path = CommandLine.arguments[1]

let meta = try Metaflac.init(filepath: path)
print(meta.streamInfo)
