// Usage: swift pack_art.swift model.glb destination.asset GeneratedArtKeys.swift
import Foundation
import CryptoKit
let args=CommandLine.arguments
precondition(args.count==4)
let name=URL(fileURLWithPath:args[2]).deletingPathExtension().lastPathComponent
let key=SymmetricKey(size:.bits256)
let bytes=key.withUnsafeBytes { Data($0) }
let sealed=try AES.GCM.seal(Data(contentsOf:URL(fileURLWithPath:args[1])),using:key)
try sealed.combined!.write(to:URL(fileURLWithPath:args[2]),options:.atomic)
let manifest=URL(fileURLWithPath:NSHomeDirectory()).appendingPathComponent("Library/Application Support/TurboRacer/ArtSources/private-art-keys.json")
var keys=(try? JSONDecoder().decode([String:String].self,from:Data(contentsOf:manifest))) ?? [:]
keys[name]=bytes.base64EncodedString()
try JSONEncoder().encode(keys).write(to:manifest,options:.atomic)
let entries=keys.sorted{$0.key<$1.key}.map { "\"\($0.key)\": Data(base64Encoded: \"\($0.value)\")!" }.joined(separator:",\n")
let code="import Foundation\nenum GeneratedArtKeys { static let keys: [String:Data] = [\n\(entries)\n] }\n"
try code.write(toFile:args[3],atomically:true,encoding:.utf8)
print("Packaged licensed art:",name)
