-- Small cached local flags. Overlay slots 0..11 belong to visible track rows.
local mp=require 'mp'
local utils=require 'mp.utils'
local root=utils.split_path(debug.getinfo(1,'S').source:gsub('^@',''))
local regions={['ar']='eg',['ara']='eg',['bg']='bg',['bul']='bg',['ca']='es',['cat']='es',['cs']='cz',['ces']='cz',['cze']='cz',['da']='dk',['dan']='dk',['de']='de',['deu']='de',['ger']='de',['el']='gr',['ell']='gr',['gre']='gr',['en']='us',['eng']='us',['es']='es',['spa']='es',['et']='ee',['est']='ee',['fa']='ir',['fas']='ir',['per']='ir',['fi']='fi',['fin']='fi',['fr']='fr',['fra']='fr',['fre']='fr',['he']='il',['heb']='il',['hi']='in',['hin']='in',['hr']='hr',['hrv']='hr',['hu']='hu',['hun']='hu',['id']='id',['ind']='id',['is']='is',['isl']='is',['ice']='is',['it']='it',['ita']='it',['ja']='jp',['jpn']='jp',['ko']='kr',['kor']='kr',['lt']='lt',['lit']='lt',['lv']='lv',['lav']='lv',['ms']='my',['msa']='my',['may']='my',['nb']='no',['nob']='no',['nl']='nl',['nld']='nl',['dut']='nl',['nn']='no',['nno']='no',['no']='no',['nor']='no',['pl']='pl',['pol']='pl',['pt']='br',['por']='br',['ro']='ro',['ron']='ro',['rum']='ro',['ru']='ru',['rus']='ru',['sk']='sk',['slk']='sk',['slo']='sk',['sl']='si',['slv']='si',['sq']='al',['sqi']='al',['alb']='al',['sr']='rs',['srp']='rs',['sv']='se',['swe']='se',['ta']='in',['tam']='in',['te']='in',['tel']='in',['th']='th',['tha']='th',['tr']='tr',['tur']='tr',['uk']='ua',['ukr']='ua',['ur']='pk',['urd']='pk',['vi']='vn',['vie']='vn',['zh']='cn',['zho']='cn',['chi']='cn',['bn']='bd',['ben']='bd',['tl']='ph',['fil']='ph',['af']='za',['afr']='za',['sw']='tz',['swa']='tz'}
local module={};local shown,used,assets={},{},{}
local function country(track)
 if track.id=='no'then return nil end
 local lang=tostring(track.lang or ''):lower():gsub('_','-')
 local title=tostring(track.title or ''):lower()
 if lang=='und'or lang==''then
  if title:find('portugu')then lang=(title:find('brasil')or title:find('brazil'))and 'pt-br'or 'pt'
  elseif title:find('english')then lang='en' elseif title:find('japan')then lang='ja' end
 end
 if lang=='es-419'then return 'mx'end
 if lang:find('hant')then return 'tw'end
 local region=lang:match('%-([a-z][a-z])$')
 if region then return region end
 local base=lang:match('^[a-z]+')
 if(base=='pt'or base=='por')and(title:find('brazil')or title:find('brasil'))then return 'br'end
 return regions[base]
end
function module.begin()used={}end
function module.draw(row,track,x,y,scale)
 local region=country(track);if not region then return false end
 if assets[region]==nil then local file=utils.join_path(root,'track-flags/'..region..'.bgra');assets[region]=utils.file_info(file)and file or false end
 local file=assets[region];if not file then return false end
 local id=row-1;local dw=math.max(1,math.floor(21*scale));local dh=math.max(1,math.floor(14*scale))
 local px,py=math.floor(x),math.floor(y-dh/2);local signature=table.concat({file,px,py,dw,dh},':')
 if shown[id]~=signature then mp.command_native({name='overlay-add',id=id,x=px,y=py,file=file,offset=0,fmt='bgra',w=96,h=64,stride=384,dw=dw,dh=dh});shown[id]=signature end
 used[id]=true;return true
end
function module.finish()for id in pairs(shown)do if not used[id]then mp.commandv('overlay-remove',id);shown[id]=nil end end end
function module.hide()used={};module.finish()end
module.country=country
mp.register_event('shutdown',module.hide)
return module
