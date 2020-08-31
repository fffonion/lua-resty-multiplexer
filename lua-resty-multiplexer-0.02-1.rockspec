package = "lua-resty-multiplexer"
version = "0.02-1"
source = {
   url = "git+ssh://git@github.com/fffonion/lua-resty-multiplexer.git",
   tag = "0.02"
}
description = {
   detailed = "lua-resty-multiplexer - Transparent port service multiplexer for stream subsystem ",
   homepage = "https://github.com/fffonion/lua-resty-multiplexer",
   license = "BSD",
}
build = {
   type = "builtin",
   modules = {
      ["resty.multiplexer.init"] = "lib/resty/multiplexer/init.lua",
      ["resty.multiplexer.matcher.client-host"] = "lib/resty/multiplexer/matcher/client-host.lua",
      ["resty.multiplexer.matcher.default"] = "lib/resty/multiplexer/matcher/default.lua",
      ["resty.multiplexer.matcher.protocol"] = "lib/resty/multiplexer/matcher/protocol.lua",
      ["resty.multiplexer.matcher.time"] = "lib/resty/multiplexer/matcher/time.lua",
      ["resty.multiplexer.protocol.dns"] = "lib/resty/multiplexer/protocol/dns.lua",
      ["resty.multiplexer.protocol.http"] = "lib/resty/multiplexer/protocol/http.lua",
      ["resty.multiplexer.protocol.ssh"] = "lib/resty/multiplexer/protocol/ssh.lua",
      ["resty.multiplexer.protocol.tls"] = "lib/resty/multiplexer/protocol/tls.lua",
      ["resty.multiplexer.protocol.xmpp"] = "lib/resty/multiplexer/protocol/xmpp.lua"
   }
}
