# Missing Recipes

A World of Warcraft addon that helps you quickly find and learn unlearned profession recipes.

## Features

- **Organized Recipe Browser**: Display all unlearned recipes organized in a professional TreeListView, grouped by expansion and item type
- **Detailed Recipe Information**: Click any recipe to see comprehensive details including:
  - Recipe ID with direct Wowhead link
  - Difficulty level and trivial skill threshold
  - Output item with rarity-based coloring and transmog status
  - Item type (Armor, Weapon, Consumable, etc.)
  - Item level, quantity, and maximum quality
  - How to obtain the recipe (vendors, quests, drops, etc.)
  - Crafting progression information
- **Interactive Item Links**: Click item names to preview in the Dressing Room (for equippable items) or right-click to insert into chat
- **Transmog Detection**: Automatically identifies whether you've collected an item's appearance for transmog purposes
- **Professional UI**: Matches Blizzard's crafting window styling with hover effects and collapse/expand controls

## Installation

1. Extract the `MissingRecipes` folder into your WoW `Interface/AddOns/` directory
2. Restart World of Warcraft or type `/reload` in-game
3. The addon will appear in your addon list with a book icon

## Usage

1. Open any profession window (Tailoring, Engineering, Blacksmithing, etc.)
2. Click the **"Missing Recipes"** button at the bottom of the profession window
3. A list of all unlearned recipes will appear, organized by expansion and item type
4. Click any recipe in the list to view detailed information in the detail pane
5. Click the item name to preview it or right-click to link it in chat

## How It Works

The addon:

- Scans the currently open profession for all unlearned recipes
- Extracts item type, rarity, and transmog appearance status from crafted items
- Groups recipes hierarchically: **Expansion → Item Type → Recipe**
- Displays recipes newest-first (Midnight at top, Classic at bottom)
- Caches profession data for quick switching between professions

## Hierarchy Example

```
Midnight (5)              ← Expansion header (collapse/expand)
├── Armor (2)             ← Item type subheader
│   ├── Spellweave Cord   ← Recipe name (click to view details)
│   └── Vibrant Shard
└── Weapon (3)
    ├── Mystic Blade
    ├── Enchanted Staff
    └── Shadow Dagger
```

## Detail Pane Sections

**Identity**

- Recipe ID (with Wowhead link)
- Expansion name

**Difficulty**

- Difficulty rating (Trivial, Easy, Medium, Hard, Impossible)
- Trivial skill threshold
- Number of skill-ups available

**Output**

- Item name (rarity-colored, clickable)
- Item type and subtype (e.g., "Armor (Cloth)")
- Rarity (Poor, Common, Uncommon, Rare, Epic, Legendary, Artifact)
- Bind type (BoP, BoE, BoA, Quest)
- Transmog appearance status (if applicable)
- Item level, quantity, and maximum quality tiers

**Progression** (if applicable)

- Recipe level unlock point
- Current and next level recipe experience

**Source**

- How to obtain the recipe (vendor, quest, drop location, etc.)

## Commands

No slash commands are needed. Everything is accessed through the "Missing Recipes" button in profession windows.

## Compatibility

- **WoW Version**: Retail (11.0.1+)
- **Localization**: English (enUS)
- **Dependencies**: None (standalone addon)

## Technical Details

- **Lua 5.1** compliant code following WoW addon standards
- **TreeListView** for efficient hierarchical rendering
- **SavedVariables**: None (stateless design)
- **Protected Functions**: Does not attempt to circumvent WoW's protection system
- Optimized API usage: Single-pass item info collection, module-level constant tables

## Known Limitations

- Only scans professions when you manually open them and click the button
- Transmog detection relies on tooltip text parsing (robust but text-dependent)
- Item types are detected from the game's item classification system

## Troubleshooting

**No recipes showing up?**

- Make sure you're in a profession window when you click the button
- Ensure BOTH learned and unlearned recipes are visible in the profession UI

**Transmog status incorrect?**

- This uses tooltip parsing, so it depends on game text. Items that can't be transmogged won't show a transmog line.

**Button not appearing?**

- Try reloading the UI: `/reload`
- Check that the addon is enabled in the addon list

## Development

Folder structure:

```
MissingRecipes/
├── Core/
│   ├── Recipes.lua       (Recipe data fetching and scanning)
│   └── Professions.lua   (Profession detection)
├── UI/
│   ├── MainFrame.lua     (Main window management)
│   ├── RecipeList.lua    (TreeListView setup and rendering)
│   ├── DetailFrame.lua   (Recipe detail pane)
│   └── ProfessionsButton.lua (Profession window integration)
├── XML/
│   └── Templates.xml     (UI frame templates)
├── MissingRecipes.lua    (Event handler and initialization)
├── Constants.lua         (Configuration and constants)
├── MissingRecipes.toc    (Addon manifest)
└── README.md
```

## License

This addon is provided as-is for personal use in World of Warcraft.

## Support

For issues or feature requests, check that your addon is up to date and that you're running a supported WoW version.
