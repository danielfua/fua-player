local mp=require 'mp'
local assdraw=require 'mp.assdraw'
local overlay=mp.create_osd_overlay('ass-events')
local utils=require 'mp.utils'
local scriptDir=utils.split_path(debug.getinfo(1,'S').source:gsub('^@',''))
local logoPath=utils.join_path(scriptDir,'fua-logo.bgra')
local logoKey=nil
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
local visible=false
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
local accent='E6C28A'
local menuX,menuY=28,100
local hoverLevels={}
local iconGeometry={}
local frameAt=mp.get_time()
local function esc(s)return tostring(s or ''):gsub('\\','\\e'):gsub('{','\\{'):gsub('}','\\}'):gsub('\n',' ')end
local function host(s)mp.commandv('script-message','fua-host',s)end
local function time(t)t=math.max(0,math.floor(t or 0));return t>=3600 and string.format('%d:%02d:%02d',t/3600,t/60%60,t%60) or string.format('%d:%02d',t/60,t%60)end
-- Thumbfast integration; a single temporary frame, no persistent timeline cache.
local previewSettings={width=480}
local previewData=os.getenv('FUA_DATA_DIR') or utils.join_path(scriptDir,'../data')
do local f=io.open(utils.join_path(previewData,'preview-settings.json'),'r');if f then local d=utils.parse_json(f:read('*a'));f:close();if type(d)=='table'then for k,v in pairs(d)do previewSettings[k]=v end end end end
local previewWidth=math.floor(math.max(240,math.min(960,tonumber(previewSettings.width) or 480)))
local preview={wanted=nil}
local draw
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
 local h=math.floor(previewWidth*r.height/r.width+.5)
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
 H=720;W=720*w/h
 mp.set_property_native('user-data/fua-controls-visible',visible)
 if not visible then preview.wanted=nil;hide_preview();overlay.data='';overlay:update();if logoKey then mp.commandv('overlay-remove',60);logoKey=nil end;return end
 local now=mp.get_time();local dt=math.min(0.1,now-frameAt);frameAt=now
 local a=assdraw.ass_new();zones={};local rawX,rawY=pointer_position();local mouseX,mouseY=rawX*W/w,rawY*H/h;local tooltip=nil;local tipX,tipY=0,0
 local function box(x,y,w,h,color,alpha)
  a:new_event();a:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H%s&}',color or 'FFFFFF',alpha or '00'));a:draw_start();a:rect_cw(x,y,x+w,y+h);a:draw_stop()
 end
 local function circle(x,y,r,color)
  a:new_event();a:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H00&}',color or accent));a:draw_start()
  for i=0,24 do local angle=i/24*math.pi*2;local px,py=x+math.cos(angle)*r,y+math.sin(angle)*r;if i==0 then a:move_to(px,py)else a:line_to(px,py)end end;a:draw_stop()
 end
 local function text(x,y,t,size,align,color)
  a:new_event();a:append(string.format('{\\an%d\\pos(%f,%f)\\fnSegoe UI\\fs%.2f\\bord0\\shad0\\1a&H00&\\1c&H%s&}',align or 5,x,y,size or 19,color or 'FFFFFF'));a:append(esc(t))
 end
  local function zone(x,y,w,h,fn,hint)
  zones[#zones+1]={x=x,y=y,w=w,h=h,fn=fn,hint=hint}
  local hot=pointer_inside() and mouseX>=x and mouseX<=x+w and mouseY>=y and mouseY<=y+h
  local key=string.format('%.0f:%.0f:%.0f',x,y,w)
  local level=hoverLevels[key] or 0;level=level+((hot and 1 or 0)-level)*math.min(1,dt*18);hoverLevels[key]=level
  -- Hover uses icon tint and scale, without button shadows or plates.
  if hot then tooltip=hint;tipX=x+w/2;tipY=y>H/2 and y-18 or y+h+22 end
  return level
 end
 local function icon(x,y,name,fn,hint)
    local hints={['≡']='Voltar à biblioteca',['♫']='Escolher áudio',['▤']='Escolher legenda',['◖']='Silenciar',['×']='Ativar som',play='Reproduzir',pause='Pausar',['↶']='Voltar 10 segundos',['↷']='Avançar 10 segundos',RTX='Ligar/desligar RTX HDR',['▣']='Salvar imagem do vídeo',['ⓘ']='Informações do vídeo',['⛶']='Tela cheia',['—']='Minimizar',['□']='Maximizar / restaurar'}
  local level=zone(x-21,y-22,42,44,fn,hint or hints[name] or 'Velocidade de reprodução')
  local active=(name=='A4K' and shaderIndex>1) or (name=='RTX' and hdrLabel:find('confirmado')) or (name=='♫' and menuKind=='audio') or (name=='▤' and menuKind=='sub') or (name=='≡' and menuKind=='main')
  local tint=(name=='×' and y<100 and level>0.08) and '6E62FF' or ((active or level>0.08) and accent or 'FFFFFF')
  local baseScale=({['▣']=0.82,['ⓘ']=0.88,['⛶']=0.88})[name] or 1
  local scale=baseScale*(1+0.10*level)
  local output=a
  local key=name..((name=='◖' and mp.get_property_number('volume',100)>35) and ':loud' or '')
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
  if name=='←' then path({{-2,-8},{-10,0},{-2,8}});stroke(-10,0,10,0)
  elseif name=='×' and y<100 then stroke(-7,-7,7,7);stroke(-7,7,7,-7)
  elseif name=='play' then path({{-6,-10},{-8,-9},{-8,9},{-6,10},{10,1.8},{11,0},{10,-1.8}},true)
  elseif name=='pause' then rect(-5,0,5,20,2.5);rect(5,0,5,20,2.5)
  elseif name=='≡' then
   for i=-1,1 do local yy=i*7;stroke(-10,yy,10,yy);local xx=i==0 and 5 or -4;stroke(xx,yy-3,xx,yy+3)end
  elseif name=='♫' or name=='◖' or name=='×' then
   path({{-9,-4},{-5,-4},{1,-9},{3,-8},{3,8},{1,9},{-5,4},{-9,4}},true)
   if name=='×' then stroke(7,-4,13,4);stroke(7,4,13,-4)
   else arc(1,0,7,-.7,.7);if name=='♫' or mp.get_property_number('volume',100)>35 then arc(1,0,11,-.7,.7)end end
  elseif name=='▤' then rect(0,0,23,17,3);stroke(-7,0,-1,0);stroke(3,0,7,0);stroke(-7,4,3,4)
  elseif name=='↶' or name=='↷' then
   local sign=name=='↶' and -1 or 1;local points={}
   for i=0,12 do local t=-math.pi*.8+math.pi*1.6*i/12;points[#points+1]={sign*math.cos(t)*10,-3+math.sin(t)*10}end;path(points)
   local px,py=sign*math.cos(-math.pi*.8)*10,-3+math.sin(-math.pi*.8)*10
   stroke(px,py,px+sign*5,py);stroke(px,py,px,py-5)
  elseif name=='RTX' then -- text only
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
   text(x,y,shaderIndex>1 and ('A4K · '..shaderProfiles[shaderIndex].short) or 'A4K',14*scale,5,shaderIndex>1 and accent or 'FFFFFF')
  elseif name=='RTX' then
   text(x,y,'RTX',16*scale,5,active and accent or 'FFFFFF')
  elseif name=='↶' or name=='↷' then text(x,y-3,'10',9*scale,5,tint)
  elseif name:match('^[%d%.]+×$') then text(x,y,name,15*scale,5,tint)end

 end
 local function slider(x,y,width,value,minimum,maximum,setter,hint)
  local fraction=math.max(0,math.min(1,(value-minimum)/(maximum-minimum)))
  box(x,y-1,width,3,'FFFFFF','B0');box(x,y-1,width*fraction,3,accent)
  circle(x+width*fraction,y,4,accent)
  local function update(px)setter(math.max(minimum,math.min(maximum,minimum+(px-x)/width*(maximum-minimum))))end
  zone(x-6,y-12,width+12,26,update,hint)
  zones[#zones].slide=update
 end
 for i=0,63 do box(0,H-192+i*3,W,3,'000000',string.format('%02X',math.floor(255-225*(i/63)^1.3)))end
  for i=0,35 do box(0,i*3,W,3,'000000',string.format('%02X',math.floor(35+220*(i/35)^1.2)))end
 icon(40,40,'←',function()host('library')end,'Voltar à biblioteca')
 icon(W-40,40,'×',function()host('close')end,'Fechar Fua Player')
 local title=mp.get_property('media-title','Fua Player');if #title>125 then title=title:sub(1,122)..'...'end
 text(28,H-105,title,20,4)
 local pos=mp.get_property_number('time-pos',0);local dur=mp.get_property_number('duration',0)
 local x1,x2,y=28,W-28,H-76
 box(x1,y,x2-x1,3,'FFFFFF','99');if dur>0 then box(x1,y,(x2-x1)*math.min(1,pos/dur),3,accent)end
 local mx,my=pointer_position();mx=mx*W/w;my=my*H/h
 local hover=pointer_inside() and mx>=x1 and mx<=x2 and my>=y-14 and my<=y+16
 if hover and dur>0 and not menuKind then local target=dur*math.max(0,math.min(1,(mx-x1)/(x2-x1)));preview_frame(target,math.max(165,math.min(w-165,mx*w/W)),y*h/H);text(mx,y-23,time(target),15)else hide_preview();preview.wanted=nil end
 if hover or mp.get_property_bool('pause')then circle(x1+(x2-x1)*(dur>0 and math.min(1,pos/dur) or 0),y+1.5,hover and 6 or 4.5,accent)end
 zone(x1,y-13,x2-x1,28,function(px)if dur>0 then mp.commandv('seek',math.max(0,math.min(1,(px-x1)/(x2-x1)))*dur,'absolute+exact')end end,'Ir para '..time(dur*math.max(0,math.min(1,(mouseX-x1)/(x2-x1)))))
 local cy=H-35
 icon(40,cy,'≡',function()if menuKind=='main' then menuKind=nil else menuKind='main';menuX=28;menuY=H-400 end;draw()end,'Menu do player')
 icon(84,cy,'♫',function()openTracks('audio')end)
 icon(128,cy,'▤',function()openTracks('sub')end)
 icon(172,cy,mp.get_property_bool('mute') and '×' or '◖',function()mp.commandv('cycle','mute')end)
 local vol=mp.get_property_number('volume',100);slider(196,cy,58,vol,0,100,function(v)mp.set_property_number('volume',v)end,'Volume · '..math.floor(vol)..'%')
 text(274,cy,time(pos)..' / '..time(dur),16,4)
 icon(W/2-62,cy,'↶',function()mp.commandv('seek',-10)end)
 icon(W/2,cy,mp.get_property_bool('pause') and 'play' or 'pause',function()mp.commandv('cycle','pause')end)
 icon(W/2+62,cy,'↷',function()mp.commandv('seek',10)end)
 local speed=mp.get_property_number('speed',1)
 icon(W-322,cy,'A4K',function()menuKind=menuKind=='shaders' and nil or 'shaders';draw()end,'Anime4K · '..shaderProfiles[shaderIndex].id)
 icon(W-248,cy,string.format('%.1f×',speed),function()mp.set_property_number('speed',speed>=2 and 0.5 or speed+0.25)end)
 icon(W-196,cy,'RTX',function()host('rtx')end)
 icon(W-144,cy,'▣',function()host('screenshot')end)
 icon(W-92,cy,'ⓘ',function()mp.commandv('script-message','fua-stats-cycle')end)
 icon(W-40,cy,'⛶',function()host('fullscreen')end)
 
 local label=hdrLabel
 -- HDR status is shown by the discreet RTX button, without a debug label.
  if menuKind=='audio' or menuKind=='sub' then
  local tracks=mp.get_property_native('track-list') or {};local choices={}
  if menuKind=='sub' then choices[#choices+1]={id='no',title='Desligar legendas'} end
  for _,tr in ipairs(tracks)do if tr.type==menuKind then choices[#choices+1]=tr end end
  trackChoices=choices
  local pw=math.min(500,W-56);local count=math.min(trackPageSize,#choices);trackOffset=math.max(0,math.min(trackOffset,#choices-count));local ph=count*30+76;local px=28;local py=H-90-ph
  box(px,py,pw,ph,'16100B','0B');text(px+18,py+21,menuKind=='audio' and 'Áudio' or 'Legendas',18,4)
  for row=1,count do local n=row+trackOffset;local tr=choices[n];local id=tr.id;local prop=menuKind=='audio' and 'aid' or 'sid';local label=tr.title or ((tr.lang or 'Faixa')..'  '..tostring(id));if tr.lang and tr.title then label=tr.lang..' · '..label end
   local ry=py+42+(row-1)*30;local chosen=tostring(mp.get_property(prop))==tostring(id)
   if chosen or n==trackCursor then box(px+8,ry,pw-30,29,'FFFFFF',chosen and 'E6' or 'F2')end
   local level=zone(px,ry,pw-24,30,function()if prop=='aid' then select_audio(id)else mp.set_property(prop,tostring(id))end;menuKind=nil;draw()end,'Selecionar '..label)
   text(px+18,ry+15,label,15+level,4,(chosen or level>0.08 or n==trackCursor) and accent or 'FFFFFF')
  end
  if #choices>count then
   local sy,sh=py+42,count*30;box(px+pw-12,sy,3,sh,'FFFFFF','D0');local thumb=math.max(20,sh*count/#choices);box(px+pw-13,sy+(sh-thumb)*trackOffset/math.max(1,#choices-count),5,thumb,accent)
   zone(px+pw-22,sy,22,sh,function(_,y)trackOffset=math.floor(math.max(0,math.min(1,(y-sy)/sh))*(#choices-count)+0.5);draw()end,'Rolar lista')
  end
  local fy=py+ph-17;text(px+18,fy,tostring(trackOffset+1)..'–'..tostring(trackOffset+count)..' de '..tostring(#choices),12,4,'C8B8A0')
  zone(px+pw-92,fy-14,36,28,function()trackOffset=math.max(0,trackOffset-count);draw()end,'Página anterior');text(px+pw-74,fy,'↑',19)
  zone(px+pw-50,fy-14,36,28,function()trackOffset=math.min(math.max(0,#choices-count),trackOffset+count);draw()end,'Próxima página');text(px+pw-32,fy,'↓',19)
  mp.set_property('user-data/fua-track-menu-state',menuKind..':'..trackOffset..':'..count..':'..#choices)
 end
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
 if menuKind=='image' then
  local pw,ph=330,264;local px=math.max(12,math.min(W-pw-12,menuX));local py=math.max(80,math.min(H-ph-100,menuY))
  box(px,py,pw,ph,'20160F','08');text(px+18,py+25,'Ajustes de imagem',19,4)
  local properties={{'Contraste','contrast'},{'Brilho','brightness'},{'Gama','gamma'},{'Saturação','saturation'}}
  for i,item in ipairs(properties)do
   local prop=item[2];local value=mp.get_property_number(prop,0);local ry=py+55+(i-1)*43
   text(px+18,ry,item[1],15,4);text(px+pw-18,ry,string.format('%+d',value),14,6,accent)
   slider(px+18,ry+15,pw-36,value,-100,100,function(v)mp.set_property_number(prop,math.floor(v+0.5))end,'Ajustar '..item[1]..' · centro = neutro')
  end
  zone(px+12,py+226,pw-24,30,function()for _,item in ipairs(properties)do mp.set_property_number(item[2],0)end;draw()end,'Restaurar os quatro ajustes')
  text(px+pw/2,py+241,'Restaurar padrão',14,5)
 end
 if menuKind=='main' then
  local pw=290;local px=math.max(12,math.min(W-pw-12,menuX));local py=math.max(80,math.min(H-365,menuY))
  box(px,py,pw,306,'20160F','08');text(px+18,py+25,'Menu do player',19,4)
  local choices={{'Play / pause',function()menuKind=nil;mp.commandv('cycle','pause')end},{'Atalhos de teclado…',function()menuKind=nil;host('shortcuts')end},{'Voltar à biblioteca',function()menuKind=nil;host('library')end},{'Ajustes de imagem',function()menuKind='image';menuX=28;menuY=H-390 end},{'Áudio',function()openTracks('audio')end},{'Legendas',function()openTracks('sub')end},{'Tela cheia / restaurar',function()menuKind=nil;host('fullscreen')end},{'Salvar imagem do vídeo',function()menuKind=nil;host('screenshot')end}} 
  for i,item in ipairs(choices)do local y=py+46+(i-1)*28;local level=zone(px+12,y,pw-24,28,item[2],item[1]);text(px+20,y+14,item[1],15+level,4,level>0.08 and accent or 'FFFFFF')end
 end

 mp.set_property_native('user-data/fua-menu-open',menuKind~=nil)
 mp.set_property_native('user-data/fua-track-menu',menuKind=='audio' or menuKind=='sub')
 overlay.res_x=W;overlay.res_y=H;overlay.data=a.text;overlay:update()
end
local function hover_controls()
 local x,y=pointer_position();local w,h=mp.get_osd_size()
 return pointer_inside() and h>0 and (y/h>=590/720 or y/h<=100/720)
end
local function update_visibility()
 visible=menuKind~=nil or (pointer_inside() and (hover_controls() or dragging or sliderDrag~=nil))
 draw()
end
local function seek_at(nx)
 local dur=mp.get_property_number('duration',0)
 local w,h=mp.get_osd_size();local width=720*w/h
 local fraction=math.max(0,math.min(1,(nx*width-28)/(width-56)))
 if dur>0 then mp.commandv('seek',fraction*dur,'absolute+exact')end
end
local lastSeek=0
local bodyClickAt=-10;local bodyClickX,bodyClickY=0,0;local bodyPauseBefore=false
mp.register_script_message('fua-native-pointer',function(nx,ny,inside)
 nativePointer={x=tonumber(nx) or 0,y=tonumber(ny) or 0,inside=inside=='yes'}
 if sliderDrag then local w,h=mp.get_osd_size();sliderDrag(nativePointer.x*720*w/h)end
 if dragging and mp.get_time()-lastSeek>0.10 then seek_at(nativePointer.x);lastSeek=mp.get_time()end
 update_visibility()
end)
mp.register_script_message('fua-native-button',function(nx,ny,mode)
 nx=tonumber(nx) or 0;ny=tonumber(ny) or 0
 if mode=='up' then if sliderDrag then local w,h=mp.get_osd_size();sliderDrag(nx*720*w/h);sliderDrag=nil end;if dragging then seek_at(nx);dragging=false end;update_visibility();return end
 local w,h=mp.get_osd_size();local width=720*w/h;local x,y=nx*width,ny*720
 if y>=720-89 and y<=720-48 and x>=28 and x<=width-28 and not menuKind then dragging=true;seek_at(nx);update_visibility();return end
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
 if menuKind then menuKind=nil;update_visibility()end
end)
-- Clicks are delivered once by the Windows host, including child video windows.
mp.add_forced_key_binding('MBTN_LEFT','fua-click',function()end)
mp.add_forced_key_binding('MBTN_LEFT_DBL','fua-double',function()end)
mp.add_forced_key_binding('ESC','fua-back',function()if menuKind then menuKind=nil;update_visibility()else host('library')end end)
mp.add_forced_key_binding('f','fua-full',function()host('fullscreen')end)
mp.observe_property('pause','bool',update_visibility)
mp.register_event('file-loaded',function()menuKind=nil;dragging=false;sliderDrag=nil;update_visibility()end)
mp.add_periodic_timer(1/30,function()if visible then update_visibility()end end)
mp.register_script_message('fua-hdr',function(label)hdrLabel=label;draw()end)
mp.msg.info('Fua overlay controls loaded - native pointer and clicks v2')



mp.register_script_message('fua-native-context',function(nx,ny)
 local w,h=mp.get_osd_size();menuX=(tonumber(nx) or 0)*720*w/h;menuY=(tonumber(ny) or 0)*720
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
userShortcuts['3']=function()mp.commandv('add','brightness',-1);mp.osd_message('Brilho: '..tostring(mp.get_property_number('brightness',0)),1)end
mp.add_forced_key_binding('3','fua-user-3',function()end)
userShortcuts['4']=function()mp.commandv('add','brightness',1);mp.osd_message('Brilho: '..tostring(mp.get_property_number('brightness',0)),1)end
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
 if key=='Escape' then menuKind=nil;update_visibility();return end
 if menuKind~='audio' and menuKind~='sub' then return end
 if key=='Enter' then local track=trackChoices[trackCursor];if track then if menuKind=='audio' then select_audio(track.id)else mp.set_property('sid',tostring(track.id))end;menuKind=nil;update_visibility()end;return end
 local step=key=='Up' and -1 or key=='Down' and 1 or key=='PageUp' and -trackPageSize or key=='PageDown' and trackPageSize or 0
 if key=='Home' then trackCursor=1 elseif key=='End' then trackCursor=#trackChoices else trackCursor=math.max(1,math.min(#trackChoices,trackCursor+step))end
 if trackCursor<=trackOffset then trackOffset=trackCursor-1 elseif trackCursor>trackOffset+trackPageSize then trackOffset=trackCursor-trackPageSize end
 draw()
end)

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
