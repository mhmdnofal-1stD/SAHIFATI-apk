# Ayah Source Matrix - 2026-05-08

## Scope

- Target gap languages for offline ayah translation coverage: `de`, `hi`, `ms`, `pa`, `ha`, `sw`, `jv`.
- Current Flutter local ayah source remains the `quran` package for already supported languages.
- Baseline rule remains unchanged: unsupported ayah locales must not fall back to English; they show Arabic only.

## Baseline Status

- `frontend_users/ui/lib/screens/quran_view/quran_view.dart` stays untouched.
- Popup and preview behavior stays local-offline when a bundled ayah source exists, and Arabic-only when it does not.
- Existing local ayah coverage from `quran` remains: `ar`, `en`, `tr`, `ml`, `fa`, `fr`, `it`, `nl`, `pt`, `ru`, `ur`, `bn`, `zh`, `id`, `es`, `sv`.
- Live app languages still missing local ayah coverage before this phase were: `hi`, `ms`, `pa`, `jv`, `ha`, `sw`, `de`.

## Source Policy

- `Tanzil` is excluded as a production source for the new gap languages because its public translations page states the translations are for non-commercial purposes only unless direct permission is obtained from the translator or publisher.
- `QuranEnc` is the preferred source in this phase because it provides official translation pages, machine-readable APIs, downloadable SQLite exports, and public republishing conditions surfaced on translation pages/search snippets.
- `AlQuranDB` is useful as a discovery index, but not as the canonical legal source; it republishes content from upstream sources such as `quranenc.com` and `tanzil.net`.

## Phase 1 Result

| Language | Decision | Source | Key | License / terms signal | Format | Coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `de` | `go` | QuranEnc | `german_bubenheim` | Official QuranEnc source; republishing conditions require attribution, no modification, source/version preservation | API + SQLite | 114 surahs / 6236 ayat verified | Best current official path |
| `hi` | `go` | QuranEnc | `hindi_omari` | Official QuranEnc source; same republishing model | API + SQLite | 114 / 6236 verified | Direct API listing present |
| `ms` | `go` | QuranEnc | `malay_basumayyah` | Official QuranEnc source; page snippet exposes re-publish conditions | API + browse page + SQLite | 114 / 6236 verified | Hidden from `translations/list/ms`, but API key is live |
| `pa` | `go` | QuranEnc | `punjabi_arif` | Official QuranEnc source; same republishing model | API + SQLite | 114 / 6236 verified | Direct API listing present |
| `ha` | `go` | QuranEnc | `hausa_gummi` | Official QuranEnc source; same republishing model | API + SQLite | 114 / 6236 verified | Direct API listing present |
| `sw` | `go` | QuranEnc | `swahili_rwwad` | Official QuranEnc source; same republishing model | API + SQLite + PDF | 114 / 6236 verified | Preferred over `swahili_barawani` for canonical pipeline |
| `jv` | `deferred` | none approved yet | none | No machine-readable official source with clear reusable terms found in this pass | n/a | not approved | Needs separate licensed acquisition or internal commissioning |

## Verification Notes

- `QuranEnc` language catalog exposes official support for `de`, `hi`, `pa`, `ha`, `sw` and also lists `ms` at the language level.
- Direct API verification confirmed these keys return complete surah payloads summing to `6236` ayat:
  - `german_bubenheim`
  - `hindi_omari`
  - `malay_basumayyah`
  - `punjabi_arif`
  - `hausa_gummi`
  - `swahili_rwwad`
  - `swahili_barawani`
- `malay_basumayyah` is a special case: the browse page and surah endpoint are live even though `translations/list/ms` currently returns an empty list.
- Search and catalog passes did not yield an equivalent official `QuranEnc` or other clearly licensable machine-readable source for `jv`.

## Immediate Consequence

- Package A can proceed for six languages now: `de`, `hi`, `ms`, `pa`, `ha`, `sw`.
- `jv` must stay out of `language-settings` surfacing and out of the ayah canonical pipeline until a separate source approval lands.

## Next Step

- Start Phase 2 for the six approved languages only.
- Build a canonical ayah source registry and transform pipeline that ingests upstream source files into offline Flutter assets without changing popup consumers yet.