**Nullgate's Who Whispered Me** is a group-forming addon for **World of Warcraft: Forever**. When you put a group together, whispers pile up fast, and finding out each player's level means typing `/who Name` one at a time. This addon collects everyone who whispers you into one window, with their **level, class, armor, guild and zone**, and lets you sort and filter the list to pick your group quickly.

> **Beta:** this is an early test version. If something doesn't work, run `/nwho check`, then send us the results with a short description.

---

## Features

- **One list of everyone who whispers you**, even when a chat addon opens each whisper in its own tab.
- **Class and race at once** for every whisper. **Level** comes from your group, your target, mouseover, nameplates, your guild and friends lists, or an earlier lookup, whenever any of them know it.
- **Look up next**: one click, or its key binding, sends a /who for the newest player whose level isn't known yet. The button shows how many are waiting and when the next lookup is allowed.
- **Sort by any column**: name, level, class, armor, race, guild, zone, message, time or status. Shift-click a second column to sort within the first.
- **Filters that combine**: class, level ranges (such as `20-29, 58-60` or `55+`), armor type (cloth, leather, mail, plate), role (tank, healer, damage), guild, and a search box over names, guilds and messages.
- **Roles from the whisper**: "tank", "heals", "dps" and the same words in all 10 languages show as a tag next to the message.
- **Quick actions**: click a player to whisper them, double-click to invite, right-click to look them up now, copy their name or dismiss them.
- **Players already in your group** are dimmed and drop to the bottom.
- **Settings** in its own window or inside Nullgate's Addon Config.

---

## How It Works

1. **List your group** in the Looking For Group window and the addon starts listening by itself. Forming a group in chat instead? Turn on **Listening** with `/nwho listen` or the box at the bottom of the window.
2. **Whispers arrive** and each player gets a row at once, with class and race. If the level is already known, it's filled in too.
3. **Press Look up next** (or its key) to look up the next player without a level. Their level, guild and zone appear when the answer comes back.
4. **Sort, filter and invite** the players you want.

When you stop listening, the list stays for 15 minutes (you can change this), so a quick relist keeps it.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nwho` or `/whowhispered` | Open or close the window. |
| `/nwho listen` | Start or stop listening for whispers (`/nwho listen on` / `off`). |
| `/nwho clear` | Clear the list. |
| `/nwho options` | Open the settings. |
| `/nwho check` | Test the addon in your game client and open a bug report to copy. |

Key bindings for **Look up the next player** and **Open or close the window** are under Key Bindings > AddOns.

---

## Supported Languages

All 10 languages the game client runs in:

- English
- Deutsch (German)
- Español (Spanish)
- Français (French)
- Italiano (Italian)
- Português do Brasil (Brazilian Portuguese)
- Русский (Russian)
- 한국어 (Korean)
- 简体中文 (Simplified Chinese)
- 繁體中文 (Traditional Chinese)

The addon uses your game's language automatically. You can switch at any time in the settings; it applies after a `/reload`. The translations were made with machine assistance, so some wording may not be quite right. Corrections are welcome: send a message here on CurseForge or [report on our website](https://nullgatestudios.com/report?addon=who-whispered-me).

---

## Installation

1. Download the latest release.
2. Extract the `NullgatesWhoWhisperedMe-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in and type `/nwho`.

---

## Good to Know

- **Why a button for lookups?** The game only lets an addon send a /who when you click or press a key, and it asks for a short wait between them. So the addon can't look everyone up on its own; one press looks up one player.
- **Not found** means the /who found nobody, usually because they logged off. They're tried once more after 5 minutes.
- Levels from an earlier lookup show in **grey**, since the player may have levelled since.
- Armor follows the usual rules: Hunters and Shamans wear mail, and Warriors and Paladins wear plate, from level 40.
