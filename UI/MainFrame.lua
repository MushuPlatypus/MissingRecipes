-- UI/MainFrame.lua
-- Creates and manages the main MissingRecipes popup frame.

MissingRecipes = MissingRecipes or {}

local mainFrame = nil

local function BuildMainFrame()
    local frame = CreateFrame("Frame", "MissingRecipesMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(MissingRecipes.FRAME_WIDTH, MissingRecipes.FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")

    -- Backdrop
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Register with UISpecialFrames so ESC closes it.
    tinsert(UISpecialFrames, "MissingRecipesMainFrame")

    -- Title (stored on frame so SetFrameTitle can update it)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetText("Missing Recipes")
    local c = MissingRecipes.COLOR_GOLD
    title:SetTextColor(c.r, c.g, c.b, c.a)
    frame.titleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Separator line below header
    local topLine = frame:CreateTexture(nil, "ARTWORK")
    topLine:SetHeight(1)
    topLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8, -30)
    topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -30)
    topLine:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- Separator line above footer
    local botLine = frame:CreateTexture(nil, "ARTWORK")
    botLine:SetHeight(1)
    botLine:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  8, 24)
    botLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 24)
    botLine:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- Status text (shown while loading or on error)
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    statusText:SetText("")
    statusText:Hide()
    frame.statusText = statusText

    -- Footer count label
    local footerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
    local gc = MissingRecipes.COLOR_GREY
    footerText:SetTextColor(gc.r, gc.g, gc.b, gc.a)
    footerText:SetText("")
    frame.footerText = footerText

    frame:Hide()
    return frame
end

-- Returns the main frame, creating it lazily on first call.
function MissingRecipes.GetMainFrame()
    if not mainFrame then
        mainFrame = BuildMainFrame()
        MissingRecipes.CreateScrollFrame(mainFrame)
    end
    return mainFrame
end

-- Update the header title text.
function MissingRecipes.SetFrameTitle(text)
    local frame = MissingRecipes.GetMainFrame()
    frame.titleText:SetText(text)
end

-- Toggle the frame open/closed (all-professions /miser path).
function MissingRecipes.ToggleFrame()
    local frame = MissingRecipes.GetMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        MissingRecipes.SetFrameTitle("Missing Recipes")
        frame:Show()
        MissingRecipes.RefreshList()
    end
end

-- Trigger a data refresh: fetch recipes and repopulate the list.
function MissingRecipes.RefreshList()
    local frame = MissingRecipes.GetMainFrame()

    frame.statusText:SetText("Loading...")
    frame.statusText:Show()
    frame.footerText:SetText("")

    MissingRecipes.FetchMissingRecipes(function(results)
        frame.statusText:Hide()
        MissingRecipes.PopulateList(results)
    end)
end
