import Darwin
import Dispatch
import Foundation

/// Metadata tracks replacements and in-place changes even when modification time is restored.
struct PlannerObservedFile: Equatable, Sendable {
  let device: Int32
  let inode: UInt64
  let size: Int64
  let modificationSeconds: Int
  let modificationNanoseconds: Int
  let changeSeconds: Int
  let changeNanoseconds: Int

  init?(_ url: URL) {
    var attributes = stat()
    guard
      url.withUnsafeFileSystemRepresentation({ path in
        guard let path else { return false }
        return stat(path, &attributes) == 0
      })
    else { return nil }
    self.init(attributes)
  }

  init(_ attributes: stat) {
    device = attributes.st_dev
    inode = attributes.st_ino
    size = attributes.st_size
    modificationSeconds = attributes.st_mtimespec.tv_sec
    modificationNanoseconds = attributes.st_mtimespec.tv_nsec
    changeSeconds = attributes.st_ctimespec.tv_sec
    changeNanoseconds = attributes.st_ctimespec.tv_nsec
  }

  func isSameFile(as other: Self) -> Bool {
    device == other.device && inode == other.inode
  }
}

/// The source is immutable after setup; Dispatch supports cancellation from any thread.
final class PlannerFileObservation: @unchecked Sendable {
  private let source: any DispatchSourceFileSystemObject
  let file: PlannerObservedFile

  init(url: URL, changed: @escaping @Sendable () -> Void) throws {
    let descriptor = open(url.path, O_EVTONLY | O_CLOEXEC)
    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var attributes = stat()
    guard fstat(descriptor, &attributes) == 0 else {
      let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      close(descriptor)
      throw error
    }
    file = .init(attributes)
    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: [.write, .delete, .rename, .attrib, .revoke],
      queue: .global(qos: .utility))
    source.setEventHandler(handler: changed)
    source.setCancelHandler { close(descriptor) }
    source.activate()
  }

  deinit { source.cancel() }
}

/// Directory events cover publication. A paced sweep checks retained files edited in place.
struct PlannerRecoveryFileAudit: Sendable {
  private var files: [URL] = []
  private var fingerprints: [URL: PlannerObservedFile] = [:]
  private var next = 0

  mutating func updateInventory(_ urls: [URL]) {
    guard files != urls else { return }
    let nextFile = files.indices.contains(next) ? files[next] : nil
    fingerprints = Dictionary(
      uniqueKeysWithValues: urls.compactMap { url in
        (fingerprints[url] ?? PlannerObservedFile(url)).map { (url, $0) }
      })
    files = urls
    next = nextFile.flatMap { files.firstIndex(of: $0) } ?? 0
  }

  mutating func checkBatch() -> Bool {
    guard !files.isEmpty else { return false }
    var changed = false
    for _ in 0..<min(128, files.count) {
      let url = files[next]
      let fingerprint = PlannerObservedFile(url)
      if fingerprints[url] != fingerprint {
        fingerprints[url] = fingerprint
        changed = true
      }
      next = (next + 1) % files.count
    }
    return changed
  }
}
