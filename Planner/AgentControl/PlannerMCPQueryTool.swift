#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPQueryTool {
    private static let civilDateSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("year"), .string("month"), .string("day")]),
      "properties": .object([
        "year": .object(["type": .string("integer")]),
        "month": .object(["type": .string("integer")]),
        "day": .object(["type": .string("integer")]),
      ]),
    ])

    private static let calendarQuerySchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([
        .string("kind"), .string("startDay"), .string("endDay"), .string("displayTimeZone"),
      ]),
      "properties": .object([
        "kind": .object(["type": .string("string"), "const": .string("calendar")]),
        "startDay": civilDateSchema, "endDay": civilDateSchema,
        "displayTimeZone": .object(["type": .string("string")]),
      ]),
    ])

    private static let itemQuerySchema: Value = .object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("kind"), .string("scope")]),
      "properties": .object([
        "kind": .object(["type": .string("string"), "const": .string("items")]),
        "text": .object(["type": .string("string")]),
        "categories": identityGroupSchema,
        "tags": identityGroupSchema,
        "lists": identityGroupSchema,
        "hasAddress": .object(["type": .string("boolean"), "default": .bool(false)]),
        "hasLinks": .object(["type": .string("boolean"), "default": .bool(false)]),
        "scheduled": .object([
          "type": .string("string"),
          "enum": .array([.string("scheduled"), .string("unscheduled"), .string("all")]),
          "default": .string("all"),
          "description": .string(
            "Any retained direct or reachable itinerary assignment, including past dates; independent of completion/archive."
          ),
        ]),
        "duration": .object([
          "oneOf": .array([
            .object(["type": .string("null")]),
            .object([
              "type": .string("object"), "additionalProperties": .bool(false),
              "required": .array([
                .string("minimumMinutes"), .string("maximumMinutes"), .string("includeUnknown"),
              ]),
              "properties": .object([
                "minimumMinutes": durationBoundSchema, "maximumMinutes": durationBoundSchema,
                "includeUnknown": .object(["type": .string("boolean")]),
              ]),
            ]),
          ])
        ]),
        "scope": .object([
          "oneOf": .array([
            .object([
              "type": .string("object"), "additionalProperties": .bool(false),
              "required": .array([.string("kind")]),
              "properties": .object([
                "kind": .object([
                  "type": .string("string"),
                  "enum": .array([.string("global"), .string("inbox")]),
                ])
              ]),
            ]),
            .object([
              "type": .string("object"), "additionalProperties": .bool(false),
              "required": .array([.string("kind"), .string("listId")]),
              "properties": .object([
                "kind": .object(["type": .string("string"), "const": .string("list")]),
                "listId": .object(["type": .string("string"), "format": .string("uuid")]),
              ]),
            ]),
            .object([
              "type": .string("object"), "additionalProperties": .bool(false),
              "required": .array([.string("kind"), .string("itineraryId")]),
              "properties": .object([
                "kind": .object(["type": .string("string"), "const": .string("itinerary")]),
                "itineraryId": .object(["type": .string("string"), "format": .string("uuid")]),
              ]),
            ]),
          ])
        ]),
        "sort": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("mode"), .string("direction")]),
          "properties": .object([
            "mode": .object([
              "type": .string("string"),
              "enum": .array([
                .string("title"), .string("created"), .string("lastUpdated"), .string("duration"),
                .string("manual"),
              ]),
            ]),
            "direction": .object([
              "type": .string("string"),
              "enum": .array([.string("ascending"), .string("descending")]),
            ]),
          ]),
        ]),
        "rowPresentation": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("referenceInstant"), .string("displayTimeZone")]),
          "properties": .object([
            "referenceInstant": .object(["type": .string("number")]),
            "displayTimeZone": .object(["type": .string("string")]),
          ]),
        ]),
        "completion": .object([
          "type": .string("string"),
          "enum": .array([.string("todo"), .string("done"), .string("all")]),
        ]),
        "archive": .object([
          "type": .string("string"),
          "enum": .array([.string("active"), .string("archived"), .string("all")]),
        ]),
      ]),
    ])

    private static let identityGroupSchema: Value = .object([
      "oneOf": .array([
        .object(["type": .string("null")]),
        .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("ids")]),
          "properties": .object([
            "ids": .object([
              "type": .string("array"),
              "items": .object(["type": .string("string"), "format": .string("uuid")]),
            ]),
            "match": .object([
              "type": .string("string"), "enum": .array([.string("any"), .string("all")]),
              "default": .string("any"),
            ]),
          ]),
        ]),
      ])
    ])

    private static let durationBoundSchema: Value = .object([
      "type": .array([.string("string"), .string("null")]),
      "pattern": .string("^(0|[1-9][0-9]*)$"),
      "description": .string(
        "Nonnegative canonical decimal Int64 minutes, at most 9223372036854775807; null is unbounded."
      ),
    ])

    private static let catalogQuerySchema: Value = .object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("kind"), .string("sourceKind")]),
      "properties": .object([
        "kind": .object(["type": .string("string"), "const": .string("catalog")]),
        "sourceKind": .object([
          "type": .string("string"), "enum": .array([.string("list"), .string("itinerary")]),
        ]),
        "text": .object(["type": .string("string")]),
        "archive": .object([
          "type": .string("string"),
          "enum": .array([.string("active"), .string("archived"), .string("all")]),
        ]),
      ]),
    ])

    private static let labelCatalogQuerySchema: Value = .object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("kind"), .string("sourceKind"), .string("archive")]),
      "properties": .object([
        "kind": .object(["type": .string("string"), "const": .string("catalog")]),
        "sourceKind": .object([
          "type": .string("string"), "enum": .array([.string("category"), .string("tag")]),
        ]),
        "text": .object(["type": .string("string")]),
        "archive": .object(["type": .string("string"), "const": .string("all")]),
      ]),
    ])

    private static let scheduleCatalogQuerySchema: Value = .object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("kind"), .string("sourceKind"), .string("archive")]),
      "properties": .object([
        "kind": .object(["type": .string("string"), "const": .string("catalog")]),
        "sourceKind": .object(["type": .string("string"), "const": .string("schedule")]),
        "text": .object(["type": .string("string"), "const": .string("")]),
        "archive": .object(["type": .string("string"), "const": .string("all")]),
      ]),
    ])

    static let definition = Tool(
      name: "planner_query",
      description:
        "Discover Item or exact List/Itinerary appearance identities, List/Itinerary title catalogs, shared labels and source-bound Schedule identities in the local Planner prototype. Calendar queries use inclusive Gregorian days and a display timezone, returning matching Schedule identities in UUID order; read their forms/live owners with calendarRows. Schedule catalogs require empty text and archive all; their order is UUID ascending. Filters narrow cumulatively; contextual progress includes hidden/archived appearances. Explicit ascending Manual preserves saved List/Itinerary order; omitted sort is alphabetical. Read rows through their issued generation.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("query")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "query": .object([
            "oneOf": .array([
              itemQuerySchema, catalogQuerySchema, labelCatalogQuerySchema,
              scheduleCatalogQuerySchema, calendarQuerySchema,
            ])
          ]),
        ]),
      ]),
      annotations: .init(
        readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false))

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      do {
        let arguments = try object(
          parameters.arguments.map(Value.object), allowed: ["formatVersion", "query"],
          required: ["formatVersion", "query"], path: "")
        guard arguments["formatVersion"] == .int(1) else {
          throw AdmissionFailure(
            code: "unsupportedVersion", path: "/formatVersion",
            message: "Expected adapter format version 1.")
        }
        let request = try queryRequest(arguments["query"])
        let queried = await planner.query(PlannerQuery(session: session, request: request))
        switch queried {
        case .failed(let reason):
          return PlannerMCPSourceTool.failure(reason)
        case .snapshot(let snapshot):
          let value = Value.object([
            "formatVersion": .int(1), "generation": .string(snapshot.generation.uuidString),
            "matchingCount": .string(String(snapshot.matchingCount)),
            "rows": .array(snapshot.rows.map(PlannerMCPRowValue.identity)),
            "rowPresentation": snapshot.rowPresentation.map(PlannerMCPRowValue.presentation)
              ?? .null,
            "unresolvedReferences": .array(
              snapshot.unresolvedReferences.map(PlannerMCPSourceTool.referenceValue)),
            "progress": .array(snapshot.progress.map(PlannerMCPSourceTool.progressValue)),
          ])
          let serialized = try JSONEncoder().encode(value)
          return CallTool.Result(
            content: [
              .text(text: String(decoding: serialized, as: UTF8.self), annotations: nil, _meta: nil)
            ],
            structuredContent: Optional.some(value), isError: false)
        }
      } catch let failure as AdmissionFailure {
        return PlannerMCPSourceTool.failure(
          code: failure.code, message: failure.message, path: failure.path)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "unavailable", message: "The Planner query could not be completed.")
      }
    }

    private static func queryRequest(_ value: Value?) throws -> PlannerQueryRequest {
      if case .object(let fields) = value, fields["kind"] == .string("calendar") {
        let query = try object(
          value, allowed: ["kind", "startDay", "endDay", "displayTimeZone"],
          required: ["kind", "startDay", "endDay", "displayTimeZone"], path: "/query")
        guard case .string(let timeZone) = query["displayTimeZone"] else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/displayTimeZone",
            message: "Expected a display timezone String.")
        }
        return .calendar(
          .init(
            startDay: try civilDate(query["startDay"], path: "/query/startDay"),
            endDay: try civilDate(query["endDay"], path: "/query/endDay"),
            displayTimeZone: timeZone))
      }
      let query = try object(
        value,
        allowed: [
          "kind", "scope", "sourceKind", "text", "completion", "archive", "categories", "tags",
          "lists",
          "duration", "scheduled", "hasAddress", "hasLinks", "sort", "rowPresentation",
        ], required: ["kind"], path: "/query")
      if query["kind"] == .string("catalog") {
        return .catalog(try catalog(value))
      }
      guard query["kind"] == .string("items") else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/kind", message: "Expected items, catalog or calendar."
        )
      }
      if query["sourceKind"] != nil {
        throw AdmissionFailure(
          code: "unknownField", path: "/query/sourceKind",
          message: "Item queries have no sourceKind.")
      }
      _ = try object(
        value, allowed: Set(query.keys), required: ["kind", "scope"], path: "/query")
      if let unsupported = Set(query.keys).subtracting([
        "kind", "scope", "text", "completion", "archive", "categories", "tags", "lists", "duration",
        "scheduled", "hasAddress", "hasLinks", "sort", "rowPresentation",
      ])
      .sorted().first {
        throw AdmissionFailure(
          code: "unavailable", path: "/query/" + unsupported,
          message:
            "This query slice supports scope, text, completion, archive, Category/Tag/List groups, duration, scheduling, address/link presence, sort and row presentation."
        )
      }
      let nativeScope = try scope(query["scope"])
      let sort = try sort(query["sort"])
      let text: String
      switch query["text"] {
      case nil: text = ""
      case .string(let value): text = value
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/text", message: "Expected Item search text.")
      }
      let completion: PlannerItemQuery.Completion
      switch query["completion"] {
      case nil, .string("todo"): completion = .todo
      case .string("done"): completion = .done
      case .string("all"): completion = .all
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/completion", message: "Expected todo, done or all.")
      }
      let archive: PlannerItemQuery.Archive
      switch query["archive"] {
      case nil, .string("active"): archive = .active
      case .string("archived"): archive = .archived
      case .string("all"): archive = .all
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/archive",
          message: "Expected active, archived or all.")
      }
      let presentation = try rowPresentation(query["rowPresentation"])
      let scheduled: PlannerItemQuery.Scheduling
      switch query["scheduled"] {
      case nil, .string("all"): scheduled = .all
      case .string("scheduled"): scheduled = .scheduled
      case .string("unscheduled"): scheduled = .unscheduled
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/scheduled",
          message: "Expected scheduled, unscheduled or all.")
      }
      return .items(
        PlannerItemQuery(
          scope: nativeScope, text: text, completion: completion, archive: archive,
          categories: try identityGroup(query["categories"], path: "/query/categories"),
          tags: try identityGroup(query["tags"], path: "/query/tags"),
          lists: try identityGroup(query["lists"], path: "/query/lists"),
          duration: try duration(query["duration"]),
          hasAddress: try presenceRequirement(query["hasAddress"], path: "/query/hasAddress"),
          hasLinks: try presenceRequirement(query["hasLinks"], path: "/query/hasLinks"),
          scheduled: scheduled,
          sort: sort, rowPresentation: presentation))
    }

    private static func presenceRequirement(_ value: Value?, path: String) throws -> Bool {
      switch value {
      case nil: return false
      case .bool(let required): return required
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: path, message: "Expected a Boolean presence requirement.")
      }
    }

    private static func identityGroup(_ value: Value?, path: String) throws
      -> PlannerItemQuery.IdentityGroup?
    {
      guard let value else { return nil }
      if case .null = value { return nil }
      let fields = try object(value, allowed: ["ids", "match"], required: ["ids"], path: path)
      guard case .array(let values) = fields["ids"] else {
        throw AdmissionFailure(
          code: "invalidInput", path: path + "/ids", message: "Expected an array of UUIDs.")
      }
      let identifiers = try values.enumerated().map { index, value in
        guard case .string(let spelling) = value, let identifier = UUID(uuidString: spelling) else {
          throw AdmissionFailure(
            code: "invalidInput", path: path + "/ids/\(index)", message: "Expected a UUID.")
        }
        return identifier
      }
      let match: PlannerItemQuery.IdentityGroup.Match
      switch fields["match"] {
      case nil, .string("any"): match = .any
      case .string("all"): match = .all
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: path + "/match", message: "Expected any or all.")
      }
      return PlannerItemQuery.IdentityGroup(ids: Set(identifiers), match: match)
    }

    private static func duration(_ value: Value?) throws -> PlannerItemQuery.Duration? {
      guard let value else { return nil }
      if case .null = value { return nil }
      let fields = try object(
        value, allowed: ["minimumMinutes", "maximumMinutes", "includeUnknown"],
        required: ["minimumMinutes", "maximumMinutes", "includeUnknown"], path: "/query/duration")
      guard case .bool(let includeUnknown) = fields["includeUnknown"] else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/duration/includeUnknown",
          message: "Expected a Boolean choice for unknown estimates.")
      }
      return PlannerItemQuery.Duration(
        minimumMinutes: try durationBound(
          fields["minimumMinutes"], path: "/query/duration/minimumMinutes"),
        maximumMinutes: try durationBound(
          fields["maximumMinutes"], path: "/query/duration/maximumMinutes"),
        includeUnknown: includeUnknown)
    }

    private static func durationBound(_ value: Value?, path: String) throws -> Int64? {
      if case .null = value { return nil }
      guard case .string(let spelling) = value, let minutes = Int64(spelling),
        minutes >= 0, String(minutes) == spelling
      else {
        throw AdmissionFailure(
          code: "invalidInput", path: path,
          message: "Expected null or nonnegative canonical decimal Int64 minutes.")
      }
      return minutes
    }

    private static func catalog(_ value: Value?) throws -> PlannerCatalogQuery {
      let fields = try object(
        value, allowed: ["kind", "sourceKind", "text", "archive"],
        required: ["kind", "sourceKind"], path: "/query")
      guard case .string(let encodedKind) = fields["sourceKind"],
        let sourceKind = PlannerEntityKind(rawValue: encodedKind), sourceKind != .item
      else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/sourceKind",
          message: "Expected a declared catalog source kind.")
      }
      let text: String
      switch fields["text"] {
      case nil: text = ""
      case .string(let value): text = value
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/text", message: "Expected catalog search text.")
      }
      let archive: PlannerItemQuery.Archive
      switch fields["archive"] {
      case nil, .string("active"): archive = .active
      case .string("archived"): archive = .archived
      case .string("all"): archive = .all
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/archive", message: "Expected active, archived or all."
        )
      }
      return PlannerCatalogQuery(sourceKind: sourceKind, text: text, archive: archive)
    }

    private static func scope(_ value: Value?) throws -> PlannerItemQuery.Scope {
      let fields = try object(
        value, allowed: ["kind", "listId", "itineraryId"], required: ["kind"], path: "/query/scope")
      switch fields["kind"] {
      case .string("global"), .string("inbox"):
        _ = try object(value, allowed: ["kind"], required: ["kind"], path: "/query/scope")
        return fields["kind"] == .string("global") ? .global : .inbox
      case .string("list"):
        _ = try object(
          value, allowed: ["kind", "listId"], required: ["kind", "listId"], path: "/query/scope")
        guard case .string(let encoded) = fields["listId"],
          let identifier = UUID(uuidString: encoded)
        else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/scope/listId", message: "Expected a List UUID.")
        }
        return .list(identifier)
      case .string("itinerary"):
        _ = try object(
          value, allowed: ["kind", "itineraryId"], required: ["kind", "itineraryId"],
          path: "/query/scope")
        guard case .string(let encoded) = fields["itineraryId"],
          let identifier = UUID(uuidString: encoded)
        else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/scope/itineraryId",
            message: "Expected an Itinerary UUID.")
        }
        return .itinerary(identifier)
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/scope/kind",
          message: "Expected global, inbox, list or itinerary scope.")
      }
    }

    private static func sort(_ value: Value?) throws -> PlannerItemQuery.Sort {
      guard let value else { return PlannerItemQuery.Sort() }
      let fields = try object(
        value, allowed: ["mode", "direction"], required: ["mode", "direction"], path: "/query/sort")
      guard case .string(let encodedMode) = fields["mode"],
        let mode = PlannerItemQuery.Sort.Mode(rawValue: encodedMode)
      else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/sort/mode", message: "Expected a declared sort mode.")
      }
      guard case .string(let encodedDirection) = fields["direction"],
        let direction = PlannerItemQuery.Sort.Direction(rawValue: encodedDirection)
      else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/sort/direction",
          message: "Expected ascending or descending.")
      }
      return PlannerItemQuery.Sort(mode: mode, direction: direction)
    }

    private static func rowPresentation(_ value: Value?) throws -> PlannerRowPresentationContext? {
      guard let value else { return nil }
      let fields = try object(
        value, allowed: ["referenceInstant", "displayTimeZone"],
        required: ["referenceInstant", "displayTimeZone"], path: "/query/rowPresentation")
      let referenceInstant: Double
      switch fields["referenceInstant"] {
      case .double(let number): referenceInstant = number
      case .int(let number): referenceInstant = Double(number)
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/rowPresentation/referenceInstant",
          message: "Expected a finite Foundation reference-date number.")
      }
      guard referenceInstant.isFinite else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/rowPresentation/referenceInstant",
          message: "Expected a finite Foundation reference-date number.")
      }
      guard case .string(let displayTimeZone) = fields["displayTimeZone"] else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/rowPresentation/displayTimeZone",
          message: "Expected a timezone identifier.")
      }
      return PlannerRowPresentationContext(
        referenceInstant: Date(timeIntervalSinceReferenceDate: referenceInstant),
        displayTimeZone: displayTimeZone)
    }

    private static func civilDate(_ value: Value?, path: String) throws -> PlannerCivilDate {
      let fields = try object(
        value, allowed: ["year", "month", "day"], required: ["year", "month", "day"], path: path)
      func component(_ name: String) throws -> Int {
        guard case .int(let number) = fields[name] else {
          throw AdmissionFailure(
            code: "invalidInput", path: path + "/" + name,
            message: "Expected an integer Gregorian component.")
        }
        return number
      }
      return try .init(year: component("year"), month: component("month"), day: component("day"))
    }

    private static func object(
      _ value: Value?, allowed: Set<String>, required: Set<String>, path: String
    ) throws -> [String: Value] {
      guard case .object(let fields) = value else {
        throw AdmissionFailure(code: "invalidInput", path: path, message: "Expected an object.")
      }
      if let unknown = Set(fields.keys).subtracting(allowed).sorted().first {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw AdmissionFailure(
          code: "unknownField", path: path + "/" + escaped, message: "Unknown property: \(unknown)."
        )
      }
      if let missing = required.subtracting(fields.keys).sorted().first {
        throw AdmissionFailure(
          code: "invalidInput", path: path + "/" + missing,
          message: "Required property is missing: \(missing).")
      }
      return fields
    }

    private struct AdmissionFailure: Error {
      let code: String
      let path: String
      let message: String
    }
  }
#endif
