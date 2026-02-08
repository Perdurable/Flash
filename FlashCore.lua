-- Backup of FlashCore.lua as of 2026-02-06
--
-- This file contains the core runtime logic for the Flash addon:
-- - saved-variable configuration bootstrapping
-- - buff tracking logic
-- - per-buff icon frame creation and positioning
-- - sound alerts for missing buffs
-- - event/timer loop and slash command

-- luacheck: globals UnitName UnitClass UnitBuff CreateFrame UIParent PlaySoundFile GetTime DEFAULT_CHAT_FRAME SlashCmdList SLASH_FLASH1 FlashOptionsMenu FLASH
-- Declare UnitBuff as a global for linting tools
UnitBuff = UnitBuff

-- Ensure addon globals exist (supports reloads / partial loads)
Flash = Flash or {}
FlashCharacterConfig = FlashCharacterConfig or {}
Flash.config = Flash.config or {}

-- Cache player name and class for quick access
local playerName = UnitName("player")
local _, class = UnitClass("player")
class = string.upper(class)

-- Normalize config fields so other code can assume valid types
local function ApplyConfigDefaults(cfg)
    -- Sanitize expected config fields so corrupted savedvars don't break arithmetic or table accesses
    cfg.iconPosX = tonumber(cfg.iconPosX) or 0
    cfg.iconPosY = tonumber(cfg.iconPosY) or 0
    cfg.selectedSound = tostring(cfg.selectedSound or "Interface\\AddOns\\Flash\\Media\\Alarm.ogg")
    if type(cfg.soundAlertEnabled) ~= "boolean" then cfg.soundAlertEnabled = true end
    if type(cfg.iconEnabled) ~= "boolean" then cfg.iconEnabled = true end
    if type(cfg.trackingEnabled) ~= "boolean" then cfg.trackingEnabled = true end
    cfg.trackedSpells = (type(cfg.trackedSpells) == "table") and cfg.trackedSpells or {}
    cfg.trackedSpellsInCombat = (type(cfg.trackedSpellsInCombat) == "table") and cfg.trackedSpellsInCombat or {}
    cfg.buffIcons = (type(cfg.buffIcons) == "table") and cfg.buffIcons or {}
    cfg.buffIconSizes = (type(cfg.buffIconSizes) == "table") and cfg.buffIconSizes or {}
    cfg._soundIndex = tonumber(cfg._soundIndex) or 1
    cfg.debugMode = cfg.debugMode and true or false
end

-- Load or create per-character config and merge with any legacy defaults
local function EnsureConfig()
    local pname = UnitName("player")
    if not pname or pname == "" then return end

    -- Create a new config table if none exists for this character
    local cfg = FlashCharacterConfig[pname]
    if type(cfg) ~= "table" then
        cfg = {
            iconPosX = 0,
            iconPosY = 0,
            selectedSound = "Interface\\AddOns\\Flash\\Media\\Alarm.ogg",
            soundAlertEnabled = true,
            iconEnabled = true,
            trackingEnabled = true,
            trackedSpells = {},
            trackedSpellsInCombat = {},
            buffIcons = {},
            buffIconSizes = {}
        }
        FlashCharacterConfig[pname] = cfg
    end

    -- Merge any previously stored Flash.config keys into the per-character table
    if Flash.config ~= cfg and type(Flash.config) == "table" then
        for k, v in pairs(Flash.config) do
            if cfg[k] == nil then cfg[k] = v end
        end
    end

    -- Bind the global config reference and normalize values
    Flash.config = cfg
    ApplyConfigDefaults(Flash.config)
end

-- Try to bind saved variables early; will rebind on PLAYER_LOGIN
EnsureConfig()

-- Ensure class spells table exists (class files will populate this)
Flash.classSpells = Flash.classSpells or {}

-- Track which missing buffs we already alerted on (so sound plays once)
Flash.alerted = Flash.alerted or {}

-- List of available sound files for the menu
Flash.soundFiles = {
    "Alarm.ogg","Alien.ogg","Bell.ogg","Clock.ogg","Dink.ogg","Dink2.ogg",
    "Electronic.ogg","FF7.ogg","MGS.ogg","MGS2.ogg","NefarianDropped.ogg",
    "OnyxiaDropped.ogg","Pop.ogg","Pop2.ogg","RendDropped.ogg","WT.ogg",
    "ZandalarDropped.ogg","Zelda.ogg"
}

-- Clamp per-buff icon sizes to a safe range
local function ClampIconSize(size)
    local s = tonumber(size) or 40
    if s < 8 then s = 8 end
    if s > 128 then s = 128 end
    return s
end

-- Read stored icon size for a specific buff key
local function GetBuffIconSize(key)
    Flash.config = Flash.config or {}
    Flash.config.buffIconSizes = Flash.config.buffIconSizes or {}
    return ClampIconSize(Flash.config.buffIconSizes[key])
end

-- Update stored icon size and apply it to the active frame
local function ApplyBuffIconSize(key, size)
    if not key then return end
    local s = ClampIconSize(size)
    Flash.config = Flash.config or {}
    Flash.config.buffIconSizes = Flash.config.buffIconSizes or {}
    Flash.config.buffIconSizes[key] = s
    local info = Flash.buffIcons and Flash.buffIcons[key]
    if info and info.frame then
        if info.frame.SetWidth then info.frame:SetWidth(s) end
        if info.frame.SetHeight then info.frame:SetHeight(s) end
    end
end

-- Expose for menu edit boxes
Flash.ApplyBuffIconSize = ApplyBuffIconSize

-- ICON FRAME (created on PLAYER_LOGIN)

-- Load class buff entries populated by class files (Flash.classBuffs)
local function LoadClassBuffs()
    local _, playerClass = UnitClass("player")
    if not playerClass then
        Flash.classBuffs = {}
        return
    end

    -- Ensure the per-class table exists, preserving any existing entries
    playerClass = string.upper(playerClass)
    Flash.classBuffs = Flash.classBuffs or {}
    Flash.classBuffs[playerClass] = Flash.classBuffs[playerClass] or {}
end

-- Reposition all buff icon frames to their saved offsets
local function UpdateIconPosition()
    -- position all buff icon frames using stored offsets
    if not Flash.buffIcons then return end
    local cx, cy = UIParent:GetCenter()
    for key, info in pairs(Flash.buffIcons) do
        local f = info.frame
        if f and f.ClearAllPoints then
            f:ClearAllPoints()
            local ox = (info.xOffset ~= nil) and info.xOffset or (Flash.config.iconPosX or 0)
            local oy = (info.yOffset ~= nil) and info.yOffset or (Flash.config.iconPosY or 0)
            if cx and cy then
                f:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
            else
                f:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
            end
        end
    end
end

-- Expose for the menu code so sliders can call it
Flash.UpdateIconPosition = UpdateIconPosition

-- Create per-buff icon frames for the current class
local function EnsureBuffIconFrames(playerClass)
    Flash.buffIcons = Flash.buffIcons or {}
    local classBuffs = Flash.classBuffs and Flash.classBuffs[playerClass] or {}

    -- Create a frame per buff; each buff is keyed by its detection path
    for i, buff in ipairs(classBuffs) do
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local key = tostring(detected)

        -- Ensure an entry exists to store per-buff frame and offsets
        if not Flash.buffIcons[key] then
            Flash.buffIcons[key] = { frame = nil, xOffset = nil, yOffset = nil }
        end
        local info = Flash.buffIcons[key]

        if not info.frame then
            -- Build the icon frame and attach a texture
            local f = CreateFrame("Frame", "FlashMissingBuffFrame_"..key, UIParent)
            local size = GetBuffIconSize(key)
            f:SetWidth(size)
            f:SetHeight(size)
            f.texture = f:CreateTexture(nil, "ARTWORK")
            f.texture:SetAllPoints()
            f:Hide()

            -- Enable drag positioning while the options menu is open
            f:EnableMouse(true)
            f:SetMovable(true)
            f:RegisterForDrag("LeftButton")
            f:SetClampedToScreen(true)
            -- Make the icon frame front-most so it can be clicked over other UI layers.
            -- Use a high strata and frame level to ensure visibility and interactivity
            -- even when other frames (dialogs/menus) are shown.
            if f.SetFrameStrata then f:SetFrameStrata("FULLSCREEN_DIALOG") end
            if f.SetFrameLevel then f:SetFrameLevel(200) end
            -- Capture loop locals so closures reference the correct row when invoked later
            local _i = i
            local _key = key
            local _playerClass = playerClass
            f:SetScript("OnDragStart", function()
                if not FlashOptionsMenu or not FlashOptionsMenu:IsShown() then return end
                Flash.isDraggingIcons = true
                f:StartMoving()
            end)
            f:SetScript("OnDragStop", function()
                f:StopMovingOrSizing()
                Flash.isDraggingIcons = false
                local centerX, centerY = f:GetCenter()
                local pcenterX, pcenterY = UIParent:GetCenter()
                if centerX and pcenterX then
                    local ox = math.floor(centerX - pcenterX + 0.5)
                    local oy = math.floor(centerY - pcenterY + 0.5)
                    info.xOffset = ox
                    info.yOffset = oy
                    Flash.config.buffIcons = Flash.config.buffIcons or {}
                    Flash.config.buffIcons[_key] = { x = ox, y = oy }
                    -- Update any visible menu edit boxes immediately so users see new offsets
                    pcall(function()
                        if FlashOptionsMenu and FlashOptionsMenu:IsShown() then
                            -- Try to refresh the specific row if its editboxes exist
                            local classBuffs = Flash.classBuffs and Flash.classBuffs[_playerClass] or {}
                            for j, bb in ipairs(classBuffs) do
                                local detected2 = bb.detectedBuffPath or bb.iconPath or ("buff_"..j)
                                if tostring(detected2) == _key then
                                    local rowName = "FlashClassCB_"..(_playerClass or "").."_"..j
                                    local xBox = _G[rowName.."_X"]
                                    local yBox = _G[rowName.."_Y"]
                                    if xBox and type(xBox) == "table" and not xBox:HasFocus() then
                                        xBox:SetText(tostring(ox))
                                    end
                                    if yBox and type(yBox) == "table" and not yBox:HasFocus() then
                                        yBox:SetText(tostring(oy))
                                    end
                                    break
                                end
                            end
                            -- As a fallback, rebuild the menu rows so saved offsets are reflected
                            local builder = _G["FlashMenu_BuildClassCheckboxes"]
                            if type(builder) == "function" then pcall(builder) end
                        end
                    end)
                    if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
                end
            end)
            info.frame = f

            -- Restore saved offsets if present
            Flash.config.buffIcons = Flash.config.buffIcons or {}
            if Flash.config.buffIcons[key] then
                info.xOffset = tonumber(Flash.config.buffIcons[key].x) or nil
                info.yOffset = tonumber(Flash.config.buffIcons[key].y) or nil
            end
        else
            -- Existing frame: just apply size updates
            local size = GetBuffIconSize(key)
            if info.frame.SetWidth then info.frame:SetWidth(size) end
            if info.frame.SetHeight then info.frame:SetHeight(size) end
            -- Ensure existing frames also have the front-most strata/level applied
            if info.frame.SetFrameStrata then info.frame:SetFrameStrata("FULLSCREEN_DIALOG") end
            if info.frame.SetFrameLevel then info.frame:SetFrameLevel(200) end
        end
    end
end

-- Expose for the menu so it can force frame creation
Flash.EnsureBuffIconFrames = EnsureBuffIconFrames

-- Note: ShowAllBuffIcons is expected to be defined elsewhere; keep the export
Flash.ShowAllBuffIcons = ShowAllBuffIcons

-- Hide all class icon frames (used on menu close and when tracking off)
local function UpdateVisibilityBasedOnBuffs(playerClass)
    -- Hide frames unless the buff is currently missing
    if not Flash.buffIcons then return end
    local classBuffs = Flash.classBuffs and Flash.classBuffs[playerClass] or {}
    for i, buff in ipairs(classBuffs) do
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local key = tostring(detected)
        local info = Flash.buffIcons[key]
        if info and info.frame then
            -- default hide
            info.frame:Hide()
        end
    end
end

Flash.UpdateVisibilityBasedOnBuffs = UpdateVisibilityBasedOnBuffs

-- Helper: scan equipped weapon enchantments by inspecting item tooltip text
local function IsWeaponEnchantedWith(name, slotID)
    if type(name) ~= "string" then return false end

    -- Reuse a hidden tooltip to read enchant text
    Flash._scanTooltip = Flash._scanTooltip or CreateFrame("GameTooltip", "FlashScanTooltip", UIParent, "GameTooltipTemplate")
    local tt = Flash._scanTooltip
    tt:SetOwner(UIParent, "ANCHOR_NONE")

    -- Inspect a single slot for a text match
    local function checkSlot(slot)
        tt:ClearLines()
        tt:SetInventoryItem("player", slot)
        local prefix = tt:GetName()
        for i = 1, 30 do
            local left = _G[prefix .. "TextLeft" .. i]
            if not left then break end
            local txt = left:GetText()
            if txt and string.find(string.lower(txt), string.lower(name), 1, true) then
                return true
            end
        end
        return false
    end

    -- If a slot is given, only scan that slot
    if slotID and tonumber(slotID) then
        return checkSlot(tonumber(slotID))
    end

    -- Otherwise scan main hand (16) and off hand (17)
    if checkSlot(16) then return true end
    if checkSlot(17) then return true end
    return false
end

-- Check whether a specific weapon slot has any known poison/enchant applied
local function IsWeaponSlotHasAnyEnchant(slotID)
    -- Reuse the hidden tooltip for scanning
    Flash._scanTooltip = Flash._scanTooltip or CreateFrame("GameTooltip", "FlashScanTooltip", UIParent, "GameTooltipTemplate")
    local tt = Flash._scanTooltip
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:ClearLines()
    tt:SetInventoryItem("player", slotID)
    local prefix = tt:GetName()

    -- list of common poison/enchant keywords to detect
    local keywords = {
        "instant poison",
        "deadly poison",
        "crippling poison",
        "mind-numbing poison",
        "mind numbing poison",
        "wound poison",
    }

    -- Scan tooltip lines for any keyword
    for i = 1, 30 do
        local left = _G[prefix .. "TextLeft" .. i]
        if not left then break end
        local txt = left:GetText()
        if txt and type(txt) == "string" then
            local lowered = string.lower(txt)
            for _, kw in ipairs(keywords) do
                if string.find(lowered, kw, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

-- Play the configured sound if sound alerts are enabled
local function PlayMissingBuffSound()
    if not Flash.config.soundAlertEnabled then return end
    -- If the user selected the explicit "None" option we store an empty string.
    -- Respect that by not attempting to play a sound when selectedSound is empty.
    local sound = Flash.config and Flash.config.selectedSound
    if not sound or sound == "" then return end
    pcall(PlaySoundFile, sound)
end

-- Core buff check loop for the current class
local function CheckForBuffsForClass(playerClass)
    -- If tracking is disabled, hide everything and clear alert cache
    if not Flash.config.trackingEnabled then
        if Flash.buffIcons then
            for k, info in pairs(Flash.buffIcons) do
                if info.frame and info.frame.Hide then info.frame:Hide() end
            end
        end
        Flash.alerted = {}
        return
    end

    -- If icons are disabled, hide frames but keep tracking state
    if not Flash.config.iconEnabled then
        -- hide all frames
        if Flash.buffIcons then
            for k, info in pairs(Flash.buffIcons) do if info.frame and info.frame.Hide then info.frame:Hide() end end
        end
        return
    end

    -- If the class has no buffs defined, hide frames and exit
    local classBuffs = Flash.classBuffs and Flash.classBuffs[playerClass] or {}
    if not classBuffs or next(classBuffs) == nil then
        if Flash.buffIcons then
            for k, info in pairs(Flash.buffIcons) do if info.frame and info.frame.Hide then info.frame:Hide() end end
        end
        return
    end

    -- Ensure frames exist for this class before trying to show/hide them
    EnsureBuffIconFrames(playerClass)

    -- Iterate each configured class buff and decide whether to alert
    for i, buff in ipairs(classBuffs) do
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local key = tostring(detected)

        -- Respect per-buff tracking settings; skip buffs the user has not enabled
        Flash.config = Flash.config or {}
        Flash.config.trackedSpells = Flash.config.trackedSpells or {}
        if not Flash.config.trackedSpells[key] then
            -- not tracking this buff, ensure icon hidden
            if Flash.buffIcons and Flash.buffIcons[key] and Flash.buffIcons[key].frame then
                Flash.buffIcons[key].frame:Hide()
            end
        else
            -- Start with expected detection data
            local detectName = buff.detectedBuffPath
            local detectTexture = buff.iconPath

            -- Check whether this buff is combat-only and if so enforce it
            Flash.config = Flash.config or {}
            Flash.config.trackedSpellsInCombat = Flash.config.trackedSpellsInCombat or {}
            local inCombatOnly = Flash.config.trackedSpellsInCombat[key] and true or false
            local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")

            -- If this buff is set to show only in combat and we're not in combat, hide and skip notifications
            if inCombatOnly and not inCombat then
                if Flash.buffIcons and Flash.buffIcons[key] and Flash.buffIcons[key].frame then
                    Flash.buffIcons[key].frame:Hide()
                end
                if Flash.alerted then Flash.alerted[key] = nil end
            else
                -- Track whether the player currently has the buff
                local hasBuff = false

                -- If this buff is a weapon enchant, inspect equipped weapon tooltips for the enchant name
                if buff.weapon then
                    local slot = buff.weaponSlot and tonumber(buff.weaponSlot) or nil
                    -- if weaponAny is requested, just check for any known weapon enchant/poison on the slot(s)
                    if buff.weaponAny then
                        if slot then
                            if IsWeaponSlotHasAnyEnchant(slot) then hasBuff = true end
                        else
                            if IsWeaponSlotHasAnyEnchant(16) or IsWeaponSlotHasAnyEnchant(17) then hasBuff = true end
                        end
                    else
                        -- Build a set of probe strings to find the enchant in tooltip text
                        local probes = {}
                        if detectName and type(detectName) == "string" then table.insert(probes, detectName) end
                        if buff.displayName and type(buff.displayName) == "string" then table.insert(probes, buff.displayName) end
                        for _, p in ipairs({detectName, buff.displayName}) do
                            if type(p) == "string" then
                                local lowered = string.lower(p)
                                local stripped = string.gsub(lowered, "%s*weapon%s*$", "")
                                if stripped and stripped ~= lowered then
                                    table.insert(probes, stripped)
                                end
                            end
                        end

                        -- Scan the requested slot(s) for any probe match
                        for _, probe in ipairs(probes) do
                            if slot then
                                if probe and IsWeaponEnchantedWith(probe, slot) then
                                    hasBuff = true
                                    break
                                end
                            else
                                if probe and IsWeaponEnchantedWith(probe) then
                                    hasBuff = true
                                    break
                                end
                            end
                        end
                    end
                else
                    -- Normal buff: scan player buffs (up to 40 slots)
                    for j = 1, 40 do
                        local data = { UnitBuff("player", j) }
                        if not data or type(data) ~= "table" then break end

                        -- Compute how many return values we actually received
                        local dataCount = 0
                        for _ in ipairs(data) do dataCount = dataCount + 1 end
                        if dataCount == 0 then break end

                        -- Compare each returned string against expected names/textures
                        for k = 1, dataCount do
                            local v = data[k]
                            if type(v) == "string" then
                                if detectName and string.find(string.lower(v), string.lower(detectName), 1, true) then
                                    hasBuff = true
                                    break
                                end
                                if detectTexture and string.find(string.lower(v), string.lower(detectTexture), 1, true) then
                                    hasBuff = true
                                    break
                                end
                            end
                        end
                        if hasBuff then break end
                    end
                end

                -- Update per-buff icon visibility and alert state
                local info = Flash.buffIcons and Flash.buffIcons[key]
                if not hasBuff then
                    if info and info.frame then
                        local icon = buff.iconPath or "Interface\\Icons\\INV_Misc_QuestionMark"
                        info.frame.texture:SetTexture(icon)
                        info.frame:Show()
                        UpdateIconPosition()
                        if not Flash.alerted[key] then
                            PlayMissingBuffSound()
                            Flash.alerted[key] = true
                        end
                    else
                        -- no frame: fallback to old behavior if possible
                        if Flash.iconTexture and Flash.iconFrame then
                            local icon = buff.iconPath or "Interface\\Icons\\INV_Misc_QuestionMark"
                            Flash.iconTexture:SetTexture(icon)
                            Flash.iconFrame:Show()
                            UpdateIconPosition()
                            if not Flash.alerted[key] then
                                PlayMissingBuffSound()
                                Flash.alerted[key] = true
                            end
                        end
                    end
                else
                    -- buff present; hide its frame and clear alerted flag
                    if info and info.frame then info.frame:Hide() end
                    Flash.alerted[key] = nil
                end
            end
        end
    end
end

-- Initialize core behavior on login
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    -- Bind config and class info after the player is fully loaded
    EnsureConfig()
    local _, playerClass = UnitClass("player")
    playerClass = string.upper(playerClass or "")

    -- Ensure class buffs are loaded (class files run before core per TOC)
    Flash.classBuffs = Flash.classBuffs or {}
    LoadClassBuffs()

    -- Create per-buff UI icon frames for this class
    if type(EnsureBuffIconFrames) == "function" then
        pcall(function() EnsureBuffIconFrames(playerClass) end)
    end

    -- Periodic check loop, throttled to avoid extra CPU use
    Flash.frame = CreateFrame("Frame")
    Flash.frame.lastCheck = 0
    Flash.frame:SetScript("OnUpdate", function()
        local now = GetTime()
        if Flash.isDraggingIcons then
            Flash.frame.lastCheck = now
            return
        end
        if now - Flash.frame.lastCheck >= 1.0 then
            CheckForBuffsForClass(playerClass)
            Flash.frame.lastCheck = now
        end
    end)

    -- Print a loaded message immediately so the player knows how to configure
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("Flash Loaded, use /flash to configure.", 1.0, 0.4, 0.8)
    end
end)

-- SLASH COMMAND
SLASH_FLASH1 = "/flash"
SlashCmdList["FLASH"] = function()
    -- If the options menu isn't loaded yet, warn and return (menu defined in FlashMenu.lua)
    if not FlashOptionsMenu then
        return
    end
    if FlashOptionsMenu:IsShown() then
        FlashOptionsMenu:Hide()
    else
        -- If the menu code exposes a builder, run it now so class checkboxes are created
        local builder = _G["FlashMenu_BuildClassCheckboxes"]
        if type(builder) == "function" then
            pcall(function()
                builder()
            end)
        end
        FlashOptionsMenu:Show()
    end
end

-- Fallback builder: if the menu file didn't expose a builder, provide one here.
if not _G["FlashMenu_BuildClassCheckboxes"] then
    local function FallbackBuildClassCheckboxes()
        if not FlashOptionsMenu then return end
        FlashOptionsMenu._classContainer = FlashOptionsMenu._classContainer or CreateFrame("Frame", "FlashClassContainer_Fallback", FlashOptionsMenu)
        local container = FlashOptionsMenu._classContainer
        container:SetWidth(380)
        container:SetHeight(300)

        -- prefer anchoring under the sound dropdown if the dropdown exists
        local dropdown = _G["FlashSoundDropdown"]
        if dropdown and dropdown.SetPoint then
            container:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, -12)
        else
            container:SetPoint("TOPRIGHT", FlashOptionsMenu, "TOPRIGHT", -20, -60)
        end

        -- cleanup: hide previous checkboxes so we can reuse them
        if FlashOptionsMenu._classCheckboxes then
            for _, cb in ipairs(FlashOptionsMenu._classCheckboxes) do
                if cb and cb.Hide then cb:Hide() end
            end
        end
        FlashOptionsMenu._classCheckboxes = {}

        if not Flash or not Flash.classBuffs then
            return
        end
        local _, playerClass = UnitClass("player")
        playerClass = string.upper(playerClass or "")
        local classBuffs = Flash.classBuffs[playerClass] or {}
        local cnt = 0
        for _ in ipairs(classBuffs) do cnt = cnt + 1 end
        if cnt == 0 then return end

        -- Container title
        if not container._title then
            local t = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            t:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -6)
            container._title = t
        end
        container._title:SetText("Buffs to Track")

        -- Size column header
        if not container._sizeHeader then
            local sh = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sh:SetPoint("TOPLEFT", container, "TOPLEFT", 300, -10)
            container._sizeHeader = sh
        end
        container._sizeHeader:SetText("Size")
        -- X/Y headers for numeric icon offsets
        if not container._xHeader then
            local xh = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            xh:SetPoint("TOPLEFT", container, "TOPLEFT", 360, -10)
            container._xHeader = xh
        end
        container._xHeader:SetText("X")
        if not container._yHeader then
            local yh = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            yh:SetPoint("TOPLEFT", container, "TOPLEFT", 420, -10)
            container._yHeader = yh
        end
        container._yHeader:SetText("Y")

        -- Build per-buff controls
        for i, buff in ipairs(classBuffs) do
            local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
            local label = buff.displayName or detected
            local key = tostring(detected)
            local name = "FlashClassCB_FALLBACK_"..playerClass.."_"..i

            -- Main checkbox for enabling tracking
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
            local txt = _G[name.."Text"]
            if txt then
                txt:SetFontObject("GameFontNormal")
                txt:SetTextColor(1, 0.82, 0)
                txt:SetText(label)
            end

            Flash.config = Flash.config or {}
            Flash.config.trackedSpells = Flash.config.trackedSpells or {}
            -- Default to not tracking unless user enables a buff
            if Flash.config.trackedSpells[key] == nil then Flash.config.trackedSpells[key] = false end
            cb:SetChecked(Flash.config.trackedSpells[key])
            cb:SetScript("OnClick", function()
                local checked = cb:GetChecked() and true or false
                Flash.config.trackedSpells[key] = checked
                if not checked and Flash.alerted then Flash.alerted[key] = nil end
            end)

            -- In-Combat-only checkbox
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
                sizeBox:SetPoint("TOPLEFT", container, "TOPLEFT", 300, -28 - ((i - 1) * 26))
                sizeBox:Show()
            else
                sizeBox = CreateFrame("EditBox", sizeName, container)
                sizeBox:SetPoint("TOPLEFT", container, "TOPLEFT", 300, -28 - ((i - 1) * 26))
                sizeBox:SetWidth(40)
                sizeBox:SetHeight(18)
                sizeBox:SetAutoFocus(false)
                sizeBox:Show()
            end
            if sizeBox.SetFontObject then sizeBox:SetFontObject("GameFontNormalSmall") end
            if sizeBox.SetTextInsets then sizeBox:SetTextInsets(4, 4, 2, 2) end
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
            sizeBox:SetText(tostring(Flash.config.buffIconSizes[key] or 40))

            -- X and Y edit boxes for fallback builder
            Flash.config.buffIcons = Flash.config.buffIcons or {}
            local savedOffsets = Flash.config.buffIcons[key]
            local info = Flash.buffIcons and Flash.buffIcons[key]
            local curX = (info and info.xOffset) or (savedOffsets and tonumber(savedOffsets.x)) or 0
            local curY = (info and info.yOffset) or (savedOffsets and tonumber(savedOffsets.y)) or 0

            local xName = name.."_X"
            local yName = name.."_Y"
            local xBox = _G[xName]
            local yBox = _G[yName]
            if xBox and type(xBox) == "table" then
                xBox:SetParent(container)
                xBox:ClearAllPoints()
                xBox:SetPoint("TOPLEFT", container, "TOPLEFT", 360, -28 - ((i - 1) * 26))
                xBox:Show()
            else
                xBox = CreateFrame("EditBox", xName, container)
                xBox:SetPoint("TOPLEFT", container, "TOPLEFT", 360, -28 - ((i - 1) * 26))
                xBox:SetWidth(40)
                xBox:SetHeight(18)
                xBox:SetAutoFocus(false)
                xBox:Show()
            end
            if xBox.SetFontObject then xBox:SetFontObject("GameFontNormalSmall") end
            if xBox.SetTextInsets then xBox:SetTextInsets(4, 4, 2, 2) end
            if xBox.SetJustifyH then xBox:SetJustifyH("CENTER") end
            if xBox.SetBackdrop then
                xBox:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
                xBox:SetBackdropColor(0,0,0,0.5)
            end
            xBox:SetText(tostring(curX))

            if yBox and type(yBox) == "table" then
                yBox:SetParent(container)
                yBox:ClearAllPoints()
                yBox:SetPoint("TOPLEFT", container, "TOPLEFT", 420, -28 - ((i - 1) * 26))
                yBox:Show()
            else
                yBox = CreateFrame("EditBox", yName, container)
                yBox:SetPoint("TOPLEFT", container, "TOPLEFT", 420, -28 - ((i - 1) * 26))
                yBox:SetWidth(40)
                yBox:SetHeight(18)
                yBox:SetAutoFocus(false)
                yBox:Show()
            end
            if yBox.SetFontObject then yBox:SetFontObject("GameFontNormalSmall") end
            if yBox.SetTextInsets then yBox:SetTextInsets(4, 4, 2, 2) end
            if yBox.SetJustifyH then yBox:SetJustifyH("CENTER") end
            if yBox.SetBackdrop then
                yBox:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
                yBox:SetBackdropColor(0,0,0,0.5)
            end
            yBox:SetText(tostring(curY))

            local function applyXY()
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
                if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
                xBox:SetText(tostring(nx))
                yBox:SetText(tostring(ny))
            end

            xBox:SetScript("OnEnterPressed", function() applyXY(); xBox:ClearFocus() end)
            xBox:SetScript("OnEscapePressed", function() xBox:SetText(tostring(curX)); xBox:ClearFocus() end)
            xBox:SetScript("OnEditFocusLost", function() applyXY() end)
            yBox:SetScript("OnEnterPressed", function() applyXY(); yBox:ClearFocus() end)
            yBox:SetScript("OnEscapePressed", function() yBox:SetText(tostring(curY)); yBox:ClearFocus() end)
            yBox:SetScript("OnEditFocusLost", function() applyXY() end)

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

            -- Track created controls so they can be reused/hidden later
            table.insert(FlashOptionsMenu._classCheckboxes, cb)
            table.insert(FlashOptionsMenu._classCheckboxes, cbCombat)
            table.insert(FlashOptionsMenu._classCheckboxes, sizeBox)
        end
    end
    _G["FlashMenu_BuildClassCheckboxes"] = FallbackBuildClassCheckboxes
end
