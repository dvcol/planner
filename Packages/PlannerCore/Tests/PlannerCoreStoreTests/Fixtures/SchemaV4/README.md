# Native schema 4 fixture

Produced through the public Core facade compiled from commit `53946e5`, before schema 5. The original Item retains content, owned links, Done/Archived flags and fractional Tokyo appointment instants. Checkpoint 6 follows creating, completing and archiving the Item, creating/removing one Schedule, and creating another. A minimal deletion marker closes the first Schedule lifetime. The producer never uses private models or tables. Its source and literal manifest are included.

The producer exited successfully before copying the SQLite/WAL/SHM, control and independent recovery files. `checksums.json` lists SHA-256 for every other fixture file. Migration tests copy the complete fixture and check public reads, original receipts and independent snapshots. These bytes were produced by schema 4, rather than recreated under the schema being tested.
