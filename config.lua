--[[
Rules:
1) Use `Flash.DebugError(msg)` to report missing helpers or unexpected states.
2) Document defaults and why values were chosen near the variables.
3) Avoid silent fallbacks; prefer explicit, logged behavior.
4) When changing icons, open Reference Material/Spell Icons and use the class-specific folder to pick icons.
]]
-- config.lua
-- Move config bootstrapping out of FlashCore to keep responsibilities focused
Flash = Flash or {}
FlashCharacterConfig = FlashCharacterConfig or {}

local function ApplyConfigDefaults(cfg)
    cfg.iconPosX = tonumber(cfg.iconPosX) or 300
    cfg.iconPosY = tonumber(cfg.iconPosY) or 200
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

local function EnsureConfig()
    local pname = UnitName("player")
    if not pname or pname == "" then return end

    local cfg = FlashCharacterConfig[pname]
    if type(cfg) ~= "table" then
        cfg = {
            iconPosX = 300,
            iconPosY = 200,
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

    if Flash.config ~= cfg and type(Flash.config) == "table" then
        for k, v in pairs(Flash.config) do
            if cfg[k] == nil then cfg[k] = v end
        end
    end

    Flash.config = cfg
    ApplyConfigDefaults(Flash.config)
end

-- Run early so other modules can assume Flash.config is ready
Flash.EnsureConfig = EnsureConfig
EnsureConfig()
