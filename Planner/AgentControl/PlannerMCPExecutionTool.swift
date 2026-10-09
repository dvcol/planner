#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPExecutionTool {
    static let definition = Tool(
      name: "planner_execute",
      description:
        "Create and edit Items and Lists, complete/reopen Items, archive/unarchive Items and Lists, and create, edit or remove direct timed/all-day Schedules. Change planning zones of timed Schedules through the local Planner prototype.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("operationId"), .string("command")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "operationId": .object(["type": .string("string"), "format": .string("uuid")]),
          "command": .object([
            "oneOf": .array([
              creationSchema, listCreationSchema, editSchema, listEditSchema, archiveSchema,
              completionSchema,
              scheduleCreationSchema,
              scheduleEditSchema, scheduleZoneSchema, scheduleRemovalSchema,
            ])
          ]),
          "reviewToken": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
      ]),
      annotations: .init(
        readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false)
    )

    private static let locationSchema = Value.object([
      "type": .array([.string("object"), .string("null")]), "additionalProperties": .bool(false),
      "required": .array([
        .string("displayName"), .string("formattedAddress"), .string("coordinate"),
      ]),
      "properties": .object([
        "displayName": .object(["type": .array([.string("string"), .string("null")])]),
        "formattedAddress": .object(["type": .array([.string("string"), .string("null")])]),
        "coordinate": .object([
          "type": .array([.string("object"), .string("null")]),
          "additionalProperties": .bool(false),
          "required": .array([.string("latitude"), .string("longitude")]),
          "properties": .object([
            "latitude": .object([
              "type": .string("number"), "minimum": .int(-90), "maximum": .int(90),
            ]),
            "longitude": .object([
              "type": .string("number"), "minimum": .int(-180), "maximum": .int(180),
            ]),
          ]),
        ]),
      ]),
    ])

    private static let linksSchema = Value.object([
      "type": .string("array"),
      "items": .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("originalUrl"), .string("label")]),
        "properties": .object([
          "linkId": .object([
            "type": .array([.string("string"), .string("null")]), "format": .string("uuid"),
          ]),
          "originalUrl": .object(["type": .string("string"), "format": .string("uri")]),
          "label": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
      ]),
    ])

    private static let creationSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("content")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("createItem")]),
        "content": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("title")]),
          "properties": .object([
            "title": .object(["type": .string("string")]),
            "notes": .object(["type": .array([.string("string"), .string("null")])]),
            "location": locationSchema,
            "links": linksSchema,
          ]),
        ]),
      ]),
    ])

    private static let colorSchema = Value.object([
      "type": .array([.string("object"), .string("null")]), "additionalProperties": .bool(false),
      "required": .array([.string("red"), .string("green"), .string("blue"), .string("alpha")]),
      "properties": .object(
        Dictionary(
          uniqueKeysWithValues: ["red", "green", "blue", "alpha"].map {
            ($0, .object(["type": .string("number"), "minimum": .int(0), "maximum": .int(1)]))
          })),
    ])

    private static let listContentProperties: [String: Value] = [
      "name": .object(["type": .string("string")]),
      "notes": .object(["type": .array([.string("string"), .string("null")])]),
      "color": colorSchema,
      "iconName": .object(["type": .array([.string("string"), .string("null")])]),
    ]

    private static let listCreationSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("content")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("createList")]),
        "content": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("name")]), "properties": .object(listContentProperties),
        ]),
      ]),
    ])

    private static let listEditSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([
        .string("type"), .string("sourceId"), .string("changes"), .string("expectedFieldHashes"),
      ]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("editList")]),
        "sourceId": .object(["type": .string("string"), "format": .string("uuid")]),
        "changes": .object([
          "type": .string("object"), "additionalProperties": .bool(false), "minProperties": .int(1),
          "properties": .object(listContentProperties),
        ]),
        "expectedFieldHashes": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "properties": .object(
            Dictionary(
              uniqueKeysWithValues: PlannerListField.allCases.map {
                (
                  $0.rawValue,
                  .object([
                    "type": .string("string"), "pattern": .string("^sha256-v1:[0-9a-f]{64}$"),
                  ])
                )
              })),
        ]),
      ]),
    ])

    private static let editSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([
        .string("type"), .string("sourceId"), .string("changes"), .string("expectedFieldHashes"),
      ]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("editItem")]),
        "sourceId": .object(["type": .string("string"), "format": .string("uuid")]),
        "changes": .object([
          "type": .string("object"), "additionalProperties": .bool(false), "minProperties": .int(1),
          "properties": .object([
            "title": .object(["type": .string("string")]),
            "notes": .object(["type": .array([.string("string"), .string("null")])]),
            "location": locationSchema,
            "links": linksSchema,
          ]),
        ]),
        "expectedFieldHashes": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "properties": .object(
            Dictionary(
              uniqueKeysWithValues: PlannerItemField.allCases.map {
                (
                  $0.rawValue,
                  .object([
                    "type": .string("string"), "pattern": .string("^sha256-v1:[0-9a-f]{64}$"),
                  ])
                )
              })),
        ]),
      ]),
    ])

    private static let archiveSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("source"), .string("archived")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("setArchive")]),
        "source": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("kind"), .string("id")]),
          "properties": .object([
            "kind": .object([
              "type": .string("string"), "enum": .array([.string("item"), .string("list")]),
            ]),
            "id": .object(["type": .string("string"), "format": .string("uuid")]),
          ]),
        ]),
        "archived": .object(["type": .string("boolean")]),
      ]),
    ])

    private static let completionSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("scope"), .string("done")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("setCompletion")]),
        "scope": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("kind"), .string("itemId")]),
          "properties": .object([
            "kind": .object(["type": .string("string"), "const": .string("globalItem")]),
            "itemId": .object(["type": .string("string"), "format": .string("uuid")]),
          ]),
        ]),
        "done": .object(["type": .string("boolean")]),
      ]),
    ])

    private static let scheduleCreationSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("source"), .string("form")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("createSchedule")]),
        "source": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("kind"), .string("id")]),
          "properties": .object([
            "kind": .object(["type": .string("string"), "const": .string("item")]),
            "id": .object(["type": .string("string"), "format": .string("uuid")]),
          ]),
        ]),
        "form": scheduleFormSchema,
      ]),
    ])

    private static let scheduleFormSchema = Value.object([
      "oneOf": .array([timedFormSchema, allDayFormSchema])
    ])

    private static let civilDateSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("year"), .string("month"), .string("day")]),
      "properties": .object([
        "year": .object(["type": .string("integer")]),
        "month": .object(["type": .string("integer")]),
        "day": .object(["type": .string("integer")]),
      ]),
    ])

    private static let allDayFormSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("kind"), .string("start"), .string("end")]),
      "properties": .object([
        "kind": .object(["type": .string("string"), "const": .string("allDay")]),
        "start": civilDateSchema,
        "end": .object(["oneOf": .array([civilDateSchema, .object(["type": .string("null")])])]),
      ]),
    ])

    private static let timedFormSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([
        .string("kind"), .string("start"), .string("end"), .string("planningTimeZone"),
      ]),
      "properties": .object([
        "kind": .object(["type": .string("string"), "const": .string("timed")]),
        "start": .object(["type": .string("number")]),
        "end": .object(["type": .array([.string("number"), .string("null")])]),
        "planningTimeZone": .object(["type": .string("string")]),
      ]),
    ])

    private static let scheduleEditSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([
        .string("type"), .string("scheduleId"), .string("changes"), .string("expectedFieldHashes"),
      ]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("editSchedule")]),
        "scheduleId": .object(["type": .string("string"), "format": .string("uuid")]),
        "changes": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("form")]),
          "properties": .object(["form": scheduleFormSchema]),
        ]),
        "expectedFieldHashes": scheduleHashesSchema,
      ]),
    ])

    private static let scheduleHashesSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("form")]),
      "properties": .object([
        "form": .object([
          "type": .string("string"), "pattern": .string("^sha256-v1:[0-9a-f]{64}$"),
        ])
      ]),
    ])

    private static let scheduleZoneSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([
        .string("type"), .string("scheduleId"), .string("planningTimeZone"),
        .string("expectedFieldHashes"),
      ]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("changeScheduleZone")]),
        "scheduleId": .object(["type": .string("string"), "format": .string("uuid")]),
        "planningTimeZone": .object(["type": .string("string")]),
        "expectedFieldHashes": scheduleHashesSchema,
      ]),
    ])

    private static let scheduleRemovalSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("scheduleId")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("removeSchedule")]),
        "scheduleId": .object(["type": .string("string"), "format": .string("uuid")]),
      ]),
    ])

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      var operationIdentifier: UUID?
      do {
        let arguments = try object(
          parameters.arguments.map(Value.object),
          allowed: ["formatVersion", "operationId", "command", "reviewToken"],
          required: ["formatVersion", "operationId", "command"], path: "")
        guard case .string(let spelling) = arguments["operationId"],
          let identity = UUID(uuidString: spelling)
        else {
          throw AdmissionFailure("invalidInput", "/operationId", "Expected an operation UUID.")
        }
        operationIdentifier = identity
        guard arguments["formatVersion"] == .int(1) else {
          throw AdmissionFailure(
            "unsupportedVersion", "/formatVersion", "Expected adapter format version 1.")
        }
        guard case .object(let suppliedCommand) = arguments["command"],
          case .string(let commandType) = suppliedCommand["type"]
        else {
          throw AdmissionFailure("invalidInput", "/command/type", "Expected a command type.")
        }
        if ["deleteSource", "applyImport", "restoreRecovery"].contains(commandType) {
          throw AdmissionFailure(
            "forbiddenOperation", "/command/type",
            "Permanent deletion, import and recovery administration are native Planner actions.")
        }
        if let token = arguments["reviewToken"], token != .null {
          throw AdmissionFailure(
            "staleReview", "/reviewToken", "No review token is issued for this ordinary data slice."
          )
        }
        let command: PlannerCommand
        switch commandType {
        case "createItem": command = try creationCommand(arguments["command"])
        case "createList": command = try listCreationCommand(arguments["command"])
        case "editList": command = try listEditCommand(arguments["command"])
        case "editItem": command = try editCommand(arguments["command"])
        case "setArchive": command = try archiveCommand(arguments["command"])
        case "setCompletion": command = try completionCommand(arguments["command"])
        case "createSchedule": command = try scheduleCreationCommand(arguments["command"])
        case "editSchedule": command = try scheduleEditCommand(arguments["command"])
        case "changeScheduleZone": command = try scheduleZoneCommand(arguments["command"])
        case "removeSchedule": command = try scheduleRemovalCommand(arguments["command"])
        default:
          throw AdmissionFailure(
            "unavailable", "/command/type", "This command is not yet implemented by the prototype.")
        }
        let outcome = await planner.execute(
          PlannerOperation(operationId: identity, session: session, command: command))
        return try encoded(outcome)
      } catch let failure as AdmissionFailure {
        return rejection(
          operationIdentifier, code: failure.code, path: failure.path, message: failure.message)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "unavailable",
          message: "The operation outcome could not be encoded; inspect its status before retrying."
        )
      }
    }

    private static func listCreationCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "content"], required: ["type", "content"], path: "/command")
      let content = try object(
        command["content"], allowed: Set(PlannerListField.allCases.map(\.rawValue)),
        required: ["name"], path: "/command/content")
      guard case .string(let name) = content["name"] else {
        throw AdmissionFailure(
          "invalidInput", "/command/content/name", "Expected a List name String.")
      }
      let color: PlannerColor?
      switch try colorChange(content["color"], path: "/command/content/color") {
      case .set(let value): color = value
      case .clear, .unchanged: color = nil
      }
      return .createList(
        content: PlannerListContentInput(
          name: name,
          notes: try nullableText(content["notes"] ?? .null, path: "/command/content/notes"),
          color: color,
          iconName: try nullableText(
            content["iconName"] ?? .null, path: "/command/content/iconName")))
    }

    private static func listEditCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "sourceId", "changes", "expectedFieldHashes"],
        required: ["type", "sourceId", "changes", "expectedFieldHashes"], path: "/command")
      guard case .string(let spelling) = command["sourceId"],
        let sourceIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/sourceId", "Expected a List UUID.")
      }
      let fieldNames = Set(PlannerListField.allCases.map(\.rawValue))
      let changes = try object(
        command["changes"], allowed: fieldNames, required: [], path: "/command/changes")
      let hashValues = try object(
        command["expectedFieldHashes"], allowed: fieldNames, required: [],
        path: "/command/expectedFieldHashes")
      var hashes: [PlannerListField: PlannerFieldHash] = [:]
      for (name, value) in hashValues {
        guard let field = PlannerListField(rawValue: name), case .string(let spelling) = value
        else {
          throw AdmissionFailure(
            "invalidInput", "/command/expectedFieldHashes/" + name, "Expected a field hash String.")
        }
        hashes[field] = PlannerFieldHash(value: spelling)
      }
      return .editList(
        sourceId: sourceIdentifier,
        changes: PlannerListChanges(
          name: try textChange(changes["name"], path: "/command/changes/name"),
          notes: try textChange(changes["notes"], path: "/command/changes/notes"),
          color: try colorChange(changes["color"], path: "/command/changes/color"),
          iconName: try textChange(changes["iconName"], path: "/command/changes/iconName")),
        expectedFieldHashes: hashes)
    }

    private static func colorChange(
      _ value: Value?, path: String
    ) throws -> PlannerFieldChange<PlannerColor> {
      guard let value else { return .unchanged }
      if case .null = value { return .clear }
      let fields = try object(
        value, allowed: ["red", "green", "blue", "alpha"],
        required: ["red", "green", "blue", "alpha"], path: path)
      return .set(
        PlannerColor(
          red: try colorComponent(fields["red"], path: path + "/red"),
          green: try colorComponent(fields["green"], path: path + "/green"),
          blue: try colorComponent(fields["blue"], path: path + "/blue"),
          alpha: try colorComponent(fields["alpha"], path: path + "/alpha")))
    }

    private static func colorComponent(_ value: Value?, path: String) throws -> Double {
      switch value {
      case .int(let number): return Double(number)
      case .double(let number): return number
      default: throw AdmissionFailure("invalidInput", path, "Expected a color component number.")
      }
    }

    private static func scheduleCreationCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "source", "form"], required: ["type", "source", "form"],
        path: "/command")
      let source = try object(
        command["source"], allowed: ["kind", "id"], required: ["kind", "id"],
        path: "/command/source")
      guard case .string(let spelling) = source["kind"],
        let sourceKind = PlannerEntityKind(rawValue: spelling),
        [.item, .itinerary].contains(sourceKind)
      else {
        throw AdmissionFailure(
          "invalidInput", "/command/source/kind", "Expected an Item or Itinerary source kind.")
      }
      guard case .string(let spelling) = source["id"],
        let sourceIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/source/id", "Expected a source UUID.")
      }
      return .createSchedule(
        source: PlannerEntityReference(kind: sourceKind, id: sourceIdentifier),
        form: try scheduleForm(command["form"], path: "/command/form"))
    }

    private static func scheduleRemovalCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "scheduleId"], required: ["type", "scheduleId"], path: "/command")
      guard case .string(let spelling) = command["scheduleId"],
        let scheduleIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/scheduleId", "Expected a Schedule UUID.")
      }
      return .removeSchedule(scheduleId: scheduleIdentifier)
    }

    private static func scheduleEditCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value,
        allowed: ["type", "scheduleId", "changes", "expectedFieldHashes"],
        required: ["type", "scheduleId", "changes", "expectedFieldHashes"], path: "/command")
      guard case .string(let spelling) = command["scheduleId"],
        let scheduleIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/scheduleId", "Expected a Schedule UUID.")
      }
      let changes = try object(
        command["changes"], allowed: ["form"], required: ["form"], path: "/command/changes")
      let form = try scheduleForm(changes["form"], path: "/command/changes/form")
      return .editSchedule(
        scheduleId: scheduleIdentifier, changes: PlannerScheduleChanges(form: form),
        expectedFieldHashes: try scheduleHashes(command["expectedFieldHashes"]))
    }

    private static func scheduleZoneCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value,
        allowed: ["type", "scheduleId", "planningTimeZone", "expectedFieldHashes"],
        required: ["type", "scheduleId", "planningTimeZone", "expectedFieldHashes"],
        path: "/command")
      guard case .string(let spelling) = command["scheduleId"],
        let scheduleIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/scheduleId", "Expected a Schedule UUID.")
      }
      guard case .string(let planningTimeZone) = command["planningTimeZone"] else {
        throw AdmissionFailure(
          "invalidInput", "/command/planningTimeZone", "Expected a planning timezone String.")
      }
      return .changeScheduleZone(
        scheduleId: scheduleIdentifier, planningTimeZone: planningTimeZone,
        expectedFieldHashes: try scheduleHashes(command["expectedFieldHashes"]))
    }

    private static func scheduleHashes(_ value: Value?) throws -> [PlannerScheduleField:
      PlannerFieldHash]
    {
      let hashes = try object(
        value, allowed: ["form"], required: ["form"], path: "/command/expectedFieldHashes")
      guard case .string(let formHash) = hashes["form"] else {
        throw AdmissionFailure(
          "invalidInput", "/command/expectedFieldHashes/form", "Expected a form hash String.")
      }
      return [.form: PlannerFieldHash(value: formHash)]
    }

    private static func scheduleForm(_ value: Value?, path: String) throws -> PlannerScheduleForm {
      let form = try object(
        value, allowed: ["kind", "start", "end", "planningTimeZone"],
        required: ["kind"], path: path)
      if form["kind"] == .string("allDay") {
        _ = try object(
          value, allowed: ["kind", "start", "end"], required: ["kind", "start", "end"], path: path)
        let start = try civilDate(form["start"], path: path + "/start")
        let end: PlannerCivilDate?
        if form["end"] == .null {
          end = nil
        } else {
          end = try civilDate(form["end"], path: path + "/end")
        }
        return .allDay(start: start, end: end)
      }
      guard form["kind"] == .string("timed") else {
        throw AdmissionFailure("invalidInput", path + "/kind", "Expected a Schedule form kind.")
      }
      _ = try object(
        value, allowed: ["kind", "start", "end", "planningTimeZone"],
        required: ["kind", "start", "end", "planningTimeZone"], path: path)
      let start = try scheduleInstant(form["start"], path: path + "/start")
      let end: Date?
      if form["end"] == .null {
        end = nil
      } else {
        end = try scheduleInstant(form["end"], path: path + "/end")
      }
      guard case .string(let planningTimeZone) = form["planningTimeZone"] else {
        throw AdmissionFailure(
          "invalidInput", path + "/planningTimeZone", "Expected a planning timezone String.")
      }
      return .timed(start: start, end: end, planningTimeZone: planningTimeZone)
    }

    private static func civilDate(_ value: Value?, path: String) throws -> PlannerCivilDate {
      let date = try object(
        value, allowed: ["year", "month", "day"], required: ["year", "month", "day"], path: path)
      return PlannerCivilDate(
        year: try civilDateComponent(date["year"], path: path + "/year"),
        month: try civilDateComponent(date["month"], path: path + "/month"),
        day: try civilDateComponent(date["day"], path: path + "/day"))
    }

    private static func civilDateComponent(_ value: Value?, path: String) throws -> Int {
      guard case .int(let component) = value else {
        throw AdmissionFailure("invalidInput", path, "Expected an integer Gregorian component.")
      }
      return component
    }

    private static func scheduleInstant(_ value: Value?, path: String) throws -> Date {
      let seconds: Double
      switch value {
      case .double(let number): seconds = number
      case .int(let number): seconds = Double(number)
      default:
        throw AdmissionFailure(
          "invalidInput", path, "Expected a finite Foundation reference-date number.")
      }
      guard seconds.isFinite else {
        throw AdmissionFailure(
          "invalidInput", path, "Expected a finite Foundation reference-date number.")
      }
      return Date(timeIntervalSinceReferenceDate: seconds)
    }

    private static func completionCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "scope", "done"], required: ["type", "scope", "done"],
        path: "/command")
      let scope = try object(
        command["scope"], allowed: ["kind", "itemId", "appearance"], required: ["kind"],
        path: "/command/scope")
      if scope["kind"] == .string("appearance") {
        _ = try object(
          command["scope"], allowed: ["kind", "appearance"], required: ["kind", "appearance"],
          path: "/command/scope")
        throw AdmissionFailure(
          "unavailable", "/command/scope/kind",
          "Appearance-local completion is not implemented by this Item-only fixture.")
      }
      guard scope["kind"] == .string("globalItem") else {
        throw AdmissionFailure(
          "invalidInput", "/command/scope/kind", "Expected a completion scope.")
      }
      let globalScope = try object(
        command["scope"], allowed: ["kind", "itemId"], required: ["kind", "itemId"],
        path: "/command/scope")
      guard case .string(let spelling) = globalScope["itemId"],
        let itemIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/scope/itemId", "Expected an Item UUID.")
      }
      guard case .bool(let done) = command["done"] else {
        throw AdmissionFailure("invalidInput", "/command/done", "Expected a completion Boolean.")
      }
      return .setCompletion(scope: .globalItem(itemId: itemIdentifier), done: done)
    }

    private static func creationCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "content"], required: ["type", "content"],
        path: "/command")
      let content = try object(
        command["content"],
        allowed: [
          "title", "notes", "subtitle", "location", "estimate", "links", "categoryIds", "tagIds",
        ],
        required: ["title"], path: "/command/content")
      if let unsupported = Set(content.keys).subtracting(["title", "notes", "links", "location"])
        .sorted().first
      {
        throw AdmissionFailure(
          "unavailable", "/command/content/" + unsupported,
          "This HTTP creation slice supports title, notes, owned location and links only.")
      }
      guard case .string(let title) = content["title"] else {
        throw AdmissionFailure(
          "invalidInput", "/command/content/title", "Expected a title String.")
      }
      let notes: String?
      switch content["notes"] {
      case nil, .null: notes = nil
      case .string(let value): notes = value
      default:
        throw AdmissionFailure(
          "invalidInput", "/command/content/notes", "Expected a notes String or null.")
      }
      let location: PlannerOwnedLocation?
      switch try locationChange(content["location"], path: "/command/content/location") {
      case .set(let value): location = value
      case .clear, .unchanged: location = nil
      }
      return .createItem(
        content: PlannerItemContentInput(
          title: title, notes: notes, location: location,
          links: try linksInput(content["links"], path: "/command/content/links")))
    }

    private static func locationChange(
      _ value: Value?, path: String
    ) throws -> PlannerFieldChange<PlannerOwnedLocation> {
      guard let value else { return .unchanged }
      if case .null = value { return .clear }
      let fields = try object(
        value, allowed: ["displayName", "formattedAddress", "coordinate"],
        required: ["displayName", "formattedAddress", "coordinate"], path: path)
      let coordinate: PlannerCoordinate?
      if case .null = fields["coordinate"] {
        coordinate = nil
      } else {
        let coordinates = try object(
          fields["coordinate"], allowed: ["latitude", "longitude"],
          required: ["latitude", "longitude"], path: path + "/coordinate")
        coordinate = PlannerCoordinate(
          latitude: try coordinateNumber(
            coordinates["latitude"], path: path + "/coordinate/latitude"),
          longitude: try coordinateNumber(
            coordinates["longitude"], path: path + "/coordinate/longitude"))
      }
      return .set(
        PlannerOwnedLocation(
          displayName: try nullableText(fields["displayName"], path: path + "/displayName"),
          formattedAddress: try nullableText(
            fields["formattedAddress"], path: path + "/formattedAddress"),
          coordinate: coordinate))
    }

    private static func coordinateNumber(_ value: Value?, path: String) throws -> Double {
      switch value {
      case .int(let number): return Double(number)
      case .double(let number): return number
      default:
        throw AdmissionFailure("invalidInput", path, "Expected a coordinate number.")
      }
    }

    private static func nullableText(_ value: Value?, path: String) throws -> String? {
      switch value {
      case .null: return nil
      case .string(let text): return text
      default:
        throw AdmissionFailure("invalidInput", path, "Expected a String or null.")
      }
    }

    private static func linksInput(_ value: Value?, path collectionPath: String) throws
      -> [PlannerLinkInput]
    {
      guard let value else { return [] }
      guard case .array(let links) = value else {
        throw AdmissionFailure(
          "invalidInput", collectionPath, "Expected an ordered links array.")
      }
      return try links.enumerated().map { index, value in
        let path = collectionPath + "/\(index)"
        let fields = try object(
          value, allowed: ["linkId", "originalUrl", "label"], required: ["originalUrl", "label"],
          path: path)
        guard case .string(let originalUrl) = fields["originalUrl"] else {
          throw AdmissionFailure(
            "invalidInput", path + "/originalUrl", "Expected an original URL String.")
        }
        let label: String?
        switch fields["label"] {
        case .null: label = nil
        case .string(let value): label = value
        default:
          throw AdmissionFailure(
            "invalidInput", path + "/label", "Expected a label String or null.")
        }
        let linkIdentifier: UUID?
        switch fields["linkId"] {
        case nil, .null: linkIdentifier = nil
        case .string(let spelling):
          guard let parsedIdentifier = UUID(uuidString: spelling) else {
            throw AdmissionFailure(
              "invalidInput", path + "/linkId", "Expected a link UUID or null.")
          }
          linkIdentifier = parsedIdentifier
        default:
          throw AdmissionFailure("invalidInput", path + "/linkId", "Expected a link UUID or null.")
        }
        return PlannerLinkInput(linkId: linkIdentifier, originalUrl: originalUrl, label: label)
      }
    }

    private static func editCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "sourceId", "changes", "expectedFieldHashes"],
        required: ["type", "sourceId", "changes", "expectedFieldHashes"], path: "/command")
      guard case .string(let spelling) = command["sourceId"],
        let sourceIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/sourceId", "Expected an Item UUID.")
      }
      let fieldNames = Set(PlannerItemField.allCases.map(\.rawValue))
      let changes = try object(
        command["changes"], allowed: fieldNames, required: [], path: "/command/changes")
      if let unsupported = Set(changes.keys).subtracting(["title", "notes", "location", "links"])
        .sorted()
        .first
      {
        throw AdmissionFailure(
          "unavailable", "/command/changes/" + unsupported,
          "This edit slice supports title, notes, location and links only.")
      }
      let hashValues = try object(
        command["expectedFieldHashes"], allowed: fieldNames, required: [],
        path: "/command/expectedFieldHashes")
      var hashes: [PlannerItemField: PlannerFieldHash] = [:]
      for (name, value) in hashValues {
        guard let field = PlannerItemField(rawValue: name), case .string(let spelling) = value
        else {
          throw AdmissionFailure(
            "invalidInput", "/command/expectedFieldHashes/" + name, "Expected a field hash String.")
        }
        hashes[field] = PlannerFieldHash(value: spelling)
      }
      let linkChanges: PlannerFieldChange<[PlannerLinkInput]>
      if let value = changes["links"] {
        linkChanges = .set(try linksInput(value, path: "/command/changes/links"))
      } else {
        linkChanges = .unchanged
      }
      return .editItem(
        sourceId: sourceIdentifier,
        changes: PlannerItemChanges(
          title: try textChange(changes["title"], path: "/command/changes/title"),
          notes: try textChange(changes["notes"], path: "/command/changes/notes"),
          location: try locationChange(changes["location"], path: "/command/changes/location"),
          links: linkChanges),
        expectedFieldHashes: hashes)
    }

    private static func archiveCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "source", "archived"], required: ["type", "source", "archived"],
        path: "/command")
      let source = try object(
        command["source"], allowed: ["kind", "id"], required: ["kind", "id"],
        path: "/command/source")
      guard case .string(let spelling) = source["kind"],
        let kind = PlannerEntityKind(rawValue: spelling),
        [.item, .list, .itinerary].contains(kind)
      else {
        throw AdmissionFailure(
          "invalidInput", "/command/source/kind", "Expected Item, List or Itinerary source kind.")
      }
      guard case .string(let spelling) = source["id"], let identity = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/source/id", "Expected a source UUID.")
      }
      guard case .bool(let archived) = command["archived"] else {
        throw AdmissionFailure("invalidInput", "/command/archived", "Expected an archive Bool.")
      }
      return .setArchive(
        source: PlannerEntityReference(kind: kind, id: identity), archived: archived)
    }

    private static func textChange(_ value: Value?, path: String) throws -> PlannerFieldChange<
      String
    > {
      switch value {
      case nil: return .unchanged
      case .null: return .clear
      case .string(let text): return .set(text)
      default: throw AdmissionFailure("invalidInput", path, "Expected a String or null.")
      }
    }

    private static func encoded(_ outcome: PlannerOperationResult) throws -> CallTool.Result {
      var fields: [String: Value] = [
        "formatVersion": .int(1), "operationId": .string(outcome.operationId.uuidString),
      ]
      var rejected = false
      switch outcome.outcome {
      case .rejected(let reason):
        fields["state"] = .string("rejected")
        fields["reason"] = PlannerMCPFailureValue.encode(reason)
        rejected = true
      case .unverified(let proposal):
        fields["state"] = .string("unverified")
        fields["proposal"] = .object([
          "proposalId": .string(proposal.proposalId.uuidString),
          "originalOperationId": .string(proposal.originalOperationId.uuidString),
          "evidence": .string(proposal.evidence),
          "requiresFreshReview": .bool(proposal.requiresFreshReview),
        ])
      case .applied(let result, let recovery):
        fields["state"] = .string("applied")
        fields["result"] = .object([
          "generated": .array(
            result.generatedIdentities.map(PlannerMCPSourceTool.appliedIdentityValue)),
          "affected": .array(
            result.affectedIdentities.map(PlannerMCPSourceTool.appliedIdentityValue)),
          "progress": .array([]), "importSummary": .null,
        ])
        switch recovery {
        case .complete(let generation):
          fields["recovery"] = .object([
            "state": .string("complete"), "checkpointGeneration": .string(String(generation)),
          ])
        case .incomplete(let reason):
          fields["recovery"] = .object([
            "state": .string("incomplete"),
            "reason": PlannerMCPFailureValue.encode(reason),
          ])
        }
      }
      return try result(.object(fields), isError: rejected)
    }

    private static func rejection(
      _ operationIdentifier: UUID?, code: String, path: String?, message: String
    ) -> CallTool.Result {
      guard let operationIdentifier else {
        return PlannerMCPSourceTool.failure(code: code, message: message, path: path)
      }
      let value = Value.object([
        "formatVersion": .int(1), "operationId": .string(operationIdentifier.uuidString),
        "state": .string("rejected"), "reason": failureValue(code, path, message),
      ])
      do { return try result(value, isError: true) } catch {
        return CallTool.Result(
          content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
      }
    }

    private static func result(_ value: Value, isError: Bool) throws -> CallTool.Result {
      let serialized = try JSONEncoder().encode(value)
      return CallTool.Result(
        content: [
          .text(text: String(decoding: serialized, as: UTF8.self), annotations: nil, _meta: nil)
        ],
        structuredContent: Optional.some(value), isError: isError)
    }

    private static func failureValue(_ code: String, _ path: String?, _ message: String) -> Value {
      .object([
        "code": .string(code), "propertyPath": path.map(Value.string) ?? .null,
        "message": .string(message), "details": .null,
      ])
    }

    private static func object(
      _ value: Value?, allowed: Set<String>, required: Set<String>, path: String
    ) throws -> [String: Value] {
      guard case .object(let fields) = value else {
        throw AdmissionFailure("invalidInput", path, "Expected an object.")
      }
      if let unknown = Set(fields.keys).subtracting(allowed).sorted().first {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw AdmissionFailure(
          "unknownField", path + "/" + escaped, "Unknown property: \(unknown).")
      }
      if let missing = required.subtracting(fields.keys).sorted().first {
        throw AdmissionFailure(
          "invalidInput", path + "/" + missing, "Required property is missing: \(missing).")
      }
      return fields
    }

    private struct AdmissionFailure: Error {
      let code: String
      let path: String
      let message: String

      init(_ code: String, _ path: String, _ message: String) {
        self.code = code
        self.path = path
        self.message = message
      }
    }
  }
#endif
