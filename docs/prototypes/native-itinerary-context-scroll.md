# Itinerary context while scrolling on iPad

## Scope

Keep the current itinerary identifiable in a narrow iPad collection pane after scrolling and rotation. Reuse the approved native UI boundary and the existing 132-appearance route fixture. Preserve the accepted single native title on iPhone and the existing Mac presentation. No saved-data, public API or signing change is needed.

## Reproduction and diagnosis

The first compile attempt starts no tests because its accessibility query uses an element where a query is required. The corrected tracer runs on unchanged production and fails after scrolling to Window Activity 020. Its original screenshot shows Filters, Add, More and search, but no itinerary name. The navigation bar retains the Windowed route identifier while its visible title is absent. The content heading has scrolled away.

Evidence is retained in the runtime failure. The earlier compilation failure is separately retained and receives no runtime credit.

Ranked predictions before the production probe:

1. A normal heading row scrolls away while the narrow native bar has no room for its replacement. Keeping the existing heading in a native safe-area inset should preserve context.
2. Search and toolbar actions consume the title space independently of scrolling. If the inset also disappears, investigate their layout separately.
3. Refresh replaces the navigation context. If this is the cause, the context may disappear again after rotation despite a pinned heading.

The first probe moves only the existing iPad heading out of the scrolling rows and into a top safe-area inset. The remaining summary stays in the native List. Phone and Mac keep their existing title treatment. The tracer stays unchanged for its first correction run.

## First correction and regressions

The unchanged tracer passes in 50.920 seconds. The source comparison records that only SavedItineraryViews changed among its 1,160 captured inputs. Original portrait and landscape screenshots show the readable heading after scrolling. Add opens and cancels normally; the same activity appearance survives both rotations.

The existing title test now locates the readable heading by its accessibility identity rather than requiring it to be a List row. Its full-name and native-action checks remain. The dark-iPad cohort passes three functions with no skips, including List/Map title and Add/Cancel, repeated-List collapse with preserved selected detail and completion, and the new scrolling/rotation check. The Mac app/Share build also passes, with no Mac interaction credit.

## Final local checkpoint

The final input/product verification reconciles all 1,160 inputs across the Mac build and seven passing mobile executions. Three light-phone regressions retain one native title through List/Map/List, native Add/Cancel and repeated-stop completion/detail state. The unchanged new iPad scrolling test also passes in light mode, and the original dark appearance is restored. All final mobile executions have zero failures and skips. Strict formatting passes the three affected Swift files; Markdown lint and whitespace checks pass.

Eight unchanged original screenshots are retained and visually inspected, including the actual failure, scrolled dark portrait/landscape, dark collection/Map, phone List/Map and light landscape. Duplicate-export cleanup removes five temporary export directories totaling 18,779,744 nominal bytes. Original result bundles, selected images and every failed test input remain. This does not measure APFS free-space gain.

This correction adds fourteen lines to the existing view and no new component, package or data logic. Full native-bar title truncation, long-title/accessibility extremes, actual Mac interaction and final whole-app visual acceptance retain their separate gates. Core and HTTP tests are not repeated for this presentation-only change.

## Long-name accessibility follow-up

The next tracer uses the native editor to save a 100-character itinerary name, then checks its route at the largest accessibility text size in portrait and landscape. Its first attempt fails during title replacement, before checking layout. Replacing that input interaction with the existing native Select All pattern reaches a real layout failure: the full heading occupies nearly the entire pane and thirty native scrolls cannot reveal a full expanded activity row. The original screenshot and failed result remain retained.

Ranked causes are an unbounded pinned heading, gestures landing on the oversized heading, and an overscrolling driver. The first correction bounds only the accessibility heading to one third of the measured viewport. Native ViewThatFits keeps a short heading fitted; a native ScrollView lets a long name remain readable inside the bounded area. The route keeps its independent native scrolling and all saved state. The failing tracer stays unchanged for this production probe.

The bounded production probe reaches the previously unavailable activity row. Its next assertion fails because the full text bounds extend beyond the clipped scroll area. The corrected observation checks the visible native scroll area and actually scrolls the name to its ending while keeping the activity hittable. A second context assertion also needs the visible intersection rather than requiring an offscreen text center to be hittable after rotation. Original captures show the name ending and the usable route; these driver corrections do not change production.

The long-name journey then passes both orientations. Its companion short-name test initially selects a different repeated Activity 020 through its forward-only title search after rotation. Keep that failed cohort. The test now locates the original public appearance identity and uses native scrolling to reveal it, rather than choosing another occurrence by name. This qualifies identity availability and heading layout; it does not claim automatic preservation of an unselected row's exact scroll offset.

Both largest-text journeys pass after that correction. Visual review still shows extra reserved space around the short heading: the outer maximum-height frame expands even when ViewThatFits chooses its shorter child. The final layout removes that chooser. It measures the native Text height and gives its native ScrollView the smaller of that height and one third of the viewport. Short names fit their text; long names remain independently scrollable. The existing accessibility tests are unchanged for its first execution.

The fitted short-name test passes. Its long-name companion reports overlap once, while a recording-derived failure frame shows a separated heading and activity. An unchanged production rerun passes the complete long-name journey. Retain that intermittent failure without assigning it to signing or declaring a persistent app defect. The final test waits up to five seconds for actual native bounds to separate and includes all relevant frames on failure; it adds no fixed sleep or production hook.

## Fitted accessibility checkpoint

The final verification reconciles all 1,160 inputs across six passing mobile executions and the matching Mac app/Share build. Two largest-text iPad functions cover long-name scrolling, fitted short-name spacing, both orientations and the exact original repeated stop. Three normal-size iPad regressions cover heading/rotation, repeated-List collapse and completion/detail state, and native title/Add/Map controls. The final light-phone function retains one native title through List/Map/List and Add/Cancel. Every final execution has zero failures and skips; the original text-size setting is restored.

Inspected final originals show the long name's ending above usable activities and the fitted short name in landscape. The earlier failures and their native results remain retained. Strict formatting and native compilation cover the two affected Swift files. Markdown lint and whitespace checks pass. New source manifests are losslessly compressed to reduce repeated evidence; readable summaries and captured product hashes remain alongside them.

This qualifies the represented heading and route interactions. It does not close every large-text row presentation, exact unselected scroll-offset restoration, actual VoiceOver, Mac window interaction, physical-device or whole-app visual acceptance gate. Data, Core/MCP declarations, formats and signing stay unchanged.
