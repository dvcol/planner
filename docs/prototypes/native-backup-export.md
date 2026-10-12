# Native backup export

## Context, before and goal

At `1270827`, Core exports the current validated portable graph, but Settings has no manual backup action. The goal is a Data section with Export Backup, an asynchronous preparation indicator and the system file exporter. Only successful file delivery reports an exported backup. Cancel returns to Settings, and failures show a useful error without changing Planner data or claiming recovery/sync success.

The implementation uses SwiftUI's [system exporter](https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:item:contenttypes:defaultfilename:oncompletion:oncancellation:)) and a [Transferable data representation](https://developer.apple.com/documentation/coretransferable/datarepresentation). The file holds immutable Core-produced JSON bytes and a dated suggested filename. The date belongs to the filename, not saved content. The system controls destination selection, renaming and any replacement confirmation. Mac declares user-selected file read/write access for its native save panel.

## Definition of ready

Native manual data-only export and `exportData(session:)` are approved. The existing native UI and public exported-file I/O boundaries are the test seams. No administration method is added to agents. Export reads stay available during incomplete recovery; presentation must not use the mutation permission as its availability check.

## Definition of done and required /tdd

- First prove the missing action through a native journey, then open and cancel the real system picker. A saved Tag keeps its identity/content after cancellation and relaunch; cancellation reports no success or failure.
- Save an actual JSON file through the native picker and inspect its public bytes. Confirm the declared portable format and owned fixture content, with no application/session/account state.
- Qualify native phone/tablet journeys, affected Swift lint and app compilation on Mac. Record any system-provider or runtime limits separately from passing evidence.
- Keep Core data, mutation acknowledgements and device preferences unchanged. Export completion describes file delivery, not upload or independent recovery.

## Execution

The first executed journey failed at the absent Export Backup action after successfully creating its Tag fixture. Subsequent test-driver corrections follow the actual system picker: its iPhone Cancel accessibility overlay points at More, its Browse-root close button is absent from queries, and iPad can report duplicate controls. The final cancellation journey uses a native header drag on iPhone and the first matching Cancel button on iPad. These are test gestures, not custom production controls.

The first real file save delivered valid JSON. Native LabeledContent exposes the delivered filename as a combined accessibility label, so tests read that label rather than expect a separate StaticText. Repeat exports exercise the provider's replacement dialog; this system dialog is outside Planner's accessibility tree in this simulator. Dated defaults avoid that dialog during the ordinary backup journey. Replacement, custom destination/rename, provider errors and native preparation-failure presentation retain separate runtime gates. They are not counted as passed tests.

The final dated-file qualification passes both journeys on each device, with no failures or skips. Cancellation and file delivery both preserve the saved Tag's identity/content after relaunch. Actual 833-byte files have the full declared format-1 root, exactly the pre-export Tag, finite preserved timestamps and no extra records or application state. Core's [current-dataset export qualification](core-native-export.md) covers complete supported graphs, invalid reads, incomplete recovery and unchanged acknowledgement. This UI change does not alter Core, MCP or App Intent registrations.

The [execution record](evidence/navigation/native-backup-export.json) includes source/configuration hashes, raw log hashes, summaries and public-file checks. It retains the real [phone backup](evidence/navigation/native-backup-export-phone.backup.json) and [tablet backup](evidence/navigation/native-backup-export-tablet.backup.json), plus [phone Settings](evidence/navigation/native-backup-export-phone-saved.png), [tablet Settings](evidence/navigation/native-backup-export-tablet-saved.png) and cancellation screenshots. Each platform executes two functions and two invocations. Four affected Swift files pass strict formatting lint; the entitlement passes plist validation and this document passes Markdown lint. Source/configuration stays fixed through the final dated qualification.

Native Mac app/UI-test compilation passes; native Mac UI runtime remains zero. Signed physical devices, provider/network failures, iCloud delivery and account transitions are not established by simulator file delivery. Import review/apply/restore and Calendar/estimate implementation remain separate map work.
