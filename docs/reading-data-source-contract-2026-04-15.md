# Frontend Users Reading Data-Source Contract

Date: 2026-04-15
Scope: `frontend_users/ui` reading surfaces only
Related task: `task058-u10-frontend-users-reading-data-source-contract`

## Purpose

This artifact makes the reading data model explicit instead of leaving it implied in code. The current frontend is intentionally hybrid in some reading paths:

- Quran text and shared reading metadata are already local-first.
- User-scoped evaluation state and chart aggregates are currently server-backed.
- Some screens compose both models in one UI surface.

The goal is not to force one source for everything. The goal is to define which source is canonical for each reading sub-surface, what can remain hybrid, and where future product decisions would be needed before any source migration is treated as canonical.

## Decision Summary

### Canonical Rules

- Static/shared Quran content remains `Local Asset` or equivalent local packaged data.
- User-scoped reading state remains `Server API` unless explicitly moved into a local sync queue.
- Chart aggregates are not a local source of truth. They remain server-derived unless a future product decision says otherwise.
- Hybrid reading screens are acceptable only when each sub-surface has an explicit source-of-truth boundary.

### Product Decisions Not Fixed By This Artifact

- This artifact does not confirm any specific offline-first sync entities, conflict policies, or sync-trigger policies as canonical handoff requirements.
- Items such as standalone notes, reading progress, bookmarks/favorites, conflict-resolution rules, or broad sync-trigger behavior remain `Product Decision Pending` unless a future task or handoff introduces them explicitly.
- Because those decisions are not fixed inputs here, they are not used as the basis for canonical judgments in the matrix below.

### Task045 Position

`task045` = `Remains Valid As-Is`

Reason: `task045` was a performance task on reading surfaces that are genuinely hybrid today. This contract does not invalidate its conclusions. Any change to make some user-scoped writes offline-first should be treated as follow-up migration slices, not as a retroactive reopen of `task045`.

## Source-Of-Truth Matrix

| Surface / Sub-surface | Data Owned | Current Source | Static/Shared vs User-Scoped | Current Judgment | Reason / Boundary |
| --- | --- | --- | --- | --- | --- |
| `AyatController` | Full ayah text, ayah metadata, surah/juz/hizb/hizbQuarter filtering from `assets/json/data.json` | `Local Asset` | `Static/Shared` | `Accepted` | Quran text and shared metadata are suitable local-first content and already cached in-process. `No Change Required Now`. |
| `IndexPage` -> ayah text/content | Ayah list for the current hizb quarter / selected reading slice | `Local Asset` via `AyatController` | `Static/Shared` | `Accepted` | Reading content itself is not user-scoped. Keep local-first. `No Change Required Now`. |
| `IndexPage` -> per-ayah user evaluation overlay | Current user evaluation attached to visible ayahs | `Server API` via `EvaluationsProvider.getAllUserEvaluations()` | `User-Scoped` | `Accepted` | The current contract is a server-backed user overlay composed on top of local ayah content. Any local pending-write overlay would be a `Future Candidate`, not a confirmed requirement in this artifact. |
| `IndexPage` -> evaluation category list | Evaluation definitions (`evaluationId`, `name`, `code`) | `Server API` via `getAllEvaluations()` | `Shared reference data` | `Accepted` | This is backend-defined taxonomy. It can be cached read-through later, but server remains the source of truth. `No Change Required Now`. |
| `IndexPage` -> connectivity gating | Online/offline reachability used before fetching user data | `Local device state` | `Runtime state` | `Accepted` | This is local runtime state that gates fetching behavior. It is not a persisted domain source and does not require source migration by itself. |
| `quran_view` / `QuranViewer` | Surah text from `package:quran` | `Local Package Data` | `Static/Shared` | `Accepted` | Legacy/local reading surface with static text only. It does not currently define user-scoped sync semantics. `No Change Required Now`. |
| `EvaluationsProvider` -> `evaluations` | Shared evaluation catalog in memory | `Server API` cached in provider memory | `Shared reference data` | `Accepted` | Provider memory is a runtime cache, not the canonical source. Server remains truth. |
| `EvaluationsProvider` -> `userEvaluations` | User evaluation read-model for current ayah set | `Server API` into provider memory | `User-Scoped` | `Accepted` | The current contract is a server-backed read model cached in provider memory. Any local merge or pending-write behavior would be a `Future Candidate` pending product decision. |
| `EvaluationsProvider` -> `chartEvaluationData` | Aggregated chart distribution for a user | `Server API` (`user-evaluations/chart/:userId`) | `User-Scoped derived aggregate` | `Accepted` | Chart data is server-derived aggregate state, not a local source of truth. Do not replace it with local asset cache automatically. `No Change Required Now`. |
| `EvaluationsProvider` -> `_questionContentAyahs` | Locally loaded ayah content for questions content items | `Hybrid` | `Hybrid` | `Accepted` | The ayah text part is local and valid. This cache is a composed runtime view, not an independent domain source. |
| `EvaluationsProvider` -> `_questionContentCompletion` | Completion flag derived from ayah list + user evaluations | `Hybrid` | `User-Scoped derived state` | `Accepted` | Completion is a derived runtime view, not a separate persisted source. It should not become an independent server or local truth without a separate product decision. |
| `EvaluationsServices.getAllEvaluations()` | Shared evaluation catalog fetch path | `Server API` | `Shared reference data` | `Accepted` | Server-backed reference data remains valid. |
| `EvaluationsServices.getAllUserEvaluations()` | User evaluation fetch path by `userId` and `ayatIds` | `Server API` | `User-Scoped` | `Accepted` | The current server-backed read contract is valid. Any local overlay above it would be a `Future Candidate` pending product decision. |
| `EvaluationsServices.evaluateAyah()` | Single ayah evaluation write path | `Server API` | `User-Scoped write` | `Accepted` | The current evidenced contract is a direct server-backed write path. Any offline-first queue above it is a `Future Candidate`, not fixed by this artifact. |
| `EvaluationsServices.evaluateMultipleAyat()` | Bulk ayah evaluation write path | `Server API` | `User-Scoped write` | `Accepted` | The current evidenced contract is a direct server-backed bulk write path. Any local queue or replay layer would require a future product decision. |
| `Chart fetch path` | `totalVerses`, per-evaluation aggregates, percentages, counts | `Server API` | `User-Scoped derived aggregate` | `Accepted` | Keep server-backed. If offline mode is required, only cache last known snapshot as UI convenience, not as canonical truth. `No Change Required Now`. |
| `SahifatyApi` auth-backed request layer | Session-bearing HTTP contract for reading-adjacent user data | `Server API` with local session secrets | `Infrastructure / session-scoped` | `Accepted` | Session transport stays server-backed. If a future task adds local pending-write behavior, it should layer above this transport rather than replace it. |

## Hybrid Surface Breakdown

### `IndexPage`

`IndexPage` is a valid hybrid surface, but only with this explicit split:

- `ayah text/content` -> `Local Asset`
- `user evaluations overlay` -> `Server API` in the current contract; any local pending queue would be a `Future Candidate` pending product decision
- `evaluation taxonomy list` -> `Server API`
- `connectivity gating` -> local runtime state only

### `EvaluationsProvider` question flow

The question flow is also hybrid, but its parts are different in nature:

- `questionContentAyahs` -> local Quran content loaded from assets
- `userEvaluations` -> server-backed user state today
- `questionContentCompletion` -> derived state from ayah content plus evaluation overlay

Important boundary:

- `questionContentCompletion` should remain derived unless a product decision explicitly asks to persist and sync it as its own domain entity.

## Conditional Future Candidate

The current inputs support one bounded future candidate without turning it into a confirmed requirement.

### Candidate 1

- Label: `Conditional`
- Title: `frontend_users offline-first evaluation-write experiment`
- Trigger: only if a future product decision explicitly asks for local pending-write behavior for user evaluations.
- Scope / Surfaces: `EvaluationsServices.evaluateAyah()`, `EvaluationsServices.evaluateMultipleAyat()`, `EvaluationsProvider.userEvaluations`, and the reading write interactions in `IndexPage` and question content flows.
- Dependency Type: `UI-only` if existing backend endpoints remain sufficient; otherwise re-scope in a separate task with backend coordination.
- Task045 Relation: `Separate from task045`
- Evidence Basis: current code already shows server-backed evaluation read/write paths. This candidate derives from those surfaces, not from a confirmed sync handoff.

## Server-Backed Boundaries That Should Not Be Flattened Into Local Assets

These should remain server-backed unless a separate product decision says otherwise:

- Per-user evaluation truth after sync confirmation
- Chart aggregates (`characterCount`, `verseCount`, `percentage`, `totalVerses`)
- Session-authenticated read paths tied to user identity
- Evaluation taxonomy when backend defines its catalog semantics

Important clarification:

- Local Quran text or local asset cache is not an automatic substitute for user evaluation state or chart data.

## No-Change-Required-Now Surfaces

The following surfaces are acceptable today and do not require immediate migration:

- `AyatController` local Quran text and shared metadata loading
- `IndexPage` hybrid split as documented in this artifact
- `quran_view` local packaged text surface
- `EvaluationsServices.getAllEvaluations()` as server-backed evaluation taxonomy fetch
- `EvaluationsServices.getAllUserEvaluations()` as current server-backed user evaluation read path
- `EvaluationsServices.evaluateAyah()` and `evaluateMultipleAyat()` as current server-backed user evaluation write paths
- `chartEvaluationData` as server-backed aggregate read model
- `task045` performance conclusions as previously documented

## Practical Contract Guidance

If implementation starts later, the intended layering should be:

1. Keep static Quran content local-first.
2. Keep the current user-scoped evaluation reads and writes server-backed in the canonical contract unless a later task changes that explicitly.
3. Treat provider memory and derived completion flags as runtime views, not independent sources of truth.
4. If product later asks for offline-first writes or additional synced entities, raise a separate bounded task before changing source-of-truth labels.

## Final Planning Decision

- Hybrid reading data is acceptable in `frontend_users/ui`.
- Static/shared Quran data remains local-first.
- User-scoped evaluation reads and writes remain server-backed in the current canonical contract.
- No additional sync entities or conflict policies are confirmed by this artifact; those remain `Product Decision Pending` unless introduced explicitly in a future handoff.
- `task045` remains valid and should not be reopened broadly because of this architecture clarification.
