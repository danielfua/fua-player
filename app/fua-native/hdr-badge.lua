-- Source-format badge, independent of display output and RTX HDR.
local mp=require 'mp'
local utils=require 'mp.utils'
local root=utils.split_path(debug.getinfo(1,'S').source:gsub('^@',''))
local generation,shown,expires,asset=0,false,0,nil
local lastDraw=nil
local function clear()
 if shown then mp.commandv('overlay-remove',62);shown=false end;lastDraw=nil
end
local function format(video)
 local label=table.concat({tostring(video.HDR_Format or ''),tostring(video.HDR_Format_Compatibility or ''),tostring(video.HDR_Format_Commercial or '')},' '):lower()
 local transfer=tostring(video.transfer_characteristics or ''):lower()
 if label:find('hdr10+',1,true) or label:find('2094%-40') then return 'hdr10plus' end
 if label:find('hdr10',1,true) or label:find('2086',1,true) then return 'hdr10' end
 if transfer:find('2084',1,true) or transfer:find('pq',1,true) or transfer:find('hlg',1,true) or transfer:find('arib',1,true) or label:find('dolby vision',1,true) then return 'hdr' end
end
local function render()
 if not asset then clear();return end
 local now=mp.get_time();local opening=now<=expires
 local fade=opening and math.max(0,math.min(12,math.ceil((expires-now)/.4*12))) or 12
 if not opening and not mp.get_property_native('user-data/fua-controls-visible') then clear();return end
 local w,h=mp.get_osd_size();if w<=0 or h<=0 then return end
 local scale=h/720
 local badgeHeight=(opening and (asset.kind=='hdr10plus' and 18 or 26) or (asset.kind=='hdr10plus' and 15 or 20))*scale
 local dh=math.max(1,math.floor(badgeHeight));local dw=math.max(1,math.floor(asset.width*dh/asset.height))
 local x=opening and (w-dw-85*scale) or (w-(355+(mp.get_property_native('user-data/fua-episodes-available') and 44 or 0))*scale-dw)
 local y=opening and (49*scale-dh/2) or (h-(35+mp.get_property_number('user-data/fua-bottom-lift',0))*scale-dh/2)
 local image=fade<12 and (asset.prefix..'.fade'..fade..'.bgra') or asset.file
 local signature=table.concat({image,w,h,dw,dh,math.floor(x),math.floor(y),opening and 'top' or 'bottom'},':');if lastDraw==signature then return end;lastDraw=signature
 mp.command_native({name='overlay-add',id=62,x=math.max(0,math.floor(x)),y=math.max(0,math.floor(y)),file=image,offset=0,fmt='bgra',w=asset.width,h=asset.height,stride=asset.width*4,dw=dw,dh=dh})
 shown=true
end
mp.register_event('start-file',function()generation=generation+1;asset=nil;clear()end)
mp.register_event('file-loaded',function()
 local token=generation;local file=mp.get_property('path');if not file then return end
 mp.command_native_async({name='subprocess',args={utils.join_path(root,'MediaProbe.exe'),file},playback_only=true,capture_stdout=true,capture_stderr=true},function(ok,result)
  if token~=generation or not ok or not result or result.status~=0 then return end
  local data=utils.parse_json((result.stdout or ''):gsub('^\239\187\191',''));if not data then return end
  local kind
  for _,track in ipairs((data.media or {}).track or {})do if track['@type']=='Video' then kind=format(track);break end end
  if not kind then return end
  local prefix=utils.join_path(root,'hdr-badges/'..kind..(kind=='hdr10plus' and '-clean' or ''));local f=io.open(prefix..'.json','r');if not f then return end
  asset=utils.parse_json(f:read('*a'));f:close();if not asset then return end
  asset.kind=kind;asset.prefix=prefix;asset.file=prefix..'.bgra';expires=mp.get_time()+5;render()
 end)
end)
mp.observe_property('user-data/fua-controls-visible','bool',render)
mp.observe_property('osd-dimensions','native',render)
mp.observe_property('user-data/fua-bottom-lift','number',render)
mp.add_periodic_timer(1/30,render)
mp.register_event('shutdown',clear)
