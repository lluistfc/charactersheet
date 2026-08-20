local sync = {};

local slot_names = {
    [0] = 'Main', 'Sub', 'Range', 'Ammo', 'Head', 'Body', 'Hands',
    'Legs', 'Feet', 'Neck', 'Waist', 'Ear1', 'Ear2', 'Ring1', 'Ring2', 'Back',
};

local containers = { 0, 8, 10, 11, 12, 13, 14, 15, 16 };

local function resource_text(field)
    if (field == nil) then return ''; end
    local ok, value = pcall(function () return field[1]; end);
    if (ok and type(value) == 'string') then return value:gsub('[\r\n]+', ' '); end
    return '';
end

local function value(text, pattern)
    local result = text:lower():match(pattern);
    return tonumber(result) or 0;
end

local function score(item, purpose)
    local text = item.text;
    local defense = tonumber(item.defense) or 0;
    local hp = value(text, 'hp%+([%d]+)');
    local mp = value(text, 'mp%+([%d]+)');
    local chr = value(text, 'chr%+([%d]+)');
    local dex = value(text, 'dex%+([%d]+)');
    local str = value(text, 'str%+([%d]+)');
    local accuracy = value(text, 'accuracy%+([%d]+)');
    local attack = value(text, 'attack%+([%d]+)');
    local haste = value(text, 'haste%+([%d]+)%%');
    local magic_accuracy = value(text, 'magic accuracy%+([%d]+)');
    local magic_evasion = value(text, 'magic evasion%+([%d]+)');
    local magic_defense = value(text, 'magic def%. bonus"?%+([%d]+)');
    local singing = value(text, 'singing skill %+(%d+)');
    local wind = value(text, 'wind instrument skill %+(%d+)');
    local string_skill = value(text, 'string instrument skill %+(%d+)');
    local duration = value(text, 'song effect duration %+(%d+)%%');
    local fast_cast = value(text, 'fast cast"?%+(%d+)%%');
    local damage_taken = value(text, 'damage taken%-([%d]+)%%');

    if (purpose == 'engaged') then
        return (tonumber(item.damage) or 0) * 8 + accuracy * 5 + attack * 3
            + haste * 12 + str * 2 + dex * 2 + defense * 0.15;
    elseif (purpose == 'song') then
        return magic_accuracy * 7 + chr * 4 + singing * 8 + wind * 8
            + string_skill * 8 + duration * 12 + fast_cast * 2 + defense * 0.05;
    end
    return defense * 0.5 + hp * 0.12 + mp * 0.08 + magic_evasion * 0.8
        + magic_defense * 5 + damage_taken * 18 + haste * 2 + chr * 0.25;
end

local function inventory_items()
    local memory = AshitaCore:GetMemoryManager();
    local inventory = memory:GetInventory();
    local player = memory:GetPlayer();
    local resources = AshitaCore:GetResourceManager();
    local job = player:GetMainJob();
    local level = player:GetMainJobLevel();
    local result = {};

    for _, container in ipairs(containers) do
        local maximum = inventory:GetContainerCountMax(container);
        for index = 1, maximum do
            local instance = inventory:GetContainerItem(container, index);
            if (instance ~= nil and instance.Id > 0 and instance.Count > 0) then
                local resource = resources:GetItemById(instance.Id);
                if (resource ~= nil) then
                    local jobs = tonumber(resource.Jobs) or 0;
                    local slots = tonumber(resource.Slots) or 0;
                    if (slots > 0 and (tonumber(resource.Level) or 0) <= level
                        and bit.band(jobs, math.pow(2, job)) ~= 0) then
                        result[#result + 1] = {
                            key = container .. ':' .. index,
                            name = resource_text(resource.Name),
                            text = resource_text(resource.Description):lower(),
                            slots = slots,
                            damage = tonumber(resource.Damage) or 0,
                            defense = tonumber(resource.Defense) or 0,
                        };
                    end
                end
            end
        end
    end
    return result;
end

local function best_set(items, purpose, first_slot)
    local result = {};
    local used = {};
    for slot = first_slot or 0, 15 do
        local candidates = {};
        for _, item in ipairs(items) do
            if (not used[item.key] and bit.band(item.slots, math.pow(2, slot)) ~= 0) then
                candidates[#candidates + 1] = item;
            end
        end
        table.sort(candidates, function (a, b)
            local a_score, b_score = score(a, purpose), score(b, purpose);
            if (a_score == b_score) then return a.name:lower() < b.name:lower(); end
            return a_score > b_score;
        end);
        if (#candidates > 0) then
            result[slot_names[slot]] = candidates[1].name;
            used[candidates[1].key] = true;
        end
    end
    return result;
end

local function named_item(items, pattern, slot)
    local matches = {};
    for _, item in ipairs(items) do
        if (bit.band(item.slots, math.pow(2, slot)) ~= 0 and item.text:find(pattern)) then
            matches[#matches + 1] = item;
        end
    end
    table.sort(matches, function (a, b)
        local av = value(a.text, pattern .. '"?%+(%d+)');
        local bv = value(b.text, pattern .. '"?%+(%d+)');
        if (av == bv) then return score(a, 'song') > score(b, 'song'); end
        return av > bv;
    end);
    return matches[1] and matches[1].name or nil;
end

local function lua_string(value)
    return "'" .. value:gsub('\\', '\\\\'):gsub("'", "\\'") .. "'";
end

local set_order = { 'Idle', 'Engaged', 'Mazurka', 'Song', 'Minuet', 'March',
    'Madrigal', 'Mambo', 'Etude', 'BuffSong', 'ReiveSong', 'Lullaby' };

local function render_sets(sets)
    local lines = { 'local sets = {' };
    for _, set_name in ipairs(set_order) do
        local set = sets[set_name];
        if (set ~= nil and next(set) ~= nil) then
            lines[#lines + 1] = ('    %s = {'):format(set_name);
            for slot = 0, 15 do
                local name = set[slot_names[slot]];
                if (name ~= nil) then
                    lines[#lines + 1] = ('        %s = %s,'):format(slot_names[slot], lua_string(name));
                end
            end
            lines[#lines + 1] = '    },';
        end
    end
    lines[#lines + 1] = '};';
    return table.concat(lines, '\n');
end

local function copy_file(source, destination)
    local input = io.open(source, 'rb');
    if (input == nil) then return false; end
    local data = input:read('*a'); input:close();
    local output = io.open(destination, 'wb');
    if (output == nil) then return false; end
    output:write(data); output:close();
    return true, data;
end

function sync.run()
    local memory = AshitaCore:GetMemoryManager();
    local player = memory:GetPlayer();
    local party = memory:GetParty();
    local resources = AshitaCore:GetResourceManager();
    local job = resources:GetString('jobs.names_abbr', player:GetMainJob()) or '';
    job = job:trimend('\x00');
    if (job:upper() ~= 'BRD') then return false, 'syncbrd can only run while on BRD.'; end
    local name = party:GetMemberName(0) or 'Character';
    local root = AshitaCore:GetInstallPath() .. 'config\\addons\\luashitacast\\';
    local path = root .. name .. '_' .. job .. '.lua';
    if (not ashita.fs.exists(path)) then
        return false, ('Could not find LuAshitacast profile: %s'):format(path);
    end

    local items = inventory_items();
    local song = best_set(items, 'song', 2);
    local sets = {
        Idle = best_set(items, 'idle', 0),
        Engaged = best_set(items, 'engaged', 0),
        Song = song,
        BuffSong = { Hands = song.Hands, Legs = song.Legs },
    };
    -- Keep persistent weapons identical so changing between Idle and Engaged
    -- never causes an unnecessary TP reset.
    sets.Idle.Main = sets.Engaged.Main;
    sets.Idle.Sub = sets.Engaged.Sub;
    -- Instruments generally have no melee score, which previously left the
    -- Engaged selection to the alphabetical tie-breaker (for example,
    -- Cornette). Use the best general Song instrument in both persistent sets
    -- so a song-specific instrument is also cleared after casting.
    sets.Idle.Range = sets.Song.Range;
    sets.Engaged.Range = sets.Song.Range;
    local special = {
        Minuet = 'minuet', March = 'march', Madrigal = 'madrigal',
        Mambo = 'mambo', Etude = 'etude', Lullaby = 'lullaby',
    };
    for set_name, pattern in pairs(special) do
        sets[set_name] = { Range = named_item(items, pattern, 2) };
    end
    sets.ReiveSong = { Range = named_item(items, 'all songs', 2) };
    for _, item in ipairs(items) do
        if (item.name == "Sprinter's Shoes") then sets.Mazurka = { Feet = item.name }; end
    end

    local ok, source = copy_file(path, path .. '.syncbrd.bak');
    if (not ok) then return false, 'Could not back up the LuAshitacast profile.'; end
    local start_at = source:find('local%s+sets%s*=%s*{');
    local marker_at = source:find('profile%.Sets%s*=%s*sets%s*;');
    if (start_at == nil or marker_at == nil or marker_at <= start_at) then
        return false, 'Could not locate the sets block in the LuAshitacast profile.';
    end
    local new_source = source:sub(1, start_at - 1) .. render_sets(sets) .. '\n\n'
        .. source:sub(marker_at);
    local output = io.open(path, 'wb');
    if (output == nil) then return false, 'Could not write the LuAshitacast profile.'; end
    output:write(new_source); output:close();
    return true, ('Updated BRD profile from %d equippable inventory items.'):format(#items);
end

return sync;
