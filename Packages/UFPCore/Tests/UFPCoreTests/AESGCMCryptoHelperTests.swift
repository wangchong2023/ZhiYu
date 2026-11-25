//
//  AESGCMCryptoHelperTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 AESGCMCryptoHelper 与 DocumentFormat 在正常路径、非法密文与未知后缀下的行为。
//

import XCTest
import CryptoKit
@testable import UFPCore

final class AESGCMCryptoHelperTests: XCTestCase {

    func testEncryptAndDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plain = "智宇 ZhiYu Secret Token 123"
        let cipher = try AESGCMCryptoHelper.encrypt(plain, using: key)
        XCTAssertNotEqual(cipher, plain)
        let decrypted = try AESGCMCryptoHelper.decrypt(cipher, using: key)
        XCTAssertEqual(decrypted, plain)
    }

    func testDecryptWithWrongKeyThrows() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let cipher = try AESGCMCryptoHelper.encrypt("secret", using: key1)
        XCTAssertThrowsError(try AESGCMCryptoHelper.decrypt(cipher, using: key2))
    }

    func testSealedBoxWithInvalidBase64ThrowsDecodingFailed() {
        XCTAssertThrowsError(try AESGCMCryptoHelper.sealedBox(from: "%%%not-base64%%%")) { error in
            XCTAssertEqual(error as? SecurityError, .decodingFailed)
        }
    }

    func testUTF8StringWithInvalidBytesThrowsDecodingFailed() {
        let invalidUTF8 = Data([0xFF, 0xFE])
        XCTAssertThrowsError(try AESGCMCryptoHelper.utf8String(from: invalidUTF8)) { error in
            XCTAssertEqual(error as? SecurityError, .decodingFailed)
        }
    }

    func testSecurityErrorDescriptionsAreNonEmpty() {
        XCTAssertEqual(SecurityError.encodingFailed.errorDescription, "Data encoding failed")
        XCTAssertEqual(SecurityError.decodingFailed.errorDescription, "Data decoding failed")
        XCTAssertNotNil(SecurityError.invalidSalt.errorDescription)
    }

    func testDocumentFormatDetection() {
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/tmp/note.md")), .markdown)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/tmp/note.txt")), .plainText)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/tmp/doc.docx")), .docx)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/tmp/sheet.xlsx")), .xlsx)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/tmp/paper.PDF")), .pdf)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/tmp/archive.bin")), .unknown)
    }
}
