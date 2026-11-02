# Reload startup check

Run "lua tests/startup_options_smoke.lua ." with Lua 5.1 or LuaJIT. Reload in a city without opening the editor, then check /fg and first-use /fg pick, saved appearance, rules, Cinematic, and input-mode switching. First-use picker entry during combat must remain blocked. This regression does not measure live FPS.

# Testing

## Size and position (experimental)

Run `lua tests/FrameLayout.lua .` (also with LuaJIT). It covers independent
opacity / size / position priority, Keep opacity, centre scaling in scaled
parents, owner moves and rescales, Edit Mode, combat (no protected writes,
combat-start size, restore after combat), exact restoration, copy/paste and
export/import.

In game (untested so far):

1. Party Frames: add In dungeon instance, turn on its toggle, Keep opacity (in the opacity window),
   Size x1.1, 40 up. Enter a dungeon: the frames grow and rise; opacity still
   follows the other rules. Leave: they return after the wait.
2. Add In combat with Size x1.2. Pull a mob: the size changes as combat
   starts, stays during the fight and returns after it. No BugSack errors and
   `/fgblocked` stays empty.
3. Turn Instant on for one rule and leave another off: the first snaps, the second eases; returning to Otherwise follows the Otherwise row's own Instant.
4. Minimap: Mouseover with Size x1.5, Grow from the top-right corner in the Size picker. It must grow toward the screen's inside, stay pinned at that corner and not flicker while you hover its edge.
5. Open Edit Mode: every frame shows its normal size and place. Move a frame
   there and close Edit Mode: the rule layout follows the new place.
6. Turn every toggle off, reset the frame, switch profile and `/reload`:
   frames return exactly to their Edit Mode place and scale.
7. In the gamepad UI, repeat 2 and open/close the map a few times; A, B and the
   gamepad cursor must keep working and `/fwm taint` must stay clean.

## Gamepad-safe Cinematic Mode

Run `lua tests/GamepadSafeCinematic.lua .` (also with LuaJIT). It fails if
entering Cinematic Mode or the Cinematic camera calls Blizzard's window or
popup code (`CloseAllWindows`, `HideUIPanel`, `StaticPopup_Hide`...).

In game, in the gamepad UI: open the world map or bags, enter Cinematic Mode,
leave it, then open and close the map with the gamepad several times. A must
still jump, B must still close windows, windows must show the gamepad cursor,
and `/fwm taint` must report the gamepad state clean. Open windows stay
visible when the scene starts.

## Nested frame picker

Run `lua tests/NestedPicker.lua .` (also with LuaJIT). In game, manage Party
Frames first, then pick CompactPartyFrameTitle and add a separate condition.
Repeat in reverse order and reload: both entries and their rules should remain.
Container opacity still affects its descendants through native inheritance.

## Protected health and mana

The regression mock must reject protected color components in `AddPoint` as well
as protected inputs to generic `Evaluate`. Test combined player health, Any party
health, and player mana with each rule matching alone and together. Earlier
matching rules must win even when their opacity is lower. The native status-bar
selector checks public clamp behavior once before using protected bounds; run
`/fg healthdebug` in game to report unsupported behavior. This native behavior
still requires live-client confirmation; the mock does not prove client support.

Run `lua tests/ProtectedPercentages.lua .` and repeat with LuaJIT. The mocked
client keeps protected values opaque outside the display API. In game, reload
and test player health <70% while crossing 70%, and ~=100% while taking damage
and healing to full. Check an earlier mouseover rule, a later party health rule,
selection highlights, reset, and profile switching. Protected results apply
immediately and show game-controlled opacity; the editor cannot identify the
matching protected rule. Confirm multiple protected rows compose on this build;
API rejection should show an unavailable-curve message instead of a false match.


## Cinematic spell alerts

Run the spell-alert standalone regression test. In game, trigger class procs before
and after entering Cinematic with no Spell Proc Overlay rule: alerts must retain
their native opacity and animations. Add an explicit rule to fade/hide that target,
then remove/disable it and confirm restoration. Repeat in combat, after reload,
and across pooled/new proc visuals. No host Show/Hide or layout changes are used.


## Parity and suite windows

Test suite windows already open on Cinematic entry and newly opened via slash
commands, including appearance popovers, help and transfer dialogs. They should stay
at native opacity even with a saved zero-opacity rule. Suite HUD widgets should
still follow their rules. Exit Cinematic and verify normal profile behavior.

## New condition validation

Run `lua tests/percentage_conditions.lua .`, `lua tests/ExtraConditions.lua .`
and `lua tests/startup_options_smoke.lua .` (also with LuaJIT).

In game, add repeated health/mana cards with different comparisons and
thresholds. Save, export/import and reload; verify the selected values persist.
Try a mana class with zero mana, a non-mana class and a shapeshifted Druid.
Check another party member, a disconnected member, solo and raid states.
Verify the editor picker saves and cancels cleanly and closes with the editor.

Check party loot and your own/another player's roll wins, with verbose loot
roll chat both on and off. Roll choices, all-passed messages and strangers
looting must not trigger the corresponding conditions. Confirm configured
durations refresh on another event and expire afterward.

Check an outdoor city, a city interior, a city dungeon and an inn outside a
city. For elite combat, target an idle elite while fighting something else,
then engage the elite without tanking it. Repeat for a rare elite, boss,
normal enemy, a visible untargeted nameplate and combat end. Retail restricted
values must fail closed without errors. Existing host opacity restoration
and combat-lockdown behavior must remain intact when new conditions expire.

## Party member percentage selectors

Run `lua tests/PartyMemberPercentages.lua .` and `lua tests/ProtectedPercentages.lua .`, also with LuaJIT. In game, pick CompactPartyFrameMember1, add a party-health rule, and select 1. Repeat with mana and slots 2–5. Reorder the compact layout: each rule must follow its corresponding frame. Check Any, missing/offline members, raid exclusion, copy/paste, export/import, reload and cancel/reopen in the percentage picker.

## Protected party borders and titles

`tests/ProtectedPercentages.lua` rejects addon-side Curve:Evaluate(secret) and tests whole-party borders at native and partial baseline alpha, plus a protected-alpha title set to 0 while its parent reveals on mouseover. It covers native repaints and rejected/restored opaque baselines. In game, reload and select a party member while the whole Party Frames target is at 0; its selection border must disappear. Set CompactPartyFrameTitle Otherwise to 0, then hover the party container: the title must stay hidden. Repeat in combat and reset the title to verify native opacity returns.


## Cinematic exit without flashing

Run `lua tests/CinematicExit.lua .` with Lua and LuaJIT. Exit Cinematic with normal-profile resting opacity 0, long fade delays, and a currently matching rule on another frame. Before the next update, hidden frames must already be hidden and matching rules must already be applied. Repeat with minimap elements and blocked restoration. This adds one shared evaluation per exit, not an ongoing scan.

The border regression also includes 140 unrelated child frames before a known party member and an initially opaque border baseline. The known border must still be tracked without raising the generic scan limit. `/fg partyborder` reports visited frames, per-member tracking and contained scan/write errors.

Gamepad highlight: run `lua Interface/AddOns/FrameGambit/tests/GamepadHighlight.lua`.
In game, reload, select the quest tracker in FG, and add Gamepad > Frame highlighted:
Yes at 100% above lower-priority rules, with Otherwise at 0%. Focus the tracker,
navigate its quest controls, then switch to another window and return to player
control. Check reveal/fade behavior and repeat in combat. Independently selected
child controls should reveal only when selected; sibling controls should stay at
their configured opacity. Native gamepad navigation must continue working.
With Party Frames set to Frame highlighted: Yes at 100% and Otherwise at 0%,
enter gamepad party targeting and move between members: the whole party should
remain revealed. Exit targeting: normal rules/fades should resume. Repeat in
combat and confirm raid navigation does not reveal an unrelated party container.
