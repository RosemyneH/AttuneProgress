local WHITE_TEX = "Interface\\Buttons\\WHITE8X8"

local CONST_ADDON_NAME = 'AttuneProgress'
AttuneProgress = {}

-- Animation and update timing
local LERP_SPEED = 0.15  -- Much slower for smooth animation
local TEXT_LERP_SPEED = 0.2  -- Separate speed for text animation
local COMBAT_UPDATE_INTERVAL = 1 -- 1fps gaming OWO
local combatUpdateTimer = 0
local combatUpdateFrame = nil

-- Store animation data for each frame
local frameAnimationData = {}
local Settings = {}

local DefaultSettings = {
    showRedForNonAttunable = true,
    showBountyIcons = true,
    showAccountIcons = false,
    showProgressText = true,
    showAccountAttuneText = false,
    faeMode = false,
    scanEquipped = false,
    excludeEquippedBars  = false,
    
    -- NEW: Animation settings
    enableAnimations = true,
    animationSpeed = 0.15,
    enableTextAnimations = true,
    textAnimationSpeed = 0.2,

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
    enableAnimations = 
        "Enable smooth animations for progress bars when values change.",
    enableTextAnimations =
        "Enable smooth animations for progress text numbers.",
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
    { id = INVSLOT_OFFHAND,  frame = "CharacterSecondaryHandSlot" },
    { id = INVSLOT_RANGED,         frame = "CharacterRangedSlot"     },
}

local function CreateCombatUpdateFrame()
    if combatUpdateFrame then return end
    
    combatUpdateFrame = CreateFrame("Frame")
    combatUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
        combatUpdateTimer = combatUpdateTimer + elapsed
        if combatUpdateTimer >= COMBAT_UPDATE_INTERVAL then
            combatUpdateTimer = 0
            AttuneProgress:ForceUpdateAllDisplays()
        end
    end)
    combatUpdateFrame:Show()
end

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
        MIN_HEIGHT_PERCENT = 0.2,
        MAX_HEIGHT_PERCENT = 0.9,
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
    local frameName = frame:GetName()

    -- Names for dynamically created frames
    local progressName = frameName .. '_attuneBar'
    local textHostFrameName = frameName .. '_attuneTextHost'

    -- Get existing frames
    local progFrame = _G[progressName]

    -- Initialize Text Host Frame and FontString ONCE per 'frame'
    if not frame.textHostFrame then
        frame.textHostFrame = CreateFrame('Frame', textHostFrameName, frame)
        frame.textHostFrame:SetAllPoints(frame)
        frame.textHostFrame:SetFrameLevel(frame:GetFrameLevel() + 3)

        frame.attuneText = frame.textHostFrame:CreateFontString(nil, 'OVERLAY', CONFIG.TEXT.FONT)
        frame.attuneText:SetPoint('BOTTOM', frame.textHostFrame, 'BOTTOM', 0, 3)
    end

    if not frame.attuneText then
        if frame.textHostFrame then
             frame.attuneText = frame.textHostFrame:CreateFontString(nil, 'OVERLAY', CONFIG.TEXT.FONT)
             frame.attuneText:SetPoint('BOTTOM', frame.textHostFrame, 'BOTTOM', 0, 3)
        else
            return
        end
    end

    -- Set text color
    frame.attuneText:SetTextColor(
        Settings.textColor.r,
        Settings.textColor.g,
        Settings.textColor.b,
        Settings.textColor.a
    )
    frame.attuneText:SetText('')

    -- Hide progress bar initially
    if progFrame then progFrame:Hide() end

    -- Early exit if no itemLink or itemId
    if not itemLink or not itemId then
        frame.attuneText:Hide()
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
        end
    elseif Settings.showRedForNonAttunable and accOK then
        if progress > 0  then
            showBar = true
            barCol  = Settings.nonAttunableBarColor
        end
    end

    -- Suppress bar on equipped items if requested
    local currentFrameName = frame:GetName()
    if EquipFrameLookup[currentFrameName] and Settings.excludeEquippedBars then
        showBar = false
    end

    -- Show or hide progress bar and text
    if showBar then
        if not progFrame then
            progFrame = CreateFrame('Frame', progressName, frame)
            progFrame:SetWidth(CONFIG.PROGRESS_BAR.WIDTH + 2)
            progFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
            _G[progressName] = progFrame

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
            progFrame.child:SetFrameLevel(progFrame:GetFrameLevel()+1)
            progFrame.child:SetPoint('BOTTOMLEFT', progFrame, 'BOTTOMLEFT', 0, 1)

            progFrame.child.texture = progFrame.child:CreateTexture(nil,'OVERLAY')
            progFrame.child.texture:SetAllPoints()

            -- Initialize animation data
            frameAnimationData[frameName] = {
                currentHeight = 0,
                targetHeight = 0,
                isAnimating = false,
                currentProgress = progress, -- Initialize with current progress
                targetProgress = progress,
                isTextAnimating = false,
                textStepTimer = 0,
                textStepInterval = 0.1
            }
        end

        progFrame:SetParent(frame)
        progFrame:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 2, 2)

        -- Calculate target height for the progress bar
        local targetHeight = math.max(
            frame:GetHeight() * CONFIG.PROGRESS_BAR.MIN_HEIGHT_PERCENT
            + (progress / 100)
            * (frame:GetHeight() * (CONFIG.PROGRESS_BAR.MAX_HEIGHT_PERCENT - CONFIG.PROGRESS_BAR.MIN_HEIGHT_PERCENT)),
            frame:GetHeight() * CONFIG.PROGRESS_BAR.MIN_HEIGHT_PERCENT
        )

        -- Initialize animation data if not exists
        if not frameAnimationData[frameName] then
            frameAnimationData[frameName] = {
                currentHeight = targetHeight,
                targetHeight = targetHeight,
                isAnimating = false,
                currentProgress = progress,
                targetProgress = progress,
                isTextAnimating = false,
                textStepTimer = 0,
                textStepInterval = 0.1
            }
        end

        local animData = frameAnimationData[frameName]

        -- Check if we need to animate height
        if Settings.enableAnimations and math.abs(animData.targetHeight - targetHeight) > 1 then
            animData.targetHeight = targetHeight
            animData.isAnimating = true
        else
            -- No animation or small change, set directly
            animData.currentHeight = targetHeight
            animData.targetHeight = targetHeight
            animData.isAnimating = false
        end

        -- FIXED: Text stepping animation
        if Settings.enableTextAnimations and Settings.showProgressText and math.abs(animData.targetProgress - progress) > 0.1 then
            animData.targetProgress = progress
            animData.isTextAnimating = true
            -- Reset stepping data for integer animation
            animData.textStepTimer = 0
            animData.textStepInterval = 1 / (Settings.textAnimationSpeed * 20) -- Steps per second
        else
            -- No animation or small change, set directly
            animData.currentProgress = progress
            animData.targetProgress = progress
            animData.isTextAnimating = false
        end

        -- Create or update animation OnUpdate
        if (animData.isAnimating or animData.isTextAnimating) and not progFrame.animationScript then
            progFrame.animationScript = true
            progFrame:SetScript("OnUpdate", function(self, elapsed)
                local data = frameAnimationData[frameName]
                if not data then
                    self:SetScript("OnUpdate", nil)
                    self.animationScript = nil
                    return
                end

                local stillAnimating = false

                -- Animate height
                if data.isAnimating then
                    local heightDiff = data.targetHeight - data.currentHeight
                    if math.abs(heightDiff) < 0.1 then
                        -- Close enough, snap to target
                        data.currentHeight = data.targetHeight
                        data.isAnimating = false
                    else
                        -- Smooth lerp using configurable speed
                        local lerpSpeed = Settings.animationSpeed or 0.15
                        data.currentHeight = data.currentHeight + (heightDiff * lerpSpeed * (elapsed * 60)) -- Normalize for 60fps
                        stillAnimating = true
                    end

                    -- Apply the height
                    self:SetHeight(data.currentHeight)
                    self.child:SetHeight(math.max(data.currentHeight - 2, 0))
                end

                -- FIXED: Animate text (integer stepping)
                if data.isTextAnimating then
                    data.textStepTimer = data.textStepTimer + elapsed
                    
                    if data.textStepTimer >= data.textStepInterval then
                        data.textStepTimer = 0
                        
                        -- Determine direction and step by 1
                        if data.currentProgress < data.targetProgress then
                            data.currentProgress = math.min(data.currentProgress + 1, data.targetProgress)
                        elseif data.currentProgress > data.targetProgress then
                            data.currentProgress = math.max(data.currentProgress - 1, data.targetProgress)
                        end
                        
                        -- Update the text display immediately during animation
                        if frame.attuneText then
                            frame.attuneText:SetText(string.format('%.0f%%', data.currentProgress))
                        end
                        
                        -- Check if we've reached the target
                        if math.abs(data.currentProgress - data.targetProgress) < 0.1 then
                            data.currentProgress = data.targetProgress
                            data.isTextAnimating = false
                        else
                            stillAnimating = true
                        end
                    else
                        stillAnimating = true
                    end
                end

                -- Stop animation if nothing is animating
                if not stillAnimating then
                    self:SetScript("OnUpdate", nil)
                    self.animationScript = nil
                end
            end)
        elseif not animData.isAnimating and not animData.isTextAnimating then
            -- Set heights directly if not animating
            progFrame:SetHeight(animData.currentHeight)
            progFrame.child:SetHeight(math.max(animData.currentHeight - 2, 0))
        end

        -- Apply the chosen color to the bar fill
        if barCol and barCol.r then
            progFrame.child.texture:SetTexture(
                barCol.r, barCol.g, barCol.b, barCol.a
            )
        else
            progFrame.child.texture:SetTexture(0.5, 0.5, 0.5, 1)
        end
        progFrame:Show()

        -- Handle text display
        if Settings.showProgressText and (charOK or (Settings.showRedForNonAttunable and accOK and progress > 0)) then
            -- Use animated progress if available, otherwise use actual progress
            local displayProgress = frameAnimationData[frameName] and frameAnimationData[frameName].currentProgress or progress
            frame.attuneText:SetText(string.format('%.0f%%', displayProgress))
            frame.attuneText:Show()
        elseif Settings.showAccountAttuneText and progress < 100 and not(charOK) and accOK then
            frame.attuneText:SetText('Acc')
            frame.attuneText:Show()
        else
            frame.attuneText:Hide()
        end

    else -- showBar is false
        if progFrame then progFrame:Hide() end

        -- Show text if it has content
        if Settings.showAccountAttuneText and progress < 100 and not(charOK) and accOK then
            frame.attuneText:SetText('Acc')
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

function AttuneProgress:RefreshOptionsPanel()
    -- Update checkbox states after settings are loaded
    local checkboxMappings = {
        "showRedForNonAttunable",
        "showBountyIcons", 
        "showAccountIcons",
        "showProgressText",
        "showAccountAttuneText",
        "faeMode",
        "scanEquipped",
        "excludeEquippedBars"
    }
    
    for _, settingKey in ipairs(checkboxMappings) do
        local checkbox = _G["AttuneProgressCheckbox_" .. settingKey]
        if checkbox then
            checkbox:SetChecked(Settings[settingKey])
        end
    end
    
    -- Update animation panel checkboxes (separate naming)
    local animCheckboxMappings = {
        "enableAnimations",
        "enableTextAnimations"
    }
    
    for _, settingKey in ipairs(animCheckboxMappings) do
        local checkbox = _G["AttuneProgressAnimCheckbox_" .. settingKey]
        if checkbox then
            checkbox:SetChecked(Settings[settingKey])
        end
    end
    
    -- Update sliders
    local slider = _G["AttuneProgressSlider_animationSpeed"]
    if slider then
        slider:SetValue(Settings.animationSpeed)
    end
    
    slider = _G["AttuneProgressSlider_textAnimationSpeed"]
    if slider then
        slider:SetValue(Settings.textAnimationSpeed)
    end
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

local function CreateSlider(parent, text, settingKey, minVal, maxVal, step, anchor, yOffset)
    local slider = CreateFrame("Slider", "AttuneProgressSlider_" .. settingKey, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(Settings[settingKey])
    slider:SetWidth(200)
    
    -- Set slider labels
    local sliderName = slider:GetName()
    _G[sliderName .. "Low"]:SetText(tostring(minVal))
    _G[sliderName .. "High"]:SetText(tostring(maxVal))
    _G[sliderName .. "Text"]:SetText(text .. ": " .. string.format("%.2f", Settings[settingKey]))
    
    slider:SetScript("OnValueChanged", function(self, value)
        Settings[settingKey] = value
        _G[sliderName .. "Text"]:SetText(text .. ": " .. string.format("%.2f", value))
        SaveSettings()
        -- Update the global lerp speeds
        if settingKey == "animationSpeed" then
            LERP_SPEED = value
        elseif settingKey == "textAnimationSpeed" then
            TEXT_LERP_SPEED = value
        end
    end)
    
    return slider
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
            Settings[settingKey] = not not self:GetChecked()
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

local function CreateAnimationOptionsPanel()
    local ap = CreateFrame("Frame")
    ap.name = 'Animation Settings'
    ap.parent = CONST_ADDON_NAME
    
    local header = ap:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
    header:SetPoint('TOPLEFT', 16, -16)
    header:SetText(CONST_ADDON_NAME .. ' - Animation Settings')
    
    local lastElement = header
    
    -- Animation checkboxes
    local function CreateAnimationCheckbox(parent, text, settingKey, anchorFrame, offsetY)
        local checkboxName = "AttuneProgressAnimCheckbox_" .. settingKey
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
            Settings[settingKey] = not not self:GetChecked()
            SaveSettings()
            AttuneProgress:ForceUpdateAllDisplays()
        end)
    
        -- Tooltip
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
    
    -- Animation enable checkboxes
    lastElement = CreateAnimationCheckbox(
        ap,
        "Enable smooth bar animations",
        "enableAnimations",
        lastElement,
        -30
    )

    lastElement = CreateAnimationCheckbox(
        ap,
        "Enable text number animations (counts up/down)",
        "enableTextAnimations",
        lastElement,
        -10
    )
    
    -- Animation speed sliders
    lastElement = CreateSlider(
        ap,
        "Bar Animation Speed",
        "animationSpeed",
        0.05, 1.0, 0.05,
        lastElement,
        -40
    )

    lastElement = CreateSlider(
        ap,
        "Text Animation Speed (steps per second)", 
        "textAnimationSpeed",
        0.1, 2.0, 0.1,
        lastElement,
        -60
    )
    
    -- Description
    local description = ap:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -40)
    description:SetWidth(500)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Animation Settings:\n\n" ..
        "• Bar animations smoothly transition progress bar heights\n" ..
        "• Text animations count up/down in whole numbers (30,31,32,33...)\n" ..
        "• Higher animation speeds = faster transitions\n" ..
        "• Text speed controls how many numbers per second it counts\n\n" ..
        "Disable animations if you prefer instant updates or experience \nperformance issues."
    )
    
    InterfaceOptions_AddCategory(ap)
    return ap
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
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == CONST_ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        
        -- LoadSettings()
        
        DelayedCall(0.1, function()
            AttuneProgress:Initialize()
        end)
    elseif event == "VARIABLES_LOADED" then
        -- NOW SavedVariables are loaded
        self:UnregisterEvent("VARIABLES_LOADED")
        LoadSettings()
        
        -- Refresh any UI that might have been created already
        if _G["AttuneProgressCheckbox_showRedForNonAttunable"] then
            AttuneProgress:RefreshOptionsPanel()
        end
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
eventFrame:RegisterEvent("VARIABLES_LOADED")

-- Main Functions
function AttuneProgress:Initialize()
    print("|cff00ff00AttuneProgress|r: Initializing...")

    UpdateConfigColors()
    CreateOptionsPanel()
    CreateColorOptionsPanel()
    CreateAnimationOptionsPanel()
    AttuneProgress:EnableUpdates()
    CreateCombatUpdateFrame()
    PeriodicFrameHooking()

    print(
        "|cff00ff00AttuneProgress|r: Use /ap for commands or check Interface > AddOns > " ..
            CONST_ADDON_NAME .. " for options."
    )
    
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
    -- Instead of immediately updating, let the natural OnUpdate cycle handle it
    -- This prevents drawing with stale GetContainerItemLink data
    
    -- Just trigger the frames to update on their next OnUpdate cycle
    for i = 1, NUM_CONTAINER_FRAMES do
        if _G["ContainerFrame" .. i] and _G["ContainerFrame" .. i]:IsVisible() then
            for j = 1, 36 do
                local frame = _G["ContainerFrame" .. i .. "Item" .. j]
                if frame then
                    -- Reset the update timer to force immediate update on next cycle
                    frame.attuneLastUpdate = 0.1 -- Force update on next OnUpdate
                end
            end
        end
    end

    -- Do the same for other frame types
    for bag = 0, 4 do
        for slot = 1, 36 do
            local frameName = "ElvUI_ContainerFrameBag" .. bag .. "Slot" .. slot
            local frame = _G[frameName]
            if frame then
                frame.attuneLastUpdate = 0.1
            end
        end
    end

    for i = 1, #AdiBagsSlots do
        local frameName = AdiBagsSlots[i]
        local frame = _G[frameName]
        if frame then
            frame.attuneLastUpdate = 0.1
        end
    end

    if _G.BagnonFrameguildbank and _G.BagnonFrameguildbank:IsVisible() then
        for i = 1, #BagnonGuildBankSlots do
            local frameName = BagnonGuildBankSlots[i]
            local frame = _G[frameName]
            if frame then
                frame.attuneLastUpdate = 0.1
            end
        end
    end

    if Settings.scanEquipped then
        for _, info in ipairs(EquipmentSlotMapping) do
            local slotFrame = _G[info.frame]
            if slotFrame then
                -- For equipped gear, we can update immediately since GetInventoryItemLink is reliable
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