-- Pure selection policy; called once per file so manual choices remain available.
local policy={}
local function folded(s)return tostring(s or ''):lower():gsub('_','-')end
local function portuguese(t)
 local lang=folded(t.lang);local title=folded(t.title)
 return lang=='pt' or lang=='por' or lang:match('^pt%-') or title:match('pt%-?br') or title:find('brazil',1,true) or title:find('brasileir',1,true) or title:find('portugu',1,true)
end
local function forced(t)local title=folded(t.title);return t.forced or title:find('forced',1,true) or title:find('forç',1,true) or title:find('forc',1,true) or title:find('signs',1,true) or title:find('songs',1,true)end
local function rank(t)
 local lang,title=folded(t.lang),folded(t.title);local score=0
 if lang=='pt-br' or title:find('brazil',1,true) or title:find('brasileir',1,true) or title:match('pt%-?br')then score=score+100 end
 if lang=='pt-pt' or title:find('portugal',1,true) or title:match('pt%-?pt')then score=score-100 end
 if t.default then score=score+5 end
 if title:find('comment',1,true) or title:find('coment',1,true) or title:find('description',1,true)then score=score-200 end
 return score
end
function policy.choose(tracks,currentAudio)
 local audio=nil;local audioScore=-math.huge
 for _,t in ipairs(tracks)do if t.type=='audio' and portuguese(t) and rank(t)>audioScore then audio=t;audioScore=rank(t)end end
 if not audio then for _,t in ipairs(tracks)do if t.type=='audio' and t.original then audio=t;break end end end
 if not audio then for _,t in ipairs(tracks)do if t.type=='audio' and (t.id==currentAudio or t.selected)then audio=t;break end end end
 if not audio then for _,t in ipairs(tracks)do if t.type=='audio' then audio=t;break end end end
 local dubbed=audio and portuguese(audio);local sub=nil;local subScore=-math.huge
 for _,t in ipairs(tracks)do if t.type=='sub' and portuguese(t) and ((dubbed and forced(t)) or (not dubbed and not forced(t)))then local score=rank(t);if score>subScore then sub=t;subScore=score end end end
 return audio and audio.id or nil,sub and sub.id or 'no'
end
return policy
