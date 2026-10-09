# Planner

Planner organizes one person's things to do and places to keep, then groups and schedules them across their devices.

## Language

**Item**:
A thing to do, buy, or keep for planning, optionally describing a place. Its shared content and archive state are referenced across plans; completion has global and contextual meanings.

**List**:
A named collection of items with its own archive state and completion derived from its children in that list. An item can belong to several lists.

**Membership**:
The association of one item with one list, including that item's local completion context. There is at most one membership for a given item/list pair. Removing a membership leaves the item intact.

**Add to a list**:
Create a reference to a shared item in another list while retaining its existing memberships. A new membership starts locally todo; an existing destination membership keeps its state.

**Move between lists**:
Remove the selected membership and add a reference to the same item in the destination list. A new destination membership starts locally todo; an existing one retains its state, and unrelated references remain intact.

**Completion state**:
Whether an item is todo or done globally or in a planning context. Lists and itineraries derive their completion from their contextual child items.

**Global completion**:
The completion of an item itself. A globally done item appears done in every context; globally reopening it reveals the retained local states.

**Contextual completion**:
An item appearance's local completion within a list or itinerary, independently of its global completion and other appearances. It starts todo. Repeated itinerary appearances have separate local states; a source list's local completion does not determine them.

**Effective completion**:
The completion shown for an item within a list or itinerary. It is done when the item is globally done or locally done in that context.

**Progress**:
The number of effectively done item appearances out of all item appearances in a list or itinerary. Repeated appearances count separately; a referenced list contributes its child items, not an extra container count. A nonempty container is completed only when every child appearance is effectively done. An empty container has no completion percentage and is not completed.

**Todo**:
An unfinished item or contextual item reference. A list or itinerary is unfinished when its contextual children do not make it completed.

**Done**:
A completed item or contextual item reference. A nonempty list or itinerary is completed when all its contextual child items are effectively done.

**Archive state**:
Whether an item, list or itinerary is active or archived, independently of its completion state.

**Active**:
An item, list or itinerary that is not archived. It can be todo or done.
_Avoid_: Using active to mean todo.

**Archived**:
An item, list or itinerary put away from ordinary planning views while retaining its content and references. It can be todo or done.
_Avoid_: Deleted.

**Permanent deletion**:
Removal of an entity and its references from the planner. Deleting a container leaves its referenced source items and lists intact.

**Recovery copy**:
A locally retained copy of saved Planner data that remains recoverable independently of the current iCloud account's mirrored data.

**Backup**:
A portable snapshot of Planner content, identities, references, completion, saved order and schedules. It includes minimal deletion history without deleted content, and excludes a device's presentation or navigation state.

**Agent Control**:
A deliberately enabled access window in which local agents can read and change ordinary Planner data until Stop or app quit. Backup, export, import and account-recovery administration remain manual Planner workflows.

**Agent access window**:
The period during which Agent Control permits authorized agent requests, ending on Stop or app quit, with no maximum duration or idle expiry. It continues through lock, sleep and last-window closure while Planner remains running. It is independent of an MCP protocol connection or session.

**Import conflict**:
A difference between incoming and current data for one Planner identity, including an identity kept deleted. A required reference to skipped deleted data can also prevent an incoming owner from being imported.

**Skip**:
The default import choice. Keep current conflicted data and omit owners blocked by its dependencies, while importing eligible independent data.

**Overwrite**:
The reviewed import choice that replaces represented data with incoming data, including container contents. Explicitly confirmed restoration is allowed; absence from a backup does not delete current entities.

**Recovery incomplete**:
A complete action has been applied locally but its independent recovery copy is not established. The action is retained; further changes in that dataset wait for recovery, and the save is not yet fully acknowledged.

**Unverified operation**:
A preserved proposal whose applied outcome cannot be established from surviving evidence. It requires explicit review before recovery rather than an assumed success or failure.

**Inbox**:
A view of items with no list memberships.

**All Items**:
A view across list memberships, including items that belong to no list.

**Category**:
A shared user-defined classification, such as food or museum, referenced by items and itineraries. Editing it updates every use. Different categories may have the same name while retaining distinct identities.

**Tag**:
A shared free-form label, such as rainy-day or ceramics, referenced by items and itineraries. Editing it updates every use. Different tags may have the same name while retaining distinct identities.

**Capture**:
Turning pasted or shared links or independent text into a reviewed draft, then creating an item or reusing an existing one.

**Capture draft**:
An unsaved, editable proposal to create an item or add references to an existing item. Cancelling it does not change the planner.

**Provider preview**:
Temporary place information supplied by a Maps provider alongside a captured link. It does not become stored item content.

**Link**:
A URL associated with an item or itinerary, with an optional label and provider description.

**Location**:
Optional place information associated with an item or itinerary, such as a name, address, or coordinates.

**Itinerary**:
A named, ordered plan with live references to existing items and lists. It has its own metadata and archive state, with completion derived from its contextual children.

**Itinerary entry**:
An ordered live reference within an itinerary to an existing item or list. Multiple entries may reference one source. An item entry has its own local completion; a list entry derives completion from its child appearances in that entry.

**Schedule entry**:
One planning date or time assignment referencing an existing item or itinerary in Planner's calendar. Several entries can reference the same source.

**All-day schedule**:
A schedule entry assigned to one date or an inclusive date range without clock times. Its dates stay unchanged across travel.

**Timed schedule**:
A schedule entry with a start date and time, and an optional end that must be a later instant when supplied.

**Planning timezone**:
The timezone associated with a timed schedule's date and clock time. It stays associated with the schedule when the device changes timezone. Changing only this zone preserves the appointment's actual instants.

**Display timezone**:
The timezone used to show timed entries on Planner's calendar. Changing it does not reschedule entries or change all-day dates.

**Duration estimate**:
An optional estimate of the time an activity takes. It can be compared with other estimates without scheduling the activity.
_Avoid_: Treating an estimate as a scheduled start or end.

**Item Last updated**:
When the item's own content, label associations, global completion or archive state last changed. Organizing or completing its references, or editing a shared label, does not change this value.

**Calendar span**:
A scheduled period in Planner's calendar, described by dates or a timed start with an optional end. It describes when an item or itinerary is planned.
_Avoid_: Using an activity estimate as a substitute for its calendar span.
