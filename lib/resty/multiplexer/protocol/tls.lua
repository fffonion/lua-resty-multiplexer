local sub = string.sub
local byte = string.byte
local lshift = bit.lshift

-- local timestamp_threshold = 3600 -- 1 hour is long enough

return {
    required_bytes = 16,
    check = function(buf)
        -- SSL3.0 https://www.ietf.org/rfc/rfc6101.txt
        -- TLS1.0 https://www.ietf.org/rfc/2246.txt
        -- TLS1.1 https://www.ietf.org/rfc/4346.txt
        -- TLS1.2 https://www.ietf.org/rfc/5246.txt
        -- TLS1.3 https://tools.ietf.org/html/draft-ietf-tls-tls13-20
        -- probe ClientHello only
        --[[
                                          1  1  1  1  1  1
            0  1  2  3  4  5  6  7  8  9  0  1  2  3  4  5
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |      Content Type     |     Version(major)    |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |     Version(minor)    |    Length (15..8)     |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |     Length (7..1)     |      Message Type     |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
        ]]
        local is_tls = false
        local offset = 0
        while true do
            offset = offset + 1 -- 1
            -- Start SSL/TLS protocol
            -- 1byte Content Type = 0x16 (Handshake)
            if byte(buf, offset) ~= 0x16 then
                break
            end
            offset = offset + 1 -- 2
            -- 1byte version(major) = 3
            -- 1byte version(minor) = 0, 1, 2, 3
            if byte(buf, offset) ~= 0x3 or byte(buf, offset + 1) > 3 then
                break
            end
            offset = offset + 2 -- 4
            -- 2byte Length
            offset = offset + 2 -- 6
            -- Start Handshake Message
            -- 1byte Message Type = 0x1 (ClientHello)
            if byte(buf, offset) ~= 0x1 then
                break
            end
            offset = offset + 1 -- 1
            --[[
            Bytes +0    |    +1     |     +2    |    +3     |
            +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
            |         Handshake Length          | Ver.major |
            +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
            | Ver.minor |      Timestamp  (63..16)          |
            +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
            | (15..0)   |                                   |
            +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
            ]]
            -- 3byte Message Length
            offset = offset + 3 -- 4
            -- 1byte version(major) = 3
            -- 1byte version(minor) = 0, 1, 2, 3
            if byte(buf, offset) ~= 0x3 or byte(buf, offset + 1) > 3 then
                break
            end
            offset = offset + 2 -- 6
            -- Random bytes
            -- 4byte Unix timestamp, modern ssl library doesn't expose epoch in random bytes
            --[[if ngx.time() - lshift(byte(buf, offset), 24) - lshift(byte(buf, offset + 1), 16) - 
                lshift(byte(buf, offset + 2), 8) - byte(buf, offset + 3) > timestamp_threshold then
                break
            end]]
            -- End Handshake Message
            -- End SSL/TLS protocol
            is_tls = true
            break
        end
        return is_tls
    end
}