-- a matcher that matches the protocol
local _M = {}

function _M.match(protocol, expected)
    return protocol == expected
end

return _M