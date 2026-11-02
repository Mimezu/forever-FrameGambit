# Frame Gambit condition ideas

Design brainstorm — September 20, 2026. No conditions implemented.

## Baseline inspected

Core.lua, README.md and the condition registry already cover:

- Typing, literal case-insensitive chat phrase matches, incoming private,
  guild/officer, group/raid/instance and General messages, friend login/logout.
- Combat, movement, casting, falling, death/ghost, stealth/invisibility, forms,
  talent builds, target presence/friendliness/death and keyboard modifiers.
- Mounted, swimming, underwater, taxi and fishing states; active class pets.
- Party/raid/solo, instances and open world, dungeon/raid/battleground,
  resting, indoors/outdoors and a restricted PvP-flag state.
- Quest updates, acceptance, turn-in and objective progress, loot events and XP.
- Ordered first-match rules, multiple requirements, live winning-rule feedback,
  fade timing, hover groups and frame relationships. Gamepad integrations add
  trigger/bar conditions and input-mode profile selection.

Registry entries for flying, skyriding, vehicles, pet battles, cosmetic pets,
arena, scenarios, Delves and War Mode are explicitly unsupported in this
Forever build. Their presence in code does not establish compatibility.

Frame Gambit controls opacity. Revealing a frame means restoring its opacity
when its owner has it shown; it should not force a host-hidden frame to open.

## Design direction

BindCards changes available actions; Frame Gambit changes what needs attention.
Conditions that would make bindings unpredictable can still be excellent visual
signals. Distinguish persistent states, timed events and attention that remains
pending until explicitly acknowledged.

## Chat proposals

| Proposal | Example and benefit | Important behavior |
| --- | --- | --- |
| Reading history | Keep chat readable while scrolled away from its newest message. | End when returning to the bottom, optionally with a grace period. Mouseover alone is insufficient. |
| Mention of me | Reveal chat when someone uses the character name or a configured nickname. | Whole-word matching; configurable aliases, channels and self-message exclusion. Existing phrase matching is the starting point, not a wholly absent feature. |
| Selected channel activity | Say, Yell, emote, officer-only, raid-warning-only, selected custom channel. | Extend the current category filters; avoid conflating General with all public chat. |
| Selected sender | Reveal for a leveling partner, raid leader or chosen friends. | Explicit sender filters; never treat a phrase match as proof of sender identity. |
| Conversation active | Keep chat visible while exchanging whispers, including after sending a reply. | A configurable timer refreshed by incoming and outgoing messages; current private-message moments cover incoming only. |
| Important message pending | A whisper received during combat remains pending afterward. | Require a defined acknowledgement, such as clicking a marker or opening the relevant tab. Visibility is not proof of reading. |
| Deferred chat reveal | Suppress public chat in combat but reveal pending private/group messages afterward. | Queue only the attention signal; do not resend messages. Aggregate floods into one reveal. |
| Relevant loot/system message | Reveal chat for reputation, skill gains, a selected item or important errors. | Prefer structured events where possible; avoid broad fragile text parsing. |

Chat is currently one coordinated group. Revealing only a whisper tab while
leaving other tabs faded would be a separate targeting/ownership feature, not
just another condition. Do not promise it as a simple rule addition.

## Player, target and companion proposals

1. **Missing health / health below threshold.** Show the player frame after a
   fall or environmental damage even when not in combat. Add distinct reveal
   and recovery thresholds to prevent flicker. Check Forever data accessibility.
2. **Resource needs attention.** Mana below a chosen threshold; rage/energy
   above a chosen value; resource not at its normal resting value. Avoid assuming
   that every resource is best understood as low versus full.
3. **Recovery in progress.** Eating, drinking or recovering health/mana keeps
   relevant bars visible until recovery ends, then fades them.
4. **Recent damage / recent healing.** Timed player-frame reveal without
   remaining permanently visible because a tiny amount of health is missing.
5. **Harmful effect present.** Reveal player debuffs, optionally only dispellable
   types or explicitly selected effects. More specialized and API-dependent.
6. **Breath or fatigue active.** Underwater already exists; a warning specifically
   when a survival meter matters is more useful than always showing all bars.
7. **Pet missing health / pet dead.** Reveal pet controls or pet frame when care
   is needed. Existing class-pet-active only answers whether a pet is present.
8. **Target casting / target targeting me.** Reveal target information when it
   becomes relevant. Treat these as optional signals, with client verification.
9. **Target changed recently.** Briefly reveal a target frame on selection, then
   return to the player's preferred opacity. Separate from persistent has-target.
10. **Resurrected / returned from ghost.** Brief recovery/preparation reveal.
11. **AFK or inactive for a chosen duration.** Reduce nonessential UI while idle;
    never let this silently outrank configured urgent events.
12. **Manual attention mode.** A toggle or held key reveals a chosen set of
    frames. Existing modifiers already provide part of this; a named group
    preset would make it easier to configure.

## Event and interaction proposals

| Proposal | Useful reveal |
| --- | --- |
| Combat just ended | Damage meter, loot, quest progress and queued social messages for a short review period. |
| Level gained specifically | XP/status/talent-related UI with its own duration. XP gained already includes level-ups; this would let players distinguish them. |
| Reputation / profession skill gained | Briefly reveal the relevant status information. |
| Quest complete / ready to turn in | Reveal objective tracker longer than for an ordinary progress increment. |
| Tracked quest item obtained | Reveal objectives only for relevant loot, instead of every item. |
| Zone or subzone changed | Brief minimap/objective reveal for orientation, with a boundary debounce. |
| Arrived from taxi / loading screen | Short orientation reveal on arrival. Taxi itself already exists. |
| Bags nearly full / inventory full | Reveal bag controls only when inventory needs attention. |
| Durability low / equipment broken | Reveal repair-related information, especially at a merchant. |
| Merchant / bank / mail / trade interaction active | Keep bags or money readable while working with inventory. Prefer semantic interaction state to a fragile single frame name. |
| Quest dialogue / gossip active | Fade unrelated HUD during conversation, restoring it cleanly afterward. |
| Map open | Fade competing elements or keep relevant navigation information visible. |
| Ready check / summon / resurrection request | Protect an actionable prompt from an otherwise immersive profile. |
| Party member joined / left / disconnected / died | Brief group-frame reveal; aggregate repeated changes. |
| Encounter started / ended | Encounter-specific visibility and post-fight review where reliable Forever signals exist. Do not substitute ordinary combat without saying so. |
| Item or spell picked up on cursor | Reveal the destination action bars while rearranging actions. |
| Action failed | Briefly reveal error text or a relevant action bar after out-of-range, resource or target errors; debounce repeated errors. |

Cooldown-ready and selected-buff-expiring conditions are later possibilities.
They should be explicit choices, not an attempt to rebuild a complete combat
alert system or scan all abilities continually.

## Rule mechanics that would make conditions useful

- **Minimum visible time:** an event should be visible long enough to notice.
- **Remain while engaged:** do not fade a frame during scrolling, typing,
  dragging or an interaction with an attached menu. Typing/hover already cover
  part of this; extend intentionally rather than duplicate existing rules.
- **Separate entrance and exit thresholds:** e.g. reveal below 70% health,
  release above 85%, instead of blinking around one cutoff.
- **Deferred moments:** optionally begin the reveal duration after combat or
  dialogue finishes, rather than let the event expire while suppressed.
- **Aggregation and cooldown:** loot, chat and group-event floods should not
  create repeated distracting animations.
- **Configurable maximum activity window:** sustained public chat should not
  necessarily keep the whole chat group visible indefinitely.
- **Explicit urgent overrides:** editable priority presets for prompts and
  critical information. Existing first-match order remains understandable.
- **ANY / NOT groups:** build on existing AND requirements, conflict detection
  and ordered rules rather than present these foundations as missing.
- **Event-aware diagnosis:** show why a reveal happened, which suppression won,
  whether it was deferred and how much time remains. Existing live winning-rule
  feedback is already present.
- **Dry-run event preview:** test a sample whisper, damage or quest event in
  the editor without sending chat or altering gameplay state.

## Example recipes

### Quiet chat, without missed conversations

Typing or reading history: 100%. Incoming private message: 100% for 15 seconds.
During combat, suppress ordinary activity and defer important notifications.
After combat, expose any pending private/group activity. Otherwise: 0%.
Priority and acknowledgement must be explicit; a displayed message is not
automatically considered read.

### Explore safely

Combat: 100% player frame. Low health or harmful effect: 100%. After recovery:
brief grace period, then 0%. Minimap appears briefly after changing zones and
while hovered. Quest tracker appears for relevant progress/completion.

### Inventory workbench

Merchant, bank or mail interaction keeps bags and money visible. Nearly full
bags create a timed reminder. Closing the interaction restores ordinary rules.

### Post-fight review

Combat ending starts a short meter/objective reveal and releases queued social
attention. Hovering or scrolling holds the relevant frame visible while reading.

## Suggested first batch

1. Chat reading-history state.
2. More granular chat channel/sender filters.
3. Deferred important-message reveal after combat.
4. Missing-health and resource thresholds with stable recovery behavior.
5. Combat-ended moment.
6. Merchant/bank/mail/trade interaction conditions.
7. Quest-completion distinction and inventory-full attention.

Ship event timing and diagnostic improvements alongside these; a large list of
conditions is less valuable if reveals expire before the player can use them.

## Compatibility and boundaries

All additions are proposals. Verify Forever events, restricted/secret values,
secure-frame behavior and host-addon ownership separately. Use event-driven
updates and bounded timers where possible. Preserve native alpha effects such
as range or disabled states. Opacity does not establish whether an invisible
frame is click-through; do not promise that without separate verification.

## Player situations and references

Player discussions are anecdotal evidence of needs, not proof of compatibility:

- [Chat should stay hidden in combat, even on mouseover](https://www.reddit.com/r/WowUI/comments/gg9js5/):
  shows why suppressing and revealing conditions need clear priority.
- [Minimal UI with health/target/casting exceptions](https://www.reddit.com/r/WowUI/comments/1ua8grs/):
  supports attention-based player-frame visibility beyond combat alone.
- [Quest tracker timed reveal and mouseover](https://www.reddit.com/r/WowUI/comments/kmmp3m/):
  a useful baseline already partly covered by Frame Gambit's quest moments.
- [Tracker opens again unexpectedly](https://us.forums.blizzard.com/en/wow/t/remove-objective-tracker/1586697):
  emphasizes predictable transitions and coordination with the owning addon.
- [Auto Hide UI author documentation](https://www.curseforge.com/wow/addons/autohideui):
  describes missing-health/target reveals and respecting other addons' alpha
  authority. It does not establish support for our Forever client.

Design goal: show information when it becomes useful, keep it visible while
the player uses it, and let it leave quietly afterward.
