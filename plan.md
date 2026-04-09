# MissingRecipes — Addon Plan

## Purpose

Show a scrollable frame listing unlearned recipes for a profession, triggered by a **"Missing Recipes" button injected into the Blizzard ProfessionsFrame**. The window scopes itself to whatever profession is currently open. The `/miser` slash command remains available as a secondary entry point that scans all professions.

---

## File Structure

```
MissingRecipes/
├── MissingRecipes.toc           — metadata, file load order
├── MissingRecipes.lua           — entry point: events, slash command, init
├── Constants.lua                — named constants (frame sizes, colours, etc.)
├── Core/
│   ├── Professions.lua          — detect which professions the character has
│   └── Recipes.lua              — fetch recipes (async queue for /miser; sync read for button)
└── UI/
    ├── MainFrame.lua            — create and manage the main popup frame
    ├── RecipeList.lua           — scrollable list widget populated with missing recipes
    └── ProfessionsButton.lua    — injects "Missing Recipes" button into ProfessionsFrame
```

---

## TOC File

```
## Interface: 120001
## Title: MissingRecipes
## Author: <your name>
## Version: 1.0.0
## Notes: Lists unlearned recipes for your known professions.

Constants.lua
Core/Professions.lua
Core/Recipes.lua
UI/MainFrame.lua
UI/RecipeList.lua
UI/ProfessionsButton.lua
MissingRecipes.lua
```

No SavedVariables are needed for v1 (data is derived live from the game state each session).

---

## Key WoW APIs

| Purpose                             | API                                                                                 |
| ----------------------------------- | ----------------------------------------------------------------------------------- |
| Get character's professions         | `GetProfessions()` → returns up to 5 slot indices                                   |
| Get info about a profession slot    | `GetProfessionInfo(index)` → name, skillLine, rank, maxRank                         |
| Open trade skill data silently      | `C_TradeSkillUI.OpenTradeSkill(skillLineID)`                                        |
| Get all recipe IDs for a profession | `C_TradeSkillUI.GetAllRecipeIDs()` (after opening)                                  |
| Get recipe details                  | `C_TradeSkillUI.GetRecipeInfo(recipeID)` → name, learned, categoryID                |
| Detect when recipe list is ready    | Event: `TRADE_SKILL_LIST_UPDATE`                                                    |
| Close trade skill (cleanup)         | `C_TradeSkillUI.CloseTradeSkill()`                                                  |
| Create scrollable list              | `CreateFrame("ScrollFrame")` + `FauxScrollFrame` helpers or `ScrollingMessageFrame` |
| Register slash command              | `SlashCmdList["MISER"]` + `SLASH_MISER1 = "/miser"`                                 |
| Detect profession window opening    | Event: `TRADE_SKILL_SHOW`                                                           |
| Get currently open profession info  | `C_TradeSkillUI.GetBaseProfessionInfo()` → `{ skillLineID, displayName, … }`        |
| Inject button into Blizzard frame   | `ProfessionsFrame` — the retail Professions UI container                            |

---

## Data Flow

### Primary path — button in ProfessionsFrame

```
Player opens a profession (ProfessionsFrame shows)
    └─► TRADE_SKILL_SHOW fires
            └─► MissingRecipes.lua: isFetching? → No
                    └─► ProfessionsButton.lua: inject "Missing Recipes" button (once)

Player clicks "Missing Recipes" button
    └─► C_TradeSkillUI.GetBaseProfessionInfo() → { displayName, skillLineID }
            └─► Recipes.lua: ReadCurrentProfessionRecipes()
                    └─► C_TradeSkillUI.GetAllRecipeIDs() (profession already open)
                            └─► for each ID: GetRecipeInfo() → filter learned == false
            └─► MainFrame.lua: SetFrameTitle(displayName) → Show frame
                    └─► RecipeList.lua: PopulateList({ [profName] = { ... } })
```

### Secondary path — /miser slash command (all professions)

```
/miser typed
    └─► Toggle MainFrame visibility
            └─► On first open (or on refresh):
                    └─► Professions.lua: GetProfessions() → list of {name, skillLineID}
                            └─► for each profession (queued sequentially):
                                    └─► C_TradeSkillUI.OpenTradeSkill(skillLineID)
                                            └─► isFetching = true
                                            └─► TRADE_SKILL_SHOW → suppress ProfessionsFrame
                                            └─► wait for TRADE_SKILL_LIST_UPDATE
                                                    └─► Recipes.lua: GetAllRecipeIDs()
                                                            └─► filter learned == false
                                            └─► C_TradeSkillUI.CloseTradeSkill()
                    └─► RecipeList.lua: render all professions grouped
```

---

## UI Design

- **ProfessionsFrame button**: `GameMenuButtonTemplate`, 130 × 22 px, anchored to the top-right of `ProfessionsFrame` below the close button. Label: "Missing Recipes". Only injected once per session (guarded by `buttonInjected` flag).
- **MainFrame**: bordered backdrop, ~400 × 500 px, centred on screen, moveable, closeable with ESC.
- **Header**: dynamic title showing the profession name (e.g. "Tailoring – Missing Recipes") + a "Refresh" button (only shown in /miser all-profession mode).
- **Body**: `ScrollFrame` with grouped rows — one section per profession (single section when opened from button).
- **Each row**: recipe name (white text).
- **Footer**: total count, e.g. "12 missing recipes".

---

## Implementation Steps

1. **TOC + folder** — create `MissingRecipes.toc` and empty Lua files matching the structure above.
2. **Constants.lua** — define frame dimensions, backdrop settings, colour constants.
3. **Core/Professions.lua** — `MissingRecipes.GetCharacterProfessions()` returns `{ {name, skillLineID}, … }`.
4. **Core/Recipes.lua** — (a) async fetch queue for `/miser`; (b) `ReadCurrentProfessionRecipes()` sync read for the button path; (c) `IsFetching()` accessor so the event handler can distinguish programmatic vs player-initiated opens.
5. **UI/MainFrame.lua** — `CreateMainFrame()` builds the frame; `ToggleFrame()` shows/hides; `SetFrameTitle(text)` updates the header title dynamically.
6. **UI/RecipeList.lua** — `PopulateList(data)` clears and re-renders the scroll list grouped by profession.
7. **UI/ProfessionsButton.lua** — on `TRADE_SKILL_SHOW` (non-fetching), injects a "Missing Recipes" button into `ProfessionsFrame`; on click, reads current profession synchronously and opens the scoped window.
8. **MissingRecipes.lua** — registers all events; `TRADE_SKILL_SHOW` branches on `IsFetching()`: if true, suppress `ProfessionsFrame`; if false, call `OnTradeSkillShow()` to inject the button.

---

## Events to Register

| Event                     | Handler                                                                                             |
| ------------------------- | --------------------------------------------------------------------------------------------------- |
| `PLAYER_LOGIN`            | Initialise the addon, print loaded message                                                          |
| `TRADE_SKILL_SHOW`        | If `IsFetching()` → suppress `ProfessionsFrame`. Otherwise → call `OnTradeSkillShow()` (inject btn) |
| `TRADE_SKILL_LIST_UPDATE` | If `IsFetching()` → read unlearned recipes for current queue entry                                  |
| `TRADE_SKILL_CLOSE`       | If `IsFetching()` → advance the profession queue                                                    |

---

## Edge Cases & Notes

- **No professions**: Show "No professions found" in the frame body.
- **All recipes learned**: Show "All recipes learned!" per profession section.
- **Secondary professions** (Cooking, Fishing, Archaeology): `GetProfessions()` returns these separately; include them if present.
- **Data timing**: Recipe data must be fetched asynchronously via `TRADE_SKILL_LIST_UPDATE`; never read `GetAllRecipeIDs()` synchronously before the event fires.
- **Multiple professions**: Queue them sequentially — open one, wait for event, collect, close, then open next.
- **isFetching flag**: The `TRADE_SKILL_SHOW` event fires both when the player opens a profession and when we open one programmatically. `IsFetching()` distinguishes the two cases so we don't suppress the player's UI or re-inject the button during a scan.
- **Button already injected**: `ProfessionsButton.lua` guards injection with a `buttonInjected` flag so repeated `TRADE_SKILL_SHOW` events don't create duplicate buttons.
- **Button path is synchronous**: When the player clicks the button, the profession is already open and `GetAllRecipeIDs()` is safe to call immediately — no async queue needed.
- **Avoid global pollution**: All module tables go under the `MissingRecipes` namespace; every helper is `local`.
