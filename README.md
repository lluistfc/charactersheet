# CharacterSheet

CharacterSheet combines equipment, live attributes, skills, abilities, and gear
bonuses in one compact, draggable panel.

## Features

- Inline equipped-item icons beside every named gear entry in the expanded
  character sheet, with a compact 4x4 grid in collapsed mode.
- Hover an equipped icon for its name, combat values, description, and decoded
  augment lines when XIUI's local augment decoder is installed.
- Item icons are rendered directly from FFXI resources; no web downloads are
  required.
- Configurable combat, defensive, and magic skill rows with current value and
  job/level cap. Equipped skill modifiers are separated from trained points,
  for example `247 (+3) / 250`.
- Skill and ability search fields with configurable display ordering.
- Live character stats: HP, MP, STR, DEX, VIT, AGI, INT, MND, CHR, attack,
  defense, jobs, levels, and item level.
- Configurable job-ability rows with live Ready/recast state.
- Aggregated equipped gear stats and gear-provided skill bonuses.
- Augment lines decoded by XIUI are included in aggregated stats and skill
  bonuses.
- Equipment bonuses are grouped into attributes, offense, defense, casting,
  and utility sections with color-coded values.
- A `Config...` button directly in the character-sheet panel.
- A persistent `-` / `+` control hides the sheet completely when collapsed,
  leaving only the expand button beside the equipment grid's top-right corner.
- The entire addon automatically hides until the character is fully loaded,
  while zoning, and during cinematics.
- A dark, gold-accented character-sheet layout with capped skills and ready
  abilities highlighted.
- Generated dark-leather panel texture rendered using the same texture/tint
  approach as XIUI's party panels.
- Restrained classic recessed item slots with unobstructed icons and tooltips.
- A wide two-column dashboard inspired by classic FFXI character menus:
  character stats, named gear and equipment bonuses on the left; skill
  progression bars, abilities and skill bonuses on the right.
- When expanded, each live icon is integrated into its Gear row; when
  collapsed, the icons become a standalone 4x4 equipment grid.
- Display, Skills, and Abilities configuration tabs.
- Adjustable UI scale, high-contrast colors, and a reduced-texture mode.
- Full, Compact, Skills, and Gear section presets, individual section
  visibility controls, and saved per-job profiles.
- Responsive two-column/single-column layouts that remain inside the current
  game viewport.
- Current TP, item level, and master level in the character summary.
- Optional position locking and a reset-position command.
- Optional GearInfo combat-stat grid with gear/magic/JA haste, mitigation,
  TP/swing, x-hit, accuracy, attack, evasion, defense, Store TP, Dual Wield,
  and Martial Arts. It has its own draggable position and can remain visible
  when the main character sheet is collapsed or hidden.

Drag the expanded sheet from its title area, or drag the collapsed sheet from
the equipment grid.

## Commands

```text
/charactersheet
/charactersheet config
/charactersheet position <x> <y>
/charactersheet size <16|32|48|64>
/charactersheet reset
/charactersheet show
/charactersheet hide
/charactersheet toggle
/charactersheet exportall
/charactersheet exportgear
/charactersheet syncbrd [support|dmg|hybrid]
/charactersheet gearinfo
/charactersheet gearinfo show|hide|toggle
/charactersheet gearinfo lock
/charactersheet gearinfo dw
/charactersheet gearinfo scale <0.6-2.0>
/charactersheet gearinfo width <68-140>
/charactersheet gearinfo reset
```

`exportall` writes a JSON snapshot to `config/addons/charactersheet/`. It includes
all currently loaded items (with raw augment/extra bytes), equipment state,
attributes, resists, combat and crafting skills, every job's levels/master
levels/job points, progression, gil, Unity data, and character identity/rank.
The JSON also records unavailable categories explicitly: the public Ashita v4
Lua interfaces do not expose completed mission/quest bitfields, key items, or
most non-item currencies. Containers not loaded by the game client are reported
as unavailable rather than silently treated as empty.

`syncbrd` is a BRD-specific profile builder, not a generic file-sync command.
It supports three combat modes: `support` prioritizes song stats, `dmg`
prioritizes melee damage, accuracy, attack, and haste, and `hybrid` blends the
two (favoring melee). The default is `hybrid`. Weapon scoring uses damage and
delay instead of raw damage, so a slow high-damage staff does not automatically
beat faster dual-wield weapons. Song-casting sets remain support-focused in all
three modes.
It evaluates the character's currently available, equippable gear with custom
Bard logic and selects equipment for each situation represented by the Idle,
Engaged, Song, BuffSong, and individual song-family sets. The scoring favors the
stats relevant to each purpose, such as survivability while idle, melee stats
while engaged, and CHR, Magic Accuracy, Singing/Instrument skill, song duration,
and Fast Cast for songs. It then updates those sets in the BRD LuAshitacast
profile, lists unused main-Inventory items, and reloads the profile.

It discovers both LuAshitacast's `<Character>_BRD.lua` and
`<Character>_<server-id>/BRD.lua` profile layouts, preserves the profile's event
logic, and writes a `.syncbrd.bak` backup first. If multiple profiles match and
the current server ID does not identify one, it stops without modifying them.

Only BRD is supported today because each job needs its own purpose-built gear
selection rules and profile sets. Similar synchronization may be added for
other jobs someday, but that expansion is not currently promised or scheduled.

```text
/addon unload equipviewer
/addon unload skillwatch
/addon load charactersheet
```

Settings are stored per character by Ashita's settings library.

## Original projects

CharacterSheet combines and substantially extends ideas and code from more
than one addon:

- Project Tako's EquipViewer for Ashita:
  [ProjectTako/ffxi-addons](https://github.com/ProjectTako/ffxi-addons/tree/master/equipviewer)
- sebyg666's GearInfo for Windower:
  [sebyg666/GearInfo](https://github.com/sebyg666/GearInfo)

There is no single upstream CharacterSheet repository.
