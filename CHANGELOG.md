# Changelog - Nullgate's Who Whispered Me (Forever)

All notable changes to **Nullgate's Who Whispered Me - Forever** are documented below.

## [1.0.0-beta.1] - 2026-11-24: First Beta

The first test version. Everything below is built and tested outside the game, but not yet in the real client, so please report anything that doesn't work.

### New

- **One list of everyone who whispers you** while you form a group: name, level, class, armor, race, guild, zone, their latest message and how long ago they wrote.
- **Class and race straight away** for every whisper. Level comes from your group, target, mouseover, nameplates, guild and friends lists, or an earlier lookup, when any of them know it.
- **Look up next**: one click (or its key binding) sends a /who for the newest player without a level. The game only allows a /who from a click or key press, with a short wait between them; the button shows the queue and the wait.
- **Sorting**: click a column header to sort, click again to reverse, Shift-click for a second sort.
- **Filters that combine**: class, level ranges (such as `20-29, 58-60` or `55+`), armor type, role, guild, a search box, and hiding players whose level is unknown or who weren't found.
- **Roles from the whisper**: words like "tank", "heals" or "dps" (in all 10 languages) show as a tag and feed the role filter.
- **Row actions**: click to whisper, double-click to invite, right-click for Whisper, Invite, Look up now, Copy name and Dismiss.
- **Listening**: starts by itself while your group is listed in the Looking For Group window, and `/nwho listen` or the box in the window turns it on for groups you form in chat. When listening stops, the list is kept for 15 minutes (you can change this), then cleared.
- **Settings** in its own window (`/nwho options`) or inside Nullgate's Addon Config.
- `/nwho check`: a self test of the /who calls in your client, with a bug report window ready to copy.

### Good to know

- Forever names have a first name and a surname; lookups use the whole name, so "Herald Talenel" isn't confused with another Herald.
- Players who don't answer a /who (offline, or a typo) are marked **Not found** and tried once more after 5 minutes.
