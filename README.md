# Nullgate's Who Whispered Me - Forever

> **Status: beta** (1.0.0-beta.1). Not yet tested in the real client. See [CHANGELOG.md](CHANGELOG.md).

**Nullgate's Who Whispered Me** is a group-forming addon for **World of Warcraft: Forever**. It collects everyone who whispers you while you form a group into one sortable, filterable window with their level, class, armor, guild and zone.

---

## How It Works

1. **Listening** collects every whisper into the list. It is on while your group is listed in Forever's group finder (`C_LFGList.HasActiveEntryInfo`, `LFG_LIST_ACTIVE_ENTRY_UPDATE`, used by its Listing tab), or while the switch (`/nwho listen`) is on.
2. **Free information first**: class and race come from the whisper's GUID; level comes from your group, target, mouseover, nameplates, guild and friends lists, or levels remembered from earlier lookups.
3. **One /who per click**: the game only sends a /who from a click or key press (tested in Forever: a /who sent from a timer is dropped silently), with a short server cooldown. **Look up next** and its key binding send one exact-name /who (`n-"Name"`) for the newest player without a level. The server's "You must wait N seconds" line sets the next allowed time and is hidden from chat.
4. Forever's group finder opens its Who tab (`LFGParentFrame`) on every `WHO_LIST_UPDATE`; when our lookup opened it, it is closed again.
5. A /who answer without our player (one you typed yourself) puts the player back in the queue; no answer within 5 seconds does too.

## Code

| File | What it does |
| :--- | :--- |
| `Safe.lua` | Guards for Forever's secret values. |
| `Data.lua` | Armor by class and level, roles by class, role words in 10 languages. |
| `Roster.lua` | The list, the lookup queue, filters and sorting (no game calls; `tests/run.lua`). |
| `Sources.lua` | Class and level without a /who. |
| `Who.lua` | /who lookups, answers, the cooldown and timeouts. |
| `UI.lua` | The window. |
| `Options.lua` | Settings (own window and Nullgate's Addon Config). |
| `Check.lua` | `/nwho check` and the shared bug report window. |
| `Core.lua` | Saved data, events, listening and slash commands. |

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nwho` or `/whowhispered` | Open or close the window. |
| `/nwho listen [on\|off]` | Start or stop listening. |
| `/nwho clear` | Clear the list. |
| `/nwho options` | Open the settings. |
| `/nwho check` | Self test and bug report window. |

## Tests

```
lua tests/run.lua      # list, filters, sorting, queue
lua tests/smoke.lua    # the whole addon with stand-in game API
lua tests/locales.lua  # every string in all 10 languages
```

`package.ps1` runs them and builds the zip.
