#if os(macOS)
  import MCP
  import PlannerCore

  enum PlannerMCPRowValue {
    static func mapWindow(_ window: PlannerMapRowWindow) -> Value {
      .object([
        "formatVersion": .int(1), "kind": .string("mapRows"),
        "generation": .string(window.generation.uuidString),
        "offset": .string(String(window.offset)),
        "matchingCount": .string(String(window.matchingCount)),
        "collection": window.collection.map(mapCollection) ?? .null,
        "listBranches": .array(
          window.listBranches.map { branch in
            .object([
              "entryId": .string(branch.entryId.uuidString),
              "routePosition": .string(String(branch.routePosition)),
              "list": mapCollection(branch.list), "matchesHeader": .bool(branch.matchesHeader),
              "matchingChildCount": .string(String(branch.matchingChildCount)),
            ])
          }),
        "rows": .array(
          window.rows.map { row in
            .object([
              "identity": identity(row.identity),
              "sourceLifetimeId": .string(row.sourceLifetimeId.uuidString),
              "title": .string(row.title),
              "ownedLocation": row.ownedLocation.map(PlannerMCPSourceTool.locationValue) ?? .null,
              "mapsLinks": .array(row.mapsLinks.map(link)),
              "placement": row.placement.map(mapPlacement) ?? .null,
            ])
          }),
      ])
    }

    private static func mapCollection(_ collection: PlannerMapCollection) -> Value {
      .object([
        "source": .object([
          "kind": .string(collection.source.kind.rawValue),
          "id": .string(collection.source.id.uuidString),
        ]),
        "sourceLifetimeId": .string(collection.sourceLifetimeId.uuidString),
        "title": .string(collection.title),
      ])
    }

    private static func mapPlacement(_ placement: PlannerMapPlacement) -> Value {
      switch placement {
      case .listMembership(let membership, let position):
        return .object([
          "kind": .string("listMembership"), "membershipId": .string(membership.uuidString),
          "childPosition": .string(String(position)),
        ])
      case .itineraryItem(let entry, let position):
        return .object([
          "kind": .string("itineraryItem"), "entryId": .string(entry.uuidString),
          "routePosition": .string(String(position)),
        ])
      case .itineraryListItem(
        let entry, let routePosition, let list, let membership, let childPosition):
        return .object([
          "kind": .string("itineraryListItem"), "entryId": .string(entry.uuidString),
          "routePosition": .string(String(routePosition)), "list": mapCollection(list),
          "membershipId": .string(membership.uuidString),
          "childPosition": .string(String(childPosition)),
        ])
      }
    }

    static func calendarWindow(_ window: PlannerCalendarRowWindow) -> Value {
      .object([
        "formatVersion": .int(1), "kind": .string("calendarRows"),
        "generation": .string(window.generation.uuidString),
        "offset": .string(String(window.offset)),
        "matchingCount": .string(String(window.matchingCount)),
        "rows": .array(
          window.rows.map { entry in
            .object([
              "schedule": .object([
                "kind": .string(entry.schedule.kind.rawValue),
                "id": .string(entry.schedule.id.uuidString),
              ]),
              "source": .object([
                "kind": .string(entry.source.kind.rawValue),
                "id": .string(entry.source.id.uuidString),
              ]),
              "title": .string(entry.title), "form": scheduleForm(entry.form),
            ])
          }),
      ])
    }

    static func presentation(_ context: PlannerRowPresentationContext) -> Value {
      .object([
        "referenceInstant": .double(context.referenceInstant.timeIntervalSinceReferenceDate),
        "displayTimeZone": .string(context.displayTimeZone),
      ])
    }

    static func identity(_ identity: PlannerRowIdentity) -> Value {
      switch identity {
      case .appearance(let source, let appearance):
        return .object([
          "kind": .string("appearance"),
          "source": .object([
            "kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString),
          ]),
          "appearance": PlannerMCPSourceTool.appearanceIdentityValue(appearance),
        ])
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

    static func scheduleForm(_ form: PlannerScheduleForm) -> Value {
      switch form {
      case .allDay(let start, let end):
        return .object([
          "kind": .string("allDay"), "start": civilDate(start), "end": end.map(civilDate) ?? .null,
        ])
      case .timed(let start, let end, let planningTimeZone):
        return .object([
          "kind": .string("timed"),
          "start": .double(start.timeIntervalSinceReferenceDate),
          "end": end.map { .double($0.timeIntervalSinceReferenceDate) } ?? .null,
          "planningTimeZone": .string(planningTimeZone),
        ])
      }
    }

    private static func civilDate(_ date: PlannerCivilDate) -> Value {
      .object(["year": .int(date.year), "month": .int(date.month), "day": .int(date.day)])
    }

    private static func row(_ row: PlannerRowRead) -> Value {
      let schedule: Value
      switch row.scheduleSummary {
      case .none: schedule = .object(["kind": .string("none")])
      case .inScheduledPlan: schedule = .object(["kind": .string("inScheduledPlan")])
      case .directItem(let reference, let owner, let form, let additionalCount),
        .itinerarySpan(let reference, let owner, let form, let additionalCount):
        let kind: String
        if case .itinerarySpan = row.scheduleSummary {
          kind = "itinerarySpan"
        } else {
          kind = "directItem"
        }
        schedule = .object([
          "kind": .string(kind),
          "schedule": .object([
            "kind": .string(reference.kind.rawValue), "id": .string(reference.id.uuidString),
          ]),
          "owner": .object([
            "kind": .string(owner.kind.rawValue), "id": .string(owner.id.uuidString),
          ]),
          "form": scheduleForm(form), "additionalCount": .string(String(additionalCount)),
        ])
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
        "manualEstimate": row.manualEstimate.map { estimate in
          .object([
            "minutes": .string(String(estimate.minutes)),
            "displayUnit": .string(estimate.displayUnit.rawValue),
          ])
        } ?? .null,
        "containerEstimates": row.containerEstimates.map(PlannerMCPSourceTool.estimatesValue)
          ?? .null,
        "globalDone": row.globalDone.map(Value.bool) ?? .null,
        "localDone": row.localDone.map(Value.bool) ?? .null,
        "effectiveDone": row.effectiveDone.map(Value.bool) ?? .null,
        "archived": row.archived.map(Value.bool) ?? .null,
        "hasLocation": .bool(row.hasLocation), "hasLinks": .bool(row.hasLinks),
        "ownedLocation": row.ownedLocation.map(PlannerMCPSourceTool.locationValue) ?? .null,
        "previewLink": row.previewLink.map(link) ?? .null,
        "labels": .array(row.labels.map(PlannerMCPSourceTool.labelValue)),
        "scheduleSummary": schedule,
      ])
    }
  }
#endif
