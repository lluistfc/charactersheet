local ffi = require('ffi');

ffi.cdef[[
    int MultiByteToWideChar(uint32_t CodePage, uint32_t dwFlags, char* lpMultiByteStr, int cbMultiByte, wchar_t* lpMultiByteStr, int32_t cchWideChar);
    int WideCharToMultiByte(uint32_t CodePage, uint32_t dwFlags, wchar_t* lpWideCharStr, int32_t cchWideChar, char* lpMultiByteStr, int32_t cbMultiByte, const char* lpDefaultChar, bool* lpUsedDefaultChar);
]]

local exports = {};
local cache = {};

function exports.shiftjis_to_utf8(value)
    local input = tostring(value or '');
    if (input == '') then return input; end
    if (cache[input] ~= nil) then return cache[input]; end

    local input_length = #input;
    local input_buffer = ffi.new('char[?]', input_length + 1);
    ffi.copy(input_buffer, input);

    local wide_length = ffi.C.MultiByteToWideChar(932, 0, input_buffer, -1, nil, 0);
    if (wide_length <= 0) then return input; end
    local wide_buffer = ffi.new('wchar_t[?]', wide_length);
    ffi.C.MultiByteToWideChar(932, 0, input_buffer, -1, wide_buffer, wide_length);

    local output_length = ffi.C.WideCharToMultiByte(65001, 0, wide_buffer, -1, nil, 0, nil, nil);
    if (output_length <= 0) then return input; end
    local output_buffer = ffi.new('char[?]', output_length);
    ffi.C.WideCharToMultiByte(65001, 0, wide_buffer, -1, output_buffer, output_length, nil, nil);

    local output = ffi.string(output_buffer);
    cache[input] = output;
    return output;
end

return exports;
