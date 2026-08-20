local imgui = require('imgui');
local skilldata = require('skilldata');
local theme = require('theme');
local equipment = require('equipment');
local set_window_font_scale = imgui.SetWindowFontScale or function () end;

local M = {};

local job_names = T{
    [0] = 'NON', 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK',
    'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP',
    'DNC', 'SCH', 'GEO', 'RUN',
};
local stat_names = T{ 'STR', 'DEX', 'VIT', 'AGI', 'INT', 'MND', 'CHR' };
local gear_slots = T{
    { 0, 'Main' }, { 1, 'Sub' }, { 2, 'Ranged' }, { 3, 'Ammo' },
    { 4, 'Head' }, { 9, 'Neck' }, { 11, 'Ear 1' }, { 12, 'Ear 2' },
    { 5, 'Body' }, { 6, 'Hands' }, { 13, 'Ring 1' }, { 14, 'Ring 2' },
    { 15, 'Back' }, { 10, 'Waist' }, { 7, 'Legs' }, { 8, 'Feet' },
};

M.groups = T{
    { name = 'Weapon Skills', skills = T{
        { 1, 'h2h' }, { 2, 'dagger' }, { 3, 'sword' }, { 4, 'great_sword' },
        { 5, 'axe' }, { 6, 'great_axe' }, { 7, 'scythe' }, { 8, 'polearm' },
        { 9, 'katana' }, { 10, 'great_katana' }, { 11, 'club' }, { 12, 'staff' },
        { 25, 'archery' }, { 26, 'marksmanship' }, { 27, 'throwing' },
    } },
    { name = 'Defensive Skills', skills = T{
        { 28, 'guarding' }, { 29, 'evasion' }, { 30, 'shield' }, { 31, 'parrying' },
    } },
    { name = 'Magic Skills', skills = T{
        { 32, 'divine' }, { 33, 'healing' }, { 34, 'enhancing' }, { 35, 'enfeebling' },
        { 36, 'elemental' }, { 37, 'dark' }, { 38, 'summoning' }, { 39, 'ninjutsu' },
        { 40, 'singing' }, { 41, 'string' }, { 42, 'wind' }, { 43, 'blue' },
        { 44, 'geomancy' }, { 45, 'handbell' },
    } },
};

M.default_settings = T{
    visible = T{ true },
    collapsed = T{ false },
    ui_scale = T{ 1.0 },
    high_contrast = T{ false },
    reduce_texture = T{ false },
    lock_position = T{ false },
    equipped_weapon = T{ true },
    hide_unavailable = T{ true },
    show_gear_stats = T{ true },
    sections = T{
        stats = T{ true },
        gear = T{ true },
        equipment_bonuses = T{ true },
        skills = T{ true },
        abilities = T{ true },
        skill_bonuses = T{ true },
    },
    skill_order = T{},
    job_profiles = {},
    ability_ids = T{},
    tracked = T{
        h2h = T{ false }, dagger = T{ false }, sword = T{ false }, great_sword = T{ false },
        axe = T{ false }, great_axe = T{ false }, scythe = T{ false }, polearm = T{ false },
        katana = T{ false }, great_katana = T{ false }, club = T{ false }, staff = T{ false },
        archery = T{ false }, marksmanship = T{ false }, throwing = T{ false },
        guarding = T{ false }, evasion = T{ false }, shield = T{ false }, parrying = T{ false },
        divine = T{ false }, healing = T{ false }, enhancing = T{ false }, enfeebling = T{ false },
        elemental = T{ false }, dark = T{ false }, summoning = T{ false }, ninjutsu = T{ false },
        singing = T{ false }, string = T{ false }, wind = T{ false }, blue = T{ false },
        geomancy = T{ false }, handbell = T{ false },
    },
};

local gear_defs = T{
    { 'Magic Evasion', 'magic%s+evasion%s*([%+%-]%d+)' },
    { 'Magic Accuracy', 'magic%s+accuracy%s*([%+%-]%d+)' },
    { 'Magic Attack', 'magic%s+attack%s+bonus%s*([%+%-]%d+)' },
    { 'Ranged Accuracy', 'ranged%s+accuracy%s*([%+%-]%d+)' },
    { 'Ranged Attack', 'ranged%s+attack%s*([%+%-]%d+)' },
    { 'Double Attack', 'double%s+attack%s*([%+%-]%d+)', '%' },
    { 'Triple Attack', 'triple%s+attack%s*([%+%-]%d+)', '%' },
    { 'Quadruple Attack', 'quadruple%s+attack%s*([%+%-]%d+)', '%' },
    { 'Fast Cast', 'fast%s+cast%s*([%+%-]%d+)', '%' },
    { 'Store TP', 'store%s+tp%s*([%+%-]%d+)' },
    { 'Subtle Blow', 'subtle%s+blow%s*([%+%-]%d+)' },
    { 'Weapon Skill Damage', 'weapon%s+skill%s+damage%s*([%+%-]%d+)', '%' },
    { 'Skillchain Damage', 'skillchain%s+damage%s*([%+%-]%d+)', '%' },
    { 'Magic Burst Damage', 'magic%s+burst%s+damage%s*([%+%-]%d+)', '%' },
    { 'Cure Potency', 'cure%s+potency%s*([%+%-]%d+)', '%' },
    { 'Physical DT', 'physical%s+damage%s+taken%s*([%+%-]%d+)', '%' },
    { 'Magic DT', 'magic%s+damage%s+taken%s*([%+%-]%d+)', '%' },
    { 'Damage Taken', 'damage%s+taken%s*([%+%-]%d+)', '%' },
    { 'Accuracy', 'accuracy%s*([%+%-]%d+)' },
    { 'Attack', 'attack%s*([%+%-]%d+)' },
    { 'Evasion', 'evasion%s*([%+%-]%d+)' },
    { 'Haste', 'haste%s*([%+%-]%d+)', '%' },
    { 'HP', 'hp%s*([%+%-]%d+)' }, { 'MP', 'mp%s*([%+%-]%d+)' },
    { 'STR', 'str%s*([%+%-]%d+)' }, { 'DEX', 'dex%s*([%+%-]%d+)' },
    { 'VIT', 'vit%s*([%+%-]%d+)' }, { 'AGI', 'agi%s*([%+%-]%d+)' },
    { 'INT', 'int%s*([%+%-]%d+)' }, { 'MND', 'mnd%s*([%+%-]%d+)' },
    { 'CHR', 'chr%s*([%+%-]%d+)' }, { 'DEF', 'def%s*:?%s*([%+%-]?%d+)' },
};

local skill_bonus_defs = T{};
local skill_bonus_order = T{ 1, 4, 6, 10, 2, 3, 5, 7, 8, 9, 11, 12, 25, 26, 27,
    28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45 };
skill_bonus_order:each(function (id)
    local name = skilldata.names[id];
    local pattern = name:lower()
        :gsub('%-', '%%-')
        :gsub('great ', 'great%%s+')
        :gsub(' magic', '%%s+magic')
        :gsub('stringed', 'string')
        :gsub(' instrument', '%%s+instrument');
    skill_bonus_defs:append({ name .. ' Skill', pattern .. '%s+skill%s*([%+%-]%d+)' });
end);
skill_bonus_defs:append({ 'All Combat Skills', 'all%s+combat%s+skills?%s*([%+%-]%d+)' });
skill_bonus_defs:append({ 'All Magic Skills', 'all%s+magic%s+skills?%s*([%+%-]%d+)' });
skill_bonus_defs:append({ 'Combat Skill', 'combat%s+skill%s*([%+%-]%d+)' });
skill_bonus_defs:append({ 'Magic Skill', 'magic%s+skill%s*([%+%-]%d+)' });
T{
    'Automaton Melee', 'Automaton Ranged', 'Automaton Magic', 'Fishing',
    'Woodworking', 'Smithing', 'Goldsmithing', 'Clothcraft', 'Leathercraft',
    'Bonecraft', 'Alchemy', 'Cooking', 'Synergy',
}:each(function (name)
    skill_bonus_defs:append({
        name .. ' Skill',
        name:lower():gsub(' ', '%%s+') .. '%s+skill%s*([%+%-]%d+)',
    });
end);

local state = {
    settings = nil,
    save = nil,
    config_open = T{ false },
    ability_cache_key = '',
    abilities = T{},
    skill_search = T{ '' },
    ability_search = T{ '' },
    panel_width = T{ 1100 },
    set_panel_width = nil,
    toggle_gearinfo = nil,
    gear_counter = -1,
    gear_stats = T{},
    gear_skills = T{},
    gear_skill_values = {},
};

local function resource_text(field)
    if (field == nil) then return ''; end
    local ok, value = pcall(function () return field[1]; end);
    return ok and type(value) == 'string' and value or '';
end

local function normalize_bonus_text(text)
    return (text or ''):lower()
        :gsub('"', ''):gsub('[\r\n]', ' ')
        :gsub('mag%.?%s*acc%.?', 'magic accuracy')
        :gsub('mag%.?%s*atk%.?%s*bns%.?', 'magic attack bonus')
        :gsub('mag%.?%s*eva%.?', 'magic evasion')
        :gsub('rng%.?%s*acc%.?', 'ranged accuracy')
        :gsub('rng%.?%s*atk%.?', 'ranged attack')
        :gsub('phys%.?%s*dmg%.?%s*taken', 'physical damage taken')
        :gsub('magic%s+dmg%.?%s*taken', 'magic damage taken')
        :gsub('dbl%.?%s*atk%.?', 'double attack')
        :gsub('triple%s+atk%.?', 'triple attack')
        :gsub('quadruple%s+atk%.?', 'quadruple attack')
        :gsub('weaponskill%s+damage', 'weapon skill damage')
        :gsub('skillchain%s+dmg%.?', 'skillchain damage')
        :gsub('enha%.?%s*mag%.?%s*skill', 'enhancing magic skill')
        :gsub('enfb%.?%s*mag%.?%s*skill', 'enfeebling magic skill')
        :gsub('elem%.?%s*magic%s*skill', 'elemental magic skill');
end

local function normalize_description(item)
    return normalize_bonus_text(resource_text(item and item.Description));
end

local function equipped_instance(slot)
    return equipment.get_equipped(slot);
end

local function get_equipped_skill()
    local _, item = equipped_instance(0);
    if (item ~= nil and skilldata.names[item.Skill] ~= nil) then return item.Skill; end
    return 1;
end

local function get_cap(id)
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return nil; end
    local ranks = skilldata.ranks[id];
    if (ranks == nil) then return nil; end
    local rank = ranks[player:GetMainJob()] or 0;
    local level = player:GetMainJobLevel();
    local main = rank > 0;
    if (not main) then rank = ranks[player:GetSubJob()] or 0; level = player:GetSubJobLevel(); end
    if (rank == 0 or level == 0 or skilldata.caps[rank] == nil) then return nil; end
    level = math.max(1, math.min(99, level));
    local cap = skilldata.caps[rank][level + 1];
    if (main and level == 99) then cap = cap + math.max(0, player:GetMasteryJobLevel() or 0); end
    return cap;
end

local function selected_skills()
    local out, added = T{}, {};
    if (state.settings.equipped_weapon[1]) then
        local id = get_equipped_skill();
        out:append(id); added[id] = true;
    end
    for _, id in ipairs(state.settings.skill_order) do
        M.groups:each(function (group)
            group.skills:each(function (entry)
                if (entry[1] == tonumber(id) and state.settings.tracked[entry[2]][1]
                        and not added[entry[1]]) then
                    out:append(entry[1]); added[entry[1]] = true;
                end
            end);
        end);
    end
    M.groups:each(function (group)
        group.skills:each(function (entry)
            if (state.settings.tracked[entry[2]][1] and not added[entry[1]]) then
                out:append(entry[1]); added[entry[1]] = true;
            end
        end);
    end);
    return out;
end

local function collect_gear()
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    local counter = inv:GetContainerUpdateCounter();
    if (counter == state.gear_counter) then
        return state.gear_stats, state.gear_skills, state.gear_skill_values;
    end
    local totals, skills = {}, {};
    for slot = 0, 15 do
        local instance, item = equipped_instance(slot);
        if (item ~= nil) then
            local desc = normalize_description(item);
            local augment_lines = equipment.get_augment_lines(instance);
            for _, line in ipairs(augment_lines) do
                desc = desc .. ' ' .. normalize_bonus_text(line);
            end
            local description_has_def = desc:find('def%s*:', 1) ~= nil;
            skill_bonus_defs:each(function (def)
                desc = desc:gsub(def[2], function (v)
                    skills[def[1]] = (skills[def[1]] or 0) + (tonumber(v) or 0);
                    return ' ';
                end);
            end);
            gear_defs:each(function (def)
                desc = desc:gsub(def[2], function (v)
                    totals[def[1]] = (totals[def[1]] or 0) + (tonumber(v) or 0);
                    return ' ';
                end);
            end);
            if (not description_has_def) then
                local defense = tonumber(item.Defense) or 0;
                if (defense > 0) then totals.DEF = (totals.DEF or 0) + defense; end
            end
        end
    end
    local stat_rows, skill_rows = T{}, T{};
    for index, def in ipairs(gear_defs) do
        local v = totals[def[1]];
        if (v and v ~= 0) then
            local label = def[1];
            local category = 'Utility';
            if (label:any('STR', 'DEX', 'VIT', 'AGI', 'INT', 'MND', 'CHR', 'HP', 'MP')) then
                category = 'Attributes';
            elseif (label:any('Magic Accuracy', 'Magic Attack', 'Fast Cast', 'Cure Potency')) then
                category = 'Casting';
            elseif (label:find('Accuracy') or label:find('Attack')
                    or label:any('Double Attack', 'Triple Attack', 'Quadruple Attack',
                        'Store TP', 'Weapon Skill Damage', 'Skillchain Damage')) then
                category = 'Offense';
            elseif (label:find('Evasion') or label:any('DEF', 'Physical DT', 'Magic DT',
                    'Damage Taken', 'Subtle Blow')) then
                category = 'Defense';
            end
            stat_rows:append({
                label = label,
                value = v,
                suffix = def[3] or '',
                category = category,
                order = index,
            });
        end
    end
    local category_order = {
        Attributes = 1, Offense = 2, Defense = 3, Casting = 4, Utility = 5,
    };
    stat_rows:sort(function (a, b)
        local left = category_order[a.category] or 99;
        local right = category_order[b.category] or 99;
        return left == right and a.order < b.order or left < right;
    end);
    skill_bonus_defs:each(function (def)
        local v = skills[def[1]];
        if (v and v ~= 0) then skill_rows:append(('%s %s%d'):fmt(def[1], v > 0 and '+' or '', v)); end
    end);

    -- Keep a per-skill modifier map so the UI can show trained points from
    -- GetCombatSkill and equipment points separately.
    local skill_values = {};
    skill_bonus_order:each(function (id)
        local value = skills[(skilldata.names[id] or '') .. ' Skill'] or 0;
        if (id >= 1 and id <= 31) then
            value = value + (skills['All Combat Skills'] or 0) + (skills['Combat Skill'] or 0);
        elseif (id >= 32 and id <= 45) then
            value = value + (skills['All Magic Skills'] or 0) + (skills['Magic Skill'] or 0);
        end
        skill_values[id] = value;
    end);

    state.gear_counter = counter;
    state.gear_stats = stat_rows;
    state.gear_skills = skill_rows;
    state.gear_skill_values = skill_values;
    return stat_rows, skill_rows, skill_values;
end

local function ability_name(ability)
    return resource_text(ability and ability.Name);
end

local function refresh_abilities()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil or player.HasAbility == nil) then
        state.abilities = T{};
        return;
    end
    local key = ('%d:%d:%d:%d'):fmt(player:GetMainJob(), player:GetMainJobLevel(), player:GetSubJob(), player:GetSubJobLevel());
    if (state.ability_cache_key == key) then return; end
    local found, seen = T{}, {};
    for _, id in ipairs(state.settings.ability_ids) do seen[tonumber(id)] = true; end
    for id = 0, 1023 do
        local ok, known = pcall(player.HasAbility, player, id);
        if (ok and known) then seen[id] = true; end
    end
    for id in pairs(seen) do
        local ability = AshitaCore:GetResourceManager():GetAbilityById(id);
        if (ability ~= nil and ability_name(ability) ~= '') then found:append({ id = id, resource = ability }); end
    end
    found:sort(function (a, b) return ability_name(a.resource) < ability_name(b.resource); end);
    state.abilities, state.ability_cache_key = found, key;
end

local function ability_selected(id)
    for _, value in ipairs(state.settings.ability_ids) do if (tonumber(value) == id) then return true; end end
    return false;
end

local function set_ability(id, enabled)
    local result = T{};
    for _, value in ipairs(state.settings.ability_ids) do
        if (tonumber(value) ~= id) then result:append(tonumber(value)); end
    end
    if (enabled) then result:append(id); end
    state.settings.ability_ids = result;
    state.save();
end

local function move_array_value(values, index, delta)
    local target = index + delta;
    if (index < 1 or index > #values or target < 1 or target > #values) then return; end
    local value = table.remove(values, index);
    table.insert(values, target, value);
    state.save();
end

local function array_index(values, wanted)
    for index, value in ipairs(values) do
        if (tonumber(value) == tonumber(wanted)) then return index; end
    end
    return nil;
end

local function ensure_skill_order(id)
    for _, value in ipairs(state.settings.skill_order) do
        if (tonumber(value) == id) then return; end
    end
    state.settings.skill_order:append(id);
end

local function ability_recast(timer_id)
    local recast = AshitaCore:GetMemoryManager():GetRecast();
    for index = 0, 31 do
        if (recast:GetAbilityTimerId(index) == timer_id) then return recast:GetAbilityTimer(index); end
    end
    return 0;
end

local function format_recast(raw)
    if (raw <= 0) then return 'Ready'; end
    local seconds = math.ceil(raw / 60);
    if (seconds >= 60) then return ('%d:%02d'):fmt(math.floor(seconds / 60), seconds % 60); end
    return ('%ds'):fmt(seconds);
end

local function section_header(label)
    imgui.Spacing();
    imgui.TextColored(theme.colors.accent, label:upper());
    imgui.Separator();
end

local function render_current_stats(player)
    local party = AshitaCore:GetMemoryManager():GetParty();
    local hp = party ~= nil and party:GetMemberHP(0) or 0;
    local mp = party ~= nil and party:GetMemberMP(0) or 0;
    local tp = party ~= nil and party:GetMemberTP(0) or 0;
    local mp_max = tonumber(player:GetMPMax()) or 0;

    section_header('Current Stats');
    imgui.Columns(2, '##vitals', false);
    imgui.TextColored(theme.colors.good,
        ('HP  %d / %d'):fmt(tonumber(hp) or 0, tonumber(player:GetHPMax()) or 0));
    imgui.NextColumn();
    if (mp_max > 0) then
        imgui.TextColored(theme.colors.link, ('MP  %d / %d'):fmt(tonumber(mp) or 0, mp_max));
    else
        imgui.TextColored(theme.colors.muted, 'MP  --');
    end
    imgui.NextColumn();
    imgui.Text(('ATK  %d'):fmt(tonumber(player:GetAttack()) or 0));
    imgui.NextColumn();
    imgui.Text(('DEF  %d'):fmt(tonumber(player:GetDefense()) or 0));
    imgui.NextColumn();
    imgui.TextColored(theme.colors.accent, ('TP   %d'):fmt(tonumber(tp) or 0));
    imgui.NextColumn();
    imgui.Text('');
    imgui.Columns(1);

    imgui.Spacing();
    imgui.Columns(4, '##attributes', false);
    for index, name in ipairs(stat_names) do
        local base = tonumber(player:GetStat(index - 1)) or 0;
        local modifier = tonumber(player:GetStatModifier(index - 1)) or 0;
        imgui.Text(('%s  %d'):fmt(name, base + modifier));
        if (modifier ~= 0 and imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.Text(('%d base  %s%d modifier'):fmt(base, modifier > 0 and '+' or '', modifier));
            imgui.EndTooltip();
        end
        imgui.NextColumn();
    end
    imgui.Columns(1);
end

local function render_gear_entry(entry, id_suffix)
    local instance, item = equipment.render_slot(entry[1], 32, id_suffix);
    local name = resource_text(item and item.Name);
    imgui.SameLine();
    imgui.BeginGroup();
    imgui.TextColored({ 0.72, 0.62, 0.43, 1.0 }, entry[2]);
    imgui.TextColored(theme.colors.link, name ~= '' and name or '--');
    if (instance ~= nil and item ~= nil and imgui.IsItemHovered()) then
        equipment.render_tooltip(instance, item);
    end
    imgui.EndGroup();
end

local function render_equipment_list(single_column)
    section_header('Gear');
    imgui.Columns(single_column and 1 or 2, '##gear_entries', false);
    if (single_column) then
        for index, entry in ipairs(gear_slots) do
            render_gear_entry(entry, ('gear_%d'):fmt(index));
            imgui.NextColumn();
        end
        imgui.Columns(1);
        return;
    end
    for row = 1, 8 do
        for column = 0, 1 do
            local entry = gear_slots[row + column * 8];
            render_gear_entry(entry, ('gear_%d_%d'):fmt(row, column));
            imgui.NextColumn();
        end
    end
    imgui.Columns(1);
end

local function render_equipment_bonuses(width)
    local stats, skills = collect_gear();
    if (#stats > 0) then
        section_header('Equipment Bonuses');
        local current_category = nil;
        stats:each(function (bonus)
            if (bonus.category ~= current_category) then
                if (current_category ~= nil) then imgui.Spacing(); end
                current_category = bonus.category;
                imgui.TextColored(theme.colors.muted, current_category:upper());
            end
            imgui.Columns(2, '##equipment_bonus_' .. bonus.label, false);
            imgui.SetColumnWidth(0, width - 72);
            imgui.Text(bonus.label);
            imgui.NextColumn();
            local value = ('%s%d%s'):fmt(
                bonus.value > 0 and '+' or '', bonus.value, bonus.suffix);
            local value_width = imgui.CalcTextSize(value);
            imgui.SetCursorPosX(math.max(
                imgui.GetCursorPosX(),
                imgui.GetColumnWidth() - value_width - 8));
            imgui.TextColored(
                bonus.value >= 0 and theme.colors.value or { 1.0, 0.58, 0.48, 1.0 },
                value);
            imgui.NextColumn();
            imgui.Columns(1);
        end);
    end
    return skills;
end

local function render_tracked_skills(player, width, gear_skill_values)
    section_header('Skills');
    local skills = selected_skills();
    local rendered = 0;
    skills:each(function (id)
        local cap = get_cap(id);
        if (cap ~= nil or not state.settings.hide_unavailable[1]) then
            local skill = player:GetCombatSkill(id);
            local trained = skill and skill:GetSkill() or 0;
            local gear_bonus = tonumber(gear_skill_values[id]) or 0;
            local modifier = gear_bonus ~= 0
                and (' (%s%d)'):fmt(gear_bonus > 0 and '+' or '', gear_bonus)
                or '';
            imgui.Text(skilldata.names[id]);
            imgui.SameLine();
            imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), width - 142));
            local capped = cap ~= nil and trained >= cap;
            imgui.TextColored(capped and theme.colors.good or theme.colors.muted,
                capped and ('%d%s / %d  MAX'):fmt(trained, modifier, cap)
                    or ('%d%s / %s'):fmt(trained, modifier, cap and tostring(cap) or '--'));
            if (imgui.IsItemHovered()) then
                imgui.BeginTooltip();
                imgui.Text(('Trained: %d'):fmt(trained));
                imgui.Text(('Equipment: %s%d'):fmt(gear_bonus > 0 and '+' or '', gear_bonus));
                if (cap ~= nil) then
                    imgui.Text(('Job/level cap: %d'):fmt(cap));
                    imgui.Text(('%d point%s remaining'):fmt(
                        math.max(0, cap - trained), cap - trained == 1 and '' or 's'));
                end
                imgui.EndTooltip();
            end
            local ratio = cap ~= nil and cap > 0 and math.min(1, trained / cap) or 0;
            imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 0.72, 0.54, 0.24, 1.0 });
            imgui.ProgressBar(ratio, { -1, 4 }, '');
            imgui.PopStyleColor();
            rendered = rendered + 1;
        end
    end);
    if (rendered == 0) then
        imgui.TextColored(theme.colors.muted, 'No skills selected. Use Config to add skills.');
    end
end

local function section_enabled(name)
    local sections = state.settings.sections;
    return sections ~= nil and sections[name] ~= nil and sections[name][1];
end

local function render_abilities(width)
    if (#state.settings.ability_ids == 0) then return; end
    section_header('Abilities');
    for _, id in ipairs(state.settings.ability_ids) do
        local ability = AshitaCore:GetResourceManager():GetAbilityById(tonumber(id));
        if (ability ~= nil) then
            local recast = format_recast(ability_recast(ability.RecastTimerId));
            imgui.Text(ability_name(ability));
            imgui.SameLine();
            imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), width - 70));
            imgui.TextColored(
                recast == 'Ready' and theme.colors.good or { 1.0, 0.68, 0.35, 1.0 },
                recast);
        end
    end
end

local function render_skill_bonuses(gear_skills)
    if (#gear_skills == 0) then return; end
    section_header('Skill Bonuses');
    gear_skills:each(function (bonus) imgui.BulletText(bonus); end);
end

local function apply_section_preset(name)
    local presets = {
        Full = { true, true, true, true, true, true },
        Compact = { true, false, false, true, false, false },
        Skills = { true, false, false, true, true, true },
        Gear = { true, true, true, false, false, true },
    };
    local preset = presets[name];
    if (preset == nil) then return; end
    local keys = {
        'stats', 'gear', 'equipment_bonuses', 'skills', 'abilities', 'skill_bonuses',
    };
    for index, key in ipairs(keys) do state.settings.sections[key][1] = preset[index]; end
    state.save();
end

local function save_job_profile(player)
    local key = tostring(player:GetMainJob());
    local profile = {
        sections = {},
        tracked_ids = {},
        skill_order = {},
        ability_ids = {},
    };
    for _, name in ipairs({
        'stats', 'gear', 'equipment_bonuses', 'skills', 'abilities', 'skill_bonuses',
    }) do
        profile.sections[name] = state.settings.sections[name][1];
    end
    M.groups:each(function (group)
        group.skills:each(function (entry)
            if (state.settings.tracked[entry[2]][1]) then
                profile.tracked_ids[#profile.tracked_ids + 1] = entry[1];
            end
        end);
    end);
    for _, id in ipairs(state.settings.skill_order) do
        profile.skill_order[#profile.skill_order + 1] = tonumber(id);
    end
    for _, id in ipairs(state.settings.ability_ids) do
        profile.ability_ids[#profile.ability_ids + 1] = tonumber(id);
    end
    state.settings.job_profiles[key] = profile;
    state.save();
end

local function load_job_profile(player)
    local profile = state.settings.job_profiles[tostring(player:GetMainJob())];
    if (profile == nil) then return false; end
    for name, value in pairs(profile.sections or {}) do
        if (state.settings.sections[name] ~= nil) then
            state.settings.sections[name][1] = value and true or false;
        end
    end
    local selected = {};
    for _, id in ipairs(profile.tracked_ids or {}) do selected[tonumber(id)] = true; end
    M.groups:each(function (group)
        group.skills:each(function (entry)
            state.settings.tracked[entry[2]][1] = selected[entry[1]] == true;
        end);
    end);
    state.settings.skill_order = T(profile.skill_order or {});
    state.settings.ability_ids = T(profile.ability_ids or {});
    state.save();
    return true;
end

function M.initialize(settings, save_callback, panel_width, width_callback, gearinfo_callback)
    state.settings = T(settings or {}):merge(M.default_settings);
    state.save = save_callback or function () end;
    state.panel_width[1] = math.max(420, math.min(1600, tonumber(panel_width) or 1100));
    state.set_panel_width = width_callback;
    state.toggle_gearinfo = gearinfo_callback;
    theme.configure(state.settings);
end

function M.invalidate()
    state.gear_counter = -1;
    state.ability_cache_key = '';
end

function M.open_config()
    state.config_open[1] = true;
end

function M.is_collapsed()
    return state.settings ~= nil and state.settings.collapsed[1];
end

function M.get_render_width(requested)
    local io = imgui.GetIO();
    local display = io and io.DisplaySize or nil;
    local screen_width = display and (tonumber(display.x) or tonumber(display[1])) or 1920;
    return math.max(420, math.min(tonumber(requested) or 1100, screen_width - 16));
end

function M.render_panel(x, y, width, grid_width)
    if (state.settings == nil or not state.settings.visible[1]) then return; end
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return; end
    local ui_scale = math.max(0.80, math.min(1.50, tonumber(state.settings.ui_scale[1]) or 1.0));
    local io = imgui.GetIO();
    local display = io and io.DisplaySize or nil;
    local screen_width = display and (tonumber(display.x) or tonumber(display[1])) or 1920;
    local screen_height = display and (tonumber(display.y) or tonumber(display[2])) or 1080;
    width = M.get_render_width(width);
    grid_width = math.max(64, tonumber(grid_width) or 128);
    local visible_width = state.settings.collapsed[1] and (grid_width + 28) or width;
    x = math.max(8, math.min(tonumber(x) or 8, screen_width - visible_width - 8));
    y = math.max(8, math.min(tonumber(y) or 8, screen_height - 80));

    if (state.settings.collapsed[1]) then
        imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
        imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
        local collapsed_flags = bit.bor(
            ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
            ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse,
            ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoSavedSettings);
        if (imgui.Begin('Character Sheet Toggle##charactersheet', nil, collapsed_flags)) then
            set_window_font_scale(ui_scale);
            equipment.render_grid(grid_width / 4);
            imgui.SetCursorPos({ grid_width + 2, 0 });
            if (imgui.Button('+##sheet_toggle', { 26, 26 })) then
                state.settings.collapsed[1] = false;
                state.save();
            end
            if (imgui.IsItemHovered()) then imgui.SetTooltip('Expand CharacterSheet'); end
        end
        imgui.End();
        imgui.PopStyleVar();
        return;
    end

    refresh_abilities();
    local _, _, gear_skill_values = collect_gear();
    local content_height = math.max(300, math.min(650, screen_height - y - 72));
    local compact_layout = width < 900;
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ width, 0 }, ImGuiCond_Always);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.0, 0.0, 0.0, 0.0 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.60, 0.43, 0.20, 0.90 });
    imgui.PushStyleColor(ImGuiCol_Separator, { 0.45, 0.32, 0.16, 0.85 });
    if (imgui.Begin('Character Sheet##charactersheet', nil, flags)) then
        set_window_font_scale(ui_scale);
        theme.draw_panel();
        local content_x = 8;
        local content_width = width - 16;
        imgui.SetCursorPos({ content_x, 8 });
        imgui.TextColored(theme.colors.accent, 'CHARACTER SHEET');
        imgui.SameLine();
        local button_x = math.max(imgui.GetCursorPosX(), width - 177);
        imgui.SetCursorPosX(button_x);
        if (imgui.Button('-##sheet_toggle', { 26, 24 })) then
            state.settings.collapsed[1] = true;
            state.save();
        end
        if (imgui.IsItemHovered()) then imgui.SetTooltip('Collapse CharacterSheet'); end
        imgui.SameLine();
        if (imgui.Button('GearInfo', { 72, 24 }) and state.toggle_gearinfo ~= nil) then
            state.toggle_gearinfo();
        end
        if (imgui.IsItemHovered()) then imgui.SetTooltip('Toggle the GearInfo combat-stat panel'); end
        imgui.SameLine();
        if (imgui.Button('Config', { 68, 24 })) then M.open_config(); end

        imgui.SetCursorPosX(content_x);
        local main_job = job_names[player:GetMainJob()] or ('JOB%d'):fmt(player:GetMainJob());
        local sub_job = job_names[player:GetSubJob()] or ('JOB%d'):fmt(player:GetSubJob());
        local identity = ('%s %d  /  %s %d'):fmt(
            main_job, player:GetMainJobLevel(), sub_job, player:GetSubJobLevel());
        local item_level = tonumber(player:GetItemLevel()) or 0;
        if (item_level > 0) then identity = identity .. ('    iLvl %d'):fmt(item_level); end
        local mastery = tonumber(player:GetMasteryJobLevel()) or 0;
        if (mastery > 0) then identity = identity .. ('    ML %d'):fmt(mastery); end
        imgui.TextColored(theme.colors.muted, identity);

        imgui.SetCursorPosX(content_x);
        local gear_skills = T{};
        local _, collected_skills = collect_gear();
        gear_skills = collected_skills;

        if (compact_layout) then
            imgui.BeginChild('character_compact', { 0, content_height }, ImGuiChildFlags_Borders);
            local compact_width = content_width - 20;
            if (section_enabled('stats')) then render_current_stats(player); end
            if (section_enabled('gear')) then render_equipment_list(true); end
            if (state.settings.show_gear_stats[1] and section_enabled('equipment_bonuses')) then
                render_equipment_bonuses(compact_width);
            end
            if (section_enabled('skills')) then
                render_tracked_skills(player, compact_width, gear_skill_values);
            end
            if (section_enabled('abilities')) then render_abilities(compact_width); end
            if (state.settings.show_gear_stats[1] and section_enabled('skill_bonuses')) then
                render_skill_bonuses(gear_skills);
            end
            imgui.EndChild();
        else
            local column_width = math.floor((content_width - 12) / 2);
            imgui.BeginChild('character_overview', { column_width, content_height }, ImGuiChildFlags_Borders);
            if (section_enabled('stats')) then render_current_stats(player); end
            if (section_enabled('gear')) then render_equipment_list(false); end
            if (state.settings.show_gear_stats[1] and section_enabled('equipment_bonuses')) then
                render_equipment_bonuses(column_width);
            end
            imgui.EndChild();

            imgui.SameLine();
            imgui.BeginChild('character_progression', { 0, content_height }, ImGuiChildFlags_Borders);
            if (section_enabled('skills')) then
                render_tracked_skills(player, column_width, gear_skill_values);
            end
            if (section_enabled('abilities')) then render_abilities(column_width); end
            if (state.settings.show_gear_stats[1] and section_enabled('skill_bonuses')) then
                render_skill_bonuses(gear_skills);
            end
            imgui.EndChild();
        end
    end
    imgui.End();
    imgui.PopStyleColor(3);
end

function M.render_config()
    if (state.settings == nil or not state.config_open[1]) then return; end
    refresh_abilities();
    imgui.SetNextWindowSize({ 620, 650 }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Character Sheet Configuration', state.config_open)) then
        if (imgui.BeginTabBar('##charactersheet_config_tabs')) then
            if (imgui.BeginTabItem('Display')) then
                local player = AshitaCore:GetMemoryManager():GetPlayer();
                if (imgui.Checkbox('Show character sheet', state.settings.visible)) then state.save(); end
                if (imgui.Checkbox('Follow equipped main weapon', state.settings.equipped_weapon)) then state.save(); end
                if (imgui.Checkbox('Hide unavailable skills', state.settings.hide_unavailable)) then state.save(); end
                if (imgui.Checkbox('Show gear stats and skill bonuses', state.settings.show_gear_stats)) then state.save(); end
                if (imgui.Checkbox('Lock panel position', state.settings.lock_position)) then state.save(); end
                imgui.Separator();
                imgui.TextColored(theme.colors.accent, 'ACCESSIBILITY');
                if (imgui.SliderFloat('UI scale', state.settings.ui_scale, 0.80, 1.50, '%.2f')) then
                    state.save();
                end
                if (imgui.SliderInt('Panel width', state.panel_width, 420, 1600, '%d px')) then
                    if (state.set_panel_width ~= nil) then
                        state.set_panel_width(state.panel_width[1]);
                    end
                    state.save();
                end
                if (imgui.Checkbox('High-contrast colors', state.settings.high_contrast)) then
                    theme.configure(state.settings);
                    state.save();
                end
                if (imgui.Checkbox('Reduce textured backgrounds', state.settings.reduce_texture)) then
                    theme.configure(state.settings);
                    state.save();
                end
                imgui.Separator();
                imgui.TextColored(theme.colors.accent, 'SECTION PRESETS');
                for _, preset in ipairs({ 'Full', 'Compact', 'Skills', 'Gear' }) do
                    if (imgui.SmallButton(preset .. '##section_preset')) then
                        apply_section_preset(preset);
                    end
                    if (preset ~= 'Gear') then imgui.SameLine(); end
                end
                if (player ~= nil) then
                    local job = job_names[player:GetMainJob()] or 'JOB';
                    imgui.Spacing();
                    if (imgui.Button('Save for ' .. job, { 120, 24 })) then
                        save_job_profile(player);
                    end
                    imgui.SameLine();
                    if (imgui.Button('Load for ' .. job, { 120, 24 })) then
                        load_job_profile(player);
                    end
                    if (imgui.IsItemHovered()) then
                        imgui.SetTooltip('Restore this job profile if one has been saved.');
                    end
                end
                imgui.Spacing();
                imgui.Columns(2, '##section_visibility', false);
                local section_options = {
                    { 'Current stats', 'stats' },
                    { 'Gear', 'gear' },
                    { 'Equipment bonuses', 'equipment_bonuses' },
                    { 'Skills', 'skills' },
                    { 'Abilities', 'abilities' },
                    { 'Skill bonuses', 'skill_bonuses' },
                };
                for _, entry in ipairs(section_options) do
                    if (imgui.Checkbox(entry[1], state.settings.sections[entry[2]])) then state.save(); end
                    imgui.NextColumn();
                end
                imgui.Columns(1);
                imgui.Spacing();
                imgui.TextWrapped('Equipment icon size can be changed with /charactersheet size 16|32|48|64.');
                imgui.EndTabItem();
            end

            if (imgui.BeginTabItem('Skills')) then
                imgui.InputText('Search##skill_search', state.skill_search, 64);
                local skill_filter = (state.skill_search[1] or ''):lower();
                M.groups:each(function (group)
                    imgui.TextColored(theme.colors.accent, group.name);
                    imgui.SameLine();
                    if (imgui.SmallButton(('All##%s'):fmt(group.name))) then
                        group.skills:each(function (entry) state.settings.tracked[entry[2]][1] = true; end);
                        state.save();
                    end
                    imgui.SameLine();
                    if (imgui.SmallButton(('None##%s'):fmt(group.name))) then
                        group.skills:each(function (entry) state.settings.tracked[entry[2]][1] = false; end);
                        state.save();
                    end
                    imgui.Columns(group.name == 'Magic Skills' and 2 or 3, '##' .. group.name, false);
                    group.skills:each(function (entry)
                        local name = skilldata.names[entry[1]];
                        if (skill_filter == '' or name:lower():find(skill_filter, 1, true)) then
                            if (imgui.Checkbox(name, state.settings.tracked[entry[2]])) then
                                if (state.settings.tracked[entry[2]][1]) then ensure_skill_order(entry[1]); end
                                state.save();
                            end
                            imgui.NextColumn();
                        end
                    end);
                    imgui.Columns(1);
                    imgui.Separator();
                end);
                imgui.TextColored(theme.colors.accent, 'DISPLAY ORDER');
                local ordered = selected_skills();
                for _, id in ipairs(ordered) do
                    imgui.Text(skilldata.names[id]);
                    imgui.SameLine();
                    imgui.SetCursorPosX(430);
                    local order_index = array_index(state.settings.skill_order, id);
                    if (order_index == nil) then
                        imgui.TextColored(theme.colors.muted, 'Auto');
                    else
                        if (imgui.SmallButton(('Up##skill_order_%d'):fmt(id))) then
                            move_array_value(state.settings.skill_order, order_index, -1);
                        end
                        imgui.SameLine();
                        if (imgui.SmallButton(('Down##skill_order_%d'):fmt(id))) then
                            move_array_value(state.settings.skill_order, order_index, 1);
                        end
                    end
                end
                imgui.EndTabItem();
            end

            if (imgui.BeginTabItem('Abilities')) then
                imgui.TextColored(theme.colors.accent, 'AVAILABLE ABILITIES');
                imgui.TextWrapped('Choose abilities to show with their live Ready/recast status.');
                imgui.InputText('Search##ability_search', state.ability_search, 64);
                local ability_filter = (state.ability_search[1] or ''):lower();
                imgui.BeginChild('ability_list', { 0, 360 }, ImGuiChildFlags_Borders);
                state.abilities:each(function (entry)
                    local name = ability_name(entry.resource);
                    if (ability_filter == '' or name:lower():find(ability_filter, 1, true)) then
                        local checked = T{ ability_selected(entry.id) };
                        if (imgui.Checkbox(name .. '##ability_' .. entry.id, checked)) then
                            set_ability(entry.id, checked[1]);
                        end
                    end
                end);
                imgui.EndChild();
                imgui.TextColored(theme.colors.accent, 'DISPLAY ORDER');
                for index, id in ipairs(state.settings.ability_ids) do
                    local ability = AshitaCore:GetResourceManager():GetAbilityById(tonumber(id));
                    if (ability ~= nil) then
                        imgui.Text(ability_name(ability));
                        imgui.SameLine();
                        imgui.SetCursorPosX(430);
                        if (imgui.SmallButton(('Up##ability_order_%d'):fmt(id))) then
                            move_array_value(state.settings.ability_ids, index, -1);
                        end
                        imgui.SameLine();
                        if (imgui.SmallButton(('Down##ability_order_%d'):fmt(id))) then
                            move_array_value(state.settings.ability_ids, index, 1);
                        end
                    end
                end
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
    end
    imgui.End();
end

return M;
