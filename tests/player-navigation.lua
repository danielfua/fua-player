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
 local people={};for i=1,18 do people[i]={id=i,name='Ator '..i}end
 mp.command_native_async=function(request,fn)
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
 -- Native brightness updates arrive asynchronously; the mouse target must stay visible.
 properties.brightness=-2;properties['user-data/fua-hdr-xp-brightness-offset']='-2'
 messages['fua-open-image']()
 messages['fua-native-button'](tostring(281.5/1280),tostring(213/720),'down')
 local function showsBrightness50()for _,overlay in ipairs(osdOverlays)do if overlay.data and overlay.data:find('+50',1,true)then return true end end;return false end
 assert(showsBrightness50(),'Mouse click displays the selected brightness before native acknowledgement')
 properties.brightness=18;advance(.1)
 assert(showsBrightness50(),'Delayed earlier values must not bounce the thumb back')
 properties.brightness=48;advance(.1)
 local brightnessRequests=0;for _,command in ipairs(commands)do if command[3]=='brightness-base:50'then brightnessRequests=brightnessRequests+1 end end
 messages['fua-native-button'](tostring(281.5/1280),tostring(213/720),'up')
 local afterRelease=0;for _,command in ipairs(commands)do if command[3]=='brightness-base:50'then afterRelease=afterRelease+1 end end
 assert(afterRelease==brightnessRequests,'Releasing a stationary brightness click must not reapply the same adjustment')
 assert(showsBrightness50(),'Mouse release preserves the selected target')
 properties.brightness=48;advance(.1);assert(showsBrightness50(),'Native acknowledgement settles at the same target')
 properties.brightness=0;properties['user-data/fua-hdr-xp-brightness-offset']='0';event('start-file');event('file-loaded')
 local seekBefore=count('seek')
 messages['fua-native-button']('0.6',tostring((720-76)/720),'down')
 assert(count('seek')==seekBefore+1,'A timeline click seeks on press')
 messages['fua-native-button']('0.6',tostring((720-76)/720),'up')
 assert(count('seek')==seekBefore+1,'Releasing a stationary timeline click must not seek twice')
 messages['fua-native-button']('0.6',tostring((720-76)/720),'down')
 messages['fua-native-button']('0.7',tostring((720-76)/720),'up')
 assert(count('seek')==seekBefore+3,'A dragged timeline still applies its different final position')
 commands={};properties['time-pos']=20;event('start-file');event('file-loaded')
 key('Right');key('Right');assert(properties.pause==false,'Seeking keeps running playback playing')
 assert(properties['time-pos']==30 and count('seek')==2,'Each arrow seeks five seconds immediately')
 assert(state().pending==-1,'No seek waits for confirmation')
 advance(5.1);assert(not properties['user-data/fua-controls-visible'],'Controls hide after five seconds')
 assert(count('seek')==2,'Timeout does not trigger another seek')
 key('Up');assert(state().pinned and properties['user-data/fua-controls-visible'],'Up pins the bar')
 advance(9);assert(properties['user-data/fua-controls-visible'],'Pinned bar remains visible')
 key('Enter');assert(properties.pause==true and count('seek')==2,'OK toggles playback without a second seek')
 key('Up');assert(not properties['user-data/fua-controls-visible'],'Up again hides the bar')
 key('Left');assert(properties['time-pos']==25 and properties.pause==true,'Paused video follows seeking and stays paused')
 key('Down');assert(state().row=='icons'and state().focus=='playback','Down enters the bottom icons')
 key('Right');assert(state().focus=='↷','Left/right move among bottom icons without changing volume')
 key('Down');assert(state().row=='cast'and properties['user-data/fua-cast-open'],'Next Down opens cast')
 key('Right');assert(state().row=='cast','Cast navigation must stay in cast')
 key('Up');assert(state().row=='timeline'and state().pinned,'Up never focuses header buttons')
 key('Up');key('Down');key('Down')
 -- Reach audio without activating any other icon.
 for i=1,5 do key('Left')end
 assert(state().focus=='♫','Audio icon must be reachable')
 key('Enter');assert(properties['user-data/fua-track-menu'],'OK opens audio menu')
 key('Down');assert(properties.aid=='1','Browsing menu choices must not apply them')
 key('Enter');assert(properties.aid=='2','OK applies selected audio')
 -- Generic menu and image sliders must also wait for OK.
 key('Left');key('Enter');assert(state().menu=='main','Main menu opens with OK')
 for i=1,3 do key('Down')end;key('Enter');assert(state().menu=='image','Image submenu is reachable')
 key('Right');assert(properties.contrast==nil,'Slider browsing must wait for confirmation')
 key('Enter');assert(properties.contrast==1,'OK applies slider draft')
 key('PageDown');assert(properties['user-data/fua-episode-menu-open'],'PgDn opens episodes: available='..tostring(properties['user-data/fua-episodes-available'])..' menu='..tostring(state().menu))
 for _,c in ipairs(commands)do assert(c[3]~='episode:episode2','Browsing must not start an episode')end
 key('Enter');local opened=false;for _,c in ipairs(commands)do if c[3]=='episode:episode2'then opened=true end end;assert(opened,'OK starts selected episode')
 key('PageDown');key('PageUp');key('Enter')
 local unexpected=false;for _,c in ipairs(commands)do if c[3]=='episode:episode3'then unexpected=true end end;assert(not unexpected,'PgUp/PgDn browse without automatic playback')
 key('Escape');assert(commands[#commands][3]=='library','Escape returns directly to library')
 event('start-file');viewportWidth=960;viewportHeight=720
 key('Down');key('Down');for i=1,3 do key('Right')end
 key('Enter');assert(state().menu=='speed','Speed opens its selection menu')
 local scaled=false;for _,overlay in ipairs(osdOverlays)do if overlay.res_x==1280 and overlay.res_y==960 then scaled=true end end;assert(scaled,'4:3 keeps a wider logical canvas to scale controls proportionally')
 key('Down');assert(properties.speed==nil,'Browsing speeds waits for OK')
 key('Enter');assert(properties.speed==.5,'OK confirms speed')
 messages['fua-native-wheel'](tostring((1280-312-(properties['user-data/fua-episodes-available']and 46 or 0))/1280),tostring((960-35)/960),'120')
 assert(properties.speed==.75,'Mouse wheel changes speed at scaled icon coordinates')
 key('Right');key('Right');key('Enter');assert(state().menu=='','HDR XP cycles without opening a floating menu')
 assert(commands[#commands][3]=='hdr-xp','OK invokes the HDR XP cycle')
 event('start-file');assert(loadfile('app/fua-native/player-navigation.lua'))
end)
local result=assert(io.open('.deps/player-navigation.result','w'));result:write(ok and 'PASS: immediate relative seeking, paused-state preservation, five-second timeout, pin/hide, icon/cast rows, menus, slider confirmation, episodes, Escape, responsive 4:3 and speed menu/wheel' or tostring(err));result:close()
quit('quit',ok and 0 or 1)
