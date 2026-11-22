-- Run with bundled mpv.com --no-config --vo=null --ao=null --idle=yes --script=tests/player-navigation.lua
local mp=require 'mp'
local quit=mp.commandv
local ok,err=pcall(function()
 local messages,events,timers,commands={},{},{},{}
 local clock=10
 local viewportWidth,viewportHeight=1280,720
 local osdOverlays={}
 local properties={duration=120,['time-pos']=20,pause=false,['mouse-pos']={hover=true},['track-list']={{id=1,type='audio',title='Português'},{id=2,type='audio',title='Inglês'}},aid='1'}
 mp.get_time=function()return clock end
 mp.get_osd_size=function()return viewportWidth,viewportHeight end
 mp.get_mouse_pos=function()return 640,360 end
 mp.get_property_native=function(name,default)if properties[name]==nil then return default,default==nil and "property unavailable"or nil end;return properties[name]end
 mp.get_property_number=function(name,default)return tonumber(properties[name])or default or 0 end
 mp.get_property_bool=mp.get_property_native
 mp.get_property=function(name,default)if name=='path'then return 'test.mkv'end;return properties[name]or default end
 mp.set_property_native=function(name,value)properties[name]=value end
 mp.set_property_number=mp.set_property_native;mp.set_property_bool=mp.set_property_native;mp.set_property=mp.set_property_native
 mp.register_script_message=function(name,fn)messages[name]=fn end
 mp.register_event=function(name,fn)events[name]=events[name]or {};table.insert(events[name],fn)end
 mp.observe_property=function()end
 mp.add_hook=function()end
 mp.add_periodic_timer=function(_,fn)timers[#timers+1]=fn;return {kill=function()end,resume=function()end}end
 mp.add_timeout=function()return {kill=function()end,resume=function()end}end
 mp.add_forced_key_binding=function()end;mp.add_key_binding=function()end
 mp.create_osd_overlay=function()local overlay={update=function()end,remove=function()end};osdOverlays[#osdOverlays+1]=overlay;return overlay end
 mp.command_native=function()return {}end
 properties['user-data/fua-lite']='true'
 local people={};for i=1,18 do people[i]={id=i,name='Ator '..i}end
 mp.command_native_async=function(request,fn)
  assert(not request.args[1]:find('node.exe',1,true) and not request.args[1]:find('CastArtwork',1,true) and not request.args[1]:find('EpisodeArtwork',1,true),'Lite must not start library helpers')
  local data=request.args[1]:find('CastArtwork',1,true)and {cast=people}or {episodes={{id='episode1',title='E01 · Primeiro',current=true},{id='episode2',title='E02 · Segundo'},{id='episode3',title='E03 · Terceiro'}}}
  fn(true,{status=0,stdout=require('mp.utils').format_json(data)})
 end
 mp.commandv=function(name,...)
  local args={...};commands[#commands+1]={name,...}
  if name=='seek'then properties['time-pos']=args[2]=='relative+exact'and properties['time-pos']+tonumber(args[1])or tonumber(args[1])end
  if name=='cycle'and args[1]=='pause'then properties.pause=not properties.pause end
  if name=='script-message'and messages[args[1]]then messages[args[1]](unpack(args,2))end
 end
 local function count(name)local n=0;for _,c in ipairs(commands)do if c[1]==name then n=n+1 end end;return n end
 local function event(name)for _,fn in ipairs(events[name]or {})do fn()end end
 local function key(value)messages['fua-player-key'](value)end
 local function advance(seconds)clock=clock+seconds;for _,fn in ipairs(timers)do fn()end end
 local function state()return properties['user-data/fua-player-navigation']end
 local flags=dofile('app/fua-native/track-flags.lua')
 assert(flags.country({lang='pt-BR'})=='br'and flags.country({lang='pt-PT'})=='pt','Portuguese flags respect the region')
 assert(flags.country({lang='eng'})=='us'and flags.country({lang='jpn'})=='jp','Three-letter language codes map to flags')
 assert(flags.country({lang='zh-Hant'})=='tw'and flags.country({lang='es-419'})=='mx','Script and regional language variants map correctly')
 assert(flags.country({id='no'})==nil and flags.country({lang='und'})==nil,'Disabled or unknown languages do not invent a flag')
 dofile('app/fua-native/fua-ui.lua');event('start-file');event('file-loaded')
 properties['media-title']='""'
 key('Down');for _,overlay in ipairs(osdOverlays)do assert(not (overlay.data or ''):find('\\pos(78,40)',1,true),'Lite does not render an empty heading')end
 key('Down');key('Down');assert(state().row~='cast','Lite does not expose cast navigation')
 assert(not properties['user-data/fua-episode-menu-open'],'Lite does not expose episodes')
 key('Escape');assert(count('script-message')>0,'Escape reaches native host')
 event('start-file');event('file-loaded');key('Down')
 messages['fua-native-button'](tostring(40/1280),tostring(685/720),'down');messages['fua-native-button'](tostring(40/1280),tostring(685/720),'up')
 assert(state().menu=='main','Lite opens floating player menu')
 messages['fua-native-button'](tostring(80/1280),tostring(580/720),'down');messages['fua-native-button'](tostring(80/1280),tostring(580/720),'up')
 local opened=false;for _,c in ipairs(commands)do if c[1]=='script-message' and c[2]=='fua-host' and c[3]=='settings'then opened=true end end
 assert(opened,'Lite floating menu opens native settings')
end)
local f=assert(io.open('.deps/lite-ui.result','w'));f:write(ok and 'PASS: Lite menus and navigation without library helpers' or tostring(err));f:close();quit('quit',ok and '0' or '1')
