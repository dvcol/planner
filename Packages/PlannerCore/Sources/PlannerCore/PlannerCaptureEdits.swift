import Foundation

func plannerEditCapture(
  _ draft: PlannerPreparedCapture, edit: PlannerCaptureEdit, items: [ItemSnapshot]
) throws -> PlannerPreparedCapture {
  let fields: [PlannerItemField]
  if edit.changes.hasChanges {
    fields = try edit.changes.validatedFields()
  } else {
    fields = []
  }
  guard !fields.isEmpty || !edit.removeInputIndexes.isEmpty || !edit.retryInputIndexes.isEmpty
  else {
    throw PlannerFailure(
      "invalidInput", "A capture edit must change a field or an input.", propertyPath: "/changes")
  }
  let availableIndexes = Set(draft.retainedInputs.map(\.inputIndex))
  guard edit.removeInputIndexes.isSubset(of: availableIndexes) else {
    throw PlannerFailure(
      "invalidInput", "A removed input must belong to this draft.",
      propertyPath: "/removeInputIndexes")
  }
  guard edit.retryInputIndexes.isSubset(of: availableIndexes) else {
    throw PlannerFailure(
      "invalidInput", "A retried input must belong to this draft.",
      propertyPath: "/retryInputIndexes")
  }
  guard edit.removeInputIndexes.isDisjoint(with: edit.retryInputIndexes) else {
    throw PlannerFailure(
      "invalidInput", "An input cannot be removed and retried in the same edit.",
      propertyPath: "/retryInputIndexes")
  }
  guard
    !draft.retainedInputs.contains(where: {
      edit.retryInputIndexes.contains($0.inputIndex) && $0.input == nil
    })
  else {
    throw PlannerFailure(
      "captureInputFailure",
      "This input was not retained. Prepare it again or remove it from the draft.",
      propertyPath: "/retryInputIndexes")
  }
  var read = draft.read
  var origins = draft.contentOrigins
  var retainedInputs = draft.retainedInputs
  if !edit.removeInputIndexes.isEmpty || !edit.retryInputIndexes.isEmpty {
    let preparation = try plannerPrepareCaptureInputs(
      retainedInputs.filter { !edit.removeInputIndexes.contains($0.inputIndex) }, items: items)
    read = preparation.read
    origins = preparation.contentOrigins
    retainedInputs = preparation.retainedInputs
  }
  var overrides = plannerMergeCaptureChanges(draft.overrides, edit.changes)
  let changed = try overrides.applyingChanges(to: read.content)
  let links: [PlannerCaptureDraftLink]
  if case .set(let values) = overrides.links {
    links = try plannerCaptureEditedLinks(values, previous: draft.read.links)
    overrides = plannerMergeCaptureChanges(
      overrides,
      .init(
        links: .set(
          links.map { .init(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label) })))
  } else {
    links = read.links.map { link in
      draft.read.links.first { $0.originalUrl == link.originalUrl } ?? link
    }
  }
  var title = changed.title
  if overrides.title.isUnchanged && (origins["title"] == "appFallback" || title.isEmpty) {
    title = ""
    origins["title"] = "independent"
    if !links.isEmpty {
      title = "Saved link"
      origins["title"] = "appFallback"
    }
  }
  let content = PlannerItemContentInput(
    title: title, subtitle: changed.subtitle, notes: changed.notes,
    location: changed.location, estimate: changed.estimate,
    links: links.map { .init(originalUrl: $0.originalUrl, label: $0.label) },
    categoryIds: changed.categoryIds, tagIds: changed.tagIds)
  let updated = PlannerCaptureDraftRead(
    draftId: draft.read.draftId, generation: UUID(), content: content, links: links,
    inputIssues: read.inputIssues,
    preview: .init(
      state: .notRequested,
      linkId: links.first { $0.kind == .appleMaps || $0.kind == .googleMaps }?.linkId,
      candidate: nil),
    reuseCandidates: plannerCaptureReuseCandidates(
      originals: Set(links.map(\.originalUrl)), items: items),
    saveAllowed: !read.inputIssues.contains(where: \.blocksSave) && (try? content.validate()) != nil
  )
  var independent = ["title": "independent"]
  if content.subtitle != nil { independent["subtitle"] = "independent" }
  if content.notes != nil { independent["notes"] = "independent" }
  if content.location != nil { independent["location"] = "independent" }
  var overriddenFields: [PlannerItemField] = []
  if overrides.hasChanges { overriddenFields = try overrides.validatedFields() }
  origins =
    plannerEditedContentOrigins(
      origins, editedFields: Set(overriddenFields.map(\.rawValue)), independent: independent)
    ?? independent
  return .init(
    session: draft.session, read: updated, contentOrigins: origins,
    retainedInputs: retainedInputs, overrides: overrides)
}

private func plannerCaptureEditedLinks(
  _ inputs: [PlannerLinkInput], previous: [PlannerCaptureDraftLink]
) throws -> [PlannerCaptureDraftLink] {
  var links: [PlannerCaptureDraftLink] = []
  var originals = Set<String>()
  for (index, input) in inputs.enumerated() {
    var retained: PlannerCaptureDraftLink?
    if let identifier = input.linkId {
      guard let existing = previous.first(where: { $0.linkId == identifier }) else {
        throw PlannerFailure(
          "invalidInput", "A retained link must belong to this capture draft.",
          propertyPath: "/changes/links/\(index)/linkId")
      }
      retained = existing
    }
    guard originals.insert(input.originalUrl).inserted else { continue }
    guard originals.count <= PlannerCaptureLimits.maximumDistinctLinks else {
      throw PlannerFailure(
        "captureInputFailure", "A capture draft can retain at most 128 distinct links.",
        propertyPath: "/changes/links")
    }
    var providerReference: PlannerProviderReference?
    if retained?.originalUrl == input.originalUrl {
      providerReference = retained?.providerReference
    }
    links.append(
      .init(
        linkId: retained?.linkId ?? UUID(), originalUrl: input.originalUrl, label: input.label,
        kind: try input.validatedKind(propertyPath: "/changes/links/\(index)"),
        providerReference: providerReference))
  }
  return links
}

private func plannerMergeCaptureChanges(
  _ previous: PlannerItemChanges, _ incoming: PlannerItemChanges
) -> PlannerItemChanges {
  .init(
    title: incoming.title.preserving(previous.title),
    subtitle: incoming.subtitle.preserving(previous.subtitle),
    notes: incoming.notes.preserving(previous.notes),
    location: incoming.location.preserving(previous.location),
    estimate: incoming.estimate.preserving(previous.estimate),
    links: incoming.links.preserving(previous.links),
    categoryIds: incoming.categoryIds.preserving(previous.categoryIds),
    tagIds: incoming.tagIds.preserving(previous.tagIds))
}

extension PlannerFieldChange {
  fileprivate func preserving(_ previous: Self) -> Self {
    if isUnchanged { return previous }
    return self
  }
}

extension PlannerItemChanges {
  fileprivate var hasChanges: Bool {
    !title.isUnchanged || !subtitle.isUnchanged || !notes.isUnchanged || !location.isUnchanged
      || !estimate.isUnchanged || !links.isUnchanged || !categoryIds.isUnchanged
      || !tagIds.isUnchanged
  }
}
