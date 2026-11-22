local mp=require 'mp'
local assdraw=require 'mp.assdraw'
local overlay=mp.create_osd_overlay('ass-events')
local utils=require 'mp.utils'
local scriptDir=utils.split_path(debug.getinfo(1,'S').source:gsub('^@',''))
local liteValue=mp.get_property_native('user-data/fua-lite')
local isLite=liteValue==true or liteValue=='true' or liteValue=='yes'
local logoPath=utils.join_path(scriptDir,'fua-logo.bgra')
if not isLite then local ok,err=pcall(dofile,utils.join_path(scriptDir,'title-artwork.lua'));if not ok then mp.msg.warn(tostring(err))end end
local badgeLoaded,badgeError=pcall(dofile,utils.join_path(scriptDir,'hdr-badge.lua'));if not badgeLoaded then mp.msg.warn(tostring(badgeError))end
local noop=function()return false end
local episodePanel=isLite and {open=false,available=noop,active=noop,draw=noop,wheel=noop,click=noop,key=noop,focus=noop,toggle=noop} or dofile(utils.join_path(scriptDir,'episode-panel.lua'))
local trackFlags=dofile(utils.join_path(scriptDir,'track-flags.lua'))
local navigation
local menuZones,menuIndex,menuParent,menuDraft={},1,nil,{}
local function hdrXpActive()local value=mp.get_property_native('user-data/fua-hdr-xp');return value==true or value=='true' end
local logoKey=nil
local rtxLogoKey=nil
local rtxLogos={}
for _,state in ipairs({'on','off'})do
 local prefix=utils.join_path(scriptDir,'rtx-logos/'..state);local f=io.open(prefix..'.json','r')
 if f then local asset=utils.parse_json(f:read('*a'));f:close();if asset then asset.file=prefix..'.bgra';rtxLogos[state]=asset end end
end
local xpLogos={}
for _,state in ipairs({'on','off','minus1','minus2'})do
 local prefix=utils.join_path(scriptDir,'hdr-xp/'..state)
 local f=io.open(prefix..'.json','r')
 if f then local asset=utils.parse_json(f:read('*a'));f:close();if asset then asset.file=prefix..'.bgra';xpLogos[state]=asset end end
end
local shaderProfiles={{id='off',label='Desligado',short='A4K'},{id='A',label='Anime4K · A',short='A',file='Anime4K_ModeA.glsl'},{id='A+A',label='Anime4K · A+A',short='A+A',file='Anime4K_ModeA_A.glsl'},{id='B',label='Anime4K · B',short='B',file='Anime4K_ModeB.glsl'},{id='B+B',label='Anime4K · B+B',short='B+B',file='Anime4K_ModeB_B.glsl'},{id='C',label='Anime4K · C',short='C',file='Anime4K_ModeC.glsl'},{id='C+A',label='Anime4K · C+A',short='C+A',file='Anime4K_ModeC_A.glsl'}}
for _,profile in ipairs(shaderProfiles)do if profile.file then local f=io.open(utils.join_path(scriptDir,'shaders/'..profile.file),'r');if f then local header=f:read(8192);f:close();profile.version=header:match('Anime4K%-v([%d%.]+)')end end end
local shaderIndex=1
local function apply_shader(index)
 local profile=shaderProfiles[index];if not profile then return end
 local shaders={}
 if profile.file then
  local file=utils.join_path(scriptDir,'shaders/'..profile.file)
  if not utils.file_info(file)then mp.msg.error('Shader ausente: '..file);return end
  shaders[1]=file
 end
 local ok,err=pcall(mp.set_property_native,'glsl-shaders',shaders)
 if not ok then mp.msg.error('Shader: '..tostring(err));return end
 shaderIndex=index
 mp.set_property('user-data/fua-shader-profile',profile.id)
end
mp.register_script_message('fua-shader-select',function(id)for i,profile in ipairs(shaderProfiles)do if profile.id==id then apply_shader(i);return end end end)

local hdrLabel=''
local volumeFeedbackUntil=0
local visible=false
local hintAppearedAt=0
local dragging=false
local sliderDrag=nil
local menuKind=nil
local select_audio
local openTracks
local trackOffset,trackCursor=0,1
local trackChoices={}
local trackPageSize=12
local last=mp.get_time()
local previousX,previousY,previousHover=nil,nil,nil
local nativePointer=nil
local function pointer_position()
 if nativePointer then local w,h=mp.get_osd_size();return nativePointer.x*w,nativePointer.y*h end
 return mp.get_mouse_pos()
end
local function pointer_inside()
 if nativePointer then return nativePointer.inside end
 return (mp.get_property_native('mouse-pos') or {}).hover~=false
end
local zones={}
local W,H=1280,720
local function uiHeight()local w,h=mp.get_osd_size();return math.max(720,1280*h/math.max(1,w))end
local speedChoices={0.25,0.5,0.75,1,1.25,1.5,1.75,2,2.5,3}
local function stepSpeed(direction)
 local value=mp.get_property_number('speed',1);local index=1
 for i,choice in ipairs(speedChoices)do if math.abs(choice-value)<math.abs(speedChoices[index]-value)then index=i end end
 mp.set_property_number('speed',speedChoices[math.max(1,math.min(#speedChoices,index+direction))])
end
local accent='E6C28A'
local menuX,menuY=28,100
local hoverLevels={}
local iconGeometry={}
local frameAt=mp.get_time()
local function esc(s)return tostring(s or ''):gsub('\\','\\e'):gsub('{','\\{'):gsub('}','\\}'):gsub('\n',' ')end
local function host(s)mp.commandv('script-message','fua-host',s)end
local pendingBrightness=nil
local pendingPeak=nil
local function setHdrXpPeak(value)
 pendingPeak={value=value,expires=mp.get_time()+2};host('hdr-xp-peak:'..value)
end
local function imageBrightness()
 local offset=tonumber((mp.get_property_native('user-data/fua-hdr-xp-brightness-offset')))or 0
 local actual=mp.get_property_number('brightness',0)-offset
 if pendingBrightness then
  if math.abs(actual-pendingBrightness.value)<.001 or mp.get_time()>pendingBrightness.expires then pendingBrightness=nil
  else return pendingBrightness.value end
 end
 return actual
end
local function setImageProperty(prop,value)
 if prop=='brightness'then
  if pendingBrightness and pendingBrightness.value==value then return end
  pendingBrightness={value=value,expires=mp.get_time()+2}
  host('brightness-base:'..value)
 else mp.set_property_number(prop,value)end
end
local function time(t)t=math.max(0,math.floor(t or 0));return t>=3600 and string.format('%d:%02d:%02d',t/3600,t/60%60,t%60) or string.format('%d:%02d',t/60,t%60)end
-- Thumbfast integration; a single temporary frame, no persistent timeline cache.
local previewSettings={width=480}
local previewData=os.getenv('FUA_DATA_DIR') or utils.join_path(scriptDir,'../data')
local shadeOverlay=mp.create_osd_overlay('ass-events')
shadeOverlay.z=-1
local shadeWidth,shadeHeight,shadeVisible
local function hideShade()
 if shadeVisible then shadeOverlay:remove();shadeVisible=false end
end
local function showShade(w,h)
 if shadeVisible and shadeWidth==w and shadeHeight==h then return end
 local drawing=assdraw.ass_new()
 local function opacity(y)
  local top=math.max(0,1-y/(h*108/uiHeight()))
  local bottom=math.max(0,1-(h-1-y)/(h*192/uiHeight()))
  return math.floor(170*top*top*(3-2*top)+185*bottom*bottom*(3-2*bottom)+.5)
 end
 local y=0
 while y<h do
  local alpha=opacity(y)
  local nextY=y+1
  while nextY<h and opacity(nextY)==alpha do nextY=nextY+1 end
  if alpha>0 then
   drawing:new_event()
   drawing:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H000000&\\1a&H%02X&}',255-alpha))
   drawing:draw_start()
   drawing:rect_cw(0,y,w,nextY)
   drawing:draw_stop()
  end
  y=nextY
 end
 shadeOverlay.res_x=w;shadeOverlay.res_y=h
 shadeOverlay.data=drawing.text
 shadeOverlay:update()
 shadeWidth=w;shadeHeight=h;shadeVisible=true
end
do local f=io.open(utils.join_path(previewData,'preview-settings.json'),'r');if f then local d=utils.parse_json(f:read('*a'));f:close();if type(d)=='table'then for k,v in pairs(d)do previewSettings[k]=v end end end end
local previewWidth=math.floor(math.max(240,math.min(960,tonumber(previewSettings.width) or 480)))
local preview={wanted=nil}
local draw
local castPeople,castLoading,castLoaded,castGeneration,castOffset={},false,false,0,0
local castScope,castFallback="",false
local castAttempts,castRetry=0,nil
local castLift,castPhotos,castScroll=0,{},0
local castFrom,castAt=0,0
local controlsDismissed,castClosing=false,false
local function moveCast(offset)
 castFrom=castScroll;castOffset=offset;castAt=mp.get_time()
end
local function castEllipsis(value,width,size)
 local chars,used={},0
 for char in tostring(value or ''):gmatch('[%z\1-\127\194-\244][\128-\191]*')do
  local weight=char:byte()>=227 and 1 or (char:match('[ilI%., ]')and .3 or .59)
  if used+weight*size>width then
   while #chars>0 and used+size*.8>width do local last=table.remove(chars);used=used-(last:byte()>=227 and 1 or .59)*size end
   return table.concat(chars)..'…'
  end
  used=used+weight*size;chars[#chars+1]=char
 end
 return table.concat(chars)
end
local function hideCastPhotos()
 for id in pairs(castPhotos)do mp.commandv('overlay-remove',id)end;castPhotos={}
end
local loadCast
loadCast=function()
 if isLite or castLoading or castLoaded then return end
 local path=mp.get_property('path');if not path then return end
 castLoading=true;castAttempts=castAttempts+1;local token=castGeneration
 mp.command_native_async({name='subprocess',args={utils.join_path(scriptDir,'CastArtwork.exe'),path},playback_only=true,capture_stdout=true,capture_stderr=true},function(ok,result)
  if token~=castGeneration then return end
  castLoading=false;castLoaded=true
  local data=ok and result and result.status==0 and utils.parse_json(result.stdout or '')or nil
  local retry=data==nil or type(data.cast)~='table'
  if data and type(data.cast)=='table' then
   castPeople=data.cast;castScope=data.scope or '';castFallback=data.fallback or false
   for _,person in ipairs(castPeople)do if type(person.photo)=='string' and person.photo:match('^https://image%.tmdb%.org/') and not person.file then retry=true;break end end
  end
  if retry and castAttempts<4 then
   castRetry=mp.add_timeout(({2,5,10})[castAttempts],function()castRetry=nil;if token~=castGeneration then return end;castLoaded=false;loadCast()end)
  end
  if draw then draw()end
 end)
end
local function activateCastPerson(index)
 local person=castPeople[index];local id=person and tostring(person.id or '') or ''
 if id:match('^%d+$')then mp.set_property_bool('pause',true);mp.commandv('run','explorer.exe','https://www.themoviedb.org/person/'..id)end
end
navigation=dofile(utils.join_path(scriptDir,'player-navigation.lua')).new({
 now=mp.get_time,position=function()return mp.get_property_number('time-pos',0)end,
 duration=function()return mp.get_property_number('duration',0)end,paused=function()return mp.get_property_bool('pause')end,
 seekRelative=function(value)mp.commandv('seek',value,'relative+exact')end,
 pause=function(value)mp.set_property_bool('pause',value)end,seek=function(value)mp.commandv('seek',value,'absolute+exact')end,
 cast=function(open)mp.set_property_native('user-data/fua-cast-open',open);if open then loadCast()end end,
 castEnabled=not isLite,castCount=function()return math.min(18,#castPeople)end,castActivate=activateCastPerson
})
mp.register_event('start-file',function()pendingBrightness=nil;pendingPeak=nil;navigation.reset();menuZones={};menuIndex=1;menuParent=nil;menuDraft={}end)
mp.register_script_message('fua-cast-toggle',function(value)
 controlsDismissed=false;castClosing=false
 local open=not isLite and value=='yes';mp.set_property_native('user-data/fua-cast-open',open)
 if open then loadCast()end
 if draw then draw()end
end)
mp.register_event('start-file',function()castGeneration=castGeneration+1;if castRetry then castRetry:kill();castRetry=nil end;castAttempts=0;castScope="";castFallback=false;castPeople={};castLoading=false;castLoaded=false;castOffset=0;castScroll=0;castLift=0;hideCastPhotos();mp.set_property_native('user-data/fua-cast-open',false);mp.set_property_number('user-data/fua-bottom-lift',0)end)
mp.register_event('file-loaded',loadCast)
mp.register_event('shutdown',hideCastPhotos)
local headingGeneration=0
mp.register_event('start-file',function()headingGeneration=headingGeneration+1;mp.set_property('user-data/fua-display-title','')end)
mp.register_event('file-loaded',function()
 if isLite then return end
 local file=mp.get_property('path');if not file then return end;local token=headingGeneration
 mp.command_native_async({name='subprocess',args={utils.join_path(scriptDir,'../node.exe'),utils.join_path(scriptDir,'../playback-title.cjs'),file},playback_only=true,capture_stdout=true,capture_stderr=true},function(ok,result)
  if token~=headingGeneration or not ok or not result or result.status~=0 then return end
  local data=utils.parse_json(result.stdout or '');if data and data.title then mp.set_property('user-data/fua-display-title',data.title);draw()end
 end)
end)
local previewHeight=270
local previewVisible=false
local previewPosition=nil
local thumbInfo=nil
local overlayVideoColorspace=false
for _,command in ipairs(mp.get_property_native('command-list') or {})do if command.name=='overlay-add'then for _,arg in ipairs(command.args or {})do if arg.name=='video_colorspace'then overlayVideoColorspace=true end end end end
local function hide_preview()
 if previewVisible then mp.commandv('overlay-remove',61);mp.commandv('script-message-to','thumbfast','clear');previewVisible=false end
 previewPosition=nil
end
mp.register_script_message('thumbfast-info',function(value)thumbInfo=utils.parse_json(value)end)
mp.register_script_message('thumbfast-render',function(value)
 local r=utils.parse_json(value)
 if r then r.received=mp.get_time();mp.set_property('user-data/fua-preview-response',utils.format_json(r))end
 if not r or not previewPosition then return end
 local h=math.floor(previewWidth*r.height/r.width+.5);previewHeight=h
 local c={name='overlay-add',id=61,x=previewPosition.x,y=math.max(0,math.floor(previewPosition.y-h-14)),file=r.thumbnail..'.bgra',offset=0,fmt='bgra',w=r.width,h=r.height,stride=r.width*4,dw=previewWidth,dh=h}
 local source=mp.get_property_native('video-params') or {}
 if overlayVideoColorspace then c.video_colorspace=source.gamma=='pq' or source.gamma=='hlg' end
 mp.command_native(c);previewVisible=true
end)
local function preview_frame(seconds,px,py)
 if thumbInfo and thumbInfo.disabled then hide_preview();return end
 local w=mp.get_osd_size();px=math.max(previewWidth/2+5,math.min(w-previewWidth/2-5,px))
 previewPosition={x=math.floor(px-previewWidth/2),y=py}
 mp.commandv('script-message-to','thumbfast','thumb',tostring(seconds),'','',mp.get_script_name())
end
mp.register_script_message('fua-preview-test',function(seconds)preview_frame(tonumber(seconds),500,500)end)
mp.register_event('shutdown',hide_preview)
draw=function()
 local w,h=mp.get_osd_size();if w<=0 or h<=0 then return end
 H=uiHeight();W=H*w/h
 mp.set_property_native('user-data/fua-controls-visible',visible)
 if not visible then trackFlags.hide();episodePanel.draw(false,0,0);hideCastPhotos();hideShade();preview.wanted=nil;hide_preview();overlay.data='';overlay:update();if logoKey then mp.commandv('overlay-remove',60);logoKey=nil end;if rtxLogoKey then mp.commandv('overlay-remove',29);rtxLogoKey=nil end;return end
 local now=mp.get_time();local dt=math.min(0.1,now-frameAt);frameAt=now
 local target=mp.get_property_native('user-data/fua-cast-open')==true and 130 or 0
 local smoothing=1-math.exp(-dt*6.5)
 castLift=castLift+(target-castLift)*smoothing
 local slide=math.min(1,(now-castAt)/.5)
 castScroll=castFrom+(castOffset-castFrom)*(slide*slide*(3-2*slide))
 if math.abs(castScroll-castOffset)<.005 then castScroll=castOffset end
 if math.abs(castLift-target)<.3 then castLift=target end
 mp.set_property_number('user-data/fua-bottom-lift',castLift)
 navigation.items={};menuZones={};local navScope=nil
 local a=assdraw.ass_new();zones={};local rawX,rawY=pointer_position();local mouseX,mouseY=rawX*W/w,rawY*H/h;local tooltip=nil;local tipX,tipY=0,0
 local function captionBackground(x,y,w,h)
  local r=7;local k=.55228475*r
  a:new_event();a:append('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H18120C&\\1a&H77&}');a:draw_start()
  a:move_to(x+r,y);a:line_to(x+w-r,y);a:bezier_curve(x+w-r+k,y,x+w,y+r-k,x+w,y+r)
  a:line_to(x+w,y+h-r);a:bezier_curve(x+w,y+h-r+k,x+w-r+k,y+h,x+w-r,y+h)
  a:line_to(x+r,y+h);a:bezier_curve(x+r-k,y+h,x,y+h-r+k,x,y+h-r)
  a:line_to(x,y+r);a:bezier_curve(x,y+r-k,x+r-k,y,x+r,y);a:draw_stop()
 end
 local function box(x,y,w,h,color,alpha)
  a:new_event();a:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H%s&}',color or 'FFFFFF',alpha or '00'));a:draw_start();a:rect_cw(x,y,x+w,y+h);a:draw_stop()
 end
 local function circle(x,y,r,color)
  a:new_event();a:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H00&}',color or accent));a:draw_start()
  for i=0,24 do local angle=i/24*math.pi*2;local px,py=x+math.cos(angle)*r,y+math.sin(angle)*r;if i==0 then a:move_to(px,py)else a:line_to(px,py)end end;a:draw_stop()
 end
 local function text(x,y,t,size,align,color,bold)
  a:new_event();a:append(string.format('{\\an%d\\pos(%f,%f)\\fnSegoe UI\\fs%.2f\\bord0\\shad0\\1a&H00&\\1c&H%s&}',align or 5,x,y,size or 19,color or 'FFFFFF'));if bold then a:append('{\\b1}')end;a:append(esc(t))
 end
  local function zone(x,y,w,h,fn,hint,focused)
  zones[#zones+1]={x=x,y=y,w=w,h=h,fn=fn,hint=hint}
  local entry={x=x,y=y,w=w,h=h,fn=fn,hint=hint}
  if navScope=='menu' then menuZones[#menuZones+1]=entry;if menuKind~='audio' and menuKind~='sub' then focused=navigation.active and #menuZones==menuIndex end end
  local hot=focused or (not navigation.active and pointer_inside() and mouseX>=x and mouseX<=x+w and mouseY>=y and mouseY<=y+h)
  local key=string.format('%.0f:%.0f:%.0f',x,y,w)
  local level=hoverLevels[key] or 0;level=level+((hot and 1 or 0)-level)*math.min(1,dt*18);hoverLevels[key]=level
  -- Hover uses icon tint and scale, without button shadows or plates.
  if hot then tooltip=hint;tipX=x+w/2;tipY=y>H/2 and y-18 or y+h+22 end
  return level
 end
 local function icon(x,y,name,fn,hint)
    local hints={['≡']=(isLite and 'Fechar vídeo' or 'Voltar à biblioteca'),['♫']='Escolher áudio',['▤']='Escolher legenda',['◖']='Silenciar',['×']='Ativar som',play='Reproduzir',pause='Pausar',['↶']='Voltar 10 segundos',['↷']='Avançar 10 segundos',RTX='Ligar/desligar RTX HDR',['▣']='Salvar imagem do vídeo',['ⓘ']='Informações do vídeo',['⛶']='Tela cheia',['—']='Minimizar',['□']='Maximizar / restaurar'}
  local navId=(name=='play' or name=='pause')and 'playback' or (name=='×' or name=='◖')and 'mute' or name:match('^[%d%.]+×$')and 'speed' or name
  local focused=false
  if y>100 and name~='cast-next' and name~='cast-prev' then focused=navigation.add(navId,fn)end
  if menuKind or episodePanel.open then focused=false end
  local hitWidth=name=='HDR XP' and 76 or name=='A4K' and 96 or 42
  local level=zone(x-hitWidth/2,y-22,hitWidth,44,fn,hint or hints[name] or 'Velocidade de reprodução',focused)
  local active=(name=='episodes' and episodePanel.open) or (name=='A4K' and shaderIndex>1) or (name=='RTX' and hdrLabel:find('confirmado')) or (name=='HDR XP' and hdrXpActive()) or (name=='♫' and menuKind=='audio') or (name=='▤' and menuKind=='sub') or (name=='≡' and menuKind=='main')
  local tint=(name=='×' and y<100 and level>0.08) and '6E62FF' or ((active or level>0.08) and accent or 'FFFFFF')
  local baseScale=({['▣']=0.82,['ⓘ']=0.88,['⛶']=0.88})[name] or 1
  local scale=baseScale*(1+0.10*level)
  local output=a
  local key=name..((name=='×' and y>=100) and ':mute' or '')..((name=='◖' and mp.get_property_number('user-data/fua-system-volume',100)>35) and ':loud' or '')
  local geometry=iconGeometry[key]
  if not geometry then
  local a=assdraw.ass_new()
  local scale,weight=1,1.9
  a:draw_start()
  local function disk(cx,cy,r)
   for i=0,6 do local t=i/6*math.pi*2;local px,py=(cx+math.cos(t)*r)*scale,(cy+math.sin(t)*r)*scale;if i==0 then a:move_to(px,py)else a:line_to(px,py)end end
  end
  local function stroke(x1,y1,x2,y2)
   local dx,dy=x2-x1,y2-y1;local len=math.sqrt(dx*dx+dy*dy);if len==0 then return end
   local r=weight/2;local nx,ny=-dy/len*r,dx/len*r
   a:move_to((x1-nx)*scale,(y1-ny)*scale);a:line_to((x2-nx)*scale,(y2-ny)*scale);a:line_to((x2+nx)*scale,(y2+ny)*scale);a:line_to((x1+nx)*scale,(y1+ny)*scale)
   disk(x1,y1,r);disk(x2,y2,r)
  end
  local function path(points,closed)
   for i=2,#points do stroke(points[i-1][1],points[i-1][2],points[i][1],points[i][2])end
   if closed then stroke(points[#points][1],points[#points][2],points[1][1],points[1][2])end
  end
  local function arc(cx,cy,r,first,last)
   local points={};for i=0,16 do local t=first+(last-first)*i/16;points[#points+1]={cx+math.cos(t)*r,cy+math.sin(t)*r}end;path(points)
  end
  local function rect(cx,cy,w,h,r)
   stroke(cx-w/2+r,cy-h/2,cx+w/2-r,cy-h/2);stroke(cx-w/2+r,cy+h/2,cx+w/2-r,cy+h/2)
   stroke(cx-w/2,cy-h/2+r,cx-w/2,cy+h/2-r);stroke(cx+w/2,cy-h/2+r,cx+w/2,cy+h/2-r)
   arc(cx+w/2-r,cy-h/2+r,r,-math.pi/2,0);arc(cx+w/2-r,cy+h/2-r,r,0,math.pi/2)
   arc(cx-w/2+r,cy+h/2-r,r,math.pi/2,math.pi);arc(cx-w/2+r,cy-h/2+r,r,math.pi,math.pi*1.5)
  end
  if name=='episodes' then path({{-10,-7},{-10,7},{-3,0}},true);stroke(1,-7,10,-7);stroke(1,0,10,0);stroke(1,7,10,7)
  elseif name=='cast-next' then path({{-3,-7},{4,0},{-3,7}})
  elseif name=='cast-prev' then path({{3,-7},{-4,0},{3,7}})
  elseif name=='←' then path({{-2,-8},{-10,0},{-2,8}});stroke(-10,0,10,0)
  elseif name=='×' and y<100 then stroke(-7,-7,7,7);stroke(-7,7,7,-7)
  elseif name=='play' then path({{-6,-10},{-8,-9},{-8,9},{-6,10},{10,1.8},{11,0},{10,-1.8}},true)
  elseif name=='pause' then rect(-5,0,5,20,2.5);rect(5,0,5,20,2.5)
  elseif name=='≡' then
   for i=-1,1 do local yy=i*7;stroke(-10,yy,10,yy);local xx=i==0 and 5 or -4;stroke(xx,yy-3,xx,yy+3)end
  elseif name=='♫' then
   stroke(2,-9,2,6);stroke(2,-9,9,-6);disk(-1,6,3.3)
  elseif name=='◖' or name=='×' then
   path({{-9,-4},{-5,-4},{1,-9},{3,-8},{3,8},{1,9},{-5,4},{-9,4}},true)
   if name=='×' then stroke(7,-3.5,13,3.5);stroke(7,3.5,13,-3.5)
   else arc(1,0,7,-.7,.7);if name=='♫' or mp.get_property_number('user-data/fua-system-volume',100)>35 then arc(1,0,11,-.7,.7)end end
  elseif name=='▤' then rect(0,0,23,17,3);stroke(-7,0,-1,0);stroke(3,0,7,0);stroke(-7,4,3,4)
  elseif name=='↶' or name=='↷' then
   local sign=name=='↶' and 1 or -1;local points={}
   for i=0,32 do local t=-math.pi*.8+math.pi*1.6*i/32;points[#points+1]={sign*math.cos(t)*10,-3+math.sin(t)*10}end;path(points)
   local px,py=sign*math.cos(-math.pi*.8)*10,-3+math.sin(-math.pi*.8)*10
   stroke(px,py,px+sign*5,py);stroke(px,py,px,py-5)
  elseif name=='RTX' or name=='HDR XP' then -- text only
  elseif name=='▣' then rect(0,1,24,17,3);path({{-7,-7},{-5,-11},{4,-11},{7,-7}});arc(0,1,5,0,math.pi*2)
  elseif name=='ⓘ' then arc(0,0,11,0,math.pi*2);stroke(0,-1,0,6);disk(0,-6,1.25)
  elseif name=='⛶' then
   for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do path({{sx*4,sy*10},{sx*10,sy*10},{sx*10,sy*4}})end end
  end
  a:draw_stop()
  geometry=a.text;iconGeometry[key]=geometry
  end
  output:new_event();output:append(string.format('{\\an7\\pos(%f,%f)\\fscx%.2f\\fscy%.2f\\bord0\\shad0\\1a&H00&\\1c&H%s&}',x,y,scale*100,scale*100,tint));output:append(geometry)
  if name=='A4K' then
   text(x,y,shaderIndex>1 and ('A4K · '..shaderProfiles[shaderIndex].short) or 'A4K',17*scale,5,shaderIndex>1 and accent or 'FFFFFF',true)
  elseif name=='RTX' then
   local asset=rtxLogos[active and 'on' or 'off']
   if asset then
    local dh=math.max(1,math.floor(11*scale*h/H));local dw=math.max(1,math.floor(dh*asset.width/asset.height))
    local px=math.floor(x*w/W-dw/2);local py=math.floor(y*h/H-dh/2)
    local signature=table.concat({asset.file,px,py,dw,dh},':')
    if rtxLogoKey~=signature then mp.command_native({name='overlay-add',id=29,x=px,y=py,file=asset.file,offset=0,fmt='bgra',w=asset.width,h=asset.height,stride=asset.width*4,dw=dw,dh=dh});rtxLogoKey=signature end
   else text(x,y,'RTX',16*scale,5,active and accent or 'FFFFFF',active)end
  elseif name=='HDR XP' then
   local compensation=tonumber((mp.get_property_native('user-data/fua-hdr-xp-mode')))or -1
   local state=not active and 'off' or compensation==1 and 'minus1' or compensation==2 and 'minus2' or 'on'
   local asset=xpLogos[state]
   if asset then
    -- Align the letter bodies; the active logo's sparkle extends above them.
    local bodyTop=asset.bodyTop or (active and 35 or 0)
    local bodyHeight=asset.bodyHeight or (asset.height-bodyTop)
    local factor=10*scale*h/H/bodyHeight
    local dw=math.max(1,math.floor(asset.width*factor));local dh=math.max(1,math.floor(asset.height*factor))
    local px=math.floor(x*w/W-dw/2);local py=math.floor(y*h/H-(bodyTop+bodyHeight/2)*factor)
    local signature=table.concat({asset.file,px,py,dw,dh},':')
    if logoKey~=signature then
     mp.command_native({name='overlay-add',id=60,x=px,y=py,file=asset.file,offset=0,fmt='bgra',w=asset.width,h=asset.height,stride=asset.width*4,dw=dw,dh=dh})
     logoKey=signature
    end
   else text(x,y,'HDR XP',13*scale,5,tint,active)end
  elseif name=='↶' or name=='↷' then text(x,y-3,'10',9*scale,5,tint)
  elseif name:match('^[%d%.]+×$') then text(x,y,name,16.5*scale,5,tint,true)end

 end
 local function slider(x,y,width,value,minimum,maximum,setter,hint,enabled)
  local draftKey=navScope=='menu' and hint or nil
  if draftKey and navigation.active and menuDraft[draftKey]~=nil then value=menuDraft[draftKey]end
  local fraction=math.max(0,math.min(1,(value-minimum)/(maximum-minimum)))
  local sliderTint=enabled==false and '707070'or accent
  box(x,y-1,width,3,'FFFFFF','B0');box(x,y-1,width*fraction,3,sliderTint)
  circle(x+width*fraction,y,4,sliderTint)
  if enabled==false then return end
  local lastApplied=nil
  local function update(px)
   local nextValue=math.max(minimum,math.min(maximum,minimum+(px-x)/width*(maximum-minimum)))
   if draftKey then nextValue=math.floor(nextValue+.5)end
   if lastApplied~=nil and math.abs(nextValue-lastApplied)<.001 then return end
   lastApplied=nextValue;setter(nextValue)
  end
  local level=zone(x-6,y-12,width+12,26,update,hint)
  if draftKey and level>.08 then circle(x+width*fraction,y,4+2*level,'FFFFFF')end
  zones[#zones].slide=update
  if draftKey then local entry=menuZones[#menuZones];entry.adjust=function(direction)menuDraft[draftKey]=math.max(minimum,math.min(maximum,value+direction))end;entry.confirm=function()if menuDraft[draftKey]~=nil then setter(menuDraft[draftKey]);menuDraft[draftKey]=nil end end end
 end
 showShade(w,h)
 icon(40,40,'←',function()host('library')end,(isLite and 'Fechar vídeo' or 'Voltar à biblioteca'))
 icon(W-40,40,'×',function()host('close')end,'Fechar Fua Player')
 local title=mp.get_property('user-data/fua-display-title','');if title=='' then title=mp.get_property('media-title','Fua Player')end
 if not isLite then text(78,40,castEllipsis(title,math.max(80,W-280),20),20,4)end
 text(28,H-105-castLift,castEllipsis(mp.get_property('filename',mp.get_property('media-title','Fua Player')),W-56,20),20,4)
 local pos=mp.get_property_number('time-pos',0);local dur=mp.get_property_number('duration',0)
 local x1,x2,y=28,W-28,H-76-castLift
 local barPosition=navigation.pending or pos
 box(x1,y,x2-x1,3,'FFFFFF','99');if dur>0 then box(x1,y,(x2-x1)*math.min(1,barPosition/dur),3,accent)end
 local chapters=mp.get_property_native('chapter-list',{}) or {}
 if dur>0 then for _,chapter in ipairs(chapters)do local t=tonumber(chapter.time);if t and t>0 and t<dur then local cx=x1+(x2-x1)*t/dur;box(cx-1,y-2,2,7,'111820')end end end
 local mx,my=pointer_position();mx=mx*W/w;my=my*H/h
 local keyboardPreview=navigation.active and navigation.shown and navigation.row=='timeline' and navigation.pending~=nil
 if keyboardPreview then mx=x1+(x2-x1)*math.min(1,navigation.pending/math.max(1,dur))end
 local hover=keyboardPreview or (not navigation.active and pointer_inside() and mx>=x1 and mx<=x2 and my>=y-14 and my<=y+16)
 if hover and dur>0 and not menuKind then local target=keyboardPreview and navigation.pending or dur*math.max(0,math.min(1,(mx-x1)/(x2-x1)));preview_frame(target,math.max(165,math.min(w-165,mx*w/W)),y*h/H);local chapterName=nil;for i,chapter in ipairs(chapters)do if tonumber(chapter.time) and chapter.time<=target then chapterName=chapter.title or ('Capítulo '..i)end end;local caption=time(target);if chapterName then caption=caption..' · '..chapterName end;if previewPosition then local cx=(previewPosition.x+previewWidth/2)*W/w;local top=math.max(0,previewPosition.y-previewHeight-14)*H/h;caption=castEllipsis(caption,previewWidth*W/w-16,14);captionBackground(previewPosition.x*W/w,math.max(0,top-27),previewWidth*W/w,24);text(cx,math.max(12,top-15),caption,14,5)end else hide_preview();preview.wanted=nil end
 if hover or mp.get_property_bool('pause')then circle(x1+(x2-x1)*(dur>0 and math.min(1,barPosition/dur) or 0),y+1.5,hover and 6 or 4.5,accent)end
 zone(x1,y-13,x2-x1,28,function(px)if dur>0 then mp.commandv('seek',math.max(0,math.min(1,(px-x1)/(x2-x1)))*dur,'absolute+exact')end end,'Ir para '..time(dur*math.max(0,math.min(1,(mouseX-x1)/(x2-x1)))))
 if not isLite then
  local castOpen=mp.get_property_native('user-data/fua-cast-open')==true
 local elapsed=mp.get_time()-hintAppearedAt
 local glow=elapsed<1 and math.sin(elapsed*math.pi) or 0
 local hintY=H-8-castLift
 a:new_event();a:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&HBBD7E9&\\1a&H%02X&}',math.floor(100-glow*70)))
 a:draw_start()
 local sign=castOpen and -1 or 1;local center=W/2
 a:move_to(center-10,hintY-3*sign);a:line_to(center,hintY+2*sign);a:line_to(center+10,hintY-3*sign);a:line_to(center+10,hintY-1*sign);a:line_to(center,hintY+4*sign);a:line_to(center-10,hintY-1*sign);a:line_to(center-10,hintY-3*sign);a:draw_stop()
 zone(W/2-30,H-20-castLift,60,20,function()host(castOpen and 'cast-close' or 'cast-open')end,castOpen and 'Recolher elenco' or 'Rolar para baixo: elenco')
 end
 local cy=H-35-castLift
 icon(40,cy,'≡',function()if menuKind=='main' then menuKind=nil else menuKind='main';menuX=28;menuY=H-400 end;draw()end,'Menu do player')
 icon(84,cy,'♫',function()openTracks('audio')end)
 icon(128,cy,'▤',function()openTracks('sub')end)
 icon(172,cy,(mp.get_property('user-data/fua-system-mute')=='yes') and '×' or '◖',function()host('system-mute')end)
 local vol=mp.get_property_number('user-data/fua-system-volume',100);slider(196,cy,76,vol,0,100,function(v)host('volume:'..v)end,'Volume · '..math.floor(vol)..'%')
 if sliderDrag or (pointer_inside() and mouseX>=190 and mouseX<=278 and mouseY>=cy-22 and mouseY<=cy+22) or mp.get_time()<volumeFeedbackUntil then text(196+76*math.max(0,math.min(100,vol))/100,cy-23,tostring(math.floor(vol+0.5))..'%',12)end
 text(292,cy,time(pos)..' / '..time(dur),16,4)
 icon(W/2-62,cy,'↶',function()mp.commandv('seek',-10)end)
 icon(W/2,cy,mp.get_property_bool('pause') and 'play' or 'pause',function()mp.commandv('cycle','pause')end)
 icon(W/2+62,cy,'↷',function()mp.commandv('seek',10)end)
 local speed=mp.get_property_number('speed',1)
 icon(W-(378+(episodePanel.available() and 46 or 0)),cy,'A4K',function()menuKind=menuKind=='shaders' and nil or 'shaders';draw()end,'Anime4K · '..shaderProfiles[shaderIndex].id)
 icon(W-(312+(episodePanel.available() and 46 or 0)),cy,string.format('%.1f×',speed),function()menuKind=menuKind=='speed' and nil or 'speed';draw()end,'Velocidade de reprodução')
 icon(W-(264+(episodePanel.available() and 46 or 0)),cy,'RTX',function()host('rtx')end)
 icon(W-(198+(episodePanel.available() and 46 or 0)),cy,'HDR XP',function()host('hdr-xp')end,'HDR XP · alternar modos (Shift+H)')
 icon(W-(132+(episodePanel.available() and 46 or 0)),cy,'▣',function()host('screenshot')end)
 icon(W-(86+(episodePanel.available() and 46 or 0)),cy,'ⓘ',function()mp.commandv('script-message','fua-stats-cycle')end)
 if episodePanel.available() then icon(W-86,cy,'episodes',function()menuKind=nil;episodePanel.toggle();draw()end,'Episódios disponíveis')end
 icon(W-40,cy,'⛶',function()host('fullscreen')end)

 if castLift>1 then
  local top=H-castLift
  local label=castLoading and "Carregando elenco…" or castScope=="episode" and "Elenco do episódio" or castScope=="season" and "Elenco da temporada" or castScope=="series" and "Elenco geral da série" or "Elenco"
  if castFallback then label=label.." · alternativa"end
  text(W/2,top+8,label,10,5)
  local count=math.min(18,math.max(1,math.floor((W-160)/88)));local used={}
  local rowWidth=math.min(count,#castPeople)*88
  local start=(W-rowWidth)/2
  for slot,person in ipairs(castPeople)do
   local cx=start+44+(slot-1-castScroll)*88;local py=top+22;local id=29+slot
   local castFocused=navigation.active and not menuKind and not episodePanel.open and navigation.row=='cast' and navigation.castIndex==slot
   local castHover=castFocused or (not navigation.active and pointer_inside() and mouseX>=cx-39 and mouseX<=cx+39 and mouseY>=py and mouseY<=py+104)
   local photoScale=castHover and 1.08 or 1
   if slot<=18 and cx>=start+32 and cx<=start+rowWidth-32 then
   if person.file then
    local px,iy,size=math.floor((cx-32*photoScale)*w/W),math.floor((py+32-32*photoScale)*h/H),math.floor(64*photoScale*h/H)
    local key=person.file..':'..px..':'..iy..':'..size
    if castPhotos[id]~=key then mp.command_native({name='overlay-add',id=id,x=px,y=iy,file=person.file,offset=0,fmt='bgra',w=144,h=144,stride=576,dw=size,dh=size});castPhotos[id]=key end
    used[id]=true
   else circle(cx,py+32,32,'3C2D1C');text(cx,py+32,tostring(person.name or '?'):sub(1,1),22)end
   local name=tostring(person.name or '')
   text(cx,py+78,castEllipsis(name,80,10.5),castHover and 11.5 or 10.5,5,castHover and accent or 'D8E5F0')
   text(cx,py+92,castEllipsis(person.character,80,9.5),9.5,5,'A59A8C')
   zone(cx-39,py,78,104,function()activateCastPerson(slot)end,name,castFocused)
   end
  end
  for id in pairs(castPhotos)do if not used[id]then mp.commandv('overlay-remove',id);castPhotos[id]=nil end end
  if #castPeople>count then
   icon(start+rowWidth+30,top+56,'cast-next',function()moveCast(math.min(math.max(0,#castPeople-count),castOffset+math.max(1,count-1)));draw()end,'Próximos atores')
   icon(start-30,top+56,'cast-prev',function()moveCast(math.max(0,castOffset-math.max(1,count-1)));draw()end,'Atores anteriores')
  end
 else hideCastPhotos()end
 local label=hdrLabel
 -- HDR status is shown by the discreet RTX button, without a debug label.
 trackFlags.begin()
 navScope='menu'
  if menuKind=='audio' or menuKind=='sub' then
  local tracks=mp.get_property_native('track-list') or {};local choices={}
  if menuKind=='sub' then choices[#choices+1]={id='no',title='Desligar legendas'} end
  for _,tr in ipairs(tracks)do if tr.type==menuKind then choices[#choices+1]=tr end end
  trackChoices=choices
  local pw=math.min(500,W-56);local count=math.min(trackPageSize,#choices);trackOffset=math.max(0,math.min(trackOffset,#choices-count));local ph=count*30+(menuKind=='sub' and 80 or 50);local px=28;local py=H-90-ph
  box(px,py,pw,ph,'16100B','0B');text(px+18,py+21,menuKind=='audio' and 'Áudio' or 'Legendas',18,4)
  for row=1,count do local n=row+trackOffset;local tr=choices[n];local id=tr.id;local prop=menuKind=='audio' and 'aid' or 'sid';local label=tr.title or ((tr.lang or 'Faixa')..'  '..tostring(id));if tr.lang and tr.title then label=tr.lang..' · '..label end
   local ry=py+42+(row-1)*30;local chosen=tostring(mp.get_property(prop))==tostring(id)
   if chosen or n==trackCursor then box(px+8,ry,pw-30,29,'FFFFFF',chosen and 'E6' or 'F2')end
   local level=zone(px,ry,pw-24,30,function()if prop=='aid' then select_audio(id)else mp.set_property(prop,tostring(id))end;menuKind=nil;draw()end,'Selecionar '..label,navigation.active and n==trackCursor)
   local flagged=trackFlags.draw(row,tr,(px+18)*w/W,(ry+15)*h/H,h/H)
   text(px+(flagged and 48 or 18),ry+15,label,15+level,4,(chosen or level>0.08 or n==trackCursor) and accent or 'FFFFFF')
  end
  if #choices>count then
   local sy,sh=py+42,count*30;box(px+pw-12,sy,3,sh,'FFFFFF','D0');local thumb=math.max(20,sh*count/#choices);box(px+pw-13,sy+(sh-thumb)*trackOffset/math.max(1,#choices-count),5,thumb,accent)
   zone(px+pw-22,sy,22,sh,function(_,y)trackOffset=math.floor(math.max(0,math.min(1,(y-sy)/sh))*(#choices-count)+0.5);draw()end,'Rolar lista')
  end
  if menuKind=='sub' then
   local settingsY=py+ph-34
   local level=zone(px+8,settingsY,pw-16,30,function()menuKind=nil;draw();host('subtitle-settings')end,'Ajustar fonte, tamanho, cor, posição e sincronização',navigation.active and trackCursor==#choices+1)
   if level>0.08 then box(px+8,settingsY,pw-16,30,accent,'E6')end
   text(px+18,settingsY+15,'Ajustes de legenda…',15+level,4,accent)
  end
  mp.set_property('user-data/fua-track-menu-state',menuKind..':'..trackOffset..':'..count..':'..#choices)
 end
 trackFlags.finish()
 if menuKind=='shaders' then
  local pw,ph=310,320;local px=W-pw-28;local py=H-90-ph
  box(px,py,pw,ph,'20160F','08');text(px+18,py+24,'Upscaling em tempo real',18,4)
  text(px+18,py+49,'Perfis originais · versão conforme arquivo',12,4,'C8B8A0')
  for i,profile in ipairs(shaderProfiles)do
   local yy=py+66+(i-1)*29;local selected=shaderIndex==i
   if selected then box(px+8,yy,pw-16,28,accent,'D8')end
   local level=zone(px+8,yy,pw-16,29,function()apply_shader(i);menuKind=nil;draw()end,profile.label)
   text(px+18,yy+14,profile.label..(profile.version and ' · v'..profile.version or ''),15,4,(selected or level>0.08) and accent or 'FFFFFF')
   if selected then text(px+pw-20,yy+14,'✓',15,6,accent)end
  end
 end
 if menuKind=='speed' then
  local pw,ph=230,66+#speedChoices*29;local px=W-pw-28;local py=H-90-ph
  box(px,py,pw,ph,'20160F','08');text(px+18,py+25,'Velocidade',18,4)
  for i,value in ipairs(speedChoices)do
   local yy=py+50+(i-1)*29;local selected=math.abs(mp.get_property_number('speed',1)-value)<.001
   if selected then box(px+8,yy,pw-16,28,accent,'D8')end
   local label=string.format('%g×',value)
   local level=zone(px+8,yy,pw-16,29,function()mp.set_property_number('speed',value);menuKind=nil;draw()end,label)
   text(px+18,yy+14,label,15,4,(selected or level>.08)and accent or 'FFFFFF')
   if selected then text(px+pw-20,yy+14,'✓',15,6,accent)end
  end
 end
 if menuKind=='image' then
  local pw,ph=350,354;local px=math.max(12,math.min(W-pw-12,menuX));local py=math.max(80,math.min(H-ph-100,menuY))
  box(px,py,pw,ph,'20160F','08');text(px+18,py+25,'Ajustes de imagem',19,4)
  local properties={{'Contraste','contrast'},{'Brilho','brightness'},{'Gama','gamma'},{'Saturação','saturation'}}
  for i,item in ipairs(properties)do
   local prop=item[2];local value=prop=='brightness'and imageBrightness()or mp.get_property_number(prop,0);local ry=py+55+(i-1)*43
   text(px+18,ry,item[1],15,4);text(px+pw-18,ry,string.format('%+d',value),14,6,accent)
   slider(px+18,ry+15,pw-36,value,-100,100,function(v)setImageProperty(prop,math.floor(v+0.5))end,'Ajustar '..item[1]..' · centro = neutro')
  end
  local xp=hdrXpActive()
  local reported=tonumber((mp.get_property_native('user-data/fua-hdr-xp-screen-peak')))or 0
  local manual=tonumber((mp.get_property_native('user-data/fua-hdr-xp-manual-peak')))or 0
  if pendingPeak then if pendingPeak.value==manual or mp.get_time()>pendingPeak.expires then pendingPeak=nil else manual=pendingPeak.value end end
  local maximum=reported>0 and reported or 10000
  local value=manual>0 and manual or (reported>0 and reported or 1000)
  local peakTint=xp and accent or '777777'
  text(px+18,py+230,'Limite HDR XP',15,4,xp and 'FFFFFF'or '777777')
  text(px+pw-18,py+230,(manual>0 and 'Manual: 'or 'Auto: ')..(manual>0 and manual or reported>0 and reported or '—')..' nits',14,6,peakTint)
  text(px+18,py+250,reported>0 and ('Windows informa: '..reported..' nits')or 'Windows não informou o pico da tela',12,4,'A59A8C')
  slider(px+18,py+266,pw-36,value,math.min(100,maximum),maximum,function(v)setHdrXpPeak(math.floor(v+.5))end,'Limite HDR XP em nits',xp)
  if xp then zone(px+12,py+278,pw-24,25,function()setHdrXpPeak(0)end,'Restaurar limite automático')end
  text(px+pw/2,py+291,'Restaurar automático',13,5,peakTint)
  zone(px+12,py+316,pw-24,30,function()for _,item in ipairs(properties)do setImageProperty(item[2],0)end;draw()end,'Restaurar os quatro ajustes')
  text(px+pw/2,py+331,'Restaurar padrão',14,5)
 end
 if menuKind=='main' then
  local pw=290;local px=math.max(12,math.min(W-pw-12,menuX));local py=math.max(80,math.min(H-424,menuY))
  box(px,py,pw,334,'20160F','08');text(px+18,py+25,'Menu do player',19,4)
  local choices={{'Play / pause',function()menuKind=nil;mp.commandv('cycle','pause')end},{'Atalhos de teclado…',function()menuKind=nil;host('shortcuts')end},{(isLite and 'Fechar vídeo' or 'Voltar à biblioteca'),function()menuKind=nil;host('library')end},{'Ajustes de imagem',function()menuKind='image';menuX=28;menuY=H-390 end},{'Áudio',function()openTracks('audio')end},{'Legendas',function()openTracks('sub')end},{'Tela cheia / restaurar',function()menuKind=nil;host('fullscreen')end},{'Salvar imagem do vídeo',function()menuKind=nil;host('screenshot')end},{'Configurações',function()menuKind=nil;draw();host('settings')end}}
  for i,item in ipairs(choices)do local y=py+46+(i-1)*28;local level=zone(px+12,y,pw-24,28,item[2],item[1]);text(px+20,y+14,item[1],15+level,4,level>0.08 and accent or 'FFFFFF')end
 end

 mp.set_property_native('user-data/fua-player-navigation', {row=navigation.row,shown=navigation.shown,pinned=navigation.pinned,focus=navigation.focus,pending=navigation.pending or -1,menu=menuKind or '',menuIndex=menuIndex})
 mp.set_property_native('user-data/fua-menu-open',menuKind~=nil or episodePanel.open)
 mp.set_property_native('user-data/fua-episode-menu-open',episodePanel.open)
 mp.set_property_native('user-data/fua-track-menu',menuKind=='audio' or menuKind=='sub')
 overlay.res_x=W;overlay.res_y=H;overlay.data=a.text;overlay:update();episodePanel.draw(visible,rawX/w,rawY/h)
end
local function hover_controls()
 local x,y=pointer_position();local w,h=mp.get_osd_size()
 return pointer_inside() and h>0 and (y/h>=1-130/uiHeight() or y/h<=100/uiHeight())
end
local function update_visibility()
 local wasVisible=visible
 local remoteVisible=navigation.tick()
 visible=remoteVisible or episodePanel.active() or (castClosing and castLift>.3) or (not controlsDismissed and (mp.get_property_native('user-data/fua-cast-open')==true or menuKind~=nil or (not navigation.active and pointer_inside() and (hover_controls() or dragging or sliderDrag~=nil))))
 if visible and not wasVisible then hintAppearedAt=mp.get_time()end
 draw()
end
local pointerSeekTarget=nil
local function seek_at(nx)
 local dur=mp.get_property_number('duration',0)
 local w,h=mp.get_osd_size();local width=uiHeight()*w/h
 local fraction=math.max(0,math.min(1,(nx*width-28)/(width-56)))
 if dur>0 then
  local target=fraction*dur
  if pointerSeekTarget and math.abs(target-pointerSeekTarget)<.001 then return end
  pointerSeekTarget=target;mp.commandv('seek',target,'absolute+exact')
 end
end
local lastSeek=0
local wheelRemainder=0;local wheelArea=nil
mp.register_script_message('fua-native-wheel',function(nx,ny,delta)
 local w,h=mp.get_osd_size();local width=uiHeight()*w/h
 if episodePanel.wheel(tonumber(nx)or 0,tonumber(ny)or 0,delta)then update_visibility();return end
 local x,y=(tonumber(nx)or 0)*width,(tonumber(ny)or 0)*uiHeight()
 local cy=uiHeight()-35-castLift;local area=nil
 if x>=190 and x<=278 and math.abs(y-cy)<=24 then area='volume'
 elseif (math.abs(x-(width-378-(episodePanel.available() and 46 or 0)))<=30 and math.abs(y-cy)<=24)or(menuKind=='shaders' and x>=width-338 and x<=width-28 and y>=uiHeight()-410 and y<=uiHeight()-90)then area='shader'
 elseif (math.abs(x-(width-312-(episodePanel.available() and 46 or 0)))<=21 and math.abs(y-cy)<=24)or(menuKind=='speed' and x>=width-258 and x<=width-28 and y>=uiHeight()-446 and y<=uiHeight()-90)then area='speed'
 elseif not menuKind and math.abs(x-width/2)<=65 and y>=cy-24 then area='cast' end
 if not area then wheelRemainder=0;wheelArea=nil;return end
 if wheelArea~=area then wheelRemainder=0;wheelArea=area end
 wheelRemainder=wheelRemainder+(tonumber(delta)or 0)
 local steps=wheelRemainder>=0 and math.floor(wheelRemainder/120)or math.ceil(wheelRemainder/120)
 if steps==0 then return end
 wheelRemainder=wheelRemainder-steps*120
 if area=='volume' then
  local value=math.max(0,math.min(100,mp.get_property_number('user-data/fua-system-volume',100)+steps))
  host('volume:'..value)
 elseif area=='speed' then
  stepSpeed(steps>0 and 1 or -1)
 elseif area=='shader' then
  apply_shader(((shaderIndex-1-steps)%#shaderProfiles)+1)
 else
  controlsDismissed=false;castClosing=false
  mp.set_property_native('user-data/fua-cast-open',steps<0)
  if steps<0 then loadCast()end
 end
 update_visibility()
end)
local bodyClickAt=-10;local bodyClickX,bodyClickY=0,0;local bodyPauseBefore=false
mp.register_script_message('fua-native-pointer',function(nx,ny,inside)
 if nativePointer and (math.abs((tonumber(nx)or 0)-nativePointer.x)>.002 or math.abs((tonumber(ny)or 0)-nativePointer.y)>.002)then navigation.pointer()end
 nativePointer={x=tonumber(nx) or 0,y=tonumber(ny) or 0,inside=inside=='yes'}
 if not navigation.active and controlsDismissed and hover_controls() then controlsDismissed=false;castClosing=false end
 if sliderDrag then local w,h=mp.get_osd_size();sliderDrag(nativePointer.x*uiHeight()*w/h)end
 if dragging and mp.get_time()-lastSeek>0.10 then seek_at(nativePointer.x);lastSeek=mp.get_time()end
 update_visibility()
end)
mp.register_script_message('fua-native-button',function(nx,ny,mode)
 nx=tonumber(nx) or 0;ny=tonumber(ny) or 0
 navigation.pointer()
 if mode=='up' then if sliderDrag then local w,h=mp.get_osd_size();sliderDrag(nx*uiHeight()*w/h);sliderDrag=nil end;if dragging then seek_at(nx);dragging=false;pointerSeekTarget=nil end;update_visibility();return end
 local w,h=mp.get_osd_size();local width=uiHeight()*w/h;local x,y=nx*width,ny*uiHeight()
 if episodePanel.click(nx,ny)then update_visibility();return end
 if y>=uiHeight()-89-castLift and y<=uiHeight()-48-castLift and x>=28 and x<=width-28 and not menuKind then dragging=true;pointerSeekTarget=nil;seek_at(nx);update_visibility();return end
  if not visible then
  if pointer_inside() then
   local now=mp.get_time()
   if now-bodyClickAt<=0.4 and math.abs(x-bodyClickX)<12 and math.abs(y-bodyClickY)<12 then
    mp.set_property_bool('pause',bodyPauseBefore);bodyClickAt=-10;host('fullscreen')
   else
    bodyClickAt=now;bodyClickX=x;bodyClickY=y;bodyPauseBefore=mp.get_property_bool('pause');mp.commandv('cycle','pause')
   end
  end
  return
 end
 bodyClickAt=-10
 for i=#zones,1,-1 do local z=zones[i];if x>=z.x and x<=z.x+z.w and y>=z.y and y<=z.y+z.h then if z.slide then sliderDrag=z.slide end;z.fn(x,y);update_visibility();return end end
 if menuKind then menuKind=nil;update_visibility()
 elseif mp.get_property_native('user-data/fua-cast-open')==true then
  mp.set_property_native('user-data/fua-cast-open',false);controlsDismissed=true;castClosing=true;update_visibility()
 end
end)
-- Clicks are delivered once by the Windows host, including child video windows.
mp.add_forced_key_binding('MBTN_LEFT','fua-click',function()end)
mp.add_forced_key_binding('MBTN_LEFT_DBL','fua-double',function()end)
mp.add_forced_key_binding('ESC','fua-back',function()host('library')end)
mp.add_forced_key_binding('f','fua-full',function()host('fullscreen')end)
mp.observe_property('pause','bool',update_visibility)
mp.register_event('file-loaded',function()menuKind=nil;dragging=false;sliderDrag=nil;controlsDismissed=false;castClosing=false;castFrom=0;castAt=0;update_visibility()end)
mp.add_periodic_timer(1/45,function()if visible then update_visibility()end end)
mp.register_script_message('fua-hdr',function(label)hdrLabel=label;draw()end)
mp.msg.info('Fua overlay controls loaded - native pointer and clicks v2')



mp.register_script_message('fua-native-context',function(nx,ny)
 local w,h=mp.get_osd_size();menuX=(tonumber(nx) or 0)*uiHeight()*w/h;menuY=(tonumber(ny) or 0)*uiHeight()
 if menuKind then menuKind=nil else menuKind='main' end;bodyClickAt=-10;update_visibility()
end)
mp.add_forced_key_binding('MBTN_RIGHT','fua-context',function()end)

local languagePolicy=dofile(utils.join_path(scriptDir,'track-policy.lua'))
mp.add_hook('on_preloaded',50,function()
 local aid,sid=languagePolicy.choose(mp.get_property_native('track-list') or {},mp.get_property_number('aid'))
 if aid then mp.set_property('aid',tostring(aid))end
 mp.set_property('sid',tostring(sid))
 local audioLang,subLang,subForced='','','no'
 for _,track in ipairs(mp.get_property_native('track-list') or {})do
  if track.type=='audio' and track.id==aid then audioLang=track.lang or track.title or '' end
  if track.type=='sub' and tostring(track.id)==tostring(sid) then subLang=track.lang or track.title or '';subForced=track.forced and 'yes' or 'no' end
 end
 mp.set_property('user-data/fua-audio-language',audioLang);mp.set_property('user-data/fua-sub-language',subLang);mp.set_property('user-data/fua-sub-forced',subForced)
end)

local audioSwitchTimer=nil
select_audio=function(id)
 if audioSwitchTimer then audioSwitchTimer:kill();audioSwitchTimer=nil end
 local position=mp.get_property_number('time-pos',0)
 mp.set_property('aid',tostring(id))
 audioSwitchTimer=mp.add_timeout(0.15,function()
  audioSwitchTimer=nil
  if mp.get_property_number('aid')==tonumber(id) then mp.commandv('seek',position,'absolute+exact')end
 end)
end
mp.register_script_message('fua-select-audio',select_audio)
mp.register_event('end-file',function()if audioSwitchTimer then audioSwitchTimer:kill();audioSwitchTimer=nil end end)

-- The native host owns number keys, including when the video child has focus.
local userShortcuts={}
-- User shortcuts imported from mpv.net/input.conf.
userShortcuts['1']=function()mp.commandv('add','contrast',-1);mp.osd_message('Contraste: '..tostring(mp.get_property_number('contrast',0)),1)end
mp.add_forced_key_binding('1','fua-user-1',function()end)
userShortcuts['2']=function()mp.commandv('add','contrast',1);mp.osd_message('Contraste: '..tostring(mp.get_property_number('contrast',0)),1)end
mp.add_forced_key_binding('2','fua-user-2',function()end)
userShortcuts['3']=function()local value=math.max(-100,math.min(100,imageBrightness()+(-1)));setImageProperty('brightness',value);mp.osd_message('Brilho: '..value,1)end
mp.add_forced_key_binding('3','fua-user-3',function()end)
userShortcuts['4']=function()local value=math.max(-100,math.min(100,imageBrightness()+(1)));setImageProperty('brightness',value);mp.osd_message('Brilho: '..value,1)end
mp.add_forced_key_binding('4','fua-user-4',function()end)
userShortcuts['5']=function()mp.commandv('add','gamma',-1);mp.osd_message('Gama: '..tostring(mp.get_property_number('gamma',0)),1)end
mp.add_forced_key_binding('5','fua-user-5',function()end)
userShortcuts['6']=function()mp.commandv('add','gamma',1);mp.osd_message('Gama: '..tostring(mp.get_property_number('gamma',0)),1)end
mp.add_forced_key_binding('6','fua-user-6',function()end)
userShortcuts['7']=function()mp.commandv('add','saturation',-1);mp.osd_message('Saturação: '..tostring(mp.get_property_number('saturation',0)),1)end
mp.add_forced_key_binding('7','fua-user-7',function()end)
userShortcuts['8']=function()mp.commandv('add','saturation',1);mp.osd_message('Saturação: '..tostring(mp.get_property_number('saturation',0)),1)end
mp.add_forced_key_binding('8','fua-user-8',function()end)

mp.register_script_message('fua-user-shortcut',function(key)if userShortcuts[key]then userShortcuts[key]()end end)

mp.register_script_message('fua-open-shaders',function()menuKind='shaders';update_visibility()end)
mp.register_script_message('fua-open-image',function()menuKind='image';update_visibility()end)
mp.register_script_message('fua-cycle-audio',function()
 local tracks={};for _,track in ipairs(mp.get_property_native('track-list') or {})do if track.type=='audio' then tracks[#tracks+1]=track.id end end
 if #tracks==0 then return end;local current=mp.get_property_number('aid');local nextIndex=1
 for i,id in ipairs(tracks)do if id==current then nextIndex=i%#tracks+1;break end end;select_audio(tracks[nextIndex])
end)

-- Audio/subtitle menu navigation is independent of confirmation notifications.
openTracks=function(kind)
 if menuKind==kind then menuKind=nil;update_visibility();return end
 menuKind=kind;trackOffset=0;trackCursor=1;visible=true;draw()
 local id=mp.get_property(kind=='audio' and 'aid' or 'sid','no')
 for i,track in ipairs(trackChoices)do if tostring(track.id)==id then trackCursor=i;break end end
 trackOffset=math.max(0,math.min(#trackChoices-trackPageSize,trackCursor-math.floor(trackPageSize/2)))
 update_visibility()
end
mp.register_script_message('fua-open-tracks',openTracks)
mp.register_script_message('fua-menu-scroll',function(delta)
 if menuKind~='audio' and menuKind~='sub' then return end
 trackOffset=math.max(0,math.min(math.max(0,#trackChoices-trackPageSize),trackOffset+(tonumber(delta) or 0)))
 trackCursor=math.max(trackOffset+1,math.min(trackOffset+trackPageSize,trackCursor));draw()
end)
mp.register_script_message('fua-menu-key',function(key)
 if key=='Escape' then episodePanel.open=false;menuKind=nil;update_visibility();return end
 if menuKind~='audio' and menuKind~='sub' then return end
 if key=='Enter' then local track=trackChoices[trackCursor];if track then if menuKind=='audio' then select_audio(track.id)else mp.set_property('sid',tostring(track.id))end;menuKind=nil;update_visibility()end;return end
 local step=key=='Up' and -1 or key=='Down' and 1 or key=='PageUp' and -trackPageSize or key=='PageDown' and trackPageSize or 0
 if key=='Home' then trackCursor=1 elseif key=='End' then trackCursor=#trackChoices else trackCursor=math.max(1,math.min(#trackChoices,trackCursor+step))end
 if trackCursor<=trackOffset then trackOffset=trackCursor-1 elseif trackCursor>trackOffset+trackPageSize then trackOffset=trackCursor-trackPageSize end
 draw()
end)

-- Remote input is confined to playback. No header buttons participate in focus.
local function focusCast()
 local count=math.min(18,math.max(1,math.floor((W-160)/88)))
 if navigation.castIndex<=castOffset then moveCast(navigation.castIndex-1)
 elseif navigation.castIndex>castOffset+count then moveCast(navigation.castIndex-count)end
end
local function playerKey(key)
 controlsDismissed=false;castClosing=false
 if key=='Escape' then navigation.cancel();host('library');return end
 if key=='PageUp' or key=='PageDown' then
  menuKind=nil;navigation.touch();navigation.row='icons';navigation.focus='episodes'
  mp.set_property_native('user-data/fua-cast-open',false)
  if episodePanel.available()then
   if not episodePanel.open then episodePanel.toggle()end
   episodePanel.key(key)
  end
  update_visibility();return
 end
 if episodePanel.open then navigation.touch();episodePanel.key(key);update_visibility();return end
 if menuKind then
  navigation.touch()
  if menuKind=='audio' or menuKind=='sub' then
   if key=='Left' then menuKind=nil
   elseif key=='Enter' and menuKind=='sub' and trackCursor==#trackChoices+1 then menuKind=nil;host('subtitle-settings')
   elseif key=='Down' and menuKind=='sub' and trackCursor>=#trackChoices then trackCursor=#trackChoices+1
   else mp.commandv('script-message','fua-menu-key',key)end
   update_visibility();return
  end
  local entry=menuZones[menuIndex]
  if key=='Left' or key=='Right' then
   if entry and entry.adjust then entry.adjust(key=='Left' and -1 or 1)
   elseif key=='Left' then menuKind=menuParent;menuParent=nil;menuIndex=1;menuDraft={}end
  elseif key=='Up' or key=='Down' then menuIndex=math.max(1,math.min(#menuZones,menuIndex+(key=='Up' and -1 or 1)))
  elseif key=='Enter' and entry then
   if entry.confirm then entry.confirm()
   else local previous=menuKind;entry.fn(entry.x+entry.w/2,entry.y+entry.h/2);if menuKind~=previous then menuParent=menuKind and previous or nil;menuIndex=1;menuDraft={}end end
  end
  update_visibility();return
 end
 if key=='Up' then navigation.up()
 elseif key=='Down' then navigation.down()
 elseif key=='Left' or key=='Right' then navigation.horizontal(key=='Left' and -1 or 1);focusCast()
 elseif key=='Enter' then
  if navigation.row=='timeline' and navigation.pending==nil then
   navigation.touch();mp.commandv('cycle','pause')
  else
   navigation.activate()
   if menuKind then menuIndex=1;menuParent=nil;menuDraft={}
   elseif episodePanel.open then episodePanel.focus()end
  end
 end
 update_visibility()
end
mp.register_script_message('fua-player-key',playerKey)
mp.register_script_message('fua-player-cancel-preview',function()navigation.cancel();update_visibility()end)

-- K cycles useful media/statistics pages without consuming picture-adjustment keys.
local statsPages={1,2,3,5,0}
local statsIndex=0
local function closeStats()
 if statsIndex>0 then mp.commandv('script-binding','stats/display-stats-toggle')end
 statsIndex=0;mp.set_property('user-data/fua-stats-page','off')
end
mp.register_script_message('fua-stats-cycle',function()
 local nextIndex=statsIndex+1
 if statsIndex>0 then mp.commandv('script-binding','stats/display-stats-toggle')end
 if nextIndex>#statsPages then statsIndex=0;mp.set_property('user-data/fua-stats-page','off');return end
 statsIndex=nextIndex
 mp.commandv('script-binding','stats/display-page-'..statsPages[statsIndex]..'-toggle')
 mp.set_property('user-data/fua-stats-page',tostring(statsPages[statsIndex]))
end)
mp.register_script_message('fua-stats-close',closeStats)
mp.register_event('start-file',closeStats)

mp.register_script_message('fua-system-volume',function(volume,muted)
 local nextVolume=tonumber(volume) or 100;if math.abs(nextVolume-mp.get_property_number('user-data/fua-system-volume',nextVolume))>0.05 then volumeFeedbackUntil=mp.get_time()+1.2 end
 mp.set_property_native('user-data/fua-system-volume',nextVolume)
 mp.set_property('user-data/fua-system-mute',muted)
 if visible then draw()end
end)

mp.observe_property('user-data/fua-hdr-xp-mode','string',function()if draw then draw()end end)
