import Foundation
import PlannerCore

enum PlannerNativeStorage {
  static func configuration(
    directory: URL, processRole: PlannerStorageConfiguration.ProcessRole
  ) -> PlannerStorageConfiguration {
    .init(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: processRole, storageMode: .localOnly)
  }

  static func mainConfiguration(localDirectory: URL, sharedDirectory: URL?) throws
    -> PlannerStorageConfiguration
  {
    let local = configuration(directory: localDirectory, processRole: .mainApplication)
    guard let sharedDirectory else { return local }
    let shared = configuration(directory: sharedDirectory, processRole: .mainApplication)
    if local.storeURL.standardizedFileURL != shared.storeURL.standardizedFileURL,
      !FileManager.default.fileExists(atPath: shared.controlURL.path),
      FileManager.default.fileExists(atPath: local.storeURL.path)
        || FileManager.default.fileExists(atPath: local.controlURL.path)
    {
      throw CocoaError(
        .fileReadUnknown,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Planner found existing local data. It must be moved safely before using shared storage. Your local data is unchanged."
        ])
    }
    return shared
  }

  static func configuredSharedDirectory() throws -> URL? {
    guard
      let configuredIdentifier = Bundle.main.object(
        forInfoDictionaryKey: "PlannerAppGroupIdentifier")
        as? String
    else { return nil }
    let identifier = configuredIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !identifier.isEmpty else { return nil }
    guard !identifier.contains("$("),
      let directory = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: identifier)
    else { throw sharedStorageUnavailable() }
    return directory.appending(path: "Planner", directoryHint: .isDirectory)
  }

  static func sharedConfiguration() throws -> PlannerStorageConfiguration {
    guard let directory = try configuredSharedDirectory() else {
      throw sharedStorageUnavailable()
    }
    return try privateConfiguration(
      configuration(directory: directory, processRole: .shareExtension))
  }

  static func privateConfiguration(_ local: PlannerStorageConfiguration) throws
    -> PlannerStorageConfiguration
  {
    guard
      let containerIdentifier = Bundle.main.object(
        forInfoDictionaryKey: "PlannerCloudContainerIdentifier") as? String,
      !containerIdentifier.isEmpty, !containerIdentifier.contains("$(")
    else {
      throw CocoaError(
        .fileReadUnknown,
        userInfo: [NSLocalizedDescriptionKey: "Planner's private iCloud configuration is missing."])
    }
    return .init(
      storeURL: local.storeURL, controlURL: local.controlURL,
      recoveryDirectoryURL: local.recoveryDirectoryURL, processRole: local.processRole,
      storageMode: .privateCloud(containerIdentifier: containerIdentifier))
  }

  private static func sharedStorageUnavailable() -> CocoaError {
    CocoaError(
      .fileReadNoPermission,
      userInfo: [
        NSLocalizedDescriptionKey:
          "Planner cannot access its shared data on this device."
      ])
  }
}
