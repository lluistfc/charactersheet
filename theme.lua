local d3d = require('d3d8');
local ffi = require('ffi');
local imgui = require('imgui');

local M = {
    panel_texture = nil,
    panel_ptr = nil,
    reduce_texture = false,
    colors = {
        background = { 0.025, 0.040, 0.060, 0.97 },
        accent = { 0.93, 0.72, 0.34, 1.0 },
        muted = { 0.68, 0.74, 0.84, 1.0 },
        link = { 0.48, 0.76, 1.0, 1.0 },
        good = { 0.48, 0.92, 0.56, 1.0 },
        value = { 0.74, 0.84, 1.0, 1.0 },
    },
};

function M.configure(settings)
    local high_contrast = settings ~= nil and settings.high_contrast ~= nil and settings.high_contrast[1];
    M.reduce_texture = settings ~= nil and settings.reduce_texture ~= nil and settings.reduce_texture[1] or false;
    if (high_contrast) then
        M.colors.background = { 0.005, 0.008, 0.012, 1.0 };
        M.colors.accent = { 1.0, 0.82, 0.36, 1.0 };
        M.colors.muted = { 0.88, 0.91, 0.96, 1.0 };
        M.colors.link = { 0.45, 0.82, 1.0, 1.0 };
        M.colors.good = { 0.48, 1.0, 0.60, 1.0 };
        M.colors.value = { 0.86, 0.92, 1.0, 1.0 };
    else
        M.colors.background = { 0.025, 0.040, 0.060, 0.97 };
        M.colors.accent = { 0.93, 0.72, 0.34, 1.0 };
        M.colors.muted = { 0.68, 0.74, 0.84, 1.0 };
        M.colors.link = { 0.48, 0.76, 1.0, 1.0 };
        M.colors.good = { 0.48, 0.92, 0.56, 1.0 };
        M.colors.value = { 0.74, 0.84, 1.0, 1.0 };
    end
end

function M.initialize(panel_path)
    M.panel_texture = nil;
    M.panel_ptr = nil;
    if (panel_path == nil or not ashita.fs.exists(panel_path)) then return; end

    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    if (ffi.C.D3DXCreateTextureFromFileA(d3d.get_device(), panel_path, texture_ptr) ~= ffi.C.S_OK) then
        return;
    end

    M.panel_texture = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));
    M.panel_ptr = tonumber(ffi.cast('uint32_t', M.panel_texture));
end

local function draw_texture_rect(draw_list, x1, y1, x2, y2)
    if (x2 <= x1 or y2 <= y1) then return; end
    draw_list:AddImage(
        M.panel_ptr,
        { x1, y1 }, { x2, y2 },
        { 0, 0 }, { 1, 1 },
        imgui.GetColorU32({ 0.72, 0.78, 0.88, 0.72 })
    );
end

function M.draw_panel()
    local x, y = imgui.GetWindowPos();
    local width, height = imgui.GetWindowSize();
    local draw_list = imgui.GetWindowDrawList();
    draw_list:AddRectFilled({ x, y }, { x + width, y + height },
        imgui.GetColorU32(M.colors.background), 0, 0);
    if (M.panel_ptr == nil or M.reduce_texture) then
        draw_list:AddRect(
            { x + 1, y + 1 }, { x + width - 1, y + height - 1 },
            imgui.GetColorU32(M.colors.accent), 0, 0, 2.0);
        return;
    end
    draw_texture_rect(draw_list, x, y, x + width, y + height);
    draw_list:AddRect(
        { x + 1, y + 1 }, { x + width - 1, y + height - 1 },
        imgui.GetColorU32(M.colors.accent), 0, 0, 2.0);
    draw_list:AddRect(
        { x + 4, y + 4 }, { x + width - 4, y + height - 4 },
        imgui.GetColorU32({ 0.20, 0.14, 0.07, 0.90 }), 0, 0, 1.0);
end

function M.shutdown()
    M.panel_ptr = nil;
    M.panel_texture = nil;
end

return M;
