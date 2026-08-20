local actionpacket = require('gearinfo_actionpacket');
local encoding = require('gearinfo_encoding');
local dw_gear = require('gearinfo_res/DW_Gear');
local martial_arts_gear = require('gearinfo_res/Martial_Arts_Gear');
local set_bonus_items = require('gearinfo_res/Set_bonus_by_item_id');

local M = {};

local state = {
    sources = {},
    gear_counter = -1,
    gear = {},
};

local job_names = T{
    [0] = 'NON', 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK',
    'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP',
    'DNC', 'SCH', 'GEO', 'RUN',
};

local gear_defs = T{
    { key = 'haste', patterns = T{ 'haste%s*([%+%-]%d+%.?%d*)%%' } },
    { key = 'pdt', patterns = T{ 'physical%s+damage%s+taken%s*([%+%-]%d+%.?%d*)%%', 'phys%.?%s+dmg%.?%s+taken%s*([%+%-]%d+%.?%d*)%%' } },
    { key = 'mdt', patterns = T{ 'magic%s+damage%s+taken%s*([%+%-]%d+%.?%d*)%%', 'magic%s+dmg%.?%s+taken%s*([%+%-]%d+%.?%d*)%%' } },
    { key = 'bdt', patterns = T{ 'breath%s+damage%s+taken%s*([%+%-]%d+%.?%d*)%%', 'breath%s+dmg%.?%s+taken%s*([%+%-]%d+%.?%d*)%%' } },
    { key = 'dt', patterns = T{ 'damage%s+taken%s*([%+%-]%d+%.?%d*)%%', 'dmg%.?%s+taken%s*([%+%-]%d+%.?%d*)%%' } },
    { key = 'stp', patterns = T{ 'store%s+tp%s*([%+%-]%d+%.?%d*)' } },
    { key = 'dw', patterns = T{ 'dual%s+wield%s*([%+%-]%d+%.?%d*)' } },
    { key = 'ma', patterns = T{ 'martial%s+arts%s*([%+%-]%d+%.?%d*)' } },
    { key = 'accuracy', patterns = T{ 'accuracy%s*([%+%-]%d+%.?%d*)' }, reject = T{ 'magic accuracy', 'ranged accuracy' } },
    { key = 'evasion', patterns = T{ 'evasion%s*([%+%-]%d+%.?%d*)' }, reject = T{ 'magic evasion' } },
};

local function resource_text(field)
    if (field == nil) then return ''; end
    local ok, value = pcall(function() return field[1]; end);
    if (not ok or type(value) ~= 'string') then return ''; end
    return encoding.shiftjis_to_utf8(value);
end

local augment_logic = nil;
local function load_augment_logic()
    if (augment_logic ~= nil) then return; end
    augment_logic = false;
    local path = ('%s\\..\\XIUI\\modules\\satchel\\augmentlogic.lua'):format(addon.path);
    if (not ashita.fs.exists(path)) then return; end
    local ok, chunk = pcall(loadfile, path);
    if (ok and chunk ~= nil) then
        local loaded, result = pcall(chunk);
        if (loaded and type(result) == 'table') then augment_logic = result; end
    end
end

local function equipped(slot)
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    if (inventory == nil) then return nil, nil; end
    local entry = inventory:GetEquippedItem(slot);
    if (entry == nil or entry.Index == 0) then return nil, nil; end
    local container = bit.band(entry.Index, 0xFF00) / 0x100;
    local instance = inventory:GetContainerItem(container, entry.Index % 0x100);
    if (instance == nil or instance.Id == 0 or instance.Id == 65535) then return nil, nil; end
    return instance, AshitaCore:GetResourceManager():GetItemById(instance.Id);
end

local function normalized_item_text(instance, item)
    local text = resource_text(item and item.Description):lower():gsub('[\r\n]', ' ');
    load_augment_logic();
    if (augment_logic and type(instance.Extra) == 'string') then
        local ok, lines = pcall(augment_logic.get_augment_lines, instance.Id, instance.Extra);
        if (ok and type(lines) == 'table') then
            for _, line in ipairs(lines) do text = text .. ' ' .. tostring(line):lower(); end
        end
    end
    return text:gsub('phys%.?', 'physical'):gsub('mag%.?', 'magic'):gsub('%s+', ' ');
end

local function add_matches(totals, text)
    for _, definition in ipairs(gear_defs) do
        local rejected = false;
        for _, phrase in ipairs(definition.reject or {}) do
            if (text:find(phrase, 1, true)) then
                rejected = true;
                break
            end
        end
        if (not rejected) then
            for _, pattern in ipairs(definition.patterns) do
                local matched = false;
                text = text:gsub(pattern, function(value)
                    totals[definition.key] = (totals[definition.key] or 0) + (tonumber(value) or 0);
                    matched = true;
                    return ' ';
                end);
                if (matched) then
                    break
                end
            end
        end
    end
end

local function collect_gear()
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    if (inventory == nil) then return {}; end
    local counter = inventory:GetContainerUpdateCounter();
    if (counter == state.gear_counter) then return state.gear; end

    local totals = { haste = 0, dt = 0, pdt = 0, mdt = 0, bdt = 0, stp = 0, dw = 0, ma = 0, accuracy = 0, evasion = 0 };
    totals.items = {};
    local equipped_sets = {};
    for slot = 0, 15 do
        local instance, item = equipped(slot);
        if (item ~= nil) then
            totals.items[slot] = item;
            add_matches(totals, normalized_item_text(instance, item));
            local dw_entry = dw_gear[instance.Id];
            if (dw_entry ~= nil) then totals.dw = totals.dw + (tonumber(dw_entry['Dual Wield']) or 0); end
            local ma_entry = martial_arts_gear[instance.Id];
            if (ma_entry ~= nil) then totals.ma = totals.ma + (tonumber(ma_entry.delay) or 0); end
            local set_entry = set_bonus_items[instance.Id];
            if (set_entry ~= nil and set_entry['set id'] ~= nil) then
                local set_id = set_entry['set id'];
                equipped_sets[set_id] = equipped_sets[set_id] or { count = 0, entry = set_entry };
                equipped_sets[set_id].count = equipped_sets[set_id].count + 1;
            end
        end
    end
    local set_keys = { Haste = 'haste', ['Store TP'] = 'stp', ['Dual Wield'] = 'dw', Accuracy = 'accuracy', Evasion = 'evasion' };
    local reduction_keys = { DT = 'dt', PDT = 'pdt', MDT = 'mdt', BDT = 'bdt' };
    for _, equipped_set in pairs(equipped_sets) do
        local minimum = tonumber(equipped_set.entry['minimum peices']) or 2;
        local bonus_table = equipped_set.entry.bonus;
        local bonus = equipped_set.count >= minimum and bonus_table and bonus_table[equipped_set.count] or nil;
        if (bonus ~= nil) then
            for key, value in pairs(bonus) do
                local destination = set_keys[key];
                if (destination ~= nil) then totals[destination] = totals[destination] + (tonumber(value) or 0); end
                destination = reduction_keys[key];
                if (destination ~= nil) then totals[destination] = totals[destination] - math.abs(tonumber(value) or 0); end
            end
        end
    end
    state.gear_counter, state.gear = counter, totals;
    return totals;
end

local spell_haste = {
    [57] = 14.65,  -- Haste
    [511] = 30.00, -- Haste II
    [358] = 14.65, -- Hastega
    [893] = 30.00, -- Hastega II
    [530] = 10.00, -- Refueling
    [710] = 30.00, -- Erratic Flutter
    [417] = 12.30, -- Honor March, base potency
    [419] = 10.55, -- Advancing March, base potency
    [420] = 15.92, -- Victory March, base potency
};

local status_magic_haste = {
    [33] = 14.65, [228] = 25.40, [580] = 29.90, [604] = 14.65,
};

local function player_server_id()
    local party = AshitaCore:GetMemoryManager():GetParty();
    return party ~= nil and party:GetMemberServerId(0) or 0;
end

function M.handle_packet(e)
    if (e.id == 0x028) then
        local ok, packet = pcall(actionpacket.parse, e);
        if (not ok or packet == nil or packet.category ~= 4) then return; end
        local spell = AshitaCore:GetResourceManager():GetSpellById(packet.param);
        local resource_status = spell and tonumber(spell.Status or spell.status) or nil;
        if (spell_haste[packet.param] == nil) then return; end
        local my_id = player_server_id();
        for _, target in ipairs(packet.targets or {}) do
            if (target.id == my_id) then
                local status = resource_status;
                for _, action in ipairs(target.actions or {}) do
                    local reported = tonumber(action.param);
                    if (reported ~= nil and reported > 0 and reported <= 0x3FF) then
                        status = reported;
                        break
                    end
                end
                if (status ~= nil) then state.sources[status] = packet.param; end
                break
            end
        end
    elseif (e.id == 0x00A or e.id == 0x00B) then
        state.sources = {};
    end
end

local function trait_dual_wield(player)
    local main, main_level = job_names[player:GetMainJob()] or '', player:GetMainJobLevel();
    local sub, sub_level = job_names[player:GetSubJob()] or '', player:GetSubJobLevel();
    local value = 0;
    if (main == 'NIN') then value = main_level >= 85 and 35 or main_level >= 65 and 30 or main_level >= 45 and 25 or main_level >= 25 and 15 or main_level >= 10 and 10 or 0;
    elseif (main == 'DNC') then value = main_level >= 80 and 30 or main_level >= 60 and 25 or main_level >= 40 and 15 or main_level >= 20 and 10 or 0;
    elseif (main == 'THF') then value = main_level >= 98 and 25 or main_level >= 90 and 15 or main_level >= 83 and 10 or 0; end
    local sub_value = sub == 'NIN' and (sub_level >= 25 and 25 or sub_level >= 10 and 10 or 0)
        or sub == 'DNC' and (sub_level >= 40 and 15 or sub_level >= 20 and 10 or 0) or 0;
    return math.max(value, sub_value);
end

local function trait_store_tp(player)
    local main, main_level = job_names[player:GetMainJob()] or '', player:GetMainJobLevel();
    local sub, sub_level = job_names[player:GetSubJob()] or '', player:GetSubJobLevel();
    local function sam(level)
        return level >= 90 and 30 or level >= 70 and 25 or level >= 50 and 20 or level >= 30 and 15 or level >= 10 and 10 or 0;
    end
    return math.max(main == 'SAM' and sam(main_level) or 0, sub == 'SAM' and sam(sub_level) or 0);
end

local function base_tp(delay)
    if (delay <= 0) then return 0; end
    if (delay <= 180) then return math.floor(61 + ((delay - 180) * 63 / 360)); end
    if (delay <= 540) then return math.floor(61 + ((delay - 180) * 88 / 360)); end
    if (delay <= 630) then return math.floor(149 + ((delay - 540) * 20 / 360)); end
    if (delay <= 720) then return math.floor(154 + ((delay - 630) * 28 / 360)); end
    if (delay <= 900) then return math.floor(161 + ((delay - 720) * 24 / 360)); end
    return math.floor(173 + ((delay - 900) * 28 / 360));
end

local function active_haste(player)
    local magic, ja = 0, 0;
    local seen = {};
    for _, id in ipairs(player:GetBuffs() or {}) do
        id = tonumber(id);
        if (id and id ~= 255 and not seen[id]) then
            seen[id] = true;
            local source = state.sources[id];
            if (source ~= nil and spell_haste[source] ~= nil) then
                magic = magic + spell_haste[source];
            elseif (status_magic_haste[id]) then
                magic = magic + status_magic_haste[id];
            elseif (id == 64) then
                ja = ja + ((job_names[player:GetMainJob()] == 'DRK' and player:GetMainJobLevel() >= 99) and 15 or 5);
            elseif (id == 353) then ja = ja + 10;
            elseif (id == 370) then ja = ja + 5; end
        end
    end
    return math.min(43.75, magic), math.min(25, ja);
end

local function weapon_delay(gear, dw)
    local main, sub = gear.items[0], gear.items[1];
    local main_delay = main and tonumber(main.Delay) or 0;
    local sub_delay = sub and tonumber(sub.Delay) or 0;
    local dual = sub and (tonumber(sub.Damage) or 0) > 0 and sub_delay > 0;
    if (dual) then return math.floor(((main_delay + sub_delay) * (1 - dw / 100)) / 2), true; end
    return main_delay, false;
end

function M.snapshot()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil or player:GetLoginStatus() ~= 2) then return nil; end
    local gear = collect_gear();
    local magic_haste, ja_haste = active_haste(player);
    local gear_haste = math.min(25, gear.haste or 0);
    local total_haste = math.min(80, gear_haste + magic_haste + ja_haste);
    local dw = (gear.dw or 0) + trait_dual_wield(player);
    local delay, dual = weapon_delay(gear, dw);
    local stp = (gear.stp or 0) + trait_store_tp(player);
    local tp = math.floor(base_tp(delay) * (100 + stp) / 100);
    local dex = (tonumber(player:GetStat(1)) or 0) + (tonumber(player:GetStatModifier(1)) or 0);
    local agi = (tonumber(player:GetStat(3)) or 0) + (tonumber(player:GetStatModifier(3)) or 0);
    local main = gear.items[0];
    local skill_id = main and tonumber(main.Skill) or 0;
    local skill_entry = skill_id > 0 and player:GetCombatSkill(skill_id) or nil;
    local skill = skill_entry and tonumber(skill_entry:GetSkill()) or 0;
    local evasion_entry = player:GetCombatSkill(29);
    local evasion_skill = evasion_entry and tonumber(evasion_entry:GetSkill()) or 0;
    local accuracy = skill + math.floor(dex * 0.75) + (gear.accuracy or 0);
    local evasion = evasion_skill + math.floor(agi * 0.5) + (gear.evasion or 0);
    local dw_needed = 0;
    if (dual and total_haste < 80) then
        dw_needed = math.max(0, math.ceil((1 - (0.2 / ((100 - total_haste) / 100))) * 100 - trait_dual_wield(player)));
    end
    return {
        gear_haste = gear_haste, magic_haste = magic_haste, ja_haste = ja_haste, total_haste = total_haste,
        dt = gear.dt or 0, pdt = gear.pdt or 0, mdt = gear.mdt or 0, bdt = gear.bdt or 0,
        tp = tp, xhit = tp > 0 and math.ceil(1000 / tp) or 0,
        accuracy = accuracy, attack = tonumber(player:GetAttack()) or 0,
        evasion = evasion, defense = tonumber(player:GetDefense()) or 0,
        stp = stp, dw = dw, dw_needed = dw_needed, ma = gear.ma or 0,
    };
end

function M.invalidate()
    state.gear_counter = -1;
end

return M;
