# Prepared command replay during pending maintenance recovery

This Q155 A follow-up fixes a common execute preflight that rejected a saved command preparation whenever a committed automatic maintenance operation still needed independent recovery. That barrier protects new mutations, but it also hid the truthful prepared-but-unverified result of an already known operation.

The preflight now applies maintenance admission to genuinely new operations. Existing prepared operations reach their original evidence-matching handlers, just as applied receipt replay already did. Matching contextual retries return the original unverified proposal; altered inputs reject. Neither path commits a command, publishes maintenance or bypasses the barrier for a new operation. No model, format, fingerprint, public interface, package, target or production test-hook changes.

## Actual pending-maintenance fixture

The existing public-store replay tracer now has three environments: missing targets, removed/re-added targets and pending maintenance recovery. Nine command scopes each run with current version-two and equivalent legacy preparations, giving 54 cases. The eighteen maintenance cases include individual standalone/expanded/direct completion, selected-alias and anchor reorders, List/branch/whole-Itinerary bulk and an empty branch.

For the new environment, an independent native write introduces a smaller duplicate membership. The ordinary command path commits real canonical maintenance. The existing didSave filesystem obstruction then prevents recovery publication. After the obstruction is restored, public status proves one committed incomplete maintenance record and no evidence that the waiting user command applied. The saved command preparation is copied without its receipt proof, as in the preceding checkpoint.

The test verifies the original unverified identity and fresh-review requirement, altered-command rejection, byte-identical export/recovery files and unchanged outcome after reopening. A separate new command still rejects mutationBlocked. Actual native maintenance and publication failure are exercised; this does not claim process interruption or cloud delivery qualification.

The first run also exposed an incorrect fixture expectation: while the recovery directory is physically obstructed, the waiting command reports persistenceFailure. After restoring the path, new-command admission reports mutationBlocked. The corrected red phase states the first error exactly and still fails all eighteen prepared-replay cases on unchanged production. The preflight fix then passes all 54 cases. Both red phases remain retained.

## Final local checkpoint

The matched verification records 256 functions, 90 suites and 788 invocations on each of Mac and iPhone Simulator, with no skips or SQLite lifetime diagnostics. All 809 Core inputs match; the full phone manifest contains 1,148 inputs. Actual products and current source hashes are verified. Both changed Swift files pass strict formatting; all 514 frozen fixtures and nineteen model source files remain unchanged.

Seven existing real MCP HTTP regressions and matching Mac app, Share and fixture builds pass. A separate isolated native bulk save-failure test uses final Mac products and verifies rollback/retry for List, Itinerary and List-branch scopes. Its actual child log is retained. Native lineage staging, the other command-evidence tests, fingerprint algorithms, preparation codec and saved-context binding module remain unchanged.

Seven retained phases preserve actual failed and passing runtime results, source/product manifests and original logs. Only marked stores from completed passing logs are removed, after their hosts and database handles are verified closed.

## Remaining scope

Other prepared command families, divergent native/history flags, active-orphan and legacy-barrier admission, changed source/entry lifetimes and broader restoration-family/reference reconciliation remain open. Alias-specific HTTP/native journeys, remaining interruption cases and committed-maintenance Retry UI need their own evidence. Actual Mac UI, signed shared storage, installed Share, CloudKit convergence, physical performance and system invocation retain their separate gates. Signing remains deferred; Q155 and the map remain open.
