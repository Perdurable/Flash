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
	{ displayName = "Blessings", iconPath = "Interface\\Icons\\Spell_Magic_MageArmor", detectedBuffPath = "Blessings", detectedBuffPaths = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Sanctuary", "Blessing of Light", "Blessing of Freedom", "Blessing of Protection", "Blessing of Sacrifice", "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings", "Greater Blessing of Sanctuary", "Greater Blessing of Salvation", "Interface\\Icons\\Spell_Holy_FistOfJustice", "Interface\\Icons\\Spell_Holy_SealOfWisdom", "Interface\\Icons\\Spell_Magic_MageArmor", "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings", "Interface\\Icons\\Spell_Holy_SealOfSalvation", "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation", "Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary", "Interface\\Icons\\Spell_Holy_PrayerOfHealing02", "Interface\\Icons\\Spell_Holy_GreaterBlessingofLight", "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom", "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings", "Interface\\Icons\\Spell_Holy_GreaterBlessingofMight", "Interface\\Icons\\Spell_Holy_SealOfValor", "Interface\\Icons\\Spell_Holy_SealOfProtection", "Interface\\Icons\\Spell_Holy_SealOfSacrifice" } },
	{ displayName = "Seals", iconPath = "Interface\\Icons\\Spell_Holy_HolySmite", detectedBuffPath = "Seals", detectedBuffPaths = { "Seal of Command", "Seal of Righteousness", "Seal of the Crusader", "Seal of Light", "Seal of Wisdom", "Seal of Justice", "Interface\\Icons\\Ability_ThunderBolt", "Interface\\Icons\\Spell_Holy_HolySmite", "Interface\\Icons\\Spell_Holy_HealingAura", "Interface\\Icons\\Spell_Holy_RighteousnessAura", "Interface\\Icons\\Spell_Holy_SealOfWrath", "Interface\\Icons\\Ability_Warrior_InnerRage", "Interface\\Icons\\Spell_Holy_SealOfCommand" } },
	{ displayName = "Auras", iconPath = "Interface\\Icons\\Spell_Holy_DevotionAura", detectedBuffPath = "Auras", detectedBuffPaths = { "Devotion Aura", "Retribution Aura", "Concentration Aura", "Crusader Aura", "Fire Resistance Aura", "Frost Resistance Aura", "Shadow Resistance Aura", "Interface\\Icons\\Spell_Holy_DevotionAura", "Interface\\Icons\\Spell_Holy_AuraOfLight", "Interface\\Icons\\Spell_Holy_MindSooth", "Interface\\Icons\\Spell_Holy_CrusaderAura", "Interface\\Icons\\Spell_Fire_SealOfFire", "Interface\\Icons\\Spell_Frost_WizardMark", "Interface\\Icons\\Spell_Shadow_SealOfKings" } }
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