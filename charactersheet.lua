addon.author = 'Project Tako'
addon.name = 'charactersheet'
addon.version = '3.3.0'
addon.desc = 'Compact character sheet for equipment, stats, skills, and abilities.'
addon.link = 'https://ashitaxi.com/'

require 'common'

local imgui = require 'imgui'
local chat = require 'chat'
local json = require 'json'
local settings = require 'settings'
local sheet = require 'sheet'
local theme = require 'theme'
local equipment = require 'equipment'
local gearinfo_panel = require 'gearinfo_panel'
local gear_export = require 'gear_export'
local brd_profile_sync = require 'brd_profile_sync'
local character_export = require 'character_export'

local default_config = T {
    position = T { 500, 500 },
    color = 0xFFFFFFFF,
    background_color = 0x40000000,
    size = 32,
    sheet_width = 1100,
    sheet = sheet.default_settings,
    gearinfo = gearinfo_panel.defaults,
}

local legacy_settings_path = ('%s\\settings\\settings.json'):fmt(addon.path)
if ashita.fs.exists(legacy_settings_path) then
    local f = io.open(legacy_settings_path, 'rb')
    if f ~= nil then
        local raw = f:read '*a'
        f:close()

        local ok, legacy = pcall(json.decode, raw or '')
        if ok and type(legacy) == 'table' then
            default_config = T(legacy):merge(default_config)
        end
    end
end

local equipViewerConfig = settings.load(default_config)
local drag_state = T {
    active = false,
    offset_x = 0,
    offset_y = 0,
}
local gameplay_visible = nil
local function save_settings()
    settings.save()
end

local function set_sheet_width(width)
    equipViewerConfig.sheet_width = width
end

local function toggle_gearinfo()
    gearinfo_panel.toggle()
end

local function initialize_panels()
    sheet.initialize(
        equipViewerConfig.sheet,
        save_settings,
        equipViewerConfig.sheet_width,
        set_sheet_width,
        toggle_gearinfo
    )
    equipViewerConfig.gearinfo = gearinfo_panel.initialize(equipViewerConfig.gearinfo, save_settings)
end

local function invalidate_panels()
    equipment.invalidate()
    sheet.invalidate()
    gearinfo_panel.invalidate()
end

local p_event_system = ashita.memory.find(
    'FFXiMain.dll',
    0,
    'A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3',
    0,
    0
)

local function event_system_active()
    if p_event_system == nil or p_event_system == 0 then
        return false
    end
    local ok, active = pcall(function()
        local pointer = ashita.memory.read_uint32(p_event_system + 1)
        return pointer ~= 0 and ashita.memory.read_uint8(pointer) == 1
    end)
    return ok and active or false
end

local function should_show_addon()
    local memory = AshitaCore:GetMemoryManager()
    local player = memory and memory:GetPlayer() or nil
    if player == nil then
        return false
    end
    if player:GetLoginStatus() ~= 2 then
        return false
    end
    if (tonumber(player:GetMainJob()) or 0) <= 0 then
        return false
    end
    if event_system_active() then
        return false
    end
    return true
end

---------------------------------------------------------------------------------------------------
-- func: load
-- desc: First called when our addon is loaded.
---------------------------------------------------------------------------------------------------
ashita.events.register('load', 'charactersheet_load_cb', function()
    gameplay_visible = nil
    equipment.initialize(addon.path)
    theme.initialize(('%s\\assets\\panel-leather-512.png'):fmt(addon.path))
    initialize_panels()
end)

settings.register('settings', 'charactersheet_settings_update', function(s)
    if s ~= nil then
        equipViewerConfig = s
    end
    initialize_panels()
    sheet.invalidate()
end)

---------------------------------------------------------------------------------------------------
-- func: command
-- desc: Called when our addon receives a command.
---------------------------------------------------------------------------------------------------
ashita.events.register('command', 'charactersheet_command_cb', function(e)
    local args = e.command:args()
    if #args == 0 or args[1] ~= '/charactersheet' then
        return
    end

    e.blocked = true

    local command = args[2] and args[2]:lower() or 'config'
    if command == 'syncbrd' then
        local mode = args[3] and args[3]:lower() or 'hybrid'
        if mode ~= 'support' and mode ~= 'dmg' and mode ~= 'hybrid' then
            print(chat.header(addon.name):append(chat.error 'Usage: /charactersheet syncbrd [support|dmg|hybrid]'))
            return
        end
        print(
            chat.header(addon.name)
                :append(chat.message(('BRD sync (%s): exporting current equippable gear...'):format(mode)))
        )
        local success, message = gear_export.run()
        if not success then
            print(chat.header(addon.name):append(chat.error('BRD sync failed: ' .. message)))
            return
        end

        print(chat.header(addon.name):append(chat.message(message)))
        local updated, update_message = brd_profile_sync.run(mode)
        if not updated then
            print(chat.header(addon.name):append(chat.error('BRD sync failed: ' .. update_message)))
            return
        end
        print(chat.header(addon.name):append(chat.message(update_message)))
        local unused_items = gear_export.get_unused_profile_items()
        if #unused_items == 0 then
            print(chat.header(addon.name):append(chat.message 'Unused equippable items: none.'))
        else
            print(chat.header(addon.name):append(chat.message(('Unused equippable items (%d):'):format(#unused_items))))
            for _, item in ipairs(unused_items) do
                print(chat.header(addon.name):append(chat.message(('%s [%s]'):format(item.name, item.bag))))
            end
        end
        print(
            chat.header(addon.name)
                :append(chat.message 'BRD sync: gear export refreshed; reloading LuAshitacast profile...')
        )
        AshitaCore:GetChatManager():QueueCommand(1, '/lac reload')
        return
    end
    if command:any('exportall', 'exportcharacter', 'exportprofile') then
        local success, message = character_export.run()
        local output = success and chat.message(message) or chat.error(message)
        print(chat.header(addon.name):append(output))
        return
    end
    if command:any('exportgear', 'export') then
        local success, message = gear_export.run()
        local output = success and chat.message(message) or chat.error(message)
        print(chat.header(addon.name):append(output))
        return
    end
    if command:any('gearinfo', 'gi') then
        local subcommand = args[3] and args[3]:lower() or 'toggle'
        if subcommand == 'show' then
            gearinfo_panel.set_visible(true)
        elseif subcommand == 'hide' then
            gearinfo_panel.set_visible(false)
        elseif subcommand == 'toggle' then
            gearinfo_panel.toggle()
        elseif subcommand == 'lock' then
            gearinfo_panel.toggle_lock()
        elseif subcommand == 'dw' then
            gearinfo_panel.toggle_dw()
        elseif subcommand == 'scale' and tonumber(args[4]) then
            gearinfo_panel.set_scale(args[4])
        elseif subcommand == 'width' and tonumber(args[4]) then
            gearinfo_panel.set_width(args[4])
        elseif subcommand == 'reset' then
            gearinfo_panel.reset()
        else
            print(
                chat.header(addon.name)
                    :append(
                        chat.message '/charactersheet gearinfo [toggle|show|hide|lock|dw|scale <n>|width <px>|reset]'
                    )
            )
        end
        return
    end
    if command:any('config', 'settings') then
        sheet.open_config()
        return
    end

    if args[2] == 'position' or args[2] == 'pos' then
        if #args < 4 then
            return
        end

        equipViewerConfig.position = T { tonumber(args[3]), tonumber(args[4]) }
        settings.save()
        return
    end

    if args[2] == 'size' then
        if #args < 3 then
            return
        end

        local size = tonumber(args[3])
        if size == nil then
            return
        end

        if T({ 16, 32, 48, 64 }):hasval(size) then
            equipViewerConfig.size = size
            settings.save()
        end

        return
    end

    if command == 'reset' then
        equipViewerConfig.position = T { 40, 40 }
        settings.save()
        return
    end

    if command == 'show' then
        equipViewerConfig.sheet.visible[1] = true
        settings.save()
        return
    elseif command == 'hide' then
        equipViewerConfig.sheet.visible[1] = false
        settings.save()
        return
    elseif command == 'toggle' then
        equipViewerConfig.sheet.visible[1] = not equipViewerConfig.sheet.visible[1]
        settings.save()
        return
    end
end)

---------------------------------------------------------------------------------------------------
-- func: packet_in
-- desc: Called when our addon receives an incoming packet.
---------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'charactersheet_packet_in_cb', function(e)
    gearinfo_panel.handle_packet(e)
    -- Equipment or Inventory Finish.
    if e.id == 0x001D or e.id == 0x0037 then
        invalidate_panels()
    end
end)

---------------------------------------------------------------------------------------------------
-- func: packet_out
-- desc: Called when our addon receives an outgoing packet.
---------------------------------------------------------------------------------------------------
ashita.events.register('packet_out', 'charactersheet_packet_out_cb', function(e)
    -- Action or Equipment Changed packet.
    if e.id == 0x001A or e.id == 0x0050 then
        invalidate_panels()
    end
end)

---------------------------------------------------------------------------------------------------
-- func: mouse
-- desc: Called when our addon receives mouse input.
---------------------------------------------------------------------------------------------------
ashita.events.register('mouse', 'charactersheet_mouse_cb', function(e)
    if not gameplay_visible then
        return
    end
    if equipViewerConfig.sheet.lock_position ~= nil and equipViewerConfig.sheet.lock_position[1] then
        drag_state.active = false
        return
    end

    local x = equipViewerConfig.position[1]
    local y = equipViewerConfig.position[2]
    local size = equipViewerConfig.size

    local function hit_test(px, py)
        if sheet.is_collapsed() then
            local grid_size = size * 4
            return (px >= x and px <= (x + grid_size) and py >= y and py <= (y + grid_size))
        end

        -- The expanded title area is the drag handle. Leave the controls on the
        -- right side to ImGui so Collapse and Config remain clickable.
        local panel_width = sheet.get_render_width(equipViewerConfig.sheet_width)
        -- Collapse (26), GearInfo (72), Config (68), and their spacing occupy
        -- roughly 190 px. Never let the custom drag handler consume clicks in
        -- that controls region.
        return (px >= x and px <= (x + panel_width - 200) and py >= y and py <= (y + 34))
    end

    -- Mouse move.
    if e.message == 512 and drag_state.active then
        equipViewerConfig.position[1] = e.x - drag_state.offset_x
        equipViewerConfig.position[2] = e.y - drag_state.offset_y
        e.blocked = true
        return
    end

    -- Left button down.
    if e.message == 513 and hit_test(e.x, e.y) then
        drag_state.active = true
        drag_state.offset_x = e.x - equipViewerConfig.position[1]
        drag_state.offset_y = e.y - equipViewerConfig.position[2]
        e.blocked = true
        return
    end

    -- Left button up.
    if e.message == 514 and drag_state.active then
        drag_state.active = false
        settings.save()
        e.blocked = true
        return
    end
end)

ashita.events.register('d3d_present', 'charactersheet_present_cb', function()
    local visible = should_show_addon()
    gameplay_visible = visible
    if not gameplay_visible then
        return
    end

    local grid_width = (tonumber(equipViewerConfig.size) or 32) * 4
    local io = imgui.GetIO()
    local display = io and io.DisplaySize or nil
    local screen_width = display and (tonumber(display.x) or tonumber(display[1])) or 1920
    local screen_height = display and (tonumber(display.y) or tonumber(display[2])) or 1080
    local render_width = sheet.is_collapsed() and (grid_width + 28)
        or sheet.get_render_width(equipViewerConfig.sheet_width)
    equipViewerConfig.position[1] =
        math.max(8, math.min(tonumber(equipViewerConfig.position[1]) or 8, screen_width - render_width - 8))
    equipViewerConfig.position[2] =
        math.max(8, math.min(tonumber(equipViewerConfig.position[2]) or 8, screen_height - 80))
    -- Render the optional companion first. If the two panels overlap, the
    -- CharacterSheet header and its Collapse/Config controls must remain on
    -- top and receive the click rather than a GearInfo cell underneath.
    gearinfo_panel.render()
    sheet.render_panel(
        equipViewerConfig.position[1],
        equipViewerConfig.position[2],
        tonumber(equipViewerConfig.sheet_width) or 1100,
        grid_width
    )
    sheet.render_config()
end)

---------------------------------------------------------------------------------------------------
-- func: unload
-- desc: Called when our addon is unloaded.
---------------------------------------------------------------------------------------------------
ashita.events.register('unload', 'charactersheet_unload_cb', function()
    settings.save()
    theme.shutdown()
    equipment.shutdown()
end)
