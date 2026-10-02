import Foundation
import CryptoKit

/// Licensed art is decrypted in memory, without writing a plaintext GLB to disk.
enum ArtVault {
    static func model(_ name:String) -> Data? {
        guard let key=GeneratedArtKeys.keys[name],let url=Bundle.main.url(forResource:name,withExtension:"asset"),let data=try? Data(contentsOf:url),let box=try? AES.GCM.SealedBox(combined:data) else{return nil}
        return try? AES.GCM.open(box,using:SymmetricKey(data:key))
    }
}
