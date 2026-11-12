# Frame Gambit

Shows each part of your UI only when you need it, with rules you set per frame.

## Install

Put the `FrameGambit` folder in `World of Warcraft/_forever_/Interface/AddOns/`, then `/reload`.

## Use

- Open the editor with `/fg`.
- Pick a frame on screen, or add one from the list.
- Add rules: combat, mouseover, target, group, events, chat and more.
- Rules are checked top to bottom. The first match sets the opacity.
- **Otherwise** applies when no rule matches.
- Drag rules to change their order.
- Rules can also set a size and a position (experimental).
- **Cinematic** is a second profile for questing with a minimal UI.
- Profiles can be exported and imported.

| Command or key | Does |
| --- | --- |
| `/fg` | Open the editor |
| `/fg pick` | Pick a frame on screen |
| `/fg cinematic` | Toggle Cinematic |
| `/fg status` | Run a check |
| Key Bindings > Frame Gambit | Cinematic, Cinematic camera, Screenshot without interface |

## Data

Settings: `WTF/Account/<account>/SavedVariables/FrameGambit.lua`.

## More

- [Guide](docs/GUIDE.md): conditions, gamepad, size and position, skins
- [Integration](INTEGRATION.md): for addon authors
- [Changelog](CHANGELOG.md)
