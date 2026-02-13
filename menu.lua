--[[
Rules:
1) When dependencies or helpers are missing, call `Flash.DebugError(msg)` instead of silently falling back.
2) Keep comments clear and up to date; add brief comments for non-obvious logic and behavior changes.
3) Preserve existing public API names and file responsibilities unless the task explicitly requires otherwise.
4) Avoid silent fallback behavior; prefer explicit, logged behavior for unexpected states.
5) When choosing class icons, use Reference Material/Spell Icons and the matching class folder.
]]
-- Flash/menu.lua - moved menu code from FlashMenu.lua
-- This file was created by refactoring to keep the main addon file smaller.
-- The original contents of FlashMenu.lua were moved here verbatim.

-- Create the options window frame
Flash = Flash or {}
Flash.menuLoaded = "start"
Flash.options = Flash.options or CreateFrame("Frame", "FlashOptionsMenu", UIParent)
local FlashOptionsMenu = Flash.options
Flash.menuLoaded = "frame"
FlashOptionsMenu:SetWidth(520)
FlashOptionsMenu:SetHeight(420)
FlashOptionsMenu:SetPoint("CENTER", UIParent)

-- Apply a standard dialog background and border
FlashOptionsMenu:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
Flash.menuLoaded = "backdrop"

-- Allow the user to drag the window around
FlashOptionsMenu:EnableMouse(true)
FlashOptionsMenu:SetMovable(true)
FlashOptionsMenu:RegisterForDrag("LeftButton")
FlashOptionsMenu:SetScript("OnDragStart", function() FlashOptionsMenu:StartMoving() end)
FlashOptionsMenu:SetScript("OnDragStop", function() FlashOptionsMenu:StopMovingOrSizing() end)
Flash.menuLoaded = "drag"

-- Hide by default and make it close on Escape
FlashOptionsMenu:Hide()
UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "FlashOptionsMenu")
Flash.menuLoaded = "hide"

-- Add a persistent bottom button early so it exists even if later code aborts
if not FlashOptionsMenu._closeButton then
    local doneBtn = nil
    local ok, btn = pcall(CreateFrame, "Button", "Flash_CloseButton", FlashOptionsMenu, "UIPanelButtonTemplate2")
    if ok and btn then doneBtn = btn end
    if not doneBtn then
        ok, btn = pcall(CreateFrame, "Button", "Flash_CloseButton", FlashOptionsMenu, "UIPanelButtonTemplate")
        if ok and btn then doneBtn = btn end
    end
    if not doneBtn then
        ok, btn = pcall(CreateFrame, "Button", "Flash_CloseButton", FlashOptionsMenu)
        if ok and btn then doneBtn = btn end
    end
    if doneBtn then
        if doneBtn.SetSize then
            doneBtn:SetSize(80, 20)
        else
            if doneBtn.SetWidth then doneBtn:SetWidth(80) end
            if doneBtn.SetHeight then doneBtn:SetHeight(20) end
        end
        doneBtn:SetPoint("BOTTOM", FlashOptionsMenu, "BOTTOM", 0, 20)
        doneBtn:SetText("Done")
        doneBtn:SetScript("OnClick", function() FlashOptionsMenu:Hide() end)
        doneBtn:Show()
        FlashOptionsMenu._closeButton = doneBtn
    else
        if Flash and type(Flash.DebugError) == "function" then
            Flash.DebugError("Failed to create Flash close button")
        end
    end
end
Flash.menuLoaded = "close"

-- Main title text for the options window
local title = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
title:SetPoint("TOP", 0, -16)
title:SetText("Flash Options")
Flash.menuLoaded = "title"

-- Top-right close (standard UIPanelCloseButton)
-- no top-right close; use bottom-center Exit button instead

---------------------------------------------------------
-- SOUND DROPDOWN
---------------------------------------------------------
-- Label for the sound control
local soundLabel = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soundLabel:SetPoint("TOPLEFT", 20, -40)
soundLabel:SetText("Alert Sound:")

-- Dropdown frame reference (use a specific name to avoid collisions)
local soundDropdown = nil

-- Helper to build the full sound file path from a short filename
local function SoundFullPath(soundFile)
    if not soundFile or soundFile == "" then return "" end
    return "Interface\\AddOns\\Flash\\Media\\" .. soundFile
end

-- Resolve selected sound index from current config value.
-- Returns 0 for "None", otherwise 1..N into Flash.soundFiles.
local function ResolveSelectedSoundIndex()
    Flash.config = Flash.config or {}
    local selectedSound = tostring(Flash.config.selectedSound or "")
    if selectedSound == "" then return 0 end
    if not Flash or not Flash.soundFiles then return 0 end
    for i, sound in ipairs(Flash.soundFiles) do
        if string.find(selectedSound, sound, 1, true) then
            return i
        end
    end
    return 0
end

-- Safe wrapper for UIDropDownMenu_SetSelectedID that tolerates
-- accidentally reversed or invalid arguments from other addons.
local function SafeUIDropDown_SetSelectedID(frame, id)
    if type(UIDropDownMenu_SetSelectedID) ~= "function" then return end
    -- normal case: frame is a frame-like table
    if type(frame) == "table" and frame.GetObjectType then
        pcall(UIDropDownMenu_SetSelectedID, frame, id)
        return
    end
    -- fallback: if arguments are reversed, try swapping
    if type(id) == "table" and id.GetObjectType then
        pcall(UIDropDownMenu_SetSelectedID, id, frame)
        return
    end
    -- otherwise ignore unsafe call
end

-- Safe wrapper for UIDropDownMenu_SetWidth to handle arg order differences
local function SafeUIDropDown_SetWidth(frame, width)
    if type(UIDropDownMenu_SetWidth) ~= "function" then return end
    if type(frame) == "table" and frame.GetObjectType then
        local ok = pcall(UIDropDownMenu_SetWidth, frame, width)
        if ok then return end
    end
    if type(width) == "table" and width.GetObjectType then
        pcall(UIDropDownMenu_SetWidth, width, frame)
        return
    end
    pcall(UIDropDownMenu_SetWidth, width, frame)
end

-- Handle a selection from the dropdown
local function Dropdown_OnClick(index)
    -- When `index` is nil we treat that as the "None" selection.
    Flash.config = Flash.config or {}
    if not index then
        Flash.config.selectedSound = ""
        Flash.config._soundIndex = 0
        return
    end
    if not Flash or not Flash.soundFiles then return end
    local sound = Flash.soundFiles[index]
    if sound then
        local fullPath = SoundFullPath(sound)
        Flash.config.selectedSound = fullPath
        Flash.config._soundIndex = index
        PlaySoundFile(fullPath)
    end
    
end

-- Populate the dropdown list and select the current value
local function Dropdown_Initialize()
    if not Flash or not Flash.soundFiles then return end

    -- Build dropdown entries with a leading "(None)" option.
    local selectedID = 1
    local selectedSound = tostring((Flash.config and Flash.config.selectedSound) or "")

    local pos = 1
    local function addEntry(text, soundIndex)
        local info = UIDropDownMenu_CreateInfo()
        info.text = text
        local thisPos = pos
        local thisSound = soundIndex
        -- closure captures both the display position and the underlying sound index
        info.func = function()
            Dropdown_OnClick(thisSound)
            SafeUIDropDown_SetSelectedID(soundDropdown, thisPos)
        end
        UIDropDownMenu_AddButton(info, 1)
        pos = pos + 1
    end

    -- None option
    addEntry("(None)", nil)

    -- Add all sound files
    for i, sound in ipairs(Flash.soundFiles) do
        addEntry(sound, i)
        if selectedSound ~= "" and string.find(selectedSound, sound, 1, true) then
            selectedID = i + 1 -- offset by 1 because None is first
        end
    end

    if selectedSound == "" then selectedID = 1 end
    SafeUIDropDown_SetSelectedID(soundDropdown, selectedID)
end

-- Refresh the visual sound control state from saved config.
local function SyncSoundControlSelection()
    Flash.config = Flash.config or {}
    local idx = ResolveSelectedSoundIndex()
    Flash.config._soundIndex = idx

    if soundDropdown and soundDropdown.GetObjectType and soundDropdown:GetObjectType() == "Frame" then
        if type(UIDropDownMenu_Initialize) == "function" then
            UIDropDownMenu_Initialize(soundDropdown, Dropdown_Initialize)
        end
        SafeUIDropDown_SetSelectedID(soundDropdown, idx + 1)
        if type(UIDropDownMenu_SetText) == "function" then
            local label = "(None)"
            if idx > 0 and Flash and Flash.soundFiles then
                label = Flash.soundFiles[idx] or "(None)"
            end
            pcall(UIDropDownMenu_SetText, soundDropdown, label)
        end
    end

    if FlashOptionsMenu and type(FlashOptionsMenu._updateSoundFallbackLabel) == "function" then
        FlashOptionsMenu._updateSoundFallbackLabel()
    end
end

-- Build the sound selector control (dropdown when available, fallback button otherwise)
local function BuildSoundControl()
    if type(UIDropDownMenu_Initialize) == "function" and type(UIDropDownMenu_SetWidth) == "function" and type(UIDropDownMenu_CreateInfo) == "function" then
            soundDropdown = CreateFrame("Frame", "FlashSoundDropdown", FlashOptionsMenu, "UIDropDownMenuTemplate")
        soundDropdown:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", -15, -5)
        UIDropDownMenu_Initialize(soundDropdown, Dropdown_Initialize)
            SafeUIDropDown_SetWidth(soundDropdown, 180)
        return
    end

    -- Hide any existing dropdown and create a simple button that cycles sounds
    if soundDropdown and soundDropdown.GetObjectType and soundDropdown:GetObjectType() == "Frame" then
        soundDropdown:Hide()
    end
    local fb = CreateFrame("Button", nil, FlashOptionsMenu, "UIPanelButtonTemplate")
    fb:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -5)
    if fb.SetSize then
        fb:SetSize(180, 24)
    else
        if fb.SetWidth then fb:SetWidth(180) end
        if fb.SetHeight then fb:SetHeight(24) end
    end
    Flash.config = Flash.config or {}
    -- Use 0 to represent the "None" selection; 1..N map to Flash.soundFiles[1..N]
    Flash.config._soundIndex = tonumber(Flash.config._soundIndex) or 0

    -- Update button label to show the selected sound (or None)
    local function updateFB()
        local idx = tonumber(Flash.config._soundIndex) or 0
        local name
        if idx == 0 then
            name = "(none)"
        else
            name = (Flash.soundFiles and Flash.soundFiles[idx]) or "(none)"
        end
        fb:SetText(name)
    end

    -- Cycle the sound list and play a preview; includes None as an option
    fb:SetScript("OnClick", function()
        if not Flash or not Flash.soundFiles then return end
        local totalSounds = 0
        for _ in ipairs(Flash.soundFiles) do totalSounds = totalSounds + 1 end
        if totalSounds == 0 then
            Flash.config._soundIndex = 0
            Flash.config.selectedSound = ""
            updateFB()
            return
        end
        local totalOptions = totalSounds + 1 -- include the None option
        local cur = tonumber(Flash.config._soundIndex) or 0
        -- increment and wrap in range [0, totalSounds]
        cur = math.fmod((cur + 1), totalOptions)
        Flash.config._soundIndex = cur
        if cur == 0 then
            Flash.config.selectedSound = ""
        else
            local sound = Flash.soundFiles[cur]
            local fullPath = SoundFullPath(sound)
            Flash.config.selectedSound = fullPath
            pcall(PlaySoundFile, fullPath)
        end
        updateFB()
    end)
    FlashOptionsMenu._soundFallbackButton = fb
    FlashOptionsMenu._updateSoundFallbackLabel = updateFB
    updateFB()
end

-- Build sound control and log if fallback was used inside BuildSoundControl
do
    local ok, err = pcall(BuildSoundControl)
    if not ok and Flash and type(Flash.DebugError) == "function" then
        Flash.DebugError("BuildSoundControl failed: "..tostring(err))
    end
end
Flash.menuLoaded = "sound"


---------------------------------------------------------
-- Build class-specific checkboxes (local, safe)
---------------------------------------------------------
-- Build class-specific checkboxes (local, safe)

-- Extracted row and helper functions at file scope to simplify BuildClassCheckboxes
local function MakeCheckButton_Global(btnName, parentFrame, xOffset, yOffset, labelText, fontObject)
    if Flash and Flash.UI and type(Flash.UI.MakeCheckButton_Global) == "function" then
        return Flash.UI.MakeCheckButton_Global(btnName, parentFrame, xOffset, yOffset, labelText, fontObject)
    end
    if Flash and type(Flash.DebugError) == "function" then
        Flash.DebugError("UI helper Flash.UI.MakeCheckButton_Global missing, using inline implementation")
    end
    -- graceful fallback (minimal inline implementation)
    local btn = _G[btnName]
    if btn and type(btn) == "table" then
        btn:SetParent(parentFrame)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
        btn:Show()
    else
        btn = CreateFrame("CheckButton", btnName, parentFrame, "UICheckButtonTemplate")
        btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
        btn:Show()
    end
    local lbl = _G[btnName.."Text"]
    if lbl then
        if fontObject and lbl.SetFontObject then lbl:SetFontObject(fontObject) end
        lbl:SetTextColor(1, 0.82, 0)
        if labelText then lbl:SetText(labelText) end
    end
    return btn
end

local function MakeEditBox_Global(boxName, parentFrame, xOffset, yOffset, width, height)
    if Flash and Flash.UI and type(Flash.UI.MakeEditBox_Global) == "function" then
        return Flash.UI.MakeEditBox_Global(boxName, parentFrame, xOffset, yOffset, width, height)
    end
    if Flash and type(Flash.DebugError) == "function" then
        Flash.DebugError("UI helper Flash.UI.MakeEditBox_Global missing, using inline implementation")
    end
    local eb = _G[boxName]
    if eb and type(eb) == "table" then
        eb:SetParent(parentFrame)
        eb:ClearAllPoints()
        eb:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
        eb:Show()
    else
        eb = CreateFrame("EditBox", boxName, parentFrame)
        eb:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
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
    if eb.SetFrameLevel and parentFrame.GetFrameLevel then
        eb:SetFrameLevel((parentFrame:GetFrameLevel() or 1) + 3)
    end
    if eb.SetFrameStrata then
        local opts = _G["FlashOptionsMenu"]
        if opts and opts.GetFrameStrata then eb:SetFrameStrata(opts:GetFrameStrata()) end
    end
    return eb
end

local function UpdateBuffXY_Global(key, nx, ny)
    if Flash and Flash.UI and type(Flash.UI.UpdateBuffXY_Global) == "function" then
        return Flash.UI.UpdateBuffXY_Global(key, nx, ny)
    end
    if Flash and type(Flash.DebugError) == "function" then
        Flash.DebugError("UI helper Flash.UI.UpdateBuffXY_Global missing, using inline implementation")
    end
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

local function UpdateBuffSize_Global(key, val)
    if Flash and Flash.UI and type(Flash.UI.UpdateBuffSize_Global) == "function" then
        return Flash.UI.UpdateBuffSize_Global(key, val)
    end
    if Flash and type(Flash.DebugError) == "function" then
        Flash.DebugError("UI helper Flash.UI.UpdateBuffSize_Global missing, using inline implementation")
    end
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

-- Layout constants for class tracker rows and headers
local CLASS_SECTION_OFFSET_X = 16
local CLASS_SECTION_OFFSET_Y = -52
local CLASS_HEADER_Y = -10
local CLASS_BUFF_HEADER_X = 8
local CLASS_ROW_START_Y = -28
local CLASS_ROW_SPACING = 26
local CLASS_INPUT_Y_OFFSET = -4
local CLASS_COL_LABEL_X = 8
local CLASS_COL_COMBAT_X = 220
local CLASS_COL_SIZE_X = 300
local CLASS_COL_X_X = 360
local CLASS_COL_Y_X = 420
local CLASS_HEADER_SIZE_CENTER_X = CLASS_COL_SIZE_X + 20
local CLASS_HEADER_X_CENTER_X = CLASS_COL_X_X + 20
local CLASS_HEADER_Y_CENTER_X = CLASS_COL_Y_X + 20

local function BuildRow_Global(container, playerClass, i, buff)
    local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
    local label = buff.displayName or detected
    local key = tostring(detected)
    local name = "FlashClassCB_"..playerClass.."_"..i

    local rowY = CLASS_ROW_START_Y - ((i - 1) * CLASS_ROW_SPACING)
    local inputRowY = rowY + CLASS_INPUT_Y_OFFSET

    local cb = MakeCheckButton_Global(name, container, CLASS_COL_LABEL_X, rowY, label, "GameFontNormal")

    Flash.config = Flash.config or {}
    Flash.config.trackedSpells = Flash.config.trackedSpells or {}
    if Flash.config.trackedSpells[key] == nil then Flash.config.trackedSpells[key] = false end
    cb:SetChecked(Flash.config.trackedSpells[key])
    cb:SetScript("OnClick", function()
        local checked = cb:GetChecked() and true or false
        Flash.config.trackedSpells[key] = checked
        if not checked and Flash.alerted then Flash.alerted[key] = nil end
    end)

    Flash.config.trackedSpellsInCombat = Flash.config.trackedSpellsInCombat or {}
    local cbCombatName = name.."_InCombat"
    local cbCombat = MakeCheckButton_Global(cbCombatName, container, CLASS_COL_COMBAT_X, rowY, "In Combat", "GameFontNormalSmall")
    if Flash.config.trackedSpellsInCombat[key] == nil then Flash.config.trackedSpellsInCombat[key] = false end
    cbCombat:SetChecked(Flash.config.trackedSpellsInCombat[key])
    cbCombat:SetScript("OnClick", function()
        local checked = cbCombat:GetChecked() and true or false
        Flash.config.trackedSpellsInCombat[key] = checked
    end)

    Flash.config.buffIconSizes = Flash.config.buffIconSizes or {}
        if Flash.config.buffIconSizes[key] == nil then Flash.config.buffIconSizes[key] = 60 end
    local sizeName = name.."_Size"
    local sizeBox = MakeEditBox_Global(sizeName, container, CLASS_COL_SIZE_X, inputRowY)
    sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 60))

    Flash.config.buffIcons = Flash.config.buffIcons or {}
    local savedOffsets = Flash.config.buffIcons[key]
    local info = Flash.buffIcons and Flash.buffIcons[key]
    local curX = (info and info.xOffset) or (savedOffsets and tonumber(savedOffsets.x)) or 300
    local curY = (info and info.yOffset) or (savedOffsets and tonumber(savedOffsets.y)) or 200

    local xName = name.."_X"
    local yName = name.."_Y"
    local xBox = MakeEditBox_Global(xName, container, CLASS_COL_X_X, inputRowY)
    xBox:SetText(tostring(curX))
    local yBox = MakeEditBox_Global(yName, container, CLASS_COL_Y_X, inputRowY)
    yBox:SetText(tostring(curY))

    local function applyXYFromBox()
        local nx = tonumber(xBox:GetText() or "")
        local ny = tonumber(yBox:GetText() or "")
        if not nx or not ny then
            xBox:SetText(tostring(curX))
            yBox:SetText(tostring(curY))
            xBox:ClearFocus()
            yBox:ClearFocus()
            return
        end
        UpdateBuffXY_Global(key, nx, ny)
        xBox:SetText(tostring(math.floor(nx + 0.5)))
        yBox:SetText(tostring(math.floor(ny + 0.5)))
    end
    xBox:SetScript("OnEnterPressed", function() applyXYFromBox(); xBox:ClearFocus() end)
    xBox:SetScript("OnEscapePressed", function() xBox:SetText(tostring(curX)); xBox:ClearFocus() end)
    xBox:SetScript("OnEditFocusLost", function() applyXYFromBox() end)
    yBox:SetScript("OnEnterPressed", function() applyXYFromBox(); yBox:ClearFocus() end)
    yBox:SetScript("OnEscapePressed", function() yBox:SetText(tostring(curY)); yBox:ClearFocus() end)
    yBox:SetScript("OnEditFocusLost", function() applyXYFromBox() end)

    local function applySizeFromBox()
        local val = tonumber(sizeBox:GetText() or "")
        if not val then
                        sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 60))
            sizeBox:ClearFocus()
            return
        end
        UpdateBuffSize_Global(key, val)
        sizeBox:SetText(tostring(math.floor(val + 0.5)))
    end
    sizeBox:SetScript("OnEnterPressed", function() applySizeFromBox(); sizeBox:ClearFocus() end)
    sizeBox:SetScript("OnEscapePressed", function() sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 60)); sizeBox:ClearFocus() end)
    sizeBox:SetScript("OnEditFocusLost", function() applySizeFromBox() end)

    table.insert(FlashOptionsMenu._classCheckboxes, cb)
    table.insert(FlashOptionsMenu._classCheckboxes, cbCombat)
    table.insert(FlashOptionsMenu._classCheckboxes, sizeBox)
end

local function BuildClassCheckboxes()
    -- prepare container frame for class checkboxes
    if not FlashOptionsMenu._classContainer then
        local cont = CreateFrame("Frame", nil, FlashOptionsMenu)
        cont:SetWidth(380)
        cont:SetHeight(300)
        -- align container under the sound label and nudge right so it sits inside the frame
        cont:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", CLASS_SECTION_OFFSET_X, CLASS_SECTION_OFFSET_Y)
        cont:Show()
        -- no background texture so container matches the rest of the options frame
        FlashOptionsMenu._classContainer = cont
    end
    local container = FlashOptionsMenu._classContainer

    -- If a container was created earlier (for example by the fallback builder),
    -- reposition it relative to the dropdown so it lines up with the sound control
    -- and sits inside the dialog frame.
    if container and soundLabel then
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", CLASS_SECTION_OFFSET_X, CLASS_SECTION_OFFSET_Y)
        container:SetParent(FlashOptionsMenu)
        container:Show()
    end

    -- hide previous checkboxes so we can reuse them; do NOT SetParent(nil)
    if FlashOptionsMenu._classCheckboxes then
        for _, cb in ipairs(FlashOptionsMenu._classCheckboxes) do
            if cb and cb.Hide then cb:Hide() end
        end
    end
    FlashOptionsMenu._classCheckboxes = {}

    -- Stop if class data is missing
    if not Flash or not Flash.classBuffs then
        return
    end

    -- Determine current player class
    local _, playerClass = UnitClass("player")
    playerClass = string.upper(playerClass or "")
    local classBuffs = Flash.classBuffs[playerClass] or {}

    -- count entries without using #
    local cnt = 0
    for _ in ipairs(classBuffs) do cnt = cnt + 1 end
    if cnt == 0 then
        -- clear any existing title
        if container._title then container._title:SetText("") end
        return
    end

    -- section header above the class buff checkbox area
    if not container._sectionHeader then
        local h = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        container._sectionHeader = h
    end
    container._sectionHeader:ClearAllPoints()
    container._sectionHeader:SetPoint("TOPLEFT", container, "TOPLEFT", CLASS_BUFF_HEADER_X, CLASS_HEADER_Y)
    container._sectionHeader:SetText("Buffs to Track")

    if container._title then
        container._title:SetText("")
    end

    -- Right column header for size edit boxes
    if not container._sizeHeader then
        local sh = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        container._sizeHeader = sh
    end
    container._sizeHeader:ClearAllPoints()
    container._sizeHeader:SetPoint("TOP", container, "TOPLEFT", CLASS_HEADER_SIZE_CENTER_X, CLASS_HEADER_Y)
    container._sizeHeader:SetText("Size")

    -- X/Y headers so users can edit icon offsets directly (pixels from screen center)
    if not container._xHeader then
        local xh = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        container._xHeader = xh
    end
    container._xHeader:ClearAllPoints()
    container._xHeader:SetPoint("TOP", container, "TOPLEFT", CLASS_HEADER_X_CENTER_X, CLASS_HEADER_Y)
    container._xHeader:SetText("X")
    if not container._yHeader then
        local yh = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        container._yHeader = yh
    end
    container._yHeader:ClearAllPoints()
    container._yHeader:SetPoint("TOP", container, "TOPLEFT", CLASS_HEADER_Y_CENTER_X, CLASS_HEADER_Y)
    container._yHeader:SetText("Y")

    -- Helpers reused for every row: define once to avoid per-row allocations
    local function MakeCheckButton(btnName, parentFrame, xOffset, yOffset, labelText, fontObject)
            if Flash and Flash.UI and type(Flash.UI.MakeCheckButton) == "function" then
                return Flash.UI.MakeCheckButton(btnName, parentFrame, xOffset, yOffset, labelText, fontObject)
            end
            if Flash and type(Flash.DebugError) == "function" then
                Flash.DebugError("UI helper Flash.UI.MakeCheckButton missing, using inline implementation")
            end
        local btn = _G[btnName]
        if btn and type(btn) == "table" then
            btn:SetParent(parentFrame)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
            btn:Show()
        else
            btn = CreateFrame("CheckButton", btnName, parentFrame, "UICheckButtonTemplate")
            btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
            btn:Show()
        end
        local lbl = _G[btnName.."Text"]
        if lbl then
            if fontObject and lbl.SetFontObject then lbl:SetFontObject(fontObject) end
            lbl:SetTextColor(1, 0.82, 0)
            if labelText then lbl:SetText(labelText) end
        end
        return btn
    end

    local function MakeEditBox(boxName, parentFrame, xOffset, yOffset, width, height)
        if Flash and Flash.UI and type(Flash.UI.MakeEditBox) == "function" then
            return Flash.UI.MakeEditBox(boxName, parentFrame, xOffset, yOffset, width, height)
        end
        if Flash and type(Flash.DebugError) == "function" then
            Flash.DebugError("UI helper Flash.UI.MakeEditBox missing, using inline implementation")
        end
        local eb = _G[boxName]
        if eb and type(eb) == "table" then
            eb:SetParent(parentFrame)
            eb:ClearAllPoints()
            eb:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
            eb:Show()
        else
            eb = CreateFrame("EditBox", boxName, parentFrame)
            eb:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, yOffset)
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
        if eb.SetFrameLevel and parentFrame.GetFrameLevel then
            eb:SetFrameLevel((parentFrame:GetFrameLevel() or 1) + 3)
        end
        if eb.SetFrameStrata then
            local opts = _G["FlashOptionsMenu"]
            if opts and opts.GetFrameStrata then eb:SetFrameStrata(opts:GetFrameStrata()) end
        end
        return eb
    end

    -- Shared update helpers to reduce per-row duplication
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

    -- Central row builder to assemble controls and hook scripts for a single buff
    -- Note: when Flash.UI helpers are absent the inline implementations above
    -- will be used and a `Flash.DebugError()` will be emitted so the missing
    -- dependency is visible in chat/logs. Follow the Rules header at the top
    -- of this file when making edits.
    local function BuildRow(i, buff)
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local label = buff.displayName or detected
        local key = tostring(detected)

        local name = "FlashClassCB_"..playerClass.."_"..i

        local rowY = CLASS_ROW_START_Y - ((i - 1) * CLASS_ROW_SPACING)
        local inputRowY = rowY + CLASS_INPUT_Y_OFFSET

        local cb = MakeCheckButton(name, container, CLASS_COL_LABEL_X, rowY, label, "GameFontNormal")

        -- Default to not tracking a buff unless the user explicitly enables it
        Flash.config = Flash.config or {}
        Flash.config.trackedSpells = Flash.config.trackedSpells or {}
        if Flash.config.trackedSpells[key] == nil then Flash.config.trackedSpells[key] = false end
        cb:SetChecked(Flash.config.trackedSpells[key])

        -- Update tracked state on click
        cb:SetScript("OnClick", function()
            local checked = cb:GetChecked() and true or false
            Flash.config.trackedSpells[key] = checked
            if not checked and Flash.alerted then Flash.alerted[key] = nil end
        end)

        -- In-Combat-only checkbox (to the right of the main checkbox)
        Flash.config.trackedSpellsInCombat = Flash.config.trackedSpellsInCombat or {}
        local cbCombatName = name.."_InCombat"
        local cbCombat = MakeCheckButton(cbCombatName, container, CLASS_COL_COMBAT_X, rowY, "In Combat", "GameFontNormalSmall")
        if Flash.config.trackedSpellsInCombat[key] == nil then Flash.config.trackedSpellsInCombat[key] = false end
        cbCombat:SetChecked(Flash.config.trackedSpellsInCombat[key])
        cbCombat:SetScript("OnClick", function()
            local checked = cbCombat:GetChecked() and true or false
            Flash.config.trackedSpellsInCombat[key] = checked
        end)

        -- Icon size edit box (far right)
        Flash.config.buffIconSizes = Flash.config.buffIconSizes or {}
        if Flash.config.buffIconSizes[key] == nil then Flash.config.buffIconSizes[key] = 60 end
        local sizeName = name.."_Size"
        local sizeBox = MakeEditBox(sizeName, container, CLASS_COL_SIZE_X, inputRowY)
        sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 60))

        -- X and Y edit boxes: show current offsets and allow numeric entry to move icons
        local xName = name.."_X"
        local yName = name.."_Y"
        -- try to get existing saved offsets
        Flash.config.buffIcons = Flash.config.buffIcons or {}
        local savedOffsets = Flash.config.buffIcons[key]
        local info = Flash.buffIcons and Flash.buffIcons[key]
        local curX = (info and info.xOffset) or (savedOffsets and tonumber(savedOffsets.x)) or 300
        local curY = (info and info.yOffset) or (savedOffsets and tonumber(savedOffsets.y)) or 200

        local xBox = MakeEditBox(xName, container, CLASS_COL_X_X, inputRowY)
        xBox:SetText(tostring(curX))

        local yBox = MakeEditBox(yName, container, CLASS_COL_Y_X, inputRowY)
        yBox:SetText(tostring(curY))

        local function applyXYFromBox()
            local nx = tonumber(xBox:GetText() or "")
            local ny = tonumber(yBox:GetText() or "")
            if not nx or not ny then
                xBox:SetText(tostring(curX))
                yBox:SetText(tostring(curY))
                xBox:ClearFocus()
                yBox:ClearFocus()
                return
            end
            UpdateBuffXY(key, nx, ny)
            xBox:SetText(tostring(math.floor(nx + 0.5)))
            yBox:SetText(tostring(math.floor(ny + 0.5)))
        end

        xBox:SetScript("OnEnterPressed", function() applyXYFromBox(); xBox:ClearFocus() end)
        xBox:SetScript("OnEscapePressed", function()
            xBox:SetText(tostring(curX))
            xBox:ClearFocus()
        end)
        xBox:SetScript("OnEditFocusLost", function() applyXYFromBox() end)

        yBox:SetScript("OnEnterPressed", function() applyXYFromBox(); yBox:ClearFocus() end)
        yBox:SetScript("OnEscapePressed", function()
            yBox:SetText(tostring(curY))
            yBox:ClearFocus()
        end)
        yBox:SetScript("OnEditFocusLost", function() applyXYFromBox() end)

        -- Apply and clamp size values on commit
        local function applySizeFromBox()
            local val = tonumber(sizeBox:GetText() or "")
            if not val then
                sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 60))
                sizeBox:ClearFocus()
                return
            end
            UpdateBuffSize(key, val)
            sizeBox:SetText(tostring(math.floor(val + 0.5)))
        end

        sizeBox:SetScript("OnEnterPressed", function() applySizeFromBox(); sizeBox:ClearFocus() end)
        sizeBox:SetScript("OnEscapePressed", function()
            sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 60))
            sizeBox:ClearFocus()
        end)
        sizeBox:SetScript("OnEditFocusLost", function() applySizeFromBox() end)

        -- Store references so we can hide/reuse them later
        table.insert(FlashOptionsMenu._classCheckboxes, cb)
        table.insert(FlashOptionsMenu._classCheckboxes, cbCombat)
        table.insert(FlashOptionsMenu._classCheckboxes, sizeBox)
    end

    for i, buff in ipairs(classBuffs) do
        BuildRow(i, buff)
    end
end

-- Safe wrapper and hook
local function SafeBuildClassCheckboxes()
    if type(BuildClassCheckboxes) ~= "function" then return end

    -- Keep sound selector display in sync with saved config when opening menu.
    pcall(SyncSoundControlSelection)

    -- Cache class for icon frame creation
    local _, pclass = UnitClass("player")
    pclass = string.upper(pclass or "")

    -- Build UI and show icon frames while the menu is open
    pcall(BuildClassCheckboxes)
    if Flash and type(Flash.EnsureBuffIconFrames) == "function" then
        pcall(function()
            Flash.EnsureBuffIconFrames(pclass)
            if type(Flash.ShowAllBuffIcons) == "function" then Flash.ShowAllBuffIcons() end
            if type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
        end)
    end
end

-- Hook menu show/hide to rebuild controls and restore icon visibility
if FlashOptionsMenu and type(FlashOptionsMenu.HookScript) == "function" then
    FlashOptionsMenu:HookScript("OnShow", SafeBuildClassCheckboxes)
    FlashOptionsMenu:HookScript("OnHide", function()
        local _, pclass = UnitClass("player")
        pclass = string.upper(pclass or "")
        if Flash and type(Flash.UpdateVisibilityBasedOnBuffs) == "function" then
            pcall(function() Flash.UpdateVisibilityBasedOnBuffs(pclass) end)
            if type(Flash.UpdateIconPosition) == "function" then pcall(Flash.UpdateIconPosition) end
        end
    end)
else
    FlashOptionsMenu:SetScript("OnShow", SafeBuildClassCheckboxes)
end

Flash.BuildClassCheckboxes = BuildClassCheckboxes
if not _G["FlashMenu_BuildClassCheckboxes"] then
    _G["FlashMenu_BuildClassCheckboxes"] = BuildClassCheckboxes
end
Flash.menuLoaded = "builder"

Flash.menuLoaded = "end"

-- end of Flash menu module
