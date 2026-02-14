--[[
Rules:
1) When dependencies or helpers are missing, call `Flash.DebugError(msg)` instead of silently falling back.
2) Keep comments clear and up to date; add brief comments for non-obvious logic and behavior changes.
3) Preserve existing public API names and file responsibilities unless the task explicitly requires otherwise.
4) Avoid silent fallback behavior; prefer explicit, logged behavior for unexpected states.
5) When choosing class icons, use Reference Material/Spell Icons and the matching class folder.
]]
-- icons.lua - icon/frame related helpers
Flash = Flash or {}

-- Clamp per-buff icon sizes to a safe range
local function ClampIconSize(size)
    local s = tonumber(size) or 60
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

-- Expose for menu and other modules
Flash.ApplyBuffIconSize = ApplyBuffIconSize

-- Load class buff entries populated by class files (Flash.classBuffs)
local function LoadClassBuffs()
    local _, playerClass = UnitClass("player")
    if not playerClass then
        Flash.classBuffs = {}
        return
    end
    if not Flash.classBuffs or type(Flash.classBuffs) ~= "table" then
        if Flash and type(Flash.DebugError) == "function" then Flash.DebugError("Flash.classBuffs missing or invalid when loading class buffs") end
    end
    playerClass = string.upper(playerClass)
    Flash.classBuffs = Flash.classBuffs or {}
    Flash.classBuffs[playerClass] = Flash.classBuffs[playerClass] or {}
    -- Migrate legacy per-entry tracked keys into combined trackers
    Flash.config = Flash.config or {}
    Flash.config.trackedSpells = Flash.config.trackedSpells or {}
    Flash.config.trackedSpellsInCombat = Flash.config.trackedSpellsInCombat or {}
    Flash.config.buffIconSizes = Flash.config.buffIconSizes or {}
    Flash.config.buffIcons = Flash.config.buffIcons or {}
    local classBuffs = Flash.classBuffs[playerClass] or {}
    for i, buff in ipairs(classBuffs) do
        if buff and buff.detectedBuffPaths and type(buff.detectedBuffPaths) == "table" then
            local newKey = tostring(buff.detectedBuffPath or buff.iconPath or ("buff_"..i))
            for _, probe in ipairs(buff.detectedBuffPaths) do
                if probe then
                    local oldKey = tostring(probe)
                    if Flash.config.trackedSpells[oldKey] then
                        Flash.config.trackedSpells[newKey] = true
                        Flash.config.trackedSpells[oldKey] = nil
                    end
                    if Flash.config.trackedSpellsInCombat[oldKey] then
                        Flash.config.trackedSpellsInCombat[newKey] = true
                        Flash.config.trackedSpellsInCombat[oldKey] = nil
                    end
                    if Flash.config.buffIconSizes[oldKey] and not Flash.config.buffIconSizes[newKey] then
                        Flash.config.buffIconSizes[newKey] = Flash.config.buffIconSizes[oldKey]
                        Flash.config.buffIconSizes[oldKey] = nil
                    end
                    if Flash.config.buffIcons[oldKey] and not Flash.config.buffIcons[newKey] then
                        Flash.config.buffIcons[newKey] = Flash.config.buffIcons[oldKey]
                        Flash.config.buffIcons[oldKey] = nil
                    end
                end
            end
        end
    end
end

-- Reposition all buff icon frames to their saved offsets
local function UpdateIconPosition()
    if not Flash.buffIcons then return end
    local cx, cy = UIParent:GetCenter()
    for key, info in pairs(Flash.buffIcons) do
        local f = info.frame
        if f and f.ClearAllPoints then
            f:ClearAllPoints()
            local ox = (info.xOffset ~= nil) and info.xOffset or (Flash.config.iconPosX or 300)
            local oy = (info.yOffset ~= nil) and info.yOffset or (Flash.config.iconPosY or 200)
            f:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
        end
    end
end

-- Expose for the menu code so sliders can call it
Flash.UpdateIconPosition = UpdateIconPosition

-- Create per-buff icon frames for the current class
local function EnsureBuffIconFrames(playerClass)
    Flash.buffIcons = Flash.buffIcons or {}
    local classBuffs = Flash.classBuffs and Flash.classBuffs[playerClass] or {}

    for i, buff in ipairs(classBuffs) do
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local key = tostring(detected)
        if not Flash.buffIcons[key] then
            Flash.buffIcons[key] = { frame = nil, xOffset = nil, yOffset = nil }
        end
        local info = Flash.buffIcons[key]

        if not info.frame then
            local f = CreateFrame("Frame", "FlashMissingBuffFrame_"..key, UIParent)
            local size = GetBuffIconSize(key)
            f:SetWidth(size)
            f:SetHeight(size)
            f.texture = f:CreateTexture(nil, "ARTWORK")
            f.texture:SetAllPoints()
            f:Hide()

            f:EnableMouse(true)
            f:SetMovable(true)
            f:RegisterForDrag("LeftButton")
            f:SetClampedToScreen(true)
            if f.SetFrameStrata then f:SetFrameStrata("FULLSCREEN_DIALOG") end
            if f.SetFrameLevel then f:SetFrameLevel(200) end

            local _i = i
            local _key = key
            local _playerClass = playerClass
            f:SetScript("OnDragStart", function()
                if not Flash.options or not Flash.options:IsShown() then return end
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
                    pcall(function()
                        if Flash.options and Flash.options:IsShown() then
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
                            local builder = _G["FlashMenu_BuildClassCheckboxes"]
                            if type(builder) == "function" then pcall(builder) end
                        end
                    end)
                    if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
                end
            end)
            info.frame = f

            Flash.config.buffIcons = Flash.config.buffIcons or {}
            if Flash.config.buffIcons[key] then
                info.xOffset = tonumber(Flash.config.buffIcons[key].x) or nil
                info.yOffset = tonumber(Flash.config.buffIcons[key].y) or nil
            end
        else
            local size = GetBuffIconSize(key)
            if info.frame.SetWidth then info.frame:SetWidth(size) end
            if info.frame.SetHeight then info.frame:SetHeight(size) end
            if info.frame.SetFrameStrata then info.frame:SetFrameStrata("FULLSCREEN_DIALOG") end
            if info.frame.SetFrameLevel then info.frame:SetFrameLevel(200) end
        end
    end
end

Flash.EnsureBuffIconFrames = EnsureBuffIconFrames

-- Hide all class icon frames (used on menu close and when tracking off)
local function UpdateVisibilityBasedOnBuffs(playerClass)
    if not Flash.buffIcons then return end
    local classBuffs = Flash.classBuffs and Flash.classBuffs[playerClass] or {}
    for i, buff in ipairs(classBuffs) do
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local key = tostring(detected)
        local info = Flash.buffIcons[key]
        if info and info.frame then
            info.frame:Hide()
        end
    end
end

Flash.UpdateVisibilityBasedOnBuffs = UpdateVisibilityBasedOnBuffs

-- Helper: scan equipped weapon enchantments by inspecting item tooltip text
local function IsWeaponEnchantedWith(name, slotID)
    if type(name) ~= "string" then return false end
    Flash._scanTooltip = Flash._scanTooltip or CreateFrame("GameTooltip", "FlashScanTooltip", UIParent, "GameTooltipTemplate")
    local tt = Flash._scanTooltip
    tt:SetOwner(UIParent, "ANCHOR_NONE")
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
    if slotID and tonumber(slotID) then
        return checkSlot(tonumber(slotID))
    end
    if checkSlot(16) then return true end
    if checkSlot(17) then return true end
    return false
end

-- Check whether a specific weapon slot has any known poison/enchant applied
local function IsWeaponSlotHasAnyEnchant(slotID)
    if type(GetWeaponEnchantInfo) == "function" then
        local hasMainEnchant, _, _, hasOffEnchant = GetWeaponEnchantInfo()
        local slot = tonumber(slotID)
        if slot == 16 then
            return hasMainEnchant and true or false
        end
        if slot == 17 then
            return hasOffEnchant and true or false
        end
        if slot == nil then
            return (hasMainEnchant and true or false) or (hasOffEnchant and true or false)
        end
    end

    Flash._scanTooltip = Flash._scanTooltip or CreateFrame("GameTooltip", "FlashScanTooltip", UIParent, "GameTooltipTemplate")
    local tt = Flash._scanTooltip
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:ClearLines()
    tt:SetInventoryItem("player", slotID)
    local prefix = tt:GetName()
    local keywords = {
        "instant poison",
        "deadly poison",
        "crippling poison",
        "mind-numbing poison",
        "mind numbing poison",
        "wound poison",
        "anesthetic poison",
        "poison",
    }
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

-- Export helper functions for other modules
Flash.LoadClassBuffs = LoadClassBuffs
Flash.IsWeaponEnchantedWith = IsWeaponEnchantedWith
Flash.IsWeaponSlotHasAnyEnchant = IsWeaponSlotHasAnyEnchant
