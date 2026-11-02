# Blizzard Legacy skin

Reference: the user's September 19 Legacy Challenges screenshot and the local
Forever UI source in `StorageInvestigation/dialogueui-forever-source/Interface/AddOns`.

## Source mapping

- `Blizzard_LegacySystem/Blizzard_LegacySystem.xml`: portrait-frame shell.
- `Blizzard_LegacySystem/Blizzard_LegacyChallenges.xml`: `Legacy-Challenge-BG`.
- `Blizzard_SharedXML/Mainline/NineSliceLayouts.lua`: runtime portrait, no-portrait and inset layouts; native corner sizes and edge tile flags.
- `Blizzard_SharedXML/ListTemplates.xml`: `common-button-list-collapseExpand`.
- `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml`: `common-searchbar-a`.
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`: `UIPanelCloseButtonNoScripts`, 24 by 24.
- `Blizzard_LegacySystem/Blizzard_LegacyChallengeCategoryList.xml`: `MinimalScrollBar`.
- `Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml`: `MinimalCheckboxTemplate`, native 30 by 29.

Frame Gambit retains its existing editor controls and event handlers. Native
decorations are non-interactive except the native scrollbar, which delegates
scroll position to the existing scroll frame. No Legacy-system gameplay mixins
or frame event registrations are copied. Other appearance presets remain available.

## Layering

Leather is on the owning frame's BACKGROUND layer. Insets are on a non-mouse
child at parent +1. Shell edges are at parent +6 and portrait/title at +7.
Existing close controls remain at parent +20, with their native decoration at
+21. Appearance menus and modal blockers retain their existing higher levels.
No decoration sets a higher frame strata than its owner.

## Automated validation

`lua Interface/AddOns/FrameGambit/tests/LegacySkin.lua` runs against the actual
extracted Blizzard NineSlice implementation with fixture atlas metadata. It
checks unscaled corners, edge tile flags, layers, large/small/tall button
resizes, unused-tile hiding, allocation stability, pressed/disabled/selected
states, theme restoration, Binder transparency, scrollbar synchronization,
and preservation of the expanded Cinematic header.

These are structural checks, not a substitute for the game renderer.

## In-game verification pending

The first user capture showed repeated edge ornaments, separated arrow strokes,
bright nested inset boxes, a portrait covering its rim, and centered rule text.
The follow-up patch uses fixed corners with continuous center-texel rails for
single-atlas controls (only native tile-safe window/slider edges are tiled),
native scrollbar-arrow shapes and MinimalSlider artwork, a lower portrait
frame level, borderless Panel-layout headers, bronze inset tint, and explicit
left alignment. Modifier names are expanded for readable punctuation shortcuts.
Inspector glyphs use a desaturated warm tint in this skin.

Regression checks also cover nine-piece control rendering regardless of size,
portrait/rim ordering, native arrow restoration, slider-thumb restoration,
and header border visibility in Panel versus Binder. A second user capture is
needed to validate these corrections in the game renderer.

The Windows capture helper failed twice with `SetIsBorderRequired failed:
No such interface supported (0x80004002)`. User screenshots requested:

1. Full editor, Blizzard Legacy + Panel, a configured frame with several rules
   and relationships selected; all corners and bottom controls visible.
2. Profiles popup over the editor, checking opacity and draw order.
3. After first visual corrections, narrow/wide sizes and Cinematic mode.

Also verify mousewheel/thumb/arrow scrolling, switching Legacy → another theme
→ Legacy, and appearance persistence after reload. Pixel-perfect in-game
rendering is not yet claimed.
