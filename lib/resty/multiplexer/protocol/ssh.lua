local sub = string.sub
return {
    required_bytes = 4,
    check = function(buf)
        return sub(buf, 1, 4) == "SSH-"
    end
}