local export = {};

local json = require('json');

local container_names = {
    [0] = 'Inventory', [1] = 'Mog Safe', [2] = 'Storage', [3] = 'Temporary',
    [4] = 'Mog Locker', [5] = 'Mog Satchel', [6] = 'Mog Sack', [7] = 'Mog Case',
    [8] = 'Mog Wardrobe', [9] = 'Mog Safe 2', [10] = 'Mog Wardrobe 2',
    [11] = 'Mog Wardrobe 3', [12] = 'Mog Wardrobe 4', [13] = 'Mog Wardrobe 5',
    [14] = 'Mog Wardrobe 6', [15] = 'Mog Wardrobe 7', [16] = 'Mog Wardrobe 8',
};

local job_names = {
    'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
    'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN',
};

local stat_names = { 'STR', 'DEX', 'VIT', 'AGI', 'INT', 'MND', 'CHR' };
local resist_names = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' };
local combat_skill_names = {
    [1] = 'Hand-to-Hand', [2] = 'Dagger', [3] = 'Sword', [4] = 'Great Sword',
    [5] = 'Axe', [6] = 'Great Axe', [7] = 'Scythe', [8] = 'Polearm', [9] = 'Katana',
    [10] = 'Great Katana', [11] = 'Club', [12] = 'Staff', [22] = 'Automaton Melee',
    [23] = 'Automaton Ranged', [24] = 'Automaton Magic', [25] = 'Archery',
    [26] = 'Marksmanship', [27] = 'Throwing', [28] = 'Guarding', [29] = 'Evasion',
    [30] = 'Shield', [31] = 'Parrying', [32] = 'Divine Magic', [33] = 'Healing Magic',
    [34] = 'Enhancing Magic', [35] = 'Enfeebling Magic', [36] = 'Elemental Magic',
    [37] = 'Dark Magic', [38] = 'Summoning Magic', [39] = 'Ninjutsu',
    [40] = 'Singing', [41] = 'String Instrument', [42] = 'Wind Instrument',
    [43] = 'Blue Magic', [44] = 'Geomancy', [45] = 'Handbell',
};
local craft_names = {
    [0] = 'Fishing', [1] = 'Woodworking', [2] = 'Smithing', [3] = 'Goldsmithing',
    [4] = 'Clothcraft', [5] = 'Leathercraft', [6] = 'Bonecraft', [7] = 'Alchemy',
    [8] = 'Cooking', [9] = 'Synergy',
};

local function clean(value)
    if (type(value) ~= 'string') then return ''; end
    return value:trimend('\0'):gsub('[\r\n]+', ' ');
end

local function resource_text(value)
    if (value == nil) then return ''; end
    local ok, text = pcall(function () return value[1]; end);
    return ok and clean(text) or '';
end

local function bytes_to_hex(value)
    if (type(value) ~= 'string') then return ''; end
    return (value:gsub('.', function (character)
        return ('%02X'):format(character:byte());
    end));
end

local function call(object, method, ...)
    if (object == nil) then return nil; end
    local found, fn = pcall(function () return object[method]; end);
    if (not found) then return nil; end
    if (type(fn) ~= 'function') then return nil; end
    local ok, value = pcall(fn, object, ...);
    return ok and value or nil;
end

local function item_record(resources, instance, container, slot, equipped)
    local item = resources:GetItemById(instance.Id);
    return {
        id = tonumber(instance.Id) or 0,
        name = item and resource_text(item.Name) or '',
        description = item and resource_text(item.Description) or '',
        count = tonumber(instance.Count) or 0,
        flags = tonumber(instance.Flags) or 0,
        price = tonumber(instance.Price) or 0,
        container_id = container,
        container = container_names[container] or ('Container ' .. container),
        slot = slot,
        equipped = equipped[container .. ':' .. slot] == true,
        extra_hex = bytes_to_hex(instance.Extra),
    };
end

function export.run()
    local memory = AshitaCore:GetMemoryManager();
    local player = memory and memory:GetPlayer() or nil;
    local inventory = memory and memory:GetInventory() or nil;
    local party = memory and memory:GetParty() or nil;
    if (player == nil or inventory == nil or party == nil or player:GetLoginStatus() ~= 2) then
        return false, 'A character must be fully logged in before exporting.';
    end

    local resources = AshitaCore:GetResourceManager();
    local name = clean(party:GetMemberName(0) or 'Character');
    local equipped = {};
    for slot = 0, 15 do
        local entry = inventory:GetEquippedItem(slot);
        if (entry ~= nil and entry.Index ~= 0) then
            local container = bit.band(entry.Index, 0xFF00) / 0x100;
            equipped[container .. ':' .. (entry.Index % 0x100)] = true;
        end
    end

    local containers = {};
    local items = {};
    for container = 0, 16 do
        local maximum = tonumber(call(inventory, 'GetContainerCountMax', container)) or 0;
        local used = tonumber(call(inventory, 'GetContainerCount', container)) or 0;
        containers[#containers + 1] = {
            id = container, name = container_names[container], used = used, capacity = maximum,
            available_in_memory = maximum > 0,
        };
        for slot = 0, maximum do
            local instance = call(inventory, 'GetContainerItem', container, slot);
            if (instance ~= nil and (tonumber(instance.Id) or 0) > 0
                    and (tonumber(instance.Count) or 0) > 0) then
                items[#items + 1] = item_record(resources, instance, container, slot, equipped);
            end
        end
    end

    local jobs = {};
    for id, abbreviation in ipairs(job_names) do
        jobs[#jobs + 1] = {
            id = id, abbreviation = abbreviation,
            level = tonumber(call(player, 'GetJobLevel', id)) or 0,
            master_level = tonumber(call(player, 'GetJobMasterLevel', id)) or 0,
            capacity_points = tonumber(call(player, 'GetCapacityPoints', id)) or 0,
            job_points = tonumber(call(player, 'GetJobPoints', id)) or 0,
            job_points_spent = tonumber(call(player, 'GetJobPointsSpent', id)) or 0,
        };
    end

    local stats = {};
    for index, stat_name in ipairs(stat_names) do
        local base = tonumber(call(player, 'GetStat', index - 1)) or 0;
        local modifier = tonumber(call(player, 'GetStatModifier', index - 1)) or 0;
        stats[stat_name] = { base = base, modifier = modifier, total = base + modifier };
    end
    local resists = {};
    for index, resist_name in ipairs(resist_names) do
        resists[resist_name] = tonumber(call(player, 'GetResist', index - 1)) or 0;
    end

    local combat_skills = {};
    for id, skill_name in pairs(combat_skill_names) do
        local skill = call(player, 'GetCombatSkill', id);
        combat_skills[#combat_skills + 1] = {
            id = id, name = skill_name,
            value = tonumber(call(skill, 'GetSkill')) or 0,
            capped = call(skill, 'IsCapped') == true,
        };
    end
    table.sort(combat_skills, function (a, b) return a.id < b.id; end);

    local craft_skills = {};
    for id = 0, 9 do
        local skill = call(player, 'GetCraftSkill', id);
        craft_skills[#craft_skills + 1] = {
            id = id, name = craft_names[id], value = tonumber(call(skill, 'GetSkill')) or 0,
            rank = tonumber(call(skill, 'GetRank')) or 0, capped = call(skill, 'IsCapped') == true,
        };
    end

    local gil = call(inventory, 'GetContainerItem', 0, 0);
    local data = {
        schema_version = 1,
        exported_at = os.date('%Y-%m-%dT%H:%M:%S%z'),
        character = {
            name = name,
            server_id = tonumber(party:GetMemberServerId(0)) or 0,
            nation = tonumber(call(player, 'GetNation')) or 0,
            rank = tonumber(call(player, 'GetRank')) or 0,
            rank_points = tonumber(call(player, 'GetRankPoints')) or 0,
            title_id = tonumber(call(player, 'GetTitle')) or 0,
            homepoint_id = tonumber(call(player, 'GetHomepoint')) or 0,
            residence_id = tonumber(call(player, 'GetResidence')) or 0,
        },
        current = {
            main_job_id = tonumber(call(player, 'GetMainJob')) or 0,
            main_job_level = tonumber(call(player, 'GetMainJobLevel')) or 0,
            sub_job_id = tonumber(call(player, 'GetSubJob')) or 0,
            sub_job_level = tonumber(call(player, 'GetSubJobLevel')) or 0,
            hp = tonumber(call(party, 'GetMemberHP', 0)) or 0,
            hp_max = tonumber(call(player, 'GetHPMax')) or 0,
            mp = tonumber(call(party, 'GetMemberMP', 0)) or 0,
            mp_max = tonumber(call(player, 'GetMPMax')) or 0,
            tp = tonumber(call(party, 'GetMemberTP', 0)) or 0,
            exp = tonumber(call(player, 'GetExpCurrent')) or 0,
            exp_needed = tonumber(call(player, 'GetExpNeeded')) or 0,
            attack = tonumber(call(player, 'GetAttack')) or 0,
            defense = tonumber(call(player, 'GetDefense')) or 0,
            item_level = tonumber(call(player, 'GetItemLevel')) or 0,
            highest_item_level = tonumber(call(player, 'GetHighestItemLevel')) or 0,
            su_level = tonumber(call(player, 'GetSuLevel')) or 0,
        },
        progression = {
            limit_points = tonumber(call(player, 'GetLimitPoints')) or 0,
            merit_points = tonumber(call(player, 'GetMeritPoints')) or 0,
            merit_points_max = tonumber(call(player, 'GetMeritPointsMax')) or 0,
            mastery_job = tonumber(call(player, 'GetMasteryJob')) or 0,
            mastery_level = tonumber(call(player, 'GetMasteryJobLevel')) or 0,
            mastery_exp = tonumber(call(player, 'GetMasteryExp')) or 0,
            mastery_exp_needed = tonumber(call(player, 'GetMasteryExpNeeded')) or 0,
        },
        currencies = {
            gil = gil and (tonumber(gil.Count) or 0) or 0,
            unity_faction = tonumber(call(player, 'GetUnityFaction')) or 0,
            unity_accolades = tonumber(call(player, 'GetUnityPoints')) or 0,
            note = 'Item-based currencies are included in items and can be summed by item id.',
        },
        stats = stats, resists = resists, jobs = jobs,
        combat_skills = combat_skills, craft_skills = craft_skills,
        containers = containers, items = items,
        unavailable = {
            'Completed missions and quests: Ashita v4 does not expose these completion bitfields through its public Lua memory interfaces.',
            'Key items and most non-item currencies: not exposed through the public Lua memory interfaces.',
            'Items in containers that have not been loaded by the game client are marked available_in_memory=false and cannot be read safely.',
        },
    };

    local safe_name = name:gsub('[^%w_%-]', '_');
    local path = AshitaCore:GetInstallPath() .. 'config\\addons\\charactersheet\\'
        .. safe_name .. '_character_export.json';
    local file = io.open(path, 'wb');
    if (file == nil) then return false, ('Could not create character export: %s'):format(path); end
    local ok, encoded = pcall(json.encode, data);
    if (not ok) then file:close(); return false, 'Could not encode character data: ' .. tostring(encoded); end
    file:write(encoded);
    file:close();
    return true, ('Exported %d items and full available character data to: %s'):format(#items, path);
end

return export;
