-- Core/Professions.lua
-- Detects which professions the character currently has.

MissingRecipes = MissingRecipes or {}

-- Returns a list of { name, skillLineID } for every profession slot the
-- character has. Primary professions occupy the first two slots; secondary
-- professions (Cooking, Fishing, Archaeology) occupy the remainder.
--
-- GetProfessions() returns up to five slot values:
--   prof1, prof2, archaeology, fishing, cooking
-- Each value is a slot index passed to GetProfessionInfo(), whose 7th return
-- value is the actual SkillLine ID used with C_TradeSkillUI.
function MissingRecipes.GetCharacterProfessions()
    local professions = {}

    -- GetProfessions returns up to 5 slot indices (or nil):
    --   prof1, prof2, archaeology, fishing, cooking
    -- Each slot index is passed to GetProfessionInfo().
    local slots = { GetProfessions() }

    for _, slot in ipairs(slots) do
        if slot then
            -- GetProfessionInfo return order (confirmed from Blizzard_ProfessionsBook.lua):
            -- name(1), texture(2), rank(3), maxRank(4), numSpells(5),
            -- spellOffset(6), skillLine(7), rankModifier(8),
            -- specializationIndex(9), specializationOffset(10), skillLineName(11)
            -- skillLine (7th) is the ID accepted by C_TradeSkillUI.OpenTradeSkill().
            local name, _, _, _, _, _, skillLine = GetProfessionInfo(slot)
            if name and skillLine and skillLine > 0 then
                table.insert(professions, { name = name, skillLineID = skillLine })
            end
        end
    end

    return professions
end
