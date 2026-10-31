# Read-only estimate accessibility

## Change and approved boundary

Estimate, Remaining and uncertainty warnings are read-only planning information.
Their grouped SwiftUI accessibility nodes were exposed as generic elements.
Native hit-region auditing treated those small caption nodes as interaction
targets.

Add isStaticText to the shared metric and warning nodes in
SavedContainerEstimates. This is a two-line semantic correction. It keeps their
complete labels/values and existing native layout. Completion buttons already
have 44-point targets; no button padding, duration rule, data format or
navigation changes are introduced.

The existing native fixture/production UI seam is approved. The new journey
opens a real saved itinerary with two List appearances and a direct Item, audits
hit regions, sufficient descriptions and traits, then scrolls to every exact
completion control and checks its full target and Todo value. It performs a
second audit after scrolling. No audit issue handler filters failures and no
production test hook, package, target or additional direct seam is added.

## Observed failure and correction

The unchanged initial phone test records four Hit area is too small failures.
Actual native issue lookup names the full estimate, remaining estimate and
missing-estimate warning; the later scrolled audit finds the remaining visible
warning. The retained native screenshots show those read-only labels. Every
completion target passes its separate 44-point and title-description checks.

The same test passes after only the two static-text declarations change. Its
source is byte-identical across the failing and passing runs. The failed packet
also records an automatic Xcode diagnostic-collection simctl error after the UI
case; its four actual audit issues and native attachments remain independently
inspectable. It supplies no passing credit.

## Local qualification

| Boundary                       | Executed result                                                                                                                                |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Light iPhone interaction audit | One new function passes both viewport audits and reaches all three exact completion controls.                                                  |
| Dark iPad                      | Three functions pass: interaction audit, unchanged imported-completion/relaunch/Reopen journey and unchanged List contrast/completion journey. |
| Light iPhone regressions       | Both existing completion/relaunch/Reopen and List contrast functions pass.                                                                     |
| Mac and HTTP                   | App, Share and fixture builds pass, followed by eleven actual HTTP functions. This is not external Mac UI or system Shortcuts evidence.        |

The final verifier reconciles all 1,157 inputs across the final mobile and Mac
runs. Only the two-line production correction and new native journey differ from
73b1339e. Core, frozen fixtures and existing test bodies remain unchanged. Four
current phone and nine Mac products are verified, and each earlier passing
phone/iPad product set is verified before build-directory reuse. No test skips
or SQLite unlink warnings occur. Strict Swift/Markdown formatting and whitespace
checks pass.

Seventeen current original PNGs are retained; six are directly inspected. They
retain readable estimates/warnings in light/dark, the iPad collection heading
and contextual Item details. Native scrolling reaches all three completion
controls above the phone tab bar. Initial content can scroll behind native
floating bars; native title truncation and broader layout acceptance remain
separate findings. No full title, spacing, accessibility or whole-app acceptance
is claimed by this semantic correction.

Verified cleanup removes eleven closed passing Mac fixture stores totaling
7,071,529 nominal file bytes. Attachment cleanup removes four byte-verified
duplicate export directories totaling 12,368,060 nominal bytes. It retains every
original result bundle, selected capture and failed dataset. A separately
exported failure manifest has different generated text-attachment identities, so
the exact guard preserves that directory. These sizes do not measure reclaimed
physical disk blocks.

Q157's serialized source-restoration maintenance declaration remains pending and
unchanged. Actual VoiceOver interaction, additional scene/text-size states, Mac
runtime, signed/installed/physical integration and feature-complete whole-app
review retain their separate gates. Signing stays deferred.
