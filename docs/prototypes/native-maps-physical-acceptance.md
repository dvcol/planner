# Physical Maps sender acceptance

31 October 2026. The refreshed signed app/Share and runner install and launch
on the authorized iPad Pro 13-inch (M4), running iPadOS 27.0.1. The test's empty
Items guard passes before it closes Planner and opens Apple Maps.

The first run ends with the runner killed while entering Maps search. Its
recording is unavailable because the attachment was still pending. After the
user puts Maps full screen, the one authorized retry reaches the same search
field but cannot give it keyboard focus. It fails before Share opens.

Neither attempt opens Planner's capture form or requests a Save. No test Item
is created. All protected source/product inputs remain unchanged. These are
failed automation attempts, not passing native sender acceptance and not
evidence of a Planner capture defect.

The [review record](evidence/native-maps-physical-2026-10-31/review.json) retains
the precise outcomes and original-log hashes. Compressed excerpts include the
relevant test/search events; full logs and system attachments remain local
because they also enumerate unrelated app windows. No manual-authentication,
signing or device security setting is changed.

The user completes the manual Apple Maps Cancel/Save/relaunch check and
confirms the original link/map and reviewed fields remain available. This
qualifies the reported physical workflow; UUIDs are not independently read
and synthetic cleanup is not separately confirmed. The user is now using the
iPad, so further device tests must use the iPhone.

The refreshed title-suggestion build is then checked on iPhone Air, running
iOS 27.0.1. The first automated run cannot find the localized Maps Share
control. The driver is corrected to use its native identifier. The bounded
retry reaches the system share sheet but cannot swipe an app row whose visible
frame is empty. Both runs stop before Planner capture opens or Save is requested.
They do not qualify the whole physical sender journey.

The user manually shares a named Apple Maps place on the iPhone and confirms
that the review title fills correctly. This verifies the reported native title
behavior alongside the passing Simulator regression; physical iPhone
Save/relaunch was not rerun. The title fix is committed locally at `9a20a3a6`.
Full system-share attachments remain local because they can expose unrelated
recipient/app suggestions.

Google Maps is not installed on either authorized
device, so its native sender is also unqualified. Existing passing Simulator
Apple Maps, physical Safari Share and in-app Google-link capture evidence is
retained separately. No additional iCloud test is introduced.
