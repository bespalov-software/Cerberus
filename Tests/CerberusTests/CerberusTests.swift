import XCTest
@testable import Cerberus

final class CerberusTests: XCTestCase {

    // Known-answer test: SHA-256 of the empty string.
    // Hash from FIPS 180-4 / RFC 6234.
    func test_sha256_emptyString() {
        let digest = Cerberus.sha256(Data())
        XCTAssertEqual(
            digest.hexString,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    // Second known-answer test: SHA-256 of "abc".
    // Hash from NIST CAVP / FIPS 180-4 example.
    func test_sha256_abc() {
        let digest = Cerberus.sha256(Data("abc".utf8))
        XCTAssertEqual(
            digest.hexString,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }
}
