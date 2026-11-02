# Cinematic mail validation

Run `lua tests/CinematicMail.lua .` from the addon directory.

In Forever and Retail, reload the UI after installing the fix. Enable Cinematic
mode, open a mailbox, and open a letter. Verify the body, attachments, and mail
actions are visible. Close the letter and open another without closing the inbox.
Repeat after toggling Cinematic mode and after reloading with Cinematic selected.
The surrounding HUD should retain its Cinematic behavior. Exit Cinematic and
verify normal mail behavior. The Lua regression also covers combat reopening,
host alpha changes, late frame discovery, and conditional alpha restoration.

Automated checks use mocked game frames; in-game visual verification is required.
