import Darwin
import Foundation
import Synchronization

// shortcut: larger histories incur cold reads beyond this metadata bound; payloads are never retained.
private let recoveryHeaderCacheCapacity = 16_384

/// Reuses decoded metadata only while the opened file and its current path still agree.
final class PlannerRecoveryHeaderCache<Header: Decodable & Sendable>: Sendable {
  private struct Fingerprint: Equatable, Sendable {
    let device: Int32
    let inode: UInt64
    let size: Int64
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let changedSeconds: Int
    let changedNanoseconds: Int

    init(_ attributes: stat) {
      device = attributes.st_dev
      inode = attributes.st_ino
      size = attributes.st_size
      modifiedSeconds = attributes.st_mtimespec.tv_sec
      modifiedNanoseconds = attributes.st_mtimespec.tv_nsec
      changedSeconds = attributes.st_ctimespec.tv_sec
      changedNanoseconds = attributes.st_ctimespec.tv_nsec
    }
  }

  private struct Entry: Sendable {
    let fingerprint: Fingerprint
    let header: Header
  }

  private let entries = Mutex<[URL: Entry]>([:])

  func read(at url: URL) throws -> Header {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    let before = try fingerprint(descriptor: file.fileDescriptor)
    if let entry = entries.withLock({ $0[url] }), entry.fingerprint == before {
      try verifyPath(url, fingerprint: before)
      return entry.header
    }

    let data = try file.readToEnd() ?? Data()
    let header = try JSONDecoder().decode(Header.self, from: data)
    guard try fingerprint(descriptor: file.fileDescriptor) == before else {
      throw changedFile()
    }
    try verifyPath(url, fingerprint: before)
    entries.withLock { values in
      if values[url] == nil, values.count >= recoveryHeaderCacheCapacity,
        let evictedURL = values.keys.first
      {
        values.removeValue(forKey: evictedURL)
      }
      values[url] = Entry(fingerprint: before, header: header)
    }
    return header
  }

  private func fingerprint(descriptor: Int32) throws -> Fingerprint {
    var attributes = stat()
    guard fstat(descriptor, &attributes) == 0 else { throw posixFailure() }
    return Fingerprint(attributes)
  }

  private func verifyPath(_ url: URL, fingerprint expected: Fingerprint) throws {
    var attributes = stat()
    let result = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return Int32(-1) }
      return stat(path, &attributes)
    }
    guard result == 0 else { throw posixFailure() }
    guard Fingerprint(attributes) == expected else { throw changedFile() }
  }

  private func posixFailure() -> Error {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
  }

  private func changedFile() -> PlannerFailure {
    PlannerFailure(
      "recoveryIntegrityFailure", "Recovery evidence changed while reading its header.")
  }
}
