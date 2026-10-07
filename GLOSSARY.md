# Planner

Planner organizes one person's things to do and places to keep, then groups and schedules them across their devices.

## Language

**Item**:
A thing to do, buy, or keep for planning, optionally describing a place. It has one completion state and a separate archive state wherever it is referenced.

**List**:
A named collection of items. An item can belong to several lists.

**Membership**:
The association of one item with one list. Removing a membership leaves the item intact.

**Completion state**:
Whether an item is todo or done. Completion belongs to the item across all its lists.

**Todo**:
An item that has not been completed. It can be active or archived.

**Done**:
An item that has been completed. It can be active or archived.

**Archive state**:
Whether an item is active or archived, independently of its completion state.

**Active**:
An item that is not archived. It can be todo or done.
_Avoid_: Using active to mean todo.

**Archived**:
An item put away from ordinary planning views while retaining its content and references. It can be todo or done.
_Avoid_: Deleted.

**Inbox**:
A view of items with no list memberships.

**All Items**:
A view across list memberships, including items that belong to no list.

**Category**:
A shared user-defined classification, such as food or museum, referenced by items and itineraries. Editing it updates every use.

**Tag**:
A shared free-form label, such as rainy-day or ceramics, referenced by items and itineraries. Editing it updates every use.

**Link**:
A URL associated with an item or itinerary, with an optional label and provider description.

**Location**:
Optional place information associated with an item or itinerary, such as a name, address, or coordinates.

**Itinerary**:
A named, ordered plan referencing existing items and lists. It has its own metadata and explicit status.

**Itinerary entry**:
An ordered reference within an itinerary to an existing item or list.

**Schedule entry**:
A planning date or time assignment referencing an existing item or itinerary in Planner's calendar.

**Duration estimate**:
An optional estimate of the time an activity takes. It can be compared with other estimates without scheduling the activity.
_Avoid_: Treating an estimate as a scheduled start or end.

**Calendar span**:
The start and end of a scheduled period in Planner's calendar. It describes when an item or itinerary is planned.
_Avoid_: Using an activity estimate as a substitute for its calendar span.
