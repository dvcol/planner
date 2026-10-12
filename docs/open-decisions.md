# Open decisions

This is the current unanswered question register after the 12 October 2026 reprint. Recommendations remain pending until the human chooses them. Q53–Q56 and Q59–Q71 are settled; fixed estimate conversions are settled too. Historical prototype entries that still call those questions pending are older execution records.

Some earlier prompts reused Q48/Q49 and changed Q51's option lettering. This register keeps one meaning per number. Q74 names the duration-layout choice previously restated as Q48; Q49 retains its original editor-placement meaning. Q51 uses the latest choices, with B recommended.

## Q48: Changing an estimate's unit

Context: One estimate year means 365 days; an estimate month means 30 days. Selecting Months for one year can change either its representation or its duration.

- A, recommended: preserve exact duration, displaying twelve months plus five days. Quantity edits change the estimate; unit selection changes its representation.
- B: preserve the displayed quantity, changing one year to one month. Unit selection itself changes the duration.

## Q49: Estimate editor placement

Context: Native Item editing has one guarded Save/Cancel and an explicit No estimate choice.

- A, recommended: inline Activity estimate section in the grouped Item form. It stays with other fields but lengthens the form.
- B: separate native duration editor returning a staged value to the same Item draft. It shortens the form but adds navigation; main Save/Cancel still controls the whole edit.

## Q51: Editing an address with a saved pin

Context: Owned coordinates may identify a deliberate meeting point. Changing an address can leave that pin stale; temporary lookup never silently replaces owned coordinates.

- A: changing the address clears coordinates on Save; name-only edits retain them. This prevents stale pins but removes one automatically.
- B, recommended: explicit staged Keep saved pin / Remove saved pin choice under the same Save/Cancel. Deliberate pins survive unless explicitly removed.
- C: defer pinned-address editing until a full pin editor exists. That workflow remains unavailable.

## Q52: Controlled native preview host

Context: The accepted production preview/provider boundary needs repeatable image, no-image, error, ambiguous-address and delayed-response UI journeys.

- A, recommended: dedicated fixture app and Xcode scheme using production views with controlled providers. It isolates fixture work but adds a target/scheme.
- B: Debug-only main-app fixture launch mode with isolated data. It reuses the target but adds a Debug fixture path.
- C: provider tests and live native journeys. Controlled ambiguity/error/delay UI qualification remains open.

## Q57: Zero-match referenced List groups

Context: An itinerary references a List with three children, all hidden by cumulative filters. Filtering changes neither saved route structure nor full progress.

- A, recommended: keep the header in route order with full progress and Showing 0 of 3 items. A truly empty List shows No items.
- B: hide the entire group until a child matches or filters are cleared. Results shorten but the visible route changes with filtering.

## Q58: Native loading fixture

Context: Real saved data must qualify traversal, selection and refresh. The required 5,000-Item/200-List performance gate remains separate from a small fixture.

- A: isolated host creates the large dataset through public Core commands, records IDs, then runs production UI tests. It reaches scale earlier with more fixture setup.
- B, recommended: create forty Items and four Lists through native controls first. Qualify bounded traversal/selection/refresh while retaining the large-data gate.
- C: wait for manual import to load the large fixture with original identities. Loading qualification depends on import completion.

## Q72: An archived container's own progress

Context: Archiving preserves child global/local Done flags. An archived List branch already counts as finished inside an itinerary. The open choice concerns the archived container's own view.

- A, recommended: derive its children as finished with zero remaining, restoring child-based progress on unarchive. Its full estimate remains intact; empty still means No items and not completed.
- B: retain child-based own progress while showing zero remaining because the container is archived. This differs from how its branch counts in another itinerary.

## Q73: Imported records with an omitted owner

Context: Incoming links/schedules name existing Item X but omit X's source record. External binding admission is settled; whole-owner Skip/Overwrite does not yet define the mutation policy for this partial owner.

- A, recommended: preserve X and its owned records in both modes, report incoming owned records as skipped and import independent sources. Replacing X requires its source record in the file.
- B: Skip preserves X; Overwrite replaces owned collections while retaining current source fields. Missing-collection/removal semantics need a subsequent decision.
- C: reject the whole review. New Lists using an existing external Item remain valid; unrelated incoming data cannot import from the rejected file.

## Q74: Native duration control layout

Context: Estimates have one-minute precision and use native controls without raw numeric text input. Existing 125 minutes must remain exactly representable.

- A, recommended: unit/count controls with exact smaller-unit remainders, such as two hours plus five minutes. The editor stays compact.
- B: every unit count visible simultaneously. It takes more space and needs clear representation rules.
- C: whole units in the selected unit, requiring an explicit smaller-unit conversion for otherwise unrepresentable values. It uses fewer controls but adds editing steps.
