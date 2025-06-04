--[[
AttuneProgress - Enhanced Item Attunement Progress Display
Features:
- Visual progress bars for attunement progress (vertical bars)
- Red bars for items not attunable by character (configurable)
- Bounty icons for bountied items
- Account-attunable indicators
--]]

local WHITE_TEX = "Interface\\Buttons\\WHITE8X8"

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
    scanEquipped = false,
    excludeEquippedBars  = false,

    progressBarColor = { r = 0, g = 1.0, b = 0.0, a = 1.0 },
    
    -- Color settings (RGB values 0-1)
    forgeColors = {
        BASE        = { r = 0,   g = 1.0,   b = 0.0,   a = 1.0 }, -- green
        TITANFORGED = { r = 0.468, g = 0.532, b = 1.000, a = 1.0 }, -- #B6C1FF
        WARFORGED   = { r = 0.872, g = 0.206, b = 0.145, a = 1.0 }, -- #F07D6A
        LIGHTFORGED = { r = 0.527, g = 0.527, b = 0.266, a = 1.0 }, -- #C0C08D
      },

    nonAttunableBarColor = {r = 1.0, g = 0.0, b = 0.0}, -- Red
    textColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
}
local FORGE_LEVEL_MAP   = { BASE = 0, TITANFORGED = 1, WARFORGED = 2, LIGHTFORGED = 3 }
local ForgeLevelNames   = { [0] = 'BASE', [1] = 'TITANFORGED', [2] = 'WARFORGED', [3] = 'LIGHTFORGED' }
local function GetForgeLevelFromLink(itemLink)  -- ★ NEW
    if not itemLink or not _G.GetItemLinkTitanforge then return FORGE_LEVEL_MAP.BASE end
    local val = GetItemLinkTitanforge(itemLink)
    for _, known in pairs(FORGE_LEVEL_MAP) do
        if val == known then return val end
    end
    return FORGE_LEVEL_MAP.BASE
end

local function CopyTable(src)
    if type(src) ~= 'table' then return src end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == 'table' then
            dst[k] = CopyTable(v) -- Recursive deep copy
        else
            dst[k] = v
        end
    end
    return dst
end

local Settings = {}
local CheckboxTooltips = {
    showRedForNonAttunable =
        "Display red bars for items attunable by your account but not by this character.\nHeight indicates attunement progress.",
    showBountyIcons =
        "Show a gold icon on items that currently have a bounty.",
    showAccountIcons =
        "Show a blue square for items attunable by your account but not by this character.",
    showProgressText =
        "Display the numeric percentage on each progress bar.",
    showAccountAttuneText =
        "Display 'Acc' text on items attunable by account only.",
    faeMode =
        "Fae Mode: Always show progress bars, even when they are at 100%.",
    scanEquipped =
        "Scan your equipped gear and display attunement bars on the character frame slots.",
    excludeEquippedBars =
        "Suppress attunement progress **bars** on equipped-gear slots\n" ..
        "(icons and text will still show on hover).",
}

local EquipmentSlotMapping = {
    { id = INVSLOT_HEAD,           frame = "CharacterHeadSlot"       },
    { id = INVSLOT_NECK,           frame = "CharacterNeckSlot"       },
    { id = INVSLOT_SHOULDER,       frame = "CharacterShoulderSlot"   },
    { id = INVSLOT_BACK,           frame = "CharacterBackSlot"       },
    { id = INVSLOT_CHEST,          frame = "CharacterChestSlot"      },
    { id = INVSLOT_WRIST,          frame = "CharacterWristSlot"      },
    { id = INVSLOT_HAND,           frame = "CharacterHandsSlot"      },
    { id = INVSLOT_WAIST,          frame = "CharacterWaistSlot"      },
    { id = INVSLOT_LEGS,           frame = "CharacterLegsSlot"       },
    { id = INVSLOT_FEET,           frame = "CharacterFeetSlot"       },
    { id = INVSLOT_FINGER1,        frame = "CharacterFinger0Slot"    },
    { id = INVSLOT_FINGER2,        frame = "CharacterFinger1Slot"    },
    { id = INVSLOT_TRINKET1,       frame = "CharacterTrinket0Slot"   },
    { id = INVSLOT_TRINKET2,       frame = "CharacterTrinket1Slot"   },
    { id = INVSLOT_MAINHAND,       frame = "CharacterMainHandSlot"   },
    { id = INVSLOT_SECONDARYHAND,  frame = "CharacterSecondaryHandSlot" },
    { id = INVSLOT_RANGED,         frame = "CharacterRangedSlot"     },
}
-- Function to save current settings
local function SaveSettings()
    if not AttuneProgressDB then AttuneProgressDB = {} end
    
    -- Clear existing to prevent stale data
    wipe(AttuneProgressDB)
    
    -- Deep copy current settings
    for key, val in pairs(Settings) do
        AttuneProgressDB[key] = CopyTable(val)
    end
end

local function CreateColorPicker(parent, label, tbl, key, anchor, yOffset)
    -- the button/frame that holds the swatch
    local sw = CreateFrame("Button", nil, parent)
    sw:SetSize(20,20)
    sw:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
  
    -- background border (optional)
    sw.bg = sw:CreateTexture(nil,"BACKGROUND")
    sw.bg:SetAllPoints(sw)
    sw.bg:SetTexture(0,0,0,1)       -- solid black
  
    -- the actual color swatch
    sw.tex = sw:CreateTexture(nil,"ARTWORK")
    sw.tex:SetAllPoints(sw)
    sw.tex:SetTexture(WHITE_TEX)    -- a 1×1 white pixel
    sw.tex:SetVertexColor(
      tbl[key].r,
      tbl[key].g,
      tbl[key].b,
      tbl[key].a
    )
  
    -- label
    local txt = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    txt:SetPoint("LEFT", sw, "RIGHT", 5, 0)
    txt:SetText(label)
  
    sw:SetScript("OnClick", function()
      local function updateSwatch()
        local r,g,b = ColorPickerFrame:GetColorRGB()
        local a     = OpacitySliderFrame:GetValue()
        tbl[key].r, tbl[key].g, tbl[key].b, tbl[key].a = r,g,b,a
        sw.tex:SetVertexColor(r,g,b,a)
        SaveSettings()
        AttuneProgress:ForceUpdateAllDisplays()
      end
  
      ColorPickerFrame.hasOpacity  = true
      ColorPickerFrame.opacity     = tbl[key].a
      ColorPickerFrame.func        = updateSwatch
      ColorPickerFrame.opacityFunc = updateSwatch
      ColorPickerFrame:SetColorRGB(tbl[key].r, tbl[key].g, tbl[key].b)
      OpacitySliderFrame:SetValue(tbl[key].a)
      ColorPickerFrame:Show()
    end)
  
    return sw
  end

-- lookup table for quick detection of CharacterFrame slots
local EquipFrameLookup = {}
for _, info in ipairs(EquipmentSlotMapping) do
  EquipFrameLookup[info.frame] = true
end

local function LoadSettings()
    if not AttuneProgressDB then AttuneProgressDB = {} end

    -- Start with a deep copy of defaults
    Settings = CopyTable(DefaultSettings)

    -- Override with saved settings (deep merge)
    for key, val in pairs(AttuneProgressDB) do
        if type(val) == 'table' and type(Settings[key]) == 'table' then
            -- Deep merge nested tables
            for sub, subval in pairs(val) do
                if type(subval) == 'table' and type(Settings[key][sub]) == 'table' then
                    for subsub, subsubval in pairs(subval) do
                        Settings[key][sub][subsub] = subsubval
                    end
                else
                    Settings[key][sub] = subval
                end
            end
        else
            Settings[key] = val
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
for i = 1, 280 do
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
    local frameName = frame:GetName() -- Get the name of the frame for unique child names

    -- Names for dynamically created frames
    local progressName = frameName .. '_attuneBar'
    local textHostFrameName = frameName .. '_attuneTextHost' -- Unique name for the text host

    -- Attempt to get existing frames
    local progFrame = _G[progressName]
    -- We'll store textHostFrame on 'frame' to avoid potential global name collisions
    -- and make it instance-specific if this function is called for multiple frames.

    -- Initialize Text Host Frame and FontString ONCE per 'frame'
    if not frame.textHostFrame then
        -- Create a dedicated host frame for the text
        frame.textHostFrame = CreateFrame('Frame', textHostFrameName, frame)
        frame.textHostFrame:SetAllPoints(frame) -- Make it cover the parent item frame completely

        -- Set FrameLevel:
        -- progFrame is frame:GetFrameLevel() + 1
        -- progFrame.child is progFrame:GetFrameLevel() + 1 = (frame:GetFrameLevel() + 1) + 1 = frame:GetFrameLevel() + 2
        -- So, textHostFrame needs to be at least frame:GetFrameLevel() + 3 to be on top.
        frame.textHostFrame:SetFrameLevel(frame:GetFrameLevel() + 3)

        -- Create FontString as a child of the new textHostFrame
        frame.attuneText = frame.textHostFrame:CreateFontString(nil, 'OVERLAY', CONFIG.TEXT.FONT)
        -- Position the text. Original was ('BOTTOM', frame, 'BOTTOM', 0, 1).
        -- Since textHostFrame overlays 'frame', this can be relative to textHostFrame.
        -- Adjust the Y-offset (last parameter) as needed for desired vertical placement.
        -- This will place text at the bottom of the item icon, but on top of the bar.
        frame.attuneText:SetPoint('BOTTOM', frame.textHostFrame, 'BOTTOM', 0, 3) -- Using 3px offset as an example
    end

    -- Ensure attuneText is available (it should be if textHostFrame was created)
    if not frame.attuneText then
        -- This would indicate an issue, but as a fallback:
        if frame.textHostFrame then
             frame.attuneText = frame.textHostFrame:CreateFontString(nil, 'OVERLAY', CONFIG.TEXT.FONT)
             frame.attuneText:SetPoint('BOTTOM', frame.textHostFrame, 'BOTTOM', 0, 3)
        else
            -- If textHostFrame doesn't exist, something is very wrong.
            -- WoW API errors might appear in chat here.
            return
        end
    end

    -- Set text color (applies to frame.attuneText)
    frame.attuneText:SetTextColor(
        Settings.textColor.r,
        Settings.textColor.g,
        Settings.textColor.b,
        Settings.textColor.a
    )
    frame.attuneText:SetText('') -- Clear text initially

    -- Hide progress bar initially
    if progFrame then progFrame:Hide() end

    -- Early exit if no itemLink or itemId
    if not itemLink or not itemId then
        frame.attuneText:Hide() -- Ensure text is hidden if no item
        return
    end

    local charOK   = IsItemValid(itemId)
    local accOK    = IsAttunableByAccount(itemId)
    local progress = GetAttuneProgress(itemLink) or 0
    local showBar, barCol = false, {}

    -- Determine if bar should be shown and its color, and set progress text
    if charOK then
        if Settings.faeMode or progress < 100 then
            showBar = true
            local fl = GetForgeLevelFromLink(itemLink)
            local key = ForgeLevelNames[fl] or 'BASE'
            barCol = Settings.forgeColors[key]
            if Settings.showProgressText then
                frame.attuneText:SetText(string.format('%.0f%%', progress))
            end
        end
    elseif Settings.showRedForNonAttunable and accOK then -- Note: original code had elseif, implying charOK is false
        if progress > 0  then
            showBar = true
            barCol  = Settings.nonAttunableBarColor
            if Settings.showProgressText then
                frame.attuneText:SetText(string.format('%.0f%%', progress))
            end
        end
    end

    -- Set "Acc" text if applicable (can override previous text)
    if Settings.showAccountAttuneText and progress < 100 and not(charOK) and accOK then
        frame.attuneText:SetText('Acc')
    end

    -- Suppress bar on equipped items if requested
    local currentFrameName = frame:GetName() -- Use local var for clarity
    if EquipFrameLookup[currentFrameName] and Settings.excludeEquippedBars then
        showBar = false
    end

    -- Show or hide progress bar and text
    if showBar then
        if not progFrame then
            progFrame = CreateFrame('Frame', progressName, frame)
            progFrame:SetWidth(CONFIG.PROGRESS_BAR.WIDTH + 2)
            progFrame:SetFrameLevel(frame:GetFrameLevel() + 1) -- Bar background/border
            _G[progressName] = progFrame -- Store globally if other parts of the addon access it by name

            progFrame.texture = progFrame:CreateTexture(nil,'OVERLAY')
            progFrame.texture:SetAllPoints()
            progFrame.texture:SetTexture(
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[1],
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[2],
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[3],
                CONFIG.PROGRESS_BAR.BACKGROUND_COLOR[4]
            )

            progFrame.child = CreateFrame('Frame', progressName..'Child', progFrame)
            progFrame.child:SetWidth(CONFIG.PROGRESS_BAR.WIDTH)
            progFrame.child:SetFrameLevel(progFrame:GetFrameLevel()+1) -- Bar fill (effectively frame:GetFrameLevel() + 2)

            -- Corrected SetPoint for 1px border effect (original was -1,-1)
            progFrame.child:SetPoint('BOTTOMLEFT', progFrame, 'BOTTOMLEFT', 1, 1)

            progFrame.child.texture = progFrame.child:CreateTexture(nil,'OVERLAY')
            progFrame.child.texture:SetAllPoints()
        end

        -- Set parent and position for progFrame (might be redundant if already parented, but safe)
        progFrame:SetParent(frame)
        progFrame:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 2, 2)

        -- Calculate height for the progress bar
        local h = math.max(
            frame:GetHeight() * CONFIG.PROGRESS_BAR.MIN_HEIGHT_PERCENT
            + (progress / 100)
            * (frame:GetHeight() * (CONFIG.PROGRESS_BAR.MAX_HEIGHT_PERCENT - CONFIG.PROGRESS_BAR.MIN_HEIGHT_PERCENT)),
            frame:GetHeight() * CONFIG.PROGRESS_BAR.MIN_HEIGHT_PERCENT
        )
        progFrame:SetHeight(h)
        progFrame.child:SetHeight(h-2) -- Child height for 1px border top/bottom

        -- Apply the chosen color to the bar fill
        if barCol and barCol.r then -- Ensure barCol is valid
            progFrame.child.texture:SetTexture(
                barCol.r, barCol.g, barCol.b, barCol.a
            )
        else
            -- Default color or error handling if barCol is not set as expected
            progFrame.child.texture:SetTexture(0.5, 0.5, 0.5, 1) -- Grey fallback
        end
        progFrame:Show()

        -- Show text if it has content
        if frame.attuneText:GetText() and frame.attuneText:GetText() ~= "" then
            frame.attuneText:Show()
        else
            frame.attuneText:Hide()
        end

    else -- showBar is false
        if progFrame then progFrame:Hide() end

        -- Show text if it has content (e.g., "Acc" text), even if bar is hidden
        if frame.attuneText:GetText() and frame.attuneText:GetText() ~= "" then
            frame.attuneText:Show()
        else
            frame.attuneText:Hide()
        end
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
        local cb = CreateFrame("CheckButton", checkboxName, parent,
                               "InterfaceOptionsCheckButtonTemplate")
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
            SaveSettings()
            AttuneProgress:ForceUpdateAllDisplays()
        end)
    
        -- NEW: tooltip on hover
        local tip = CheckboxTooltips[settingKey]
        if tip then
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(text, 1, 1, 1)
                GameTooltip:AddLine(tip, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
        end
    
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
    lastElement = CreateCheckbox(
    panel,
    "Scan equipped gear",
    "scanEquipped",
    lastElement,
    -10
    )

    lastElement = CreateCheckbox(
      panel,
      "Exclude bars from equipped gear",
      "excludeEquippedBars",
      lastElement,
      -10
    )


    -- Description
    --[[--
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
    --]]--

    -- Add to Blizzard Interface Options
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

local function CreateColorOptionsPanel()
    local cp = CreateFrame("Frame")
    cp.name   = 'Colors'
    cp.parent = CONST_ADDON_NAME
  
    local header = cp:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
    header:SetPoint('TOPLEFT', 16, -16)
    header:SetText(CONST_ADDON_NAME .. ' - Color Settings')
  
    local lastSwatch = header
    local SPACING    = -28
  
    -- first: account‐attunable bar colour
    lastSwatch = CreateColorPicker(
      cp,
      'Account-attunable bar colour',
      Settings,
      'nonAttunableBarColor',
      lastSwatch,
      SPACING
    )
  
    -- then each forge‐tier
    for lvl = 0, 3 do
      local key   = ForgeLevelNames[lvl]
      local label = key:lower():gsub("^%l", string.upper) .. ' bar colour'
      lastSwatch = CreateColorPicker(
        cp,
        label,
        Settings.forgeColors,
        key,
        lastSwatch,
        SPACING
      )
    end
  
    -- finally global text colour
    lastSwatch = CreateColorPicker(
      cp,
      'Global text colour',
      Settings,
      'textColor',
      lastSwatch,
      SPACING
    )
  
    InterfaceOptions_AddCategory(cp)
    return cp
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

-- Event Management (updated)
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == CONST_ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        
        LoadSettings()
        
        DelayedCall(0.1, function()
            AttuneProgress:Initialize()
        end)
    elseif event == "BAG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        -- Force refresh on bag updates and world entering
        --DelayedCall(0.1, function()
            AttuneProgress:ForceUpdateAllDisplays()
        --end)
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            AttuneProgress:ForceUpdateAllDisplays()
        end
    end
end
local eventFrame = CreateFrame("Frame", "AttuneProgressEventFrame", UIParent)
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
-- Main Functions
function AttuneProgress:Initialize()
    print("|cff00ff00AttuneProgress|r: Initializing...")

    LoadSettings()
    UpdateConfigColors() -- lol
    CreateOptionsPanel()
    CreateColorOptionsPanel()    
    AttuneProgress:EnableUpdates()
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
    if Settings.scanEquipped then
        for _, info in ipairs(EquipmentSlotMapping) do
            local slotFrame = _G[info.frame]
            if slotFrame then
                local link = GetInventoryItemLink("player", info.id)
                UpdateItemDisplay(slotFrame, link)
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