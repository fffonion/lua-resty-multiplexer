-- a matcher that matches the client host
local _M = {}

function _M.match(protocol, expected)
    return ngx.var.remote_addr == expected
end

return _M