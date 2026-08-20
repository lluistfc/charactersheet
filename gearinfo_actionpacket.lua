-- Action packet parser adapted for Ashita v4's bit reader.
local actionpacket = {};

function actionpacket.parse(e)
    local data = e.data_raw;
    local offset = 40;
    local function bits(length)
        local value = ashita.bits.unpack_be(data, 0, offset, length);
        offset = offset + length;
        return value;
    end

    local packet = { };
    packet.actor_id = bits(32);
    local target_count = bits(6);
    offset = offset + 4;
    packet.category = bits(4);
    packet.param = bits(17);
    offset = offset + 15;
    packet.recast = bits(32);
    packet.targets = { };

    for i = 1, target_count do
        local target = { id = bits(32), actions = { } };
        local action_count = bits(4);
        for j = 1, action_count do
            local action = {
                reaction = bits(5), animation = bits(12), effect = bits(7),
                knockback = bits(3), param = bits(17), message = bits(10),
                flags = bits(31),
            };
            if (bits(1) == 1) then
                action.additional = { damage = bits(10), param = bits(17), message = bits(10) };
            end
            if (bits(1) == 1) then
                action.spikes = { damage = bits(10), param = bits(14), message = bits(10) };
            end
            target.actions[j] = action;
        end
        packet.targets[i] = target;
    end
    return packet;
end

return actionpacket;
