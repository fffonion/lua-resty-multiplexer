local match = ngx.re.match
return {
    required_bytes = 50,
    check = function(buf)
        return match(buf, "jabber", "jo")
    end
}
