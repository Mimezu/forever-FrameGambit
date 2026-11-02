# Frame Gambit integration API

Frame Gambit is a companion layer: it owns only its own opacity rules and
saved variables.  An external UI can opt in by registering a stable adapter;
it must not expose its configuration database.

```lua
local ok, reason = FrameGambitAPI.RegisterTarget({
  id = "myui.main_bar", -- Stable forever; changing it loses the user's rule.
  label = "Main action bar",
  source = "My UI",
  protected = true,
  capability = "Live fade in combat",
  capabilityTone = "teal", -- teal, accent, amber, or muted
  capabilityNote = "Frame Gambit fades this bar but never changes its secure buttons.",
  -- Optional: the host accepts a target alpha but owns its physical animation.
  -- Frame Gambit will keep rule priority and fade-out delay, without applying
  -- a competing transition or presenting a misleading duration control.
  timingOwner = "host",
  timingLabel = "My UI timing",
  timingNote = "My UI owns the physical fade animation.",
  -- Optional: keep this frame opacity-only; Frame Gambit's experimental
  -- size and position rules will not be offered for it.
  layout = false,
  resolve = function()
    return MyUI_MainBar
  end,
})
```

`resolve()` may return `nil` until the frame exists.  The returned frame must
provide `GetRect`, `IsShown`, `GetAlpha`, and `SetAlpha`.  A provider may
alternatively pass stable global frame names as `names = { "MyUI_MainBar" }`.

Registration is intentionally one-way.  Providers cannot change profiles,
reactions, alpha values, or relationship settings. Frame Gambit never shows,
hides, reparents, or changes secure attributes on registered frames. While a
target is actively controlled, a guarded `SetAlpha` post-hook remembers the
host's newest alpha for restoration and reapplies PF's current opacity. The
hook is inert after ownership ends and never replaces the host method.

The in-game frame atlas can also register an exact named global frame without
an adapter. Unnamed frames are deliberately session-only. Adapter registration
remains preferable when a UI needs a composite hit region, host-visibility
signal, dynamic resolver, or more precise capability guidance.

Cinematic Mode separately leases eligible top-level UI roots and explicit
shared-parent child branches for its blackout scene. It uses guarded post-hooks
only to reapply zero alpha when a leased frame shows or its owning addon
repaints alpha. Those hooks are inert outside the scene and never replace frame
methods, mouse behavior, layout, or styling.

`capability` and `capabilityTone` are optional user-facing guidance shown in
the target editor and picker. `capabilityNote` is the bounded explanatory copy
shown in the editor. They describe the adapter's limits; they do not grant
Frame Gambit any extra control over the frame.

`timingOwner = "host"` is an optional adapter contract for semantic surfaces
whose supported API accepts a final opacity but deliberately owns its own
animation. `timingLabel` and `timingNote` explain that boundary in the editor.
Frame Gambit still evaluates ordered conditions and its fade-out wait, then
requests the resolved opacity once instead of running a second interpolation.

Keep `label` and `source` to at most 64 characters, `capability` concise (48
characters or fewer), and `capabilityNote` to at most 240 characters so they
remain readable in the compact editor and bounded in diagnostic output.

## Cinematic scene providers

Optional UI addons can register a semantic visual role without becoming a
required dependency:

```lua
FrameGambitAPI.RegisterSceneProvider({
  id = "myaddon_palette",
  role = "quick_actions",
  cinematicKeep = true,
  resolve = function()
    return MyAddonPaletteFrame
  end,
})
```

`resolve()` may return one Frame or a table of Frames. Frame Gambit only uses
these roots as Cinematic visual exemptions; it does not open, close, reparent,
restyle, or modify the provider's configuration. The built-in providers use
this same path for DialogueUI/Blizzard quest conversations and Ellesmere
Quickdraw. OPie's anonymous renderer retains its stricter structural adapter.

## Ellesmere Cooldown Manager

Frame Gambit exposes the three stable Blizzard viewer layers used by the
Cooldown Manager: Cooldowns, Utility, and Buffs. EllesmereUI may style,
reposition, and divide their icons into its own bars; PF applies only a final
alpha to the underlying viewer. EUI therefore retains styling, placement,
cooldown states, alerts, and icon membership.

Set the relevant EUI bars to **Always Visible**, then configure the matching
`CDM · ...` target through the normal Frame Gambit workflow. Custom EUI bars
inherit the PF rules of their underlying Blizzard category. Two custom bars
from the same category cannot have separate PF rules, which is the deliberate
tradeoff for a stable integration that does not inspect EUI runtime tables,
edit EUI source, or touch its SavedVariables.

## In-game audit

Run `/fg audit` to print a read-only summary
of the active profile, its relationship graph, and adapter availability. This
is useful before reproducing a frame issue; it never changes a profile or a
registered frame.
