# Frontend Users Mushaf Reading Layout Reference

Date: 2026-05-20
Scope: `frontend_users/ui` mushaf reading page only
Owning renderer: `lib/screens/quran_view/index_page.dart`
Primary layout asset: `assets/json/mushaf_layout_mushaf5.json`

## Status

No earlier repository document was found that fixed the visual rules for the mushaf page frame, line sizing, and inter-word spacing. This file becomes the internal reference until a stricter visual spec or golden-based approval replaces it.

## Canonical Rules

### 1) Pages 1 and 2 are special framed pages

- Page 1 and page 2 keep a dedicated framed composition instead of the standard full-page text treatment.
- The framed composition must be centered horizontally and vertically inside the reader page.
- The inner frame should remain narrower than the full page width so the special opening pages keep their centered visual identity.

### 2) Mushaf text size is fixed per orientation

- Portrait uses the reader's base mushaf word size.
- Landscape uses the reader's landscape mushaf word size.
- The renderer must not enlarge or shrink specific lines based on how many words they contain.
- A short line is still a short line; it must not be visually promoted by line-specific font scaling.

### 3) Line grouping comes from the mushaf layout asset

- Word grouping and line breaks come from `assets/json/mushaf_layout_mushaf5.json`.
- The renderer may decide how a line is aligned and how conservative the spacing should be, but it must not invent new line breaks to hide spacing issues.

### 4) Spacing must stay conservative

- Sparse lines may use a compact centered treatment.
- Normal lines may distribute spacing, but inter-word gaps must stay capped.
- Gap capping must still let the sentence extend across the line from its start to its end; the line must not collapse around the center and leave oversized outer margins.
- Leaving outer margins is preferred over creating exaggerated blank spaces between words.
- Because the current renderer does not have a dedicated Arabic kashida engine, it must not try to mimic mushaf justification by aggressively widening spaces.

### 5) Portrait fill and scrolling rules

- Portrait is the locked reading mode for full-page display and should not introduce scroll for normal mushaf pages.
- When vertical space remains inside the reading frame in portrait, the renderer should absorb it by slightly spreading the line slots so the page fills the frame instead of leaving a large empty block below the text.
- Landscape is the only mode where vertical scrolling is allowed when the page content needs it.
- Landscape must preserve visible page content; layout choices used to fill portrait pages must not collapse the landscape page height.

### 6) Header tool anchoring

- The menu, surah picker, and filter controls stay anchored to the physical right edge of the header.
- The reading tool cluster (color, underline, tap mode, notice) stays anchored to the physical left edge of the header.
- Header control anchoring is physical, not locale-relative; switching text direction must not pull the left tool cluster inward.

## Current Implementation Surface

Visual policy currently lives in:

- `lib/screens/quran_view/index_page.dart`
  - `_ReaderRenderedPage._buildPageContent`
  - `_resolveMushafLinePattern`
  - `_resolveMushafLineFineTune`
  - `_buildMushafWordLine`

Structural source-of-truth remains:

- `assets/json/mushaf_layout_mushaf5.json`
- `tool/generate_mushaf_layout.dart`
- `test/mushaf_page_layout_test.dart`

## Regression Guardrails

- Reintroducing per-line font scaling is a visual regression.
- Reintroducing aggressive gap expansion that produces visibly large blanks between Arabic words is a visual regression.
- Reverting pages 1 and 2 to a full-width or off-center frame treatment is a visual regression.
- Reintroducing portrait scroll for standard mushaf pages is a visual regression.
- Allowing portrait-only fill behavior to hide or collapse the landscape page content is a visual regression.
- If a future task adds real kashida-aware justification, it may replace conservative gap capping, but it should not restore line-specific font scaling.