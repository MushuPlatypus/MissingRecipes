-- UI/RecipeList.lua
-- Scrollable list of missing recipes grouped by profession using Blizzard's TreeListView.
-- Uses TreeDataProvider for hierarchical data and TreeListView for efficient rendering.

MissingRecipes = MissingRecipes or {}

-- Mixins for category and recipe buttons
MissingRecipesCategoryMixin = {}

function MissingRecipesCategoryMixin:OnLoad()
    self.Label:SetFontObject(GameFontNormal_NoShadow or GameFontNormal)
end

function MissingRecipesCategoryMixin:Init(node)
    local elementData = node:GetData()
    local categoryInfo = elementData.categoryInfo
    
    self.Label:SetText(categoryInfo.displayName)
    self:SetCollapseState(node:IsCollapsed())
    
    self:SetScript("OnClick", function(button)
        node:ToggleCollapsed()
        button:SetCollapseState(node:IsCollapsed())
    end)
end

function MissingRecipesCategoryMixin:SetCollapseState(collapsed)
    local atlas = collapsed and "Professions-recipe-header-expand" or "Professions-recipe-header-collapse"
    self.CollapseIcon:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
    self.CollapseIconAlphaAdd:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
end

function MissingRecipesCategoryMixin:OnEnter()
    self.Label:SetFontObject(GameFontHighlight_NoShadow or GameFontHighlight)
end

function MissingRecipesCategoryMixin:OnLeave()
    self.Label:SetFontObject(GameFontNormal_NoShadow or GameFontNormal)
end

function MissingRecipesCategoryMixin:OnClick()
    -- Handled in Init
end

-- Mixin for recipe item buttons
MissingRecipesRecipeMixin = {}

function MissingRecipesRecipeMixin:OnLoad()
    self.Label:SetFontObject(GameFontHighlight_NoShadow or GameFontHighlight)
end

function MissingRecipesRecipeMixin:Init(node)
    local elementData = node:GetData()
    local recipeInfo = elementData.recipeInfo
    
    self.Label:SetText(recipeInfo.name)
    
    self:SetScript("OnClick", function(button)
        if recipeInfo.recipeID then
            MissingRecipes.ShowRecipeDetail(recipeInfo.recipeID)
        end
    end)
end

function MissingRecipesRecipeMixin:OnEnter()
    -- Show the hover highlight overlay (matches Professions_Recipe_Hover)
    if self.HighlightOverlay then
        self.HighlightOverlay:Show()
    end
end

function MissingRecipesRecipeMixin:OnLeave()
    -- Hide the hover highlight overlay
    if self.HighlightOverlay then
        self.HighlightOverlay:Hide()
    end
end

function MissingRecipesRecipeMixin:OnClick()
    -- Handled in Init
end

-- Build the tree data structure from recipe results
local function BuildRecipeTree(results)
    local dataProvider = CreateTreeDataProvider()
    local totalMissing = 0
    
    -- Merge all recipes across professions into a single flat list
    local allRecipes = {}
    for _, recipes in pairs(results) do
        for _, recipe in ipairs(recipes) do
            table.insert(allRecipes, recipe)
        end
    end

    -- Group by expansion
    local expansionGroups = {}
    for _, recipe in ipairs(allRecipes) do
        local exp = recipe.expansion
        if not expansionGroups[exp] then
            expansionGroups[exp] = {}
        end
        table.insert(expansionGroups[exp], recipe)
    end

    -- Sort expansions (newest first)
    local sortedExps = {}
    for exp in pairs(expansionGroups) do
        table.insert(sortedExps, exp)
    end
    table.sort(sortedExps, function(a, b)
        local order = MissingRecipes.EXPANSION_ORDER
        local orderA = order[a] or 999
        local orderB = order[b] or 999
        return orderA > orderB
    end)

    for _, exp in ipairs(sortedExps) do
        local expRecipes = expansionGroups[exp]

        local expNode = dataProvider:Insert({
            categoryInfo = {
                displayName = exp .. " (" .. #expRecipes .. ")",
                isCategory = true,
            },
        })

        -- Group by item type
        local typeGroups = {}
        for _, recipe in ipairs(expRecipes) do
            local iType = recipe.itemType or "Other"
            if not typeGroups[iType] then typeGroups[iType] = {} end
            table.insert(typeGroups[iType], recipe)
        end

        -- Sort item types alphabetically, "Other" last
        local sortedTypes = {}
        for iType in pairs(typeGroups) do
            table.insert(sortedTypes, iType)
        end
        table.sort(sortedTypes, function(a, b)
            if a == "Other" then return false end
            if b == "Other" then return true end
            return a < b
        end)

        for _, iType in ipairs(sortedTypes) do
            local typeRecipes = typeGroups[iType]
            local typeNode = expNode:Insert({
                categoryInfo = {
                    displayName = iType .. " (" .. #typeRecipes .. ")",
                    isCategory = true,
                },
            })
            for _, recipe in ipairs(typeRecipes) do
                typeNode:Insert({
                    recipeInfo = {
                        name = recipe.name,
                        recipeID = recipe.recipeID,
                    },
                })
                totalMissing = totalMissing + 1
            end
        end
    end
    
    return dataProvider, totalMissing
end

-- Creates the scroll frame with TreeListView attached to parentFrame
-- Called once when the main frame is initialized
function MissingRecipes.CreateScrollFrame(parentFrame)
    -- Create outer frame to hold both scroll box and scroll bar
    local outerFrame = CreateFrame("Frame", "MissingRecipesScrollContainer", parentFrame)
    outerFrame:SetPoint(
        "TOPLEFT",     parentFrame, "TOPLEFT",
        MissingRecipes.CONTENT_LEFT_PADDING,
        MissingRecipes.CONTENT_TOP_OFFSET
    )
    outerFrame:SetPoint(
        "BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT",
        -MissingRecipes.CONTENT_RIGHT_CLEARANCE,
        MissingRecipes.CONTENT_BOTTOM_OFFSET
    )
    
    -- Clip any children that overflow the bounds (prevents scrollbar from showing outside)
    outerFrame:SetClipsChildren(true)

    -- Add background texture (matches Professions UI)
    local background = outerFrame:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("Professions-background-summarylist")
    background:SetAllPoints(outerFrame)

    -- Create the ScrollBox (the actual scrollable content area)
    local scrollBox = CreateFrame("Frame", "MissingRecipesScrollBox", outerFrame, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", outerFrame, "TOPLEFT", 0, 0)
    scrollBox:SetPoint("BOTTOMRIGHT", outerFrame, "BOTTOMRIGHT", -26, 0)

    -- Create the ScrollBar
    local scrollBar = CreateFrame("EventFrame", "MissingRecipesScrollBar", outerFrame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 0, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 0, 0)

    -- Setup TreeListView with proper padding and spacing
    local view = CreateScrollBoxListTreeListView(
        14,     -- indent per depth level
        0,      -- topPadding
        0,      -- bottomPadding
        0,      -- leftPadding
        0       -- rightPadding
    )

    -- Set the element factory to create buttons based on node data type
    view:SetElementFactory(function(factory, node)
        local elementData = node:GetData()
        
        if elementData.categoryInfo then
            -- Create category button
            local function Initializer(button)
                button:Init(node)
            end
            factory("MissingRecipesCategoryButtonTemplate", Initializer)
        else
            -- Create recipe item button
            local function Initializer(button)
                button:Init(node)
            end
            factory("MissingRecipesRecipeButtonTemplate", Initializer)
        end
    end)

    -- Apply CallbackRegistryMixin to scrollBox and scrollBar
    -- (WowScrollBoxList might already have it, but ensure it's there)
    if not scrollBox.RegisterCallback then
        CallbackRegistryMixin.OnLoad(scrollBox)
    end
    if not scrollBar.RegisterCallback then
        CallbackRegistryMixin.OnLoad(scrollBar)
    end

    -- Initialize the scroll box with the view
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    parentFrame.scrollFrame = outerFrame
    parentFrame.scrollBox = scrollBox
    parentFrame.scrollBar = scrollBar
    parentFrame.view = view
end

-- Populate the list with recipe results
-- results: { ["ProfessionName"] = { { name = "Recipe", expansion = "Exp", recipeID = id }, ... }, ... }
function MissingRecipes.PopulateList(results)
    local frame = MissingRecipes.GetMainFrame()
    
    -- Build tree data
    local dataProvider, totalMissing = BuildRecipeTree(results)
    
    -- Attach data provider to the scroll box
    frame.scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
    
    -- Update footer with count
    if totalMissing == 1 then
        frame.footerText:SetText("1 missing recipe")
    elseif totalMissing == 0 then
        frame.footerText:SetText("No missing recipes")
    else
        frame.footerText:SetText(totalMissing .. " missing recipes")
    end
end
