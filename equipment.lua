local d3d = require('d3d8');
local ffi = require('ffi');
local imgui = require('imgui');

local M = {
    addon_path = nil,
    slot_texture = nil,
    slot_ptr = nil,
    item_cache = {},
    augment_logic = nil,
};

local slot_mapping = {
    [0] = 0, [1] = 1, [2] = 2, [3] = 3,
    [4] = 4, [5] = 9, [6] = 11, [7] = 12,
    [8] = 5, [9] = 6, [10] = 13, [11] = 14,
    [12] = 15, [13] = 10, [14] = 7, [15] = 8,
};

local function resource_text(field)
    if (field == nil) then return ''; end
    local ok, value = pcall(function () return field[1]; end);
    return ok and type(value) == 'string' and value or '';
end

local function load_file_texture(path)
    if (path == nil or not ashita.fs.exists(path)) then return nil, nil; end
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    if (ffi.C.D3DXCreateTextureFromFileA(d3d.get_device(), path, texture_ptr) ~= ffi.C.S_OK) then
        return nil, nil;
    end
    local texture = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));
    return texture, tonumber(ffi.cast('uint32_t', texture));
end

local function load_item_texture(item_id)
    local cached = M.item_cache[item_id];
    if (cached ~= nil) then return cached.ptr; end
    local item = AshitaCore:GetResourceManager():GetItemById(item_id);
    if (item == nil or item.Bitmap == nil or (tonumber(item.ImageSize) or 0) <= 0) then return nil; end

    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    local result = ffi.C.D3DXCreateTextureFromFileInMemoryEx(
        d3d.get_device(), item.Bitmap, item.ImageSize,
        0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8,
        ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT,
        0xFF000000, nil, nil, texture_ptr);
    if (result ~= ffi.C.S_OK) then return nil; end

    local texture = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));
    cached = { texture = texture, ptr = tonumber(ffi.cast('uint32_t', texture)) };
    M.item_cache[item_id] = cached;
    return cached.ptr;
end

function M.get_equipped(slot)
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    local equipment = inventory and inventory:GetEquippedItem(slot) or nil;
    if (equipment == nil or equipment.Index == 0) then return nil, nil; end
    local container = bit.band(equipment.Index, 0xFF00) / 0x100;
    local instance = inventory:GetContainerItem(container, equipment.Index % 0x100);
    if (instance == nil or instance.Id == 0 or instance.Id == 65535) then return nil, nil; end
    return instance, AshitaCore:GetResourceManager():GetItemById(instance.Id);
end

local function render_tooltip(instance, item)
    local name = resource_text(item.Name);
    local description = resource_text(item.Description);
    imgui.BeginTooltip();
    imgui.TextColored({ 0.48, 0.76, 1.0, 1.0 }, name ~= '' and name or ('Item %d'):fmt(instance.Id));
    local damage = tonumber(item.Damage) or 0;
    local delay = tonumber(item.Delay) or 0;
    local defense = tonumber(item.Defense) or 0;
    if (damage > 0) then
        imgui.Text(('DMG:%d%s'):fmt(damage, delay > 0 and ('  Delay:%d'):fmt(delay) or ''));
    elseif (defense > 0) then
        imgui.Text(('DEF:%d'):fmt(defense));
    end
    if (description ~= '') then
        imgui.Separator();
        imgui.PushTextWrapPos(imgui.GetFontSize() * 30);
        imgui.TextWrapped(description);
        imgui.PopTextWrapPos();
    end
    if (M.augment_logic ~= nil and type(instance.Extra) == 'string') then
        local ok, augments = pcall(M.augment_logic.get_augment_lines, instance.Id, instance.Extra);
        if (ok and type(augments) == 'table' and #augments > 0) then
            imgui.Separator();
            imgui.TextColored({ 0.48, 0.92, 0.56, 1.0 }, 'Augments');
            for _, augment in ipairs(augments) do imgui.Text(augment); end
        end
    end
    imgui.EndTooltip();
end

M.render_tooltip = render_tooltip;

function M.get_augment_lines(instance)
    if (M.augment_logic == nil or instance == nil or type(instance.Extra) ~= 'string') then
        return {};
    end
    local ok, lines = pcall(M.augment_logic.get_augment_lines, instance.Id, instance.Extra);
    return ok and type(lines) == 'table' and lines or {};
end

function M.initialize(addon_path)
    M.addon_path = addon_path;
    M.slot_texture, M.slot_ptr = load_file_texture(('%s\\assets\\slot-classic.png'):fmt(addon_path));
    local augment_path = ('%s\\..\\XIUI\\modules\\satchel\\augmentlogic.lua'):fmt(addon_path);
    if (ashita.fs.exists(augment_path)) then
        local ok, chunk = pcall(loadfile, augment_path);
        if (ok and chunk ~= nil) then
            local loaded, result = pcall(chunk);
            if (loaded and type(result) == 'table') then M.augment_logic = result; end
        end
    end
end

function M.invalidate()
    -- Textures are keyed by immutable item resource id and remain valid.
end

function M.render_slot(slot, slot_size, id_suffix)
    slot_size = math.max(16, tonumber(slot_size) or 32);
    local draw_list = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    if (M.slot_ptr ~= nil) then
        draw_list:AddImage(M.slot_ptr, { x, y }, { x + slot_size, y + slot_size },
            { 0, 0 }, { 1, 1 }, imgui.GetColorU32({ 0.78, 0.65, 0.42, 1.0 }));
    else
        draw_list:AddRectFilled({ x, y }, { x + slot_size, y + slot_size },
            imgui.GetColorU32({ 0.08, 0.10, 0.13, 0.96 }), 0, 0);
        draw_list:AddRect({ x, y }, { x + slot_size, y + slot_size },
            imgui.GetColorU32({ 0.55, 0.42, 0.22, 1.0 }), 0, 0, 1);
    end

    local instance, item = M.get_equipped(slot);
    if (instance ~= nil and item ~= nil) then
        local ptr = load_item_texture(instance.Id);
        if (ptr ~= nil) then
            local inset = math.max(1, math.floor(slot_size * 0.07));
            draw_list:AddImage(ptr,
                { x + inset, y + inset }, { x + slot_size - inset, y + slot_size - inset },
                { 0, 0 }, { 1, 1 }, 0xFFFFFFFF);
        end
    end

    imgui.InvisibleButton(('##equipment_slot_%s'):fmt(tostring(id_suffix or slot)), { slot_size, slot_size });
    if (instance ~= nil and item ~= nil and imgui.IsItemHovered()) then
        render_tooltip(instance, item);
    end
    return instance, item;
end

function M.render_grid(slot_size)
    slot_size = math.max(16, tonumber(slot_size) or 32);
    local start_x, start_y = imgui.GetCursorScreenPos();
    for display_slot = 0, 15 do
        local column = display_slot % 4;
        local row = math.floor(display_slot / 4);
        local x = start_x + column * slot_size;
        local y = start_y + row * slot_size;
        imgui.SetCursorScreenPos({ x, y });
        M.render_slot(slot_mapping[display_slot], slot_size, ('grid_%d'):fmt(display_slot));
    end
    imgui.SetCursorScreenPos({ start_x, start_y + slot_size * 4 });
    imgui.Dummy({ slot_size * 4, 0 });
end

function M.shutdown()
    M.item_cache = {};
    M.slot_ptr = nil;
    M.slot_texture = nil;
    M.augment_logic = nil;
end

return M;
