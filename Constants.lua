-- Constants.lua
-- Named constants for MissingRecipes. Loaded first by the TOC.

MissingRecipes = MissingRecipes or {}

MissingRecipes.ADDON_NAME  = "MissingRecipes"
MissingRecipes.ADDON_TITLE = "Missing Recipes"
MissingRecipes.VERSION     = "1.0.0"

-- UI dimensions
MissingRecipes.FRAME_WIDTH  = 400
MissingRecipes.FRAME_HEIGHT = 500

-- Row heights in the scroll list
MissingRecipes.ROW_HEIGHT        = 16
MissingRecipes.HEADER_ROW_HEIGHT = 22

-- Content area offsets inside the main frame
MissingRecipes.CONTENT_TOP_OFFSET    = -34   -- below title + separator
MissingRecipes.CONTENT_BOTTOM_OFFSET = 28    -- above footer + separator
MissingRecipes.CONTENT_LEFT_PADDING  = 8
-- Scroll frame right clearance (scrollbar width + border)
MissingRecipes.CONTENT_RIGHT_CLEARANCE = 28
-- Usable content width (without scrollbar area)
MissingRecipes.CONTENT_WIDTH =
    MissingRecipes.FRAME_WIDTH
    - MissingRecipes.CONTENT_LEFT_PADDING
    - MissingRecipes.CONTENT_RIGHT_CLEARANCE
    - 20  -- inner padding of UIPanelScrollFrameTemplate scrollbar

-- Text colours
MissingRecipes.COLOR_GOLD  = { r = 1,   g = 0.82, b = 0,   a = 1 }
MissingRecipes.COLOR_WHITE = { r = 1,   g = 1,    b = 1,   a = 1 }
MissingRecipes.COLOR_GREY  = { r = 0.6, g = 0.6,  b = 0.6, a = 1 }

-- Expansion ordering (index = sort order, newest first)
-- Lower indices sort first (display at top)
MissingRecipes.EXPANSION_ORDER = {
    ["The War Within"]          = 1,
    ["Midnight"]                = 2,
    ["Dragonflight"]            = 3,
    ["Shadowlands"]             = 4,
    ["Battle for Azeroth"]      = 5,
    ["Legion"]                  = 6,
    ["Warlords of Draenor"]     = 7,
    ["Mists of Pandaria"]       = 8,
    ["Cataclysm"]               = 9,
    ["Wrath of the Lich King"]  = 10,
    ["The Burning Crusade"]     = 11,
    ["Classic"]                 = 12,
}

-- Accordion state: tracks which expansions are collapsed/expanded per profession
-- Structure: { ["ProfessionName"] = { ["ExpansionName"] = isExpanded, ... }, ... }
MissingRecipes.ACCORDION_STATE = {}
