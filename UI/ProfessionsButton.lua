-- UI/ProfessionsButton.lua
-- Injects a "Missing Recipes" button into the Blizzard ProfessionsFrame.
-- Profession info is cached on TRADE_SKILL_LIST_UPDATE (not TRADE_SKILL_SHOW)
-- because GetBaseProfessionInfo() is only reliable after the recipe list loads.

MissingRecipes = MissingRecipes or {}

local button         = nil
local buttonInjected = false

-- Cached when TRADE_SKILL_LIST_UPDATE fires (profession data guaranteed ready).
local cachedProfName    = nil
local cachedSkillLineID = nil

-- Called by MissingRecipes.lua on TRADE_SKILL_LIST_UPDATE when NOT fetching.
-- At this point GetBaseProfessionInfo() is fully populated.
-- ProfessionInfo fields (from Blizzard source): professionID, professionName,
-- skillLevel, maxSkillLevel, isPrimaryProfession, etc.
-- NOTE: the field is professionID, NOT skillLineID.
function MissingRecipes.OnProfessionListReady()
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    if info and info.professionID and info.professionID > 0 then
        cachedSkillLineID = info.professionID
        cachedProfName = info.professionName or "Unknown"
    end
end

-- Updates button visibility based on whether CraftingPage is active.
local function UpdateButtonVisibility()
    if not button then return end
    
    -- Only show button if CraftingPage (Recipes tab) is visible
    if ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage:IsShown() then
        button:Show()
    else
        button:Hide()
    end
end

-- Called when the player clicks the injected button.
local function OnButtonClick()
    -- Prefer cached info; try a live read as last resort.
    if not cachedSkillLineID then
        MissingRecipes.OnProfessionListReady()
    end

    if not cachedSkillLineID then
        print("|cffFFD700MissingRecipes|r: Could not read current profession.")
        return
    end

    local profName = cachedProfName

    -- The profession is already open, so GetAllRecipeIDs is safe to call now.
    local missing = MissingRecipes.ReadCurrentProfessionRecipes()

    -- Update the frame title and show results scoped to this one profession.
    MissingRecipes.SetFrameTitle(profName .. " \226\128\147 Missing Recipes")
    local frame = MissingRecipes.GetMainFrame()
    frame.statusText:Hide()
    frame:Show()
    MissingRecipes.PopulateList({ [profName] = missing })
end

-- Injects the button into the CraftingPage frame.
-- Called once; subsequent TRADE_SKILL_SHOW events are ignored.
local function InjectButton()
    if buttonInjected then return end
    if not ProfessionsFrame then return end
    if not ProfessionsFrame.CraftingPage then return end

    button = CreateFrame("Button", "MissingRecipesProfButton", ProfessionsFrame.CraftingPage, "GameMenuButtonTemplate")
    button:SetSize(130, 23)
    button:SetPoint("BOTTOM", ProfessionsFrame.CraftingPage, "BOTTOM", -122, 7)
    button:SetText("Missing Recipes")
    button:SetScript("OnClick", OnButtonClick)
    
    buttonInjected = true
end

-- Called by MissingRecipes.lua on TRADE_SKILL_SHOW when NOT fetching.
-- Only responsible for injecting the button; cache is populated later on
-- TRADE_SKILL_LIST_UPDATE via MissingRecipes.OnProfessionListReady().
function MissingRecipes.OnTradeSkillShow()
    -- Reset cache so switching professions always gets fresh info.
    cachedProfName    = nil
    cachedSkillLineID = nil

    -- Small defer so ProfessionsFrame finishes building before we attach to it.
    C_Timer.After(0, function()
        InjectButton()
        UpdateButtonVisibility()
    end)
end

-- Called by MissingRecipes.lua on TRADE_SKILL_CLOSE.
-- Hides the button when leaving the Recipes tab.
function MissingRecipes.OnTradeSkillClose()
    UpdateButtonVisibility()
    -- Don't reset buttonInjected; button stays parented to CraftingPage
end
