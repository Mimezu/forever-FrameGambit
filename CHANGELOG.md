# Frame Gambit changelog

## 1.2.1 - Build 70338

- The PvP-flagged condition also re-checks on the new `PLAYER_PVP_FLAG_CHANGED` event.

## 1.2.0 - Size and position (experimental)

- Host fade animations no longer show a frame that should be hidden. Blizzard's status bar plays its own 0.5 s fade-in when it appears, which changes opacity without the SetAlpha call Frame Gambit watches; Frame Gambit then noticed up to a second later and applied the fade-out wait, so Primary Status Bar showed for about two seconds after a reload. Alpha animations on controlled frames are now watched: the rule's opacity is re-applied every frame while one plays and put back the moment it ends. Any other silent host change found by the opacity audit is also undone at once instead of waiting and fading. New test `tests/HostAnimations.lua`.
- Pick on screen and Discover visible UI are now the same width, and their visible edges line up with the search box (the Legacy button art sits about 3 px inside the button).
- Sizes are shown as a scale factor (x0.75, x1.25) on the cards and in the Size picker, so they are not confused with opacity percentages.
- The frame holding the minimap (Minimap, MinimapCluster or a parent) stays at its normal opacity until the loading screen is gone. Then the minimap zoom is nudged one step and back while it is still at full opacity (what fixes an empty map by hand), and half a second later the frame goes straight to its rule state with no wait or fade. Starting it faded left the minimap terrain empty until zoomed. Only on the first capture during loading; frames added later are not held. The startup timeline is kept in `FrameGambitDB.minimapStartup`.
- New `/fg minimapdebug` prints the minimap's frame state, the stack multiplier, the renderer gate and the native blob channels, for diagnosing minimap display problems.
- Startup no longer applies sizes and positions during login and loading screens (only opacity is settled there); they are applied by the normal evaluator passes once you are in the world.
- "Quest updated" and "Quest objective updated" no longer fire from the quest-log refreshes the game sends while logging in, reloading and zooming (QUEST_LOG_UPDATE and QUEST_WATCH_UPDATE within 6 seconds of a loading screen are ignored, and any recorded during loading are dropped). That refresh revealed frames such as Objectives for 3 seconds plus their wait after every reload. Accepting or turning in a quest, and quest progress after the loading has settled, still count. New test `tests/QuestLoadNoise.lua`.
- Frames now start in their rule state after a reload or login. Before, a frame given a long wait before fading out (for example Objectives at 0% with a 3.9 s wait) was first seen at full opacity and then waited before fading. The first time Frame Gambit takes over a frame in a session it now applies the rule at once, with no wait or fade, and every frame is settled as soon as you log in and again on each loading screen. Later re-captures (a profile switch, for example) still fade as before.
- The two timing buttons (Fade timing, Wait) are now one full-width button that opens the timing window and shows every value: `In 0.2s / Out 0.2s / Wait 3.9s` (`<host label> / Wait ...` for frames that own their fade animation). The timing window uses the same list-button art as the cards in the Blizzard Legacy appearance, and its subtitle is left-aligned under the title.
- Blizzard Legacy appearance: the reaction cards and the Otherwise row now use the same list-button art as the frame list and the right-hand cards, whose lit top edge makes each card stand out from the leather behind it.
- Yes/No choices on cards (Movement, Form and the gamepad conditions) are now one button that flips between Yes and No instead of two. The Movement row's answer button follows its full name, so "Movement" is no longer cut off.
- Smoother animation: opacity, size and position transitions that are already running are now advanced on every game frame between the 20 Hz evaluator ticks, instead of only on the ticks. What to fade to, the wait before fading out and all ownership checks are still decided by the evaluator, and nothing extra runs while nothing is animating (a table-empty check per frame).
- Rules can now also change a frame's size and position. Each rule card has a small size-and-position toggle next to its opacity number. The requirements **+** button now sits before the condition name (the count shows on the button, so the name no longer ends with "+ 1"). The on/off switches (size-and-position toggle, Instant, Keep) look like the frame list: dark with muted text when off, accent-filled with white text when on. They hover exactly like the frame list rows. Off, the card is exactly as before. On, **Instant**, the size and **Move** (position) appear beside the toggle (on a second line only when the card is too narrow, for example a long condition name in a small editor window). The Otherwise row works the same way.
- Opacity, size and position each come from the first matching rule that sets them, then from Otherwise. Example: In combat 100% + Size x1.2; In party opacity only; In dungeon instance Keep opacity + Size x1.1, 40 up.
- **Keep opacity** is a switch in the rule's opacity window (shown for rules with the toggle on). It makes the rule change only size or position; opacity comes from the next matching rule or Otherwise, and the card's opacity button reads Keep. Choosing an opacity turns it off.
- The Otherwise row has the same toggle for the frame's default size and position.
- Size scales the frame around its centre, or around any corner or edge: the Size picker has a 3x3 **Grow from** grid (one setting per frame, used by all of its sizes; changing it re-places the frame at once). Export record O. Position moves it from where its owner (Edit Mode, Ellesmere...) places it, in UI units, with arrow buttons and a 1 / 10 / 50 step.
- Mouseover rules can change size but never position, and hover also counts the frame's normal area, so a resized frame cannot flicker under the cursor.
- Size and position changes use the frame's fade-in and fade-out times and its wait before fading out, unless the rule's small **Instant** button is on: then the change happens at once, ignoring the fade times and the wait. The rule taking effect decides (Otherwise when no rule is in charge), so In combat can snap while In dungeon still eases. Export records I (rule) and N (Otherwise).
- Frame Gambit only takes over a frame's geometry once a rule or Otherwise sets a size or position. When nothing needs it any more (toggle off, frame reset, profile switch, logout), it writes back the owner's exact anchor and scale.
- Owner changes are followed: when Edit Mode or another addon moves or rescales the frame, that becomes the new normal place and the rule layout is applied on top. While Edit Mode is open, frames show their normal layout.
- Protected frames (action bars, unit frames, party and raid frames...) are never moved or resized in combat. An In combat size is applied at the moment combat starts, before the lockdown; other changes wait until combat ends and the editor says so.
- Not available for frames that are really several frames (Chat, gamepad bars and other composite adapters), frames labelled Opacity only, and frames held by more than one anchor.
- Profiles, copy/paste rules and export/import carry the new settings (new K, Z and Y export records). Older versions of Frame Gambit cannot import a profile that uses them.
- Provider API: `RegisterTarget` accepts `layout = false` to keep a registered frame opacity-only.
- New regression test `tests/FrameLayout.lua`. Untested in game.
- Fixed the Help button doing nothing in the first 1.2.0 build: the new Help text had broken `Tutorial.lua`, so it failed to load. New test `tests/TocSyntax.lua` compiles every file in the TOC.
- Fixed two mistyped texture paths in the Add a reaction window (`Interface\Buttons` written with single backslashes). No visible change: both textures are recoloured right after. `Options.lua` now also loads in LuaJIT and other strict Lua parsers.

## Unreleased - Gamepad-safe Cinematic Mode

- Fixed the controller getting stuck after Cinematic Mode on Forever: A no longer jumped, B no longer backed out, and windows opened without the gamepad cursor until `/reload`. Entering Cinematic Mode called Blizzard's `CloseAllWindows()` from addon code, so Blizzard's gamepad window manager stored its focus state under Frame Gambit's taint (BugSack 2026-09-27: `SetPreferredGamepadInteractTarget()` forbidden, then `SmartNavigation` Show/Hide refused when the map opened or closed). This is the same problem Forever Windows 1.3.2 fixed.
- Cinematic Mode now leaves open windows open. Blizzard panels and windows registered for Escape closing stay visible above the scene, including ones opened during it, so none of them fades into an invisible mouse trap. Close them as usual.
- The Cinematic camera no longer hides Blizzard's experimental-camera warning from addon code. It still stops the warning from appearing.
- New regression test `tests/GamepadSafeCinematic.lua`.

## Unreleased - Class-action button prompts

- Picked gamepad class-action buttons now fade their sibling L1 + L2 / R1 + R2 input prompts with the button. Existing rules and target IDs remain valid. Native prompt hiding is preserved, and resetting the button restores the prompt's own opacity. An independently managed prompt keeps its own rules.

## Unreleased - Active rule reporting with health conditions

- Fixed missing active-row highlights and misleading "Otherwise" status when Mouseover or another public rule wins above protected health/mana rules. Preserve rule identity and inherited status; protected results still use the game-controlled health/mana message.

## Unreleased - Gamepad frame highlight

- Fixed party/raid member navigation: the selected member now also highlights its containing group frame, even when Blizzard's ordinary menu-focus mode is inactive. Existing Frame highlighted rules work unchanged.
- New Gamepad condition "Frame highlighted", with independent Yes/No requirements. Reveals a frame when it or a child control has native gamepad UI focus, including menu navigation. Does not require Gamepad Companion.
- Reads native focus without hooks or changes to Blizzard's navigation state. Returning to player control clears the condition even if Blizzard retains its previous focus target; unavailable or restricted focus matches neither answer.

## Unreleased - Sitting at a campfire

- New Character condition "Sitting at a campfire": true while Forever's one-minute campfire timer runs, and false once the camp buffs land or you stand up.
- Works out of the box: the timer aura "Welcoming Campfire" (1229739) is built in (confirmed in game). For a campfire variant it does not recognize, learn its aura with `/fg campfire` while the timer runs. `/fg campfire <n>` picks from a list when the match is ambiguous; `/fg campfire list` and `/fg campfire clear` manage the learned aura. The learned aura is stored account-wide in `FrameGambitDB.campfireAuras`.

## 1.1.17 - Evaluator allocation pass

- The 20 Hz evaluator allocates far less per tick: linked-parent hover walks a reused stack instead of building a closure and visited table per target per tick (verified equivalent on 25,005 random link graphs, cycles included), and missing reaction/requirement lists use one shared empty table.
- Each target's frame is resolved once per tick; hover checks and alpha application share the lookup. The cache lives only inside a tick.
- Minimap stack conflict checks allocate only when a conflict exists.
- A burst of ADDON_LOADED events refreshes the gamepad integration once after the burst instead of once per addon. The UNIT_SPELLCAST event test is memoized.
- Retired the SavedVariables-era `/fgstorage` and `/fgrecover` tools, the `FrameGambitStorageDiagnostics` variable and the local profile snapshot; both files are kept in `StorageInvestigation/framegambit-retired-storage-tools-20260925`. The `/bug` Issue Reporter toggle stays.

## Unreleased - Combined protected percentage rules

- Replace protected fallback curve points with public selection bounds and a reused native status bar for opacity composition. Verify native clamping before use and expose unsupported-client errors through `/fg healthdebug`.
- Regression coverage now rejects protected curve points and checks all combinations of player health, party health, and player mana, including priority and border scaling. In-game confirmation pending.

## 1.1.16 - Party borders and independent child opacity

- Apply the normal profile immediately on Cinematic exit, avoiding a visible restore-then-fade flash.
- Prioritize known party-member borders before bounded subtree scans and preserve initially protected border opacity for restoration.
- Keep whole-party selection borders faded when health rules produce protected opacity, without calling the restricted generic curve evaluator.
- Apply a child frame's own rules even when its initial opacity is protected by its parent; preserve and restore opaque native opacity safely.


## 1.1.15 - Party member health and mana

- Add Any and numbered party-frame selectors to health/mana rules. Numbered rules track the unit actually assigned to CompactPartyFrameMember1-5, including the player.
- Preserve member choices in copied, saved and exported rules; old rules retain Any behavior.

## Unreleased - Nested frame selection

- Allow containers and nested frames, including CompactPartyFrameTitle, to be added in either order with separate rules.
- Drive protected health/mana opacity through client curves instead of treating every protected percentage as an unmatched condition. Preserve priority and party-member matching; protected output applies immediately without fade timing and the editor reports game-controlled opacity.

## 1.1.14 - Player, party and loot conditions

- Add repeatable player and party health/mana percentage cards with six comparisons and editable thresholds.
- Add party-member combat, party loot and loot-roll winner conditions.
- Add recognized major cities and combat with observable elites, rare elites and bosses.
- Preserve comparison settings in copied/shared profiles; unavailable combat data never triggers a condition.

## 1.1.13 - Cinematic mail reading

- Keep opened letters visible in Cinematic mode, including reopening mail while the inbox remains open.

## 1.1.12 — Reload startup work

- Build the editor and its skin on first use instead of allocating hidden controls at login.
- Preserve first-use frame selection through /fg pick and combat rejection.

## 1.1.11 - Panel layout only

- Removes Binder mode and the layout selector. Existing saved Binder selections
  automatically use the normal Panel layout; appearance and frame rules remain.


## 1.1.10 - Cinematic and client parity

- Keeps suite addon windows and their dialogs visible in Cinematic, including
  windows opened afterward and those targeted by explicit fading rules.
- Backports bounded chat discovery, shared evaluator audits, dynamic editbox
  cleanup, pooled highlight restoration, and safer secret-value handling.
- Fixes importing escaped profile text containing separate fade timings.

## 1.1.9 - Cinematic spell alerts

- Cinematic mode leaves Blizzard spell activation overlays visible by default,
  including newly created or pooled overlay visuals.
- The existing Spell Proc Overlay target can still hide or fade them with rules.


## 1.1.8 - Achievement chat activity

- Guild achievements now trigger the existing guild-message condition.
- Current party and raid members achievement announcements now trigger the
  group-message condition. Nearby strangers do not.
- Existing rules and durations are preserved.

## Unreleased

- Fix Bar active for manually picked native gamepad bars, including the stance bar, and apply their opacity immediately when native bar selection changes.

- Add CHAT's "Friend logs on or off" condition for localized character-friend notifications and Battle.net login/logout alerts, with configurable duration and opacity.

- Hide native minimap icons and controllable quest blobs at map opacity 30% or below; restore above 30%. Keep terrain at the configured opacity. The complete renderer fallback remains restricted to exactly 0%.

- Suspend the unprotected native Minimap renderer at exact zero opacity to cover quest areas that escape blob alpha setters; restore at the start of reveal. Preserve cluster/direct-map hover geometry, host Show/Hide decisions, profile release and retry behavior. Live confirmation of the remaining quest-area overlay is pending.

- Add a CHAT condition category containing Typing, Chat contains text, and private/guild/group/General activity. Typing uses chat input focus and respects configured opacity in Cinematic mode. Text rules support literal, case-insensitive phrases, item-link names, individual durations, late chat windows, rule copying and profile sharing without retaining messages.
- Correct native minimap blob opacity to its byte range so overlays return after hiding. Keep full 0% hiding; the user confirmed recovery in Forever after reload.

- Include native quest, task and archaeology blob fills, outside overlays and patterned rings in Minimap/MinimapCluster visibility. Track host alpha writes, audit faded native layers, and restore on release; getter-less channels fall back to full opacity when no host value has been observed.

- Align the Legacy title-bar close button to Blizzard's native 24px size and TOPRIGHT (1, 0) anchor. Align inspector checkbox centers with their status labels and give the profile arrow more text clearance.

- Polish Blizzard Legacy from the first in-game screenshot: remove repeated button-edge ornaments, replace segmented arrows and flat slider thumbs with native artwork, put the portrait under its rim, remove nested header boxes, soften silver insets to bronze, preserve font alignment, left-align rule labels, and expand modifier names in shortcut labels.

- Add the selectable Blizzard Legacy skin using Forever's Legacy Challenges textures and native frame border definitions. Preserve corner sizes and tile edge runs; use native close controls, search-field artwork, checkboxes, and scrollbars. Move the editor identity into the portrait title bar and retain Cinematic and Binder layouts.

- Replace the single-window Blizzard Chat fallback with a dynamic whole-chat group. Future whisper windows, tabs, input, dock, minimized windows and alpha-independent children follow existing Chat gambits. Track native opacity separately, avoid multiplying parent and child fades, restore on release, and handle late Ellesmere handoff.

- Exempt native bank windows and their children from Cinematic blackout and hooks even while hidden. Add bounded protected-action diagnostics and `/fgblocked` to identify a recurring block.
- Add private, guild, group/raid and General-channel message Events with separate configurable durations (10 seconds by default); matching messages restart their timers.
- Remove Cinematic mode's automatic Alt reveal; use individual Alt held gambits instead. The explicit frame picker still reveals frames while picking.
- Add XP gained under Events, with a configurable duration (5 seconds by default), including gains that level up the player.
- Fade Blizzard's selected party-member highlight with Party Frames, including at 0% opacity, and restore its native opacity when control is released.
- Split frame timing into independent fade-in and fade-out times. Existing settings initialize both directions to the previous fade duration; copying rules and sharing profiles preserve both times.

## 1.1.7

- Apply controller bar opacity synchronously with the native bar-selection notification, preserving rule priority and alpha restoration.
- Cancel controller bar reveal commitments and fade timing on native switches so trigger release can hide the bar immediately.

## 1.1.6

- Add bounded startup storage diagnostics and a command to recover missing profiles from a local snapshot, without replacing existing profiles.
- Investigate the reported reload reset; no root-cause fix is claimed by this diagnostic build.

## 1.1.5

- Add named Left shoulder and Right shoulder targets for Blizzard's Forever controller HUD. Each target fades its background, icon and pressed highlight together without changing input or layout. These targets do not require Gamepad Companion.
- Add Control hints as a whole-panel opacity target with visible-content preview bounds.
- Add optional automatic profile selection for Gamepad and Keyboard/mouse UI modes.

## Unreleased

- Yield Cinematic camera writes to DialogueUI during conversations, then resume or restore the camera after dialogue ends. Preserve camera settings changed while dialogue is open.
- Keep Cinematic Mode's black borders visible and opaque while DialogueUI fades or hides the HUD. Independent border frames retain the configured height and UI scale, and still hide when Cinematic Mode or letterboxing is disabled.
- Fix Forever Cinematic chat staying revealed after typing: use the current chat API and return inactive native edit-box borders to the Cinematic blackout instead of retaining their temporary open-window exemption. Restore native inactive opacity on exit.
- Fix Cinematic minimap reveals remaining transparent after a normal-profile cluster fade: compare actual alpha readbacks when restoring target ownership, so native rounding cannot strand a faded parent. Apply the same bookkeeping to minimap helper visuals.
- Temporarily reveal managed controller bars, shoulders and hints while Gamepad Companion's editor is open, without changing saved opacity rules.
- Keep the four gamepad bars under their configured opacity rules while typing in chat or using native menus, instead of releasing them to native opacity. Gameplay input conditions remain unavailable in menu/chat contexts.
- Add Left shoulder held, Right shoulder held and Both shoulders held as Yes/No cards and independent requirements, using Gamepad Companion's physical button state.
- Add independent Yes/No Gamepad requirements to reaction cards, including combinations of trigger states. Preserve their answers through profile export/import and reject opposite answers for the same condition.
- Fix progressive dimming of the control hints and both shoulder targets: retain actual native alpha readbacks so rounded fade values never become a new opacity baseline.
- Releases temporary minimap fades before profile/Cinematic transitions so
  the next profile cannot inherit a helper's faded opacity. Removes the
  redundant direct-map alpha override from cluster fading.

- Automatically acknowledges the experimental camera warning when Cinematic
  Mode starts, including after reloads, while keeping camera settings enabled.

- Restores mouseover and selection outlines for logical frame adapters by
  exposing their geometry scale, including Player Frame, Ellesmere Chat,
  Details, and native controller shoulders/hints. Composite bounds account
  for each member's scale before combining them.

- Corrects frame outlines and mouseover areas when global UI scale and
  individual Edit Mode or inherited frame scales differ.

- Forever controller integration: four native cross-bar opacity targets and repeatable Gamepad mode, LT held, RT held, Both held, and Bar active Yes/No cards. Gamepad Companion supplies input state; native menus release the opacity lease. Profiles preserve each card's answer and order.

- Forever beta port: Interface 16001, Primary/Secondary build rules, Classic forms and fishing, guarded events, swing timers and Totem Bar. See PORT-VALIDATION.md.

- Stops Frame Gambit from controlling native quest, task, and archaeology
  area overlays, so world-quest zones remain owned by Blizzard and the map UI.
- Adds an optional saved Binder layout: transparent, click-through gutters,
  attached editor cards and content-fitted rules.
  Appearance > Layout restores the original Panel layout at any time.
- Removes the footer message and bar in both layouts. Reset frame and the
  conditional Remove from list action now live at the bottom of the context card.
- Expands the saved Appearance selector to all 17 suite themes with a compact
  BindCards-style grid, live repainting, contrast-safe input ink, and stable
  orange Cinematic accents for every class.

## 1.1.3 - Three bundled appearances

- Adds a live, saved Appearance selector with Ellesmere, Mimezu, and Luminous.
  Ellesmere remains the default and keeps its exact shell treatment; the two
  alternatives include complete local palettes and their own shell artwork.
- Repaints open and later-created Frame Gambit windows without a reload while
  preserving Cinematic's amber identity and all functional Ellesmere adapters.

## 1.1.2 - Exact shell parity

- Uses the exact requested EllesmereUI shell texture and matching crop,
  overlay, title/footer bands, borders, font shadow, controls, and art stripping
  while keeping Frame Gambit's custom marks and icons visible.

## 1.1.1 - Self-contained visual skin

- Bundles Frame Gambit's complete dark shell, neutral panels, controls, font,
  borders, and class accent so the editor looks the same with or without
  EllesmereUI installed. Ellesmere frame visibility integrations remain intact.

## 1.1.0 - BindCards visual refit and Cinematic composition

- In Preview mode, hovering a frame name now moves the screen outline immediately;
  clicking still selects the frame for editing.
- Adds a Cinematic FOV slider and a reversible left-camera composition that
  adapts to zoom, can be chosen as the entry default, and has its own keybind.
- Uses the same form- and mount-specific camera curves as Narcissus, leases
  Retail's two centering locks only while the offset is active, and performs a
  single camera refresh when composition changes instead of a repeating zoom.
- Restores the player's prior FOV and shoulder offset when Cinematic ends,
  without overwriting a later camera change made by the player or another addon.
- Reveals the complete Chat target only while the player is typing in
  Cinematic—never for incoming messages—then returns it to its configured wait
  and fade after the chat input closes.
- Makes native quest, task, and archaeology blob fills, edges, ring alpha, and
  ring scale follow a fully faded Minimap, including tracked quest circles.
- Aligns the editor, Help center, and guided tutorial with the BindCards visual
  language: paper-dark surfaces, quiet blue-gray 1px borders, compact controls,
  teal scrollbars, and consistent hover/remove states.
- Uses EllesmereUI's public third-party skin facade for the live window shell,
  panels, controls, fonts, close actions, and editor inputs when enabled.

## 1.0.0 - First friends release

- Separates the add-requirement control from opacity, gives it a distinct
  lavender treatment, and enlarges its bare plus mark for clearer recognition.
- Keeps the teal reaction-card highlight synchronized with the live winning
  rule, including when conditions change without another editor action.
- Renames the dungeon location condition to **In dungeon instance** so it is
  clearly distinct from raid and party group conditions.
- Renames **Moments** to **Events**, moves the former World conditions into
  **Group & instances**, and removes the empty World category.
- Splits **Presence** into ordered **System** and **Character** categories,
  separating mouse and modifier input from character state.
- Builds both reaction reorder arrows from the same mark rotated 180 degrees,
  keeping their bar lengths and thickness identical.
- Shows the Help notification only for a deliberately newer Help revision and
  permanently clears it as soon as the player opens Help.
- Adds the official Frame Gambit icon to the addon listing and editor header.
- Adds a Busted regression suite for Lua compilation, profile transfer,
  clipboard escaping, checksum validation, requirement conflicts, and
  visibility-loop prevention.
- Removes stale minimap compositor bookkeeping and unused evaluator/UI values
  found by the first focused Luacheck pass.

## 2.13.7 - Clearer interface text

- Rewrites editor labels, tooltips, status messages, and Cinematic controls in
  short, direct language focused on the player's next action.
- Reworks frame-picker guidance around the mouse wheel and teal outline while
  replacing internal terms such as UI roots, adapters, and resolved opacity.
- Tightens Help and the guided tutorial so each heading, summary, and body adds
  new information without repeating the same idea.
- Clarifies profile transfer, availability, relationship, audit, and recovery
  messages while retaining legacy import and API identifiers for compatibility.

## 2.13.6 - Preview target switching

- Keeps the left target-selection rail visible and interactive at 30% opacity
  during Preview while hiding the rest of the editor beneath the return bar.
- Switching rows in Preview updates the top message and selected-frame outline
  immediately without returning to the full editor.
- Restores every editor section, backdrop, and input state when Preview ends or
  the editor is closed.

## 2.13.5 - Font-safe picker navigation

- Replaces picker arrow glyphs with plain ASCII labels so custom WoW fonts do
  not render the mouse-wheel guide or candidate navigation as empty squares.

## 2.13.4 - Focused on-screen frame picker

- Replaces the centered picker banner with a cursor-adjacent guide that keeps
  the mouse-wheel instruction prominent.
- Reserves teal for the one current candidate, shows only its immediate
  neighbours as muted context, restores the bounded lavender overview map,
  and lists the previous/current/next position.
- Prefers compact named UI roots, hides full-screen and model-scene technical
  layers by default, and keeps them reachable through **Show technical**.
- Adds friendly frame descriptions, secondary technical names, clickable
  Previous/Next controls, and clear warnings for broad or technical frames.
- Keeps the entire scene consistently dim when the cursor is over empty ground
  or a full-screen technical layer, preventing rapid full-screen brightness
  changes while moving between smaller UI controls.

## 2.13.3 - Visible target dragging

- Shows a complete target-row preview under the cursor while dragging a frame
  onto its visibility parent, matching the existing Gambit-card drag feedback.
- Restores the source row and clears drag state cleanly after a drop, a
  cancelled drag, or closing the editor.

## 2.13.2 - Stock player aura targets

- Adds separate built-in targets for Blizzard's normal player buff and debuff
  frames without conflating them with Cooldown Manager's tracked-buff viewers.
- Promotes matching picker-created `BuffFrame` and `DebuffFrame` entries into
  the new semantic targets while preserving their profile relationships.

## 2.13.1 - Broader Blizzard target catalog

- Adds explicit built-in targets for the remaining Blizzard action bars, pet
  and stance bars, extra abilities, Buff Bar Cooldown Manager, party and arena
  frames, menu bars, encounter widgets, status bars, and common HUD overlays.
- Uses stable semantic target IDs with Ellesmere fallbacks instead of scanning
  every UI frame at startup. Frames that have not loaded remain safely marked
  unavailable until Blizzard or their owning addon creates them.
- Promotes matching picker-created targets into the new built-in entries while
  preserving profile rules, groups, links, and visibility relationships.

## 2.13.0 - Performance and safety milestone

- Avoids idle editor update loops when selection outlines, drag previews, or
  the frame picker are not active.
- Reduces steady-state evaluator allocations, shares cursor and timing reads,
  filters player-only events earlier, and avoids redundant Cinematic and
  Minimap work.
- Caches relationship ancestry lookups and preserves newer host alpha changes
  during immediate or delayed restoration.
- Clears in-flight fades when reveal groups or linked relationships change.
- Rejects altered profile exports and keeps impossible Movement AND
  requirements out of imported or newly edited profiles.

## 2.12.0 - Clean standalone release

- Ships one install folder: `FrameGambit`. The temporary Priority Fader
  SavedVariables bridge and its release packaging have been removed.
- Rewrites the README around what players can do with the addon, with concise
  feature explanations and screenshots instead of development history.
- Keeps legacy slash commands, integration aliases, and old profile-export
  imports available for players who still use them.

## 2.11.0 - Frame Gambit public milestone

- Completes the Frame Gambit package rename with a safe Priority Fader
  settings bridge and backward-compatible commands, exports, and integrations.
- Rebuilds profile import/export for reliable WoW clipboard round trips and
  portable sharing across different Blizzard and addon frame setups.
- Refines the main and Cinematic editors, relationship controls, condition
  picker, reaction reordering, tutorial flow, and compact-window layouts.
- Adds an illustrated GitHub overview and publishes both the Frame Gambit
  folder and its migration bridge in the install-ready release ZIP.

## 2.10.9 - Profile picker header spacing

- Gives the Profiles description its own full-width row beneath the header
  actions, preventing it from overlapping Import and Export.

## 2.10.8 - WoW edit-box import round trip

- Detects and decodes Retail EditBox pipe escaping before checksum and record
  validation. A copied export whose visible `T` row has six fields no longer
  reaches the parser as eleven alternating fields.
- Makes shared profiles installation-aware: compatible target IDs resolve to
  the recipient's available Blizzard/addon frames, while unavailable targets
  and their dangling relationships are skipped with an explicit count.

## 2.10.7 - Cinematic editor composition and import compatibility

- Makes **Exit cinematic edit** the single scene-exit action, keeps normal
  profile switching available, and replaces the duplicate Scene/Turn off
  controls with clearly separated Black bars and Shortcut groups.
- Aligns and compacts Transition & relationships, its action cards, and the
  reduced-width header while preserving Frame Gambit's existing skin.
- Parses state-reaction exports when the WoW clipboard removes either or both
  trailing empty optional fields, and reports the exact line shape for any
  genuinely unrecognized entry.

## 2.10.6 - Clipboard-safe profile parsing

- Normalizes CRLF, bare carriage returns, clipboard BOM markers, outer
  whitespace, and harmless line-edge whitespace before validating an import.
  The checksum is advisory after normalization: structurally valid records are
  still fully validated and imported when Retail's editor changes invisible
  clipboard bytes.

## 2.10.5 - Rebuilt profile transfer

- Rebuilds Import/Export around Retail's supported scrolling edit-box widget,
  keeps the underlying profile picker hidden so only one close control is
  visible, resets pasted exports to their first line, and validates pasted
  imports live.
- Import supplies a unique profile name by default, saves without a live UI
  switch, returns to a refreshed profile list, and surfaces parser or runtime
  errors directly in the modal.

## 2.10.4 - Reliable profile import commit

- Imports now save the validated profile before any profile switch or editor
  rebuild. The picker confirms the result and lets the player select the new
  profile normally; unexpected runtime errors are shown in the import dialog.

## 2.10.3 - Reliable profile import control

- Simplifies profile import to one **Import profile** action. It validates and
  imports in the same click, and the control is raised above the long-export
  text field so pasted content cannot intercept the click.

## 2.10.2 - Reliable renamed-package settings bridge

- Corrects the first rename migration: WoW stores SavedVariables by addon
  package file, so the `FrameGambit` package alone cannot read the old
  `PriorityFader.lua` file.
- Ships a temporary, dependency-ordered `PriorityFader` settings bridge beside
  the new folder. It loads only the old saved settings and hands them to Frame
  Gambit before login; it never loads the former addon code.

## 2.10.1 - Frame Gambit package rename

- Renames the install folder, TOC, saved-variable primary name, keybinding,
  slash-command family, API, addon-owned frame names, and release ZIP to
  **Frame Gambit**.
- Automatically adopts existing `PriorityFaderDB` settings at first login and
  migrates the old Cinematic keybinding when no new one has been chosen. Old
  slash commands, profile exports, and integration API calls remain compatible.
- Adds clear update instructions: remove only the old addon folder, keep
  SavedVariables, and install the new `FrameGambit` folder.

## 2.10.0 - Clearer Cinematic editor entry

- Renames the header action to **Cinematic mode edit**. When inactive it uses
  the normal button treatment with an amber label; while editing Cinematic it
  remains visible as a full amber status marker, with scene exit continuing
  to live in the inline **Turn off** control.

## 2.9.0 - Editor and Cinematic refinement release

- Reworks the main editor into a clearer Targets, ordered reactions, and
  Transition & relationships layout, with compact visual controls and a
  purpose-made flat inspector icon set.
- Refines Cinematic editing so it stays within the familiar main editor while
  preserving access to normal profiles and safe scene exit.
- Expands the gambit and tutorial experience with repeatable conditions,
  requirement conflict protection, live priority reordering, and a real
  temporary practice frame.

## 2.8.15 - Calmer inspector scale and timing language

- Replaces the inspector sheet with the preferred composed icon artwork and
  scales each sprite down within its cell for quieter card spacing.
- Uses the same unambiguous timing names everywhere: **Fade duration** and
  **Wait before fade** replace the reversed-looking Transition time/Fade-out
  delay terminology in the timing popup.

## 2.8.14 - Inspector icon set

- Adds a purpose-made, flat lavender icon sprite sheet for Transition,
  Preview, Hover group, Linked child, and Visibility child. The inspector now
  uses those consistent artwork assets instead of improvised texture bars.

## 2.8.13 - Reliable header and remove icons

- Uses a dedicated profile-label font string, leaving no legacy glyph content
  behind the drawn profile arrow on clients with incomplete font coverage.
- Renames the header's temporary editor-collapse action from **Peek** to the
  clearer **Preview**.
- Draws the reaction remove X in deep red, so the destructive cue remains
  stable through normal and Cinematic theme refreshes.

## 2.8.12 - Visual controls pass

- Replaces unreliable font-glyph arrows with drawn triangles for profile
  selection and reaction priority controls; the mirrored up/down icons also
  appear correctly on the live drag card.
- Gives reaction removal a restrained deep-red treatment instead of the
  normal lavender action color.
- Rebuilds the right inspector toward the visual-card layout: compact Fade and
  Wait controls, drawn Transition/Preview/relationship icons, Preview and
  relationship cards with visual On/Off states, and tooltips in place of the
  always-visible safety paragraph.
- The header Cinematic button is now an entry control only. While active, the
  profile control stays available: choosing any normal profile exits
  Cinematic editing and returns to that profile in one step. The inline
  **Turn off** control remains the quick return to the prior profile.

## 2.8.11 - Editor hierarchy refresh

- Reworks the Frame Gambit editor into a clearer three-part workspace:
  **Targets** on the left, ordered live rules in the center, and a wider
  **Transition & relationships** inspector on the right.
- Moves profile and mode controls into a more legible header hierarchy, puts
  rule copy/paste alongside the rule workspace, and keeps the footer honest:
  changes apply live and never need a separate save step.
- Gives the inspector distinct Transition and Relationships sections, with
  room for the existing safe timing, outline, marker, and connection controls.

## 2.8.10 - Restored reaction cards

- Fixes a Boolean check in the AND-compatibility guard that incorrectly hid
  every card in the normal Add reaction picker. Compatibility filtering now
  applies only while editing AND requirements.

## 2.8.9 - Centered drag cards

- The condition text on a dragged reaction card now uses the same centered
  alignment as its stationary row.

## 2.8.8 - Focused quest moments

- Quest moment cards are now mutually exclusive as AND requirements. This
  prevents redundant combinations such as Quest accepted + Quest updated;
  use separate ordered reactions when different quest events need responses.
  Loot window opened and Looted an item remain combinable.

## 2.8.7 - Compatible travel requirements

- Adds mutually-exclusive travel-mode guardrails. Pet battle cannot be
  combined with another travel state; Vehicle, Flight path, and Fishing are
  exclusive modes. Valid pairs such as Flying + Dragonriding and Swimming +
  Underwater remain available.

## 2.8.6 - Reliable reaction reordering and Delve context

- Reaction dragging now uses a dedicated full-card visual ghost beneath the
  cursor, while the original cards safely make a live, card-sized gap at the
  destination. The former thin insertion line has been removed.
- **In Delve** is now mutually exclusive with every other specific instance
  location, including Arena, Dungeon, Raid instance, Battleground, Scenario,
  and open world.

## 2.8.4 - Cleaner target search and compatible AND requirements

- Removes the Managed-only filter now that the target rail is always a tree.
  The rail now uses an indented **Search frames** field with a search icon.
- The AND-requirements picker now prevents combinations that Retail state APIs
  guarantee cannot be true together, including mutually exclusive group and
  instance contexts. Invalid choices are greyed out with an explanation.
- Older or imported impossible combinations are kept safely for manual
  cleanup, highlighted red, and remain clickable to remove.

## 2.8.3 - Easier AND requirement recall

- Category navigation now shows a small teal corner marker wherever that
  category already contains an added AND requirement for the reaction.
- Hovering a reaction's `+N` requirements button now lists the base condition
  and every added requirement, so the complete match is visible at a glance.

## 2.8.2 - Clearer condition categories

- Gives the Add reaction and Add requirements category row its own inset
  **CATEGORIES** navigation rail. Categories now use muted labels and a thin
  active underline, distinct from the raised condition cards they reveal.

## 2.8.1 - Tree-only target rail

- Removes the List/Tree switch. The target rail now always presents managed
  frames as their visibility hierarchy, with linked children indented below
  their parent. Dragging a managed frame onto another managed frame is always
  available for creating that relationship.

## 2.8.0 - Corrected public package

- Corrects the malformed 2.6.0/2.7.0 public ZIPs so Frame Gambit loads and
  every documented slash command works after installation.
- Cinematic now recognizes all Blizzard panel-manager windows as intentional
  player windows. It closes them when the scene starts, then keeps any opened
  afterward visible and usable above the scene, including future standard
  panels instead of relying on a hand-maintained exception list. Friends and
  guild/community windows also have direct Retail-version fallbacks. Bags,
  spells/talents, collections, group/PvP finder, calendar, profession, macro,
  keybinding, and common interaction frames have the same fallback coverage.

## 2.6.0 - Cinematic editor and expanded gambits

- Opening the World Map during Cinematic Mode now keeps every map view visible
  above the scene while Cinematic remains active.
- Adds `/fg` as the shortest slash alias for opening Frame Gambit.
- Adds a configurable **Form** reaction with a dense form picker and Yes/No
  state choice. Forms unavailable to the current class/spec are retained,
  muted, and skipped, enabling one profile to safely cover several specs.
  Supported entries are Druid forms, Shadowform, Ghost Wolf, and Demon Hunter
  Metamorphosis, including Devourer Void Metamorphosis.
- Establishes the reusable picker-card Boolean pattern: a two-part **Yes / No**
  control with the selected answer filled. The new **Movement** card uses it
  directly (Yes = moving; No = stationary); old Moving/Stationary rows remain
  supported in saved and imported profiles.
- Adds a repeatable **Spec** picker card. It asks for class first and then a
  spec, preserves other-class rows for shared profiles, and safely skips those
  rows until they apply to the current character.
- Adds **Stealthed / invisible**, **Fishing**, and **In Delve** conditions.
  Stealth refreshes only on player aura changes; fishing uses the player’s
  active Fishing channel; Delves use the supported party-state API.
- Adds an **On/Off** switch to every reaction row. Disabled rows retain their
  ordered configuration, are visibly greyed out, and are skipped by the
  evaluator. Form choice and row-enabled state round-trip through profile
  export/import.
- Added two precise pet conditions: **Class pet active** (the player's combat
  pet unit) and **Cosmetic companion active** (a summoned Pet Journal
  companion). They remain deliberately separate; there is no ambiguous
  "any pet" condition.
- Reflowed the live Cinematic strip into its own header row, so scene toggle,
  black bars, and shortcut controls no longer overlap the editor header or
  Presence panel. Entering Cinematic from the editor keeps it visibly open and
  starts the target rail on **Managed** frames.
- Cinematic editing now remaps the normal teal live-state cue to Cinematic
  orange across the editor. Unavailable and confirm-before-changing states use
  red addon-wide, keeping orange exclusive to Cinematic.
- Enabled reactions now remain fully legible and editable when they are not
  the currently matching row. Only a deliberately disabled **Off** reaction
  is greyed out. The header Cinematic control also becomes **Exit scene**
  while active, providing a second reliable way to return to the prior profile
  without closing the editor.
- The guided-tutorial card now stays above the live editor after each required
  click. On wide screens it docks in the free left column, leaving the real
  highlighted target or control unobstructed.
- Tutorial highlighting now always uses a small real control or rule row. It
  no longer falls back to an oversized editor-panel rectangle after a required
  click changes the editor contents. Reaction On/Off is now beside its drag
  handle, clearly separating row state from the condition's value controls.
- During the guided Mouseover lesson, the palette opens directly on Presence
  and highlights **Mouseover**; after selection, the focus moves to its real
  opacity control for the 100% choice.
- The tutorial now seeds **Otherwise** at 100% beside its 30% Stationary rule,
  so moving immediately demonstrates a visible first-match fallback change.
- Rebuilt the guided tutorial around a visible, session-only **Tutorial
  Frame** with the player's portrait. It is pinned to the real target rail and
  teaches actual selection, management, reaction creation, first-match
  priority, row movement, and Otherwise editing under a focused dim overlay;
  the target and its rules are removed automatically on every exit.
- Removed the dedicated Cinematic page. The orange Cinematic control now
  enters the live Cinematic profile directly in the main editor; its inline
  strip keeps the Cinematic On/Off toggle, black bars, and shortcut together.
- Removed the developer-facing `Run audit` action from Help. The read-only
  diagnostic remains available by `/pfader audit` when troubleshooting calls
  for it.
- Simplified the Cinematic page into scene-wide controls only. Frame
  visibility now has one source of truth: **Edit Cinematic profile** and the
  familiar ordered-rule editor; the duplicate quick-mode rows are gone.
- Removed the redundant Cinematic `Keep a frame` shortcut and its opaque
  exception count. Existing saved keeps are cleared once; use **Edit Cinematic
  profile** to add any custom frame through the normal, visible rules.
- Cinematic's dedicated toggle now leaves the Frame Gambit editor open for
  live scene setup, while slash/keybinding activation continues closing it with
  other game panels.
- Minimap `Hide at 0%` and `Scale with map` now also fade Super Tracking's
  alpha-escaping quest-direction arc when it is clamped to the screen edge.
- Fixed Cinematic's temporary panel exception for `HIGH`-strata windows, so
  EllesmereUI Bags and themed Character panels can appear above the scene when
  opened without disabling Cinematic Mode.
- Rebuilt Frame Gambit's Help & tutorial around the shared Resonance-style
  standalone window: a toggleable `? Help` control, centered draggable layout,
  topic rail, Escape close behavior, and retained tutorial/audit actions.
- Cinematic now closes Blizzard game panels as it starts, preventing invisible
  windows from retaining mouse input. Panels opened afterward, including
  supported top-level addon windows, remain visible above the scene until
  closed without leaving Cinematic Mode.
- Cinematic black bars now allow 0% through 25% (default 4%). At 0%, no
  letterbox is drawn. EllesmereUI Data Bars and XIV Databar remain visible
  above the bars without Frame Gambit changing either addon's frames, while
  world-space names and nameplates remain behind the letterbox.
- Minimap `Hide at 0%` and `Scale with map` now include Blizzard's separate
  quest, archaeology, and task-area rings, which do not follow icon scale.
- Fixed a regression that made experimental native Minimap marker modes
  unavailable on Retail clients exposing `SetIconScale` without a matching
  getter. Selecting a mode is now the explicit opt-in to its documented
  restoration fallback; the default remains untouched.
- Cinematic Mode now defaults its Minimap to `Hide at 0%`, so Blizzard's
  engine-drawn service and quest markers disappear with a fully faded map.
  Existing Cinematic profiles using the old unchanged default are upgraded;
  an intentional `Scale with map` choice is preserved.
- Reduced normal-profile evaluator work: Frame Gambit now queries only states
  referenced by enabled gambits and relies on its guarded alpha post-hooks,
  with a low-rate safety audit, instead of polling every managed frame's alpha
  and every supported game state at 20 Hz.
- Added a compact Help Center with focused guides for Gambits, relationships,
  Cinematic Mode, safety, and troubleshooting.
- Added a reusable, non-destructive guided tutorial for the complete
  Manage → React → Order → Otherwise → Preview flow, followed by a clear handoff
  to the real on-screen picker.
- Added an interactive priority board that demonstrates why the first
  matching line wins without changing a real profile.
- Added safe tutorial persistence, combat pause/resume, contextual highlights,
  and a Help notification until the tour is completed.
- Added optional mouse-transparent Cinematic letterbox bars. Their shared
  height is adjustable from 0% to 25% of the screen and adapts to resolution
  or UI-scale changes without modifying any Blizzard or addon frame.
- Added an experimental Minimap native-marker control with `Leave unchanged`,
  `Hide at 0%`, and `Scale with map` modes. It uses the Minimap compositor's
  icon-scale surface and never edits Blizzard tracking categories. Frame
  Gambit now recomposes later Blizzard scale requests and periodically
  reasserts the result after native marker-layer rebuilds.
- Native minimap marker composition now captures and restores the host's real
  icon scale instead of assuming 100%, accepts host scales above 1, and keeps
  failed restorations pending until they can complete safely.
- On clients where native marker scale is write-only, `Leave unchanged` remains
  completely non-invasive. Explicitly selecting an experimental marker mode
  uses a clearly disclosed 100% restoration baseline until Blizzard or the
  owning UI announces its real scale, preserving functional marker fading.
- Minimap native-marker mode now survives profile export/import through a
  backward-compatible optional record; older profile strings still import.
- The existing Chat target now becomes a complete Ellesmere Chat visibility
  proxy when that module is installed, covering its UIParent-level messages,
  panel, tabs, sidebar and chrome while returning native ownership to EUI when
  the target is released. Blizzard Chat remains the automatic fallback.
- Ellesmere Chat now explicitly uses host-owned physical timing: Frame Gambit
  controls ordered rules and fade-out wait, while Ellesmere performs its own
  supported animation without a competing or misleading duration control.
- Empty non-Cinematic profiles now detach Frame Gambit's shared 20 Hz evaluator
  until an event or editor mutation creates work again.
- Actionable editor warnings now use a persistent, dismissible amber notice
  with reserved layout space instead of being overwritten by the live-state
  label or briefly painting over rule text.

- Began the safe user-facing rename from Priority Fader to **Frame Gambit**.
  The editor, addon metadata, keybinding category, diagnostics, and help copy
  now use the new name and display the creator credit **by Mimezu**.
- Added `/framegambit` and `/fgambit` aliases. Existing `/pfader`, addon-folder,
  SavedVariables, profile export, frame names, and public API identifiers remain
  unchanged for compatibility.
- Fade transitions now finish in the exact configured time instead of using
  repeated easing that could take roughly five times longer. Brief reveals
  still complete before the configured wait and fade-out begin.
- Expanded fade-out wait time from 5 seconds to 15 seconds.
- Added a compact search field to Hover group, Linked children, and Visibility
  children pickers.
- Matched Resonance's raised custom close-button treatment so thick editor
  borders cannot paint over the control.
- Removed the duplicate header frame-picker action, moved the version and
  creator credit to the top-right, and added a Resonance-style resize grip.

## 2.5.0 - stable CDM viewers and complete minimap flyout fading

- Replaces the private experimental EUI CDM bridge with first-class Blizzard
  Cooldowns, Utility, and Buffs viewer targets. EUI continues to own every
  icon's styling, position, alerts, cooldown state, and bar membership.
- Custom EUI bars intentionally inherit the PF rule of their underlying viewer
  category, avoiding dependencies on EUI's daily-changing private internals.
- Migrates existing picker-created viewer rules to the canonical targets and
  removes obsolete experimental targets without leaving group or link ghosts.
- Treats Minimap as a semantic stack: pooled POI regions, Blizzard tracking
  and indicator branches, UIParent super-tracking, LibDBIcon buttons, and EUI's
  grouped flyout now follow the one Minimap rule without double-fading normal
  descendants.
- Adds built-in logical targets for Details windows. Each one fades the title,
  controls, background, and separately-parented meter rows together instead of
  exposing Details' implementation frames as misleading independent choices.
- Introduces optional semantic providers rather than requiring one personal UI
  stack. Details targets register only when Details exists; Ellesmere Damage
  Meter windows register when that module exists; Blizzard's native Damage
  Meter remains the no-addon fallback. Cinematic quest conversations resolve
  through DialogueUI or Blizzard, and quick-action palettes through OPie or
  Ellesmere Quickdraw.
- Lets discovered and on-screen-picked frames be removed from the catalog with
  a two-step confirmation, cleaning their rules and relationships in every
  profile while keeping built-in adapters intact.
- Makes the Cinematic editing boundary four pixels thick for a clearer mode
  cue while ordinary controls retain the calmer Resonance palette.
- Replaces Cinematic's 20 Hz full blackout sweep with immediate frame hooks,
  reveal-state updates, and a low-rate safety audit. Root discovery is slower
  and load-on-demand addon scans are debounced, removing the largest sustained
  FPS cost when hundreds of UI branches are blacked out.
- Adds visibility inheritance, an optional managed-frame tree, drag-to-link,
  and per-target Copy/Paste so related frames can share behavior without
  duplicating every ordered rule manually.
- Commits brief reveal conditions to their full requested opacity before the
  configured wait and fade-out. Short movement, casts, mouseovers, and target
  changes can no longer leave a frame stranded halfway through its transition.
- Replaces Blizzard's bulky arrow scrollbars throughout the editor with the
  slim Resonance rail and draggable thumb. Every rail is inset into its card's
  reserved gutter, so it no longer overlaps or crops across panel borders.
- Makes Linked child genuinely directional. Hovering the source always reveals
  the child, while hovering the child reveals itself only when that child has
  its own Mouseover row. Existing links keep their existing rows and behavior.

## 2.4.2 - quieter Cinematic identity and quick components

- Limits the warm Cinematic accent to scene controls, the live editing cue,
  and the outer editor border; ordinary controls remain Resonance lavender.
- Fixes Cinematic quick-mode buttons retaining a teal filled hover state.
- Adds Cast Bar (Casting only) and Resource Bars (Combat only) to the default
  Cinematic scene controls and profile template.

## 2.4.1 - managed target filter

- Adds a compact Managed only toggle to the target rail. It shows only frames
  controlled by the current profile without changing any frame or rule.

## 2.4.0 - Cinematic editing clarity and casting state

- Replaces the ambiguous duplicate Rules actions with a single header-level
  Back to editor action and a clearly named Fine-tune profile action.
- Fine-tuning always opens the Cinematic system profile; if the scene is off,
  Priority Fader turns it on first rather than editing the active normal
  profile by accident.
- Introduces a warm Cinematic identity for its dedicated controls and live
  profile editor. Version 2.4.2 narrows that treatment after visual testing.
- Adds `Is casting` as a normal state condition for player casts, channels,
  and empowered casts, including combat-safe event tracking.

## 2.3.0 - experimental EUI CDM icon bars

- Adds one normal Priority Fader target for every live Ellesmere CDM bar,
  including user-created custom bars.
- Uses the EUI bar shell for hover geometry while fading its assigned
  Blizzard icon frames, since those icons are not children of the shell.
- Composes PF opacity with EUI's latest per-icon opacity so hidden,
  cooldown-lowered, alert, placeholder, styling, and layout behavior remain
  owned by EUI.
- Restores the latest EUI-requested opacity whenever PF releases a CDM bar.
- Picker selections on an EUI CDM shell now resolve to its dedicated icon-bar
  target instead of a misleading container-only target.
- Makes no changes to EllesmereUI files or SavedVariables.
- Extends the existing Minimap target to fade descendants that explicitly
  ignore parent alpha and EUI's separate grouped-button panel, while preserving
  each element's own host opacity and click behavior.
- Makes the Ellesmere Player Frame adapter control EUI's real player
  visibility wrapper while retaining the unit frame itself for hover and
  preview geometry. This fixes Player remaining invisible in Cinematic Mode
  even though the equivalent Target rule was active.

## 2.2.6 - reliable visual selector

- Replaced the selector's failing global frame enumeration with the same
  UIParent hierarchy used successfully by visible-UI discovery. Visible roots
  and descendants are mapped incrementally, then indexed for cursor and wheel
  selection.
- Increased overview guides to clear two-pixel lavender wireframes and stacked
  candidates to teal, while keeping every overlay mouse-transparent.
- Mapping totals now remain visible after scanning and distinguish an empty map
  from simply pointing at world space outside a UI frame.
- Cinematic Mode now explicitly exempts Blizzard's nameplate driver and
  Ellesmere's anonymous pooled enemy/friendly nameplate roots, including while
  those pools are hidden and waiting to be reused.
- Untouched Cinematic player/target defaults now reveal for combat, any target,
  or hover. Existing customized rules remain unchanged.

## 2.2.5 - full-canvas editor peek

- Added a compact Peek control to the Rules header. It collapses the full
  editor into a small top-center return bar so the entire game canvas can be
  inspected without moving or resizing the options window.
- The selected target's live teal outline remains visible during Peek, making
  centrally positioned frames easy to identify before returning to the exact
  editor state.

## 2.2.4 - horizontal slider input

- Explicitly set opacity, reaction-duration, transition-time, and fade-delay
  sliders to horizontal orientation. Their input direction now matches the
  visible track and thumb movement.

## 2.2.3 - frame map recovery and edit-in-context

- Fixed the visual frame atlas publishing an empty map after its deferred
  finalization failed silently. Mapping now uses an explicit visible-parent
  walk and completes directly, while the expensive frame enumeration remains
  time-sliced.
- The picker now reports both checked and eligible frame counts while mapping,
  and gives a useful diagnostic instead of a misleading empty hover state if
  no readable frames can be published.
- Selecting a target in the Rules editor now draws a persistent,
  mouse-transparent teal boundary around the live frame. The existing preview
  control is now an on-by-default outline toggle; the marker follows moving
  frames and disappears with the editor or on the Cinematic page.
- Hover-group and linked-child choices now live in a bounded two-column
  scroll area with mouse-wheel support, so discovered frames cannot overflow
  the modal or cover its actions.

## 2.2.2 - visual frame atlas and cinematic hardening

- Rebuilt Pick on Screen around a one-time, time-sliced UI atlas. The picker no
  longer walks thousands of live frames every tenth of a second, and cursor
  selection uses a small cached spatial index after mapping completes. The
  full frame list and atlas finalization are completed incrementally without a
  silent frame-count cutoff.
- Added pooled, mouse-transparent wireframes for the main visible UI regions.
  Moving over a box reveals its local frame stack; the mouse wheel now chooses
  the exact inner frame or whole-window scope shown by the teal outline.
- Added descendant-union geometry for zero-sized addon anchors, stable named
  child-frame persistence, and a bounded session-only fallback for anonymous
  frames. Auto-discovery remains a single read-only pass.
- Cinematic Mode now uses WoW's native UI-role suppression where available,
  without touching UIParent or suppressing unit frames and the Minimap. Addon
  roots remain controlled by Priority Fader's reversible alpha ledger.
- Added guarded OnShow/SetAlpha post-hooks for blacked-out roots so chat, cast
  bars, and other self-repainting addon frames cannot flash between evaluator
  ticks. Host alpha remains the value restored when Cinematic Mode ends.
- Normal managed targets now use the same guarded ownership principle: a host
  repaint updates the restoration alpha while PF immediately reapplies its
  current rule opacity. Hidden transient frames are prepared before Show.
- Cinematic defaults are now truly hidden at rest: player and target appear
  with any target (or hover), while the Minimap appears on hover. Existing
  untouched 2.2 defaults migrate; customized Advanced rules are preserved.
- Replaced broad fullscreen/OPie guesses with exact read-only preservation for
  OPie's shared proxy and anonymous ring renderer, Dialogue UI's quest frame,
  Blizzard loot/dialog frames, and SpeedyAutoLoot's compact loot display.
- Ellesmere's shared secure unit-frame hider is handled as a structural
  pass-through: player/target remain rule-owned while focus, pet, ToT, and boss
  siblings join the blackout. Minimap hover includes its visible EUI controls.

## 2.2.1 - Explorer recovery

- Fixed the live picker and visible-UI discovery stopping at the first modern
  Blizzard frame whose geometry is protected by secret values. Those frames
  are now skipped safely, allowing the scan to continue to ordinary addon and
  EUI roots.

## 2.2.0 - Cinematic blackout scene

- Cinematic Mode now snapshots visible, eligible top-level UI roots and fades
  them to a true blackout, including normal addon windows such as Details.
- Player frame, target frame, and Minimap keep their simple Cinematic rules;
  action bars, chat, objectives, and other UI are now blacked out by default.
- Added `Rescan` for newly opened UI and `Keep a frame`: hold Alt to reveal the
  scene, pick a root, and make it a persistent exception when it has a name.
- Nameplates, OPie, loot, warnings, dialogs, and system UI remain protected
  exceptions. The blackout only changes alpha; it never edits another addon's
  settings, layout, styling, click handling, or code.

## 2.1.0 - Live frame explorer

- Replaced the adapter-only frame picker with a live UI-frame explorer. Hover
  any visible UI, use the wheel to step through overlapping roots, then select
  the root Priority Fader should manage.
- Named roots are saved and restored on reload; anonymous roots are clearly
  marked session-only rather than becoming broken saved targets.

## 2.0.2 - Picker and Cinematic repairs

- Fixed the frame picker’s rectangle handling, which could repeatedly error on
  a valid frame and prevent selection.
- Fixed the Cinematic page reference, so opening, closing, and its controls
  now address the actual page instead of a missing panel field.

## 2.0.1 - CDM integration rollback

- Removed the experimental Ellesmere Cooldown Manager bridge and all CDM
  targets. Priority Fader no longer changes, depends on, or hooks EUI source.
- Saved CDM targets and their relationships are removed safely during the
  update, leaving EUI's own CDM styling, options, and click behavior alone.
- CDM will remain unsupported until there is a stable, official integration
  surface that works without modifying EUI.

## 2.0.0 - Cinematic Mode

- Added a dedicated Cinematic Mode page: a quiet, reversible questing view
  backed by its own managed profile and a remembered return profile.
- Added simple scene controls for player/target frames, main action bar,
  minimap, objectives, and chat. Advanced changes remain available through
  the normal ordered-rule editor while the cinematic scene is active.
- Enemy nameplates, OPie, and loot windows remain intentionally untouched and
  owned by their existing UI systems.
- Added an unbound native `Toggle Cinematic Mode` keybinding, `/pfader
  cinematic`, and a combat-safe in-addon shortcut capture with replacement
  confirmation and rollback if WoW cannot save a new binding.
- Resetting the scene is explicitly confirmed, expires after a short delay,
  and never strands a previously faded target.

## 1.9.0 - Ellesmere Cooldown Manager bridge

- Added a composition-safe bridge for every normal live Ellesmere Cooldown
  Manager bar, including user-created bars. The target catalog discovers live
  bar keys through EUI's module API; it never reads EUI's saved settings.
- Priority Fader now contributes an external opacity multiplier inside EUI's
  own icon-opacity pipeline. EUI keeps ownership of visibility, placeholders,
  cooldown-state effects, vehicle handling, and combat-safe icon behavior.
- CDM targets require the EUI bar to use **Always visible**. If EUI hides a
  bar for one of its own rules, Priority Fader respects that decision.

## 1.8.0 - repeatable validation

- Added `/pfader audit` (also `/priorityfader status`): a bounded, read-only
  chat report of adapter availability and active-profile graph health.
- The audit distinguishes expected unavailable frames from configuration faults
  and checks group/link structure, link loops, and connected-hover fallbacks.
- Added a focused [Retail validation script](TESTING.md) covering picker UX,
  direct priority ordering, relationships, profiles, combat, and coexistence.

## 1.7.0 - direct priority ordering

- Added direct drag reordering for reaction rows. A teal insertion line shows
  where the row will land; priority changes only when the drag is released.
- The drag operation uses one temporary, mouse-transparent overlay, respects
  scrolled lists and UI scale, and safely cancels when the editor closes.
- Retained the arrow controls as a compact precise alternative.

## 1.6.0 - adapter diagnostics

- The target rail now keeps every registered adapter visible. Amber entries
  explain why a frame is not currently available instead of silently vanishing.
- Selecting an unavailable target preserves its rules and shows a plain-language
  recovery message; available, host-hidden, and unavailable states are now
  distinct throughout the runtime and editor.
- Reworked shared tooltips so they retain the Resonance-style hover feedback
  without replacing button scripts or accumulating handlers.

## 1.5.0 - faster target setup

- Added a compact literal filter to the target rail. Search by frame name,
  source, or stable adapter ID without disturbing the current rule editor.
- Added a two-second, read-only frame preview. It outlines the selected frame
  plus its direct hover-group and link relationships, using no opacity or
  protected-frame changes.
- Kept the target rail independently pooled, so filtering remains lightweight
  even while the selected target has a large rule stack.

## 1.4.0 - portable profiles

- Added compact validated export/import for individual profiles. Imports have a
  versioned envelope, integrity check, size limits, and always create a new
  profile rather than replacing one.
- Added bounded, scrollable transfer and reaction editors, with clear
  validation feedback and no unbounded pasted-data or row allocation path.
- Hardened profile graphs: groups are disjoint, links are loop-free and capped,
  and every connected frame keeps its required unconditional Mouseover rule
  without exceeding the per-target reaction limit.

## 1.3.0 - named profiles

- Added compact named profiles: create a safe copy of the active setup, switch
  directly, and delete only after a clear confirmation. Default is preserved
  as the recovery profile.
- Profile switches restore the previous profile's alpha before a new profile
  claims the frame, including guarded handoff for provider frames that fail a
  restore temporarily.

## 1.2.0 - expanded Ellesmere unit frames

- Added explicit Ellesmere adapters for pet, target-of-target, focus target,
  and boss frames, all verified against the installed Ellesmere version.
- Made the target rail scrollable as the supported catalog grows.
- Retired the former invisible Resource Bars anchor and cleaned its old saved
  relationships. Individual resource bars remain deferred until Ellesmere can
  offer a safe host-visibility integration point.

## Legacy Priority Fader 1.1.0 - capability guidance

- Added clear, color-coded capability status in both picker stages, so a frame's
  limitations are visible before it is selected.
- Added bounded explanatory guidance in the target editor and a documented
  adapter API for external UI authors to describe their own limits.

## 1.0.0 - frame timing

- Replaced the old cycling fade button with a compact timing panel for each
  target: transition time (0.05–2.00s) and fade-out delay (0–5.00s).
- Timing edits apply live, including while a frame is already waiting to fade;
  the summary now states both values plainly.

## 0.9.0 - timed reactions

- Moment reactions now show their duration directly in the priority stack and
  open the same compact preset-and-slider control used for opacity.
- Added exact quarter-second durations from 0.5 to 30 seconds, plus a live
  countdown in the active-state chip while a timed reaction is winning.

## 0.8.0 - advanced reactions

- Added optional all-of requirements to every reaction row: configure compact
  combinations such as **In combat + Has hostile target** with one opacity.
- Preserved first-match priority, including requirements and timed moments, so
  complex rows stay clear and predictable.
- Made hover groups and links self-protecting: connected frames always retain
  an unconditional Mouseover reaction, including when an older profile loads.

## 0.7.0 - provider integration

- Added a deliberately narrow, versioned `PriorityFaderAPI.RegisterTarget()`
  adapter API for other UI authors.
- Added [integration guidance](INTEGRATION.md) and strict frame contract
  validation; providers cannot alter profiles or opacity rules.
- Tracked the actual frame instance controlled by each target, restoring it
  safely when a resolver changes, fails, or is removed.

## 0.6.0 - broader safe reactions

- Added out-of-combat, stationary/falling, Shift/Control/Alt, flight-path,
  open-world/scenario, War Mode, and more precise quest/loot reactions.
- Split quest moments into accepted, turned in, and objective-updated variants.
- "Looted an item" now reacts only to a guarded local-player loot event; party
  and raid loot messages cannot activate it.

## 0.5.0 - intentional frame selection

- Picker now follows a safe Pick -> Confirm -> Use flow. First click freezes
  the spotlight; only **Use this frame** changes the profile.
- Added Choose again, reliable Escape restoration, and no unexpected editor
  opening when `/pfader pick` is used from a closed window.
- Picker cancels cleanly for combat, pet battles, and world transitions, and
  validates a selected frame's geometry before applying it.

## 0.4.0 - opacity controls

- Replaced opacity click-cycling with a compact modal control: six useful
  presets plus a precise live slider.
- Added modal input capture and Escape/Done dismissal for the opacity control.

## 0.3.0 - relationship editor

- Replaced the remaining vanilla group/link menus with a compact multi-select
  connection editor in the Resonance visual language.
- Added direct add/remove editing for hover groups and linked children, with
  Done/close/Escape controls and clear source labels.
- Linked parent hover now propagates through its descendant branch; cycles are
  rejected before they can be saved.

## 0.2.0 — rule palette and safe state snapshot

- Added a categorized, compact reaction palette: Presence, Target, Travel,
  Group & instance, World, and Moments.
- Added safe, fail-closed target, travel, group, instance, world, and
  event-moment conditions.
- Sampled game state once per evaluation pass; all targets now share that
  snapshot while mouseover remains target-specific.
- Added database v2 migration and stable numeric reaction/group IDs.
- Added active-rule highlighting, a locked **Otherwise** fallback label, and
  basic relationship status/removal controls.
- Linked parents now reveal their full descendant branch; hovering a child
  continues to reveal that child alone.
- Preserved combat safety: the addon remains alpha-only and picker cancellation
  no longer reopens settings when combat begins.

## 0.1.0 — first playable build

- Initial adapters, ordered opacity reactions, spotlight picker, grouping, and
  parent-to-child hover links.
