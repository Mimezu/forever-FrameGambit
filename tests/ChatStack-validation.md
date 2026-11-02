# Whole-chat validation

Implementation inspected against the locally extracted Forever UI build
1.60.1.69913, particularly Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua
and FloatingChatFrame.xml. Temporary windows are registered in CHAT_FRAMES;
tabs move between the dock and FullscreenFrame, and minimized windows are
separate siblings. ChatStack therefore uses a logical group, not reparenting.

Automated: `lua Interface/AddOns/FrameGambit/tests/ChatStack.lua` checks late
whispers past slot 20, inherited opacity, alpha-independent descendants,
20 dock/undock/release/reacquire cycles, host writes, new anonymous chrome,
inactive main tab, geometry, cinematic member discovery and Ellesmere handoff.
ChatMoments.lua and ForeverChat.lua cover event timers and input lifecycle.

In-game checks still required:

1. Reload, keep existing Chat rules (Otherwise 0%, New private message 100%).
2. Receive a whisper from a new sender while hidden. Check the new tab,
   selected messages and dock reveal together, then fade after the duration.
3. Reply, close, reopen, undock/redock, and minimize/maximize the whisper.
4. Set a 50% rule; repeat docking and profile switches. Confirm opacity stays
   stable and disabling Chat restores native appearance.
5. Repeat in Cinematic and combat, with mouseover and typing. Check escaped
   prompt text, borders and controls at 0%. Native selected-tab/Show/Hide
   decisions remain Blizzard-owned; the group does not force inactive tabs open.

Unrelated third-party chat replacements need their own provider; anonymous
descendants are covered, but arbitrary UIParent siblings cannot be identified
as chat merely by where they are anchored.
