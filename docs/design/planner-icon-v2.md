# Monochrome Planner icon

The current app icon uses one generated transparent mark in
[AppIcon.icon](../../Planner/AppIcon.icon/icon.json), with native appearance
settings. Default is charcoal on near-white; Dark is white on charcoal. Both
use the same geometry and placement. The platform supplies its enclosure and
subtle grayscale material. No colored accent or colored gradient is included.

The original blue concept remains historical. The generated
light and dark palette
studies are retained; the production icon uses the single transparent foreground
rather than independent flattened images.

## Local verification

Apple's installed Icon Composer renderer exports were inspected at 256 pixels
for Default/Dark on iOS and macOS, and at 32 pixels for both iOS appearances.
The first native Dark preview exposed insufficient contrast; the retained final
manifest corrects it using the native layer fill specializations. Source artwork
is fitted to the 1024-point canvas through its native layer scale.

Both affected app builds pass with the same 1164 native inputs. Their actual
compiled Info plists select AppIcon and their Assets.car files contain the icon
stack, mark and dark/light appearance metadata. Exact inputs, commands and
outcomes are in the evidence.
Installed phone/iPad Simulator Home Screen appearances now have the checkpoint
below. Mac Dock appearance and physical devices remain unqualified. These
resource checks do not claim a whole-app accessibility pass.

## Installed Home Screen, 31 October 2026

The native Home Screen journey passes on iPhone 18 Pro (15.559 seconds) and
iPad Pro 13-inch M5 (16.147 seconds), both on iOS 27.0. It uses the installed
Planner icon, opens native Customize, selects Default then Dark, checks the
selected controls and unchanged Planner identity, and restores Default. All four
original captures are inspected: charcoal on near-white and white on charcoal
retain the same shape at actual icon size. Both runs share 254 unchanged native
inputs. Their app installation epochs are recorded separately, with identical
icon manifest/artwork and unchanged production library; identical compiled asset
catalogs are not claimed. Commands, results and hashes are in the
review packet.

System appearance alone leaves Home Screen icons at Default in the initial
trial, so it supplies no dark-icon credit. Earlier trials expose an offscreen
icon, an invalid hit-test assertion while the native customization panel is
modal, and an iPad fixture with only the runner installed. Their failures and
the control-only feasibility run remain separate from final acceptance. The
test is restricted to Simulator and requires a disposable device with Planner
installed. It adds no production styling or theme controller. Physical Home
Screen, Mac Dock and automatic/Clear/Tinted choices remain unqualified.

The package follows Apple's [Icon Composer guidance](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer),
the installed Xcode Icon Composer template and the icon manifest structure in
Apple's [alternate-icon sample](https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons).
No runtime theme-switching code or additional dependency is needed.

## Built-in image-generation prompts

### Light palette study

```text
Edit the attached Planner app icon. Preserve exactly the checkmark-and-circular-waypoint silhouette, its position, proportions, rounded stroke ends and generous canvas spacing. Change only the palette and remove texture: the light appearance must have a uniform near-white background (#F5F5F5) and a uniform very dark charcoal symbol (#202124). Entire image strictly grayscale, achromatic, no blue or other hue. Clean flat vector-like edges, no gradient, no texture, no highlights, no bevel, no shadow, no 3D, no extra detail. Output one opaque square app-icon master, without a rounded outer mask, typography, border, surrounding presentation or mockup. Keep the circular opening in the waypoint. This is the Light variant of the same app identity.
```

### Dark palette study

```text
Create the Dark appearance of the attached monochrome Planner app icon. Change only the two colors: use a uniform charcoal background (#202124) and an off-white checkmark-and-circular-waypoint symbol (#F5F5F5). Preserve the exact silhouette, circular opening, stroke widths, positions, proportions, canvas and margins of the attached light icon. One flat grayscale image only, with no hue, gradient, texture, highlight, bevel, shadow, 3D effect, text or extra detail. Keep the square canvas opaque and without a rounded outer mask. The light and dark variants must look like the same icon with inverted colors.
```

### Shared transparent foreground

```text
Extract only the dark checkmark-and-circular-waypoint symbol from this Planner app icon onto a genuinely transparent background. Preserve the exact silhouette, round opening, stroke width, placement and original square canvas margins. Remove the pale background completely, including inside the circular opening. The symbol must be a single flat solid neutral black (#000000), with clean antialiased edges and no texture, shading, shadow, outline or extra elements. Do not add a checkerboard or any opaque background. Output one transparent PNG foreground layer for Apple's native Icon Composer; the system will supply the light and dark colors and background.
```
