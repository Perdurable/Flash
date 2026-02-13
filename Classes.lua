--[[
Rules:
1) When dependencies or helpers are missing, call `Flash.DebugError(msg)` instead of silently falling back.
2) Keep comments clear and up to date; add brief comments for non-obvious logic and behavior changes.
3) Keep per-class entries documented; include displayName and detectedBuffPath where possible.
4) Top-of-file headers must document any deviations from upstream defaults.
5) To pick icons, open Reference Material/Spell Icons and select icons from the folder for the class you're updating.
]]
-- Classes.lua - restored from backup
Flash = Flash or {}
Flash.classBuffs = Flash.classBuffs or {}

Flash.classBuffs["DRUID"] = {
	{ iconPath = "Interface\\Icons\\Spell_Nature_Regeneration", detectedBuffPath = "Mark of the Wild" },
	{ iconPath = "Interface\\Icons\\Spell_Nature_Thorns", detectedBuffPath = "Thorns" }
}

Flash.classBuffs["HUNTER"] = {
	{ displayName = "Hunter Aspects", iconPath = "Interface\\Icons\\Spell_Nature_RavenForm", detectedBuffPath = "Aspects", detectedBuffPaths = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack", "Aspect of the Wild", "Aspect of the Beast", "Aspect of the Snake", "Aspect of the Fox", "Aspect of the Wolf", "Aspect of the Turtle", "Interface\\Icons\\Spell_Nature_RavenForm", "Interface\\Icons\\Ability_Hunter_AspectOfTheMonkey", "Interface\\Icons\\Ability_Mount_JungleTiger", "Interface\\Icons\\Ability_Mount_WhiteTiger", "Interface\\Icons\\Spell_Nature_ProtectionformNature", "Interface\\Icons\\Ability_Mount_PinkTiger", "Interface\\Icons\\ability_hunter_aspectoftheviper", "Interface\\Icons\\ability_hunter_aspectofthefox", "Interface\\Icons\\Ability_Mount_WhiteDireWolf", "Interface\\Icons\\Ability_Hunter_Pet_Turtle" } },
	{ displayName = "Pet Summoned", iconPath = "Interface\\Icons\\Ability_Hunter_BeastCall", detectedBuffPath = "Pet Summoned", customCheck = "petSummoned" },
	{ displayName = "Pet Happiness", iconPath = "Interface\\Icons\\Ability_Hunter_MendPet", detectedBuffPath = "Pet Happiness", customCheck = "petNotUnhappy" },
}

Flash.classBuffs["MAGE"] = {
	{ displayName = "Mage Armors", iconPath = "Interface\\Icons\\Spell_Frost_FrostArmor02", detectedBuffPath = "Mage Armors", detectedBuffPaths = { "Frost Armor", "Ice Armor", "Mage Armor", "Interface\\Icons\\Spell_Frost_FrostArmor02", "Interface\\Icons\\Spell_Frost_IceArmor", "Interface\\Icons\\Spell_Ice_MageArmor" } },
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
	{ displayName = "Shaman Shields", iconPath = "Interface\\Icons\\Spell_Nature_LightningShield", detectedBuffPath = "Shaman Shields", detectedBuffPaths = { "Lightning Shield", "Water Shield", "Interface\\Icons\\Spell_Nature_LightningShield", "Interface\\Icons\\Ability_Shaman_WaterShield" } },
	-- Combined checkbox to track any weapon imbue (Rockbiter/Flametongue/Frostbrand/Windfury)
	{ displayName = "Shaman Weapon Imbues", iconPath = "Interface\\Icons\\Spell_Nature_RockBiter", detectedBuffPath = "Weapon Imbues", weapon = true, weaponAny = true, weaponKeywords = {"Rockbiter","Flametongue","Frostbrand","Windfury"}, iconCandidates = { "Interface\\Icons\\Spell_Nature_RockBiter" } },
}

Flash.classBuffs["WARLOCK"] = {
	{ iconPath = "Interface\\Icons\\Spell_Shadow_DemonBreath", detectedBuffPath = "Interface\\Icons\\Spell_Shadow_DemonBreath" },
	{ displayName = "Pet Summoned", iconPath = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", detectedBuffPath = "Pet Summoned", customCheck = "petSummoned" }
}

Flash.classBuffs["WARRIOR"] = {
	{ displayName = "Battle Shout", iconPath = "Interface\\Icons\\Ability_Warrior_BattleShout", detectedBuffPath = "Battle Shout" },
}