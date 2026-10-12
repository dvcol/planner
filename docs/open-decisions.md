# Decision register

The human settled this batch on 12 October 2026. None of the nine questions below remains unanswered. Accepted behavior is a requirement, not evidence that its implementation or native qualification is complete. Earlier execution records that describe these choices as pending are historical.

Earlier prompts reused Q48/Q49 and changed Q51's option lettering. This register keeps one meaning per number. Q74 is the duration-layout choice previously restated as Q48; Q49 retains its original editor-placement meaning.

| Question | Accepted choice | Required behavior and impact |
| --- | --- | --- |
| Q48, estimate unit changes | A | Preserve exact duration. One 365-day year displayed as months is twelve 30-day months plus five days. Unit selection changes representation; quantity edits change the value. |
| Q49, estimate editor | A | Inline Activity estimate section in the native grouped Item form, governed by the Item's existing Save/Cancel and No estimate choice. |
| Q51, editing a pinned address | B | Explicit staged Keep saved pin / Remove saved pin choice under the same Save/Cancel. Automatic lookup never silently replaces owned coordinates. |
| Q52, controlled preview testing | A | Dedicated fixture app and Xcode scheme using production views with controlled providers. Image/no-image/error, address ambiguity and delayed-result native journeys remain required. |
| Q57, referenced List filtering | Human refinement | Show the List group when the List itself matches the cumulative filters or at least one child matches. Hide it when neither matches. A matching List can remain visible with zero matching children. Filters never change full progress or saved route order. |
| Q58, loading fixture | B | First create forty Items and four Lists through native controls and test traversal, selection and refresh. Keep the separate 5,000-Item/200-List performance gate. |
| Q72, archived container's own progress | B | Keep its own child-based progress while showing zero remaining time because the container is archived. Its archived branch still counts as finished in a parent itinerary. Preserve child Done flags and the full estimate. |
| Q73, import with omitted source owner | A | Preserve the omitted owner and its owned records in both Skip and Overwrite. Report incoming owned records as skipped; import independent sources. Replacing an owner requires its source record in the file. New declared Lists referencing existing external Items remain valid. |
| Q74, native duration controls | A | Unit/count controls with exact smaller-unit remainders, such as two hours plus five minutes. Preserve one-minute precision and use native controls without raw numeric text input. |

Required /tdd coverage belongs to each affected feature's definition of done. These answers unlock that work; they do not close import application/restoration, native preview/loading, aggregate/calendar, physical sync/account/Share or whole-app polish gates.

## Q75, List-header filter applicability

The human accepted A on 12 October 2026. Every selected criterion applies when evaluating the List header's own match. An active Item-only restriction makes that header match false because Lists do not own those fields; a matching child can still keep the group visible. For example, searching Tokyo Food with a Rainy day Tag restriction hides that group when no child matches both criteria. The [native itinerary filter slice](prototypes/native-itinerary-filters.md) retains the required tests. Matching headers may have zero matching children; they never reveal children that fail the filters. No question in this recorded frontier remains unanswered.
