-- FlashMenu.lua - options UI for the Flash addon
--
-- Detailed description:
-- This module constructs the options window named `FlashOptionsMenu` and
-- exposes one primary area of user interaction:
--   1) Alert Sound selection: a dropdown (or fallback button) that lets the
--      user choose a sound file to be played when a tracked buff is missing.
--      The special value "(None)" disables sound playback while keeping
--      icon notifications active.
--   2) Buffs to Track: a list of per-class entries where each row contains:
--      - a checkbox to enable/disable tracking of that buff
--      - an "In Combat" checkbox to limit notifications to combat
--      - a size edit box that controls the pixel size of the missing-buff icon
--
-- Saved configuration keys used by this UI (in `Flash.config` per-character):
--   - selectedSound : string path to selected sound file, or empty string for None
--   - _soundIndex   : numeric index (0 for None, 1..N for sound list) used by fallback
--   - trackedSpells : table keyed by buff detection key -> boolean
--   - trackedSpellsInCombat : table keyed by buff detection key -> boolean
--   - buffIconSizes : table keyed by buff detection key -> number (pixels)
--
-- The menu keeps the UI minimal: a sound control, the buff list (checkboxes + size),
-- and a single Done button. Legacy or unused controls (sliders, extra buttons) have
-- been removed to simplify the dialog.

-- Create the options window frame
FlashOptionsMenu = CreateFrame("Frame", "FlashOptionsMenu", UIParent)
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

-- Allow the user to drag the window around
FlashOptionsMenu:EnableMouse(true)
FlashOptionsMenu:SetMovable(true)
FlashOptionsMenu:RegisterForDrag("LeftButton")
FlashOptionsMenu:SetScript("OnDragStart", function() FlashOptionsMenu:StartMoving() end)
FlashOptionsMenu:SetScript("OnDragStop", function() FlashOptionsMenu:StopMovingOrSizing() end)

-- Hide by default and make it close on Escape
FlashOptionsMenu:Hide()
tinsert(UISpecialFrames, "FlashOptionsMenu")

-- Add a persistent bottom button early so it exists even if later code aborts
if not FlashOptionsMenu._closeButton then
    local doneBtn = CreateFrame("Button", "Flash_CloseButton", FlashOptionsMenu, "UIPanelButtonTemplate2")
    if not doneBtn then
        doneBtn = CreateFrame("Button", "Flash_CloseButton", FlashOptionsMenu, "UIPanelButtonTemplate")
    end
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
end

-- Main title text for the options window
local title = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
title:SetPoint("TOP", 0, -16)
title:SetText("Flash Options")

-- Top-right close (standard UIPanelCloseButton)
-- no top-right close; use bottom-center Exit button instead

---------------------------------------------------------
-- SOUND DROPDOWN
---------------------------------------------------------
-- Label for the sound control
local soundLabel = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soundLabel:SetPoint("TOPLEFT", 20, -40)
soundLabel:SetText("Alert Sound:")

-- Dropdown frame reference
local dropdown = nil

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
        local fullPath = "Interface\\AddOns\\Flash\\Media\\" .. sound
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
            UIDropDownMenu_SetSelectedID(dropdown, thisPos)
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
    UIDropDownMenu_SetSelectedID(dropdown, selectedID)
end

-- Initialize the dropdown only if the UIDropDownMenu API is present; otherwise create a safe fallback button
if type(UIDropDownMenu_Initialize) == "function" and type(UIDropDownMenu_SetWidth) == "function" and type(UIDropDownMenu_CreateInfo) == "function" then
    dropdown = CreateFrame("Frame", "FlashSoundDropdown", FlashOptionsMenu, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_Initialize(dropdown, Dropdown_Initialize)
    UIDropDownMenu_SetWidth(dropdown, 180)
else
    -- Hide any existing dropdown and create a simple button that cycles sounds
    if dropdown and dropdown.GetObjectType and dropdown:GetObjectType() == "Frame" then
        dropdown:Hide()
    end
    local fb = CreateFrame("Button", "FlashSoundFallbackButton", FlashOptionsMenu, "UIPanelButtonTemplate")
    fb:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -5)
    fb:SetSize(180, 24)
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
            local fullPath = "Interface\\AddOns\\Flash\\Media\\" .. sound
            Flash.config.selectedSound = fullPath
            pcall(PlaySoundFile, fullPath)
        end
        updateFB()
    end)
    updateFB()
end


---------------------------------------------------------
-- Build class-specific checkboxes (local, safe)
---------------------------------------------------------
local function BuildClassCheckboxes()
    -- prepare container frame for class checkboxes
    if not FlashOptionsMenu._classContainer then
        local cont = CreateFrame("Frame", "FlashClassContainer", FlashOptionsMenu)
        cont:SetWidth(380)
        cont:SetHeight(320)
        -- align container under the sound label and nudge right so it sits inside the frame
        cont:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 16, -12)
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
        container:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 16, -12)
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

    -- title for the container: anchor directly to the sound label for exact alignment
    if not container._title then
        local t = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 24, -6)
        container._title = t
    end
    container._title:SetText("Buffs to Track")

    -- Right column header for size edit boxes
    if not container._sizeHeader then
        local sh = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sh:SetPoint("TOPLEFT", container, "TOPLEFT", 320, -10)
        container._sizeHeader = sh
    end
    container._sizeHeader:SetText("Size")

    -- X/Y headers so users can edit icon offsets directly (pixels from screen center)
    if not container._xHeader then
        local xh = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        xh:SetPoint("TOPLEFT", container, "TOPLEFT", 380, -10)
        container._xHeader = xh
    end
    container._xHeader:SetText("X")
    if not container._yHeader then
        local yh = FlashOptionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        yh:SetPoint("TOPLEFT", container, "TOPLEFT", 440, -10)
        container._yHeader = yh
    end
    container._yHeader:SetText("Y")

    -- Build one row of controls per buff
    for i, buff in ipairs(classBuffs) do
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local label = buff.displayName or detected
        local key = tostring(detected)

        local name = "FlashClassCB_"..playerClass.."_"..i
        local cb = _G[name]
        if cb and type(cb) == "table" then
            cb:SetParent(container)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -28 - ((i - 1) * 26))
            cb:Show()
        else
            cb = CreateFrame("CheckButton", name, container, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -28 - ((i - 1) * 26))
            cb:Show()
        end

        -- Style the label text
        local txt = _G[name.."Text"]
        if txt then
            txt:SetFontObject("GameFontNormal")
            txt:SetTextColor(1, 0.82, 0)
            txt:SetText(label)
        end

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
        local cbCombat = _G[cbCombatName]
        if cbCombat and type(cbCombat) == "table" then
            cbCombat:SetParent(container)
            cbCombat:ClearAllPoints()
            cbCombat:SetPoint("TOPLEFT", container, "TOPLEFT", 220, -28 - ((i - 1) * 26))
            cbCombat:Show()
        else
            cbCombat = CreateFrame("CheckButton", cbCombatName, container, "UICheckButtonTemplate")
            cbCombat:SetPoint("TOPLEFT", container, "TOPLEFT", 220, -28 - ((i - 1) * 26))
            cbCombat:Show()
        end

        -- Label for the in-combat toggle
        local txtCombat = _G[cbCombatName.."Text"]
        if txtCombat then
            txtCombat:SetFontObject("GameFontNormalSmall")
            txtCombat:SetTextColor(1, 0.82, 0)
            txtCombat:SetText("In Combat")
        end
        if Flash.config.trackedSpellsInCombat[key] == nil then Flash.config.trackedSpellsInCombat[key] = false end
        cbCombat:SetChecked(Flash.config.trackedSpellsInCombat[key])
        cbCombat:SetScript("OnClick", function()
            local checked = cbCombat:GetChecked() and true or false
            Flash.config.trackedSpellsInCombat[key] = checked
        end)

        -- Icon size edit box (far right)
        Flash.config.buffIconSizes = Flash.config.buffIconSizes or {}
        if Flash.config.buffIconSizes[key] == nil then Flash.config.buffIconSizes[key] = 40 end
        local sizeName = name.."_Size"
        local sizeBox = _G[sizeName]
        if sizeBox and type(sizeBox) == "table" then
            sizeBox:SetParent(container)
            sizeBox:ClearAllPoints()
            sizeBox:SetPoint("TOPLEFT", container, "TOPLEFT", 320, -30 - ((i - 1) * 26))
            sizeBox:Show()
        else
            sizeBox = CreateFrame("EditBox", sizeName, container)
            sizeBox:SetPoint("TOPLEFT", container, "TOPLEFT", 320, -30 - ((i - 1) * 26))
            sizeBox:SetWidth(52)
            sizeBox:SetHeight(24)
            sizeBox:SetAutoFocus(false)
            sizeBox:Show()
        end
        if sizeBox.SetFontObject then sizeBox:SetFontObject("GameFontNormal") end
        if sizeBox.SetTextInsets then sizeBox:SetTextInsets(6, 6, 3, 2) end
        if sizeBox.SetJustifyH then sizeBox:SetJustifyH("CENTER") end
        if sizeBox.SetBackdrop then
            sizeBox:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true, tileSize = 16,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            sizeBox:SetBackdropColor(0, 0, 0, 0.5)
        end
        if sizeBox.SetFrameLevel and container.GetFrameLevel then
            sizeBox:SetFrameLevel((container:GetFrameLevel() or 1) + 3)
        end
        if sizeBox.SetFrameStrata and FlashOptionsMenu and FlashOptionsMenu.GetFrameStrata then
            sizeBox:SetFrameStrata(FlashOptionsMenu:GetFrameStrata())
        end
        sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 40))

        -- X and Y edit boxes: show current offsets and allow numeric entry to move icons
        local xName = name.."_X"
        local yName = name.."_Y"
        local xBox = _G[xName]
        local yBox = _G[yName]
        -- try to get existing saved offsets
        Flash.config.buffIcons = Flash.config.buffIcons or {}
        local savedOffsets = Flash.config.buffIcons[key]
        local info = Flash.buffIcons and Flash.buffIcons[key]
        local curX = (info and info.xOffset) or (savedOffsets and tonumber(savedOffsets.x)) or 0
        local curY = (info and info.yOffset) or (savedOffsets and tonumber(savedOffsets.y)) or 0

        if xBox and type(xBox) == "table" then
            xBox:SetParent(container)
            xBox:ClearAllPoints()
            xBox:SetPoint("TOPLEFT", container, "TOPLEFT", 380, -30 - ((i - 1) * 26))
            xBox:Show()
        else
            xBox = CreateFrame("EditBox", xName, container)
            xBox:SetPoint("TOPLEFT", container, "TOPLEFT", 380, -30 - ((i - 1) * 26))
            xBox:SetWidth(52)
            xBox:SetHeight(24)
            xBox:SetAutoFocus(false)
            xBox:Show()
        end
        if xBox.SetFontObject then xBox:SetFontObject("GameFontNormal") end
        if xBox.SetTextInsets then xBox:SetTextInsets(6, 6, 3, 2) end
        if xBox.SetJustifyH then xBox:SetJustifyH("CENTER") end
        if xBox.SetBackdrop then
            xBox:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true, tileSize = 16,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            xBox:SetBackdropColor(0, 0, 0, 0.5)
        end
        xBox:SetText(tostring(curX))

        if yBox and type(yBox) == "table" then
            yBox:SetParent(container)
            yBox:ClearAllPoints()
            yBox:SetPoint("TOPLEFT", container, "TOPLEFT", 440, -30 - ((i - 1) * 26))
            yBox:Show()
        else
            yBox = CreateFrame("EditBox", yName, container)
            yBox:SetPoint("TOPLEFT", container, "TOPLEFT", 440, -30 - ((i - 1) * 26))
            yBox:SetWidth(52)
            yBox:SetHeight(24)
            yBox:SetAutoFocus(false)
            yBox:Show()
        end
        if yBox.SetFontObject then yBox:SetFontObject("GameFontNormal") end
        if yBox.SetTextInsets then yBox:SetTextInsets(6, 6, 3, 2) end
        if yBox.SetJustifyH then yBox:SetJustifyH("CENTER") end
        if yBox.SetBackdrop then
            yBox:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true, tileSize = 16,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            yBox:SetBackdropColor(0, 0, 0, 0.5)
        end
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
            nx = math.floor(nx + 0.5)
            ny = math.floor(ny + 0.5)
            Flash.config = Flash.config or {}
            Flash.config.buffIcons = Flash.config.buffIcons or {}
            Flash.config.buffIcons[key] = { x = nx, y = ny }
            Flash.buffIcons = Flash.buffIcons or {}
            Flash.buffIcons[key] = Flash.buffIcons[key] or {}
            Flash.buffIcons[key].xOffset = nx
            Flash.buffIcons[key].yOffset = ny
            if Flash and type(Flash.UpdateIconPosition) == "function" then
                Flash.UpdateIconPosition()
            end
            xBox:SetText(tostring(nx))
            yBox:SetText(tostring(ny))
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
                sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 40))
                sizeBox:ClearFocus()
                return
            end
            val = math.floor(val + 0.5)
            if val < 8 then val = 8 end
            if val > 128 then val = 128 end
            if Flash and type(Flash.ApplyBuffIconSize) == "function" then
                Flash.ApplyBuffIconSize(key, val)
            else
                Flash.config.buffIconSizes[key] = val
            end
            sizeBox:SetText(tostring(val))
            if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
        end

        sizeBox:SetScript("OnEnterPressed", function() applySizeFromBox(); sizeBox:ClearFocus() end)
        sizeBox:SetScript("OnEscapePressed", function()
            sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 40))
            sizeBox:ClearFocus()
        end)
        sizeBox:SetScript("OnEditFocusLost", function() applySizeFromBox() end)

        -- Store references so we can hide/reuse them later
        table.insert(FlashOptionsMenu._classCheckboxes, cb)
        table.insert(FlashOptionsMenu._classCheckboxes, cbCombat)
        table.insert(FlashOptionsMenu._classCheckboxes, sizeBox)
    end
end

-- Safe wrapper and hook
local function SafeBuildClassCheckboxes()
    if type(BuildClassCheckboxes) ~= "function" then return end

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

_G["FlashMenu_BuildClassCheckboxes"] = BuildClassCheckboxes

-- Updater: refresh X/Y edit boxes from live icon positions every 1 second
-- Removed periodic updater: X/Y boxes are now refreshed on drag-release.

-- end of FlashMenu.lua
