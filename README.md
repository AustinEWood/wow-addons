# wow-addons

A collection of World of Warcraft addons.

---

## CleanView

**Version:** 0.1.0  
**Interface:** 12.0.0.1 (The War Within)  
**Author:** awood

Quickly hide UI elements for immersive exploration or screenshots. Toggle individual UI groups on or off, or use the `/hide` preset to hide everything at once with a single command.

### Features

- Hide/show individual UI groups independently (chat, action bars, minimap, unit frames, etc.)
- `/hide` preset — configure which groups are hidden and toggle them all at once
- Per-character settings saved between sessions
- In-game options panel (accessible via **Escape → Options → AddOns → CleanView**)

### Slash Commands

| Command | Description |
|---|---|
| `/view` | Open the CleanView options panel |
| `/hide` | Hide all groups selected in the `/hide` preset |
| `/unhide` | Restore only the groups hidden by `/hide` |

#### Debug Commands

| Command | Description |
|---|---|
| `/cvdebug on\|off` | Enable or disable debug event capture |
| `/cvdebug clear` | Clear captured debug history |
| `/cvdump` | Print current anchor dump to chat |
| `/cvreport` | Open a copyable debug report window |

### UI Groups

The following groups can be independently toggled:

- **Chat** — Chat frames and buttons
- **Objectives Tracker** — Quest/objective tracker
- **Action Bars** — Main and extra action bars
- **Experience Bars** — XP and reputation tracking bars
- **Bag Buttons** — Backpack and bag slots
- **Menu** — Micro menu buttons
- **Buffs** — Buff, debuff, and enchant frames
- **Minimap** — Minimap cluster
- **Unit Frames** — Player, target, and focus frames
- **Stance Bar** — Stance/shapeshift bar

### Installation

1. Download or clone this repository.
2. Copy the `CleanView` folder into your WoW addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/CleanView
   ```
3. Launch WoW and enable **CleanView** in the AddOns list on the character select screen.
