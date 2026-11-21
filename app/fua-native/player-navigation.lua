-- Player-only navigation. Timeline arrows seek immediately.
local module={}
function module.new(port)
 local n={active=false,shown=false,pinned=false,deadline=0,row='timeline',pending=nil,resume=false,focus='playback',castIndex=1,items={}}
 function n.reset()
  n.active=false;n.shown=false;n.pinned=false;n.deadline=0;n.row='timeline';n.pending=nil;n.resume=false;n.focus='playback';n.castIndex=1;n.items={}
 end
 function n.touch()n.active=true;n.shown=true;n.deadline=port.now()+5 end
 function n.tick()
  if n.shown and not n.pinned and n.row~='cast' and port.now()>=n.deadline then n.shown=false end
  return n.shown
 end
 function n.seekStep(direction)
  if port.duration()<=0 then return end
  n.cancel();port.seekRelative(direction*5);n.row='timeline';n.touch()
 end
 function n.confirm()
  if n.pending==nil then return false end
  local target,resume=n.pending,n.resume;n.pending=nil;n.resume=false
  port.seek(target);n.touch();return true
 end
 function n.cancel()n.pending=nil;n.resume=false end
 function n.up()
  n.active=true
  if n.shown and n.pinned then n.shown=false;n.pinned=false;port.cast(false)
  else n.touch();n.pinned=true end
  n.row='timeline'
 end
 function n.down()
  local shown=n.shown;n.touch()
  if not shown then n.row='timeline'
  elseif n.row=='timeline' then n.row='icons'
  elseif n.row=='icons' then n.row='cast';port.cast(true)
  end
 end
 function n.horizontal(direction)
  if not n.shown then n.row='timeline' end
  n.touch()
  if n.row=='timeline' then n.seekStep(direction);return end
  if n.row=='cast' then n.castIndex=math.max(1,math.min(math.max(1,port.castCount()),n.castIndex+direction));return end
  local index=1
  for i,item in ipairs(n.items)do if item.id==n.focus then index=i;break end end
  local nextItem=n.items[math.max(1,math.min(#n.items,index+direction))];if nextItem then n.focus=nextItem.id end
 end
 function n.add(id,fn)
  n.items[#n.items+1]={id=id,fn=fn}
  return n.active and n.shown and n.row=='icons' and n.focus==id
 end
 function n.activate()
  n.touch()
  if n.row=='timeline' then return n.confirm()end
  if n.row=='cast' then port.castActivate(n.castIndex);return true end
  for _,item in ipairs(n.items)do if item.id==n.focus then item.fn();return true end end
  return false
 end
 function n.pointer()n.active=false;n.shown=false;n.pinned=false;n.cancel()end
 return n
end
return module
