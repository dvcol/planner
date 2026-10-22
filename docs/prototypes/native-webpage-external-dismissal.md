# Native external-app confirmation dismissal

## Accepted behavior and existing boundary

Q145 A requires an explicit native Open action for reported supported app links. Q146 A retains WebKit's intercepted Phone menu on iPad. Existing button-cancellation journeys do not establish interactive sheet dismissal or confirmation before any webpage has loaded.

Use the existing production-app native UI boundary and its shared loopback server. Add one real HTTP 302 response to a Maps app URL, without a webpage body. The first journey must keep Planner foreground, expose the exact target and dismiss the native sheet by dragging its header. With no committed page, dismissal must return to the exact saved Item and preserve its original HTTP bookmark. A second journey dismisses the Mail confirmation from an already loaded guide, retains that page and its Back history, then returns to the original bookmark. Neither journey chooses Open, sends a message or changes Planner content.

These are actual iPhone/iPad component checks. No production parameter, dependency injection seam, target, signature, signing setup or account configuration is added. The installed WebPage's initial-redirect behavior must be observed rather than assumed. Preserve failures with their actual native state. Actual external opening, Mac modal interaction, accessibility and physical acceptance remain separate.

## Final local dismissal checkpoint

The [reconciled checkpoint](evidence/native-webpage-external-dismissal/final-reconciliation.json) passes eight native executions across four functions, with eleven original captures inspected. All executions and matching Mac compilation use the same 1,081 source inputs. Four runtime products per invocation and nine Mac compiler products reconcile at their respective boundaries before reuse. Production Planner, Share and Core sources are unchanged.

| Invocation | Passed functions | Original captures | Outcome |
| --- | --- | --- | --- |
| [Initial and loaded dismissal, iPhone](evidence/native-webpage-external-dismissal/external-initial-and-dismissal-phone/) | 2 | 3 | Initial HTTP app redirect awaits confirmation; swiping the sheet away returns to the exact Item. A loaded guide and its history survive interactive dismissal. |
| [Existing policy regressions, iPhone](evidence/native-webpage-external-dismissal/external-dismissal-policy-regressions-phone/) | 2 | 2 | Direct, generated and redirected app URLs keep exact targets behind explicit Open. Cancellation preserves the guide and bookmark. |
| [All four, dark iPad](evidence/native-webpage-external-dismissal/external-initial-dismissal-and-policy-dark-tablet/) | 4 | 6 | Both interactive paths and existing policies pass. Apple's intercepted native Phone menu is cancelled without selecting an action. Original appearance is restored. |
| [Mac compiler](evidence/native-webpage-external-dismissal/external-dismissal-mac-compiler/) | Not executed | None | Matching app, Share and native test targets compile. No Mac runtime credit. |

The additional server route is a real HTTP 302 to `maps://?ll=36,140`, with an empty body. Existing routes retain their previous responses. No Open, Call, Message or Contacts action was selected. Strict affected Swift/Markdown lint and whitespace checks pass. The narrow iPad Items title remains truncated and stays on the whole-app polish list. Actual Mac modal interaction, external-system handoff, broader accessibility and physical acceptance remain open.
