-- Core/Recipes.lua
-- Asynchronously fetches unlearned recipes for each profession, one at a time.
-- Professions are queued sequentially: open → wait for TRADE_SKILL_LIST_UPDATE
-- → collect unlearned recipes → close → wait for TRADE_SKILL_CLOSE → next.

MissingRecipes = MissingRecipes or {}

-- Module-local fetch state
local fetchQueue    = {}   -- { { name, skillLineID }, ... }
local fetchIndex    = 0
local fetchResults  = {}   -- { ["ProfessionName"] = { "RecipeName", ... }, ... }
local onComplete    = nil  -- callback(fetchResults)
local isFetching    = false

-- Advance to the next profession in the queue.
local function ProcessNextInQueue()
    fetchIndex = fetchIndex + 1

    if fetchIndex > #fetchQueue then
        -- All professions processed; hand results to the caller.
        isFetching = false
        if onComplete then
            onComplete(fetchResults)
            onComplete = nil
        end
        return
    end

    local prof = fetchQueue[fetchIndex]
    fetchResults[prof.name] = {}
    -- Opening the trade skill fires TRADE_SKILL_LIST_UPDATE when data is ready.
    C_TradeSkillUI.OpenTradeSkill(prof.skillLineID)
end

-- Called by the event frame on TRADE_SKILL_LIST_UPDATE.
-- Reads the currently open profession's recipe list and filters unlearned ones.
function MissingRecipes.OnTradeSkillListUpdate()
    if not isFetching then return end

    local prof = fetchQueue[fetchIndex]
    if not prof then return end

    -- Ensure both learned AND unlearned recipes are included in the filtered list.
    -- GetFilteredRecipeIDs() (the correct API — GetAllRecipeIDs does not exist)
    -- only returns recipes that pass the current UI filter, so we must set these
    -- before reading. Blizzard's own SetDefaultFilters() does the same thing.
    C_TradeSkillUI.SetShowLearned(true)
    C_TradeSkillUI.SetShowUnlearned(true)

    local recipeIDs = C_TradeSkillUI.GetFilteredRecipeIDs()
    local unlearned = 0
    for _, recipeID in ipairs(recipeIDs) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        -- Only include recipes the character has not yet learned.
        if info and info.name and not info.learned then
            unlearned = unlearned + 1
            -- GetTradeSkillLineForRecipe returns: tradeSkillID, skillLineName (expansion), parentTradeSkillID
            -- skillLineName includes the profession (e.g., "Classic Tailoring"), so strip the profession suffix
            local tradeSkillID, skillLineName, parentSkillID = C_TradeSkillUI.GetTradeSkillLineForRecipe(recipeID)
            local expansionName = skillLineName and skillLineName:gsub(" [^ ]+$", "") or "Unknown"
            -- Get item type from output item
            local itemType = "Other"
            local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
            if schematic and schematic.outputItemID then
                local _, iType = C_Item.GetItemInfoInstant(schematic.outputItemID)
                if iType then itemType = iType end
            end
            table.insert(fetchResults[prof.name], {
                recipeID = recipeID,
                name = info.name,
                expansion = expansionName,
                itemType = itemType,
            })
        end
    end
    if unlearned == 0 then
        print("|cffFFD700MissingRecipes|r: No unlearned recipes found for " .. prof.name)
    else
        print("|cffFFD700MissingRecipes|r: Found " .. unlearned .. " unlearned recipes for " .. prof.name)
    end

    -- Sort by expansion (newest first via expansion ordering), then alphabetically by recipe name.
    table.sort(fetchResults[prof.name], function(a, b)
        local expansionOrder = MissingRecipes.EXPANSION_ORDER
        local aExpIdx = expansionOrder[a.expansion] or 999
        local bExpIdx = expansionOrder[b.expansion] or 999
        if aExpIdx ~= bExpIdx then
            return aExpIdx < bExpIdx
        end
        return a.name < b.name
    end)

    C_TradeSkillUI.CloseTradeSkill()
    -- TRADE_SKILL_CLOSE will advance the queue (see OnTradeSkillClose below).
end

-- Called by the event frame on TRADE_SKILL_CLOSE.
-- A short delay lets the close settle before we open the next profession.
function MissingRecipes.OnTradeSkillClose()
    if not isFetching then return end
    C_Timer.After(0.05, ProcessNextInQueue)
end

-- Public entry point.
-- Fetches all unlearned recipes for every profession the character has, then
-- calls callback(results) where results is:
--   { ["Tailoring"] = { "Recipe A", "Recipe B", ... }, ... }
function MissingRecipes.FetchMissingRecipes(callback)
    local professions = MissingRecipes.GetCharacterProfessions()

    if #professions == 0 then
        callback({})
        return
    end

    fetchQueue   = professions
    fetchIndex   = 0
    fetchResults = {}
    onComplete   = callback
    isFetching   = true

    ProcessNextInQueue()
end

-- Returns true while an async profession scan (/miser) is in progress.
-- Used by the event handler to distinguish programmatic opens from player opens.
function MissingRecipes.IsFetching()
    return isFetching
end

-- Synchronously reads unlearned recipes from the currently open profession.
-- Safe to call only when a profession window is already visible (button path).
-- Returns a sorted array of recipe objects with name and expansion.
function MissingRecipes.ReadCurrentProfessionRecipes()
    local missing = {}
    -- Ensure both learned and unlearned recipes are visible to GetFilteredRecipeIDs.
    C_TradeSkillUI.SetShowLearned(true)
    C_TradeSkillUI.SetShowUnlearned(true)
    local recipeIDs = C_TradeSkillUI.GetFilteredRecipeIDs()
    for _, recipeID in ipairs(recipeIDs) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info and info.name and not info.learned then
            -- GetTradeSkillLineForRecipe returns: tradeSkillID, skillLineName (expansion), parentTradeSkillID
            -- skillLineName includes the profession (e.g., "Classic Tailoring"), so strip the profession suffix
            local tradeSkillID, skillLineName, parentSkillID = C_TradeSkillUI.GetTradeSkillLineForRecipe(recipeID)
            local expansionName = skillLineName and skillLineName:gsub(" [^ ]+$", "") or "Unknown"
            -- Get item type from output item
            local itemType = "Other"
            local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
            if schematic and schematic.outputItemID then
                local _, iType = C_Item.GetItemInfoInstant(schematic.outputItemID)
                if iType then itemType = iType end
            end
            table.insert(missing, {
                recipeID = recipeID,
                name = info.name,
                expansion = expansionName,
                itemType = itemType,
            })
        end
    end
    -- Sort by expansion (newest first), then alphabetically.
    table.sort(missing, function(a, b)
        local expansionOrder = MissingRecipes.EXPANSION_ORDER
        local aExpIdx = expansionOrder[a.expansion] or 999
        local bExpIdx = expansionOrder[b.expansion] or 999
        if aExpIdx ~= bExpIdx then
            return aExpIdx < bExpIdx
        end
        return a.name < b.name
    end)
    return missing
end
