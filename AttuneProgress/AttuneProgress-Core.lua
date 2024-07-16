--[[
todo:

double check weapons
properly handle affix items

options
	font
	size
	colour
	position
	decimals
	
	grey out attuned items

]]

local CONST_ADDON_NAME = 'AttuneProgressGescht'
AttuneProgressGescht = LibStub('AceAddon-3.0'):NewAddon(CONST_ADDON_NAME)

local SynastriaCoreLib = LibStub('SynastriaCoreLib-1.0')


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

SynastriaCoreLib.GetAttuneProgress(itemIdOrLink, suffixId, forgedType)
return GetItemAttuneProgress(itemId, suffixId, forgedType) or 0

SynastriaCoreLib.IsAttuned(itemIdOrLink)
	local ret = SynastriaCoreLib.GetAttuneProgress(itemIdOrLink)
return ret >= 100

SynastriaCoreLib.IsAttunable(itemIdOrLink)
return SynastriaCoreLib.IsItemValid(itemId) and not SynastriaCoreLib.IsAttuned(itemIdOrLink)

SynastriaCoreLib.HasAttuneProgress(itemIdOrLink)
	local ret = SynastriaCoreLib.GetAttuneProgress(itemIdOrLink)
return ret > 0 and ret < 100

]]

local function GetAttuneText(itemId)
	local attunePercent = SynastriaCoreLib.GetAttuneProgress(itemId)
	attunePercent = attunePercent - (attunePercent % 1)
	return attunePercent.."%"
end

local function IsResistArmor(itemLink,itemId)
	--item is not armor
	if select(6,GetItemInfo(itemId)) ~= "Armor" then return false end

	local itemName = itemLink:match("%[.*")
	local resistIndicator = {
		"Resistance",
		"Protection"
	}
	local typeIndicator = {
		"Arcane",
		"Fire",
		"Nature",
		"Frost",
		"Shadow"
	}
	for _, resInd in ipairs(resistIndicator) do
		--item name includes resistance or protection
		if string.find(itemName, resInd) then
			for _, resType in ipairs(typeIndicator) do
				--item name includes any spell school
				if  string.find(itemName, resType) then
					--item is a resistance piece
					return true
				end
			end
		end
	end
	return false
end


local function ContainerFrame_OnUpdate(self, elapsed)
	local itemLink = GetContainerItemLink(self:GetParent():GetID(), self:GetID())
	
	--containerslot does not have an item
	if not itemLink then self.attune:SetText() return end
	local itemId = tonumber(itemLink:match('item:(%d+)'))

	--item is resist gear
	if IsResistArmor(itemLink,itemId) then self.attune:SetText("Resist") return end
	--item not attunable
	if not SynastriaCoreLib.IsAttunable(itemId) then self.attune:SetText() return end

	self.attune:SetText(GetAttuneText(itemId))
end
local function CharacterFrame_OnUpdate(self, elapsed)
	--shirt slot or mainhand weapon slot
	if self.id == 4 or self.id == 16 then self.attune:SetText() return end
	
	local itemLink = GetInventoryItemLink("player", self.id)
	--no item equipped
	if not itemLink then self.attune:SetText() return end
	local itemId = GetInventoryItemID("player", self.id)

	--item not attunable
	if not SynastriaCoreLib.IsAttunable(itemId) then self.attune:SetText() return end

	self.attune:SetText(GetAttuneText(itemId))
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