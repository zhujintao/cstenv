--
--Author: Top Zhu <t@taotao.me>
--Update: Tue Jul 18 19:23:34 CST 2017
--Ver: 0.1.2
--
if not ngx.var.envs then

local abgrayfile = io.open("etc/abgray.ini")
if not abgrayfile then
   return
end

inifile = require("inifile")
abconf=inifile.parse("etc/abgray.ini")

if abconf['outside']['path'] and io.open(abconf['outside']['path']) then
      abconf=inifile.parse(abconf['outside']['path'])
end

local field =abconf['ab-cookie']['field']
local value =abconf['ab-cookie']['value']
local wsdir =abconf['ab-cookie']["wsdir"]

local pvalue =abconf["pre"]["value"]
local pwsdir =abconf["pre"]["wsdir"]

if field ~= nil and value ~= nil and  wsdir ~= nil then 
if ngx.var["cookie_" .. field] then 
if ngx.re.find(value, "," .. ngx.var["cookie_" .. field] .. ",") then

if abconf["pre"]["target"] == field then 
if pvalue ~= nil then	
if pvalue == "*" or ngx.re.find(pvalue,ngx.var.remote_addr .. ",") then
   ngx.var.wsdir=pwsdir
   return 		
end	
end
end
   ngx.var.wsdir=wsdir
   return  
end
end
end

if pvalue == nil or pwsdir == nil then return end
if abconf["pre"]["target"] == field and field then
if ngx.var["cookie_" .. field] then
if pvalue == "*" or ngx.re.find(pvalue,ngx.var.remote_addr .. ",") then
   ngx.var.wsdir=pwsdir
   return
end
end
end

if abconf["pre"]["target"] == nil then
if pvalue == "*" or ngx.re.find(pvalue,ngx.var.remote_addr .. ",") then
   ngx.var.wsdir=pwsdir
   return
end
end


end

if not ngx.var.http_host then
   return
end
local file = io.open("envs/" .. ngx.var.http_host)
if not file then
   return
end
local root = file:read("*l")
file:close()
ngx.var.domain= ngx.var.http_host
ngx.var.wsdir= root

