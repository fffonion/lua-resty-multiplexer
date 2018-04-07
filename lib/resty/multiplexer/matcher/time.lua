-- a matcher that matches time
local localtime = ngx.localtime
local sub = string.sub
local _M = {
    config = {
        year_match = {},
        year_not_match = {},
        month_match = {},
        month_not_match = {},
        day_match = {}, -- day of month
        day_not_match = {},
        -- dow_match = {}, -- day of weak
        -- dow_not_match = {},
        hour_match = {},
        hour_not_match = {},
        minute_match = {},
        minute_not_match = {},
        second_match = {},
        second_not_match = {},
    }
}

function _M.match(protocol, expected)
    local t = ngx.localtime()
    local tm = {
        year = tonumber(sub(t, 1, 4)),
        month = tonumber(sub(t, 6, 7)),
        day = tonumber(sub(t, 9, 10)),
        hour = tonumber(sub(t, 12, 13)),
        minute = tonumber(sub(t, 15, 16)),
        second = tonumber(sub(t, 18, 19))
    }
    local is_match = false
    for tm_k, tm_v in pairs(tm) do
        local nm = _M.config[tm_k .. "_not_match"]
        if nm and #nm > 0 then
            for _, r in ipairs(nm) do
                if tm_v == r[1] or (
                    r[2] ~= nil and tm_v > r[1] and tm_v < r[2]) then
                    return false
                end
            end
        end
        local m = _M.config[tm_k .. "_match"]
        if m and #m > 0 then
            for _, r in ipairs(m) do
                if tm_v == r[1] or (
                    r[2] ~= nil and tm_v > r[1] and tm_v < r[2]) then
                    is_match = true
                    break
                end
            end
        end
    end
    return is_match
end

return _M