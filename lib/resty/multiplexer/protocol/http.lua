local re = ngx.re
return {
    required_bytes = 8,
    check = function(buf)
        return re.match(buf, "^(GET|PUT|POST|HEAD|PATCH|TRACE|DELETE|CONNECT|OPTIONS) ", "jo")
    end
}