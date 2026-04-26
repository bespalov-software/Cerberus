// Cerberus — Swift facade over the BoringSSL static libraries packaged in
// CCerberus.xcframework. The initial surface is intentionally tiny — just
// enough to validate the link chain (Swift → CCerberus → libcrypto). Expand
// with typed wrappers for AES-GCM, HKDF, ECDH, etc. as consumers need them.

import CCerberus
import Foundation

public enum Cerberus {

    /// SHA-256 digest of `data`. Used by smoke tests to prove BoringSSL is linked.
    public static func sha256(_ data: Data) -> Data {
        var digest = Data(count: Int(SHA256_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes { digestBuf in
            data.withUnsafeBytes { dataBuf in
                _ = SHA256(
                    dataBuf.bindMemory(to: UInt8.self).baseAddress,
                    data.count,
                    digestBuf.bindMemory(to: UInt8.self).baseAddress
                )
            }
        }
        return digest
    }
}

public extension Data {
    /// Lowercase hex encoding. Test/debug use only — not constant-time.
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
