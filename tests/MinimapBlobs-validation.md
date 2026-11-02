# Native quest overlays in the minimap group

The patterned circle shown in the Forever screenshots matches the previously
identified `MINIMAP/UI-QuestBlob-MinimapRing` asset. It belongs to the native
blob renderer; scanning child frames/regions cannot claim this channel.

Sources checked:
- Local Forever 1.60.1.69913 API export:
  `StorageInvestigation/dialogueui-forever-source/Interface/AddOns/Blizzard_APIDocumentationGenerated/MinimapFrameAPIDocumentation.lua`.
- [Blizzard UI API export](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MinimapFrameAPIDocumentation.lua)
  lists nine blob alpha setters, plus SetIconScale; no blob alpha getters.
- [Blizzard minimap XML](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.xml)
  establishes the map/cluster hierarchy.
- Installed Leatrix Plus uses SetQuestBlobRingAlpha and SetArchBlobRingAlpha
  to suppress rings for square maps; early setter hooks preserve those choices.

Implementation composes the active map/cluster opacity with all nine native
Quest/Task/Arch Inside/Outside/Ring alpha channels. The ring is retained when
the map is visible and follows partial and zero opacity. This is independent
of the icon scaling option. Native icons retain Keep/Hide at 0%/Scale behavior;
the inspected API does not expose an icon opacity setter.

Baseline limitation: read a getter if a client provides one, otherwise capture
host setter calls from module load. If neither is available, assume 255 (full byte opacity).
This is a deliberate compatibility fallback, not a verified client default;
a pre-load skin override cannot be recovered through the documented API.
Untouched channels are not written at full opacity. Later host settings,
including zero alpha, are preserved and restored on release.

Automated: MinimapBlobs.lua, ForeverMinimap.lua, and MinimapProfileSwitch.lua
(cluster and retail arguments). Cover all channels, partial/zero opacity,
host writes, native rebuilds, combined target alpha, release and retry,
missing methods and profile transitions.

The initial 0..1 fallback hid overlays but did not visibly restore them.
After correcting native channel values to the 0..255 byte range, the user
confirmed that overlays hide and return correctly in Forever, including full
hiding. The requested minimum-opacity experiment was canceled; keep zero.
Automated native-channel tests now model byte opacity and check visible return.
Static inspection of the shipped executable did not yield usable function
code; it was not evidence for the range. The live user check verified recovery.

Additional live cases to check after /reload:
1. Stand inside a tracked quest area with the patterned circle visible.
2. Use the existing MinimapCluster gambit at 100%, 50%, and 0%.
   Check the patterned circle, blue fill/boundary, and quest icons. Native
   icons hide at zero with Hide at 0%; they do not alpha-fade at 50%.
3. Cross the quest boundary, change tracked quest, zoom and rotate the map;
   repeat during combat and with mouseover reveal.
4. Switch profiles and disable map control; check ring/overlay restoration.
5. If a layer remains visible, identify it in game before adding more guessed
   frame names or replacing textures. Mock tests cannot verify native drawing.


## Follow-up: multiple quest areas

The user subsequently showed one quest area still visible at zero while a
second area and the minimap disappeared. This supersedes the earlier complete
success assessment: byte opacity fixed restoration, but native alpha coverage
was incomplete. The exact selected/unselected native rendering distinction is
not established from the screenshots alone.

At exact zero, Frame Gambit now hides the unprotected native Minimap frame,
leaving MinimapCluster shown and retaining the owned map rectangle for hover.
Positive opacity restores the renderer at the beginning of the reveal. Native
Show/Hide requests are tracked; a host-hidden minimap is never forced visible
on release. Protected or unreadable-protection frames keep alpha-only behavior.
No CVar, quest tracking selection, texture replacement or minimum alpha is used.

MinimapRenderer.lua exercises zero/reveal cycles, direct and cluster hover,
host Show/Hide, failed restoration/retry, combat on unprotected maps, skipping
protected maps, and map replacement. It passes under Lua 5.1 and LuaJIT along
with blob, profile and geometry regressions. These mocks verify lifecycle,
not the beta compositor: repeat the user's two-area example after /reload.


Marker-only cutoff: at effective map opacity <= 30%, native icon scale and
controllable blob alpha receive zero. Above 30% they resume configured behavior.
The renderer gate uses the original map opacity, so terrain stays visible at
12% and 30%; only actual 0% suspends it. MinimapRenderer.lua checks 12%, 30%,
and 30.1%. Native blob paths that ignore the alpha setters may still escape
the marker-only cutoff; this does not extend the complete renderer gate.
