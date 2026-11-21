local mp=require 'mp'
local utils=require 'mp.utils'
local options={mode='capture',output='',report=''}
require('mp.options').read_options(options,'jxl-test')
mp.register_event('file-loaded',function()
 mp.add_timeout(.4,function()
  local source=mp.get_property_native('video-params')
  local ok,err=true,nil
  if options.mode=='capture'then local result;result,err=mp.command_native({'screenshot-to-file',options.output,'subtitles'});ok=err==nil end
  local f=assert(io.open(options.report,'w'));f:write(utils.format_json({video=source,ok=ok,error=tostring(err)}));f:close()
  if options.mode~='capture'or not ok then mp.commandv('quit',ok and 0 or 1);return end
  local deadline=mp.get_time()+15;local timer
  timer=mp.add_periodic_timer(.1,function()local file=utils.file_info(options.output);if file and file.size>0 then timer:kill();mp.commandv('quit',0)elseif mp.get_time()>deadline then timer:kill();mp.commandv('quit',1)end end)
 end)
end)
