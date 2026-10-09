# Native schema 3 fixture

Produced by archived committed PlannerCore at `4ecd459`, running the included public-facade producer with Xcode 27 on macOS. Copied only after the producer process completed successfully. Store, SQLite WAL/SHM, writer control and independent recovery remain together. No file's schema/version was edited.

Hotel retains Original notes, the Meeting point address/coordinates, a two-hour estimate, Map/Menu owned links, global Done and Archived state. A direct Tokyo timed Schedule retains fractional start/end instants. Checkpoint 4 follows Item creation, completion, archive and Schedule creation; the manifest records original IDs, full hashes, timestamps and receipt IDs.

Source and producer logs were `/private/tmp/PlannerSchema3Producer-4ecd459` and `/private/tmp/PlannerSchema3Producer-4ecd459.log`; generated data was `/private/tmp/PlannerSchema3Produced-4ecd459`. The consumer must copy the fixture to a fresh temporary directory before opening it. This fixture proves migration from real schema 3 data, without a physical Share extension or CloudKit claim.
