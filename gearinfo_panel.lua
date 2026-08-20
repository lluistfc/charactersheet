local engine = require('gearinfo_engine');
local imgui = require('imgui');

local M = {};

M.defaults = T{
    visible = T{ false },
    locked = T{ false },
    show_dw = T{ true },
    scale = T{ 1.0 },
    cell_width = T{ 76 },
    position = T{ 680, 450 },
    interval = 0.25,
};

local state = {
    settings = nil,
    save = function() end,
    snapshot = nil,
    last_update = 0,
    first_position = true,
};

local colors = {
    red = { 0.68, 0.08, 0.18, 0.94 },
    purple = { 0.34, 0.13, 0.52, 0.94 },
    blue = { 0.10, 0.22, 0.55, 0.94 },
    green = { 0.10, 0.48, 0.31, 0.94 },
    orange = { 0.66, 0.28, 0.06, 0.94 },
    header = { 1.00, 0.82, 0.88, 1.00 },
    value = { 1.00, 1.00, 1.00, 1.00 },
};

local function scalar(value, fallback)
    if (type(value) == 'table') then return tonumber(value[1]) or fallback; end
    return tonumber(value) or fallback;
end

local function enabled(value)
    return type(value) == 'table' and value[1] == true or value == true;
end

local function format_number(value, decimals)
    value = tonumber(value) or 0;
    if (decimals) then return (('%.1f'):format(value):gsub('%.0$', '')); end
    return ('%d'):format(math.floor(value + 0.5));
end

local function cell(label, value, color, id, scale, cell_width)
    local width, height = cell_width * scale, 44 * scale;
    local x, y = imgui.GetCursorScreenPos();
    local draw = imgui.GetWindowDrawList();
    draw:AddRectFilled({ x, y }, { x + width, y + height }, imgui.GetColorU32(color), 2 * scale);
    draw:AddRect({ x, y }, { x + width, y + height },
        imgui.GetColorU32({ 0.85, 0.60, 0.92, 0.50 }), 2 * scale, 0, 1);
    local label_size = imgui.CalcTextSize(label);
    draw:AddText({ x + (width - label_size) / 2, y + 4 * scale }, imgui.GetColorU32(colors.header), label);
    local value_text = tostring(value);
    local value_size = imgui.CalcTextSize(value_text);
    draw:AddText({ x + (width - value_size) / 2, y + 22 * scale }, imgui.GetColorU32(colors.value), value_text);
    imgui.InvisibleButton(('##charactersheet_gi_%s'):format(id), { width, height });
end

local function row(entries, row_id, scale, cell_width)
    for index, entry in ipairs(entries) do
        if (index > 1) then imgui.SameLine(0, 0); end
        cell(entry[1], entry[2], entry[3], ('%s_%d'):format(row_id, index), scale, cell_width);
    end
end

local function draw_grid(snapshot, scale, cell_width, show_dw)
    row({
        { 'G-Haste', format_number(snapshot.gear_haste, true), colors.red },
        { 'M-Haste', format_number(snapshot.magic_haste, true), colors.red },
        { 'JA-Haste', format_number(snapshot.ja_haste, true), colors.red },
        { 'Total', format_number(snapshot.total_haste, true), colors.red },
    }, 'haste', scale, cell_width);
    row({
        { 'DT', format_number(snapshot.dt, true), colors.purple },
        { 'PDT', format_number(snapshot.pdt, true), colors.purple },
        { 'MDT', format_number(snapshot.mdt, true), colors.purple },
        { 'BDT', format_number(snapshot.bdt, true), colors.purple },
    }, 'dt', scale, cell_width);
    row({
        { 'TP/swing', format_number(snapshot.tp), colors.blue },
        { 'X-hit', format_number(snapshot.xhit), colors.blue },
        { 'Acc.', format_number(snapshot.accuracy), colors.blue },
        { 'Att.', format_number(snapshot.attack), colors.blue },
    }, 'offense', scale, cell_width);
    row({
        { 'Eva.', format_number(snapshot.evasion), colors.blue },
        { 'Def.', format_number(snapshot.defense), colors.blue },
        { 'STP', format_number(snapshot.stp), colors.green },
        { 'UGS', 'true', colors.purple },
    }, 'utility', scale, cell_width);
    if (show_dw) then
        row({
            { 'DW', format_number(snapshot.dw), colors.orange },
            { 'DW Need', format_number(snapshot.dw_needed), colors.orange },
            { 'MA', format_number(snapshot.ma), colors.orange },
            { 'Delay Cap', snapshot.total_haste >= 80 and 'true' or 'false',
                snapshot.total_haste >= 80 and colors.green or colors.orange },
        }, 'delay', scale, cell_width);
    end
end

function M.initialize(config, save_callback)
    state.settings = T(config or {}):merge(M.defaults);
    state.save = save_callback or function() end;
    state.first_position = true;
    engine.invalidate();
    return state.settings;
end

function M.handle_packet(e)
    engine.handle_packet(e);
end

function M.invalidate()
    engine.invalidate();
end

function M.toggle()
    state.settings.visible[1] = not state.settings.visible[1];
    state.save();
    return state.settings.visible[1];
end

function M.set_visible(value)
    state.settings.visible[1] = value == true;
    state.save();
end

function M.toggle_lock()
    state.settings.locked[1] = not state.settings.locked[1];
    state.save();
end

function M.toggle_dw()
    state.settings.show_dw[1] = not state.settings.show_dw[1];
    state.save();
end

function M.set_scale(value)
    state.settings.scale[1] = math.max(0.6, math.min(2.0, tonumber(value) or 1));
    state.save();
end

function M.set_width(value)
    state.settings.cell_width[1] = math.max(68, math.min(140, tonumber(value) or 76));
    state.save();
end

function M.reset()
    state.settings.position[1], state.settings.position[2] = 680, 450;
    state.settings.scale[1], state.settings.cell_width[1] = 1.0, 76;
    state.first_position = true;
    state.save();
end

function M.render()
    if (state.settings == nil or not enabled(state.settings.visible)) then return; end
    local now = os.clock();
    if (now >= state.last_update + scalar(state.settings.interval, 0.25)) then
        state.last_update = now;
        state.snapshot = engine.snapshot();
    end
    if (state.snapshot == nil) then return; end

    local scale = math.max(0.6, math.min(2.0, scalar(state.settings.scale, 1.0)));
    local cell_width = math.max(68, math.min(140, scalar(state.settings.cell_width, 76)));
    if (state.first_position) then
        imgui.SetNextWindowPos({ state.settings.position[1], state.settings.position[2] }, ImGuiCond_Once);
        state.first_position = false;
    end
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 0, 0 });
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.04, 0.02, 0.08, 0.72 });
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoFocusOnAppearing);
    if (enabled(state.settings.locked)) then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs);
    end
    if (imgui.Begin('GearInfo##charactersheet_gearinfo', nil, flags)) then
        if (imgui.SetWindowFontScale ~= nil) then imgui.SetWindowFontScale(scale); end
        draw_grid(state.snapshot, scale, cell_width, enabled(state.settings.show_dw));
        local x, y = imgui.GetWindowPos();
        if (not enabled(state.settings.locked)) then
            state.settings.position[1], state.settings.position[2] = x, y;
        end
    end
    imgui.End();
    imgui.PopStyleColor(1);
    imgui.PopStyleVar(2);
end

return M;
