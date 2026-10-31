# Native label appearance review

## Context

The accepted [content contract](content-and-reader-review.md) gives Categories and Tags optional sRGB color and icon-name fields. Their full source reads and live Item/Itinerary label reads already include those fields. Manage Labels currently creates and edits names only; Item details also use fixed kind icons.

Q121 asks how the user should choose an icon. It does not reopen shared identities, live references, duplicate names, deletion confirmation or the approved content format.

## Verified platform facts

Apple supplies a native [ColorPicker](https://developer.apple.com/documentation/swiftui/colorpicker) with Color or CGColor bindings and optional opacity support. The installed SwiftUI, SwiftUICore, AppKit and UIKit declarations expose no complete SF Symbols picker. A generic [Picker palette](https://developer.apple.com/documentation/SwiftUI/PickerStyle/palette) can present app-supplied symbols but does not provide a symbol catalog or search.

Modern cross-platform [Color resolution](https://developer.apple.com/documentation/swiftui/color/resolved) exposes nonlinear sRGB components as Float. Exact existing PlannerColor Double values must not be round-tripped through that representation unless the user changes the color. Extended-gamut color selection also needs explicit sRGB conversion and finite/range validation. The current content contract rejects invalid components rather than silently clamping them. Clearing color or icon remains an explicit choice.

The read-only SDK observation retains the probe, exact commands and reported exits for macOS 27 and iOS 27. The agent's original tool output reported nonfatal sandbox messages and exit 0 for both. Root inspected the retained source without rerunning it. This is declaration evidence only, not picker behavior or runtime color conversion. No account or signing settings changed.

## Accepted decision

- A: A native Picker with a small named set of familiar symbols and Default. Preserve any existing custom icon until explicitly changed or cleared. This is the recommended minimal native workflow.
- B: Add a searchable symbol-picker library, with dependency and compatibility review.
- C: Implement color editing now and defer icon editing, leaving that feature open.

Q121 A was accepted on 21 October 2026. Use the small native symbol picker, preserving custom values until explicitly changed. No additional test boundary is introduced. Any implementation should use the already approved native UI/Core boundaries to verify Save/Cancel, exact unchanged values, live references, clearing and relaunch. Creating a label must not rewrite its referring owners or their completion.

## Local implementation checkpoint

The native editor and delivered-file qualification are recorded in [Native label appearance](prototypes/native-label-appearance.md). Original custom values survive untouched saves; explicit icon/color edits, Cancel, clearing and relaunch are qualified on mobile. Actual Mac interaction, signed storage and physical-device checks remain separate.
