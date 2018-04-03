--
----Author: Top Zhu <t@taotao.me>
----
--

local wl=false
local f=io.open("etc/urlwl.ini","r")

if f then
for line in f:lines() do
local m,err =ngx.re.match(line, "(.+):(.+)")
if m then
if not ngx.re.find(m[1],'\\*') then m[1] = m[1] .. "$"  end
if ngx.re.find(ngx.var.uri ,m[1]) then
if m[2]  == "*" or ngx.re.find(m[2],ngx.var.remote_addr .. ",") then
   wl=true
   break
end
end
end
end
end
f:close()

if wl ~= true then
local random = ngx.var.cookie_cstenvR
if (random == nil) then
   return ngx.redirect("/auth?url=" .. ngx.var.request_uri)
end

local token = ngx.md5("t@taotao.me" .. ngx.var.remote_addr .. random)
if (ngx.var.cookie_cstenvT ~= token) then
   return ngx.redirect("/auth?url=".. ngx.var.request_uri)
end
end
