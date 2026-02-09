--[[
Rules:
1) When dependencies or helpers are missing, call `Flash.DebugError(msg)` instead of silently falling back.
2) Keep per-class entries documented; include displayName and detectedBuffPath where possible.
3) Top-of-file headers must document any deviations from upstream defaults.
4) To pick icons, open Reference Material/Spell Icons and select icons from the folder for the class you're updating.
]]
-- Classes.lua - restored from backup
Flash = Flash or {}
Flash.classBuffs = Flash.classBuffs or {}

Flash.classBuffs["DRUID"] = {
	{ iconPath = "Interface\\Icons\\Spell_Nature_Regeneration", detectedBuffPath = "Mark of the Wild" },
	{ iconPath = "Interface\\Icons\\Spell_Nature_Thorns", detectedBuffPath = "Thorns" }
}

Flash.classBuffs["HUNTER"] = {
	{ displayName = "Aspect of the Hawk", iconPath = "Interface\\Icons\\Ability_Hunter_AspectOfTheHawk", detectedBuffPath = "Aspect of the Hawk" },
	{ displayName = "Aspect of the Monkey", iconPath = "Interface\\Icons\\Ability_Hunter_AspectOfTheMonkey", detectedBuffPath = "Aspect of the Monkey" },
	{ displayName = "Aspect of the Cheetah", iconPath = "Interface\\Icons\\Ability_Hunter_AspectOfTheCheeta", detectedBuffPath = "Aspect of the Cheetah" },
	{ displayName = "Aspect of the Pack", iconPath = "Interface\\Icons\\Ability_Hunter_AspectOfThePack", detectedBuffPath = "Aspect of the Pack" },
	{ displayName = "Aspect of the Wild", iconPath = "Interface\\Icons\\Ability_Hunter_AspectOfTheWild", detectedBuffPath = "Aspect of the Wild" },
	{ displayName = "Aspect of the Beast", iconPath = "Interface\\Icons\\Ability_Hunter_AspectOfTheBeast", detectedBuffPath = "Aspect of the Beast" },
}

Flash.classBuffs["MAGE"] = {
	{ displayName = "Frost Armor", iconPath = "Interface\\Icons\\Spell_Frost_FrostArmor02", detectedBuffPath = "Frost Armor" },
	{ displayName = "Ice Armor", iconPath = "Interface\\Icons\\Spell_Frost_IceArmor", detectedBuffPath = "Ice Armor" },
	{ displayName = "Mage Armor", iconPath = "Interface\\Icons\\Spell_Ice_MageArmor", detectedBuffPath = "Mage Armor" },
	{ displayName = "Arcane Intellect", iconPath = "Interface\\Icons\\Spell_Holy_MagicalSentry", detectedBuffPath = "Arcane Intellect" },
}

Flash.classBuffs["PALADIN"] = {
	{ iconPath = "Interface\\Icons\\INV_Enchant_EssenceEternalLarge", detectedBuffPath = "Blessing of Might" },
	{ iconPath = "Interface\\Icons\\INV_Misc_Rune_01", detectedBuffPath = "Blessing of Kings" }
}

Flash.classBuffs["PRIEST"] = {
	{ displayName = "Power Word: Fortitude", iconPath = "Interface\\Icons\\Spell_Holy_WordFortitude", detectedBuffPath = "Power Word: Fortitude" },
}

Flash.classBuffs["ROGUE"] = {
	{ displayName = "Main Hand Poison", iconPath = "Interface\\Icons\\Ability_Poisons", detectedBuffPath = "Main Hand Poison", weapon = true, weaponSlot = 16, weaponAny = true },
	{ displayName = "Off Hand Poison", iconPath = "Interface\\Icons\\Ability_Poisons", detectedBuffPath = "Off Hand Poison", weapon = true, weaponSlot = 17, weaponAny = true },
}

Flash.classBuffs["SHAMAN"] = {
	{ displayName = "Lightning Shield", iconPath = "Interface\\Icons\\Spell_Nature_LightningShield", detectedBuffPath = "Lightning Shield" },
	{ displayName = "Water Shield", iconPath = "Interface\\Icons\\Ability_Shaman_WaterShield", detectedBuffPath = "Water Shield" },
	-- Combined checkbox to track any weapon imbue (Rockbiter/Flametongue/Frostbrand/Windfury)
	{ displayName = "Shaman Weapon Imbues", iconPath = "Interface\\Icons\\Spell_Nature_RockBiter", detectedBuffPath = "Weapon Imbues", weapon = true, weaponAny = true, weaponKeywords = {"Rockbiter","Flametongue","Frostbrand","Windfury"}, iconCandidates = { "Interface\\Icons\\Spell_Nature_RockBiter" } },
}

Flash.classBuffs["WARLOCK"] = {
	{ iconPath = "Interface\\Icons\\Spell_Shadow_DemonBreath", detectedBuffPath = "Interface\\Icons\\Spell_Shadow_DemonBreath" }
}

Flash.classBuffs["WARRIOR"] = {
	{ displayName = "Battle Shout", iconPath = "Interface\\Icons\\Ability_Warrior_BattleShout", detectedBuffPath = "Battle Shout" },
}