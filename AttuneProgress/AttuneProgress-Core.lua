--[[
todo:

options
	font
	size
	colour
	position
	decimals
	
	grey out attuned items

]]


local CharacterSlots = {
	CharacterHeadSlot,
	CharacterNeckSlot,
	CharacterShoulderSlot,
	CharacterShirtSlot,
	CharacterChestSlot,
	CharacterWaistSlot,
	CharacterLegsSlot,
	CharacterFeetSlot,
	CharacterWristSlot,
	CharacterHandsSlot,
	CharacterFinger0Slot,
	CharacterFinger1Slot,
	CharacterTrinket0Slot,
	CharacterTrinket1Slot,
	CharacterBackSlot,
	CharacterMainHandSlot,
	CharacterSecondaryHandSlot,
	CharacterRangedSlot
}

CharRangedItems = {
    ["Priest"]      = {["Wands"] = true },
    ["Mage"]        = {["Wands"] = true },
    ["Warlock"]     = {["Wands"] = true },
    ["Rogue"]       = {["Bows"] = true ,["Crossbows"] = true ,["Guns"] = true ,["Thrown"] = true },
    ["Hunter"]      = {["Bows"] = true ,["Crossbows"] = true ,["Guns"] = true },
    ["Warrior"]     = {["Bows"] = true ,["Crossbows"] = true ,["Guns"] = true ,["Thrown"] = true },
}

local CharArmorSubType = {
	["Priest"]      = "Cloth",
	["Mage"]        = "Cloth",
	["Warlock"]     = "Cloth",
	["Rogue"]       = "Leather",
	["Druid"]       = "Leather",
	["Hunter"]      = "Mail",
	["Shaman"]      = "Mail",
	["Warrior"]     = "Plate",
	["Paladin"]     = "Plate",
	["Deathknight"] = "Plate"
}
--[[

print("test")
print(UnitClass("player"))
print(CharArmorSubType[UnitClass("player")])

local itemId = tonumber(itemLink:match('item:(%d+)'))
itemId = GetInventoryItemID("player", invSlot);
/dump ItemAttuneHas[45286]
/dump ItemAttuneHas[GetInventoryItemID("player", self.id)]
"Miscellaneous"

/dump GetItemInfo(GetInventoryItemLink("player", 5))
	local itemType = select(6,GetItemInfo(itemLink))
	local itemSubType = select(7,GetItemInfo(itemLink))
]]

--[[
	"INVTYPE_AMMO" 				Ammo 											0
	"INVTYPE_HEAD" 				Head 											1
	"INVTYPE_NECK" 				Neck 											2
	"INVTYPE_SHOULDER" 			Shoulder 										3
	"INVTYPE_BODY" 				Shirt 											4
	"INVTYPE_CHEST" 			Chest 											5
	"INVTYPE_ROBE" 				Chest 											5
	"INVTYPE_WAIST" 			Waist 											6
	"INVTYPE_LEGS" 				Legs 											7
	"INVTYPE_FEET" 				Feet 											8
	"INVTYPE_WRIST" 			Wrist 											9
	"INVTYPE_HAND" 				Hands 											10
	"INVTYPE_FINGER" 			Fingers 										11,12
	"INVTYPE_TRINKET" 			Trinkets 										13,14
	"INVTYPE_CLOAK" 			Cloaks 											15
	"INVTYPE_WEAPON" 			One-Hand 										16,17
	"INVTYPE_SHIELD" 			Shield 											17
	"INVTYPE_2HWEAPON" 			Two-Handed 										16
	"INVTYPE_WEAPONMAINHAND" 	Main-Hand Weapon 								16
	"INVTYPE_WEAPONOFFHAND" 	Off-Hand Weapon 								17
	"INVTYPE_HOLDABLE" 			Held In Off-Hand 								17
"INVTYPE_RANGED" 			Bows 											18
"INVTYPE_THROWN" 			Ranged 											18
"INVTYPE_RANGEDRIGHT" 		Wands, Guns, and Crossbows (changed in 2.4.3) 	18
	"INVTYPE_RELIC" 			Relics 											18
	"INVTYPE_TABARD" 			Tabard 											19
	"INVTYPE_BAG" 				Containers 										20,21,22,23
	"INVTYPE_QUIVER" 			Quivers 										20,21,22,23 (defined in GlobalStrings.lua, but does not appear to be used) 
]]

--main use for items already equipped by the player
--itemlink is never nil
local function ItemAttunable(itemLink)
	local itemSubType = select(7,GetItemInfo(itemLink))
	local itemType = select(6,GetItemInfo(itemLink))
	local playerClass = UnitClass("player")
	if itemType == "Armor" then
		
		local itemSlot = select(9,GetItemInfo(itemLink))
		--item is cloak
		if itemSlot == "INVTYPE_CLOAK" then return true end
		--item is offhand
		if itemSlot == "INVTYPE_HOLDABLE" then return true end
		
		--item is tabard
		if itemSlot == "INVTYPE_TABARD" then return false end
		--item is shirt
		if itemSlot == "INVTYPE_BODY" then return false end
		
		--item is jewelry
		if itemSubType == "Miscellaneous" then return true end

		--item is Shield and player is shaman paladin or druid
		if itemSlot == "INVTYPE_SHIELD" and (playerClass == "Shaman" or playerClass == "Paladin" or playerClass == "Warrior") then return true end
		
		local charSubType = CharArmorSubType[playerClass]
		--itemSubType matches playerclass
		if (itemSubType == charSubType) then return true end
	elseif itemType == "Weapon" then
		--ranged weapon can be attuned by player
		if CharRangedItems[playerClass] and CharRangedItems[playerClass][itemSubType] then
			return true
		end
	elseif itemType == "Quest" then
		local itemId = tonumber(itemLink:match('item:(%d+)'))
		if itemId == 32649 or itemId == 32757 or itemId == 18706 then
			--32649 Medallion of Karabor
			--32757 Blessed Medallion of Karabor
			--18706 Arena Master
			return true
		end
	end
	--default to false
	return false
end

local function GetAttuneText(itemLink)
	local attuneText = ""
	local itemId = tonumber(itemLink:match('item:(%d+)'))
	local attunePercent = ItemAttuneHas[itemId]
	if not attunePercent then attunePercent = 0 end
	if attunePercent == 100 then
		attuneText = ""
	else
		attunePercent = attunePercent - (attunePercent % 1)
		attuneText = attunePercent.."%"
	end
	return attuneText
end

local function ContainerFrame_OnUpdate(self, elapsed)
	local itemLink = GetContainerItemLink(self:GetParent():GetID(), self:GetID())
	
	--containerslot does not have an item
	if not itemLink then self.attune:SetText() return end
	--item not attunable
	if not ItemAttunable(itemLink) then self.attune:SetText() return end
	
	self.attune:SetText(GetAttuneText(itemLink))
end
local function CharacterFrame_OnUpdate(self, elapsed)
	--shirt slot or mainhand weapon slot
	if self.id == 4 or self.id == 16 then self.attune:SetText() return end
	
	local itemLink = GetInventoryItemLink("player", self.id)
	--no item equipped
	if not itemLink then self.attune:SetText() return end
	--item not attunable
	if not ItemAttunable(itemLink) then self.attune:SetText() return end
	
	self.attune:SetText(GetAttuneText(itemLink))
end

for i=1,NUM_CONTAINER_FRAMES do
	for j=1,MAX_CONTAINER_ITEMS do
		local frame = _G["ContainerFrame"..i.."Item"..j]
		if frame then
			frame.attune = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
			frame.attune:SetPoint("BOTTOM", 1, 1)
			frame.attune:SetTextColor(1,1,0)
		end
	end
end
for i=1,#CharacterSlots do
	frame = CharacterSlots[i]
	frame.id = i
	frame.attune = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	frame.attune:SetPoint("BOTTOM", 1, 1)
	frame.attune:SetTextColor(1,1,0)
end

local function OnEvent(self, event, ...)
	if event == "ADDON_LOADED" and ... == "AttuneProgress" then
		self:UnregisterEvent("ADDON_LOADED")
		AttuneProgress:Toggle()
	end
end

local frame = CreateFrame("Frame", "AttuneProgress", UIParent)
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("ADDON_LOADED")

function AttuneProgress:Toggle()
	for i=1,NUM_CONTAINER_FRAMES do
		for j=1,MAX_CONTAINER_ITEMS do
			local frame = _G["ContainerFrame"..i.."Item"..j]
			if frame then
				frame:HookScript("OnUpdate", ContainerFrame_OnUpdate)
			end
		end
	end
	for i=1,#CharacterSlots do
		CharacterSlots[i]:HookScript("OnUpdate", CharacterFrame_OnUpdate)
	end
end