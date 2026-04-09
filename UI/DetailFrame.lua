-- UI/DetailFrame.lua
-- Displays detailed information about a selected recipe.

MissingRecipes = MissingRecipes or {}

local detailFrame = nil
local copyDialog = nil

-- Create a reusable copy dialog frame
local function GetOrCreateCopyDialog()
    if copyDialog then
        return copyDialog
    end

    local dialog = CreateFrame("Frame", "MissingRecipesCopyDialog", detailFrame, "BackdropTemplate")
    dialog:SetSize(400, 120)
    dialog:SetPoint("CENTER")

    dialog:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dialog:SetBackdropColor(0, 0, 0, 1)
    dialog:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)

    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 12, -10)
    local gc = MissingRecipes.COLOR_GOLD
    title:SetTextColor(gc.r, gc.g, gc.b, gc.a)
    title:SetText("Copy to Clipboard")
    dialog.title = title

    -- Instructions
    local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("TOPLEFT", dialog, "TOPLEFT", 12, -35)
    instructions:SetWidth(376)
    local wc = MissingRecipes.COLOR_WHITE
    instructions:SetTextColor(wc.r, wc.g, wc.b, wc.a)
    instructions:SetText("Press Ctrl+C to copy:")

    -- EditBox for the copyable text
    local editBox = CreateFrame("EditBox", nil, dialog, "BackdropTemplate")
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(376)
    editBox:SetHeight(20)
    editBox:SetPoint("TOPLEFT", dialog, "TOPLEFT", 12, -55)
    editBox:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    editBox:SetBackdropColor(0, 0, 0, 0.95)
    editBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function(self) dialog:Hide() end)
    dialog.editBox = editBox

    dialog:Hide()
    copyDialog = dialog
    return dialog
end

-- Maps TradeskillRelativeDifficulty enum values to display info.
-- Blizzard uses: Trivial=0, Easy=1, Moderate=2, Difficult=3, Optimal=4
local DIFFICULTY_INFO = {
    [0] = { r = 0.6, g = 0.6, b = 0.6, text = "Trivial" },
    [1] = { r = 0.4, g = 0.8, b = 0.4, text = "Easy" },
    [2] = { r = 1,   g = 1,   b = 0,   text = "Medium" },
    [3] = { r = 1,   g = 0.5, b = 0,   text = "Hard" },
    [4] = { r = 1,   g = 0,   b = 0,   text = "Impossible" },
}

-- Gather all available information about a recipe using correct API field names.
local function GetRecipeDetails(recipeID)
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if not info then return nil end

    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    local _, expansionName = C_TradeSkillUI.GetTradeSkillLineForRecipe(recipeID)

    -- Source text: same API used by Blizzard's crafting window (RecipeSourceButton)
    local sourceText = C_TradeSkillUI.GetRecipeSourceText(recipeID)

    -- Output item info
    local outputItemName, outputItemLink
    local outputItemID = schematic and schematic.outputItemID
    if outputItemID then
        outputItemName, outputItemLink = C_Item.GetItemInfo(outputItemID)
    end

    return {
        -- Identity
        recipeID           = recipeID,
        skillLineAbilityID = info.skillLineAbilityID,
        name               = info.name or "Unknown",
        expansion          = expansionName or "Unknown",
        hyperlink          = info.hyperlink,
        icon               = info.icon,

        -- Difficulty / skill
        relativeDifficulty = info.relativeDifficulty,
        maxTrivialLevel    = info.maxTrivialLevel,
        itemLevel          = info.itemLevel,
        numSkillUps        = info.numSkillUps or 0,

        -- Output
        outputItemID       = outputItemID,
        outputItemName     = outputItemName,
        outputItemLink     = outputItemLink,
        quantityMin        = schematic and schematic.quantityMin or 0,
        quantityMax        = schematic and schematic.quantityMax or 0,
        recipeType         = schematic and schematic.recipeType,
        maxQuality         = info.maxQuality,

        -- XP / levels
        currentRecipeExperience   = info.currentRecipeExperience,
        nextLevelRecipeExperience = info.nextLevelRecipeExperience,
        unlockedRecipeLevel       = info.unlockedRecipeLevel,

        -- Source
        sourceText = sourceText,

        -- Flags
        favorite           = info.favorite or false,
        firstCraft         = info.firstCraft or false,
        supportsQualities  = info.supportsQualities,
        isEnchantingRecipe = info.isEnchantingRecipe,
        isSalvageRecipe    = info.isSalvageRecipe,
        isGatheringRecipe  = info.isGatheringRecipe,
    }
end

-- Builds the outer shell once. Only called the very first time.
local function BuildShell()
    local frame = CreateFrame("Frame", "MissingRecipesDetailFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("TOOLTIP")

    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.95)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Register with UISpecialFrames so ESC closes it.
    tinsert(UISpecialFrames, "MissingRecipesDetailFrame")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Title bar
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    local gc = MissingRecipes.COLOR_GOLD
    title:SetTextColor(gc.r, gc.g, gc.b, gc.a)
    frame.titleText = title

    -- Separator
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8, -30)
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -30)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- Scroll frame shell (persistent)
    local scrollFrame = CreateFrame("ScrollFrame", "MissingRecipesDetailScrollFrame",
        frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     8,  -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28,  8)
    frame.scrollFrame = scrollFrame

    frame:Hide()
    return frame
end

-- Builds a fresh detail frame. Called each time a recipe is clicked.
local function BuildDetailFrame()
    -- Shell is created once; reuse it.
    if not detailFrame then
        detailFrame = BuildShell()
    end
    return detailFrame
end

-- Public entry point. Reuses the shell frame; rebuilds only the scroll content.
function MissingRecipes.ShowRecipeDetail(recipeID)
    local frame = BuildDetailFrame()

    local details = GetRecipeDetails(recipeID)
    if not details then
        print("|cffFFD700MissingRecipes|r: Could not load recipe details.")
        return
    end

    -- Hide and replace the old scroll content child so we get a clean slate.
    -- (FontStrings can't be destroyed in WoW, so we swap the child frame instead.)
    if frame.scrollContent then
        frame.scrollContent:Hide()
    end
    local content = CreateFrame("Frame", nil, frame.scrollFrame)
    content:SetWidth(frame.scrollFrame:GetWidth() - 20)
    content:SetHeight(1)
    frame.scrollFrame:SetScrollChild(content)
    frame.scrollContent = content
    local contentWidth = content:GetWidth() - 10
    local yOffset = 0

    frame.titleText:SetText(details.name)

    -- ── Helpers ───────────────────────────────────────────────────────────
    local function AddLine(labelText, valueText, valueColor)
        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetWidth(contentWidth * 0.42)
        lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -yOffset)
        lbl:SetText(labelText)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        local grey = MissingRecipes.COLOR_GREY
        lbl:SetTextColor(grey.r, grey.g, grey.b, grey.a)

        local val = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        val:SetWidth(contentWidth * 0.56)
        val:SetPoint("TOPLEFT", lbl, "TOPRIGHT", 4, 0)
        val:SetText(valueText or "\226\128\148")
        val:SetJustifyH("LEFT")
        val:SetWordWrap(true)
        if valueColor then
            val:SetTextColor(valueColor.r, valueColor.g, valueColor.b, valueColor.a)
        else
            local wc = MissingRecipes.COLOR_WHITE
            val:SetTextColor(wc.r, wc.g, wc.b, wc.a)
        end

        yOffset = yOffset + math.max(lbl:GetHeight(), val:GetHeight()) + 4
    end

    local function AddClickableLink(labelText, valueText, copyText)
        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetWidth(contentWidth * 0.42)
        lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -yOffset)
        lbl:SetText(labelText)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        local grey = MissingRecipes.COLOR_GREY
        lbl:SetTextColor(grey.r, grey.g, grey.b, grey.a)

        -- Create an invisible button to capture clicks
        local btn = CreateFrame("Button", nil, content)
        btn:SetWidth(contentWidth * 0.56)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", lbl, "TOPRIGHT", 4, 0)

        -- Create text on the button (styled as a link)
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetWidth(contentWidth * 0.56)
        btnText:SetPoint("TOPLEFT", 0, 0)
        btnText:SetText(valueText)
        btnText:SetJustifyH("LEFT")
        btnText:SetWordWrap(true)
        btnText:SetTextColor(0, 0.52, 0.97, 1)  -- Link blue

        -- Click handler to copy to clipboard
        btn:SetScript("OnClick", function()
            local dialog = GetOrCreateCopyDialog()
            dialog.editBox:SetText(copyText)
            dialog.editBox:HighlightText(0, -1)
            dialog.editBox:SetFocus()
            dialog:Show()
        end)

        -- Hover effects
        btn:SetScript("OnEnter", function()
            btnText:SetTextColor(0.2, 0.7, 1, 1)  -- Lighter blue on hover
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:SetText("Click to copy Wowhead link", 1, 1, 1)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            btnText:SetTextColor(0, 0.52, 0.97, 1)
            GameTooltip:Hide()
        end)

        yOffset = yOffset + math.max(lbl:GetHeight(), btn:GetHeight()) + 4
    end

    local function AddSeparator()
        local line = content:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -yOffset - 2)
        line:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset - 2)
        line:SetColorTexture(0.35, 0.35, 0.35, 0.7)
        yOffset = yOffset + 8
    end

    local function AddHeader(text)
        local hdr = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetWidth(contentWidth)
        hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -yOffset)
        hdr:SetText(text)
        hdr:SetJustifyH("LEFT")
        local gc = MissingRecipes.COLOR_GOLD
        hdr:SetTextColor(gc.r, gc.g, gc.b, gc.a)
        yOffset = yOffset + hdr:GetHeight() + 4
    end

    -- ── Identity ──────────────────────────────────────────────────────────
    AddHeader("Identity")
    local wowheadUrl = "https://www.wowhead.com/spell=" .. tostring(details.skillLineAbilityID)
    AddClickableLink("Recipe ID", tostring(details.recipeID), wowheadUrl)
    AddLine("Ability ID", tostring(details.skillLineAbilityID))
    AddLine("Expansion",  details.expansion)
    if details.recipeType then
        AddLine("Type", details.recipeType)
    end

    -- ── Difficulty / Skill ────────────────────────────────────────────────
    AddSeparator()
    AddHeader("Difficulty")
    if details.relativeDifficulty ~= nil then
        local di = DIFFICULTY_INFO[details.relativeDifficulty]
                or { r = 1, g = 1, b = 1, text = "Unknown" }
        AddLine("Difficulty", di.text, { r = di.r, g = di.g, b = di.b, a = 1 })
    end
    if details.maxTrivialLevel and details.maxTrivialLevel > 0 then
        AddLine("Trivial at skill", tostring(details.maxTrivialLevel))
    end
    if details.numSkillUps > 0 then
        AddLine("Skill-ups", tostring(details.numSkillUps))
    end

    -- ── Output ────────────────────────────────────────────────────────────
    AddSeparator()
    AddHeader("Output")
    if details.outputItemLink then
        AddLine("Item", details.outputItemLink)
    elseif details.outputItemName then
        AddLine("Item", details.outputItemName)
    end
    if details.itemLevel and details.itemLevel > 0 then
        AddLine("Item level", tostring(details.itemLevel))
    end
    if details.quantityMin and details.quantityMax
       and (details.quantityMin > 0 or details.quantityMax > 0) then
        if details.quantityMin == details.quantityMax then
            AddLine("Quantity", tostring(details.quantityMin))
        else
            AddLine("Quantity", details.quantityMin .. " \226\128\147 " .. details.quantityMax)
        end
    end
    if details.maxQuality and details.maxQuality > 0 then
        AddLine("Max quality", string.rep("*", details.maxQuality))
    end

    -- ── Progression ───────────────────────────────────────────────────────
    if details.unlockedRecipeLevel or details.currentRecipeExperience then
        AddSeparator()
        AddHeader("Progression")
        if details.unlockedRecipeLevel and details.unlockedRecipeLevel > 0 then
            AddLine("Recipe level", tostring(details.unlockedRecipeLevel))
        end
        if details.currentRecipeExperience then
            AddLine("Recipe XP",    tostring(details.currentRecipeExperience))
        end
        if details.nextLevelRecipeExperience then
            AddLine("Next level XP", tostring(details.nextLevelRecipeExperience))
        end
    end

    -- ── Source ────────────────────────────────────────────────────────────
    AddSeparator()
    AddHeader("Source")
    AddLine("How to get",
        (details.sourceText and details.sourceText ~= "") and details.sourceText or "Unknown")

    -- ── Flags ─────────────────────────────────────────────────────────────
    local flags = {}
    if details.favorite           then table.insert(flags, "* Favorite") end
    if details.firstCraft         then table.insert(flags, "First Craft Bonus") end
    if details.supportsQualities  then table.insert(flags, "Has Quality Tiers") end
    if details.isEnchantingRecipe then table.insert(flags, "Enchanting") end
    if details.isSalvageRecipe    then table.insert(flags, "Salvage") end
    if details.isGatheringRecipe  then table.insert(flags, "Gathering") end
    if #flags > 0 then
        AddSeparator()
        AddHeader("Flags")
        for _, f in ipairs(flags) do
            AddLine("", f)
        end
    end

    content:SetHeight(math.max(yOffset + 8, 1))
    frame.scrollFrame:SetVerticalScroll(0)
    frame:Show()
end

function MissingRecipes.GetDetailFrame()
    return detailFrame
end
