const bundledDetails={titles:{},files:{}};
// Bundled artwork cache also supports an already-running library service.
const bundledArtwork={};
function titleArtwork(g){const h=el('h1','media-heading');if(!g.logo){h.textContent=g.title;return h}const image=el('img','media-title-logo');image.src=g.logo;image.alt=g.title;image.decoding='async';image.onerror=()=>{h.replaceChildren();h.textContent=g.title};h.append(image);return h}
const $=id=>document.getElementById(id);let lastSignature='',titles=[],filter='all',query='',selected=null,pollTimer,toastTimer,refreshing=false;
const fold=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase(),time=ms=>Math.floor(ms/60000)+':'+String(Math.floor(ms/1000)%60).padStart(2,'0');
function el(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e}
function button(text,cls,fn){const b=el('button',cls,text);b.onclick=fn;return b}
function toast(message){$('toast').textContent=message;$('toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').hidden=true,6000)}
function episodeAction(item){return item.watched?'↻ Assistir novamente':item.position?'▶ Continuar · '+time(item.position):'▶ Assistir'}
function label(item){return item.watched?'Assistido':item.position?'Retomar em '+time(item.position):'Ainda não assistido'}
async function play(item,b){if(b)b.disabled=true;try{const r=await fetch('/api/play',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:item.id})}),data=await r.json();if(!r.ok)throw Error(data.error||'Não foi possível abrir o vídeo');toast('Reproduzindo'+(data.resume?' · retomando em '+time(data.resume):''))}catch(e){toast(e.message)}finally{if(b)b.disabled=false}}
const ratingRequests = new Map();
function ratingBadge(source, logo, score, media, imdbId) {
 const badge = el('a','source-rating '+source);
 const search=encodeURIComponent(media.title);
 badge.href=source==='tmdb'
  ? 'https://www.themoviedb.org/'+media.type+'/'+media.tmdb
  : source==='imdb'
   ? (/^tt\d+$/.test(imdbId||'')?'https://www.imdb.com/title/'+imdbId+'/':'https://www.imdb.com/find/?q='+search)
   : 'https://www.rottentomatoes.com/search?search='+search;
 badge.target='_blank';
 badge.rel='noopener noreferrer';
 badge.setAttribute('aria-label', (source==='rotten'?'Rotten Tomatoes':logo)+' '+score);
 const mark = el('span','rating-brand',logo);
 mark.setAttribute('aria-hidden','true');
 if(source==='tmdb'){
  const image=el('img','tmdb-rating-logo');
  image.src='https://www.themoviedb.org/assets/2/v4/logos/v2/blue_square_2-d537fb228cf3ded904ef09b136fe3fec72548ebc1fea3fbbd1ad9e36364db38b.svg';
  image.alt='';
  image.onload=()=>mark.replaceChildren(image);
 }
 badge.append(mark,el('span','',score));
 return badge;
}
function meta(g){
 const row=el('div','metadata');
 const ratings=el('span','source-ratings');
 if(g.rating) ratings.append(ratingBadge('tmdb','TMDB',Number(g.rating).toFixed(1)+'/10',g));
 row.append(ratings);
 if(g.ratings){
  if(g.ratings.imdb) ratings.append(ratingBadge('imdb','IMDb',g.ratings.imdb+'/10',g,g.ratings.imdbId));
  if(g.ratings.rotten) ratings.append(ratingBadge('rotten','🍅',g.ratings.rotten,g));
 }else if(g.tmdb && (g.type==='movie'||g.type==='tv')){
  const key=g.type+'/'+g.tmdb;
  if(!ratingRequests.has(key)){
   const request=fetch('/api/shelf/ratings/'+key).then(response=>{
    if(!response.ok) throw Error('Notas indisponíveis');
    return response.json();
   }).catch(()=>{ratingRequests.delete(key);return {};});
   ratingRequests.set(key,request);
  }
  ratingRequests.get(key).then(async data=>{
   if(!data.imdb || !data.rotten){
    const local=titles.find(t=>t.type===g.type&&t.tmdb===g.tmdb);
    if(local){
     let stored=bundledDetails.titles[local.key]?.ratings;
     try{
      const response=await fetch('/api/shelf/'+local.key+'/extra');
      if(response.ok) stored=(await response.json()).ratings||stored;
     }catch{}
     data={...stored,...data};
    }
   }
   if(data.imdb) ratings.append(ratingBadge('imdb','IMDb',data.imdb+'/10',g,data.imdbId));
   if(data.rotten) ratings.append(ratingBadge('rotten','🍅',data.rotten,g));
  });
 }
 if(g.year)row.append(el('span','',g.year));row.append(el('span','',g.type==='tv'?'Série':g.type==='movie'?'Filme':'Vídeo local'));if(g.items.length>1)row.append(el('span','',g.items.length+' arquivos'));for(const genre of(g.genres||[]).slice(0,2))row.append(el('span','',genre));return row}
let heroKey=null,heroFilter=null,heroDeadline=Date.now()+8000;
let heroSource = 'library';
let trendingTitles;
let trendingError;
let loadingTrending = false;

function heroSources() {
 const controls = el('div','hero-sources');
 controls.setAttribute('role','group');
 controls.setAttribute('aria-label','Origem do destaque');
 for (const [source,label] of [['library','Minha biblioteca'],['trending','Em alta']]) {
  const choice = button(label,'',async () => {
   heroSource = source;
   heroDeadline = Date.now()+8000;
   hero();
   document.querySelector('.hero-sources [aria-pressed="true"]')?.focus({preventScroll:true});
   if (source !== 'trending' || loadingTrending || trendingTitles) return;
   loadingTrending = true;
   trendingError = null;
   try {
    const response = await fetch('/api/shelf/trending');
    const data = await response.json();
    if (!response.ok) throw Error(data.error || 'TMDB temporariamente indisponível.');
    trendingTitles = data.titles;
   } catch (error) {
    trendingError = error.message;
   } finally {
    loadingTrending = false;
    if (filter === 'all' && heroSource === 'trending') hero();
   }
  });
  choice.setAttribute('aria-pressed',String(heroSource === source));
  controls.append(choice);
 }
 return controls;
}
function hero(step=0){const h=$('hero');h.hidden=filter==='video';if(h.hidden)return;const inTrending=filter==='all'&&heroSource==='trending';const available=inTrending?(trendingTitles||[]):titles.filter(g=>filter==='movie'?g.type==='movie':filter==='tv'?g.type==='tv':filter==='continue'?!!g.resume:g.type!=='video');const context=inTrending?'trending':filter;if(heroFilter!==context){heroFilter=context;heroKey=null}let index=available.findIndex(g=>g.key===heroKey);if(index<0)index=Math.max(0,available.findIndex(g=>g.resume&&g.backdrop));if(step&&available.length)index=(index+step+available.length)%available.length;const g=available[index];if(!g){h.style.backgroundImage='';h.replaceChildren();if(filter==='all'){const content=el('div','hero-content');content.append(heroSources(),el('p','hero-description',inTrending?(trendingError||(trendingTitles?'Nenhum título em alta encontrado.':'Buscando os títulos em alta…')):'Sua biblioteca está vazia.'));h.append(content)}return}heroKey=g.key;h.style.backgroundImage=g.backdrop?'url("'+g.backdrop+'")':'';h.replaceChildren();const c=el('div','hero-content');if(filter==='all')c.append(heroSources());c.append(titleArtwork(g),meta(g),el('p','hero-description',g.synopsis||(inTrending?'Sinopse indisponível.':'Sua coleção particular, pronta para o próximo play.')));const local=inTrending?titles.find(t=>t.type===g.type&&t.tmdb===g.tmdb):g;if(local){const row=el('div','action-row'),item=local.resume||local.items.find(x=>!x.watched)||local.items[0];const b=button(local.resume?'▶ Continuar · '+time(item.position):'▶ Assistir','primary',()=>play(item,b));row.append(b,button('Detalhes e episódios','secondary',()=>details(local)));c.append(row)}else c.append(el('span','trending-caption','Em alta na semana · TMDB'));h.append(c);if(available.length>1){const arrows=el('div','hero-arrows');for(const [direction,label,path] of [[-1,'Título anterior','M15 5L8 12L15 19'],[1,'Próximo título','M9 5L16 12L9 19']]){const a=button('','hero-arrow',()=>{heroDeadline=Date.now()+8000;hero(direction)});a.setAttribute('aria-label',label);a.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="'+path+'"/></svg>';arrows.append(a)}h.append(arrows)} }
function visible(){return titles.filter(g=>(filter==='all'?g.type!=='video':filter==='continue'?!!g.resume:g.type===filter)&&(!query||query.split(/\s+/).every(t=>fold(g.title+' '+g.localTitle+' '+g.items.map(x=>x.name).join(' ')).includes(t))))}
function render(){document.body.classList.toggle('local-videos',filter==='video');const items=visible();document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('active',b.dataset.filter===filter));$('shelf-title').textContent={all:'Sua coleção',movie:'Seus filmes',tv:'Suas séries',continue:'Continue de onde parou',video:'Vídeos locais'}[filter];$('shelf-kicker').textContent='';$('count').textContent=items.length+' títulos · '+items.reduce((n,g)=>n+g.items.length,0)+' arquivos';$('grid').replaceChildren();for(const g of items){const b=button('','poster-card',()=>details(g)),wrap=el('div','poster-wrap');if(g.poster){const img=el('img');img.src=g.poster.replace('/w342/','/w780/');img.srcset=g.poster.replace(/\/w\d+\//,'/w500/')+' 500w, '+g.poster.replace(/\/w\d+\//,'/w780/')+' 780w';img.sizes='(max-width:600px) 45vw, 22vw';img.alt='Capa de '+g.title;img.loading='lazy';img.onerror=()=>{img.remove();wrap.prepend(el('span','poster-placeholder',g.title.slice(0,2).toUpperCase()))};wrap.append(img)}else if(g.type==='video'){const img=el('img','local-thumbnail');img.src='/api/thumbnail/'+g.items[0].id;img.alt='Amostra do vídeo '+g.title;img.loading='lazy';img.onerror=()=>{img.remove();wrap.prepend(el('span','poster-placeholder','▷'))};wrap.append(img)}else wrap.append(el('span','poster-placeholder',g.title.slice(0,2).toUpperCase()));wrap.append(el('span','poster-shade'));const badge=g.resume?'Continuar · '+time(g.resume.position):g.watched===g.items.length?'✓ Assistido':g.type==='tv'?g.items.length+' episódios':!g.identified?'Arquivo local':'';if(badge)wrap.append(el('span','badge'+(g.resume?' resume':''),badge));b.append(wrap,el('h3','',g.title),el('p','',[g.year,g.type==='tv'?'Série':g.type==='movie'?'Filme':'Vídeo'].filter(Boolean).join(' · ')));b.setAttribute('aria-label',g.title+(g.resume?' · continuar em '+time(g.resume.position):''));$('grid').append(b)}if(!items.length)$('grid').append(el('p','empty',query?'Nenhum título encontrado nessa busca.':'Nenhum título nesta seção.'));}
async function load(){if(refreshing)return;refreshing=true;try{const r=await fetch('/api/shelf/library'),d=await r.json();if(!r.ok)throw Error(d.error);const signature=JSON.stringify(d.titles);if(signature!==lastSignature){titles=d.titles.map(g=>g.logo?g:{...g,...bundledArtwork[g.key]});lastSignature=signature;hero();render();}const j=d.job;$('scan').classList.toggle('loading',j.running);$('scan').disabled=j.running;$('notice').textContent=j.running?'Buscando capas e sinopses · '+j.done+' de '+j.total:j.error||'';clearTimeout(pollTimer);if(j.running)pollTimer=setTimeout(load,1800)}catch(e){$('notice').textContent=e.message}finally{refreshing=false}}
async function scan(retry=false){$('scan').disabled=true;$('scan').classList.add('loading');$('notice').textContent='Identificando sua coleção…';try{const r=await fetch('/api/shelf/scan'+(retry?'?retry=1':''),{method:'POST'});if(!r.ok)throw Error('Não foi possível atualizar a coleção');await load()}catch(e){toast(e.message);$('scan').disabled=false;$('scan').classList.remove('loading')}}
function technicalLabel(t){const v=t?.video;return v?[v.resolution,v.codec,v.hdr,v.bitDepth?v.bitDepth+' bits':null].filter(Boolean).join(' · '):''}
function technicalPanel(t){const panel=el('dl','technical-data');function add(label,value){if(!value)return;panel.append(el('dt','',label),el('dd','',value))}add('Vídeo',technicalLabel(t));add('Resolução',t?.video?.width&&t?.video?.height?t.video.width+' × '+t.video.height:null);add('Taxa de quadros',t?.video?.fps?t.video.fps.toFixed(3).replace(/0+$/,'').replace(/\.$/,'')+' fps':null);add('Bitrate',t?.bitrate?(t.bitrate/1000000).toFixed(1)+' Mbps':null);add('Duração',t?.duration?Math.floor(t.duration/60)+' min':null);add('Arquivo',t?.size?(t.size/1073741824).toFixed(2)+' GB · '+(t.container||''):t?.container);return panel}
async function enrichDetail(g,content,page){let extra=bundledDetails.titles[g.key]||{};try{const r=await fetch('/api/shelf/'+g.key+'/extra');if(r.ok){const v=await r.json();if(v.updated)extra=v}}catch{}if(selected!==g.key||page.hidden)return;
 const notes=el('div','detail-facts');if(extra.certification)notes.append(el('span','certification',extra.certification==='L'?'Livre':extra.certification+' anos'));if(extra.runtime)notes.append(el('span','',extra.runtime+' min'));const metadata=content.querySelector('.metadata');metadata?.after(notes);
 const credits=el('div','detail-credits');if(extra.directors?.length)credits.append(el('p','', 'Direção: '+extra.directors.join(', ')));if(extra.creators?.length)credits.append(el('p','', 'Criação: '+extra.creators.join(', ')));if(credits.children.length)content.append(credits);
 const item=g.resume||g.items[0];let tech=bundledDetails.files[item.id];try{const r=await fetch('/api/shelf/file/'+item.id);if(r.ok)tech=await r.json()}catch{}if(selected!==g.key||page.hidden)return;if(tech){const block=el('details','file-specs');block.append(el('summary','', 'Dados do arquivo · '+technicalLabel(tech)),technicalPanel(tech));content.append(block)}
 if(extra.cast?.length){const cast=el('section','cast-section');cast.append(el('h2','','Elenco'));const row=el('div','cast-row');for(const person of extra.cast){const card=el(person.id?'a':'article','cast-card');if(person.id){card.href='https://www.themoviedb.org/person/'+person.id;card.target='_blank';card.rel='noopener noreferrer';card.setAttribute('aria-label','Ver perfil de '+person.name+' no TMDB')}if(person.photo){const photo=el('img');photo.src=person.photo;photo.alt='';photo.loading='lazy';photo.onerror=()=>photo.remove();card.append(photo)}else card.append(el('span','cast-placeholder',person.name.slice(0,1)));card.append(el('strong','',person.name),el('small','',person.character));row.append(card)}cast.append(row);page.insertBefore(cast,page.querySelector('.episode-section'))} }
let libraryScroll=0,libraryFocus=null;
function leaveDetails(){const d=$('details');d.hidden=true;selected=null;document.body.classList.remove('view-details');document.querySelector('body>main:not(#details)').hidden=false;requestAnimationFrame(()=>{window.scrollTo(0,libraryScroll);if(libraryFocus?.isConnected)libraryFocus.focus({preventScroll:true})});heroDeadline=Date.now()+8000;load()}
function backToLibrary(){if(history.state?.fuaDetail)history.back();else leaveDetails()}
window.addEventListener('popstate',()=>{const key=history.state?.fuaDetail;if(key){const g=titles.find(g=>g.key===key);if(g)details(g,false);else leaveDetails()}else leaveDetails()});
function details(g,push=true){if(!selected){libraryScroll=window.scrollY;libraryFocus=document.activeElement}if(push)history.pushState({fuaDetail:g.key},'',location.pathname+location.search+'#title='+g.key);selected=g.key;const d=$('details');d.replaceChildren();const h=el('div','detail-hero');if(g.backdrop)h.style.backgroundImage='url("'+g.backdrop+'")';const close=button('','detail-back',backToLibrary);close.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 12H5M12 5L5 12L12 19"/></svg><span>Biblioteca</span>';close.setAttribute('aria-label','Voltar à biblioteca');h.append(close,titleArtwork(g),meta(g),el('p','synopsis',g.synopsis||'Sinopse não disponível para este arquivo.'));const row=el('div','action-row'),item=g.resume||g.items.find(x=>!x.watched)||g.items[0],b=button(g.resume?'▶ Continuar · '+time(item.position):'▶ Assistir','primary',()=>play(item,b));if(g.type!=='tv'){row.append(b);h.append(row);}if(!g.identified&&g.type!=='video')h.append(el('p','unmatched','Título ainda sem identificação no TMDB. O arquivo continua disponível para assistir.'));const layout=el('div','detail-layout');if(g.poster){const poster=el('img','detail-poster');poster.src=g.poster;poster.alt='Capa de '+g.title;poster.onerror=()=>poster.remove();layout.append(poster)}const content=el('div','detail-copy');[...h.children].filter(n=>n!==close).forEach(n=>content.append(n));layout.append(content);h.append(layout);d.append(h);
 const section=el('section','episode-section'),head=el('div','episode-heading');head.append(el('h2','',g.type==='tv'?'Episódios disponíveis':g.type==='movie'?'Versões disponíveis':'Arquivos disponíveis'));const list=el('div');section.append(head,list);if(g.type!=='movie'||g.items.length>1)d.append(section);let season=g.resume?.season??g.items[0].season;if(g.type==='tv'){const s=el('select');s.setAttribute('aria-label','Temporada');for(const n of[...new Set(g.items.map(x=>x.season||1))].sort((a,b)=>a-b)){const o=el('option','',n===0?'Especiais':'Temporada '+n);o.value=n;s.append(o)}s.value=season;s.onchange=()=>{season=Number(s.value);episodes()};head.append(s)}
 let revision=0;async function episodes(){const rev=++revision;const items=g.items.filter(x=>g.type!=='tv'||(x.season||1)===Number(season));let info=[];function paint(){list.replaceChildren();for(const item of items){const extra=info.find(e=>e.episode===item.episode),b=button('','episode',()=>play(item,b));const thumb=extra?.still?el('img','episode-thumb'):el('span','episode-thumb',item.episode?String(item.episode).padStart(2,'0'):'▷');if(extra?.still){thumb.src=extra.still.replace('/w300/','/w780/');thumb.alt='';thumb.loading='lazy'}const body=el('div','episode-info');body.append(el('strong','',g.type==='tv'?(item.episode?'E'+String(item.episode).padStart(2,'0')+' · ':'')+(extra?.title||'Episódio '+(item.episode||'')):g.title),el('small','',label(item)+(extra?.runtime?' · '+extra.runtime+' min':'')));if(extra?.synopsis)body.append(el('p','',extra.synopsis));const file=el('div','file-name',item.name);body.append(file);const technical=bundledDetails.files[item.id];if(technical)body.append(el('small','episode-technical',technicalLabel(technical)));b.append(thumb,body,el('span','episode-play'+(item.position&&!item.watched?' has-resume':''),episodeAction(item)));list.append(b)}}paint();if(g.type==='tv'&&g.tmdb){try{const r=await fetch('/api/shelf/'+g.key+'/season/'+season);const data=await r.json();if(rev!==revision||selected!==g.key||d.hidden)return;info=data.episodes||[];paint()}catch{}}}d.hidden=false;document.body.classList.add('view-details');document.querySelector('body>main:not(#details)').hidden=true;window.scrollTo(0,0);episodes();enrichDetail(g,content,d);close.focus({preventScroll:true})}
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&selected){e.preventDefault();backToLibrary()}});

document.querySelectorAll('nav button').forEach(b=>b.onclick=()=>{if(selected){history.replaceState(null,'',location.pathname+location.search);leaveDetails()}filter=b.dataset.filter;hero();render()});$('search').oninput=e=>{if(selected){history.replaceState(null,'',location.pathname+location.search);leaveDetails()}query=fold(e.target.value).trim();render()};$('scan').onclick=()=>scan(true);addEventListener('focus',()=>load());document.addEventListener('visibilitychange',()=>{if(!document.hidden)load()});setInterval(()=>{if(!document.hidden&&!!$('details').hidden)load()},20000);
(async()=>{await load();scan()})();



// Abertura original sintetizada localmente; nenhum áudio de terceiros.
(()=>{
 const intro=document.getElementById('fua-intro'),sound=document.getElementById('intro-sound'),full=document.getElementById('fullscreen');if(!intro)return;document.body.classList.add('intro-playing');const behind=[...document.querySelectorAll('.topbar,body>main')];behind.forEach(e=>e.inert=true);
 let enabled=true;try{enabled=localStorage.getItem('fua-intro-sound')!=='off'}catch{}let context=null,master=null,finished=false,timer;
 function setSound(){sound.setAttribute('aria-pressed',String(enabled));sound.title=enabled?'Desligar som da abertura':'Ligar som da abertura'}setSound();
 function stopSound(){if(context&&context.state!=='closed'){try{master?.gain.setTargetAtTime(0,context.currentTime,.04);setTimeout(()=>context?.close().catch(()=>{}),180)}catch{}}}
 function finish(skip=false){if(finished)return;finished=true;clearTimeout(timer);intro.setAttribute('aria-hidden','true');intro.inert=true;stopSound();document.removeEventListener('keydown',key,true);const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches,duration=skip===true||reduced?120:350;
 if(duration===120){intro.classList.add('quick-leaving')}else{intro.classList.add('portal-out');const frame=intro.querySelector('.intro-logo-frame'),cover=intro.querySelector('.intro-cover'),r=frame.getBoundingClientRect(),cx=r.left+r.width*.46552,cy=r.top+r.height*.5628,base=r.width*(25/1740),begin=performance.now();
 const zoomEnd=Math.max(95,Math.hypot(innerWidth,innerHeight)/Math.max(base,1)*1.3);
 function animate(now){const p=Math.min(1,(now-begin)/duration),ease=p*p,zoom=Math.exp(Math.log(zoomEnd)*ease),radius=Math.max(0,(zoom-1)*base);frame.style.transformOrigin='46.552% 56.28%';frame.style.transform='scale('+zoom+')';const mask='radial-gradient(circle at '+cx+'px '+cy+'px,transparent 0px,transparent '+radius+'px,#000 '+(radius+1.5)+'px)';cover.style.maskImage=mask;cover.style.webkitMaskImage=mask;if(p<1)requestAnimationFrame(animate)}requestAnimationFrame(animate)}
 setTimeout(()=>{intro.remove();document.body.classList.remove('intro-playing');behind.forEach(e=>e.inert=false)},duration)
 }
 function key(e){if(['Escape','Enter',' '].includes(e.key)){e.preventDefault();e.stopImmediatePropagation();finish(true)}}
 document.addEventListener('keydown',key,true);
 sound.onclick=()=>{enabled=!enabled;try{localStorage.setItem('fua-intro-sound',enabled?'on':'off')}catch{}setSound();if(!enabled)stopSound()};
 full.onclick=()=>{if(window.chrome?.webview){window.chrome.webview.postMessage('fullscreen');return}if(document.fullscreenElement)document.exitFullscreen().catch(()=>{});else document.documentElement.requestFullscreen().catch(()=>{})};
 async function signature(){if(!enabled)return;try{const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;context=new Audio();if(context.state==='suspended'){const attempt=context.resume();await Promise.race([attempt,new Promise(r=>setTimeout(r,250))]);if(context.state!=='running'){context.close().catch(()=>{});return}}if(finished)return;master=context.createGain();master.gain.value=.22;master.connect(context.destination);const now=context.currentTime+.06;
 function tone(f,start,duration,volume,type='sine'){const osc=context.createOscillator(),gain=context.createGain();osc.type=type;osc.frequency.setValueAtTime(f,now+start);gain.gain.setValueAtTime(0,now+start);gain.gain.linearRampToValueAtTime(volume,now+start+.055);gain.gain.exponentialRampToValueAtTime(.0001,now+start+duration);osc.connect(gain);gain.connect(master);osc.start(now+start);osc.stop(now+start+duration+.03)}
 tone(130.8128,0,1.5,.65);tone(261.6256,.18,1.2,.32);tone(391.9954,.48,1.45,.32);tone(659.2551,.8,1.3,.2);tone(783.9909,.81,.9,.08);
 setTimeout(()=>{if(context?.state!=='closed')context.close().catch(()=>{})},2500);
 }catch{}}
 if(new URLSearchParams(location.search).get('intro')==='preview'){intro.classList.add('intro-preview');return}
 signature();timer=setTimeout(()=>finish(false),1250);
})();

// Controles da janela do aplicativo.
document.getElementById('close-app')?.addEventListener('click',()=>{if(window.chrome?.webview){window.chrome.webview.postMessage('close');return}window.close();setTimeout(()=>{if(!window.closed)toast('Use Alt+F4 para fechar esta janela do navegador.')},250)});


// Controles nativos discretos para a janela integrada.
if(window.chrome?.webview){
 const close=document.getElementById('close-app');
 const minimize=document.createElement('button');
 minimize.className=close?.className||'icon-button';
 minimize.title='Minimizar';minimize.setAttribute('aria-label','Minimizar');
 minimize.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M5 12h14"/></svg>';
 minimize.onclick=()=>window.chrome.webview.postMessage('minimize');
 close?.parentNode.insertBefore(minimize,close);
}

// A sombra mantém o contraste quando as capas passam sob o cabeçalho.
const fuaHeader=document.querySelector('.topbar');
const windowModeButton=document.getElementById('fullscreen');
function showWindowMode(fullscreen) {
 windowModeButton.setAttribute('aria-label', fullscreen ? 'Restaurar janela' : 'Tela cheia');
 windowModeButton.querySelector('path').setAttribute('d', fullscreen
  ? 'M4 9H9V4M20 9H15V4M9 20V15H4M15 20V15H20'
  : 'M9 4H4V9M15 4H20V9M4 15V20H9M20 15V20H15');
}
window.chrome?.webview?.addEventListener('message', event => {
 if (event.data === 'window:fullscreen' || event.data === 'window:normal')
  showWindowMode(event.data === 'window:fullscreen');
});
document.addEventListener('fullscreenchange', () => showWindowMode(Boolean(document.fullscreenElement)));
let headerDragStart;
const headerControls = 'button, a, input, select, textarea, label, [contenteditable]';
fuaHeader?.addEventListener('dblclick', event => {
 if (event.button !== 0 || event.target.closest(headerControls)) return;
 windowModeButton.click();
});
fuaHeader?.addEventListener('pointerdown', event => {
 if (event.button !== 0 || event.pointerType !== 'mouse' ||
     event.target.closest(headerControls)) return;
 headerDragStart = [event.clientX, event.clientY];
});
window.addEventListener('pointerup', () => { headerDragStart = null; });
window.addEventListener('pointercancel', () => { headerDragStart = null; });
window.addEventListener('pointermove', event => {
 if (!headerDragStart) return;
 if (!(event.buttons & 1)) {
  headerDragStart = null;
  return;
 }
 if (Math.hypot(event.clientX - headerDragStart[0], event.clientY - headerDragStart[1]) < 5) return;
 headerDragStart = null;
 window.chrome?.webview?.postMessage('drag-window');
});
const fuaHeaderScroll=()=>fuaHeader?.classList.toggle('is-scrolled',scrollY>32);
addEventListener('scroll',fuaHeaderScroll,{passive:true});fuaHeaderScroll();

// Returning from native playback must not assign keyboard focus to the brand link.
document.querySelector('.brand')?.setAttribute('tabindex','-1');
function clearPointerHints(){document.querySelectorAll('[title]').forEach(n=>n.removeAttribute('title'))}
clearPointerHints();new MutationObserver(clearPointerHints).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['title']});

setInterval(()=>{if(document.hidden||document.body.classList.contains('intro-playing')||!$('details').hidden||$('hero').matches(':hover')||$('hero').contains(document.activeElement)){heroDeadline=Date.now()+8000;return}if(Date.now()>=heroDeadline){heroDeadline=Date.now()+8000;hero(1)}},500);

(()=>{const settings=button('','',()=>{if(window.chrome?.webview)window.chrome.webview.postMessage('settings');else toast('Abra as configurações pelo aplicativo instalado.')});settings.id='app-settings';settings.setAttribute('aria-label','Configurações, pastas e backup');settings.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><circle cx="12" cy="12" r="3"/><path d="M9.4 3.5l.5-1h4.2l.5 1 .4 1.8 1.5.9 1.8-.6 1.1.1 2.1 3.6-.5 1-1.4 1.2v1.8l1.4 1.2.5 1-2.1 3.6-1.1.1-1.8-.6-1.5.9-.4 1.8-.5 1H9.9l-.5-1-.4-1.8-1.5-.9-1.8.6-1.1-.1-2.1-3.6.5-1 1.4-1.2v-1.8L3 10.9l-.5-1 2.1-3.6 1.1-.1 1.8.6 1.5-.9z"/></svg>';document.querySelector('.tools')?.insertBefore(settings,document.getElementById('intro-sound'));})();
