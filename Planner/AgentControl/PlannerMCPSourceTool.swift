#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPSourceTool {
    static let definition = Tool(
      name: "planner_read",
      description:
        "Read an Item, List, Itinerary, Category, Tag or Schedule source, an exact List/direct/expanded itinerary appearance, or a generation-bound row window from the local Planner prototype.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("request")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "request": .object([
            "oneOf": .array([
              .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("kind"), .string("appearance")]),
                "properties": .object([
                  "kind": .object(["type": .string("string"), "const": .string("appearance")]),
                  "appearance": PlannerMCPAppearance.schema,
                ]),
              ]),
              .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("kind"), .string("source")]),
                "properties": .object([
                  "kind": .object(["type": .string("string"), "const": .string("source")]),
                  "source": .object([
                    "type": .string("object"), "additionalProperties": .bool(false),
                    "required": .array([.string("kind"), .string("id")]),
                    "properties": .object([
                      "kind": .object([
                        "type": .string("string"),
                        "enum": .array([
                          .string("item"), .string("list"), .string("itinerary"),
                          .string("category"), .string("tag"),
                          .string("schedule"),
                        ]),
                      ]),
                      "id": .object(["type": .string("string"), "format": .string("uuid")]),
                    ]),
                  ]),
                ]),
              ]),
              .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([
                  .string("kind"), .string("generation"), .string("offset"), .string("limit"),
                ]),
                "properties": .object([
                  "kind": .object(["type": .string("string"), "const": .string("rows")]),
                  "generation": .object(["type": .string("string"), "format": .string("uuid")]),
                  "offset": .object([
                    "type": .string("string"), "pattern": .string("^(0|[1-9][0-9]*)$"),
                  ]),
                  "limit": .object([
                    "type": .string("string"), "pattern": .string("^[1-9][0-9]*$"),
                  ]),
                ]),
              ]),
            ])
          ]),
        ]),
      ]),
      annotations: .init(
        readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      guard parameters.name == "planner_read" else {
        return failure(
          code: "invalidInput", message: "This read-only prototype does not implement that tool.")
      }
      do {
        let arguments = try object(
          parameters.arguments.map(Value.object), keys: ["formatVersion", "request"], path: "")
        guard arguments["formatVersion"] == .int(1) else {
          throw AdmissionFailure(
            code: "unsupportedVersion", path: "/formatVersion",
            message: "Expected adapter format version 1.")
        }
        let request = try readRequest(arguments["request"])
        let result = await planner.read(session: session, request: request)
        let structured: Value
        switch result {
        case .status:
          return failure(
            code: "forbiddenOperation", message: "Dataset status is a native Planner observation.")
        case .source(.itinerary(let read)):
          structured = .object([
            "formatVersion": .int(1), "kind": .string("source"), "value": itineraryValue(read),
          ])
        case .appearance(let read):
          structured = .object([
            "formatVersion": .int(1), "kind": .string("appearance"),
            "value": appearanceReadValue(read),
          ])
        case .source(.list(let read)):
          structured = .object([
            "formatVersion": .int(1), "kind": .string("source"), "value": listValue(read),
          ])
        case .rows(let window):
          structured = PlannerMCPRowValue.window(window)
        case .failed(let reason):
          return failure(reason)
        case .source(.schedule(let read)):
          structured = .object([
            "formatVersion": .int(1), "kind": .string("source"), "value": scheduleValue(read),
          ])
        case .source(.category(let read)):
          structured = .object([
            "formatVersion": .int(1), "kind": .string("source"), "value": categoryValue(read),
          ])
        case .source(.tag(let read)):
          structured = .object([
            "formatVersion": .int(1), "kind": .string("source"), "value": tagValue(read),
          ])
        case .source(.item(let read)):
          structured = Value.object([
            "formatVersion": .int(1), "kind": .string("source"), "value": sourceValue(read),
          ])
        }
        let serialized = try JSONEncoder().encode(structured)
        return CallTool.Result(
          content: [
            .text(text: String(decoding: serialized, as: UTF8.self), annotations: nil, _meta: nil)
          ],
          structuredContent: Optional.some(structured), isError: false)
      } catch let reason as AdmissionFailure {
        return failure(code: reason.code, message: reason.message, path: reason.path)
      } catch let reason as PlannerMCPAppearance.Failure {
        return failure(code: reason.code, message: reason.message, path: reason.path)
      } catch {
        return failure(code: "unavailable", message: "The Planner read could not be completed.")
      }
    }

    static func failure(code: String, message: String, path: String? = nil) -> CallTool.Result {
      failure(
        .object([
          "code": .string(code), "propertyPath": path.map(Value.string) ?? .null,
          "message": .string(message), "details": .null,
        ]), message: message)
    }

    static func failure(_ reason: PlannerFailure) -> CallTool.Result {
      failure(PlannerMCPFailureValue.encode(reason), message: reason.message)
    }

    private static func failure(_ reason: Value, message: String) -> CallTool.Result {
      CallTool.Result(
        content: [.text(text: message, annotations: nil, _meta: nil)],
        structuredContent: .object([
          "formatVersion": .int(1), "state": .string("failed"),
          "reason": reason,
        ]), isError: true)
    }

    private static func readRequest(_ value: Value?) throws -> PlannerReadRequest {
      guard case .object(let fields) = value else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/request", message: "Expected an object.")
      }
      switch fields["kind"] {
      case .string("appearance"):
        let request = try object(value, keys: ["kind", "appearance"], path: "/request")
        return .appearance(
          try PlannerMCPAppearance.decode(request["appearance"], path: "/request/appearance"))
      case .string("source"):
        let request = try object(value, keys: ["kind", "source"], path: "/request")
        let source = try object(request["source"], keys: ["kind", "id"], path: "/request/source")
        guard case .string(let spelling) = source["kind"],
          let sourceKind = PlannerEntityKind(rawValue: spelling),
          [.item, .list, .itinerary, .category, .tag, .schedule].contains(sourceKind)
        else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/request/source/kind",
            message:
              "This prototype supports Item, List, Itinerary, Category, Tag and Schedule sources.")
        }
        return .source(
          PlannerEntityReference(
            kind: sourceKind, id: try identifier(source["id"], path: "/request/source/id")))
      case .string("rows"):
        let request = try object(
          value, keys: ["kind", "generation", "offset", "limit"], path: "/request")
        return .rows(
          generation: try identifier(request["generation"], path: "/request/generation"),
          offset: try count(request["offset"], minimum: 0, path: "/request/offset"),
          limit: try count(request["limit"], minimum: 1, path: "/request/limit"))
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/request/kind",
          message: "Expected source, appearance or rows.")
      }
    }

    private static func scheduleValue(_ read: PlannerScheduleSourceRead) -> Value {
      .object([
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": .object([
          "source": .object([
            "kind": .string(read.content.source.kind.rawValue),
            "id": .string(read.content.source.id.uuidString),
          ]),
          "form": PlannerMCPRowValue.scheduleForm(read.content.form),
        ]),
        "createdAt": .null, "updatedAt": .null,
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
        "state": .object(["globalDone": .null, "archived": .null]),
        "labels": .array([]), "references": .array([]),
        "progress": .null, "estimates": .null,
      ])
    }

    private static func identifier(_ value: Value?, path: String) throws -> UUID {
      guard case .string(let spelling) = value, let identity = UUID(uuidString: spelling) else {
        throw AdmissionFailure(
          code: "invalidInput", path: path, message: "Expected a Planner UUID.")
      }
      return identity
    }

    private static func count(_ value: Value?, minimum: Int64, path: String) throws -> Int64 {
      guard case .string(let spelling) = value, let count = Int64(spelling),
        String(count) == spelling, count >= minimum
      else {
        throw AdmissionFailure(
          code: "invalidInput", path: path,
          message: "Expected a canonical decimal Int64 with minimum \(minimum).")
      }
      return count
    }

    private static func object(_ value: Value?, keys: Set<String>, path: String) throws -> [String:
      Value]
    {
      guard case .object(let fields) = value else {
        throw AdmissionFailure(code: "invalidInput", path: path, message: "Expected an object.")
      }
      if let unknown = Set(fields.keys).subtracting(keys).sorted().first {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw AdmissionFailure(
          code: "unknownField", path: path + "/" + escaped, message: "Unknown property: \(unknown)."
        )
      }
      if let missing = keys.subtracting(fields.keys).sorted().first {
        throw AdmissionFailure(
          code: "invalidInput", path: path + "/" + missing,
          message: "Required property is missing: \(missing).")
      }
      return fields
    }

    private static func categoryValue(_ read: PlannerCategorySourceRead) -> Value {
      .object([
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": .object([
          "name": .string(read.content.name), "color": read.content.color.map(colorValue) ?? .null,
          "iconName": read.content.iconName.map(Value.string) ?? .null,
        ]),
        "createdAt": .double(read.createdAt.timeIntervalSinceReferenceDate),
        "updatedAt": .double(read.updatedAt.timeIntervalSinceReferenceDate),
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
        "state": .object(["globalDone": .null, "archived": .null]),
        "labels": .array([]), "references": .array(read.references.map(referenceValue)),
        "progress": .null, "estimates": .null,
      ])
    }

    private static func tagValue(_ read: PlannerTagSourceRead) -> Value {
      .object([
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": .object([
          "name": .string(read.content.name), "color": read.content.color.map(colorValue) ?? .null,
          "iconName": read.content.iconName.map(Value.string) ?? .null,
        ]),
        "createdAt": .double(read.createdAt.timeIntervalSinceReferenceDate),
        "updatedAt": .double(read.updatedAt.timeIntervalSinceReferenceDate),
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
        "state": .object(["globalDone": .null, "archived": .null]),
        "labels": .array([]), "references": .array(read.references.map(referenceValue)),
        "progress": .null, "estimates": .null,
      ])
    }

    private static func itineraryValue(_ read: PlannerItinerarySourceRead) -> Value {
      .object([
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": .object([
          "title": .string(read.content.title),
          "notes": read.content.notes.map(Value.string) ?? .null,
          "color": read.content.color.map(colorValue) ?? .null,
          "iconName": read.content.iconName.map(Value.string) ?? .null,
          "location": read.content.location.map(locationValue) ?? .null,
          "manualEstimate": read.content.manualEstimate.map(estimateValue) ?? .null,
          "links": .array(read.content.links.map(PlannerMCPRowValue.link)),
          "categoryIds": .array(
            read.content.categoryIds.sorted { $0.uuidString < $1.uuidString }.map {
              .string($0.uuidString)
            }),
          "tagIds": .array(
            read.content.tagIds.sorted { $0.uuidString < $1.uuidString }.map {
              .string($0.uuidString)
            }),
        ]),
        "createdAt": .double(read.createdAt.timeIntervalSinceReferenceDate),
        "updatedAt": .double(read.updatedAt.timeIntervalSinceReferenceDate),
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
        "state": .object([
          "globalDone": read.state.globalDone.map(Value.bool) ?? .null,
          "archived": read.state.archived.map(Value.bool) ?? .null,
        ]),
        "labels": .array(read.labels.map(labelValue)),
        "references": .array(read.references.map(referenceValue)),
        "progress": progressValue(read.progress),
        "estimates": estimatesValue(read.estimates),
      ])
    }

    private static func listValue(_ read: PlannerListSourceRead) -> Value {
      .object([
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": .object([
          "name": .string(read.content.name),
          "notes": read.content.notes.map(Value.string) ?? .null,
          "color": read.content.color.map(colorValue) ?? .null,
          "iconName": read.content.iconName.map(Value.string) ?? .null,
          "manualEstimate": read.content.manualEstimate.map(estimateValue) ?? .null,
        ]),
        "createdAt": .double(read.createdAt.timeIntervalSinceReferenceDate),
        "updatedAt": .double(read.updatedAt.timeIntervalSinceReferenceDate),
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
        "state": .object([
          "globalDone": read.state.globalDone.map(Value.bool) ?? .null,
          "archived": read.state.archived.map(Value.bool) ?? .null,
        ]),
        "labels": .array([]), "references": .array(read.references.map(referenceValue)),
        "progress": progressValue(read.progress),
        "estimates": estimatesValue(read.estimates),
      ])
    }

    static func estimateValue(_ estimate: PlannerEstimate) -> Value {
      .object([
        "minutes": .string(String(estimate.minutes)),
        "displayUnit": .string(estimate.displayUnit.rawValue),
      ])
    }

    static func progressValue(_ progress: PlannerContainerProgress) -> Value {
      .object([
        "container": .object([
          "kind": .string(progress.container.kind.rawValue),
          "id": .string(progress.container.id.uuidString),
        ]),
        "state": .string(progress.state.rawValue),
        "doneCount": progress.doneCount.map { .string(String($0)) } ?? .null,
        "archivedCount": progress.archivedCount.map { .string(String($0)) } ?? .null,
        "finishedCount": progress.finishedCount.map { .string(String($0)) } ?? .null,
        "totalCount": progress.totalCount.map { .string(String($0)) } ?? .null,
      ])
    }

    private static func estimatesValue(_ estimates: PlannerContainerEstimates) -> Value {
      .object([
        "calculatedEstimate": durationTotalValue(estimates.calculatedEstimate),
        "fullEstimate": durationTotalValue(estimates.fullEstimate),
        "remainingEstimate": durationTotalValue(estimates.remainingEstimate),
        "completedExceedsTotal": .bool(estimates.completedExceedsTotal),
      ])
    }

    private static func durationTotalValue(_ total: PlannerDurationTotal) -> Value {
      switch total {
      case .exact(let minutes):
        .object(["kind": .string("exact"), "minutes": .string(String(minutes))])
      case .lowerBound(let minutes, let missingEstimateCount):
        .object([
          "kind": .string("lowerBound"), "minutes": .string(String(minutes)),
          "missingEstimateCount": .string(String(missingEstimateCount)),
        ])
      case .upperBound(let minutes, let missingFinishedEstimateCount):
        .object([
          "kind": .string("upperBound"), "minutes": .string(String(minutes)),
          "missingFinishedEstimateCount": .string(String(missingFinishedEstimateCount)),
        ])
      case .unavailable:
        .object(["kind": .string("unavailable")])
      }
    }

    static func colorValue(_ color: PlannerColor) -> Value {
      .object([
        "red": .double(color.red), "green": .double(color.green), "blue": .double(color.blue),
        "alpha": .double(color.alpha),
      ])
    }

    private static func itemContentValue(_ content: PlannerItemContent) -> Value {
      return .object([
        "title": .string(content.title),
        "subtitle": content.subtitle.map(Value.string) ?? .null,
        "notes": content.notes.map(Value.string) ?? .null,
        "location": content.location.map(locationValue) ?? .null,
        "estimate": content.estimate.map { estimate in
          .object([
            "minutes": .string(String(estimate.minutes)),
            "displayUnit": .string(estimate.displayUnit.rawValue),
          ])
        } ?? .null,
        "links": .array(content.links.map(PlannerMCPRowValue.link)),
        "categoryIds": .array(
          content.categoryIds.sorted { $0.uuidString < $1.uuidString }.map {
            .string($0.uuidString)
          }),
        "tagIds": .array(
          content.tagIds.sorted { $0.uuidString < $1.uuidString }.map { .string($0.uuidString) }),
      ])
    }

    static func appearanceIdentityValue(_ appearance: PlannerAppearance) -> Value {
      switch appearance {
      case .expandedListItem(let itineraryId, let listEntryId, let membershipId):
        return .object([
          "kind": .string("expandedListItem"), "itineraryId": .string(itineraryId.uuidString),
          "listEntryId": .string(listEntryId.uuidString),
          "membershipId": .string(membershipId.uuidString),
        ])
      case .directItineraryItem(let itineraryId, let entryId):
        return .object([
          "kind": .string("directItineraryItem"), "itineraryId": .string(itineraryId.uuidString),
          "entryId": .string(entryId.uuidString),
        ])
      case .listMembership(let listId, let membershipId):
        return .object([
          "kind": .string("listMembership"), "listId": .string(listId.uuidString),
          "membershipId": .string(membershipId.uuidString),
        ])
      }
    }

    private static func appearanceReadValue(_ read: PlannerAppearanceRead) -> Value {
      .object([
        "appearance": appearanceIdentityValue(read.appearance),
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": itemContentValue(read.content),
        "labels": .array(read.labels.map(labelValue)),
        "globalDone": .bool(read.globalDone), "localDone": .bool(read.localDone),
        "effectiveDone": .bool(read.effectiveDone), "archived": .bool(read.archived),
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
      ])
    }

    private static func sourceValue(_ read: PlannerItemSourceRead) -> Value {
      .object([
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": itemContentValue(read.content),
        "createdAt": .double(read.createdAt.timeIntervalSinceReferenceDate),
        "updatedAt": .double(read.updatedAt.timeIntervalSinceReferenceDate),
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
        "state": .object([
          "globalDone": read.state.globalDone.map(Value.bool) ?? .null,
          "archived": read.state.archived.map(Value.bool) ?? .null,
        ]),
        "labels": .array(read.labels.map(labelValue)),
        "references": .array(read.references.map(referenceValue)),
        "progress": .null, "estimates": .null,
      ])
    }

    static func labelValue(_ label: PlannerLabelRead) -> Value {
      .object([
        "reference": .object([
          "kind": .string(label.reference.kind.rawValue),
          "id": .string(label.reference.id.uuidString),
        ]),
        "name": .string(label.name), "color": label.color.map(colorValue) ?? .null,
        "iconName": label.iconName.map(Value.string) ?? .null,
      ])
    }

    static func appliedIdentityValue(_ identity: PlannerAppliedIdentity) -> Value {
      switch identity {
      case .source(let source):
        return .object(["kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString)])
      case .reference(let reference): return referenceValue(reference)
      }
    }

    static func referenceValue(_ reference: PlannerReferenceRead) -> Value {
      switch reference {
      case .expandedCompletion(let itineraryId, let listEntryId, let membershipId):
        return .object([
          "kind": .string("expandedCompletion"),
          "appearance": appearanceIdentityValue(
            .expandedListItem(
              itineraryId: itineraryId, listEntryId: listEntryId, membershipId: membershipId)),
        ])
      case .itineraryEntry(let identifier, let itinerary, let source):
        return .object([
          "kind": .string("itineraryEntry"), "id": .string(identifier.uuidString),
          "owner": .object(["kind": .string("itinerary"), "id": .string(itinerary.id.uuidString)]),
          "source": .object([
            "kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString),
          ]),
          "appearance": source.kind == .item
            ? appearanceIdentityValue(
              .directItineraryItem(itineraryId: itinerary.id, entryId: identifier)) : .null,
        ])
      case .membership(let identifier, let list, let item):
        return .object([
          "kind": .string("membership"), "id": .string(identifier.uuidString),
          "owner": .object(["kind": .string(list.kind.rawValue), "id": .string(list.id.uuidString)]
          ),
          "source": .object([
            "kind": .string(item.kind.rawValue), "id": .string(item.id.uuidString),
          ]),
          "appearance": .object([
            "kind": .string("listMembership"), "listId": .string(list.id.uuidString),
            "membershipId": .string(identifier.uuidString),
          ]),
        ])
      case .labelAssociation(let identifier, let owner, let label):
        return .object([
          "kind": .string("labelAssociation"), "id": .string(identifier.uuidString),
          "owner": .object([
            "kind": .string(owner.kind.rawValue), "id": .string(owner.id.uuidString),
          ]),
          "source": .object([
            "kind": .string(label.kind.rawValue), "id": .string(label.id.uuidString),
          ]),
          "appearance": .null,
        ])
      case .ownedLink(let identifier, let owner):
        return .object([
          "kind": .string("ownedLink"), "id": .string(identifier.uuidString),
          "owner": .object([
            "kind": .string(owner.kind.rawValue), "id": .string(owner.id.uuidString),
          ]),
          "source": .null, "appearance": .null,
        ])
      case .schedule(let identifier, let source):
        return .object([
          "kind": .string("schedule"), "id": .string(identifier.uuidString), "owner": .null,
          "source": .object([
            "kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString),
          ]),
          "appearance": .null,
        ])
      }
    }

    static func locationValue(_ location: PlannerOwnedLocation) -> Value {
      .object([
        "displayName": location.displayName.map(Value.string) ?? .null,
        "formattedAddress": location.formattedAddress.map(Value.string) ?? .null,
        "coordinate": location.coordinate.map {
          .object(["latitude": .double($0.latitude), "longitude": .double($0.longitude)])
        } ?? .null,
      ])
    }

    private struct AdmissionFailure: Error {
      let code: String
      let path: String
      let message: String
    }
  }
#endif
