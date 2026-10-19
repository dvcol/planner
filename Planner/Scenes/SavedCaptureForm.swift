import MapKit
import PlannerCore
import SwiftUI

enum SavedCaptureEntryPoint: Identifiable {
  case global
  case list(UUID)
  case share(PlannerLoadedCaptureInputs)

  var id: String {
    switch self {
    case .global: "global"
    case .list(let identifier): "list.\(identifier.uuidString)"
    case .share: "share"
    }
  }

  var initialListIdentifier: UUID? {
    guard case .list(let identifier) = self else { return nil }
    return identifier
  }
}

struct SavedCaptureForm: View {
  private struct DestinationLoadIdentity: Equatable {
    let namespace: String?
    let revision: UUID
    let draftIdentifier: UUID?
  }

  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let entryPoint: SavedCaptureEntryPoint
  let didSave: (PlannerEntityReference) -> Void
  var didCancel: (() -> Void)? = nil
  @State private var input = ""
  @State private var draft: PlannerCaptureDraftRead?
  @State private var title = ""
  @State private var subtitle = ""
  @State private var notes = ""
  @State private var estimate: PlannerEstimate?
  @State private var categoryIdentifiers: Set<UUID> = []
  @State private var tagIdentifiers: Set<UUID> = []
  @State private var locationName = ""
  @State private var locationAddress = ""
  @State private var links: [SavedOwnedLinkDraft] = []
  @State private var reuseIdentifier: UUID?
  @State private var destinationWindow: SavedItemWindow?
  @State private var loadedDestinationIdentity: DestinationLoadIdentity?
  @State private var initializedDestinationDraft: UUID?
  @State private var captureNamespace: String?
  @State private var destinationFailure: String?
  @State private var selectedListIdentifiers: Set<UUID> = []
  @State private var isWorking = false
  @State private var applied = false
  @State private var operationIdentifier = UUID()
  @State private var reviewChanged = false
  @State private var selectedPreviewLinkIdentifier: UUID?
  @State private var activePreviewRequestIdentifier: UUID?

  var body: some View {
    NavigationStack {
      Form {
        if let draft {
          reviewSections(draft)
        } else if case .share = entryPoint {
          Section {
            Text("Review the shared content before adding one Item.")
          }
        } else {
          Section {
            TextField("Text or link", text: $input, axis: .vertical)
              .lineLimit(4...10)
              .accessibilityIdentifier("saved.capture.input")
          } footer: {
            Text("Paste your text or links, then review before adding one Item.")
          }
        }
        if reviewChanged {
          Section {
            Label(
              "The destination changed. Review before adding again.", systemImage: "arrow.clockwise"
            )
          }
        }
      }
      .formStyle(.grouped)
      .accessibilityIdentifier("saved.capture.form")
      .disabled(isWorking || store.isSaving || applied)
      .safeAreaInset(edge: .top, spacing: 0) {
        if let message = store.alertMessage {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background)
            .accessibilityIdentifier("saved.capture.failure")
        }
      }
      .navigationTitle(draft == nil ? "Capture Text or Link" : "Review Capture")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(applied ? "Done" : "Cancel") {
            Task {
              isWorking = true
              if let draft, !applied { await store.discardCapture(draft) }
              if let didCancel { didCancel() } else { dismiss() }
            }
          }
          .disabled(isWorking || store.isSaving)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("saved.capture.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          if draft == nil {
            Button(entryPoint.id == "share" ? "Retry" : "Review") { Task { await prepare() } }
              .disabled(
                !store.canCreate || isWorking
                  || (entryPoint.id != "share"
                    && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              )
              .accessibilityIdentifier("saved.capture.review")
          } else {
            Button("Add") { Task { await save() } }
              .disabled(!store.canCreate || isWorking || applied || !canSave)
              .accessibilityIdentifier("saved.capture.add")
          }
        }
      }
      .overlay {
        if isWorking || store.isSaving {
          ProgressView(store.isSaving ? "Saving Item" : "Preparing capture")
        }
      }
    }
    .interactiveDismissDisabled(isWorking || store.isSaving)
    .task {
      if case .share = entryPoint { await prepare() }
    }
    .task(id: destinationLoadIdentity) { await loadDestinations(identity: destinationLoadIdentity) }
    .task(id: selectedPreviewLinkIdentifier) { await lookupMaps() }
    .onChange(of: links.map(\.input)) {
      guard let draft, links.map(\.input) != captureLinkInputs(draft) else { return }
      activePreviewRequestIdentifier = nil
    }
    .onDisappear {
      destinationWindow?.cancel()
      if let draft, !applied { Task { await store.discardCapture(draft) } }
    }
    #if os(macOS)
      .frame(minWidth: 440, minHeight: 420)
    #endif
  }

  @ViewBuilder
  private func reviewSections(_ draft: PlannerCaptureDraftRead) -> some View {
    if !draft.reuseCandidates.isEmpty || reuseIdentifier != nil {
      Section {
        Picker("Save as", selection: $reuseIdentifier) {
          Text("Create new Item").tag(nil as UUID?)
          if let reuseIdentifier,
            !draft.reuseCandidates.contains(where: { $0.itemId == reuseIdentifier })
          {
            Text("Selected Item no longer matches").tag(Optional(reuseIdentifier)).disabled(true)
          }
          ForEach(draft.reuseCandidates, id: \.itemId) { candidate in
            Text("Use existing: \(candidate.title)").tag(Optional(candidate.itemId))
          }
        }
        .accessibilityIdentifier("saved.capture.choice")
      } footer: {
        Text(
          "Use existing adds missing links and Lists. Its content and completion stay as they are.")
      }
    }
    if reuseIdentifier == nil {
      Section("Item") {
        TextField("Title", text: $title).accessibilityIdentifier("saved.capture.title")
        TextField("Subtitle", text: $subtitle).accessibilityIdentifier("saved.capture.subtitle")
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.capture.notes")
      }
      SavedActivityEstimateEditor(
        estimate: $estimate, accessibilityIdentifierPrefix: "saved.capture.estimate")
      Section("Labels") {
        NavigationLink {
          SavedItemLabelPicker(store: store, kind: .category, selection: $categoryIdentifiers)
        } label: {
          LabeledContent("Categories", value: selectionSummary(categoryIdentifiers))
        }
        .accessibilityIdentifier("saved.capture.categories")
        NavigationLink {
          SavedItemLabelPicker(store: store, kind: .tag, selection: $tagIdentifiers)
        } label: {
          LabeledContent("Tags", value: selectionSummary(tagIdentifiers))
        }
        .accessibilityIdentifier("saved.capture.tags")
      }
      Section("Location") {
        TextField("Place name", text: $locationName).accessibilityIdentifier(
          "saved.capture.location.name")
        TextField("Address", text: $locationAddress).accessibilityIdentifier(
          "saved.capture.location.address")
      }
    }
    SavedOwnedLinksEditor(links: $links, accessibilityIdentifierPrefix: "saved.capture.link")
    mapsPreviewSection(draft)
    Section {
      if let destinationWindow {
        SavedContainerWindowRows(
          window: destinationWindow, sourceKind: .list, selectionTag: { $0.id }
        ) { row in
          if case .source(let source) = row.identity {
            Toggle(
              row.title,
              isOn: Binding(
                get: { selectedListIdentifiers.contains(source.id) },
                set: { selected in
                  if selected {
                    selectedListIdentifiers.insert(source.id)
                  } else {
                    selectedListIdentifiers.remove(source.id)
                  }
                })
            )
            .accessibilityIdentifier("saved.capture.list.\(source.id.uuidString)")
          }
        }
      }
      if let reason = destinationLoadingFailure {
        Label(reason, systemImage: "exclamationmark.triangle")
        Button("Try Again") {
          Task { await loadDestinations(identity: destinationLoadIdentity) }
        }
        .accessibilityIdentifier("saved.capture.destinations.retry")
      } else if !destinationsAreReady {
        ProgressView("Loading Lists")
      } else if !selectedListIdentifiers.isSubset(of: availableDestinationIdentifiers) {
        Label(
          "A selected List is no longer available. Review your destinations before adding.",
          systemImage: "exclamationmark.triangle")
        Button("Remove unavailable Lists") {
          selectedListIdentifiers.formIntersection(availableDestinationIdentifiers)
        }
        .accessibilityIdentifier("saved.capture.destinations.removeUnavailable")
      } else if destinationWindow?.matchingCount == 0 {
        Text("New Items will be added to Inbox.").foregroundStyle(.secondary)
      }
    } header: {
      Text("Add to Lists")
    } footer: {
      Text("With no Lists selected, a new Item goes to Inbox. Existing memberships are kept.")
    }
    ForEach(draft.inputIssues, id: \.inputIndex) { issue in
      Section {
        Label(issue.message, systemImage: "exclamationmark.triangle")
        Button("Remove Input") {
          Task {
            isWorking = true
            defer { isWorking = false }
            if let updated = await store.updateCapture(
              draft, edit: .init(removeInputIndexes: [issue.inputIndex]))
            {
              adoptCaptureDraft(updated, replacing: draft)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func mapsPreviewSection(_ draft: PlannerCaptureDraftRead) -> some View {
    let previewLinks = draft.links.filter { $0.kind == .appleMaps || $0.kind == .googleMaps }
    let linksChanged = links.map(\.input) != captureLinkInputs(draft)
    if linksChanged || !previewLinks.isEmpty {
      Section {
        if !linksChanged, previewLinks.count > 1 {
          Picker("Preview link", selection: $selectedPreviewLinkIdentifier) {
            ForEach(previewLinks, id: \.linkId) { previewLink in
              Text(previewLink.label ?? previewLink.originalUrl).tag(Optional(previewLink.linkId))
            }
          }
          .pickerStyle(.menu)
          .accessibilityIdentifier("saved.capture.preview.source")
        }
        if linksChanged {
          Label("Links changed. Refresh to preview the edited links.", systemImage: "map")
          Button("Refresh Preview") { Task { await lookupMaps() } }
            .accessibilityIdentifier("saved.capture.preview.refresh")
        } else if activePreviewRequestIdentifier != nil {
          ProgressView("Loading Maps preview")
            .accessibilityIdentifier("saved.capture.preview.loading")
        } else if draft.preview.linkId == selectedPreviewLinkIdentifier,
          let candidate = draft.preview.candidate
        {
          if let name = candidate.displayName {
            Text(name).font(.headline).accessibilityIdentifier("saved.capture.preview.title")
          }
          if let address = candidate.formattedAddress {
            Label(address, systemImage: "mappin.and.ellipse")
          }
          if candidate.provider == .googleMaps {
            Label("Search preview", systemImage: "magnifyingglass").foregroundStyle(.secondary)
          }
          if let coordinate = candidate.coordinate {
            ItemLocationMap(
              title: candidate.displayName ?? title,
              coordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
              accessibilityIdentifier: "saved.capture.preview.map")
          }
          if let attribution = candidate.attributionText {
            Text(attribution).font(.caption).foregroundStyle(.secondary)
          }
        } else {
          Label(
            draft.preview.state == .unavailable ? "Preview unavailable" : "No Maps preview",
            systemImage: "map"
          )
          .accessibilityIdentifier("saved.capture.preview.unavailable")
          Button("Retry") { Task { await lookupMaps() } }
            .accessibilityIdentifier("saved.capture.preview.retry")
        }
      } header: {
        Text("Maps preview")
      } footer: {
        Text("This preview is temporary. Your own fields and the original link are saved.")
      }
    }
  }

  private func lookupMaps() async {
    guard var draft, !isWorking, !applied else {
      return
    }
    let requestedLinks = links.map(\.input)
    let requestIdentifier = UUID()
    activePreviewRequestIdentifier = requestIdentifier
    defer {
      if activePreviewRequestIdentifier == requestIdentifier {
        activePreviewRequestIdentifier = nil
      }
    }
    if requestedLinks != captureLinkInputs(draft) {
      isWorking = true
      let updated = await store.updateCapture(
        draft, edit: .init(changes: .init(links: .set(requestedLinks))))
      isWorking = false
      guard let updated, self.draft?.generation == draft.generation
      else { return }
      adoptCaptureDraft(updated, replacing: draft)
      draft = updated
      if links.map(\.input) == requestedLinks {
        links = updated.links.map(SavedOwnedLinkDraft.init)
      }
    }
    guard !Task.isCancelled, activePreviewRequestIdentifier == requestIdentifier,
      links.map(\.input) == captureLinkInputs(draft), !applied
    else { return }
    let previewLinks = draft.links.filter { $0.kind == .appleMaps || $0.kind == .googleMaps }
    let linkIdentifier =
      previewLinks.first { $0.linkId == selectedPreviewLinkIdentifier }?.linkId
      ?? previewLinks.first?.linkId
    guard let linkIdentifier else {
      selectedPreviewLinkIdentifier = nil
      return
    }
    if selectedPreviewLinkIdentifier != linkIdentifier {
      selectedPreviewLinkIdentifier = linkIdentifier
      return
    }
    guard let updated = await store.lookupCapture(draft, linkIdentifier: linkIdentifier),
      !Task.isCancelled, activePreviewRequestIdentifier == requestIdentifier,
      selectedPreviewLinkIdentifier == linkIdentifier, self.draft?.draftId == draft.draftId,
      self.draft?.generation == draft.generation, links.map(\.input) == captureLinkInputs(draft),
      !isWorking, !applied
    else { return }
    self.draft = updated
  }

  private func captureLinkInputs(_ draft: PlannerCaptureDraftRead) -> [PlannerLinkInput] {
    draft.links.map {
      PlannerLinkInput(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
    }
  }

  private func adoptCaptureDraft(
    _ updated: PlannerCaptureDraftRead, replacing previous: PlannerCaptureDraftRead
  ) {
    if title == previous.content.title { title = updated.content.title }
    draft = updated
  }

  private var canSave: Bool {
    guard let draft, destinationsAreReady,
      selectedListIdentifiers.isSubset(of: availableDestinationIdentifiers),
      !draft.inputIssues.contains(where: \.blocksSave)
    else {
      return false
    }
    if let reuseIdentifier {
      return draft.reuseCandidates.contains { $0.itemId == reuseIdentifier }
    }
    return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func selectionSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "None" : "\(identifiers.count) selected"
  }

  private var location: PlannerOwnedLocation? {
    let coordinate = draft?.content.location?.coordinate
    let name = optionalText(locationName, original: draft?.content.location?.displayName)
    let address = optionalText(locationAddress, original: draft?.content.location?.formattedAddress)
    if name == nil && address == nil && coordinate == nil { return nil }
    return .init(displayName: name, formattedAddress: address, coordinate: coordinate)
  }

  private func optionalText(_ text: String, original: String?) -> String? {
    if text == (original ?? "") { return original }
    return text.isEmpty ? nil : text
  }

  private func optionalChange<Value: Equatable>(_ value: Value?, original: Value?)
    -> PlannerFieldChange<Value>
  {
    if value == original { return .unchanged }
    if let value { return .set(value) }
    return .clear
  }

  private var destinationLoadIdentity: DestinationLoadIdentity {
    .init(
      namespace: store.devicePreferenceNamespace, revision: store.changeRevision,
      draftIdentifier: draft?.draftId)
  }

  private var destinationsAreReady: Bool {
    loadedDestinationIdentity == destinationLoadIdentity && destinationWindow?.state == .ready
      && captureNamespace != nil && captureNamespace == store.devicePreferenceNamespace
  }

  private var availableDestinationIdentifiers: Set<UUID> {
    guard destinationsAreReady, let destinationWindow else { return [] }
    return Set(
      destinationWindow.rowIdentities.compactMap { identity in
        guard case .source(let source) = identity, source.kind == .list else { return nil }
        return source.id
      })
  }

  private var destinationLoadingFailure: String? {
    if case .failed(let reason) = destinationWindow?.state { return reason }
    return destinationFailure
  }

  private func destinationPreferenceKey(namespace: String) -> String {
    "Planner.capture.\(entryPoint.id).destinations.\(namespace)"
  }

  private func prepare() async {
    guard !isWorking, let namespace = store.devicePreferenceNamespace else { return }
    isWorking = true
    defer { isWorking = false }
    let captureInput: PlannerCaptureInput
    if case .share(let loaded) = entryPoint {
      captureInput = .loaded(loaded)
    } else {
      captureInput = .direct([.text(input)])
    }
    guard let prepared = await store.prepareCapture(input: captureInput), !Task.isCancelled,
      store.devicePreferenceNamespace == namespace
    else { return }
    captureNamespace = namespace
    draft = prepared
    title = prepared.content.title
    subtitle = prepared.content.subtitle ?? ""
    notes = prepared.content.notes ?? ""
    estimate = prepared.content.estimate
    categoryIdentifiers = prepared.content.categoryIds
    tagIdentifiers = prepared.content.tagIds
    locationName = prepared.content.location?.displayName ?? ""
    locationAddress = prepared.content.location?.formattedAddress ?? ""
    links = prepared.links.map(SavedOwnedLinkDraft.init)
    if prepared.reuseCandidates.count == 1 { reuseIdentifier = prepared.reuseCandidates[0].itemId }
    selectedPreviewLinkIdentifier = prepared.preview.linkId
  }

  private func loadDestinations(identity: DestinationLoadIdentity) async {
    guard !Task.isCancelled else { return }
    destinationWindow?.cancel()
    destinationWindow = nil
    loadedDestinationIdentity = nil
    destinationFailure = nil
    guard let draftIdentifier = identity.draftIdentifier else { return }
    guard let namespace = identity.namespace, namespace == captureNamespace,
      let window = store.makeItemWindow()
    else {
      destinationFailure =
        "This capture is unavailable in the current dataset. Close it and try again."
      return
    }
    destinationWindow = window
    await window.reload(
      catalogQuery: .init(sourceKind: .list, archive: .active),
      identity: .init(namespace: namespace, savedRevision: identity.revision))
    guard !Task.isCancelled, destinationLoadIdentity == identity, destinationWindow === window,
      window.state == .ready
    else { return }
    loadedDestinationIdentity = identity
    guard initializedDestinationDraft != draftIdentifier else { return }
    initializedDestinationDraft = draftIdentifier
    selectedListIdentifiers = []
    let available = availableDestinationIdentifiers
    if let identifier = entryPoint.initialListIdentifier, available.contains(identifier) {
      selectedListIdentifiers.insert(identifier)
    }
    let key = destinationPreferenceKey(namespace: namespace)
    if let values = UserDefaults.standard.stringArray(forKey: key) {
      let remembered = Set(values.compactMap(UUID.init(uuidString:)))
      selectedListIdentifiers = remembered.isSubset(of: available) ? remembered : []
    }
  }

  private func save() async {
    guard var draft, !isWorking, !applied, canSave, let namespace = captureNamespace else { return }
    let preferenceKey = destinationPreferenceKey(namespace: namespace)
    isWorking = true
    store.alertMessage = nil
    defer { isWorking = false }
    let previousLinks = draft.links.map {
      PlannerLinkInput(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
    }
    let editedLinks = links.map(\.input)
    let hasContentChanges =
      reuseIdentifier == nil
      && (title != draft.content.title || subtitle != (draft.content.subtitle ?? "")
        || notes != (draft.content.notes ?? "") || estimate != draft.content.estimate
        || location != draft.content.location || categoryIdentifiers != draft.content.categoryIds
        || tagIdentifiers != draft.content.tagIds)
    if hasContentChanges || editedLinks != previousLinks {
      let changes: PlannerItemChanges
      if reuseIdentifier == nil {
        changes = .init(
          title: title == draft.content.title ? .unchanged : .set(title),
          subtitle: optionalChange(
            optionalText(subtitle, original: draft.content.subtitle),
            original: draft.content.subtitle),
          notes: optionalChange(
            optionalText(notes, original: draft.content.notes), original: draft.content.notes),
          location: optionalChange(location, original: draft.content.location),
          estimate: optionalChange(estimate, original: draft.content.estimate),
          links: editedLinks == previousLinks ? .unchanged : .set(editedLinks),
          categoryIds: optionalChange(categoryIdentifiers, original: draft.content.categoryIds),
          tagIds: optionalChange(tagIdentifiers, original: draft.content.tagIds))
      } else {
        changes = .init(links: .set(editedLinks))
      }
      guard
        let updated = await store.updateCapture(
          draft,
          edit: .init(changes: changes))
      else { return }
      adoptCaptureDraft(updated, replacing: draft)
      draft = updated
      links = updated.links.map(SavedOwnedLinkDraft.init)
    }
    guard canSave else { return }
    let choice: PlannerCaptureChoice = reuseIdentifier.map { .reuse(itemId: $0) } ?? .createNew
    guard
      let prepared = await store.reviewCapture(
        draft, choice: choice, listIdentifiers: selectedListIdentifiers)
    else { return }
    guard store.devicePreferenceNamespace == namespace else { return }
    switch await store.applyReviewedChange(prepared, operationIdentifier: operationIdentifier) {
    case .applied(let result):
      applied = true
      if !store.recoveryBlocked, store.alertMessage == nil {
        UserDefaults.standard.set(selectedListIdentifiers.map(\.uuidString), forKey: preferenceKey)
      }
      let source =
        reuseIdentifier.map { PlannerEntityReference(kind: .item, id: $0) }
        ?? result.generated.first { $0.kind == .item }
      if let source { didSave(source) }
      if !store.recoveryBlocked, store.alertMessage == nil { dismiss() }
    case .reviewChanged:
      reviewChanged = true
    case .failed: break
    }
  }
}
