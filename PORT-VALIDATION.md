# Frame Gambit — Forever beta

Unreleased port of the current Retail 1.1.4 working copy for Forever
1.60.1.69893, Interface 16001. Retail code and SavedVariables are untouched.

## Port changes

- Primary/Secondary talent-build conditions for the nine Classic classes.
  Addon-owned build IDs do not reinterpret Retail specialization IDs. Locked,
  missing, or unreadable build state does not match a rule.
- Classic Warrior stances, Aquatic Form, Dire Bear alias, Shadowform, and
  fishing detection. Actual learned form IDs still require character testing.
- Unsupported Retail activity conditions are excluded from the picker and fail
  closed in existing data. Retail profiles containing specialization records
  are rejected rather than silently translated; recreate those rules here.
- Optional events are validated/protected during registration.
- Totem bar and separate main-hand, off-hand, and ranged swing-timer targets.
  Native Cinematic roles include swing timers and queue status. Arena frames
  remain unavailable; Action Bar 9 requires a supporting addon.
- Existing alpha leases, owner repaint handling, combat deferral, bounded
  discovery/evaluation, camera restoration, and optional adapters are retained.
- UTF-8 UI text and bundled artwork are preserved; no global compatibility
  shims or changes to Blizzard/addon host frames were introduced.

## Verification

- DialogueUI can temporarily suspend Cinematic camera writes through
  `FrameGambitAPI.SetDialogueCameraActive`. Existing camera leases remain intact;
  writes and zoom updates resume only after DialogueUI restores its snapshot.
  `Interface/AddOns/DialogueUI/tests/ForeverCamera.lua` exercises the production
  modules together, including entering/leaving Cinematic Mode mid-conversation
  and changing camera settings while suspended. Live composition still needs
  an NPC interaction check on the installed client.

- Cinematic letterbox bars are independent roots anchored to UIParent's edges
  and matched to its effective scale. DialogueUI can fade or hide UIParent
  without fading/hiding the bars. `tests/ForeverLetterbox.lua` checks HUD fades
  and hiding, both dialogue visibility paths, UI scale/display changes,
  repeated refreshes, and disabling Cinematic Mode/letterboxing while hidden.
  Live visual check: enable Cinematic Mode and black borders, open/close an NPC
  dialogue, then exit Cinematic Mode and confirm the borders disappear.

- All logical adapters now expose a matching effective scale: Player Frame,
  Ellesmere Chat, Details, controller shoulders, and controller hints. Details
  and hint bounds normalize each member before taking their union. Run
  `tests/AdapterGeometry.lua` with Lua 5.1/LuaJIT to exercise actual target
  resolution, mouseover rules, and the right-side outline toggle. It also
  covers direct Target Frame and combat; a separate native-target failure
  has not been reproduced. After reload, verify saved target outlines agree
  with Pick on screen and that hovering faded frames reveals them.

- Frame rectangles now convert from each frame's effective scale into the
  main UI's coordinate system before drawing outlines or testing mouseover.
  `tests/ForeverGeometry.lua` covers global UI scale, individual and inherited
  frame scaling, mixed-scale descendant bounds, and unreadable values on Lua
  5.1/LuaJIT. In game, scale BagsBar and MinimapCluster independently in Edit
  Mode, reopen the picker, and check both outlines and mouseover card edges.

- Native quest blobs now follow Minimap/MinimapCluster opacity, including the
  crosshatched `MINIMAP/UI-QuestBlob-MinimapRing` overlay. The implementation
  composes all nine Quest/Task/Arch Inside/Outside/Ring native alpha channels.
  Getter-less channels use observed host writes or a 255 (full byte opacity) fallback; pre-load
  overrides remain unobservable. See `tests/MinimapBlobs-validation.md` for
  source evidence, limitations and the required in-game checks.

- Forever minimap cluster handling: custom targets resolving to MinimapCluster
  now drive the native marker and escaping-texture helper. Ordinary map frames
  inherit the cluster fade; the helper does not write their alpha or change
  parent-alpha inheritance. Profile switches synchronously release helper
  fades before the next profile captures host opacity. Unset marker behavior now
  defaults to Hide at 0%; explicit Leave unchanged/Scale with map are retained.
- `lua Interface/AddOns/FrameGambit/tests/ForeverMinimap.lua` (from the client
  directory) covers cluster/map targets, partial fades, region-only and late
  overlays, owner repaint, icon rebuilds, rejected restoration, ownership
  handoff, setter-only clients, and missing optional APIs. Run with LuaJIT too.
  In game, reload and test the existing MinimapCluster rule at 0%, 50%, and
  100%, then remove it; check arrows, hover reveal, combat,
  rotating minimap, and restored icon size. Live visual checks remain manual.

- `tests/MinimapProfileSwitch.lua` covers repeated Cinematic/normal switches,
  switches during an unfinished fade, synchronous helper restoration, and
  rejected restoration/retry. In game, reload once, switch into Cinematic
  while the map is partially faded, return to normal, and reveal the map to
  100%. Repeat several times and confirm the terrain, border, and indicators
  recover their normal opacity. The native quest-area ring now follows the same visibility lifecycle.

- 31 Busted regressions passed on Lua 5.4, including imports, relationships,
  Cinematic camera restoration, and chat lifecycle. The port's round-trip test
  uses Druid Primary instead of an unavailable Retail Evoker specialization.
- Standalone Forever Core checks pass on Lua 5.1, Lua 5.4 and LuaJIT: event
  rejection, Primary/Secondary switches, locked/missing builds, forms, fishing,
  and unsupported conditions.
- Standalone target checks pass on Lua 5.1 and LuaJIT: missing/late/removed
  targets, exact alpha restoration, later owner alpha, and rejected-write retry.
- Theme smoke checks cover 17 palettes, Binder transitions and Cinematic colors.
- All shipped Lua parses with Lua 5.1 and LuaJIT. Luacheck uses the project's
  prescribed exclusions. Independent scoped compatibility/safety review found
  no blocking defects.

These are mocked and source-level checks, not live WoW validation.

## First game test

1. Try `/reload`, then `/fg`. BindCards was discovered this way in this beta.
   If the new addon is not discovered, a later full client restart is needed.
2. Choose Minimap, enable it, set Otherwise to 30%, Mouseover to 100%, and
   verify fade, hover reveal, disable/restoration, and persistence after reload.
3. Repeat with Player Frame and an action bar. Enter/leave combat and ensure
   no protected-action or Lua errors occur. Frame layout must remain unchanged.
4. Check learned forms/stances and Primary build conditions. Test Secondary
   only when unlocked. Confirm unavailable entries never match unexpectedly.
5. On a Shaman, check Totem Bar when created. Check the three swing timers when
   enabled by the game; absence should show as unavailable, without errors.
6. Toggle Cinematic outside combat, test chat input, then exit. Verify UI alpha,
   black bars and camera settings restore. Test reload and profile switching.
7. Use `/fg audit` for a read-only report. Compare FPS in the same scene before
   and after enabling a small set of targets if performance changes.

No Retail profile was copied into the beta. The installer refuses to overwrite
an existing beta FrameGambit folder and verifies every installed file by hash.

## Gamepad Companion integration checks

- Run `lua spec/gamepad_spec.lua` from the addon directory. It covers missing
  and late providers, unknown/secret input, disabled controller mode, menu
  release, held versus active state, subscription wake/idempotence, all four
  targets, alpha restoration/owner repaint/rejected retry, and repeated Boolean
  card export/import alongside existing Movement records.
- In the Forever beta, add each Gamepad bar, rest 0%, Bar active Yes 100%.
  Check LT, RT, both, release, rapid transitions, combat and reload. Verify
  that button icons and actions remain Blizzard-owned and click behavior is
  unchanged. Test the companion's active zoom alongside fades.
- Add two LT held cards with opposite answers and different opacity. Reorder,
  disable, export and import them. Confirm each answer stays with its own row.
- Open native controller menus and chat while faded; verify bar opacity rules remain active. Disable gamepad mode, and remove
  a managed target. Verify host alpha restoration, including a host repaint
  while managed. Confirm a reload without Gamepad Companion leaves the rest
  of Frame Gambit usable and gamepad cards unknown.
- Verify the Gamepad palette and Yes/No row at supported UI scales in Panel
  and Binder. Game runtime and visual checks remain manual release gates.
- Run `lua Interface/AddOns/FrameGambit/tests/GamepadOpacity.lua` from the client
  directory (also LuaJIT). It checks both rounding directions across repeated
  fades, native repaints and rejected restoration retries for both shoulders
  and the control hints. In game, reload once, then repeatedly alternate 0%,
  50% and 100%; confirm full opacity returns without cumulative dimming.
