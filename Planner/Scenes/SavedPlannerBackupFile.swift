import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct SavedPlannerBackupFile: Transferable {
  let data: Data
  let filename =
    "Planner Backup " + Date.now.ISO8601Format().replacingOccurrences(of: ":", with: "-")

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .json) { backup in backup.data }
  }

  static func readSelectedFile(_ selectedURL: URL) throws -> Data {
    let hasScopedAccess = selectedURL.startAccessingSecurityScopedResource()
    defer { if hasScopedAccess { selectedURL.stopAccessingSecurityScopedResource() } }
    var coordinationFailure: NSError?
    var readResult: Result<Data, any Error>?
    NSFileCoordinator().coordinate(
      readingItemAt: selectedURL, options: [], error: &coordinationFailure
    ) { coordinatedURL in
      readResult = Result { try Data(contentsOf: coordinatedURL) }
    }
    if let coordinationFailure { throw coordinationFailure }
    guard let readResult else { throw CocoaError(.fileReadUnknown) }
    return try readResult.get()
  }
}
