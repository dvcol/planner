# Query generation retention decision

Status: Q84 C accepted by the human on 15 October 2026. Keep the current in-memory retention and lazy cleanup. No eviction, expiry, disk-spill or release mechanism is introduced.

## Context, starting state and goal

Core captures query identities and presentation metadata for consistent paging. Calendar also captures live owner titles and Schedule forms. A changed dataset/store invalidates old pages; Calendar's native loader discards partial pages and restarts. Other native Item/List/label readers currently report a stale-read error rather than automatically restarting.

Equivalent Calendar results already reuse a capture after full validation. Distinct results and sessions retain separate captures in the shared querySnapshots dictionary. A saved-history change invalidates their readability; memory cleanup is lazy. A later query prunes bindings with older history, and a stale page read removes only its requested binding. Item and catalog generations use the same dictionary. Before Q84, the contracts defined stale failures after store changes without settling early eviction, a retention duration, a cache budget or a release operation.

The public Core probe reads 100 overlapping windows of the existing 5,000-Schedule fixture. Each result contains 3,001 through 3,100 Schedules. All 100 distinct generations remain readable afterward, and the saved full backup is byte-identical. This establishes retained availability, not a memory failure. Whole-process debug macOS resident memory can fall as the runtime reclaims other allocations; it does not isolate capture allocations or prove a mobile budget. The probe evidence records the observations and source.

The accepted end state records the existing lifetime rule for native and agent clients in the [adapter contract](adapter-contract.md#queries-catalogs-and-reads). Item generations retain their originally captured presentation instant/timezone while valid. Agent Control's accepted no-idle-expiry and no-admission-cap behavior remains in force.

## Q84 alternatives and impacts

A. Treat query generations as temporary cached results that can be discarded under a bounded retention policy, even without an edit. Reading a discarded generation returns the existing staleSnapshot failure. Native consumers restart from the query and discard partial pages; agent clients do the same. This controls retained captures with comparatively little code, but an old paged query may need restarting during an otherwise unchanged read-only workflow. A single large query and the dataset itself remain uncapped.

B. Preserve old-generation availability until a saved-data/ownership change, and spill older captures to local temporary storage. Clients can continue paging without a cache-eviction restart, and the in-memory cache can be smaller. This adds temporary serialization/storage, I/O failure handling, ownership isolation and cleanup work. These files are cache data, outside backups and iCloud-owned content.

C. Keep the current in-memory retention and lazy cleanup. Distinct generations remain available while their history/session stays valid. Captured buffers can remain until a later query/read removes stale bindings or the Core instance ends; an edit alone does not immediately release them all. This keeps paging availability and implementation simplicity. Retained captures have no count or memory bound; native/physical measurements must still establish acceptable behavior for the agreed workloads.

The initial recommendation was A. The human selected C. Distinct generations remain readable in the issuing Core instance while their dataset/session/history bindings remain valid. Issuing another query or the passage of time does not evict them. Saved-history changes still invalidate reads, with the existing lazy memory cleanup. A process restart does not retain query handles. No retained-result count or memory bound is promised. No code change is needed to adopt C.

## Definition of ready

The human has chosen C, and the public lifetime contract records it. The existing public Core probe provides a Calendar baseline with 100 distinct readable generations and an unchanged full backup. This decision does not authorize an agent access timeout, query size cap, data limit or early cache eviction.

## Required TDD and definition of done

Use the already accepted public Core query/read/store, actual MCP HTTP and native UI seams for further read qualification. Preserve readable oldest/newest generations while their bindings remain valid, complete identities and captured values, interleaved clients, ownership/history invalidation and unchanged backup data. Cover Calendar, Item and catalog pages. Stale retries must discard partial results, honor cancellation and keep a valid detail selection. An error cannot become a successful empty query.

Measure retained-result behavior through public reads with many distinct requests, separately from whole-process RAM, native moving-window loading and physical responsiveness. Pass affected strict lint, compilation and narrow regressions when implementation changes. Record original measurements, source/product hashes and remaining platform gates. This documentation-only decision adds no test invocations. No general memory, latency or whole-map completion claim follows from the baseline probe alone.
