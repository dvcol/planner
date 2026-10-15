# Atomic ordinary Item creation in a List

Status: proposed Q93 contract. Q88 approves the behavior; this public command extension still needs review before its /tdd implementation.

## Context and starting state

New Item currently uses `createItem(content:)`, which preserves authored bookmarks but creates no membership. `addMembership` is another saved operation. Q88 requires creating the source and its originating List appearance together. The proposed native adapter initially reused Capture, but Capture deliberately deduplicates exact original URLs. Ordinary authored bookmarks can repeat the same URL with distinct identities and labels. Reusing Capture would silently discard those records and cannot meet the existing content contract.

## Goal and expected end state

Extend the existing command to `createItem(content: PlannerItemContentInput, listId: UUID? = nil)`. Omitting the destination retains existing ordinary global creation. A supplied destination creates the same ordinary Item plus one membership at the end of that List, locally Todo, in one local transaction. Preserve authored content, repeated URL records, link order and generated identities. The operation does not edit existing Items or any other container.

The writer resolves and validates the destination's current identity/lifetime under the existing mutation coordination. For a new operation, a missing, deleted or archived List rejects the entire operation before saving a source, membership, links or receipt. Existing Category/Tag and content validation stays intact. A failed local persistence transaction leaves the whole operation unapplied. Successful local save followed by incomplete independent recovery remains applied and reports Recovery incomplete under the existing contract.

Native drafts retain the originating List's opaque name-field hash from the existing source read. Support `prepareReview` for destination-bearing createItem commands, returning an item-creation review with the resolved List binding and name-field hash in its review digest. Before applying that review, native creation re-reads the List and compares its name hash with the draft's original hash. Because that hash includes the source lifetime, rename or replacement requires explicit refreshed destination review. The subsequent review-token validation atomically rejects a destination lifetime or name-hash change after that comparison. A List's unrelated membership changes do not silently change the destination or require a new content draft. Retain the authored fields when destination review needs refreshing. Agents never supply raw lifetime identifiers; unreviewed commands resolve the currently live destination under writer coordination, while callers may use the existing review-token workflow for reviewed binding. Test deletion/restoration both before and after review so this guarantee is proven rather than inferred from UUID equality.

The operation identity covers the destination and resolved lifetime as well as content. Replay returns the same source, link and membership identities without duplicating or re-adding a later removed membership. Reusing an applied operation identity with a different destination fails as a payload mismatch. For destination-free commands, retain the existing canonical payload representation and replay compatibility. No schema change or saved draft is introduced.

Expose the same optional `listId` in the existing MCP createItem command and its schema. Omission or null means no destination; a non-null value must be a valid UUID for a live active List. Existing callers retain their default behavior. Native ordinary creation uses this command; Capture keeps its accepted URL deduplication and review workflow. This adds no backup/admin agent action or new scheduling behavior.

## Definition of ready

- User approves this concrete public contract after Q88's accepted native behavior.
- Existing ordinary creation, membership ordering/lifetimes, operation receipts, independent recovery and Capture deduplication are inspected together.
- Tests use the already approved public Planner command/read, real persistence I/O failure and MCP HTTP boundaries. Native UI tests use actual production forms and local datasets. No test-only production parameter is added.

## Required tests in /tdd

1. From one active empty List, execute ordinary rich creation with two differently labeled bookmarks sharing an exact URL. Read one source with both distinct link identities in saved order and one local Todo membership. Another List remains unchanged. Relaunch and replay retain the same graph and identities.
2. Omit the destination and preserve existing ordinary creation behavior and receipt compatibility. Change the supplied destination on an applied operation identity and reject without extra data. Remove its membership, replay, and do not recreate that removed reference.
3. Missing/deleted/archived destinations, stale lifetime, invalid content or labels and local save failure create neither source nor membership nor partial links/receipt. Verify the real persistence failure boundary and the existing distinct incomplete-recovery outcome.
4. Real MCP HTTP accepts omitted/null and valid destination values, rejects invalid values explicitly, and returns the same ordinary source/reference identities. Existing command defaults and Capture's distinct deduplication remain compatible.
5. Native List Add > New Item preserves rich fields, duplicate authored bookmarks and original destination through Save, Cancel, invalid input, navigation and relaunch. Add existing and From Link or Text retain their established semantics.

## Definition of done

Witness a failing public-boundary test before each implementation slice. Pass focused Core, real HTTP and native compatibility checks, strict affected Swift/Markdown lint and compiler checks. Record source epochs and actual runtime evidence. Commit the command/native integration in logical steps, update the map, and leave unrelated signing, physical sync/account/Share, accessibility, performance and final UI polish gates open.
