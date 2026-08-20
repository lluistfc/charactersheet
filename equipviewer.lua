addon.author    = 'Project Tako';
addon.name      = 'equipviewer';
addon.version   = '2.0.0';
addon.desc      = 'Compact equipment viewer and configurable character sheet.';
addon.link      = 'https://ashitaxi.com/';

require('common');
require('core');

local http      = require('socket.http');
local imgui     = require('imgui');
local json      = require('json');
local settings  = require('settings');
local sheet     = require('sheet');

local default_config = T{
    position = T{ 500, 500 },
    color = 0xFFFFFFFF,
    background_color = 0x40000000,
    size = 32,
    sheet_width = 360,
    sheet = sheet.default_settings,
};

local legacy_settings_path = ('%s\\settings\\settings.json'):fmt(addon.path);
if (ashita.fs.exists(legacy_settings_path)) then
    local f = io.open(legacy_settings_path, 'rb');
    if (f ~= nil) then
        local raw = f:read('*a');
        f:close();

        local ok, legacy = pcall(json.decode, raw or '');
        if (ok and type(legacy) == 'table') then
            default_config = T(legacy):merge(default_config);
        end
    end
end

local equipViewerConfig = settings.load(default_config);
local equipViewer;
local drag_state = T{
    active = false,
    offset_x = 0,
    offset_y = 0,
};
local mouse_state = T{ x = -1, y = -1 };
local gameplay_visible = false;
local p_event_system = ashita.memory.find(
    'FFXiMain.dll', 0,
    'A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3',
    0, 0);

local slot_mapping = {
    [0] = 0, [1] = 1, [2] = 2, [3] = 3,
    [4] = 4, [5] = 9, [6] = 11, [7] = 12,
    [8] = 5, [9] = 6, [10] = 13, [11] = 14,
    [12] = 15, [13] = 10, [14] = 7, [15] = 8,
};

local augment_logic = nil;
do
    local path = ('%s\\..\\XIUI\\modules\\satchel\\augmentlogic.lua'):fmt(addon.path);
    if (ashita.fs.exists(path)) then
        local ok, chunk = pcall(loadfile, path);
        if (ok and chunk ~= nil) then
            local loaded, result = pcall(chunk);
            if (loaded and type(result) == 'table') then augment_logic = result; end
        end
    end
end

local function event_system_active()
    if (p_event_system == nil or p_event_system == 0) then return false; end
    local pointer = ashita.memory.read_uint32(p_event_system + 1);
    return pointer ~= 0 and ashita.memory.read_uint8(pointer) == 1;
end

local function should_show_addon()
    local memory = AshitaCore:GetMemoryManager();
    local player = memory and memory:GetPlayer() or nil;
    local party = memory and memory:GetParty() or nil;
    if (player == nil or party == nil) then return false; end
    if (player:GetLoginStatus() ~= 2) then return false; end
    if ((tonumber(player:GetIsZoning()) or 0) ~= 0) then return false; end
    if ((tonumber(party:GetMemberIsActive(0)) or 0) <= 0) then return false; end
    if (event_system_active()) then return false; end
    return true;
end

local function resource_text(field)
    if (field == nil) then return ''; end
    local ok, value = pcall(function () return field[1]; end);
    return ok and type(value) == 'string' and value or '';
end

local function get_equipped_instance(slot)
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    local equipment = inventory and inventory:GetEquippedItem(slot) or nil;
    if (equipment == nil or equipment.Index == 0) then return nil, nil; end
    local container = bit.band(equipment.Index, 0xFF00) / 0x100;
    local item = inventory:GetContainerItem(container, equipment.Index % 0x100);
    if (item == nil or item.Id == 0 or item.Id == 65535) then return nil, nil; end
    return item, AshitaCore:GetResourceManager():GetItemById(item.Id);
end

local function render_item_tooltip()
    if (drag_state.active or equipViewer == nil) then return; end
    local x, y = equipViewerConfig.position[1], equipViewerConfig.position[2];
    local size = tonumber(equipViewerConfig.size) or 32;
    if (mouse_state.x < x or mouse_state.y < y
        or mouse_state.x >= x + size * 4 or mouse_state.y >= y + size * 4) then
        return;
    end

    local column = math.floor((mouse_state.x - x) / size);
    local row = math.floor((mouse_state.y - y) / size);
    local display_slot = row * 4 + column;
    local inventory_slot = slot_mapping[display_slot];
    local instance, item = get_equipped_instance(inventory_slot);
    if (instance == nil or item == nil) then return; end

    local name = resource_text(item.Name);
    local description = resource_text(item.Description);
    imgui.BeginTooltip();
    imgui.TextColored({ 0.45, 0.75, 1.0, 1.0 }, name ~= '' and name or ('Item %d'):fmt(instance.Id));
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
        imgui.PushTextWrapPos(430);
        imgui.TextWrapped(description);
        imgui.PopTextWrapPos();
    end
    if (augment_logic ~= nil and type(instance.Extra) == 'string') then
        local ok, augments = pcall(augment_logic.get_augment_lines, instance.Id, instance.Extra);
        if (ok and type(augments) == 'table' and #augments > 0) then
            imgui.Separator();
            imgui.TextColored({ 0.40, 1.0, 0.55, 1.0 }, 'Augments');
            for _, augment in ipairs(augments) do imgui.Text(augment); end
        end
    end
    imgui.EndTooltip();
end

local icon_root = ('%s\\icons'):fmt(addon.path);
if (not ashita.fs.exists(icon_root)) then
    ashita.fs.create_dir(icon_root);
end

for _, size in ipairs({ 16, 32, 48, 64 }) do
    local size_path = ('%s\\%d'):fmt(icon_root, size);
    if (not ashita.fs.exists(size_path)) then
        ashita.fs.create_dir(size_path);
    end
end

---------------------------------------------------------------------------------------------------
-- func: load
-- desc: First called when our addon is loaded.
---------------------------------------------------------------------------------------------------
ashita.events.register('load', 'equipviewer_load_cb', function ()
    -- Create instance of our "class".
    equipViewer = EquipViewer();

    -- Set the size before we do anything else, since if we do it after it'll redo a lot of work.
    equipViewer:SelectSize(equipViewerConfig.size);

    -- Inject the functions it needs to create onscreen objects.
    equipViewer:InjectPrimitiveDependancies(
        ashitaPrimitiveCreate,
        ashitaPrimitiveSetPosition,
        ashitaPrimitiveSetSize,
        ashitaPrimitiveSetFixToTexture,
        ashitaPrimitiveSetVisibility,
        ashitaPrimitiveSetColor,
        ashitaSetText,
        ashitaPrimitiveSetTextureFromFile,
        ashitePrimitiveDelete
    );

    -- Inject the functions it needs to get equipment info.
    equipViewer:InjectInventoryDependancies(ashitaGetEquippedItemId, ashitaGetTexturePath);

    -- Create onscreen objects.
    equipViewer:Create(
        equipViewerConfig.position[1],
        equipViewerConfig.position[2],
        equipViewerConfig.color,
        equipViewerConfig.background_color
    );

    -- Update equipment for initial load.
    equipViewer:Update();
    equipViewer:SetVisible(false);
    gameplay_visible = false;
    sheet.initialize(equipViewerConfig.sheet, function () settings.save(); end);
end);

settings.register('settings', 'equipviewer_settings_update', function (s)
    if (s ~= nil) then equipViewerConfig = s; end
    sheet.initialize(equipViewerConfig.sheet, function () settings.save(); end);
    sheet.invalidate();
end);

---------------------------------------------------------------------------------------------------
-- func: command
-- desc: Called when our addon receives a command.
---------------------------------------------------------------------------------------------------
ashita.events.register('command', 'equipviewer_command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/equipviewer', '/skillwatch', '/swatch')) then
        return;
    end

    e.blocked = true;

    local command = args[2] and args[2]:lower() or 'config';
    if (command:any('config', 'settings')) then
        sheet.open_config();
        return;
    end

    if (args[2] == 'position' or args[2] == 'pos') then
        if (#args < 4) then
            return;
        end

        equipViewerConfig.position = T{ tonumber(args[3]), tonumber(args[4]) };
        equipViewer:Move(equipViewerConfig.position[1], equipViewerConfig.position[2]);
        settings.save();
        return;
    end

    if (args[2] == 'size') then
        if (#args < 3) then
            return;
        end

        local size = tonumber(args[3]);
        if (size == nil) then
            return;
        end

        local validSize = equipViewer:SelectSize(size);
        if (validSize > -1) then
            equipViewerConfig.size = size;
            equipViewer:Resize(equipViewerConfig.position[1], equipViewerConfig.position[2], equipViewerConfig.size);
            if (not gameplay_visible) then equipViewer:SetVisible(false); end
            settings.save();
        end

        return;
    end

    if (command == 'show') then
        equipViewerConfig.sheet.visible[1] = true;
        settings.save();
        return;
    elseif (command == 'hide') then
        equipViewerConfig.sheet.visible[1] = false;
        settings.save();
        return;
    elseif (command == 'toggle') then
        equipViewerConfig.sheet.visible[1] = not equipViewerConfig.sheet.visible[1];
        settings.save();
        return;
    end
end);

---------------------------------------------------------------------------------------------------
-- func: packet_in
-- desc: Called when our addon receives an incoming packet.
---------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'equipviewer_packet_in_cb', function (e)
    -- Equipment or Inventory Finish.
    if (e.id == 0x001D or e.id == 0x0037) then
        if (gameplay_visible) then equipViewer:Update(); end
        sheet.invalidate();
    end
end);

---------------------------------------------------------------------------------------------------
-- func: packet_out
-- desc: Called when our addon receives an outgoing packet.
---------------------------------------------------------------------------------------------------
ashita.events.register('packet_out', 'equipviewer_packet_out_cb', function (e)
    -- Action or Equipment Changed packet.
    if (e.id == 0x001A or e.id == 0x0050) then
        if (gameplay_visible) then equipViewer:Update(); end
        sheet.invalidate();
    end
end);

---------------------------------------------------------------------------------------------------
-- func: mouse
-- desc: Called when our addon receives mouse input.
---------------------------------------------------------------------------------------------------
ashita.events.register('mouse', 'equipviewer_mouse_cb', function (e)
    if (equipViewer == nil or not gameplay_visible) then
        return;
    end

    mouse_state.x = e.x;
    mouse_state.y = e.y;

    local x = equipViewerConfig.position[1];
    local y = equipViewerConfig.position[2];
    local size = equipViewerConfig.size;
    local width = size * 4;
    local height = size * 4;

    local function hit_test(px, py)
        return (px >= x and px <= (x + width) and py >= y and py <= (y + height));
    end

    -- Mouse move.
    if (e.message == 512 and drag_state.active) then
        equipViewerConfig.position[1] = e.x - drag_state.offset_x;
        equipViewerConfig.position[2] = e.y - drag_state.offset_y;
        equipViewer:Move(equipViewerConfig.position[1], equipViewerConfig.position[2]);
        e.blocked = true;
        return;
    end

    -- Left button down.
    if (e.message == 513 and hit_test(e.x, e.y)) then
        drag_state.active = true;
        drag_state.offset_x = e.x - equipViewerConfig.position[1];
        drag_state.offset_y = e.y - equipViewerConfig.position[2];
        e.blocked = true;
        return;
    end

    -- Left button up.
    if (e.message == 514 and drag_state.active) then
        drag_state.active = false;
        settings.save();
        e.blocked = true;
        return;
    end
end);

ashita.events.register('d3d_present', 'equipviewer_present_cb', function ()
    if (equipViewer == nil) then return; end
    local visible = should_show_addon();
    if (visible ~= gameplay_visible) then
        gameplay_visible = visible;
        equipViewer:SetVisible(visible);
    end
    if (not gameplay_visible) then return; end

    local grid_width = (tonumber(equipViewerConfig.size) or 32) * 4;
    sheet.render_panel(
        equipViewerConfig.position[1] + grid_width,
        equipViewerConfig.position[2],
        tonumber(equipViewerConfig.sheet_width) or 330
    );
    sheet.render_config();
    render_item_tooltip();
end);

---------------------------------------------------------------------------------------------------
-- func: unload
-- desc: Called when our addon is unloaded.
---------------------------------------------------------------------------------------------------
ashita.events.register('unload', 'equipviewer_unload_cb', function ()
    settings.save();

    if (equipViewer ~= nil) then
        equipViewer:Delete();
        equipViewer = nil;
    end
end);

-- Functions to work with Font/Primitive Objects.
function ashitaPrimitiveCreate(name)
    local f = AshitaCore:GetFontManager():Create(name);
    f:SetAutoResize(false);
    f:SetLocked(true);
end

function ashitaSetText(name, text)
    AshitaCore:GetFontManager():Get(name):SetText(text);
end

function ashitaPrimitiveSetPosition(name, x, y)
    AshitaCore:GetFontManager():Get(name):SetPositionX(x);
    AshitaCore:GetFontManager():Get(name):SetPositionY(y);
end

function ashitaPrimitiveSetSize(name, x, y)
    AshitaCore:GetFontManager():Get(name):GetBackground():SetWidth(x);
    AshitaCore:GetFontManager():Get(name):GetBackground():SetHeight(y);
end

function ashitaPrimitiveSetFixToTexture(name, fitToTextture)
end

function ashitaPrimitiveSetVisibility(name, visible)
    local font = AshitaCore:GetFontManager():Get(name);
    if (font == nil) then
        return;
    end

    font:SetVisible(visible);

    local bg = font:GetBackground();
    if (bg ~= nil) then
        bg:SetVisible(visible);
    end
end

function ashitaPrimitiveSetColor(name, color)
    local font = AshitaCore:GetFontManager():Get(name);
    if (font == nil) then
        return;
    end

    font:SetColor(color);

    local bg = font:GetBackground();
    if (bg ~= nil) then
        bg:SetColor(color);
    end
end

function ashitaPrimitiveSetTextureFromFile(name, texturePath)
    local font = AshitaCore:GetFontManager():Get(name);
    if (font == nil) then
        return;
    end

    local bg = font:GetBackground();
    if (bg ~= nil) then
        bg:SetTextureFromFile(texturePath);
    end
end

function ashitePrimitiveDelete(name)
    AshitaCore:GetFontManager():Delete(name);
end

-- Inventory Functions.
function ashitaGetEquippedItemId(slot, slot_name)
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    if (inventory == nil) then
        return 0;
    end

    local equipment = inventory:GetEquippedItem(slot);
    if (equipment == nil) then
        return 0;
    end

    local index = equipment.Index;

    if (index == 0) then
        return 0;
    end

    local container = bit.band(index, 0xFF00) / 0x0100;
    local container_index = bit.band(index, 0x00FF);
    local item = inventory:GetContainerItem(container, container_index);
    if (item == nil) then
        return 0;
    end

    return item.Id or 0;
end

-- Pathing functions.
function ashitaGetTexturePath(itemId)
    local path = ('%s\\icons\\%d\\%d.png'):fmt(addon.path, equipViewerConfig.size, itemId);
    if (ashita.fs.exists(path)) then
        return path;
    end

    local body, code = http.request(('http://static.ffxiah.com/images/icon/%d.png'):fmt(itemId));
    if (not body) then
        print(('Could not find or retrieve icon file for item id %d. HTTP Code: %s'):fmt(itemId, tostring(code)));
        return ('%s\\icons\\0.png'):fmt(addon.path);
    end

    local f = assert(io.open(path, 'wb'));
    f:write(body);
    f:close();

    return path;
end
