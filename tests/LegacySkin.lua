-- lua Interface/AddOns/FrameGambit/tests/LegacySkin.lua
-- Exercises the skin against the actual locally extracted Blizzard nine-slice
-- implementation. Atlas sizes are fixtures; this is not a visual engine test.
local root = arg[1] or "Interface/AddOns/FrameGambit"
local blizzard = "StorageInvestigation/dialogueui-forever-source/Interface/AddOns/Blizzard_SharedXML"
local current, cinematic = "legacy", false
local ns = { ICON_TEXTURE = "icon" }
function ns:GetAppearanceTheme() return current end
function ns:IsCinematicActive() return cinematic end
local M = {}
M.__index = M
local count = 0
local function Object(parent, name)
    count = count + 1
    return setmetatable({ parent=parent, name=name, points={}, hooks={}, shown=true,
        width=120, height=24, level=parent and parent.level + 1 or 500, enabled=true }, M)
end
function M:SetSize(w,h) self.width,self.height=w,h; self:Fire("OnSizeChanged",w,h) end
function M:GetSize() if self.all then return self.all:GetSize() end; return self.width,self.height end
function M:SetWidth(w) self:SetSize(w,self.height) end
function M:SetHeight(h) self:SetSize(self.width,h) end
function M:GetWidth() return (self:GetSize()) end
function M:GetHeight() return select(2,self:GetSize()) end
function M:SetPoint(...) self.points[#self.points+1]={...} end
function M:ClearAllPoints() self.points={} end
function M:SetAllPoints(other) self.all=other or self.parent end
function M:SetFrameLevel(v) self.level=v end
function M:GetFrameLevel() return self.level end
function M:GetParent() return self.parent end
function M:GetName() return self.name end
function M:EnableMouse(v) self.mouse=v end
function M:IsEnabled() return self.enabled end
function M:CreateTexture(_,layer,_,sub) local t=Object(self); t.layer,t.sub=layer,sub; return t end
function M:CreateFontString(...) return Object(self) end
function M:CreateMaskTexture() return Object(self) end
function M:SetTexture(v) self.texture=v end
function M:SetTexCoord(...) self.coords={...} end
function M:SetVertexColor(...) self.tint={...} end
function M:SetColorTexture(...) self.color={...} end
function M:SetTextColor(...) self.ink={...} end
function M:SetText(v) self.text=v end
function M:SetJustifyH(v) self.justifyH=v end
function M:SetRotation(v) self.rotation=v end
function M:SetDesaturated(v) self.desaturated=v end
function M:GetFontString() return self.label end
function M:GetThumbTexture() return self.thumb end
function M:SetThumbTexture(v) self.thumb=v end
function M:SetShown(v) self.shown=not not v end
function M:Show() self.shown=true end
function M:Hide() self.shown=false end
function M:IsShown() return self.shown end
function M:SetBackdropColor(...) self.backdrop={...} end
function M:SetBackdropBorderColor(...) self.backdropBorder={...} end
function M:SetDrawLayer(layer,sub) self.layer,self.sub=layer,sub end
function M:SetHorizTile(v) self.horizTile=v end
function M:SetVertTile(v) self.vertTile=v end
function M:SetSnapToPixelGrid(v) self.snap=v end
function M:SetTexelSnappingBias(v) self.bias=v end
function M:AddMaskTexture(v) self.mask=v end
function M:LockHighlight() self.highlight=true end
function M:UnlockHighlight() self.highlight=false end
function M:SetButtonState(v) self.buttonState=v end
function M:HookScript(event,fn) self.hooks[event]=self.hooks[event] or {}; table.insert(self.hooks[event],fn) end
function M:Fire(event,...) for _,fn in ipairs(self.hooks[event] or {}) do fn(self,...) end end
function M:RegisterCallback(event,fn,owner) self.callback,self.callbackOwner=fn,owner end
function M:SetVisibleExtentPercentage(v) self.extent=v end
function M:SetPanExtentPercentage(v) self.pan=v end
function M:SetScrollPercentage(v) self.percentage=v; if self.callback then self.callback(self.callbackOwner,v) end end
function M:GetVerticalScrollRange() return self.range or 0 end
function M:GetVerticalScroll() return self.scroll or 0 end
function M:SetVerticalScroll(v) self.scroll=v; if self.update then self.update() end end
function CreateFrame(_,name,parent,template) local o=Object(parent,name); o.template=template; return o end
C_Texture = {}
function C_Texture.GetAtlasInfo(name)
    local w,h=32,32
    if name:find("EdgeTop") or name:find("EdgeBottom") then w,h=256,16
    elseif name:find("EdgeLeft") or name:find("EdgeRight") then w,h=16,256
    elseif name=="Legacy-Challenge-BG" then w,h=920,575
    elseif name=="common-button-list-collapseExpand" then w,h=300,25
    elseif name=="common-searchbar-a" then w,h=120,20 end
    return {file=123,width=w,height=h,leftTexCoord=.1,rightTexCoord=.9,topTexCoord=.2,bottomTexCoord=.8,
        tilesHorizontally=name:sub(1,1)=="_",tilesVertically=name:sub(1,1)=="!"}
end
function M:SetAtlas(name,useSize)
    self.atlas=name
    if useSize then local info=C_Texture.GetAtlasInfo(name); self.width,self.height=info.width,info.height end
end
function GetFinalNameFromTextureKit(atlas) return atlas end
assert(loadfile(blizzard.."/Mainline/NineSliceLayouts.lua"))()
assert(loadfile(blizzard.."/NineSlice.lua"))()
assert(loadfile(root.."/LegacySkin.lua"))("FrameGambit",ns)
local skin=ns.LegacySkin
local main=CreateFrame("Frame","FrameGambitOptions")
main:SetSize(1180,680)
local state={art=Object(main),overlay=Object(main),atlasBorder=Object(main)}
skin:Apply("shell",main,state,{},true)
local native=state.legacy.visuals
assert(not state.art.shown and native.background.shown)
assert(native.background.layer=="BACKGROUND" and native.border.level==506)
assert(native.chrome.level==507 and not native.chrome.mouse)
assert(native.portrait.level<native.border.level,"Portrait must not obscure its metal rim")
local corner=native.border.TopLeftCorner
assert(corner.atlas=="UI-Frame-PortraitMetal-CornerTopLeft")
assert(corner.width==32 and corner.height==32)
assert(native.border.TopEdge.horizTile and native.border.LeftEdge.vertTile)
main:SetSize(930,560)
assert(corner.width==32 and corner.height==32,"Resize must not scale corners")
skin:Apply("shell",main,state,{},false)
assert(state.art.shown and not native.border.shown)

local button=CreateFrame("Button",nil,main)
button.label=Object(button)
local bs={bg=Object(button),hover=Object(button),border={Object(button)}}
skin:Apply("button",button,bs,{},true)
local art=bs.legacy.visuals.art
for _,size in ipairs({{22,22},{228,22},{630,25},{206,70},{76,24}}) do
    button:SetSize(unpack(size))
    assert(art.used==9,"Resizing must not repeat ornamental edges")
    assert(art.pieces[1].width==5 and art.pieces[1].height==5,"Fixed button corners")
    for i,piece in ipairs(art.pieces) do
        if i<=art.used then
            assert(piece.shown and piece.width>0 and piece.height>0)
            for _,coord in ipairs(piece.coords) do assert(coord>=.1-1e-8 and coord<=.9+1e-8) end
        else assert(not piece.shown,"Unused tiles hidden after shrinking") end
    end
end
local before=count
for _=1,20 do skin:Apply("button",button,bs,{},true) end
assert(count==before,"Repainting must not allocate more textures or hooks")
button:Fire("OnMouseDown")
assert(bs.legacy.visuals.selected.shown and art.pieces[1].tint[1]==.7)
button:Fire("OnMouseUp")
assert(not bs.legacy.visuals.selected.shown)
button._selected=true
skin:Apply("button",button,bs,{},true)
assert(bs.legacy.visuals.selected.shown)
button.enabled=false; button:Fire("OnDisable")
assert(not bs.legacy.visuals.selected.shown and button.label.ink[1]==.5)
skin:Apply("button",button,bs,{},false)
assert(bs.bg.shown and not art.pieces[1].shown)
skin:Apply("button",button,bs,{},true)
assert(not bs.bg.shown and art.pieces[1].shown)

local edit=CreateFrame("EditBox",nil,main)
local es={bg=Object(edit),border={Object(edit)}}
skin:Apply("edit",edit,es,{},true)
assert(es.legacy.visuals.art.atlas=="common-searchbar-a")
local close=CreateFrame("Button",nil,main)
local cs={x=Object(close)}
skin:Apply("close",close,cs,{},true)
assert(cs.legacy.visuals.close.template=="UIPanelCloseButtonNoScripts")
assert(cs.legacy.visuals.close.width==28 and not cs.legacy.visuals.close.mouse)
close:Fire("OnMouseDown"); assert(cs.legacy.visuals.close.buttonState=="PUSHED")
close:Fire("OnMouseUp"); assert(cs.legacy.visuals.close.buttonState=="NORMAL")

local scroll=CreateFrame("ScrollFrame",nil,main)
local custom=CreateFrame("Button",nil,main)
scroll.range=600; scroll.scroll=150; scroll.height=300
scroll.update=function() skin:UpdateScroll(scroll,custom) end
assert(skin:UpdateScroll(scroll,custom))
local bar=skin.scrolls[scroll]
assert(bar.template=="MinimalScrollBar" and not custom.shown)
assert(bar.percentage==.25 and bar.extent==1/3)
bar.callback(bar.callbackOwner,.5)
assert(scroll.scroll==300,"Native scrollbar moves existing scroll child without recursive callbacks")
scroll.range=0; scroll.update(); assert(not bar.shown)
current="eui"; assert(not skin:UpdateScroll(scroll,custom) and not bar.shown)
current="legacy"

for _,key in ipairs({"legacyTitle","legacyIcon","header","subtitle","version","appearance","closeButton",
    "profile","cinematic","peek","helpButton","headerDivider"}) do main[key]=Object(main) end
main._legacyChrome=Object(main)
skin:Layout(main,true)
assert(main.closeButton.width==28 and main.closeButton.height==28)
assert(main.closeButton.points[1][4]==0 and main.closeButton.points[1][5]==3,
    "Close button must match Forever's Camelot TOPRIGHT (0, 3) anchor (build 70532)")
assert(not main.legacyTitle.shown and main.header.height==40,"Legacy header is a single toolbar row")
assert(main.subtitle.justifyH=="LEFT")
assert(main.profile.points[1][1]=="TOPLEFT" and main.profile.points[1][4]>=52,"Context group clears the portrait")
assert(main.helpButton.points[1][1]=="TOPRIGHT","Utilities anchor the right edge")
assert(main.version.points[1][2]==main,"Legacy version sits in the window title bar")
cinematic=true; skin:Layout(main,true)
assert(main.header.height==112,"Cinematic controls add their strip below the toolbar row")
skin:Layout(main,false)
assert(main.closeButton.width==26 and main.closeButton.points[1][4]==-4 and main.closeButton.points[1][5]==-4,
    "Other skins must retain their original close-button position")
assert(main.legacyTitle.shown and main.header.height==152)
assert(main.profile.points[1][1]=="RIGHT","Other skins keep the context group in the right toolbar")
assert(main.version.points[1][2]==main.legacyTitle,"Other skins show the version beside the title")
local arrow=Object(main)
arrow.arrowLines={Object(arrow),Object(arrow),Object(arrow)}
skin:Arrow(arrow,"right",true)
assert(arrow._legacyArrow.atlas=="minimal-scrollbar-arrow-top")
assert(arrow._legacyArrow.rotation==-math.pi/2 and not arrow.arrowLines[1].shown)
skin:RefreshDetails(false)
assert(not arrow._legacyArrow.shown and arrow.arrowLines[1].shown)
local slider=Object(main)
local originalThumb=Object(slider)
slider:SetThumbTexture(originalThumb)
skin:Slider(slider,true)
assert(slider.thumb.atlas=="Minimal_SliderBar_Button" and not originalThumb.shown)
assert(skin.sliders[slider].middle.horizTile)
skin:Slider(slider,false)
assert(slider.thumb==originalThumb and originalThumb.shown)
assert(not skin.sliders[slider].left.shown)
main.header._legacyHeader=true
local hs={bg=Object(main.header)}
ns.Options=main
skin:Apply("panel",main.header,hs,{},true)
assert(not hs.legacy.visuals.border.shown,"Header should not have a nested box")
skin:Layout(main,true)
assert(not hs.legacy.visuals.border.shown,"Panel keeps header integrated")
-- Cards use the Blizzard list-button art.
local card=CreateFrame("Frame",nil,main)
skin:Row(card,false)
local row=card._legacyRow
assert(row.art and row.art.visible, "cards use the list-button art")
assert(not row.selected.shown, "card not live")
skin:Row(card,true)
assert(row.selected.shown, "live card fill still works")
local previousTheme=current
current="eui"
skin:Row(card,true)
assert(row.art.visible==false and not row.selected.shown, "hidden when the appearance is not Legacy")
current=previousTheme

print("Legacy skin: fixed corners, tiled edges, layering, states, resize, theme switching, scrolling and Cinematic layout passed")
