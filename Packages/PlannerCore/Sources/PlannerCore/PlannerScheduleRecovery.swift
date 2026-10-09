import Foundation

struct PortableScheduleRecord: Codable {
  let id: UUID
  let lifetimeId: UUID
  let source: PlannerBoundIdentity
  let form: PlannerScheduleForm

  init(_ schedule: ScheduleSnapshot, owner: ItemSnapshot) {
    id = schedule.id
    lifetimeId = schedule.lifetimeId
    source = PlannerBoundIdentity(kind: "item", id: owner.id, lifetimeId: owner.lifetimeId)
    form = schedule.form
  }

  func validated(sources: [PortableItemRecord]) throws -> PlannerPortableSchedule {
    guard source.kind == "item",
      sources.contains(where: { $0.id == source.id && $0.lifetimeId == source.lifetimeId })
    else {
      throw PlannerFailure("recoveryIntegrityFailure", "The Schedule has invalid source ownership.")
    }
    try form.validate()
    return PlannerPortableSchedule(
      id: id, lifetimeId: lifetimeId, source: PlannerEntityReference(kind: .item, id: source.id),
      sourceLifetimeId: source.lifetimeId, form: form)
  }
}
