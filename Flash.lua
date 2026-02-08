-- Minimal compatibility stub: ensure `Flash` and basic config exist
Flash = Flash or {}
-- Ensure Flash.config is a table and has sane defaults (guard savedvars corruption)
if type(Flash.config) ~= "table" then
	Flash.config = {
		iconPosX = 0,
		iconPosY = 0,
		selectedSound = "Interface\\AddOns\\Flash\\Media\\Alarm.ogg",
		soundAlertEnabled = true,
		iconEnabled = true,
		trackedSpells = {},
		buffIcons = {}
	}
else
	Flash.config.iconPosX = tonumber(Flash.config.iconPosX) or 0
	Flash.config.iconPosY = tonumber(Flash.config.iconPosY) or 0
	Flash.config.selectedSound = tostring(Flash.config.selectedSound or "Interface\\AddOns\\Flash\\Media\\Alarm.ogg")
	if type(Flash.config.soundAlertEnabled) ~= "boolean" then Flash.config.soundAlertEnabled = true end
	if type(Flash.config.iconEnabled) ~= "boolean" then Flash.config.iconEnabled = true end
	Flash.config.trackedSpells = (type(Flash.config.trackedSpells) == "table") and Flash.config.trackedSpells or {}
	Flash.config.buffIcons = (type(Flash.config.buffIcons) == "table") and Flash.config.buffIcons or {}
	Flash.config.debugMode = Flash.config.debugMode and true or false
end
Flash.soundFiles = Flash.soundFiles or {
	"Alarm.ogg","Alien.ogg","Bell.ogg","Clock.ogg","Dink.ogg","Dink2.ogg",
	"Electronic.ogg","FF7.ogg","MGS.ogg","MGS2.ogg","NefarianDropped.ogg",
	"OnyxiaDropped.ogg","Pop.ogg","Pop2.ogg","RendDropped.ogg","WT.ogg",
	"ZandalarDropped.ogg","Zelda.ogg"
}


