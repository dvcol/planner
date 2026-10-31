import Darwin
import Foundation
import Testing

@testable import PlannerCore

struct PrivateSyncLeaseTests {
  @Test func workerOwnershipIsExclusiveAndReleasesWithoutSuspensionUnsafeLocks() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    var owner: PlannerPrivateSyncLease? = try #require(
      try PlannerPrivateSyncLease(directory: directory))
    #expect(try PlannerPrivateSyncLease(directory: directory) == nil)
    let descriptor = open(
      directory.appendingPathComponent("sync-worker.lock").path,
      O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
    #expect(descriptor >= 0)
    guard descriptor >= 0 else { return }
    defer { close(descriptor) }
    #if os(iOS)
      #expect(
        flock(descriptor, LOCK_EX | LOCK_NB) == 0,
        "iOS worker ownership must not retain a kernel file lock across app suspension.")
      flock(descriptor, LOCK_UN)
    #else
      #expect(flock(descriptor, LOCK_EX | LOCK_NB) == -1)
      #expect(errno == EWOULDBLOCK)
    #endif
    #expect(owner != nil)
    owner = nil
    let successor = try #require(try PlannerPrivateSyncLease(directory: directory))
    let competitor = try PlannerPrivateSyncLease(directory: directory)
    #expect(competitor == nil)
    withExtendedLifetime(successor) {}
  }
}
