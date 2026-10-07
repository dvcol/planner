Build a personal native planning application for iPhone, iPad, and macOS.

The app is initially intended to manage travel / city exploration — places to see, restaurants to try, shopping, trips and itineraries — but the underlying model must remain generic enough to work as a general “things I want to do” planner.

This is also a Swift learning project, so favor modern, idiomatic Apple APIs and a relatively simple architecture.

======================================================================
1. PRODUCT / TECHNOLOGY DECISIONS
======================================================================

Use:

- Swift
- SwiftUI
- One multiplatform app supporting:
  - iPhone
  - iPad
  - macOS
- SwiftData for local persistence.
- iCloud / CloudKit automatic synchronization through SwiftData.
- MapKit / MapKit for SwiftUI as the primary native map implementation.
- App Intents + App Entities for Siri, Shortcuts, Spotlight and Apple Intelligence integration.
- Share Extension / system sharing integration where appropriate.
- Modern Swift concurrency (async/await, actors where justified).
- The latest stable Apple APIs supported by the chosen deployment target.
- Latest Apple Human Interface Guidelines and current Liquid Glass design guidance.

Do NOT introduce:

- a custom web backend,
- Supabase/Firebase/Postgres,
- a bespoke REST API,
- React Native,
- Electron,
- a permanent background server,

unless a requirement genuinely cannot be solved by the Apple-native stack.

CloudKit is the synchronization backend for V1.

The app must work offline. SwiftData is the local source used by the UI; CloudKit synchronizes the user's private data between their Apple devices.

Design the SwiftData schema to be CloudKit-compatible from the beginning and migration-friendly.

Add a user-accessible JSON export/import mechanism eventually so the data is not locked exclusively inside CloudKit.

======================================================================
2. ARCHITECTURE
======================================================================

Keep business/domain logic independent from every control surface.

Use approximately this architecture:

                        PlannerCore
                    ┌─────────────────┐
                    │ Models          │
                    │ Repositories    │
                    │ Services        │
                    │ Commands        │
                    │ Search/filter   │
                    └────────┬────────┘
                             │
                    SwiftData / CloudKit
                             │
             ┌───────────────┼────────────────┐
             │               │                │
          SwiftUI        App Intents         MCP
             │               │                │
           Human       Apple ecosystem    Any agent

SwiftUI, App Intents and MCP MUST call the same domain services.

Do not duplicate operations such as:

- add item
- move item
- archive item
- mark item done
- schedule item
- add/remove list membership
- import a map URL

inside different integration layers.

For example:

    planner.addItem(...)
    planner.markDone(...)
    planner.archive(...)
    planner.move(...)
    planner.addToList(...)
    planner.schedule(...)
    planner.search(...)

should represent shared operations usable from SwiftUI, App Intents and MCP.

Prefer straightforward architecture over elaborate Clean Architecture ceremony.

======================================================================
3. CORE CONCEPT: TODO ITEM
======================================================================

The fundamental entity is a generic TODO / Place item.

It can represent:

- a restaurant
- a shop
- a museum
- a sightseeing location
- an activity
- a task
- something to buy
- an arbitrary place or thing to do

An item should support at minimum:

Identity:
- stable UUID
- createdAt
- updatedAt

Content:
- title
- optional subtitle
- notes / description

Status:
- active
- done
- archived
- optionally soft-deleted / trash separately from archive

Marking an item done should normally remove it from active lists and make it accessible from an Archive / Done section.

Archive and Delete must remain distinct concepts.

Support standard gestures:
- swipe to mark done/archive
- swipe/delete or context action to remove
- drag/reorder where appropriate
- move to another list
- add to another list

======================================================================
4. ADDRESSES / MAP LOCATIONS
======================================================================

An item may optionally contain a location.

Support:

- manually entered address
- latitude/longitude
- Apple Maps URL
- Google Maps URL
- imported Apple Maps location
- imported Google Maps location

Store enough provider-independent information to display the item without requiring the original map provider:

- display name
- formatted address
- latitude
- longitude

Also retain provider-specific information when available:

- original URL
- Apple Maps URL
- Google Maps URL
- provider identifier if safely available

Do not make Google Maps or Apple Maps lists the application's database.

The Planner owns its own structured place data.

======================================================================
5. LINKS
======================================================================

Each TODO can contain zero or more arbitrary links.

Examples:

- Tabelog
- Google Maps
- Apple Maps
- restaurant website
- museum website
- booking page
- Instagram
- article/reference
- arbitrary URL

Model links as proper child records rather than fixed URL columns.

A link should contain:

- URL
- optional label
- optional detected provider/type
- sort order

Automatically detect common providers when possible:

- Apple Maps
- Google Maps
- Tabelog
- website
- booking
- generic URL

But always permit arbitrary links.

======================================================================
6. EASY URL IMPORT
======================================================================

A core UX requirement is:

    paste/share a Google Maps or Apple Maps link
        ↓
    get a mostly completed TODO

Provide at least two entry points:

A. An "Import Link" field inside the app.

B. Share-sheet integration so that from Maps/Safari/etc. the user can:
   Share → Planner → choose destination list.

The importer should:

1. accept Apple Maps or Google Maps URLs
2. resolve redirects/shortened URLs when required
3. extract information available from the URL/documented API
4. derive or geocode coordinates/address where appropriate
5. pre-fill:
   - name
   - address
   - map provider link
   - coordinates
6. show a confirmation/edit screen before saving when information is uncertain

Do not rely on brittle scraping of Google Maps pages.

Preserve the original URL even when parsing is incomplete.

Design the importer as a service so additional providers can be added later.

======================================================================
7. TIME COMMITMENT / DURATION
======================================================================

Every TODO can optionally contain an estimated time commitment.

It should support human-friendly durations such as:

- minutes
- hours
- half day
- day
- multiple days
- weekend
- week
- month

Do not make duration a free-form string only.

Provide a normalized representation suitable for:

- filtering
- sorting
- calendar planning

while retaining a human-friendly representation.

Examples:

    30 min
    1 h
    2 h
    4 h
    half day
    full day
    2 days
    weekend
    1 week

The UI should make choosing common duration presets very fast.

======================================================================
8. CATEGORIES AND TAGS
======================================================================

Items support:

- one or more categories
- arbitrary tags

Typical categories include:

- sightseeing
- food
- shopping
- museum
- activity
- trip

Do not hardcode these so strongly that users cannot create their own.

Tags are free-form.

Examples:

    ceramics
    ramen
    modern-art
    rainy-day
    outdoor
    reservation-required
    expensive
    Tokyo
    Ginza

Both categories and tags must participate in search/filtering.
Both categories and tags can be associated with a color and icon.

======================================================================
9. LISTS
======================================================================

Users can create arbitrary Lists.

Examples:

    Tokyo Food
    Tokyo Shopping
    Things to do in Paris
    Ceramics
    Next Weekend
    Japan Wishlist

TODO ↔ List is MANY-TO-MANY.

A TODO can belong to several lists simultaneously.

The UI must clearly show when an item belongs to multiple lists.

Actions should include:

- Add to list
- Remove from list
- Move to list
- Add to another list

"Move" means replacing the relevant membership.

"Add to" means retaining existing memberships.

Removing an item from one list must NOT delete the item from other lists.

Deleting an item itself is a distinct operation.

======================================================================
10. DONE / ARCHIVE
======================================================================

Completion is principally an item-level state, not a list-level state.

If a restaurant is marked visited/done, it should be considered done regardless
of how many lists reference it.

Done items:

- disappear from the normal active view by default
- remain searchable if requested
- appear in an Archive / Done section
- remain referenced by past itineraries/calendar entries
- may be restored to active

Support very fast completion using swipe actions.

======================================================================
11. SEARCH AND FILTERING
======================================================================

Search is a first-class feature.

All lists should be searchable.

Support filtering by combinations of:

- text
- category
- tag
- status
- list membership
- duration/time commitment
- location / neighborhood when available
- has address
- has links
- done/not done
- scheduled/unscheduled

Filters should compose naturally.

Examples:

    Food + under 2 hours + active

    Shopping + Ginza + not done

    Museums + half-day-or-less

    Items not scheduled anywhere

Provide both:

- fast simple search
- a more advanced filter UI

Search should work across all lists as well as within one list.

======================================================================
12. MAP UI
======================================================================

Maps are a core secondary representation of TODO data.

Apple Maps:

- Use native MapKit / MapKit for SwiftUI.
- Display selected/list-filtered items as annotations.
- Selecting a map annotation selects the corresponding item.

Google Maps:

Support Google Maps as an optional alternate view.

Prefer documented integration mechanisms.

If a proper embedded Google map requires WebView or a provider SDK/API key,
isolate that implementation behind a MapProvider abstraction.

Do not compromise the otherwise-native app architecture merely to display Google Maps.

For V1, native Apple MapKit is the default.

For any item/link, offer actions such as:

    Show in Planner map
    Open in Apple Maps
    Open in Google Maps
    Open in embedded browser
    Open in default browser

======================================================================
13. SPLIT VIEW / EMBEDDED CONTENT
======================================================================

On iPad and macOS, take advantage of larger screens.

Use NavigationSplitView and other platform-native adaptive layouts.

A typical layout may be:

┌───────────────┬───────────────────────┬────────────────────┐
│ Lists         │ Items                 │ Map / Detail       │
│               │                       │                    │
│ Tokyo         │ Nezu Museum           │       MAP          │
│ Food          │ Ebimaru               │                    │
│ Shopping      │ SUSgallery            │                    │
└───────────────┴───────────────────────┴────────────────────┘

Allow the secondary/detail area to show:

- native Apple Map
- item detail
- linked webpage
- optional Google Map

For webpages, use the current native SwiftUI WebView/WebPage APIs when available
for the target rather than immediately wrapping WKWebView manually.

Clicking a link should let the user choose or configure behavior such as:

- open inside a sheet/inspector/slideover browser
- open in Safari/default browser
- open the corresponding native app

On iPhone, adapt this naturally to NavigationStack + sheets rather than
attempting to reproduce desktop split panes.

======================================================================
14. ITINERARIES
======================================================================

An Itinerary is intentionally NOT an entirely separate task system.

It is a meta-grouping over existing TODOs and Lists.

Its purpose is to group things that logically belong together.

Examples:

    Daikanyama + Nakameguro
    Kuramae → Kappabashi → Ueno
    Ginza morning
    Weekend in Hakone
    Three days in Kyoto

An itinerary can represent a:

- neighborhood
- city
- region
- country
- theme
- logical route
- time block

Typical time blocks:

- 2 hours
- 4 hours
- half day
- full day
- weekend
- several days
- week

An itinerary should have its own metadata:

- title
- notes
- links
- location/address where useful
- tags/categories
- estimated duration
- active/done/archive state

It contains ordered references to:

- Lists
and/or
- TODO items

Prefer references over duplicated data.

For example:

Tokyo East Day
    ├── Kuramae list
    ├── Kappabashi list
    └── Ueno list

Or:

Museum Morning
    ├── Nezu Museum
    ├── lunch option A
    └── lunch option B

Itinerary completion can derive useful progress from its children while still
having an explicit itinerary status.

Make reordering itinerary sections/items easy with drag and drop.

======================================================================
15. CALENDAR / SCHEDULING
======================================================================

Provide a planner Calendar view.

The calendar can contain references to either:

- individual TODO items
- complete Itineraries

A calendar entry should NOT duplicate the underlying TODO/itinerary.

Model it as a scheduling reference.

Support:

- start date
- optional start time
- optional end time
- all-day
- approximate/flexible slot if useful
- rescheduling by drag/drop where appropriate

Examples:

    Tuesday morning
        Toguri Museum

    Friday
        Kawagoe itinerary

    Fri-Sun
        Hakone itinerary

Initially, the Planner calendar is its own canonical planning calendar.

Design the model so optional EventKit / Apple Calendar integration can be added
cleanly, but do not make the user's Apple Calendar the application's primary database.

======================================================================
16. APP INTENTS / SIRI / SHORTCUTS / SYSTEM INTEGRATION
======================================================================

Use the modern App Intents framework, not legacy SiriKit, for new functionality.

Expose important domain entities through AppEntity where useful:

- TODO
- List
- Itinerary

Use stable identifiers across devices.

Where supported by the latest SDK, investigate and appropriately use:

- SyncableEntity
- current App Schema integrations
- modern App Shortcuts
- Spotlight integration
- Apple Intelligence integration
- interactive snippets where genuinely useful

Candidate App Intents:

- Add TODO
- Import URL
- Add place to list
- Mark TODO done
- Archive TODO
- Restore TODO
- Move TODO to list
- Add TODO to another list
- Search TODOs
- Show today's plan
- Schedule TODO
- Schedule itinerary
- Get unscheduled items
- Open list
- Open itinerary

Example interactions:

    "Add this restaurant to Tokyo Food"

    "Mark Ebimaru as done"

    "Show my shopping TODOs"

    "What's planned today?"

    "Add this place to my Ginza itinerary"

Expose only actions that make sense outside the main app UI.

Use App Shortcuts where supported, while recognizing that App Intents themselves
remain the important cross-platform abstraction.

======================================================================
17. SHARE EXTENSION
======================================================================

Provide an excellent Share Sheet workflow.

Primary use case:

    Apple Maps / Google Maps / Safari
        → Share
        → Planner
        → Add to...

The extension should accept at least:

- URL
- text containing URL
- plain text when sensible

Show a lightweight confirmation UI:

    Add "Nezu Museum"

    List:
        Tokyo Museums

    Categories:
        Sightseeing, Museum

    Duration:
        2 h

    [Add]

Do as little work in the extension process as practical; share domain/import
logic with PlannerCore.

======================================================================
18. AGENT CONTROL THROUGH MCP
======================================================================

The application needs a vendor-neutral agent interface in addition to Apple's
App Intents.

Implement MCP on the macOS target.

This is NOT a permanent server.

Agent control is intentionally punctual and user-authorized.

UX:

    Toolbar / menu:
        "Allow Agent Control…"

Opening this starts an ephemeral MCP session.

Default:

- localhost only
- Streamable HTTP MCP
- temporary random port or managed local port
- temporary session credential/token
- visible countdown/session state
- manual Stop button
- automatic timeout after inactivity

Possible choices:

    Allow for 15 minutes
    Allow for 30 minutes
    Allow for 1 hour

Optional explicit mode:

    Allow on Local Network

LAN exposure must NEVER happen silently.

Do not implement a public Internet endpoint in V1.

Do not implement a permanent LaunchAgent/daemon in V1.

Do not implement stdio MCP unless a real client compatibility requirement
appears later.

HTTP MCP is sufficient for the initial architecture.

======================================================================
19. MCP SECURITY
======================================================================

When Agent Control is off:

    no MCP listener exists.

When enabled:

localhost should be the default binding.

LAN access requires explicit user action.

Use an ephemeral high-entropy session credential.

Consider session capabilities such as:

    read
    edit
    destructive

Default agent session:

    read            allowed
    create/edit     allowed
    archive         allowed
    permanent delete NOT allowed

Destructive operations should either:

- not be exposed,
or
- require an explicit confirmation mechanism.

Display active agent access clearly in the Mac UI.

Display enough activity history to understand what changed.

Example:

    Agent activity

    11:42  searchItems("ceramics")
    11:43  addToList(item: ..., list: Tokyo Shopping)
    11:44  schedule(item: ..., date: tomorrow)
    11:45  markDone(item: ...)

Do not log secrets.

======================================================================
20. MCP TOOL SURFACE
======================================================================

Expose semantic domain operations, NOT UI automation.

Possible MCP tools:

READ:

    planner.get_lists
    planner.get_list
    planner.search_items
    planner.get_item
    planner.get_itinerary
    planner.get_calendar
    planner.get_today
    planner.get_unscheduled
    planner.get_archive

WRITE:

    planner.create_item
    planner.update_item
    planner.import_url
    planner.mark_done
    planner.archive_item
    planner.restore_item

    planner.add_to_list
    planner.remove_from_list
    planner.move_to_list

    planner.create_list
    planner.update_list

    planner.create_itinerary
    planner.update_itinerary
    planner.add_to_itinerary
    planner.reorder_itinerary

    planner.schedule
    planner.reschedule
    planner.unschedule

Prefer structured request/response schemas with stable IDs.

MCP must call PlannerCore, exactly as SwiftUI and App Intents do.

Do not make agents click SwiftUI controls.

======================================================================
21. LIQUID GLASS / SWIFTUI DESIGN
======================================================================

Use the current Apple design language rather than constructing a custom design system.

Prefer:

- native SwiftUI controls
- native navigation
- native sheets
- native context menus
- native toolbars
- native search
- native swipe actions
- native drag/drop
- native sidebars
- standard typography
- semantic system colors
- system spacing

Adopt the latest Liquid Glass behavior primarily by allowing native controls and
navigation containers to receive their system appearance automatically.

Do not put arbitrary glass panels behind every piece of content.

Use explicit glass effects only where they improve hierarchy or interaction.

Use the latest appropriate APIs such as current:

- Liquid Glass effects
- toolbar organization
- toolbar spacers/grouping
- search presentation
- tab behavior
- WebView/WebPage
- swipe actions
- drag/reordering APIs
- inspectors/sheets/presentation APIs

when they improve the app.

The app should look like a high-quality current Apple application, not like a
web dashboard recreated in SwiftUI.

======================================================================
22. PLATFORM-SPECIFIC UX
======================================================================

iPhone:

- NavigationStack-oriented
- bottom tabs only if they genuinely improve navigation
- excellent swipe gestures
- sheets for quick editing
- map can become a full-screen mode
- quick "Add" and "Share to Planner" workflows

iPad:

- NavigationSplitView
- list + content + map/detail where space allows
- inspector/slideover for item details/web content where appropriate
- drag/drop is important

macOS:

- NavigationSplitView/sidebar
- keyboard shortcuts
- menu commands
- toolbar
- context menus
- multi-selection where useful
- efficient search/filter UI
- large map/detail pane
- Agent Control entry point
- optional Table presentation where it materially improves dense list management

Share the overwhelming majority of domain and SwiftUI code while allowing
platform-specific presentation where Apple conventions differ.

Do not force pixel-identical UI across platforms.

======================================================================
23. CORE SCREENS
======================================================================

Design at least:

1. Today / Calendar

2. Lists
   - sidebar of lists
   - selected list contents
   - search/filter controls
   - map/detail pane on large devices

3. All TODOs

4. Itineraries

5. Map

6. Archive / Done

7. Item detail/edit

8. Itinerary detail/edit

9. Import Place/URL

10. Agent Control
    macOS only

======================================================================
24. ITEM DETAIL
======================================================================

An item detail screen should make the most important information immediately
accessible:

- title
- done status
- address
- map
- duration
- categories/tags
- lists containing this item
- notes
- links
- schedule
- itinerary memberships

Quick actions:

- Done
- Schedule
- Add to list
- Move
- Map
- Open link
- Edit

Avoid overwhelming the UI with rarely used fields.

Use progressive disclosure.

======================================================================
25. SEARCH-FIRST UX
======================================================================

This database may eventually contain hundreds or thousands of places.

Do not design assuming the user navigates exclusively through manually curated lists.

Global search should be immediately accessible.

The user should be able to type:

    ramen

and then filter:

    Tokyo
    active
    <= 2 hours
    food

or:

    ceramics
    shopping
    not done

Search and filters should operate over the common domain model, not implement
separate custom search logic per screen.

======================================================================
26. MODELING GUIDELINES
======================================================================

Aim for entities approximately equivalent to:

TodoItem
List
ListMembership
Category
Tag
ItemTag
Link
Location
Itinerary
ItineraryEntry
ScheduleEntry

Do not blindly implement this exact schema if SwiftData makes another model
cleaner.

Important semantics:

TODO ↔ List = many-to-many.

TODO ↔ Tag = many-to-many.

ScheduleEntry references its source object rather than cloning it.

ItineraryEntry references an existing TODO/List/possibly nested itinerary rather
than copying it.

Stable IDs are mandatory.

Persist ordering explicitly where user-controlled ordering exists.

Use enums carefully with SwiftData/CloudKit compatibility in mind.

======================================================================
27. PERFORMANCE / DATA OWNERSHIP
======================================================================

Expected scale is modest:

- hundreds to a few thousand TODOs
- dozens/hundreds of lists
- many links/tags/memberships

Optimize for correctness, responsiveness and maintainability rather than extreme scale.

No network connection should be required to browse existing data.

CloudKit sync can happen asynchronously.

The UI should optimistically use local SwiftData state.

======================================================================
28. TESTING
======================================================================

Keep domain logic highly testable without rendering SwiftUI.

Add unit tests for at least:

- list membership semantics
- move vs add-to-list
- archive/restore
- completion
- scheduling
- duration filtering
- category/tag filtering
- search
- itinerary membership/order
- URL provider detection
- map URL import parsing

Add integration tests where appropriate for persistence.

Add UI tests for critical workflows, especially:

- add item
- import shared URL
- swipe done/archive
- move between lists
- filter/search
- schedule item
- build itinerary

MCP tool handlers should also have tests against the same PlannerCore services.

======================================================================
29. IMPLEMENTATION STRATEGY
======================================================================

Do not attempt every feature at once.

First inspect the latest stable Apple SDK/documentation and confirm the current
recommended APIs for:

- SwiftUI / Liquid Glass
- SwiftData + CloudKit
- MapKit for SwiftUI
- WebView/WebPage
- App Intents / App Entities / App Schema
- Siri / Shortcuts / Spotlight integration
- Share extensions
- macOS local networking
- MCP Swift SDK / current MCP Streamable HTTP specification

Then propose a compact architecture and implementation plan before writing a large
amount of code.

Build a vertical slice first:

V0:

    TodoItem
        ↓
    SwiftData
        ↓
    List
        ↓
    searchable SwiftUI list
        ↓
    add/edit
        ↓
    mark done/archive
        ↓
    iCloud sync

Then:

V1:
    locations
    map
    arbitrary links
    categories/tags
    duration
    many-to-many lists
    filters

V2:
    Apple/Google Maps link import
    Share Extension
    Itineraries
    Calendar

V3:
    App Intents
    Siri/Shortcuts/Spotlight
    MCP temporary Agent Control

Do not let V3 architectural requirements distort the simple V0 domain model,
but keep PlannerCore independent enough that integrations can reuse it.

======================================================================
30. PRINCIPLES
======================================================================

The app should feel:

- native
- fast
- calm
- spatial
- low maintenance
- useful with very little data entry

A user should be able to save a place from Maps in a few seconds.

A user should be able to see:

    What can I do today?
    What's near here?
    What have I not done yet?
    What fits into two hours?
    What food places are on my list?
    What was I planning for this neighborhood?

without performing project-management work.

The software exists to make doing things easier, not to create another system
that needs constant upkeep.

Favor Apple platform conventions and system capabilities over custom components.

Favor semantic operations over UI automation.

Favor simple native synchronization over backend infrastructure.

Favor references/composition over duplicated data.

Favor progressive complexity: the initial app should remain useful even before
Itineraries, Calendar, App Intents and MCP are complete.