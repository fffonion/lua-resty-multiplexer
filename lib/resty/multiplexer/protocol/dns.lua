local sub = string.sub
local byte = string.byte
local band = bit.band
local bor = bit.bor
local rshift = bit.rshift
 
return {
    required_bytes = 14,
    check = function(buf)
        -- https://www.ietf.org/rfc/rfc1035.txt
        -- https://www.ietf.org/rfc/rfc2065.txt
        --[[
                                          1  1  1  1  1  1
            0  1  2  3  4  5  6  7  8  9  0  1  2  3  4  5
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |                      ID                       |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |QR|   Opcode  |AA|TC|RD|RA| Z|AD|CD|   RCODE   |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |                    QDCOUNT                    |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |                    ANCOUNT                    |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |                    NSCOUNT                    |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
          |                    ARCOUNT                    |
          +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
        ]]
        local is_dns = false
        -- for tcp, first 2 bytes are length
        local offset = 2
        while true do
            offset = offset + 3 -- 3
            -- 2bytes ID, no signature
            local byte_3 = byte(buf, offset)
            -- 1bit QR = 0
            if band(rshift(byte_3, 7), 0x1) ~= 0 then
                break
            end
            -- 4bit Opcode = 0, 1, 2, 4, 5
            local Opcode = band(rshift(byte_3, offset), 0xf)
            if Opcode == 3 or Opcode > 5 then
                break
            end
            offset = offset + 1 -- 4
            -- 1bit x 3 AA, TC, RD no signature
            local byte_4 = byte(buf, offset)
            -- 1bit RA, no signature
            -- 1bit Z = 0
            -- 1bit AD, no signature
            -- 1bit CD, no signature
            -- 4bit RCODE = 0
            -- mask: 0b01001111 = 0x4f
            if band(byte_4, 0x4f) ~= 0 then
                break
            end
            offset = offset + 1 -- 5
            -- 16bit QDCOUNT > 0
            if byte(buf, offset) == 0 and byte(buf, offset + 1) == 0 then
                break
            end
            offset = offset + 2 -- 7
            -- 16bit x 3 ANCOUNT, NSCOUNT
            for i = offset, offset + 3, 1 do
                if byte(buf, i) ~= 0 then
                    is_dns = false
                    break
                end
                is_dns = true
            end
            -- ARCOUNT can be bigger than 0
            break
        end
        return is_dns
    end
}