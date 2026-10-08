# Planner

Planner organizes one person's things to do and places to keep, then groups and schedules them across their devices.

## Language

**Item**:
A thing to do, buy, or keep for planning, optionally describing a place. Its shared content and archive state are referenced across plans; completion has global and contextual meanings.

**List**:
A named collection of items with its own archive state and completion derived from its children in that list. An item can belong to several lists.

**Membership**:
The association of one item with one list, including that item's local completion context. There is at most one membership for a given item/list pair. Removing a membership leaves the item intact.

**Completion state**:
Whether an item is todo or done globally or in a planning context. Lists and itineraries derive their completion from their contextual child items.

**Global completion**:
The completion of an item itself. A globally done item appears done in every context; globally reopening it reveals the retained local states.

**Contextual completion**:
An item's local completion within a list or itinerary, independently of its global completion and other contexts. It starts todo. All appearances of an item within one itinerary share that contextual state; a source list's local completion does not determine it.

**Effective completion**:
The completion shown for an item within a list or itinerary. It is done when the item is globally done or locally done in that context.

**Progress**:
The number of effectively done items out of the unique items currently reachable in a list or itinerary. Repeated appearances count once. An empty container has no completion percentage and is not completed.

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

**Inbox**:
A view of items with no list memberships.

**All Items**:
A view across list memberships, including items that belong to no list.

**Category**:
A shared user-defined classification, such as food or museum, referenced by items and itineraries. Editing it updates every use. Different categories may have the same name while retaining distinct identities.

**Tag**:
A shared free-form label, such as rainy-day or ceramics, referenced by items and itineraries. Editing it updates every use. Different tags may have the same name while retaining distinct identities.

**Link**:
A URL associated with an item or itinerary, with an optional label and provider description.

**Location**:
Optional place information associated with an item or itinerary, such as a name, address, or coordinates.

**Itinerary**:
A named, ordered plan with live references to existing items and lists. It has its own metadata and archive state, with completion derived from its contextual children.

**Itinerary entry**:
An ordered live reference within an itinerary to an existing item or list. Completion is interpreted within that itinerary's context.

**Schedule entry**:
One planning date or time assignment referencing an existing item or itinerary in Planner's calendar. Several entries can reference the same source.

**All-day schedule**:
A schedule entry assigned to a date or date range without clock times.

**Timed schedule**:
A schedule entry with a start date and time, and an optional end.

**Duration estimate**:
An optional estimate of the time an activity takes. It can be compared with other estimates without scheduling the activity.
_Avoid_: Treating an estimate as a scheduled start or end.

**Calendar span**:
A scheduled period in Planner's calendar, described by dates or a timed start with an optional end. It describes when an item or itinerary is planned.
_Avoid_: Using an activity estimate as a substitute for its calendar span.
