--[[
AttuneProgress - Enhanced Item Attunement Progress Display
Features:
- Visual progress bars for attunement progress (vertical bars)
- Red bars for items not attunable by character (configurable)
- Bounty icons for bountied items
- Account-attunable indicators
- Enabled by default (always on)
- WotLK 3.3.5a compatible
]]

local CONST_ADDON_NAME = 'AttuneProgress'
AttuneProgress = {}

-- Settings with defaults
local DefaultSettings = {
    showRedForNonAttunable = true,
    showBountyIcons = true,
    showAccountIcons = false,
    showProgressText = true,
    showAccountAttuneText = false,
    faeMode = false,
    
    -- Color settings (RGB values 0-1)
    progressBarColor = {r = 1.0, g = 1.0, b = 0.0}, -- Yellow
    nonAttunableBarColor = {r = 1.0, g = 0.0, b = 0.0}, -- Red
}
local Settings = {}

local function LoadSettings()
    -- Initialize the SavedVariable if it doesn't exist
    if not AttuneProgressDB then
        AttuneProgressDB = {}
    end
    
    -- Deep copy defaults first
    for key, value in pairs(DefaultSettings) do
        if type(value) == "table" then
            Settings[key] = {}
            for subkey, subvalue in pairs(value) do
                Settings[key][subkey] = subvalue
            end
        else
            Settings[key] = value
        end
    end
    
    -- Override with saved settings
    for key, value in pairs(AttuneProgressDB) do
        if type(value) == "table" and type(Settings[key]) == "table" then
            -- Merge table values (like colors)
            for subkey, subvalue in pairs(value) do
                Settings[key][subkey] = subvalue
            end
        else
            Settings[key] = value
        end
    end
end

-- Function to save current settings
local function SaveSettings()
    if not AttuneProgressDB then
        AttuneProgressDB = {}
    end
    
    -- Deep copy current settings to SavedVariables
    for key, value in pairs(Settings) do
        if type(value) == "table" then
            AttuneProgressDB[key] = {}
            for subkey, subvalue in pairs(value) do
                AttuneProgressDB[key][subkey] = subvalue
            end
        else
            AttuneProgressDB[key] = value
        end
    end
end

-- Configuration
local CONFIG = {
    PROGRESS_BAR = {
        WIDTH = 6,
        MIN_HEIGHT_PERCENT = 0.2, -- 20% of item height at 0% progress
        MAX_HEIGHT_PERCENT = 1.0, -- 100% of item height at 100% progress
        BACKGROUND_COLOR = {0, 0, 0, 1}, -- Black background
        PROGRESS_COLOR = {1, 1, 0, 1}, -- Yellow for progress (will be updated from settings)
        NON_ATTUNABLE_COLOR = {1, 0, 0, 1}, -- Red for non-attunable by character but attunable by account (will be updated from settings)
    },
    BOUNTY_ICON = {
        SIZE = 16,
        TEXTURE = 'Interface/MoneyFrame/UI-GoldIcon',
    },
	RESIST_ICON = {
		SIZE = 16,
		TEXTURE = 'Interface\\Addons\\AttuneProgress\\assets\\ScenarioIcon-Combat.blp', -- Using bounty icon as placeholder
	},
    ACCOUNT_ICON = {
        SIZE = 8,
        COLOR = {0.3, 0.7, 1.0, 0.8}, -- Light blue
    },
    TEXT = {
        FONT = "NumberFontNormal",
        COLOR = {1.0, 1.0, 0.0}, -- Yellow
        ACCOUNT_COLOR = {0.3, 0.7, 1.0}, -- Light blue for "Acc" text
    }
}

-- Function to update CONFIG colors from Settings
local function UpdateConfigColors()
    CONFIG.PROGRESS_BAR.PROGRESS_COLOR = {
        Settings.progressBarColor.r,
        Settings.progressBarColor.g,
        Settings.progressBarColor.b,
        1
    }
    CONFIG.PROGRESS_BAR.NON_ATTUNABLE_COLOR = {
        Settings.nonAttunableBarColor.r,
        Settings.nonAttunableBarColor.g,
        Settings.nonAttunableBarColor.b,
        1
    }
end

-- Bagnon Guild Bank Slots
local BagnonGuildBankSlots = {}
for i = 1, 98 do
    table.insert(BagnonGuildBankSlots, "BagnonGuildItemSlot" .. i)
end

-- ElvUI Container Slots (assuming bags 0-4 and up to 36 slots each)
local ElvUIContainerSlots = {}
for bag = 0, 4 do
    for slot = 1, 36 do
        table.insert(ElvUIContainerSlots, "ElvUI_ContainerFrameBag" .. bag .. "Slot" .. slot)
    end
end

-- AdiBags Stack Buttons
local AdiBagsSlots = {}
for i = 1, 160 do
    table.insert(AdiBagsSlots, "AdiBagsItemButton" .. i)
end

-- Utility Functions
local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local itemIdStr = string.match(itemLink, "item:(%d+)")
    if itemIdStr then return tonumber(itemIdStr) end
    return nil
end

-- Item Validation Functions
local function IsItemValid(itemIdOrLink)
    local itemId = itemIdOrLink
    if type(itemIdOrLink) == "string" then
        itemId = GetItemIDFromLink(itemIdOrLink)
    end
    if not itemId then return false end

    -- _G.CanAttuneItemHelper check, returns 1 if attunable by player
    if _G.CanAttuneItemHelper then
        return CanAttuneItemHelper(itemId) >= 1
    end
    return false
end

local function GetAttuneProgress(itemLink)
    if not itemLink then return 0 end

    -- _G.GetItemLinkAttuneProgress check
    if _G.GetItemLinkAttuneProgress then
        local progress = GetItemLinkAttuneProgress(itemLink)
        if type(progress) == "number" then
            return progress
        end
    end
    return 0
end

local function IsItemBountied(itemId)
    -- Requires _G.GetCustomGameData, returns >0 if bountied
    if not itemId or not _G.GetCustomGameData then return false end
    local bountiedValue = GetCustomGameData(31, itemId)
    return (bountiedValue or 0) > 0
end

local function IsAttunableByAccount(itemId)
    if not itemId then return false end

    -- Prefer IsAttunableBySomeone (more reliable for account-wide)
    if _G.IsAttunableBySomeone then
        local check = IsAttunableBySomeone(itemId)
        return (check ~= nil and check ~= 0)
    end

    -- Fallback to GetItemTagsCustom for account-bound items (tag 64)
    if _G.GetItemTagsCustom then
        local itemTags = GetItemTagsCustom(itemId)
        if itemTags then
            return bit.band(itemTags, 96) == 64 -- Check if tag 64 (account-bound) is set
        end
    end

    return false
end

local function IsItemResistArmor(itemLink, itemId)
    if not itemLink or not itemId then return false end

    -- Check if it's armor
    if select(6, GetItemInfo(itemId)) ~= "Armor" then return false end

    local itemName = itemLink:match("%[(.-)%]") -- Extract name from link
    if not itemName then return false end

    -- Common resist/protection indicators
    local resistIndicators = {"Resistance", "Protection"}
    -- Specific resistance types
    local resistTypes = {"Arcane", "Fire", "Nature", "Frost", "Shadow"}

    for _, resInd in ipairs(resistIndicators) do
        if string.find(itemName, resInd) then
            for _, resType in ipairs(resistTypes) do
                if string.find(itemName, resType) then
                    return true
                end
            end
        end
    end
    return false
end

-- UI Creation and Update Functions
local function SetFrameBounty(frame, itemLink)
    local bountyFrameName = frame:GetName() .. '_Bounty'
    local bountyFrame = _G[bountyFrameName]
    local itemId = GetItemIDFromLink(itemLink)

    if Settings.showBountyIcons and itemId and IsItemBountied(itemId) then
        if not bountyFrame then
            bountyFrame = CreateFrame('Frame', bountyFrameName, frame)
            bountyFrame:SetWidth(CONFIG.BOUNTY_ICON.SIZE)
            bountyFrame:SetHeight(CONFIG.BOUNTY_ICON.SIZE)
            bountyFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
            bountyFrame.texture = bountyFrame:CreateTexture(
                nil,
                'OVERLAY'
            ) -- Set strata to OVERLAY for texture
            bountyFrame.texture:SetAllPoints()
            bountyFrame.texture:SetTexture(CONFIG.BOUNTY_ICON.TEXTURE)
        end
        bountyFrame:SetParent(frame)
        bountyFrame:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -2, -2)
        bountyFrame:Show()
    elseif bountyFrame then
        bountyFrame:Hide()
    end
end

local function SetFrameAccountIcon(frame, itemId)
    local iconFrameName = frame:GetName() .. '_Account'
    local iconFrame = _G[iconFrameName]

    -- Show icon if it's account-attunable and not attunable by *this* character
    if Settings.showAccountIcons and itemId and IsAttunableByAccount(itemId) and not IsItemValid(itemId) then
        if not iconFrame then
            iconFrame = CreateFrame('Frame', iconFrameName, frame)
            iconFrame:SetWidth(CONFIG.ACCOUNT_ICON.SIZE)
            iconFrame:SetHeight(CONFIG.ACCOUNT_ICON.SIZE)
            iconFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
            iconFrame.texture = iconFrame:CreateTexture(
                nil,
                'OVERLAY'
            ) -- Set strata to OVERLAY for texture
            iconFrame.texture:SetAllPoints()
            iconFrame.texture:SetTexture(1, 1, 1, 1) -- White square
            iconFrame.texture:SetVertexColor(
                CONFIG.ACCOUNT_ICON.COLOR[1],
                CONFIG.ACCOUNT_ICON.COLOR[2],
                CONFIG.ACCOUNT_ICON.COLOR[3],
                CONFIG.ACCOUNT_ICON.COLOR[4]
            )
        end
        iconFrame:SetParent(frame)
        iconFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', 2, -2)
        iconFrame:Show()
    elseif iconFrame then
        iconFrame:Hide()
    end
end

local function SetFrameResistIcon(frame, itemLink, itemId)
    local resistFrameName = frame:GetName() .. '_Resist'
    local resistFrame = _G[resistFrameName]

    if itemLink and itemId and IsItemResistArmor(itemLink, itemId) then
        if not resistFrame then
            resistFrame = CreateFrame('Frame', resistFrameName, frame)
            resistFrame:SetWidth(CONFIG.RESIST_ICON.SIZE)
            resistFrame:SetHeight(CONFIG.RESIST_ICON.SIZE)
            resistFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
            resistFrame.texture = resistFrame:CreateTexture(
                nil,
                'OVERLAY'
            ) -- Set strata to OVERLAY for texture
            resistFrame.texture:SetAllPoints()
            resistFrame.texture:SetTexture(CONFIG.RESIST_ICON.TEXTURE)
        end
        resistFrame:SetParent(frame)
        resistFrame:SetPoint('TOP', frame, 'TOP', 0, -2) -- Top center position
        resistFrame:Show()
    elseif resistFrame then
        resistFrame:Hide()
    end
end

local function SetFrameAttunement(frame, itemLink)
    local itemId = GetItemIDFromLink(itemLink)
    local progressFrameName = frame:GetName() .. '_attuneBar'
    local progressFrame = _G[progressFrameName]

    -- Ensure text font string exists
    if not frame.attuneText then
        frame.attuneText = frame:CreateFontString(nil, "OVERLAY", CONFIG.TEXT.FONT)
        frame.attuneText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)
    end

    -- Reset text color and hide bar initially
    frame.attuneText:SetTextColor(
        CONFIG.TEXT.COLOR[1],
        CONFIG.TEXT.COLOR[2],
        CONFIG.TEXT.COLOR[3]
    )
    frame.attuneText:SetText("")
    if progressFrame then progressFrame:Hide() end

    if not itemLink or not itemId then return end

    local attunableByCharacter = IsItemValid(itemId)
    local attunableByAccount = IsAttunableByAccount(itemId)
    local attuneProgress = GetAttuneProgress(itemLink) or 0
    local showBar = false
    local barColor = CONFIG.PROGRESS_BAR.PROGRESS_COLOR

    -- Check for resist armor
	-- local isResistArmor = IsItemResistArmor(itemLink, itemId)

    if attunableByCharacter then
		-- In Fae Mode, show bars even at 100%. Otherwise, only show bars below 100%
		if Settings.faeMode or attuneProgress < 100 then
			showBar = true
			barColor = CONFIG.PROGRESS_BAR.PROGRESS_COLOR -- Character color
			if Settings.showProgressText then
				if isResistArmor then
					frame.attuneText:SetText("Resist " .. string.format("%.0f%%", attuneProgress))
				else
					frame.attuneText:SetText(string.format("%.0f%%", attuneProgress))
				end
			elseif isResistArmor then
				frame.attuneText:SetText("Resist")
			end
		elseif isResistArmor then
			frame.attuneText:SetText("Resist")
		end
	elseif Settings.showRedForNonAttunable and attunableByAccount then
		-- ... existing code ...
		if Settings.showProgressText and attuneProgress > 0 then
			if isResistArmor then
				frame.attuneText:SetText("Resist " .. string.format("%.0f%%", attuneProgress))
			else
				frame.attuneText:SetText(string.format("%.0f%%", attuneProgress))
			end
		elseif Settings.showAccountAttuneText then
			if isResistArmor then
				frame.attuneText:SetText("Resist Acc")
			else
				frame.attuneText:SetText("Acc")
			end
			-- ... existing color code ...
		elseif isResistArmor then
			frame.attuneText:SetText("Resist")
		end
	elseif isResistArmor then
		frame.attuneText:SetText("Resist")
	end

    if showBar then
        if not progressFrame then
            progressFrame = CreateFrame('Frame', progressFrameName, frame)
            progressFrame:SetWidth(CONFIG.PROGRESS_BAR.WIDTH + 2)
            progressFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
            progressFrame.texture = progressFrame:CreateTexture(
                nil,
                'OVERLAY'
            ) -- Set strata to OVERLAY for texture
            progressFrame.texture:SetAllPoints()
            progressFrame.texture:SetTexture(
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[1],
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[2],
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[3],
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[4]
            )

            progressFrame.child = CreateFrame('Frame', progressFrameName .. 'Child', progressFrame)
            progressFrame.child:SetWidth(CONFIG.PROGRESS_BAR.WIDTH)
            progressFrame.child:SetFrameLevel(progressFrame:GetFrameLevel() + 1)
            progressFrame.child:SetPoint('BOTTOMLEFT', progressFrame, 'BOTTOMLEFT', -1, -1)
            progressFrame.child.texture = progressFrame.child:CreateTexture(
                nil,
                'OVERLAY'
            ) -- Set strata to OVERLAY for texture
            progressFrame.child.texture:SetAllPoints()
        end

        progressFrame:SetParent(frame)
        progressFrame:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 2, 2)

        local frameHeight = frame:GetHeight()
        local minHeight = frameHeight * CONFIG.PROGRESS_BAR.MIN_HEIGHT_PERCENT
        local maxHeight = frameHeight * CONFIG.PROGRESS_BAR.MAX_HEIGHT_PERCENT
        local height

        -- Both character and account-wide items should respect progress ratio
        local progressRatio = attuneProgress / 100
        height = minHeight + (progressRatio * (maxHeight - minHeight))

        height = math.max(height, minHeight) -- Ensure minimum height
        progressFrame:SetHeight(height)

        progressFrame.child:SetHeight(height - 2)
        progressFrame.child.texture:SetTexture(
            barColor[1], barColor[2], barColor[3], barColor[4]
        )
        progressFrame:Show()
    end
end

local function UpdateItemDisplay(frame, itemLink)
    -- If the addon is not logically "enabled" (though the option is removed, we keep the flag)
    -- or if the frame is invalid, return.
    if not frame or not frame:GetName() then return end

    local itemId = itemLink and GetItemIDFromLink(itemLink) or nil

    -- Clear previous states (bars, icons, text) to ensure clean updates
    local progressFrame = _G[frame:GetName() .. '_attuneBar']
    if progressFrame then progressFrame:Hide() end
    local bountyFrame = _G[frame:GetName() .. '_Bounty']
    if bountyFrame then bountyFrame:Hide() end
    local iconFrame = _G[frame:GetName() .. '_Account']
    if iconFrame then iconFrame:Hide() end
    local resistFrameName = frame:GetName() .. '_Resist'
	if _G[resistFrameName] then _G[resistFrameName]:Hide() end
    if frame.attuneText then frame.attuneText:SetText("") end

    -- If no item link, ensure everything is hidden and return
    if not itemLink then return end

    -- Update all displays based on current item link and ID
    SetFrameBounty(frame, itemLink)
    SetFrameAccountIcon(frame, itemId)
    SetFrameResistIcon(frame, itemLink, itemId)  -- Add this line
    SetFrameAttunement(frame, itemLink)
end

-- Event Handlers
local function ContainerFrame_OnUpdate(self, elapsed)
    -- More aggressive update - every 0.05 seconds
    self.attuneLastUpdate = self.attuneLastUpdate or 0
    self.attuneLastUpdate = self.attuneLastUpdate + elapsed
    if self.attuneLastUpdate < 0.05 then return end -- Update every 0.05 seconds
    self.attuneLastUpdate = 0

    local itemLink = GetContainerItemLink(self:GetParent():GetID(), self:GetID())
    UpdateItemDisplay(self, itemLink)
end

local function ElvUIContainer_OnUpdate(self, elapsed)
    -- More aggressive update - every 0.05 seconds
    self.attuneLastUpdate = self.attuneLastUpdate or 0
    self.attuneLastUpdate = self.attuneLastUpdate + elapsed
    if self.attuneLastUpdate < 0.05 then return end -- Update every 0.05 seconds
    self.attuneLastUpdate = 0

    -- Extract bag and slot from frame name (e.g., "ElvUI_ContainerFrameBag0Slot5" -> bag=0, slot=5)
    local frameName = self:GetName()
    local bag, slot = string.match(frameName, "ElvUI_ContainerFrameBag(%d+)Slot(%d+)")
    if not bag or not slot then return end
    
    bag = tonumber(bag)
    slot = tonumber(slot)

    local itemLink = GetContainerItemLink(bag, slot)
    UpdateItemDisplay(self, itemLink)
end

local function AdiBags_OnUpdate(self, elapsed)
    -- More aggressive update - every 0.05 seconds
    self.attuneLastUpdate = self.attuneLastUpdate or 0
    self.attuneLastUpdate = self.attuneLastUpdate + elapsed
    if self.attuneLastUpdate < 0.05 then return end -- Update every 0.05 seconds
    self.attuneLastUpdate = 0

    -- AdiBags stores item information differently
    local itemLink = nil
    
    -- Method 1: Check if the button has itemLink property
    if self.itemLink then
        itemLink = self.itemLink
    end
    
    -- Method 2: Check if there's a GetLink method
    if not itemLink and self.GetLink then
        itemLink = self:GetLink()
    end
    
    -- Method 3: Check for item property and build link
    if not itemLink and self.item then
        itemLink = self.item
    end

    UpdateItemDisplay(self, itemLink)
end

local function BagnonGuildBank_OnUpdate(self, elapsed)
    -- Only update if BagnonFrameguildbank is visible
    if not _G.BagnonFrameguildbank or not _G.BagnonFrameguildbank:IsVisible() then
        return
    end

    -- More aggressive update - every 0.05 seconds
    self.attuneLastUpdate = self.attuneLastUpdate or 0
    self.attuneLastUpdate = self.attuneLastUpdate + elapsed
    if self.attuneLastUpdate < 0.05 then return end -- Update every 0.05 seconds
    self.attuneLastUpdate = 0

    -- Extract slot number from frame name (e.g., "BagnonGuildItemSlot5" -> 5)
    local frameName = self:GetName()
    local slotNum = tonumber(string.match(frameName, "BagnonGuildItemSlot(%d+)"))
    if not slotNum then return end

    -- Try different methods to get guild bank item link
    local itemLink = nil
    
    -- Method 1: Try GetGuildBankItemLink if it exists
    if _G.GetGuildBankItemLink then
        local tab = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1
        itemLink = GetGuildBankItemLink(tab, slotNum)
    end
    
    -- Method 2: Try Bagnon-specific methods if available
    if not itemLink and _G.Bagnon and _G.Bagnon.GetItemLink then
        itemLink = _G.Bagnon.GetItemLink(self)
    end
    
    -- Method 3: Check if the frame has itemLink property (some addons store it)
    if not itemLink and self.itemLink then
        itemLink = self.itemLink
    end
    
    -- Method 4: Try tooltip scanning as fallback
    if not itemLink then
        -- Create a hidden tooltip for scanning
        if not _G.AttuneProgressScanTooltip then
            _G.AttuneProgressScanTooltip = CreateFrame("GameTooltip", "AttuneProgressScanTooltip", UIParent, "GameTooltipTemplate")
            _G.AttuneProgressScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end
        
        _G.AttuneProgressScanTooltip:ClearLines()
        _G.AttuneProgressScanTooltip:SetOwner(self, "ANCHOR_NONE")
        
        -- Try to set tooltip to this item
        if self.hasItem then
            _G.AttuneProgressScanTooltip:SetGuildBankItem(GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1, slotNum)
            local itemName = _G.AttuneProgressScanTooltipTextLeft1 and _G.AttuneProgressScanTooltipTextLeft1:GetText()
            if itemName then
                -- This is a basic fallback - we have the name but not the full link
                -- The attunement system might still work with just the name in some cases
                itemLink = itemName
            end
        end
    end

    UpdateItemDisplay(self, itemLink)
end

-- Options Panel Creation
local function CreateOptionsPanel()
    -- Main Panel
    local panel = CreateFrame("Frame")
    panel.name = CONST_ADDON_NAME

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(CONST_ADDON_NAME .. " Options")

    -- Checkbutton helper function
    local function CreateCheckbox(parent, text, settingKey, anchorFrame, offsetY)
        local checkboxName = "AttuneProgressCheckbox_" .. settingKey
        local cb = CreateFrame("CheckButton", checkboxName, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY)
        
        local textObject = _G[cb:GetName() .. "Text"]
        if textObject then
            textObject:SetText(text)
        else
            for i = 1, cb:GetNumRegions() do
                local region = select(i, cb:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    region:SetText(text)
                    break
                end
            end
        end
    
        cb:SetChecked(Settings[settingKey])
        cb:SetScript("OnClick", function(self)
            Settings[settingKey] = self:GetChecked()
            SaveSettings() -- Save when changed
            AttuneProgress:ForceUpdateAllDisplays()
        end)
        return cb
    end

    local lastElement = title

    -- Red Bars Checkbox
    lastElement = CreateCheckbox(
        panel,
        "Show red bars for account-attunable items (not by character)",
        "showRedForNonAttunable",
        lastElement,
        -20
    )

    -- Bounty Icons Checkbox
    lastElement = CreateCheckbox(
        panel,
        "Show bounty icons",
        "showBountyIcons",
        lastElement,
        -10
    )

    -- Account Icons Checkbox
    lastElement = CreateCheckbox(
        panel,
        "Show account-attunable icon (blue square)",
        "showAccountIcons",
        lastElement,
        -10
    )

    -- Progress Text Checkbox
    lastElement = CreateCheckbox(
        panel,
        "Show progress percentage text",
        "showProgressText",
        lastElement,
        -10
    )

    -- Show "Acc" text for account-attunable items
    lastElement = CreateCheckbox(
        panel,
        "Show 'Acc' text for account-attunable items",
        "showAccountAttuneText",
        lastElement,
        -10
    )

    -- Fae Mode Checkbox
    lastElement = CreateCheckbox(
        panel,
        "Fae Mode - Show bars even at 100% completion",
        "faeMode",
        lastElement,
        -10
    )

    -- Description
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -30)
    description:SetWidth(500)
    description:SetJustifyH("LEFT")
    description:SetText(
        "AttuneProgress enhances your item display with attunement information.\n\n" ..
            "Yellow bars: Items attunable by your character (height indicates progress).\n" ..
            "Red bars: Items attunable by account, but not by your current character (when enabled).\n" ..
            "Gold icons: Bountied items.\n" ..
            "Blue squares: Account-attunable items.\n" ..
            "'Acc' text: Items attunable by account, not by your character (when enabled).\n" ..
            "'Resist' text: Resistance armor items.\n" ..
            "Fae Mode: Always show bars, even at 100% completion.\n\n" ..
            "Supported: Blizzard bags, ElvUI bags, AdiBags, Bagnon Guild Bank\n\n" ..
            "Check the 'Colors' subcategory to customize bar colors."
    )

    -- Add to Blizzard Interface Options
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

local function CreateColorOptionsPanel()
    -- Color Panel
    local colorPanel = CreateFrame("Frame")
    colorPanel.name = "Colors"
    colorPanel.parent = CONST_ADDON_NAME

    -- Title
    local colorTitle = colorPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    colorTitle:SetPoint("TOPLEFT", 16, -16)
    colorTitle:SetText(CONST_ADDON_NAME .. " - Color Settings")

    -- Color slider helper function
    local function CreateColorSlider(parent, text, colorTable, colorKey, anchorFrame, offsetY)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY)
        label:SetText(text)

        local sliderFrame = CreateFrame("Frame", nil, parent)
        sliderFrame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        sliderFrame:SetSize(200, 60)

        -- Generate unique names for the sliders
        local uniqueId = colorKey .. "_" .. math.random(1000, 9999)

        -- Red slider
        local redSlider = CreateFrame("Slider", "AttuneProgressRedSlider_" .. uniqueId, sliderFrame, "OptionsSliderTemplate")
        redSlider:SetPoint("TOPLEFT", sliderFrame, "TOPLEFT", 0, -10)
        redSlider:SetSize(180, 15)
        redSlider:SetMinMaxValues(0, 1)
        redSlider:SetValue(colorTable[colorKey].r)
        redSlider:SetValueStep(0.01)
        _G[redSlider:GetName().."Low"]:SetText("0")
        _G[redSlider:GetName().."High"]:SetText("1")
        _G[redSlider:GetName().."Text"]:SetText("Red: " .. string.format("%.2f", colorTable[colorKey].r))

        -- Green slider
        local greenSlider = CreateFrame("Slider", "AttuneProgressGreenSlider_" .. uniqueId, sliderFrame, "OptionsSliderTemplate")
        greenSlider:SetPoint("TOPLEFT", redSlider, "BOTTOMLEFT", 0, -20)
        greenSlider:SetSize(180, 15)
        greenSlider:SetMinMaxValues(0, 1)
        greenSlider:SetValue(colorTable[colorKey].g)
        greenSlider:SetValueStep(0.01)
        _G[greenSlider:GetName().."Low"]:SetText("0")
        _G[greenSlider:GetName().."High"]:SetText("1")
        _G[greenSlider:GetName().."Text"]:SetText("Green: " .. string.format("%.2f", colorTable[colorKey].g))

        -- Blue slider
        local blueSlider = CreateFrame("Slider", "AttuneProgressBlueSlider_" .. uniqueId, sliderFrame, "OptionsSliderTemplate")
        blueSlider:SetPoint("TOPLEFT", greenSlider, "BOTTOMLEFT", 0, -30)
        blueSlider:SetSize(180, 15)
        blueSlider:SetMinMaxValues(0, 1)
        blueSlider:SetValue(colorTable[colorKey].b)
        blueSlider:SetValueStep(0.01)
        _G[blueSlider:GetName().."Low"]:SetText("0")
        _G[blueSlider:GetName().."High"]:SetText("1")
        _G[blueSlider:GetName().."Text"]:SetText("Blue: " .. string.format("%.2f", colorTable[colorKey].b))

        -- Color preview
        local colorPreview = CreateFrame("Frame", nil, sliderFrame)
        colorPreview:SetPoint("TOPRIGHT", sliderFrame, "TOPRIGHT", 0, 0)
        colorPreview:SetSize(15, 45)
        colorPreview.texture = colorPreview:CreateTexture(nil, "BACKGROUND")
        colorPreview.texture:SetAllPoints()
        colorPreview.texture:SetTexture(colorTable[colorKey].r, colorTable[colorKey].g, colorTable[colorKey].b, 1)

        local function UpdateColor()
            colorTable[colorKey].r = redSlider:GetValue()
            colorTable[colorKey].g = greenSlider:GetValue()
            colorTable[colorKey].b = blueSlider:GetValue()
            colorPreview.texture:SetTexture(colorTable[colorKey].r, colorTable[colorKey].g, colorTable[colorKey].b, 1)
            _G[redSlider:GetName().."Text"]:SetText("Red: " .. string.format("%.2f", colorTable[colorKey].r))
            _G[greenSlider:GetName().."Text"]:SetText("Green: " .. string.format("%.2f", colorTable[colorKey].g))
            _G[blueSlider:GetName().."Text"]:SetText("Blue: " .. string.format("%.2f", colorTable[colorKey].b))
            UpdateConfigColors()
            SaveSettings() -- Save when changed
            AttuneProgress:ForceUpdateAllDisplays()
        end

        redSlider:SetScript("OnValueChanged", UpdateColor)
        greenSlider:SetScript("OnValueChanged", UpdateColor)
        blueSlider:SetScript("OnValueChanged", UpdateColor)

        return sliderFrame
    end

    local lastElement = colorTitle

    -- Character Progress Bar Color
    lastElement = CreateColorSlider(
        colorPanel,
        "Character-attunable progress bar color:",
        Settings,
        "progressBarColor",
        lastElement,
        -25
    )

    -- Account Progress Bar Color
    lastElement = CreateColorSlider(
        colorPanel,
        "Account-attunable progress bar color:",
        Settings,
        "nonAttunableBarColor",
        lastElement,
        -85
    )

    -- Color Description
    local colorDescription = colorPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    colorDescription:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -90)
    colorDescription:SetWidth(500)
    colorDescription:SetJustifyH("LEFT")
    colorDescription:SetText(
        "Customize the colors of the attunement progress bars.\n\n" ..
            "Character-attunable: For items your current character can attune.\n" ..
            "Account-attunable: For items attunable by other characters on your account.\n\n" ..
            "Use the RGB sliders to adjust each color component (0.0 to 1.0).\n" ..
            "The colored square shows a preview of your selected color.\n" ..
            "Changes are applied immediately to all visible items."
    )

    -- Add to Blizzard Interface Options as subcategory
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(colorPanel)
    end

    return colorPanel
end

-- WotLK compatible timer function
local function DelayedCall(delay, func)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            frame:SetScript("OnUpdate", nil)
            func()
            frame:Hide() -- Hide the frame to clean up
        end
    end)
    frame:Show() -- Show the frame to make OnUpdate fire
end

-- Periodic frame hooking to catch frames that weren't available initially
local function PeriodicFrameHooking()
    local hookFrame = CreateFrame("Frame")
    local elapsed = 0
    hookFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 2.0 then -- Check every 2 seconds
            elapsed = 0
            AttuneProgress:HookNewFrames()
        end
    end)
    hookFrame:Show()
end

-- Event Management
-- Event Management (updated)
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == CONST_ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        
        -- Load settings from SavedVariables
        LoadSettings()
        
        -- Delay initialization slightly to ensure all frames are loaded
        DelayedCall(0.1, function()
            AttuneProgress:Initialize()
        end)
    elseif event == "BAG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        -- Force refresh on bag updates and world entering
        DelayedCall(0.1, function()
            AttuneProgress:ForceUpdateAllDisplays()
        end)
    end
end
local eventFrame = CreateFrame("Frame", "AttuneProgressEventFrame", UIParent)
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Main Functions
function AttuneProgress:Initialize()
    print("|cff00ff00AttuneProgress|r: Initializing...")

    -- Update CONFIG colors from settings on initialization
    UpdateConfigColors()
    -- Create both options panels
    CreateOptionsPanel()
    CreateColorOptionsPanel()
    -- Enable updates always
    AttuneProgress:EnableUpdates()
    -- Start periodic frame hooking
    PeriodicFrameHooking()

    --print("|cff00ff00AttuneProgress|r: Enhanced attunement display loaded and enabled!")
    print(
        "|cff00ff00AttuneProgress|r: Use /ap for commands or check Interface > AddOns > " ..
            CONST_ADDON_NAME .. " for options."
    )
    
    -- Multiple delayed refreshes to catch frames that load later
    DelayedCall(1.0, function() AttuneProgress:ForceUpdateAllDisplays() end)
    DelayedCall(3.0, function() AttuneProgress:ForceUpdateAllDisplays() end)
    DelayedCall(5.0, function() AttuneProgress:ForceUpdateAllDisplays() end)
end

function AttuneProgress:HookNewFrames()
    -- Hook container frame updates
    for i = 1, NUM_CONTAINER_FRAMES do
        for j = 1, 36 do
            local frame = _G["ContainerFrame" .. i .. "Item" .. j]
            if frame and not frame.attuneUpdateHooked then
                frame:HookScript("OnUpdate", ContainerFrame_OnUpdate)
                frame.attuneUpdateHooked = true
            end
        end
    end

    -- Hook ElvUI container frame updates
    for i = 1, #ElvUIContainerSlots do
        local frameName = ElvUIContainerSlots[i]
        local frame = _G[frameName]
        if frame and not frame.attuneUpdateHooked then
            frame:HookScript("OnUpdate", ElvUIContainer_OnUpdate)
            frame.attuneUpdateHooked = true
        end
    end

    -- Hook AdiBags frame updates
    for i = 1, #AdiBagsSlots do
        local frameName = AdiBagsSlots[i]
        local frame = _G[frameName]
        if frame and not frame.attuneUpdateHooked then
            frame:HookScript("OnUpdate", AdiBags_OnUpdate)
            frame.attuneUpdateHooked = true
        end
    end

    -- Hook Bagnon Guild Bank frame updates
    for i = 1, #BagnonGuildBankSlots do
        local frameName = BagnonGuildBankSlots[i]
        local frame = _G[frameName]
        if frame and not frame.attuneUpdateHooked then
            frame:HookScript("OnUpdate", BagnonGuildBank_OnUpdate)
            frame.attuneUpdateHooked = true
        end
    end
end

function AttuneProgress:EnableUpdates()
    AttuneProgress:HookNewFrames()
    print("|cff00ff00AttuneProgress|r: Updates enabled!")
end

function AttuneProgress:DisableUpdates()
    -- Hide all existing bars and icons
    for i = 1, NUM_CONTAINER_FRAMES do
		for j = 1, 36 do
			local frame = _G["ContainerFrame" .. i .. "Item" .. j]
			if frame and frame:GetName() then
				local progressFrameName = frame:GetName() .. '_attuneBar'
				local bountyFrameName = frame:GetName() .. '_Bounty'
				local iconFrameName = frame:GetName() .. '_Account'
				local resistFrameName = frame:GetName() .. '_Resist'
	
				if _G[progressFrameName] then _G[progressFrameName]:Hide() end
				if _G[bountyFrameName] then _G[bountyFrameName]:Hide() end
				if _G[iconFrameName] then _G[iconFrameName]:Hide() end
				if _G[resistFrameName] then _G[resistFrameName]:Hide() end 
				if frame.attuneText then frame.attuneText:SetText("") end
			end
		end
	end

    -- Hide ElvUI displays
    for i = 1, #ElvUIContainerSlots do
        local frameName = ElvUIContainerSlots[i]
        local frame = _G[frameName]
        if frame and frame:GetName() then
			local progressFrameName = frame:GetName() .. '_attuneBar'
			local bountyFrameName = frame:GetName() .. '_Bounty'
			local iconFrameName = frame:GetName() .. '_Account'
			local resistFrameName = frame:GetName() .. '_Resist'

			if _G[progressFrameName] then _G[progressFrameName]:Hide() end
			if _G[bountyFrameName] then _G[bountyFrameName]:Hide() end
			if _G[iconFrameName] then _G[iconFrameName]:Hide() end
			if _G[resistFrameName] then _G[resistFrameName]:Hide() end 
			if frame.attuneText then frame.attuneText:SetText("") end
        end
    end

    -- Hide AdiBags displays
    for i = 1, #AdiBagsSlots do
        local frameName = AdiBagsSlots[i]
        local frame = _G[frameName]
        if frame and frame:GetName() then
			local progressFrameName = frame:GetName() .. '_attuneBar'
			local bountyFrameName = frame:GetName() .. '_Bounty'
			local iconFrameName = frame:GetName() .. '_Account'
			local resistFrameName = frame:GetName() .. '_Resist'

			if _G[progressFrameName] then _G[progressFrameName]:Hide() end
			if _G[bountyFrameName] then _G[bountyFrameName]:Hide() end
			if _G[iconFrameName] then _G[iconFrameName]:Hide() end
			if _G[resistFrameName] then _G[resistFrameName]:Hide() end 
			if frame.attuneText then frame.attuneText:SetText("") end
        end
    end

    -- Hide Bagnon Guild Bank displays
    for i = 1, #BagnonGuildBankSlots do
        local frameName = BagnonGuildBankSlots[i]
        local frame = _G[frameName]
        if frame and frame:GetName() then
			local progressFrameName = frame:GetName() .. '_attuneBar'
			local bountyFrameName = frame:GetName() .. '_Bounty'
			local iconFrameName = frame:GetName() .. '_Account'
			local resistFrameName = frame:GetName() .. '_Resist'

			if _G[progressFrameName] then _G[progressFrameName]:Hide() end
			if _G[bountyFrameName] then _G[bountyFrameName]:Hide() end
			if _G[iconFrameName] then _G[iconFrameName]:Hide() end
			if _G[resistFrameName] then _G[resistFrameName]:Hide() end 
			if frame.attuneText then frame.attuneText:SetText("") end
        end
    end

    print("|cff00ff00AttuneProgress|r: All displays cleared!")
end

-- Force a refresh on all currently displayed items
function AttuneProgress:ForceUpdateAllDisplays()
    -- Update container frames
    for i = 1, NUM_CONTAINER_FRAMES do
        if _G["ContainerFrame" .. i] and _G["ContainerFrame" .. i]:IsVisible() then
            for j = 1, 36 do
                local frame = _G["ContainerFrame" .. i .. "Item" .. j]
                if frame then
                    local itemLink = GetContainerItemLink(i, j)
                    UpdateItemDisplay(frame, itemLink)
                end
            end
        end
    end

    -- Update ElvUI container frames
    for bag = 0, 4 do
        for slot = 1, 36 do
            local frameName = "ElvUI_ContainerFrameBag" .. bag .. "Slot" .. slot
            local frame = _G[frameName]
            if frame then
                local itemLink = GetContainerItemLink(bag, slot)
                UpdateItemDisplay(frame, itemLink)
            end
        end
    end

    -- Update AdiBags frames
    for i = 1, #AdiBagsSlots do
        local frameName = AdiBagsSlots[i]
        local frame = _G[frameName]
        if frame then
            -- Let the OnUpdate handler determine the item link
            AdiBags_OnUpdate(frame, 0.1) -- Force an immediate update
        end
    end

    -- Update Bagnon Guild Bank frames
    if _G.BagnonFrameguildbank and _G.BagnonFrameguildbank:IsVisible() then
        for i = 1, #BagnonGuildBankSlots do
            local frameName = BagnonGuildBankSlots[i]
            local frame = _G[frameName]
            if frame then
                -- We'll let the OnUpdate handler determine the item link
                -- since it has the logic for multiple methods
                BagnonGuildBank_OnUpdate(frame, 0.1) -- Force an immediate update
            end
        end
    end
end

-- Slash Commands
SLASH_ATTUNEPROGRESS1 = "/attuneprogress"
SLASH_ATTUNEPROGRESS2 = "/ap"
SlashCmdList["ATTUNEPROGRESS"] = function(msg)
    local cmd = string.lower(msg or "")

    if cmd == "reload" or cmd == "r" then
        AttuneProgress:Initialize()
        print("|cff00ff00AttuneProgress|r: Reloaded!")
    elseif cmd == "refresh" or cmd == "re" then
        AttuneProgress:ForceUpdateAllDisplays()
        print("|cff00ff00AttuneProgress|r: All displays refreshed!")
    elseif cmd == "options" or cmd == "config" then
        InterfaceOptionsFrame_OpenToCategory(CONST_ADDON_NAME)
    elseif cmd == "acc" then
        Settings.showAccountAttuneText = not Settings.showAccountAttuneText
        SaveSettings() -- Save the change
        print(
            string.format(
                "|cff00ff00AttuneProgress|r: Show 'Acc' text for account attunable items %s.",
                Settings.showAccountAttuneText and "enabled" or "disabled"
            )
        )
        AttuneProgress:ForceUpdateAllDisplays()
    elseif cmd == "fae" then
        Settings.faeMode = not Settings.faeMode
        SaveSettings() -- Save the change
        print(
            string.format(
                "|cff00ff00AttuneProgress|r: Fae Mode %s.",
                Settings.faeMode and "enabled" or "disabled"
            )
        )
        AttuneProgress:ForceUpdateAllDisplays()
    else
        print("|cff00ff00AttuneProgress|r Commands:")
        print("  /ap refresh - Refresh all item displays")
        print("  /ap acc - Toggle 'Acc' text for account-attunable items")
        print("  /ap fae - Toggle Fae Mode (show bars even at 100%)")
        print("  /ap options - Open options panel")
        print("")
        print("You can also access options via Interface > AddOns > " .. CONST_ADDON_NAME)
    end
end

-- Legacy function for compatibility (now just calls refresh)
function AttuneProgress:Toggle()
    AttuneProgress:ForceUpdateAllDisplays()
end