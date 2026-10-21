# Directed native plan-opening handoff

Status: Q126 A accepted on 21 October 2026. The concrete production handoff and additional test boundary below are approved. The implementation checkpoint is linked below; all 13 post-focus-fix production-interface cases pass in the existing direct XCTest mode, while IDE-session and actual window/system qualification remain open.

## Context and starting state

Planner owns one shared store, but each SavedPlannerView owns its selections and unsaved draft. There is no directed window request mechanism. Existing draft navigation correctly validates and saves before continuing; it silently ignores navigation while Save is running. OpenIntent foregrounding alone does not prove that a particular main window exists or consumes a request.

## Goal and expected end state

Open an exact current List or Itinerary in one foreground main window, with native draft protection. Other windows retain their selections. Cold launch and all-windows-closed operation need native main-window delivery, not a broadcast or a custom URL.

## Q126, concrete contract and test boundary

A. One app-internal MainActor coordinator registers main-window identities, tracks native foreground activity, and directs one ephemeral opening request to one window. The action validates the typed source in the current dataset and submits that exact identity plus the dataset/ownership binding. A cold request waits for a ready main window; native window activation/creation supplies the main scene when needed. Claiming a request is exclusive. No view consumes another window's request.

The receiving window uses the existing Save / Discard / Keep editing guard. While a Save or another navigation decision is pending, keep the existing request and reject an additional external request with a useful busy error rather than replace it. Keep editing cancels the request. Save must validate and durably finish first; an invalid Save keeps the editor and request available. Revalidate dataset and target after any delay. Missing/deleted targets or changed datasets fail without selecting a similarly named plan. Closing the recipient cancels a claimed request rather than redirecting it into another window's draft.

The action reports that opening was requested, with any pending draft decision explained. It does not claim the plan was displayed before navigation completes. Request state stays in memory and outside backups. No new data mutation, agent administration, persisted queue or automatic draft save is added.

Approve direct tests of the production coordinator's registration, submission, exclusive claim and resolution interface in the existing app-hosted target. Use real Planner storage for dataset/source validation and actual production request values. No injected fake window, callback/confirmation hook, private-helper tests, new package or target. Existing Intent tests cover action validation; native UI/system tests still cover actual window activation, draft controls and adaptation.

B. Revise the concrete request lifecycle or test boundary before implementation. Q122's foreground-window and draft-protection policy remains accepted.

Recommend A. It makes delayed navigation truthful and testable while retaining actual window/UI qualification.

## Definition of ready

- Q122 A accepts one foreground main window, other-window isolation and Q91 draft protection.
- Q126 A approves the concrete coordinator lifecycle and additional production test seam.
- Installed SDK and existing scene/draft code establish available APIs, not successful cold/warm native delivery. Signing stays deferred.

## Required tests and validation

Use the real coordinator interface to verify exactly one claimant, ordered active-window selection, pending cold requests, duplicate/busy admission, completion/cancellation, recipient closure and dataset replacement. Invalid, removed or wrong-kind targets reject; archived and renamed plans retain exact identity. No coordinator result may assert display before its window resolves navigation.

At existing native seams, verify Save/Discard/Keep editing, invalid Save, failed persistence, an in-progress Save, target deletion during a draft decision, compact pushed pages and resize. Prove two-window selection isolation and focused-window targeting, cold launch and all-windows-closed reopening on applicable platforms. Record unavailable system journeys separately, without replacing them with coordinator tests.

Run affected strict lint/type checks, matching Mac/Simulator/unsigned device compilation and metadata comparisons. Preserve all saved content, associations, completion, schedules and ordinary draft navigation regressions.

## Definition of done

- Accepted concrete contract precedes dependent implementation/tests.
- Production coordinator and Intent behavior has red/green evidence with real data and truthful request outcomes.
- Native window/draft/device journeys pass where runnable; unresolved system gates stay open with actual failure evidence.
- Source and evidence are committed; no signing/account setup or full-map completion is inferred.

## Local implementation checkpoint

The [directed plan-opening report](prototypes/native-plan-opening-handoff.md) records the production coordinator, exact-identity Open actions, native scene integration and draft protection. It separates passing earlier production-interface and ordinary mobile draft journeys from the passing direct-module focus-order rerun, blocked Xcode IDE-session workflow, actual external-request/window tests, system invocation and signing/physical gates. No map acceptance is inferred from implementation or compilation.
