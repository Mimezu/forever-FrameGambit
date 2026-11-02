# Frame Gambit

Use **Chat > Add a reaction > CHAT** for chat conditions. **Typing** matches while the chat input has keyboard focus, including an empty box after Enter; choose the opacity on its rule. **Chat contains text** accepts a name, item, dungeon, or phrase and matches new messages in any configured chat window without case sensitivity. Set its duration and opacity, or add multiple rules for different phrases. Item links match their displayed names. Chat message activity conditions are also in CHAT.

With Gamepad Companion 0.1.3, controller bar opacity follows Blizzard's bar-selection notification immediately. On a native bar switch, the four configured controller bars reevaluate their normal rule priorities and apply the result without fade duration, hide delay or waiting for the shared evaluator. Other updates retain normal timing. Use **RT held**, **LT held**, **Both held**, or **Bar active** to choose the opacity.

Profiles load through native SavedVariables. The former `/fgstorage` and `/fgrecover` storage tools and their local profile snapshot were retired in 1.1.17; they are preserved in `StorageInvestigation/framegambit-retired-storage-tools-20260925`.

Forever's native shoulder indicators are available as **Gamepad - Left shoulder** and **Gamepad - Right shoulder** in the target picker. Each controls the background, button icon and pressed highlight together. Search for **shoulder** to find them. They work independently of Gamepad Companion, including while its integration is suspended. Their physical targeting/input behavior remains native.

The controller help panel is **Gamepad - Control hints**. It includes the current hints for interface focus, previous/next frame, tooltips and other native contexts. Frame Gambit fades the whole panel and uses its visible content for preview/hover bounds; it does not change navigation or which hints Blizzard shows.

In **Profiles**, enable **Automatic input-mode profiles** and choose a profile for **Gamepad** and **Keyboard/mouse**. Switching Blizzard's UI mode then selects the matching Frame Gambit profile. Leaving a mode unassigned keeps the current profile. Manual profile choices last until the next actual UI-mode transition or reload; Cinematic is not automatically selected or interrupted. This uses UI mode, not the last device touched, and works without Gamepad Companion.

**Show each part of your UI only when you need it.**

Frame Gambit allows you to create intricate alpha-only visibility rules for all
your frames.

Forever beta build: open with `/fg`. See [port validation](PORT-VALIDATION.md) for compatibility and first-run checks.

**Chat is one group.** Its gambits control every Blizzard chat window, including future whisper tabs, the dock, edit boxes, minimized windows and attached controls. Existing Chat rules apply automatically. The group follows native docking without moving or reparenting frames, and applies its opacity once per alpha-inheritance branch while preserving native styling. Ellesmere Chat continues to use its own whole-chat authority when installed. Use the built-in **Chat** target rather than adding separate targets for its individual parts.

To briefly reveal your XP bar, add **Events → XP gained** to its frame, set the opacity, and adjust the duration (5 seconds by default). Further XP gains restart the duration; level-ups also count. Cinematic mode reveals frames on Alt only when you add an **Alt held** gambit for them.

To reveal chat only for selected message types, set Chat's **Otherwise** opacity to 0% and add the desired **Events** reactions at 100%: **New private message**, **New guild message**, **New group or raid message**, or **New General chat message**. Each defaults to 10 seconds and has its own duration; another matching message restarts that timer. Private covers incoming character/Battle.net whispers, guild includes officer chat, and group/raid includes instance chat and raid warnings. General means the zone's General channel, excluding Trade, Say and Yell. These conditions filter by message type, independently of chat-tab or other addons' message filters. Earlier matching gambits still take priority.



## Highlights

- Pick a frame on screen or choose one from the built-in catalog.
- Add and reorder gambits for combat, mouseover, targets, travel, groups, events,
  character state, and more.
- Set opacity, separate fade-in and fade-out times, and wait-before-fade-out per frame.
- Connect related frames with hover groups and parent/child relationships.
- See the currently winning gambit highlighted live.
- Preview your UI in-world and hover frame names to move the screen outline.
- Switch the complete editor appearance live between Ellesmere, Mimezu, and
  Luminous.
- Create profiles and share them.
- Build a separate Cinematic profile for immersive questing and minimal UI.

## How gambits work

Choose a frame and add the conditions that should control it. Frame Gambit
checks them from top to bottom; the first matching row sets the frame's target
opacity.

**Otherwise** applies when no row matches.

Drag rows to change priority. Add requirements when one row should need several
conditions at once. The teal row is the rule currently controlling the frame.

Conditions are organized into **System**, **Player**, **Any party member**,
**Target**, **Travel**, **Pets**, **Group & instances**, **Events**, and **CHAT**.

![Adding a character condition](.github/readme/reaction-picker-character.png)

## Cinematic mode

Cinematic mode provides a separate profile for immersive questing and minimal
UI, with optional black bars, a scene FOV, a form-aware left camera, and chat
that returns while you type. The mode and camera composition each have their
own shortcut.

![Editing the Cinematic profile](.github/readme/cinematic-editor.png)

## Installation

1. Download the latest `FrameGambit.zip`.
2. Extract it into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Start WoW or use `/reload`.
4. Open the editor with `/fg` or `/framegambit`.

The ZIP already contains the required `FrameGambit` folder.

## Safety and compatibility

Frame Gambit changes opacity. It does not restyle, reparent, show, hide, or
change secure attributes on frames owned by WoW or another addon. It resizes
or moves a frame only when one of that frame's rules, or Otherwise, sets a size
or position (experimental, see below). Host changes are preserved and restored
when Frame Gambit releases a frame.

## Size and position (experimental)

Each rule card has a small size-and-position toggle beside its opacity
number. With the toggle off the card works exactly as before. Turn it on and
the card shows these beside the toggle (on a second line only if the card is too narrow):

- **Size**: a size for this rule (75%-150% presets, 50%-200% on the slider),
  or **Same size** to leave it to later rules.
- **Move** (position): arrows move the frame from its normal place by 1, 10 or 50 UI
  units; **Same position** leaves it to later rules.
- **Keep opacity** (in the rule's opacity window): the rule changes only size or position; its opacity button then reads Keep.

Opacity, size and position are decided separately: each comes from the first
matching rule that sets it, otherwise from the Otherwise row, which has the
same toggle for the default size and position. For example, Party Frames with
*In combat 100% + Size x1.2*, *In party 70%* and *In dungeon instance: Keep
opacity, Size x1.1, 40 up* are 70% opacity and x1.1 size, raised by 40, in a dungeon
out of combat. The Size and Position buttons of the rule currently in charge
are highlighted like the winning card.

Size scales around the frame's centre, or around a corner or edge you choose with **Grow from** in the Size picker (one choice per frame); position is measured from where Edit
Mode or its addon puts the frame, so moving it there moves the rule layout too.
Changes use the frame's fade times, or happen at once when the rule's **Instant** button is on. Mouseover rules can resize but never move a
frame. Protected frames change only outside combat; an In combat size is
applied as combat starts. Edit Mode always shows the normal layout. Chat, the
gamepad bars, other composite frames, frames labelled Opacity only and frames
held by two anchors can only fade.

It targets Retail WoW and supports Blizzard UI, discovered frames, and explicit
integrations for several popular addons. Unavailable frames remain safely
listed and are skipped until their owner creates them.

Frame Gambit uses the standard Panel layout. Older saved Binder selections automatically migrate to Panel.

The editor ships with eighteen visual skins, matching BindCards' appearance
grid and including its console-inspired palettes. **Ellesmere** is the exact
default treatment, **Mimezu** restores the blue-charcoal suite palette, and
**Luminous** uses a lighter graphite-slate surface. Choose one from Appearance
in the editor header; it applies immediately, is saved, and does not require
EllesmereUI. EllesmereUI cannot recolor Frame Gambit's selected appearance.
Cinematic accents stay orange in every skin and for every class.

**Blizzard Legacy** uses Forever's Legacy Challenges artwork: the client's
portrait-frame nine-slice border, leather background, inset borders, native
close button, search-field art and MinimalScrollBar. Use the Panel layout
for the complete framed window. Corners retain their native size; edge runs
tile, while background textures fill the available space. The skin can be
switched live without changing profiles or visibility rules.

## Help and profiles

Open **Help** in the editor for concise guides and a non-destructive tutorial.
Profiles can be exported and imported for sharing; unsupported frames on the
receiving UI are skipped safely.

For addon integrations, see [INTEGRATION.md](INTEGRATION.md). Release history is
in [CHANGELOG.md](CHANGELOG.md).

## Forever gamepad bars

With Gamepad Companion installed, add **Gamepad - Base**, **Gamepad - LT**,
**Gamepad - RT**, or **Gamepad - LT + RT** to Frame Gambit. To show a bar only
when active, set its rest opacity to 0% and add **Gamepad > Bar active: Yes**
at 100%. Fade speed and delay use the normal Frame Gambit controls.

Gamepad cards are repeatable and ordered. **LT held**, **RT held**, and
**Both held** describe physical triggers; **Bar active** describes the selected
layer. **Gamepad mode** describes whether Blizzard's controller mode is enabled.
Unknown input matches neither Yes nor No. Trigger rules and bar targets are
unavailable during native menu navigation; Frame Gambit releases its opacity
and preserves the host's latest alpha. Layout and assignments stay in Blizzard's
editor and Gamepad Companion.

### Cinematic window protection

Suite editor windows (including BindCards, Wardrobe Time Capsule and Resonance)
and their dialogs remain visible in Cinematic, even when opened afterward.
Cinematic temporarily releases any explicit Frame Gambit fade on these windows;
normal-profile rules resume afterward. Other addons can register a dialog root
with `FrameGambitAPI.RegisterCinematicWindow(frame)`. HUD widgets remain subject
to their own visibility rules.

## Health, party, loot and location conditions

Player and Any party member offer Health percentage and Mana percentage. Each
row has its own comparison (less than, at most, equal, not equal, at least,
more than) and threshold from 0 to 100. Decimal thresholds are supported;
equality compares the unrounded percentage. Mana means mana even while a
Druid uses another power type. Units with no mana never match a mana rule.

Party conditions cover the other four party members, excluding the player,
pets, disconnected members and raid groups. Any party member also offers
In combat. CHAT adds Party member loots an item and Loot roll winner announced,
with configurable reveal durations. Select the chat frame receiving loot
messages to read the winner; Frame Gambit does not enable hidden chat channels.

Group & instances adds In a major city using recognized city map IDs and
interior parent maps. Outdoor inns and city dungeons do not count. Player
adds In combat with an elite, which requires readable player threat on an
elite, rare elite or boss found through target, focus, party targets, boss
units or nameplates. Enemies without an observable unit token cannot be
detected. Protected health/mana percentages use client display curves when
available, preserving rule priority without reading the protected numbers.
This opacity applies immediately (no fade timing), and the editor reports
game-controlled opacity rather than naming a matching rule. Protected
comparisons use native curve precision, with a 0.00001 percentage-point step
for inclusive and equality boundaries. Unavailable APIs or unreadable threat
never activate conditions.

Percentage cards are repeatable primary conditions; their AND requirements
can use ordinary states, but percentage comparisons cannot themselves be
selected as AND requirements. All parameters survive profile export/import.

### Party member selection

Click a party health or mana rule to choose **Any** or **1–5**. Any keeps the existing check across other party members. Numbers follow the corresponding `CompactPartyFrameMember1–5` unit assignment, including your character when shown there. A reordered layout changes which unit a numbered rule follows. Missing, offline, or unavailable assignments do not match; these rules exclude raids.
