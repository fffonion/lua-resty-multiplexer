

local sub = string.sub
local byte = string.byte
local format = string.format
local tcp = ngx.socket.tcp
local setmetatable = setmetatable
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait


local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end


local _M = new_tab(0, 8)
_M._VERSION = '0.01'
_M.protocols = nil -- cached protocol modules
_M.matchers = nil -- cached matcher modules
_M.rules = nil -- user-definsed routing rules

local mt = { __index = _M }

function _M.load_protocols(...)
    local protocols = {...}
    if not #protocols then
        return
    end
    -- loaded modules
    local modules = new_tab(0, #protocols)
    -- the offset of bytes we want to stop and check the protocol
    local positions = new_tab(0, #protocols)
    for _, proto in pairs(protocols) do
        local status, ret = pcall(require, "resty.multiplexer.protocol." .. proto)
        if not status then
            ngx.log(ngx.ERR, format("[multiplexer] can't load protocol '%s': %s", proto, ret))
        elseif ret.required_bytes == nil or not type(ret.required_bytes) == "number" or ret.check == nil then
            ngx.log(ngx.ERR, format("[multiplexer] protocol module '%s' is malformed", proto))
        else
            -- merge protocol filters with same required_bytes
            if modules[ret.required_bytes] == nil then
                modules[ret.required_bytes] = {}
                positions[#positions + 1] = ret.required_bytes
            end
            local mrec = modules[ret.required_bytes]
            -- add protocol name for reference
            ret.name = proto

            mrec[#mrec + 1] = ret

            ngx.log(ngx.INFO, format("[multiplexer] protocol '%s' loaded", proto))
        end
    end

    if #positions == 0 then
        return
    end

    -- sort filters in ascending order of required_bytes
    table.sort(positions)
    _M.protocols = new_tab(#positions, 0)
    for _, k in ipairs(positions) do
        _M.protocols[#_M.protocols + 1] = {k, modules[k]}
    end

end

function _M.set_rules(...)
    local rules = {...}
    if not #rules then
        return
    end
    _M.rules = rules
    _M.matchers = new_tab(0, #rules)
    -- iterate all rules to cache matcher modules
    for _, rule in pairs(rules) do
        for i = 1, #rule - 2, 1 do
            local matcher = rule[i][1]
            if not _M.matchers[matcher] then
                local status, ret = pcall(require, "resty.multiplexer.matcher." .. matcher)
                if not status then
                    ngx.log(ngx.ERR, format("[multiplexer] can't load matcher '%s': %s", matcher, ret))
                else
                    _M.matchers[matcher] = ret
                    ngx.log(ngx.INFO, format("[multiplexer] matcher '%s' loaded", matcher))
                end
            end
        end
    end
end

-- syntax sugar to proxy matcher_config to matchers[MATCHER].config
_M.matcher_config = setmetatable({}, {
    __newindex = function(table, key, value)
        if _M.matchers[key] == nil then
            ngx.log(ngx.WARN, format("[multiplexer] try to set matcher config of '%s', which is not loaded", key))
            return
        end
        _M.matchers[key].config = value
    end
})

function _M.new(self, bufsize, timeout)
    local srvsock, err = tcp()
    if not srvsock then
        return nil, err
    end
    --srvsock:settimeout(timeout or 10000)
    
    local reqsock, err = ngx.req.socket()
    if not reqsock then
        return nil, err
    end
    --reqsock:settimeout(timeout or 10000)
    return setmetatable({
        srvsock = srvsock,
        reqsock = reqsock,
        exit_flag = false,
        server_name = nil,
        bufsize = bufsize or 1024
    }, mt)
end

local function _cleanup(self)
    -- make sure buffers are clean
    ngx.flush(true)

    local srvsock = self.srvsock
    local reqsock = self.reqsock
    if srvsock ~= nil then
        srvsock:shutdown("send")
        if srvsock.close ~= nil then
            local ok, err = srvsock:setkeepalive()
            if not ok then
                --
            end
        end
    end
    
    if reqsock ~= nil then
        reqsock:shutdown("send")
        if reqsock.close ~= nil then
            local ok, err = reqsock:close()
            if not ok then
                --
            end
        end
    end
    
end

local function probe(self)
    if _M.protocols == nil then
        return 0, nil, ""
    end
    local bytes_read = 0
    local buf = ''
    for _, v in pairs(_M.protocols) do
        ngx.log(ngx.INFO, "[multiplexer] check on position " .. v[1])
        -- read more bytes
        local new_buf, err = self.reqsock:receive(v[1] - bytes_read)
        -- concat buffer
        buf = buf .. new_buf
        -- check protocol
        for _, p in pairs(v[2]) do
            if p.check(buf) then
                return 0, p.name, buf
            end
        end
        -- update current read bytes position
        bytes_read = v[1]
    end
    return 0, nil, buf
end

local function _upl(self)
    -- proxy client request to server
    local buf, len, err, hd, _
    local rsock = self.reqsock
    local ssock = self.srvsock
    while true do
        buf, err, _ = rsock:receive("*p")
        if err then
            if ssock.close ~= nil then
                _, err = ssock:send(_)
            end
            break
        elseif buf == nil then
            break
        end

        _, err = ssock:send(buf)
        if err then
            break
        end
    end
end

local function _dwn(self)
    -- proxy response to client
    local buf, len, err, hd, _
    local rsock = self.reqsock
    local ssock = self.srvsock
    while true do
        buf, err, _ = ssock:receive("*p")
        if err then
            if rsock.close ~= nil then
                _, err = rsock:send(_)
            end
            break
        elseif buf == nil then
            break
        end
        
        _, err = rsock:send(buf)
        if err then
            break
        end
    end
end

function _M.run(self)
    while true do
        if _M.matchers == nil then
            ngx.log(ngx.ERR, "[multiplexer] no rule is defined")
            break
        end
        local code, protocol, buffer = probe(self)
        if code ~= 0 then
            ngx.log(ngx.INFO, "[multiplexer] cleaning up with an exit code ", code)
            break
        end
        ngx.log(ngx.INFO, format("[multiplexer] protocol:%s exit:%d", protocol, code))
        local upstream, port
        
        for _, v in pairs(_M.rules) do
            local is_match = false
            -- stop before last to elements of rules, which is server addr and port
            for i = 1, #v - 2, 1 do
                local m = _M.matchers[v[i][1]]
                if not m then
                    ngx.log(ngx.WARN, "[multiplexer] try to use a matcher '", v[i][1], "', which is not loaded ")
                elseif m.match(protocol, v[i][2]) then
                    is_match = true
                end
            end
            if is_match then
                upstream = v[#v - 1]
                port = v[#v]
                break
            end
        end
        if upstream == nil or port == nil then
            ngx.log(ngx.WARN, "[multiplexer] no matches found for this request")
            break
        end
        ngx.log(ngx.INFO, format("[multiplexer] selecting upstream: %s:%d", upstream, port, err))
        local ok, err = self.srvsock:connect(upstream, port)
        if not ok then
            ngx.log(ngx.ERR, format("[multiplexer] failed to connect to proxy upstream: %s:%s, err:%s", upstream, port, err))
            break
        end
        -- send buffer
        self.srvsock:send(buffer)
        
        wait(
            spawn(_upl, self),
            spawn(_dwn, self)
        )
        
        break
    end
    _cleanup(self)
    
end


return _M
