local mp=require 'mp'
local utils=require 'mp.utils'
local assdraw=require 'mp.assdraw'
local root=utils.split_path(debug.getinfo(1,'S').source:gsub('^@',''))
local panel={open=false,amount=0,items={},offset=0,scroll=0,loading=false}
local overlay=mp.create_osd_overlay('ass-events');overlay.z=-1
local generation,photos,zones,lastHover,hoverAt=0,{},{},nil,0
local zoom={}
local lastFrame=mp.get_time()
local rowStep=140
local function listBottom()return 620-(mp.get_property_number and mp.get_property_number('user-data/fua-bottom-lift',0) or 0)end
local function maxScroll()return math.max(0,73+math.max(0,#panel.items-1)*rowStep+116-listBottom()+8)end
local function textWidth(value)
 local width=0
 for char in value:gmatch('[%z\1-\127\194-\244][\128-\191]*')do
  width=width+(char:match('[ilIjt%.,:!| ]') and 3.5 or char:match('[MWmw@]') and 11 or char:byte()>=227 and 13 or 7)
 end
 return width
end
local function clearPhotos()for id in pairs(photos)do mp.commandv('overlay-remove',id)end;photos={}end
local function hide()clearPhotos();overlay:remove();zones={}end
function panel.active()return panel.open or panel.amount>.002 end
function panel.toggle()panel.open=not panel.open end
function panel.available()return #panel.items>0 end
function panel.wheel(nx,ny,delta)
 local w,h=mp.get_osd_size();local W=720*w/h
 if not panel.open or nx*W<W-230 or ny*720<65 or ny*720>listBottom() then return false end
 panel.offset=math.max(0,math.min(maxScroll(),panel.offset-(tonumber(delta)or 0)/120*95));return true
end
function panel.click(nx,ny)
 if not panel.open then return false end
 local w,h=mp.get_osd_size();local x,y=nx*720*w/h,ny*720
 if y<65 or y>listBottom() then return false end
 for _,z in ipairs(zones)do if x>=z.x and x<=z.x+z.w and y>=z.y and y<=z.y+z.h then
  if not z.item.current then mp.commandv('script-message','fua-host','episode:'..z.item.id)end
  panel.open=false;return true
 end end
 if x<720*w/h-230 then panel.open=false end
 return true
end
function panel.draw(visible,nx,ny)
 local now=mp.get_time();local dt=math.min(.1,now-lastFrame);lastFrame=now
 panel.amount=panel.amount+((panel.open and 1 or 0)-panel.amount)*(1-math.exp(-dt*10))
 panel.scroll=panel.scroll+(panel.offset-panel.scroll)*(1-math.exp(-dt*12))
 if math.abs(panel.amount-(panel.open and 1 or 0))<.002 then panel.amount=panel.open and 1 or 0 end
 if math.abs(panel.scroll-panel.offset)<.05 then panel.scroll=panel.offset end
 if not visible or panel.amount<.002 then hide();return end
 local w,h=mp.get_osd_size();local W,H=720*w/h,720;local x=W-220+(1-panel.amount)*240
 local a=assdraw.ass_new();overlay.res_x=W;overlay.res_y=H;zones={};local used={}
 local function box(bx,by,bw,bh,color,alpha)
  a:new_event();a:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H%02X&}',color,alpha));a:draw_start();a:rect_cw(bx,by,bx+bw,by+bh);a:draw_stop()
 end
 local function text(tx,ty,value,size,color,clip)
  a:new_event();a:append(string.format('{\\an4\\pos(%.2f,%.2f)\\fnSegoe UI\\fs%.2f\\b1\\bord0\\shad0\\1c&H%s&}',tx,ty,size,color));if clip then a:append(string.format('{\\clip(%.2f,%.2f,%.2f,%.2f)}',x+24,65,W-12,listBottom()))end
  a:append(tostring(value):gsub('\\','＼'):gsub('{',''):gsub('}',''))
 end
 -- A single translucent full-height bar; controls remain above this layer.
 box(x,0,220,H,'18120C',48)
 local hovered=nil
 for i,item in ipairs(panel.items)do
  local y=73+(i-1)*rowStep-panel.scroll
  if y<listBottom() and y+116>65 then
   local bx=x+28;local bw=184;local bh=103.5;local id=48+(i%12)
   -- Cards use a 16:9 image with the title immediately below it.
   bw=176;bh=99
   local hot=nx*W>=bx and nx*W<=bx+bw and ny*H>=y and ny*H<=y+116
   if hot then hovered=i end
   zoom[i]=(zoom[i]or 0)+((hot and 1 or 0)-(zoom[i]or 0))*(1-math.exp(-dt*14))
   if math.abs(zoom[i]-(hot and 1 or 0))<.002 then zoom[i]=hot and 1 or 0 end
   local imageWidth,imageHeight=bw*(1+.035*zoom[i]),bh*(1+.035*zoom[i])
   local imageX,imageY=bx-(imageWidth-bw)/2,y-(imageHeight-bh)/2
   local imageTop,imageBottom=math.max(65,imageY),math.min(listBottom(),imageY+imageHeight)
   if item.file and imageBottom>imageTop then
    local sourceTop=imageY>=65 and 0 or math.min(179,math.max(0,math.floor((imageTop-imageY)/imageHeight*180+.5)));local sourceBottom=imageY+imageHeight<=listBottom() and 180 or math.min(180,math.floor((imageBottom-imageY)/imageHeight*180+.5));local sourceHeight=math.max(1,sourceBottom-sourceTop)
    local px,py,pw,ph=math.floor(imageX*w/W+.5),math.floor(imageTop*h/H+.5),math.floor(imageWidth*w/W+.5),math.max(1,math.floor((imageBottom-imageTop)*h/H+.5))
    local key=table.concat({item.file,px,py,pw,ph,sourceTop,sourceHeight},':')
    if photos[id]~=key then mp.command_native({name='overlay-add',id=id,x=px,y=py,file=item.file,offset=sourceTop*1280,fmt='bgra',w=320,h=sourceHeight,stride=1280,dw=pw,dh=ph});photos[id]=key end;used[id]=true
   elseif not item.file and imageBottom>imageTop then box(bx,imageTop,bw,imageBottom-imageTop,'30251C',40);if y>=65 then text(bx+12,y+bh/2,item.current and 'Reproduzindo' or 'Episódio',13,'DBD3C9')end end
   local title=tostring(item.title or '')
   local overflow=math.max(0,(tonumber(item.titleWidth)or textWidth(title))-bw)
   local shift=0
   if hot and lastHover==i and overflow>0 then local t=math.max(0,now-hoverAt-.7);shift=overflow*(.5-.5*math.cos(math.min(1,t/math.max(2,overflow/28))*math.pi))end
   if not hot and overflow>0 then local out={};local n=0;for ch in title:gmatch('[%z\1-\127\194-\244][\128-\191]*')do n=n+1;if textWidth(table.concat(out)..ch..'…')>bw then break end;out[#out+1]=ch end;title=table.concat(out)..'…'end
   if y+110>=70 and y+110<=listBottom()-5 then text(bx-shift,y+110,title,13,item.current and 'E6C28A' or 'E8E0D7',true)end
   zones[#zones+1]={x=bx,y=math.max(65,y),w=bw,h=math.min(listBottom(),y+116)-math.max(65,y),item=item}
  end
 end
 if hovered~=lastHover then lastHover=hovered;hoverAt=now end
 for id in pairs(photos)do if not used[id]then mp.commandv('overlay-remove',id);photos[id]=nil end end
 if panel.loading and #panel.items==0 then text(x+28,90,'Carregando episódios…',13,'E8E0D7')end
 overlay.data=a.text;overlay:update()
end
mp.register_event('start-file',function()generation=generation+1;panel.open=false;panel.amount=0;panel.items={};panel.loading=false;panel.offset=0;panel.scroll=0;zoom={};lastHover=nil;hide();mp.set_property_native('user-data/fua-episodes-available',false)end)
mp.register_event('file-loaded',function()
 local file=mp.get_property('path');if not file then return end
 local token=generation;panel.loading=true
 mp.command_native_async({name='subprocess',args={utils.join_path(root,'EpisodeArtwork.exe'),file},playback_only=true,capture_stdout=true,capture_stderr=true},function(ok,result)
  if token~=generation then return end;panel.loading=false
  if ok and result and result.status==0 then local data=utils.parse_json(result.stdout or '');panel.items=data and data.episodes or {} end
  for i,item in ipairs(panel.items)do if item.current then panel.offset=math.max(0,math.min(maxScroll(),(i-1)*rowStep-rowStep));panel.scroll=panel.offset;break end end
  mp.set_property_native('user-data/fua-episodes-available',#panel.items>0)
 end)
end)
mp.register_event('shutdown',hide)
return panel
