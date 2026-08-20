local export = {};

local bag_names = {
    [0] = 'Inventory', [8] = 'Wardrobe', [10] = 'Wardrobe2',
    [11] = 'Wardrobe3', [12] = 'Wardrobe4', [13] = 'Wardrobe5',
    [14] = 'Wardrobe6', [15] = 'Wardrobe7', [16] = 'Wardrobe8',
};

local slot_names = {
    [0] = 'Main', 'Sub', 'Range', 'Ammo', 'Head', 'Body', 'Hands',
    'Legs', 'Feet', 'Neck', 'Waist', 'Ear1', 'Ear2', 'Ring1', 'Ring2', 'Back',
};

local function normalize_name(value)
    return type(value) == 'string' and value:lower():gsub('^%s+', ''):gsub('%s+$', '') or '';
end

local function collect_string_literals(source, output)
    local index = 1;
    while index <= #source do
        local quote = source:sub(index, index);
        if (quote == "'" or quote == '"') then
            local value = {};
            index = index + 1;
            while index <= #source do
                local character = source:sub(index, index);
                if (character == '\\' and index < #source) then
                    value[#value + 1] = source:sub(index + 1, index + 1);
                    index = index + 2;
                elseif (character == quote) then
                    output[normalize_name(table.concat(value))] = true;
                    index = index + 1;
                    break;
                else
                    value[#value + 1] = character;
                    index = index + 1;
                end
            end
        else
            index = index + 1;
        end
    end
end

-- Returns every item name mentioned by one of this character's LuAshitacast
-- profiles.  Reading the source instead of executing it avoids profile side
-- effects (OnLoad commands, includes, and other user code) during a sync.
local function profile_item_names(player_name)
    local names = {};
    local root = AshitaCore:GetInstallPath() .. 'config\\addons\\luashitacast\\';
    local escaped_name = player_name:gsub('([^%w])', '%%%1');
    local files = ashita.fs.get_dir(root, '.*\\.lua$', true) or {};

    for _, relative_path in ipairs(files) do
        local path = root .. relative_path;
        local normalized_path = path:lower():gsub('/', '\\');
        local filename = normalized_path:match('[^\\]+$') or '';
        local is_player_profile = filename:match('^' .. escaped_name:lower() .. '_') ~= nil
            or normalized_path:match('\\' .. escaped_name:lower() .. '_%d+\\[^\\]+%.lua$') ~= nil;
        if (is_player_profile and not normalized_path:find('\\backups\\', 1, true)) then
            local file = io.open(path, 'rb');
            if (file ~= nil) then
                local source = file:read('*a') or '';
                file:close();

                -- Gear entries may be plain strings or Name fields in tables.
                -- Collecting all string literals is deliberately conservative:
                -- a literal matching an owned item will never be reported as
                -- unused even if a profile builds its sets indirectly.
                collect_string_literals(source, names);
            end
        end
    end

    return names;
end

local function resource_text(field)
    if (field == nil) then return ''; end
    local ok, value = pcall(function () return field[1]; end);
    if (ok and type(value) == 'string') then
        return value:gsub('[\r\n]+', ' ');
    end
    return '';
end

local function slot_text(mask)
    local result = {};
    for slot = 0, 15 do
        if (bit.band(mask, math.pow(2, slot)) ~= 0) then
            result[#result + 1] = slot_names[slot];
        end
    end
    return table.concat(result, ', ');
end

function export.run()
    local memory = AshitaCore:GetMemoryManager();
    local inventory = memory:GetInventory();
    local player = memory:GetPlayer();
    local party = memory:GetParty();
    local resources = AshitaCore:GetResourceManager();
    local current_job = player:GetMainJob();
    local current_level = player:GetMainJobLevel();
    local player_name = party:GetMemberName(0) or 'Character';
    local job_name = resources:GetString('jobs.names_abbr', current_job) or ('JOB' .. current_job);
    job_name = job_name:trimend('\x00');
    local equipped = {};
    local entries = {};

    for slot = 0, 15 do
        local item = inventory:GetEquippedItem(slot);
        if (item ~= nil and item.Index ~= 0) then
            local container = bit.band(item.Index, 0xFF00) / 0x100;
            local index = item.Index % 0x100;
            equipped[container .. ':' .. index] = true;
        end
    end

    for _, container in ipairs({ 0, 8, 10, 11, 12, 13, 14, 15, 16 }) do
        local maximum = inventory:GetContainerCountMax(container);
        for index = 1, maximum do
            local instance = inventory:GetContainerItem(container, index);
            if (instance ~= nil and instance.Id > 0 and instance.Count > 0) then
                local item = resources:GetItemById(instance.Id);
                if (item ~= nil) then
                    local jobs = tonumber(item.Jobs) or 0;
                    local slots = tonumber(item.Slots) or 0;
                    local level = tonumber(item.Level) or 0;
                    if (slots > 0 and level <= current_level
                        and bit.band(jobs, math.pow(2, current_job)) ~= 0) then
                        local name = resource_text(item.Name);
                        local stats = {};
                        local damage = tonumber(item.Damage) or 0;
                        local delay = tonumber(item.Delay) or 0;
                        local defense = tonumber(item.Defense) or 0;
                        local description = resource_text(item.Description);
                        if (damage > 0) then stats[#stats + 1] = 'DMG:' .. damage; end
                        if (delay > 0) then stats[#stats + 1] = 'Delay:' .. delay; end
                        if (defense > 0) then stats[#stats + 1] = 'DEF:' .. defense; end
                        if (description ~= '') then stats[#stats + 1] = description; end
                        entries[#entries + 1] = {
                            name = name,
                            text = ('%s%s | Lv.%d | %s | %s | %s'):format(
                                equipped[container .. ':' .. index] and '[EQUIPPED] ' or '',
                                name, level, slot_text(slots), bag_names[container],
                                table.concat(stats, ' | ')),
                        };
                    end
                end
            end
        end
    end

    table.sort(entries, function (a, b)
        return string.lower(a.name) < string.lower(b.name);
    end);

    local filename = ('%s_%s_gear.txt'):format(player_name, job_name);
    local path = AshitaCore:GetInstallPath() .. 'config\\addons\\charactersheet\\' .. filename;
    local file = io.open(path, 'w');
    if (file == nil) then
        return false, ('Could not create gear export: %s'):format(path);
    end

    file:write(('%s %s equippable gear (level %d)\n'):format(
        player_name, job_name, current_level));
    file:write(('Exported entries: %d\n\n'):format(#entries));
    for _, entry in ipairs(entries) do file:write(entry.text .. '\n'); end
    file:close();
    return true, ('Exported %d entries to: %s'):format(#entries, path);
end

function export.get_unused_profile_items()
    local memory = AshitaCore:GetMemoryManager();
    local inventory = memory:GetInventory();
    local player = memory:GetPlayer();
    local party = memory:GetParty();
    local resources = AshitaCore:GetResourceManager();
    local current_job = player:GetMainJob();
    local current_level = player:GetMainJobLevel();
    local player_name = party:GetMemberName(0) or 'Character';
    local profiled_names = profile_item_names(player_name);
    local equipped = {};
    local entries = {};

    for slot = 0, 15 do
        local item = inventory:GetEquippedItem(slot);
        if (item ~= nil and item.Index ~= 0) then
            local container = bit.band(item.Index, 0xFF00) / 0x100;
            local index = item.Index % 0x100;
            equipped[container .. ':' .. index] = true;
        end
    end

    -- The sync report is intentionally limited to the main Inventory bag.
    -- Wardrobe gear is available to LuAshitacast but is not part of the
    -- requested cleanup list.
    for _, container in ipairs({ 0 }) do
        local maximum = inventory:GetContainerCountMax(container);
        for index = 1, maximum do
            local instance = inventory:GetContainerItem(container, index);
            if (instance ~= nil and instance.Id > 0 and instance.Count > 0) then
                local item = resources:GetItemById(instance.Id);
                if (item ~= nil) then
                    local jobs = tonumber(item.Jobs) or 0;
                    local slots = tonumber(item.Slots) or 0;
                    local level = tonumber(item.Level) or 0;
                    local name = resource_text(item.Name);
                    if (slots > 0 and level <= current_level
                        and bit.band(jobs, math.pow(2, current_job)) ~= 0
                        and not equipped[container .. ':' .. index]
                        and not profiled_names[normalize_name(name)]) then
                        entries[#entries + 1] = {
                            name = name,
                            bag = bag_names[container],
                        };
                    end
                end
            end
        end
    end

    table.sort(entries, function (a, b)
        if (string.lower(a.name) == string.lower(b.name)) then
            return a.bag < b.bag;
        end
        return string.lower(a.name) < string.lower(b.name);
    end);
    return entries;
end

return export;
