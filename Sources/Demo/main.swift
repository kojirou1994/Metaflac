import Metaflac
import Foundation

#if DEBUG
print(MemoryLayout<StreamInfo>.stride)
exit(0)
#endif

let path = CommandLine.arguments[1]

let meta = try Metaflac.init(filepath: path)
print(meta.streamInfo)
