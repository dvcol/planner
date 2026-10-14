import Foundation
let parser = ISO8601DateFormatter()
let start = parser.date(from: "2026-11-01T05:30:00Z")!
let end = parser.date(from: "2026-11-01T06:30:00Z")!
let formatter = DateIntervalFormatter()
formatter.locale = Locale(identifier: "en_US")
formatter.timeZone = TimeZone(identifier: "America/New_York")!
formatter.dateStyle = .medium
formatter.timeStyle = .short
print("existing:", formatter.string(from: start, to: end))
for template in ["yMMMdjmz", "jmz"] {
  formatter.dateTemplate = template
  print(template + ":", formatter.string(from: start, to: end))
}
