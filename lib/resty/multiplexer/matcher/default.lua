-- a matcher that matches everything
local _M = {}

function _M.match(protocol, expected)
    return true
end

return _M