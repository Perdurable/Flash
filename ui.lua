-- ui.lua - centralized UI helper functions for Flash menu
Flash = Flash or {}
Flash.UI = Flash.UI or {}

local function getOptionsFrame()
    if not _G["FlashOptionsMenu"] and Flash and type(Flash.DebugError) == "function" then
        Flash.DebugError("Options frame FlashOptionsMenu missing when calling getOptionsFrame()")
    end
    return _G["FlashOptionsMenu"]
end

local function MakeCheckButton(name, parent, xOffset, yOffset, labelText, fontObject)
    local btn = _G[name]
    if btn and type(btn) == "table" then
        btn:SetParent(parent)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        btn:Show()
    else
        btn = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        btn:Show()
    end
    local lbl = _G[name .. "Text"]
    if lbl then
        if fontObject and lbl.SetFontObject then lbl:SetFontObject(fontObject) end
        lbl:SetTextColor(1, 0.82, 0)
        if labelText then lbl:SetText(labelText) end
    end
    return btn
end

local function MakeEditBox(name, parent, xOffset, yOffset, width, height)
    local eb = _G[name]
    if eb and type(eb) == "table" then
        eb:SetParent(parent)
        eb:ClearAllPoints()
        eb:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        eb:Show()
    else
        eb = CreateFrame("EditBox", name, parent)
        eb:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        eb:SetWidth(width or 40)
        eb:SetHeight(height or 18)
        eb:SetAutoFocus(false)
        eb:Show()
    end
    if eb.SetFontObject then eb:SetFontObject("GameFontNormalSmall") end
    if eb.SetTextInsets then eb:SetTextInsets(4, 4, 2, 2) end
    if eb.SetJustifyH then eb:SetJustifyH("CENTER") end
    if eb.SetBackdrop then
        eb:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile = true, tileSize = 16,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        eb:SetBackdropColor(0, 0, 0, 0.5)
    end
    if eb.SetFrameLevel and parent.GetFrameLevel then
        eb:SetFrameLevel((parent:GetFrameLevel() or 1) + 3)
    end
    local opts = getOptionsFrame()
    if eb.SetFrameStrata and opts and opts.GetFrameStrata then
        eb:SetFrameStrata(opts:GetFrameStrata())
    end
    return eb
end

local function UpdateBuffXY(key, nx, ny)
    nx = math.floor(nx + 0.5)
    ny = math.floor(ny + 0.5)
    Flash.config = Flash.config or {}
    Flash.config.buffIcons = Flash.config.buffIcons or {}
    Flash.config.buffIcons[key] = { x = nx, y = ny }
    Flash.buffIcons = Flash.buffIcons or {}
    Flash.buffIcons[key] = Flash.buffIcons[key] or {}
    Flash.buffIcons[key].xOffset = nx
    Flash.buffIcons[key].yOffset = ny
    if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
end

local function UpdateBuffSize(key, val)
    val = math.floor(val + 0.5)
    if val < 8 then val = 8 end
    if val > 128 then val = 128 end
    if Flash and type(Flash.ApplyBuffIconSize) == "function" then
        Flash.ApplyBuffIconSize(key, val)
    else
        Flash.config = Flash.config or {}
        Flash.config.buffIconSizes = Flash.config.buffIconSizes or {}
        Flash.config.buffIconSizes[key] = val
    end
    if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
end

-- expose historical names for compatibility
Flash.UI.MakeCheckButton = MakeCheckButton
Flash.UI.MakeEditBox = MakeEditBox
Flash.UI.UpdateBuffXY = UpdateBuffXY
Flash.UI.UpdateBuffSize = UpdateBuffSize
Flash.UI.MakeCheckButton_Global = MakeCheckButton
Flash.UI.MakeEditBox_Global = MakeEditBox
Flash.UI.UpdateBuffXY_Global = UpdateBuffXY
Flash.UI.UpdateBuffSize_Global = UpdateBuffSize

-- helper to ensure table exists; consumers can call this before using APIs
function Flash.LoadUIHelpers()
    Flash.UI = Flash.UI or {}
end
