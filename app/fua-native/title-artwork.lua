local mp=require 'mp'
local utils=require 'mp.utils'
local root=utils.split_path(debug.getinfo(1,'S').source:gsub('^@',''))
local art,serial,shown,last=nil,0,false,nil
local function clear()if shown then mp.commandv('overlay-remove',63);shown=false end;last=nil end
local scaled,pending={},{}
local render
render=function()
 if not art or not mp.get_property_native('user-data/fua-controls-visible')then clear();return end
 local w,h=mp.get_osd_size();if w<=0 or h<=0 then clear();return end
 local scale=math.min(h/720,w/1280);local left=390;local right=w/scale/2-90;local available=right-left;if available<45 then clear();return end
 local factor=math.min(math.min(190,available)/art.width,38/art.height)*scale
 local dw,dh=math.max(1,math.floor(art.width*factor)),math.max(1,math.floor(art.height*factor))
 local size=dw..'x'..dh
 local image=scaled[size]
 if not image then
  clear()
  if not pending[size] then
   pending[size]=true;local token=serial
   mp.command_native_async({name='subprocess',args={utils.join_path(root,'TitleArtwork.exe'),'--resize',art.file,tostring(art.width),tostring(art.height),tostring(dw),tostring(dh)},playback_only=true,capture_stdout=true,capture_stderr=true},function(ok,result)
    if token~=serial then return end
    pending[size]=nil
    if not ok or not result or result.status~=0 then return end
    local value=utils.parse_json(result.stdout or '')
    if value and value.file and value.width==dw and value.height==dh then scaled[size]=value;render()end
   end)
  end
  return
 end
 local lift=mp.get_property_number('user-data/fua-bottom-lift',0)
 local key=w..':'..h..':'..lift;if last==key then return end;last=key
 mp.command_native({name='overlay-add',id=63,x=math.floor((left*scale+right*scale-dw)/2),y=math.floor(h-(35+lift)*scale-dh/2),file=image.file,offset=0,fmt='bgra',w=dw,h=dh,stride=dw*4,dw=dw,dh=dh});shown=true
end
mp.register_event('start-file',function()serial=serial+1;art=nil;scaled={};pending={};clear()end)
mp.register_event('file-loaded',function()
 local file=mp.get_property('path');if not file then return end;local token=serial
 mp.command_native_async({name='subprocess',args={utils.join_path(root,'TitleArtwork.exe'),file},playback_only=true,capture_stdout=true,capture_stderr=true},function(ok,result)
 if token~=serial or not ok or not result or result.status~=0 then return end
 local value=utils.parse_json(result.stdout or '');if value and value.file and value.width and value.height then art=value;render()end
 end)
end)
mp.observe_property('user-data/fua-controls-visible','bool',render)
mp.observe_property('osd-dimensions','native',render)
mp.observe_property('user-data/fua-bottom-lift','number',render)
mp.register_event('shutdown',clear)
