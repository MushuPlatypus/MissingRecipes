-- UI/RecipeList.lua
-- Scrollable list of missing recipes grouped by profession.
-- Rows are represented as child Frames so they can be found and recycled via
-- GetChildren(); FontStrings live inside those row frames.

MissingRecipes = MissingRecipes or {}

-- Pool of row frames; reused across refreshes to avoid allocating every time.
local rowPool = {}

-- Returns the nth pooled row frame, creating it if necessary.
-- Each row is a Frame with a child FontString (row.label).
local function GetPooledRow(parent, index)
    if not rowPool[index] then
        local rowFrame = CreateFrame("Frame", nil, parent)
        local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT",  rowFrame, "LEFT",  0, 0)
        label:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        rowFrame.label = label
        rowPool[index] = rowFrame
    end
    local row = rowPool[index]
    row:SetParent(parent)
    row:Show()
    return row
end

-- Hide all pooled rows beyond activeCount.
local function HideExcessRows(activeCount)
    for i = activeCount + 1, #rowPool do
        rowPool[i]:Hide()
    end
end

-- Build accordion-style row data grouped by expansion (newest first).
-- results: { ["ProfessionName"] = { { name = "Recipe", expansion = "Exp" }, ... }, ... }
-- Returns: rows (table), totalMissing (number)
local function BuildRowData(results)
    local rows        = {}
    local totalMissing = 0

    -- Sort profession names for a consistent display order.
    local profNames = {}
    for name in pairs(results) do
        table.insert(profNames, name)
    end
    table.sort(profNames)

    for _, profName in ipairs(profNames) do
        local recipes = results[profName]
        local count   = #recipes

        -- Profession header row
        local countLabel = count > 0
            and (" (" .. count .. " missing)")
            or  " \226\128\148 all learned"
        table.insert(rows, {
            type   = "prof_header",
            text   = profName .. countLabel,
            height = MissingRecipes.HEADER_ROW_HEIGHT,
        })

        if count == 0 then
            table.insert(rows, {
                type   = "empty",
                text   = "  Nothing missing here.",
                height = MissingRecipes.ROW_HEIGHT,
            })
        else
            -- Group recipes by expansion
            local expansionGroups = {}
            for _, recipe in ipairs(recipes) do
                local exp = recipe.expansion
                if not expansionGroups[exp] then
                    expansionGroups[exp] = {}
                end
                table.insert(expansionGroups[exp], recipe)  -- Store full recipe object, not just name
            end

            -- Sort expansions by order (newest first)
            local sortedExps = {}
            for exp in pairs(expansionGroups) do
                table.insert(sortedExps, exp)
            end
            table.sort(sortedExps, function(a, b)
                local order = MissingRecipes.EXPANSION_ORDER
                return (order[a] or 999) < (order[b] or 999)
            end)

            -- Build rows for each expansion accordion
            for _, exp in ipairs(sortedExps) do
                local expRecipes = expansionGroups[exp]
                local expCount = #expRecipes

                -- Initialize accordion state if not yet set (default expanded)
                if not MissingRecipes.ACCORDION_STATE[profName] then
                    MissingRecipes.ACCORDION_STATE[profName] = {}
                end
                if MissingRecipes.ACCORDION_STATE[profName][exp] == nil then
                    MissingRecipes.ACCORDION_STATE[profName][exp] = true  -- expanded by default
                end

                local isExpanded = MissingRecipes.ACCORDION_STATE[profName][exp]
                local accordionKey = profName .. "|" .. exp
                local toggleSymbol = isExpanded and "▼" or "▶"

                -- Expansion accordion header
                table.insert(rows, {
                    type            = "expansion_header",
                    text            = "  " .. toggleSymbol .. " " .. exp .. " (" .. expCount .. ")",
                    height          = MissingRecipes.HEADER_ROW_HEIGHT,
                    accordionKey    = accordionKey,
                    expansion       = exp,
                    profession      = profName,
                    isExpanded      = isExpanded,
                })

                -- Add recipe rows if expanded
                if isExpanded then
                    for _, recipe in ipairs(expRecipes) do
                        table.insert(rows, {
                            type      = "recipe",
                            text      = "    " .. recipe.name,
                            height    = MissingRecipes.ROW_HEIGHT,
                            recipeID  = recipe.recipeID,
                        })
                        totalMissing = totalMissing + 1
                    end
                else
                    -- Just count, don't display rows
                    totalMissing = totalMissing + expCount
                end
            end
        end
    end

    if #profNames == 0 then
        table.insert(rows, {
            type   = "empty",
            text   = "No professions found on this character.",
            height = MissingRecipes.ROW_HEIGHT,
        })
    end

    return rows, totalMissing
end

-- Creates the scroll frame attached to parentFrame.
-- Called once when the main frame is first built.
function MissingRecipes.CreateScrollFrame(parentFrame)
    local scrollFrame = CreateFrame(
        "ScrollFrame",
        "MissingRecipesScrollFrame",
        parentFrame,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint(
        "TOPLEFT",     parentFrame, "TOPLEFT",
        MissingRecipes.CONTENT_LEFT_PADDING,
        MissingRecipes.CONTENT_TOP_OFFSET
    )
    scrollFrame:SetPoint(
        "BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT",
        -MissingRecipes.CONTENT_RIGHT_CLEARANCE,
        MissingRecipes.CONTENT_BOTTOM_OFFSET
    )

    -- The scroll child carries the actual row frames.
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(MissingRecipes.CONTENT_WIDTH)
    content:SetHeight(1)  -- resized dynamically in PopulateList
    scrollFrame:SetScrollChild(content)

    parentFrame.scrollFrame  = scrollFrame
    parentFrame.scrollContent = content
end

-- Clears the list and renders fresh rows from results.
-- results: { ["ProfessionName"] = { { name = "Recipe", expansion = "Exp" }, ... }, ... }
function MissingRecipes.PopulateList(results)
    local frame   = MissingRecipes.GetMainFrame()
    local content = frame.scrollContent

    -- Reset scroll to top
    frame.scrollFrame:SetVerticalScroll(0)

    local rows, totalMissing = BuildRowData(results)

    local yOffset = 0
    for i, row in ipairs(rows) do
        local rowFrame = GetPooledRow(content, i)
        rowFrame:SetHeight(row.height)
        rowFrame:SetWidth(MissingRecipes.CONTENT_WIDTH)
        rowFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)

        local label = rowFrame.label
        label:SetWidth(MissingRecipes.CONTENT_WIDTH)
        label:SetText(row.text)

        if row.type == "prof_header" then
            -- Profession header (non-clickable)
            label:SetFontObject("GameFontNormalLarge")
            local c = MissingRecipes.COLOR_GOLD
            label:SetTextColor(c.r, c.g, c.b, c.a)
            rowFrame:EnableMouse(false)
        elseif row.type == "expansion_header" then
            -- Expansion accordion header (clickable)
            label:SetFontObject("GameFontNormal")
            local c = MissingRecipes.COLOR_WHITE
            label:SetTextColor(c.r, c.g, c.b, c.a)
            
            -- Make the row clickable to toggle accordion
            rowFrame:EnableMouse(true)
            rowFrame:SetScript("OnMouseDown", function(self)
                -- Toggle expansion state
                local prof = row.profession
                local exp = row.expansion
                MissingRecipes.ACCORDION_STATE[prof][exp] = not MissingRecipes.ACCORDION_STATE[prof][exp]
                -- Refresh the list with updated accordion state
                MissingRecipes.PopulateList(results)
            end)
            rowFrame:SetScript("OnEnter", function(self)
                -- Highlight on hover
                label:SetTextColor(1, 1, 0, 1)  -- bright yellow
            end)
            rowFrame:SetScript("OnLeave", function(self)
                local c = MissingRecipes.COLOR_WHITE
                label:SetTextColor(c.r, c.g, c.b, c.a)
            end)
        elseif row.type == "recipe" then
            -- Individual recipe (clickable)
            label:SetFontObject("GameFontNormal")
            local c = MissingRecipes.COLOR_WHITE
            label:SetTextColor(c.r, c.g, c.b, c.a)
            
            -- Make the row clickable to show recipe details
            rowFrame:EnableMouse(true)
            rowFrame:SetScript("OnMouseDown", function(self)
                if row.recipeID then
                    MissingRecipes.ShowRecipeDetail(row.recipeID)
                end
            end)
            rowFrame:SetScript("OnEnter", function(self)
                -- Highlight on hover
                label:SetTextColor(1, 1, 0, 1)  -- bright yellow
            end)
            rowFrame:SetScript("OnLeave", function(self)
                local c = MissingRecipes.COLOR_WHITE
                label:SetTextColor(c.r, c.g, c.b, c.a)
            end)
        else  -- "empty"
            label:SetFontObject("GameFontNormal")
            local c = MissingRecipes.COLOR_GREY
            label:SetTextColor(c.r, c.g, c.b, c.a)
            rowFrame:EnableMouse(false)
        end

        yOffset = yOffset + row.height
    end

    HideExcessRows(#rows)
    content:SetHeight(math.max(yOffset, 1))

    -- Footer summary
    if totalMissing == 1 then
        frame.footerText:SetText("1 missing recipe")
    else
        frame.footerText:SetText(totalMissing .. " missing recipes")
    end
end
