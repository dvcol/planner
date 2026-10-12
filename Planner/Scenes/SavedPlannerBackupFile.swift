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
}
