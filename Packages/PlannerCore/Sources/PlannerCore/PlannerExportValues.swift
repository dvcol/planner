import Foundation

public enum PlannerExportResult: Sendable {
  case exported(Data)
  case failed(PlannerFailure)
}
