import PlannerCore
import SwiftUI

private struct SavedRecoverySelectionDraft: Identifiable {
  let selection: PlannerRecoverySelection
  var id: UUID { selection.selectionId }
}

struct SavedRecoveryCopiesView: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @State private var copies: [PlannerRecoveryView]?
  @State private var failure: String?
  @State private var isLoading = false
  @State private var loadingIdentifier = UUID()
  @State private var selectionRequest: PlannerRecoveryRequest?
  @State private var requestIdentifier = UUID()
  @State private var isSelecting = false
  @State private var selection: SavedRecoverySelectionDraft?

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          ProgressView("Reading recovery copies")
        } else if let failure {
          ContentUnavailableView {
            Label("Recovery unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(failure)
          } actions: {
            Button("Try again") { Task { await loadCopies() } }
          }
        } else if let copies, copies.isEmpty {
          ContentUnavailableView(
            "No Recovery Copies", systemImage: "clock.arrow.circlepath",
            description: Text("Recovery copies appear after Planner saves data.")
          )
          .accessibilityIdentifier("saved.recovery.empty")
        } else if let copies {
          Form {
            ForEach(copies, id: \.namespaceId) { copy in
              Section {
                if let snapshot = copy.acknowledgedSnapshot {
                  Button {
                    requestSelection(
                      .acknowledgedSnapshot(
                        namespaceId: copy.namespaceId,
                        checkpointGeneration: snapshot.checkpointGeneration))
                  } label: {
                    Label("Saved snapshot", systemImage: "checkmark.shield")
                  }
                  .disabled(copy.availability != .available || snapshot.integrity != "verified")
                  .accessibilityIdentifier("saved.recovery.snapshot.\(copy.namespaceId)")
                } else {
                  Text("No acknowledged saved snapshot")
                    .foregroundStyle(.secondary)
                }
                ForEach(copy.preparedProposals, id: \.proposalId) { proposal in
                  Button {
                    requestSelection(
                      .proposal(namespaceId: copy.namespaceId, proposalId: proposal.proposalId))
                  } label: {
                    Label("Unverified proposal", systemImage: "exclamationmark.triangle")
                  }
                  .disabled(copy.availability != .available)
                  .accessibilityIdentifier("saved.recovery.proposal.\(proposal.proposalId)")
                }
                if copy.availability != .available {
                  Label(availabilityDescription(copy), systemImage: "exclamationmark.triangle")
                }
                DisclosureGroup("Copy details") {
                  LabeledContent("Dataset", value: copy.datasetId.uuidString)
                  LabeledContent("Recovery copy", value: copy.namespaceId.uuidString)
                }
              } header: {
                Text(copy.ownershipDescription ?? "Dataset \(copy.datasetId.uuidString.prefix(8))")
              } footer: {
                if !copy.preparedProposals.isEmpty {
                  Text("Unverified proposals contain intended changes, not confirmed saved data.")
                }
              }
            }
          }
          .formStyle(.grouped)
          .disabled(isSelecting)
        } else {
          ProgressView("Reading recovery copies")
        }
      }
      .navigationTitle("Recovery copies")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("saved.recovery.done")
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Refresh", systemImage: "arrow.clockwise") { Task { await loadCopies() } }
            .disabled(isLoading || isSelecting)
            .accessibilityIdentifier("saved.recovery.refresh")
        }
      }
      .overlay { if isSelecting { ProgressView("Opening recovery copy") } }
    }
    .task(id: store.changeRevision) { await loadCopies() }
    .task(id: requestIdentifier) { await loadSelection() }
    .sheet(item: $selection) { draft in
      SavedRecoverySelectionView(store: store, selection: draft.selection)
    }
    #if os(macOS)
      .frame(minWidth: 480, minHeight: 440)
    #endif
  }

  private func availabilityDescription(_ copy: PlannerRecoveryView) -> String {
    switch copy.availability {
    case .available: "Available"
    case .unavailable: "This recovery copy is unavailable."
    case .ownershipUnverified: "The owner of this recovery copy could not be verified."
    }
  }

  private func requestSelection(_ request: PlannerRecoveryRequest) {
    selectionRequest = request
    requestIdentifier = UUID()
  }

  private func loadCopies() async {
    let request = UUID()
    loadingIdentifier = request
    isLoading = true
    failure = nil
    defer { if loadingIdentifier == request { isLoading = false } }
    do {
      let loaded = try await store.readRecoveryCopies()
      guard !Task.isCancelled, loadingIdentifier == request else { return }
      copies = loaded
    } catch {
      guard !Task.isCancelled, loadingIdentifier == request else { return }
      failure = (error as? PlannerFailure)?.message ?? error.localizedDescription
    }
  }

  private func loadSelection() async {
    guard let selectionRequest else { return }
    let request = requestIdentifier
    isSelecting = true
    defer { if requestIdentifier == request { isSelecting = false } }
    do {
      let selected = try await store.selectRecoveryCopy(selectionRequest)
      guard !Task.isCancelled, requestIdentifier == request else { return }
      selection = .init(selection: selected)
    } catch {
      guard !Task.isCancelled, requestIdentifier == request else { return }
      failure = (error as? PlannerFailure)?.message ?? error.localizedDescription
    }
  }
}
