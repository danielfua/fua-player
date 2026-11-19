const bundledDetails={titles:{},files:{}};
// Bundled artwork cache also supports an already-running library service.
const bundledArtwork={};
function titleArtwork(g){const h=el('h1','media-heading');if(!g.logo){h.textContent=g.title;return h}const image=el('img','media-title-logo');image.src=g.logo;image.alt=g.title;image.decoding='async';image.onerror=()=>{h.replaceChildren();h.textContent=g.title};h.append(image);return h}
const $=id=>document.getElementById(id);let lastSignature='',titles=[],filter='all',query='',selected=null,pollTimer,toastTimer,refreshing=false;
const fold=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase(),time=ms=>Math.floor(ms/60000)+':'+String(Math.floor(ms/1000)%60).padStart(2,'0');
function el(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e}
function button(text,cls,fn){const b=el('button',cls,text);b.onclick=fn;return b}
function toast(message){$('toast').textContent=message;$('toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').hidden=true,6000)}
let refreshOpenEpisodes=null;
async function refreshAfterPlayback(){await fetch("/api/maintenance/flush",{method:"POST"}).catch(()=>{});while(refreshing)await new Promise(resolve=>setTimeout(resolve,50));await load();}
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
const trailerRequests=new Map();
let trailerDialog=null;
const unavailableTrailers=new Set();
let youtubeReady;
function youtubeApi(){
 if(window.YT?.Player)return Promise.resolve(window.YT);
 if(youtubeReady)return youtubeReady;
 youtubeReady=new Promise((resolve,reject)=>{
  const previous=window.onYouTubeIframeAPIReady;
  window.onYouTubeIframeAPIReady=()=>{previous?.();resolve(window.YT);};
  const script=document.createElement('script');script.src='https://www.youtube.com/iframe_api';
  const timeout=setTimeout(()=>{youtubeReady=null;reject(Error('YouTube indisponível'));},15000);
  script.onerror=()=>{clearTimeout(timeout);youtubeReady=null;reject(Error('YouTube indisponível'));};
  script.onload=()=>{if(window.YT?.Player){clearTimeout(timeout);resolve(window.YT);}};
  document.head.append(script);
 }).then(yt=>yt);
 return youtubeReady;
}
function openTrailer(g,video){
 if(trailerDialog)return;
 const dialog=el('dialog','trailer-dialog');trailerDialog=dialog;
 dialog.setAttribute('aria-label','Trailer de '+g.title);
 const frame=el('iframe','trailer-frame');
 frame.title='Trailer de '+g.title;
 frame.referrerPolicy='strict-origin-when-cross-origin';
 frame.allow='autoplay; encrypted-media; picture-in-picture; fullscreen';
 frame.allowFullscreen=true;
 frame.src='https://www.youtube-nocookie.com/embed/'+video.key+'?autoplay=1&rel=0&enablejsapi=1&origin='+encodeURIComponent(location.origin);
 dialog.append(frame);
 let player;
 const previous=document.activeElement;
 dialog.addEventListener('close',()=>{player?.destroy();frame.src='about:blank';dialog.remove();trailerDialog=null;heroDeadline=Date.now()+8000;if(previous?.isConnected)previous.focus({preventScroll:true});},{once:true});
 dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close();}});
 document.body.append(dialog);dialog.showModal();frame.focus();
 const unavailable=()=>{
  if(trailerDialog!==dialog)return;
  unavailableTrailers.add(g.type+'/'+g.tmdb);
  document.querySelectorAll('.trailer-button').forEach(b=>{if(b.dataset.media===g.type+'/'+g.tmdb)b.remove();});
  dialog.close();
 };
 youtubeApi().then(yt=>{if(trailerDialog===dialog)player=new yt.Player(frame,{events:{onError:unavailable}});}).catch(()=>{if(trailerDialog===dialog)dialog.close();});
}
function recommendationMeta(g){
 const row=meta(g),key=g.type+'/'+g.tmdb;
 if(!g.tmdb||!['movie','tv'].includes(g.type))return row;
 if(!trailerRequests.has(key))trailerRequests.set(key,fetch('/api/shelf/trailer/'+key).then(async r=>{if(!r.ok)throw Error('Trailer indisponível');return (await r.json()).trailer;}).catch(()=>{trailerRequests.delete(key);return null;}));
 trailerRequests.get(key).then(video=>{if(!video||!row.isConnected||unavailableTrailers.has(key))return;const b=button('▶ Ver trailer','trailer-button',()=>openTrailer(g,video));b.dataset.media=key;b.setAttribute('aria-label','Ver trailer de '+g.title);row.append(b);});
 return row;
}

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
const localCastRequests=new Map();
function recommendationSummary(g,loadLocal=false){
 const layout=el('div','recommendation-summary');
  const synopsis=el('div','recommendation-synopsis');
 const description=el('p','hero-description',g.synopsis||'Sinopse indisponível.');
 description.tabIndex=0;description.setAttribute('aria-label','Sinopse completa · role para ler');
 synopsis.append(description);layout.append(synopsis);
 if(!g.cast?.length){
  const placeholder=el('div','recommendation-cast cast-empty');placeholder.setAttribute('aria-hidden','true');layout.append(placeholder);
  if(loadLocal&&g.tmdb){
   if(!localCastRequests.has(g.key))localCastRequests.set(g.key,fetch('/api/shelf/'+g.key+'/extra').then(async r=>{if(!r.ok)throw Error('Elenco indisponível');return (await r.json()).cast||[];}).catch(()=>{localCastRequests.delete(g.key);return [];}));
   localCastRequests.get(g.key).then(cast=>{if(!layout.isConnected||!cast.length)return;const section=recommendationSummary({...g,cast}).querySelector('.recommendation-cast');if(section)placeholder.replaceWith(section);});
  }
  return layout;
 }
 const section=el('section','recommendation-cast');section.setAttribute('aria-label','Elenco de '+g.title);
 const heading=el('div','recommendation-cast-heading');heading.append(el('h2','','Elenco'));
 const row=el('div','recommendation-cast-row');row.setAttribute('aria-label','Elenco completo disponível no TMDB');row.tabIndex=0;
 const updateFade=()=>row.classList.toggle('has-more',row.scrollWidth-row.clientWidth-row.scrollLeft>2);
 row.addEventListener('scroll',updateFade,{passive:true});
 const resize=new ResizeObserver(()=>{if(!row.isConnected){resize.disconnect();return;}updateFade();});resize.observe(row);
 requestAnimationFrame(updateFade);
 const controls=el('div','recommendation-cast-controls');
 for(const [direction,label] of [[-1,'Elenco anterior'],[1,'Próximo elenco']]){
  const b=button(direction<0?'‹':'›','',()=>row.scrollBy({left:direction*Math.max(180,row.clientWidth*.75),behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'}));
  b.setAttribute('aria-label',label);b.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="'+(direction<0?'M15 5L8 12L15 19':'M9 5L16 12L9 19')+'"/></svg>';controls.append(b);
 }
 heading.append(controls);
 for(const person of g.cast){
  const card=el('a','recommendation-person');card.href='https://www.themoviedb.org/person/'+person.id;card.target='_blank';card.rel='noopener noreferrer';
  card.setAttribute('aria-label','Ver perfil de '+person.name+' no TMDB');
  const placeholder=()=>{const p=el('span','recommendation-person-placeholder',person.name.slice(0,1));p.setAttribute('aria-hidden','true');return p;};
  if(person.photo){const image=el('img');image.src=person.photo;image.alt='';image.loading='lazy';image.decoding='async';image.onerror=()=>image.replaceWith(placeholder());card.append(image);}else card.append(placeholder());
  card.append(el('strong','',person.name),el('small','recommendation-character',person.character||''));
  card.setAttribute('aria-label',person.name+(person.character?' · '+person.character:'')+' · Ver perfil no TMDB');row.append(card);
 }
 section.append(controls,row);layout.append(section);return layout;
}
let heroDragNav=null;
function heroPagination(available,current){
 const nav=el('div','hero-pagination');nav.setAttribute('role','group');nav.setAttribute('aria-label','Escolher título do destaque');
 for(let i=0;i<available.length;i++){
  const dot=button('','hero-dot',()=>{heroDeadline=Date.now()+8000;heroKey=available[i].key;hero();});
  dot.setAttribute('aria-label','Mostrar '+available[i].title+' · '+(i+1)+' de '+available.length);
  dot.setAttribute('aria-pressed',String(i===current));nav.append(dot);
 }
 let dragging=false,moved=false,startX=0;const pick=x=>{const buttons=[...nav.children];return buttons.reduce((best,b,i)=>Math.abs(b.getBoundingClientRect().left+b.offsetWidth/2-x)<best.distance?{index:i,distance:Math.abs(b.getBoundingClientRect().left+b.offsetWidth/2-x)}:best,{index:0,distance:Infinity}).index};
 nav.addEventListener('pointerdown',e=>{if(e.button!==0)return;dragging=true;moved=false;startX=e.clientX;nav.setPointerCapture(e.pointerId);heroDragNav=nav;nav.classList.add('dragging');e.preventDefault()});
 nav.addEventListener('pointermove',e=>{if(!dragging)return;if(Math.abs(e.clientX-startX)>3)moved=true;if(!moved)return;const i=pick(e.clientX);if(heroKey!==available[i].key){heroKey=available[i].key;heroDeadline=Date.now()+8000;hero()}});
 const finish=e=>{const click=dragging&&!moved&&e?.type==='pointerup';const i=click?pick(e.clientX):null;dragging=false;heroDragNav=null;nav.classList.remove('dragging');if(click){heroDeadline=Date.now()+8000;heroKey=available[i].key;hero()}};nav.addEventListener('pointerup',finish);nav.addEventListener('pointercancel',finish);nav.addEventListener('lostpointercapture',finish);nav.addEventListener('click',e=>{if(moved){e.preventDefault();e.stopImmediatePropagation();moved=false}},true);
 nav.addEventListener('keydown',e=>{let target;if(e.key==='ArrowRight')target=(current+1)%available.length;else if(e.key==='ArrowLeft')target=(current-1+available.length)%available.length;else if(e.key==='Home')target=0;else if(e.key==='End')target=available.length-1;else return;e.preventDefault();e.stopPropagation();heroDeadline=Date.now()+8000;heroKey=available[target].key;hero();$('hero').querySelectorAll('.hero-dot')[target]?.focus({preventScroll:true});});
 requestAnimationFrame(()=>{const active=nav.children[current];if(nav.isConnected&&active)nav.scrollLeft=Math.max(0,active.offsetLeft-nav.offsetLeft-nav.clientWidth/2+active.clientWidth/2);});
 return nav;
}
function hero(step=0){const h=$('hero');h.hidden=filter==='video';if(h.hidden)return;const inTrending=filter==='all'&&heroSource==='trending';h.classList.toggle('hero-recommendation',inTrending);h.classList.add('hero-with-cast');const available=inTrending?(trendingTitles||[]):titles.filter(g=>filter==='movie'?g.type==='movie':filter==='tv'?g.type==='tv':filter==='continue'?!!g.resume:g.type!=='video');const context=inTrending?'trending':filter;if(heroFilter!==context){heroFilter=context;heroKey=null}let index=available.findIndex(g=>g.key===heroKey);if(index<0)index=Math.max(0,available.findIndex(g=>g.resume&&g.backdrop));if(step&&available.length)index=(index+step+available.length)%available.length;const g=available[index];if(!g){h.style.backgroundImage='';h.replaceChildren();if(filter==='all'){const content=el('div','hero-content');content.append(heroSources(),el('p','hero-description',inTrending?(trendingError||(trendingTitles?'Nenhum título em alta encontrado.':'Buscando os títulos em alta…')):'Sua biblioteca está vazia.'));h.append(content)}return}heroKey=g.key;h.style.backgroundImage=g.backdrop?'url("'+g.backdrop+'")':'';if(heroDragNav)h.querySelector('.hero-content')?.remove();else h.replaceChildren();const c=el('div','hero-content');if(filter==='all')c.append(heroSources());const artwork=titleArtwork(g),link=button('','hero-title-link',()=>details(g));link.setAttribute('aria-label','Ver detalhes de '+g.title);link.append(artwork);c.append(link,recommendationMeta(g),recommendationSummary(g,!inTrending));h.append(c);if(available.length>1){if(heroDragNav){[...heroDragNav.children].forEach((dot,i)=>dot.setAttribute('aria-pressed',String(i===index)));if(heroDragNav.parentNode!==h)h.append(heroDragNav)}else h.append(heroPagination(available,index));}c.animate([{opacity:.35,transform:'translateX(10px)'},{opacity:1,transform:'translateX(0)'}],{duration:220,easing:'ease-out'}); }
function visible(){return titles.filter(g=>(filter==='all'?g.type!=='video':filter==='continue'?!!g.resume:g.type===filter)&&(!query||query.split(/\s+/).every(t=>fold(g.title+' '+g.localTitle+' '+g.items.map(x=>x.name).join(' ')).includes(t))))}
function prepareHomeShelves(items){
 $('home-series')?.remove();
 if(filter!=='all')return null;
 const section=el('section','home-series');section.id='home-series';section.setAttribute('aria-label','Séries da biblioteca');
 const series=items.filter(g=>g.type==='tv');
 const heading=el('div','shelf-head home-series-head');heading.append(el('h2','','Séries'),el('p','',series.length+' títulos · '+series.reduce((n,g)=>n+g.items.length,0)+' arquivos'));
 const grid=el('div','grid');grid.setAttribute('aria-label','Séries da biblioteca');
 section.append(heading,grid);$('grid').after(section);return grid;
}
function shelfCard(g){const b=button('','poster-card',()=>details(g)),wrap=el('div','poster-wrap');if(g.poster){const img=el('img');img.src=g.poster.replace('/w342/','/w780/');img.srcset=g.poster.replace(/\/w\d+\//,'/w500/')+' 500w, '+g.poster.replace(/\/w\d+\//,'/w780/')+' 780w';img.sizes='(max-width:600px) 45vw, 22vw';img.alt='Capa de '+g.title;img.loading='lazy';img.onerror=()=>{img.remove();wrap.prepend(el('span','poster-placeholder',g.title.slice(0,2).toUpperCase()))};wrap.append(img)}else if(g.type==='video'){const img=el('img','local-thumbnail');img.src='/api/thumbnail/'+g.items[0].id;img.alt='Amostra do vídeo '+g.title;img.loading='lazy';img.onerror=()=>{img.remove();wrap.prepend(el('span','poster-placeholder','▷'))};wrap.append(img)}else wrap.append(el('span','poster-placeholder',g.title.slice(0,2).toUpperCase()));wrap.append(el('span','poster-shade'));const badge=g.resume?'Continuar · '+time(g.resume.position):g.watched===g.items.length?'✓ Assistido':g.type==='tv'?g.items.length+' episódios':!g.identified?'Arquivo local':'';if(badge)wrap.append(el('span','badge'+(g.resume?' resume':''),badge));b.append(wrap,el('h3','',g.title),el('p','',[g.year,g.type==='tv'?'Série':g.type==='movie'?'Filme':'Vídeo'].filter(Boolean).join(' · ')));b.setAttribute('aria-label',g.title+(g.resume?' · continuar em '+time(g.resume.position):''));return b}
function render(){
 document.body.classList.remove('local-videos');filter='all';const items=titles.filter(g=>!query||query.split(/\s+/).every(t=>fold(g.title+' '+g.localTitle+' '+g.items.map(x=>x.name).join(' ')).includes(t)));
 for(const id of ['home-series','home-continue','home-video'])$(id)?.remove();
 const mainHead=$('shelf-title').closest('.shelf-head');mainHead.id='home-movie';mainHead.dataset.shelf='movie';$('shelf-title').textContent='Filmes';$('shelf-kicker').textContent='';$('grid').replaceChildren();
 const groups=[['movie','Filmes',items.filter(g=>g.type==='movie')],['tv','Séries',items.filter(g=>g.type==='tv')],['continue','Continuar',items.filter(g=>g.resume)],['video','Vídeos locais',items.filter(g=>g.type==='video')]];let previous=$('grid');
 for(const [key,label,entries]of groups){let grid,count;if(key==='movie'){grid=$('grid');count=$('count')}else{const section=el('section','home-series home-section');section.id=key==='tv'?'home-series':'home-'+key;section.dataset.shelf=key;section.setAttribute('aria-label',label);const head=el('div','shelf-head');count=el('p');head.append(el('h2','',label),count);grid=el('div','grid');grid.setAttribute('aria-label',label);section.append(head,grid);previous.after(section);previous=section}count.textContent=entries.length+' títulos · '+entries.reduce((n,g)=>n+g.items.length,0)+' arquivos';for(const g of entries)grid.append(shelfCard(g));if(!entries.length)grid.append(el('p','empty',query?'Nenhum título encontrado nessa busca.':key==='continue'?'Nenhum título em andamento.':'Nenhum título nesta seção.'))}
 requestAnimationFrame(updateScrollTab)
}

async function load(){if(refreshing)return;refreshing=true;try{const r=await fetch('/api/shelf/library'),d=await r.json();if(!r.ok)throw Error(d.error);const signature=JSON.stringify(d.titles);if(signature!==lastSignature){titles=d.titles.map(g=>g.logo?g:{...g,...bundledArtwork[g.key]});lastSignature=signature;hero();render();if(selected&&refreshOpenEpisodes){const current=titles.find(g=>g.key===selected);if(current)refreshOpenEpisodes(current)}}const j=d.job;$('scan').classList.toggle('loading',j.running);$('scan').disabled=j.running;$('notice').textContent=j.running?'Buscando capas e sinopses · '+j.done+' de '+j.total:j.error||'';clearTimeout(pollTimer);if(j.running)pollTimer=setTimeout(load,1800)}catch(e){$('notice').textContent=e.message}finally{refreshing=false}}
async function scan(retry=false){$('scan').disabled=true;$('scan').classList.add('loading');$('notice').textContent='Identificando sua coleção…';try{const r=await fetch('/api/shelf/scan'+(retry?'?retry=1':''),{method:'POST'});if(!r.ok)throw Error('Não foi possível atualizar a coleção');await load()}catch(e){toast(e.message);$('scan').disabled=false;$('scan').classList.remove('loading')}}
function technicalLabel(t){const v=t?.video;return v?[v.resolution,v.codec,v.hdr,v.bitDepth?v.bitDepth+' bits':null].filter(Boolean).join(' · '):''}
function audioLabel(t){return [...new Set((t?.audio||[]).map(a=>[a.technology||a.codec,a.channels?a.channels+' canais':null].filter(Boolean).join(' · ')))].join(' / ')}

function trackLanguage(track){
 const raw=(track.language||'und').replaceAll('_','-');let name='Idioma não informado',region=null;
 try{const locale=new Intl.Locale(raw),code=locale.language;const br=code==='pt'&&(/br/i.test(locale.region||'')||/brazil|brasil|pt.?br/i.test(track.title||''));region=br?'BR':locale.region||locale.maximize().region;if(code==='und')region=null;name=code==='und'?name:new Intl.DisplayNames(['pt-BR'],{type:'language'}).of(br?'pt-BR':locale.toString())}catch{name=track.language||name}
 return {name,region}
}
function trackFlag(region){
 const img=el('img','track-flag');img.alt='';const neutral='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20"><circle cx="15" cy="10" r="8" fill="#376782"/><g fill="none" stroke="#b7d8ec"><circle cx="15" cy="10" r="7"/><ellipse cx="15" cy="10" rx="3" ry="7"/><path d="M8 10h14"/></g></svg>');img.onerror=()=>{img.onerror=null;img.src=neutral};img.src=/^[A-Z]{2}$/.test(region||'')?'/images/flags/'+region.toLowerCase()+'.svg':neutral;return img
}
function trackDetails(t){const container=el('div','file-tracks');for(const [label,tracks,audio]of [['Áudio',t?.audio,true],['Legendas',t?.subtitles,false]]){const section=el('section','file-track-section');section.tabIndex=0;section.setAttribute('aria-label',label+' disponíveis; lista rolável');section.append(el('h3','',label));if(!tracks?.length)section.append(el('p','track-empty',audio?'Nenhuma faixa de áudio informada.':'Nenhuma legenda embutida informada.'));for(const track of tracks||[]){const language=trackLanguage(track),line=el('div','file-track');line.append(trackFlag(language.region));const parts=[language.name,audio?([track.codec,track.technology&&track.technology!==track.codec?track.technology:null].filter(Boolean).join(' ')):track.codec,audio&&track.channels?track.channels+' canais':null,audio&&track.bitrate?Math.round(track.bitrate/1000)+' kb/s':null,track.forced?'Forçada':null,track.title];line.append(el('span','',parts.filter(Boolean).join(' · ')));section.append(line)}container.append(section)}return container}
function technicalPanel(t){const panel=el('dl','technical-data');function add(label,value){if(!value)return;panel.append(el('dt','',label),el('dd','',value))}add('Vídeo',technicalLabel(t));add('Resolução',t?.video?.width&&t?.video?.height?t.video.width+' × '+t.video.height:null);add('Taxa de quadros',t?.video?.fps?t.video.fps.toFixed(3).replace(/0+$/,'').replace(/\.$/,'')+' fps':null);add('Bitrate',t?.bitrate?(t.bitrate/1000000).toFixed(1)+' Mbps':null);add('Duração',t?.duration?Math.floor(t.duration/60)+' min':null);add('Arquivo',t?.size?(t.size/1073741824).toFixed(2)+' GB · '+(t.container||''):t?.container);const wrap=el('div','technical-layout');wrap.append(panel,trackDetails(t));return wrap}
async function enrichDetail(g,content,page){let extra=bundledDetails.titles[g.key]||{};try{const r=await fetch('/api/shelf/'+g.key+'/extra');if(r.ok){const v=await r.json();if(v.updated)extra=v}}catch{}if(selected!==g.key||page.hidden)return;
 const notes=el('div','detail-facts');if(extra.certification)notes.append(el('span','certification',extra.certification==='L'?'Livre':extra.certification+' anos'));if(extra.runtime)notes.append(el('span','',extra.runtime+' min'));const metadata=content.querySelector('.metadata');metadata?.after(notes);
 const credits=el('div','detail-credits');if(extra.directors?.length)credits.append(el('p','', 'Direção: '+extra.directors.join(', ')));if(extra.creators?.length)credits.append(el('p','', 'Criação: '+extra.creators.join(', ')));if(credits.children.length)content.append(credits);
 const item=g.resume||g.items[0];let tech=item?bundledDetails.files[item.id]:null;try{const r=item?await fetch('/api/shelf/file/'+item.id):null;if(r?.ok)tech=await r.json()}catch{}if(selected!==g.key||page.hidden)return;if(tech){const block=el('details','file-specs');block.append(el('summary','', 'Dados do arquivo · '+[technicalLabel(tech),audioLabel(tech)].filter(Boolean).join(' · ')),technicalPanel(tech));content.append(block)}
 if(extra.cast?.length){const cast=el('section','cast-section');cast.setAttribute('aria-label','Elenco');const row=el('div','cast-row');for(const person of extra.cast){const card=el(person.id?'a':'article','cast-card');if(person.id){card.href='https://www.themoviedb.org/person/'+person.id;card.target='_blank';card.rel='noopener noreferrer';card.setAttribute('aria-label','Ver perfil de '+person.name+' no TMDB')}if(person.photo){const photo=el('img');photo.src=person.photo;photo.alt='';photo.loading='lazy';photo.onerror=()=>photo.remove();card.append(photo)}else card.append(el('span','cast-placeholder',person.name.slice(0,1)));card.append(el('strong','',person.name),el('small','',person.character));row.append(card)}cast.append(row);page.insertBefore(cast,page.querySelector('.episode-section'))} }
let libraryScroll=0,libraryFocus=null;
function leaveDetails(){const d=$('details');d.hidden=true;selected=null;document.body.classList.remove('view-details');document.querySelector('body>main:not(#details)').hidden=false;requestAnimationFrame(()=>{window.scrollTo(0,libraryScroll);if(libraryFocus?.isConnected)libraryFocus.focus({preventScroll:true})});heroDeadline=Date.now()+8000;load()}
function backToLibrary(){if(history.state?.fuaDetail)history.back();else leaveDetails()}
window.addEventListener('popstate',()=>{const key=history.state?.fuaDetail;if(key){const g=titles.find(g=>g.key===key);if(g)details(g,false);else leaveDetails()}else leaveDetails()});
function details(g,push=true){if(!selected){libraryScroll=window.scrollY;libraryFocus=document.activeElement}if(push)history.pushState({fuaDetail:g.key},'',location.pathname+location.search+'#title='+g.key);selected=g.key;const d=$('details');d.replaceChildren();const h=el('div','detail-hero');if(g.backdrop)h.style.setProperty('--detail-backdrop','url("'+g.backdrop+'")');h.append(titleArtwork(g),meta(g),el('p','synopsis',g.synopsis||'Sinopse não disponível para este arquivo.'));const row=el('div','action-row'),item=g.resume||g.items.find(x=>!x.watched)||g.items[0],b=button(g.resume?'▶ Continuar · '+time(item.position):'▶ Assistir','primary',()=>play(item,b));if(g.type!=='tv'&&g.items.length){row.append(b);h.append(row);}if(!g.identified&&g.type!=='video')h.append(el('p','unmatched','Título ainda sem identificação no TMDB. O arquivo continua disponível para assistir.'));const layout=el('div','detail-layout');if(g.poster){const poster=el('img','detail-poster');poster.src=g.poster;poster.alt='Capa de '+g.title;poster.onerror=()=>poster.remove();layout.append(poster)}const content=el('div','detail-copy');[...h.children].forEach(n=>content.append(n));layout.append(content);h.append(layout);d.append(h);
 const section=el('section','episode-section'),head=el('div','episode-heading');head.append(el('h2','',g.type==='tv'?'Episódios disponíveis':g.type==='movie'?'Versões disponíveis':'Arquivos disponíveis'));const list=el('div');section.append(head,list);if(g.items.length&&(g.type!=='movie'||g.items.length>1))d.append(section);let season=g.resume?.season??g.items[0]?.season;if(g.type==='tv'&&g.items.length){
 head.hidden=true;section.classList.add('season-episodes');section.setAttribute('aria-label','Episódios disponíveis');
 const seasons=el('div','action-row detail-seasons');seasons.setAttribute('aria-label','Temporadas');
 for(const n of [...new Set(g.items.map(x=>x.season??1))].sort((a,b)=>a-b)){
 const seasonButton=button(n===0?'Especiais':'Temporada '+n,'secondary',()=>{season=n;for(const b of seasons.children)b.setAttribute('aria-pressed',String(b===seasonButton));episodes();requestAnimationFrame(()=>section.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'start'}))});
 seasonButton.setAttribute('aria-pressed',String(n===Number(season)));seasons.append(seasonButton)
 }
 content.querySelector('.synopsis').after(seasons)
 }
 const seasonInfo=new Map();let revision=0;async function episodes(fetchInfo=true){const rev=++revision;const items=g.items.filter(x=>g.type!=='tv'||(x.season??1)===Number(season));let info=seasonInfo.get(Number(season))||[];function paint(){list.replaceChildren();for(const item of items){const extra=info.find(e=>e.episode===item.episode),b=el('article','episode');let opening=false;const activate=async()=>{if(opening)return;opening=true;thumbButton.disabled=action.disabled=true;try{await play(item,action)}finally{opening=false;thumbButton.disabled=action.disabled=false}};const thumbButton=button('','episode-thumb-button',activate),action=button(episodeAction(item),'episode-play'+(item.position&&!item.watched?' has-resume':''),activate);thumbButton.setAttribute('aria-label',episodeAction(item)+' · '+(extra?.title||item.name));const thumb=extra?.still?el('img','episode-thumb'):el('span','episode-thumb',item.episode?String(item.episode).padStart(2,'0'):'▷');if(extra?.still){thumb.src=extra.still.replace('/w300/','/w780/');thumb.alt='';thumb.loading='lazy'}const body=el('div','episode-info');body.append(el('strong','',g.type==='tv'?(item.episode?'E'+String(item.episode).padStart(2,'0')+' · ':'')+(extra?.title||'Episódio '+(item.episode||'')):g.title),el('small','',label(item)+(extra?.runtime?' · '+extra.runtime+' min':'')));if(extra?.synopsis)body.append(el('p','',extra.synopsis));const file=el('div','file-name',item.name);body.append(file);const technical=bundledDetails.files[item.id];if(technical)body.append(el('small','episode-technical',[technicalLabel(technical),audioLabel(technical)].filter(Boolean).join(' · ')));thumbButton.append(thumb);b.append(thumbButton,body,action);list.append(b)}}paint();if(fetchInfo&&g.type==='tv'&&g.tmdb&&g.items.length){try{const r=await fetch('/api/shelf/'+g.key+'/season/'+season);const data=await r.json();if(rev!==revision||selected!==g.key||d.hidden)return;info=data.episodes||[];seasonInfo.set(Number(season),info);paint()}catch{}}}refreshOpenEpisodes=fresh=>{g={...g,...fresh};episodes(false)};d.hidden=false;document.body.classList.add('view-details');document.querySelector('body>main:not(#details)').hidden=true;window.scrollTo(0,0);episodes();enrichDetail(g,content,d)}
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&selected){e.preventDefault();backToLibrary()}});

document.querySelectorAll('nav button').forEach(b=>b.onclick=()=>{if(selected){history.replaceState(null,'',location.pathname+location.search);leaveDetails()}scrollToShelf(b.dataset.filter)});$('search').oninput=e=>{if(selected){history.replaceState(null,'',location.pathname+location.search);leaveDetails()}query=fold(e.target.value).trim();render()};$('scan').onclick=()=>scan(true);addEventListener('focus',()=>load());document.addEventListener('visibilitychange',()=>{if(!document.hidden)load()});setInterval(()=>{if(!document.hidden&&!!$('details').hidden)load()},20000);
(async()=>{await load();scan()})();



// Abertura original sintetizada localmente; nenhum áudio de terceiros.
(()=>{
 const intro=document.getElementById('fua-intro'),sound=document.getElementById('intro-sound'),full=document.getElementById('fullscreen');if(!intro)return;document.body.classList.add('intro-playing');const behind=[...document.querySelectorAll('.topbar,body>main')];behind.forEach(e=>e.inert=true);
 let enabled=true;try{enabled=localStorage.getItem('fua-intro-sound')!=='off'}catch{}let context=null,master=null,finished=false,timer;
 function setSound(){sound.setAttribute('aria-pressed',String(enabled));sound.title=enabled?'Desligar som da abertura':'Ligar som da abertura'}setSound();
 function stopSound(){if(context&&context.state!=='closed'){try{master?.gain.setTargetAtTime(0,context.currentTime,.04);setTimeout(()=>context?.close().catch(()=>{}),180)}catch{}}}
 function finish(skip=false){if(finished)return;finished=true;clearTimeout(timer);intro.setAttribute('aria-hidden','true');intro.inert=true;if(skip===true)stopSound();document.removeEventListener('keydown',key,true);const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches,duration=skip===true||reduced?120:350;
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

setInterval(()=>{if(document.querySelector('dialog[open]')||trailerDialog||document.hidden||document.body.classList.contains('intro-playing')||!$('details').hidden||$('hero').matches(':hover')||$('hero').contains(document.activeElement)){heroDeadline=Date.now()+8000;return}if(Date.now()>=heroDeadline){heroDeadline=Date.now()+8000;hero(1)}},500);

(()=>{const settings=button('','',()=>{if(window.chrome?.webview)window.chrome.webview.postMessage('settings');else toast('Abra as configurações pelo aplicativo instalado.')});settings.id='app-settings';settings.setAttribute('aria-label','Configurações, pastas e backup');settings.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><circle cx="12" cy="12" r="3"/><path d="M9.4 3.5l.5-1h4.2l.5 1 .4 1.8 1.5.9 1.8-.6 1.1.1 2.1 3.6-.5 1-1.4 1.2v1.8l1.4 1.2.5 1-2.1 3.6-1.1.1-1.8-.6-1.5.9-.4 1.8-.5 1H9.9l-.5-1-.4-1.8-1.5-.9-1.8.6-1.1-.1-2.1-3.6.5-1 1.4-1.2v-1.8L3 10.9l-.5-1 2.1-3.6 1.1-.1 1.8.6 1.5-.9z"/></svg>';document.querySelector('.tools')?.insertBefore(settings,document.getElementById('intro-sound'));})();

document.addEventListener('keydown',e=>{
 if(e.defaultPrevented||e.altKey||e.ctrlKey||e.metaKey||e.shiftKey||!['ArrowLeft','ArrowRight'].includes(e.key))return;
 if(selected||document.querySelector('dialog[open]')||document.body.classList.contains('intro-playing')||$('hero').hidden)return;
 if(e.target.closest?.('input,textarea,select,[contenteditable="true"],.recommendation-cast,.topbar,.grid'))return;
 e.preventDefault();heroDeadline=Date.now()+8000;hero(e.key==='ArrowRight'?1:-1);
 $('hero').querySelector('.hero-dot[aria-pressed="true"]')?.focus({preventScroll:true});
});

let scrollTabFrame=0;const sectionTargets={all:'hero',movie:'home-movie',tv:'home-series',continue:'home-continue',video:'home-video'};
function moveTabIndicator(key){const nav=document.querySelector('.topbar nav');let line=nav.querySelector('.nav-section-indicator');if(!line){line=el('span','nav-section-indicator');line.setAttribute('aria-hidden','true');nav.append(line)}for(const b of nav.querySelectorAll('button')){const active=b.dataset.filter===key;b.classList.toggle('active',active);if(active){b.setAttribute('aria-current','location');line.style.width=b.offsetWidth+'px';line.style.transform='translateX('+b.offsetLeft+'px)'}else b.removeAttribute('aria-current')}}
function updateScrollTab(){scrollTabFrame=0;syncHomeScrollHint();if(selected)return;const threshold=document.querySelector('.topbar').getBoundingClientRect().bottom+45;let key='all';for(const k of ['movie','tv','continue','video']){const target=$(sectionTargets[k]);if(target&&target.getBoundingClientRect().top<=threshold)key=k}moveTabIndicator(key)}
function scrollToShelf(key){const target=$(sectionTargets[key]);if(!target)return;const header=document.querySelector('.topbar').getBoundingClientRect().height;window.scrollTo({top:key==='all'?0:window.scrollY+target.getBoundingClientRect().top-header-20,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});heroDeadline=Date.now()+8000}
addEventListener('scroll',()=>{if(!scrollTabFrame)scrollTabFrame=requestAnimationFrame(updateScrollTab)},{passive:true});addEventListener('resize',()=>requestAnimationFrame(updateScrollTab));

// Return home inside the current document, without replaying startup audio or animation.
document.querySelector('.brand')?.addEventListener('click',e=>{if(e.ctrlKey||e.metaKey||e.shiftKey||e.altKey)return;e.preventDefault();history.replaceState(null,'',location.pathname+location.search);libraryScroll=0;libraryFocus=null;if(selected)leaveDetails();requestAnimationFrame(()=>{window.scrollTo({top:0,behavior:'instant'});updateScrollTab()})});

// Keep scrolling available while hiding its chrome on the opening artwork.
function syncHomeScrollHint(){document.documentElement.classList.toggle('home-at-top',window.scrollY<16)}
const homeScrollHint=button('','home-scroll-hint',()=>{const first=['movie','tv','continue','video'].find(k=>$(sectionTargets[k]));if(first)scrollToShelf(first)});
homeScrollHint.setAttribute('aria-label','Rolar para a coleção');
homeScrollHint.innerHTML='<svg viewBox="0 0 40 16" aria-hidden="true"><path d="M5 4 L20 11 L35 4"/></svg>';
document.body.append(homeScrollHint);syncHomeScrollHint();

// Align pagination with the cast captions, including after artwork changes.
let heroAlignmentFrame=0;
function scheduleHeroAlignment(){if(heroAlignmentFrame)return;heroAlignmentFrame=requestAnimationFrame(()=>{heroAlignmentFrame=0;const h=$('hero'),nav=h.querySelector('.hero-pagination'),cast=h.querySelector('.recommendation-person small')||h.querySelector('.recommendation-cast-row');if(!nav)return;if(!cast||innerWidth<=650){nav.style.removeProperty('top');nav.style.removeProperty('bottom');return}const baseline=cast.getBoundingClientRect().bottom-5;nav.style.top=(baseline-h.getBoundingClientRect().top-nav.offsetHeight/2)+'px';nav.style.bottom='auto'})}
new MutationObserver(scheduleHeroAlignment).observe($('hero'),{childList:true,subtree:true});
new ResizeObserver(scheduleHeroAlignment).observe($('hero'));
addEventListener('resize',scheduleHeroAlignment);$('hero').addEventListener('load',scheduleHeroAlignment,true);
document.fonts.ready.then(scheduleHeroAlignment);scheduleHeroAlignment();
