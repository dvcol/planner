# Schema 14 migration fixture

Produced with unchanged public Core at `a47caea2c65d5f8c417c627231a62d79cb277564`. The real SwiftData store retains repeated Item/List entries, independent local completion, labels, owned links, archive state, Item and Itinerary schedules, a removed Schedule marker and operation receipts. Checkpoint 19 preserves independent recovery. The producer and copied-byte checksums accompany the fixture. Tests copy the directory before migration.
