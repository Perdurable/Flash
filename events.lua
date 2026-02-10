-- events.lua - core runtime loop, checks, slash command, fallback UI builder
Flash = Flash or {}
Flash.alerted = Flash.alerted or {}

local function PlayMissingBuffSound()
    if not Flash.config.soundAlertEnabled then return end
    local sound = Flash.config and Flash.config.selectedSound
    if not sound or sound == "" then return end
    pcall(PlaySoundFile, sound)
end

-- Core buff check loop for the current class
local function CheckForBuffsForClass(playerClass)
    if not Flash.config.trackingEnabled then
        if Flash.buffIcons then
            for k, info in pairs(Flash.buffIcons) do
                if info.frame and info.frame.Hide then info.frame:Hide() end
            end
        end
        Flash.alerted = {}
        return
    end

    if not Flash.config.iconEnabled then
        if Flash.buffIcons then
            for k, info in pairs(Flash.buffIcons) do if info.frame and info.frame.Hide then info.frame:Hide() end end
        end
        return
    end

    local classBuffs = Flash.classBuffs and Flash.classBuffs[playerClass] or {}
    if not classBuffs or next(classBuffs) == nil then
        if Flash.buffIcons then
            for k, info in pairs(Flash.buffIcons) do if info.frame and info.frame.Hide then info.frame:Hide() end end
        end
        return
    end

    if type(Flash.EnsureBuffIconFrames) == "function" then Flash.EnsureBuffIconFrames(playerClass) end

    for i, buff in ipairs(classBuffs) do
        local detected = buff.detectedBuffPath or buff.iconPath or ("buff_"..i)
        local key = tostring(detected)

        Flash.config = Flash.config or {}
        Flash.config.trackedSpells = Flash.config.trackedSpells or {}
        if not Flash.config.trackedSpells[key] then
            if Flash.buffIcons and Flash.buffIcons[key] and Flash.buffIcons[key].frame then
                Flash.buffIcons[key].frame:Hide()
            end
        else
            Flash.config = Flash.config or {}
            Flash.config.trackedSpellsInCombat = Flash.config.trackedSpellsInCombat or {}
            local inCombatOnly = Flash.config.trackedSpellsInCombat[key] and true or false
            local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")

            if inCombatOnly and not inCombat then
                if Flash.buffIcons and Flash.buffIcons[key] and Flash.buffIcons[key].frame then
                    Flash.buffIcons[key].frame:Hide()
                end
                if Flash.alerted then Flash.alerted[key] = nil end
            else
                local hasBuff = false

                if buff.weapon then
                    local slot = buff.weaponSlot and tonumber(buff.weaponSlot) or nil
                    local scanSlots = {}
                    if buff.weaponAny then
                        scanSlots = {16, 17}
                    else
                        scanSlots = { tonumber(slot) or 16 }
                    end

                    if buff.weaponKeywords and type(buff.weaponKeywords) == "table" then
                        -- Scan the weapon tooltip lines directly for the provided keywords across the chosen slots.
                        Flash._scanTooltip = Flash._scanTooltip or CreateFrame("GameTooltip", "FlashScanTooltip", UIParent, "GameTooltipTemplate")
                        local tt = Flash._scanTooltip
                        tt:SetOwner(UIParent, "ANCHOR_NONE")
                        for _, scanSlot in ipairs(scanSlots) do
                            tt:ClearLines()
                            tt:SetInventoryItem("player", scanSlot)
                            local prefix = tt:GetName()
                            for i = 1, 30 do
                                local left = _G[prefix .. "TextLeft" .. i]
                                if not left then break end
                                local txt = left:GetText()
                                if txt and txt ~= "" then
                                    local clean = tostring(txt)
                                    clean = string.gsub(clean, "|c%x%x%x%x%x%x%x%x", "")
                                    clean = string.gsub(clean, "|r", "")
                                    local lowered = string.lower(clean)
                                    for _, kw in ipairs(buff.weaponKeywords) do
                                        if kw and string.find(lowered, string.lower(tostring(kw)), 1, true) then
                                            hasBuff = true
                                            if Flash and Flash.config and Flash.config.debugMode and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                                                DEFAULT_CHAT_FRAME:AddMessage("Flash: matched weapon keyword '"..tostring(kw).."' on slot "..tostring(scanSlot).." -> "..clean)
                                            end
                                            break
                                        end
                                    end
                                    if hasBuff then break end
                                end
                            end
                            if hasBuff then break end
                        end
                    else
                        -- No explicit keywords: fall back to fast slot-enchant checks or probe-based checks
                        if buff.weaponAny then
                            if (Flash.IsWeaponSlotHasAnyEnchant and Flash.IsWeaponSlotHasAnyEnchant(16)) or (Flash.IsWeaponSlotHasAnyEnchant and Flash.IsWeaponSlotHasAnyEnchant(17)) then
                                hasBuff = true
                            end
                        else
                            local probes = {}
                            if buff.detectedBuffPath and type(buff.detectedBuffPath) == "string" then table.insert(probes, buff.detectedBuffPath) end
                            if buff.displayName and type(buff.displayName) == "string" then table.insert(probes, buff.displayName) end
                            for _, p in ipairs({buff.detectedBuffPath, buff.displayName}) do
                                if type(p) == "string" then
                                    local lowered = string.lower(p)
                                    local stripped = string.gsub(lowered, "%s*weapon%s*$", "")
                                    if stripped and stripped ~= lowered then
                                        table.insert(probes, stripped)
                                    end
                                end
                            end
                            for _, probe in ipairs(probes) do
                                if slot then
                                    if probe and Flash.IsWeaponEnchantedWith and Flash.IsWeaponEnchantedWith(probe, slot) then hasBuff = true; break end
                                else
                                    if probe and Flash.IsWeaponEnchantedWith and Flash.IsWeaponEnchantedWith(probe) then hasBuff = true; break end
                                end
                            end
                        end
                    end
                else
                    local function MatchesBuffName(buffName, buffEntry)
                        local lowered = string.lower(buffName)
                        if buffEntry.detectedBuffPaths and type(buffEntry.detectedBuffPaths) == "table" then
                            for _, probe in ipairs(buffEntry.detectedBuffPaths) do
                                if probe and string.find(lowered, string.lower(probe), 1, true) then
                                    return true
                                end
                            end
                        end
                        if buffEntry.detectedBuffPath and string.find(lowered, string.lower(buffEntry.detectedBuffPath), 1, true) then
                            return true
                        end
                        if buffEntry.iconPath and string.find(lowered, string.lower(buffEntry.iconPath), 1, true) then
                            return true
                        end
                        return false
                    end

                    for j = 1, 40 do
                        local data = { UnitBuff("player", j) }
                        if not data or type(data) ~= "table" then break end
                        local dataCount = 0
                        for _ in ipairs(data) do dataCount = dataCount + 1 end
                        if dataCount == 0 then break end
                        for k = 1, dataCount do
                            local v = data[k]
                            if type(v) == "string" then
                                if MatchesBuffName(v, buff) then
                                    hasBuff = true; break
                                end
                            end
                        end
                        if hasBuff then break end
                    end
                end

                local info = Flash.buffIcons and Flash.buffIcons[key]
                if not hasBuff then
                    if info and info.frame then
                        local icon = nil
                        if buff.iconCandidates and type(buff.iconCandidates) == "table" then
                            local k = next(buff.iconCandidates)
                            if k then icon = buff.iconCandidates[k] end
                        end
                        if not icon then icon = buff.iconPath end
                        if not icon then icon = "Interface\\Icons\\INV_Misc_QuestionMark" end
                        info.frame.texture:SetTexture(icon)
                        info.frame:Show()
                        if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
                        if not Flash.alerted[key] then PlayMissingBuffSound(); Flash.alerted[key] = true end
                    else
                        if Flash.iconTexture and Flash.iconFrame then
                            local icon = nil
                            if buff.iconCandidates and type(buff.iconCandidates) == "table" then
                                local k = next(buff.iconCandidates)
                                if k then icon = buff.iconCandidates[k] end
                            end
                            if not icon then icon = buff.iconPath end
                            if not icon then icon = "Interface\\Icons\\INV_Misc_QuestionMark" end
                            Flash.iconTexture:SetTexture(icon)
                            Flash.iconFrame:Show()
                            if Flash and type(Flash.UpdateIconPosition) == "function" then Flash.UpdateIconPosition() end
                            if not Flash.alerted[key] then PlayMissingBuffSound(); Flash.alerted[key] = true end
                        end
                    end
                else
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
    if type(Flash.EnsureConfig) == "function" then Flash.EnsureConfig() end
    local _, playerClass = UnitClass("player")
    playerClass = string.upper(playerClass or "")

    Flash.classBuffs = Flash.classBuffs or {}
        if type(Flash.LoadClassBuffs) == "function" then Flash.LoadClassBuffs() end

    if type(Flash.EnsureBuffIconFrames) == "function" then pcall(function() Flash.EnsureBuffIconFrames(playerClass) end) end

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

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("Flash Loaded, use /flash to configure.", 1.0, 0.4, 0.8)
    end
    
end)

-- SLASH COMMAND
SLASH_FLASH1 = "/flash"
SlashCmdList["FLASH"] = function()
    if not Flash.options then return end
    if Flash.options:IsShown() then
        Flash.options:Hide()
    else
        local builder = _G["FlashMenu_BuildClassCheckboxes"]
        if type(builder) == "function" then
            pcall(function() builder() end)
        else
            if Flash and type(Flash.DebugError) == "function" then
                local loaded = (Flash and Flash.menuLoaded ~= nil) and tostring(Flash.menuLoaded) or "nil"
                Flash.DebugError("Menu builder FlashMenu_BuildClassCheckboxes missing; menuLoaded="..loaded.."; check Flash.toc and menu.lua load order")
            end
            return
        end
        Flash.options:Show()
    end
end
