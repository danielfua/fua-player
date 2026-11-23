local mp=require 'mp'
local quit=mp.commandv
local ok,err=pcall(function()
 local utils=require 'mp.utils'
 local events,observers,requests,draws={},{},{},{}
 local w,h,visible=1920,1080,true
 mp.get_osd_size=function()return w,h end
 mp.get_property_native=function()return visible end
 mp.get_property_number=function()return 0 end
 mp.get_property=function()return 'test.mkv'end
 mp.register_event=function(n,f)events[n]=f end
 mp.observe_property=function(n,t,f)observers[n]=f end
 mp.commandv=function()end
 mp.command_native=function(c)draws[#draws+1]=c end
 mp.command_native_async=function(c,f)requests[#requests+1]={c=c,f=f}end
 local function finish(i,value)requests[i].f(true,{status=0,stdout=utils.format_json(value)})end
 dofile('app/fua-native/title-artwork.lua')
 events['start-file']();events['file-loaded']()
 finish(1,{file='source.bgra',width=500,height=124})
 local r=requests[2].c.args
 assert(r[2]=='--resize' and tonumber(r[6])==229,'1080p prepares the final bitmap width')
 finish(2,{file='1080.bgra',width=tonumber(r[6]),height=tonumber(r[7])})
 local d=draws[#draws];assert(d.w==d.dw and d.h==d.dh and d.stride==d.w*4,'Overlay draws one source pixel per screen pixel')
 w,h=3840,2160;observers['osd-dimensions']()
 r=requests[3].c.args;assert(tonumber(r[6])==459,'4K keeps proportional logo size')
 visible=false;finish(3,{file='4k.bgra',width=tonumber(r[6]),height=tonumber(r[7])})
 assert(#draws==1,'Late resize never reveals hidden controls')
 visible=true;observers['user-data/fua-controls-visible']();assert(draws[#draws].file=='4k.bgra','Prepared image is reused')
 w,h=1280,720;observers['osd-dimensions']();r=requests[4].c.args
 events['start-file']();finish(4,{file='stale.bgra',width=tonumber(r[6]),height=tonumber(r[7])})
 assert(draws[#draws].file=='4k.bgra','Previous content cannot restore a stale logo')
end)
local f=io.open('.deps/title-artwork.result','w');f:write(ok and 'PASS: title logo resampling, 1080p/4K, visibility and stale callbacks' or tostring(err));f:close();quit('quit',ok and '0' or '1')

