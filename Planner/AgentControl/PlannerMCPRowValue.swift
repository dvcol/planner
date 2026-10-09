#if os(macOS)
  import MCP
  import PlannerCore

  enum PlannerMCPRowValue {
    static func presentation(_ context: PlannerRowPresentationContext) -> Value {
      .object([
        "referenceInstant": .double(context.referenceInstant.timeIntervalSinceReferenceDate),
        "displayTimeZone": .string(context.displayTimeZone),
      ])
    }

    static func identity(_ identity: PlannerRowIdentity) -> Value {
      switch identity {
      case .source(let source):
        return .object([
          "kind": .string("source"),
          "source": .object([
            "kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString),
          ]),
        ])
      }
    }

    static func window(_ window: PlannerRowWindow) -> Value {
      .object([
        "formatVersion": .int(1), "kind": .string("rows"),
        "generation": .string(window.generation.uuidString),
        "offset": .string(String(window.offset)),
        "matchingCount": .string(String(window.matchingCount)),
        "rowPresentation": window.rowPresentation.map(presentation) ?? .null,
        "rows": .array(window.rows.map(row)),
      ])
    }

    static func link(_ link: PlannerOwnedLinkRead) -> Value {
      .object([
        "linkId": .string(link.linkId.uuidString), "originalUrl": .string(link.originalUrl),
        "label": link.label.map(Value.string) ?? .null, "kind": .string(link.kind.rawValue),
        "providerReference": link.providerReference.map { reference in
          .object(["kind": .string(reference.kind.rawValue), "value": .string(reference.value)])
        } ?? .null,
      ])
    }

    private static func row(_ row: PlannerRowRead) -> Value {
      let schedule: Value
      switch row.scheduleSummary {
      case .none: schedule = .object(["kind": .string("none")])
      }
      return .object([
        "identity": identity(row.identity), "title": .string(row.title),
        "subtitle": row.subtitle.map(Value.string) ?? .null,
        "estimate": row.estimate.map { estimate in
          .object([
            "minutes": .string(String(estimate.minutes)),
            "displayUnit": .string(estimate.displayUnit.rawValue),
          ])
        } ?? .null,
        "globalDone": row.globalDone.map(Value.bool) ?? .null,
        "localDone": row.localDone.map(Value.bool) ?? .null,
        "effectiveDone": row.effectiveDone.map(Value.bool) ?? .null,
        "archived": row.archived.map(Value.bool) ?? .null,
        "hasLocation": .bool(row.hasLocation), "hasLinks": .bool(row.hasLinks),
        "ownedLocation": row.ownedLocation.map(PlannerMCPSourceTool.locationValue) ?? .null,
        "previewLink": row.previewLink.map(link) ?? .null,
        "scheduleSummary": schedule,
      ])
    }
  }
#endif
