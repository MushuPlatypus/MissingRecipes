-- MissingRecipes.lua
-- Entry point: event registration and slash command wiring.
-- All Core/ and UI/ modules are loaded before this file (see .toc order).

MissingRecipes = MissingRecipes or {}

-- ---------------------------------------------------------------------------
-- Event frame
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Print a short confirmation in chat so the player knows the addon loaded.
        print("|cffFFD700MissingRecipes|r v" .. MissingRecipes.VERSION .. " loaded.")

    elseif event == "TRADE_SKILL_SHOW" then
        -- The player opened a profession; inject our button.
        MissingRecipes.OnTradeSkillShow()

    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        -- Player opened a profession; cache the profession info now
        -- that GetBaseProfessionInfo() is guaranteed to be populated.
        MissingRecipes.OnProfessionListReady()

    elseif event == "TRADE_SKILL_CLOSE" then
        -- (No action needed on close)
    end
end)


