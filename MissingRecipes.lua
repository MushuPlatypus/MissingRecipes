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
        print("|cffFFD700MissingRecipes|r v"
            .. MissingRecipes.VERSION
            .. " loaded. Type |cffffffff/miser|r to open.")

    elseif event == "TRADE_SKILL_SHOW" then
        if MissingRecipes.IsFetching() then
            -- We opened the profession programmatically for scanning (/miser).
            -- Suppress the Blizzard Professions frame so it doesn't pop up.
            if ProfessionsFrame and ProfessionsFrame:IsShown() then
                ProfessionsFrame:Hide()
            end
        else
            -- The player opened a profession normally; inject our button.
            MissingRecipes.OnTradeSkillShow()
        end

    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        if MissingRecipes.IsFetching() then
            -- Async profession scan in progress (/miser path).
            MissingRecipes.OnTradeSkillListUpdate()
        else
            -- Player opened a profession normally; cache the profession info now
            -- that GetBaseProfessionInfo() is guaranteed to be populated.
            MissingRecipes.OnProfessionListReady()
        end

    elseif event == "TRADE_SKILL_CLOSE" then
        MissingRecipes.OnTradeSkillClose()
    end
end)

-- ---------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------
SLASH_MISER1 = "/miser"
SlashCmdList["MISER"] = function()
    MissingRecipes.ToggleFrame()
end
