import { createCanvas, GlobalFonts } from '@napi-rs/canvas';
import { createHash } from 'node:crypto';
import { graphemes, presentationSignature } from './codec.mjs';
GlobalFonts.loadSystemFonts();
const FONT = '"Hiragino Sans GB"';
const EMOJI_FONT = '"Apple Color Emoji"';
const cache = new Map(); let cacheBytes = 0;
const MAX_CACHE_BYTES = 16 * 1024 * 1024;
let metricsMeasurements=0;
const measureContext=createCanvas(1,1).getContext('2d');
function runs(text,size) {
  const result=[];let textRun='',emojiRun=null;
  const flush=()=>{if(textRun){const font=`${size}px ${emojiRun?EMOJI_FONT:FONT}`;measureContext.font=font;metricsMeasurements++;const m=measureContext.measureText(textRun);result.push({text:textRun,font,width:m.width,ascent:m.actualBoundingBoxAscent,descent:m.actualBoundingBoxDescent});textRun='';}};
  for(const char of graphemes(text)){const emoji=/\p{Extended_Pictographic}|\p{Regional_Indicator}|\u20e3/u.test(char);if(emoji!==emojiRun){flush();emojiRun=emoji;}textRun+=char;}flush();return result;
}
function row(text,size,color,width) {
  const shaped=runs(text,size),ascent=Math.max(0,...shaped.map(run=>run.ascent)),descent=Math.max(0,...shaped.map(run=>run.descent));
  const canvas=createCanvas(Math.max(1,Math.ceil(width)+4),Math.max(1,Math.ceil(ascent+descent)+4)),ctx=canvas.getContext('2d');ctx.fillStyle=color;ctx.textBaseline='alphabetic';let x=2;
  for(const run of shaped){ctx.font=run.font;ctx.fillText(run.text,x,ascent+2);x+=run.width;}return canvas;
}
function measure(text,size){return runs(text,size).reduce((sum,run)=>sum+run.width,0);}
const pages = text => { const chars = graphemes(text ?? ''); const result = []; for (let i=0;i<chars.length;i+=400) result.push({text:chars.slice(i,i+400).join(''),location:i}); return result.length ? result : [{text:'',location:0}]; };
const statusText = s => s.suspended ? '睡眠中' : !s.isPlaying && s.state !== 'idle' ? '已暂停' : ({idle:'请在 LyricsX Next 播放歌曲',loading:'正在寻找歌词',instrumental:'纯音乐',notFound:'未找到歌词',song:s.artist || '间奏'})[s.state] || '';
function readingPages(text,size,available) {
  const chars=graphemes(text??''),result=[];let start=0;
  while(start<chars.length){let end=start+1;while(end<chars.length&&measure(chars.slice(start,end+1).join(''),size)<=available)end++;result.push({text:chars.slice(start,end).join(''),location:start});start=end;}
  return result.length?result:[{text:'',location:0}];
}
function auxiliaryText(snapshot,options) {
  if(options.secondary==='off')return '';
  if(options.secondary==='next')return snapshot.nextLine?.trim()?snapshot.nextLine:'';
  return snapshot.translation?.trim()?snapshot.translation:snapshot.nextLine?.trim()?snapshot.nextLine:snapshot.state==='lyrics'?'':statusText(snapshot);
}
function layout(snapshot,width,options,page,manual) {
  const auxiliary=auxiliaryText(snapshot,options), single=!auxiliary.trim(), size=single?36:26;
  const signature=JSON.stringify([presentationSignature(snapshot),width,options.secondary,page,manual,auxiliary]);
  if(cache.has(signature)){const value=cache.get(signature);cache.delete(signature);cache.set(signature,value);return value;}
  const primaryReading=readingPages(snapshot.primary,size,width-24),secondaryReading=readingPages(auxiliary,18,width-64);
  const primaryPages=manual?primaryReading:pages(snapshot.primary),secondaryPages=manual?secondaryReading:pages(auxiliary);
  const count=Math.max(primaryPages.length,secondaryPages.length),currentPage=page%count;
  const main=primaryPages[currentPage%primaryPages.length],second=secondaryPages[currentPage%secondaryPages.length];
  // Reading-page progress is an interaction state, never a fabricated lyric row.
  const secondary=second.text, mainWidth=measure(main.text,size),secondaryWidth=measure(secondary,18),chars=graphemes(main.text);
  let prefix='',advances=[0];for(const character of chars){prefix+=character;advances.push(measure(prefix,size));}
  const ranges=(snapshot.timing?.words??[]).flatMap(word=>{
    const start=Math.max(0,word.location-main.location),end=Math.min(chars.length,word.location+word.length-main.location);
    return end>start?[{...word,x:advances[start],width:advances[end]-advances[start]}]:[];
  });
  const primary=row(main.text,size,'#8a9aaa',mainWidth),lit=row(main.text,size,'#f6fbff',mainWidth),secondaryRow=row(secondary,18,'#c1cddd',secondaryWidth);
  const value={primary,lit,secondary:secondaryRow,mainWidth,secondaryWidth,ranges,single,size,pageCount:count,readingPageCount:Math.max(primaryReading.length,secondaryReading.length),pageText:main.text,pageLocation:main.location,readingFirstText:primaryReading[0].text,
    bytes:primary.width*primary.height*8+secondaryRow.width*secondaryRow.height*4};
  cache.set(signature,value);cacheBytes+=value.bytes;
  while(cacheBytes>MAX_CACHE_BYTES&&cache.size>1){const key=cache.keys().next().value;cacheBytes-=cache.get(key).bytes;cache.delete(key);}return value;
}
function scroll(width,available,elapsed,playing) {
  if (width <= available) return 0;
  const distance=width-available, travel=distance/34, cycle=travel*2+1.4;
  const t=Math.max(0,elapsed)%cycle;
  if (t<0.7) return 0;
  if (t<0.7+travel) return (t-0.7)*34;
  if (t<1.4+travel) return distance;
  return Math.max(0,distance-(t-1.4-travel)*34);
}
function scrollDelay(width,available,elapsed,frameDelay) {
  if(width<=available)return null;
  const travel=(width-available)/34,t=Math.max(0,elapsed)%(travel*2+1.4);
  if(t<0.7)return (0.7-t)*1000;
  if(t>=0.7+travel&&t<1.4+travel)return (1.4+travel-t)*1000;
  return frameDelay;
}
export class Renderer {
  constructor(){this.reset();}
  reset(){this.signature=null;this.started=0;this.previous=null;this.lastLayout=null;this.lastLayer=null;this.page=0;this.frozenElapsed=0;this.playing=false;this.content=null;this.manualPage=false;this.readingPageCount=1;}
  nextPage(){
    if(this.readingPageCount<=1){this.manualPage=false;this.page=0;return;}
    if(!this.manualPage){this.manualPage=true;this.page=1;}
    else if(this.page+1>=this.readingPageCount){this.manualPage=false;this.page=0;}
    else this.page++;
  }
  render(snapshot,width,position,now,options={secondary:'translation',fps:30}){
    width=Math.max(120,Math.min(2170,Math.round(width)));
    const content=presentationSignature(snapshot)+snapshot.trackRevision;
    if(content!==this.content){this.page=0;this.manualPage=false;this.content=content;}
    const lyricTime=position+(snapshot.timing?.offsetMilliseconds??0)/1000;
    if(!this.manualPage&&snapshot.isPlaying&&snapshot.timing?.words.length){const cue=[...snapshot.timing.words].reverse().find(cue=>lyricTime>=cue.start);if(cue)this.page=Math.floor(cue.location/400);}
    const signature=content+JSON.stringify([width,options.secondary,this.page,this.manualPage,options.alignment]);
    if(signature!==this.signature){this.previous=this.lastLayer;this.started=now;this.frozenElapsed=0;this.signature=signature;}
    let elapsed=now-this.started;
    if(!snapshot.isPlaying||snapshot.suspended){if(this.playing)this.frozenElapsed=elapsed;elapsed=this.frozenElapsed;}
    else if(!this.playing&&this.lastLayout){this.started=now-this.frozenElapsed;elapsed=this.frozenElapsed;}
    this.playing=snapshot.isPlaying&&!snapshot.suspended;
    const current=layout(snapshot,width,options,this.page,this.manualPage);this.lastLayout=current;this.readingPageCount=current.readingPageCount;
    const canvas=createCanvas(width,60),ctx=canvas.getContext('2d');ctx.fillStyle='#081321';ctx.fillRect(0,0,width,60);
    if(!options.immersive){ctx.fillStyle='#28435d';ctx.fillRect(0,0,3,60);}
    const available=width-24;
    let mainScroll=scroll(current.mainWidth,available,elapsed);
    if(current.mainWidth>available&&snapshot.timing){
      const cue=[...current.ranges].reverse().find(cue=>lyricTime>=cue.start);
      if(cue){const progress=cue.end===cue.start?1:Math.max(0,Math.min(1,(lyricTime-cue.start)/(cue.end-cue.start)));mainScroll=Math.max(0,Math.min(current.mainWidth-available,cue.x+cue.width*progress-available*0.55));}
      else if(!current.ranges.length&&snapshot.timing.end>snapshot.timing.start){const budget=snapshot.timing.end-snapshot.timing.start;mainScroll=Math.max(0,Math.min(1,(lyricTime-snapshot.timing.start)/Math.max(0.1,budget-0.3)))*(current.mainWidth-available);}
    }
    const auxScroll=scroll(current.secondaryWidth,available,elapsed);
    const alignment=options.alignment??(options.immersive?'center':'left');
    const aligned=(textWidth,offset)=>alignment==='center'&&textWidth<=available?(width-textWidth)/2-2:10-offset;
    const geometry={mainX:aligned(current.mainWidth,mainScroll),secondaryX:aligned(current.secondaryWidth,auxScroll),primaryY:current.single?(60-current.primary.height)/2:1,secondaryY:33,mainScroll,auxScroll,time:lyricTime,lyrical:snapshot.state==='lyrics'};
    const paint=(layer,alpha,shift)=>{
      const {item,g}=layer;ctx.save();ctx.globalAlpha=alpha;ctx.beginPath();ctx.rect(12,0,available,60);ctx.clip();ctx.drawImage(item.primary,g.mainX,g.primaryY+shift);
      if(g.lyrical&&!item.ranges.length)ctx.drawImage(item.lit,g.mainX,g.primaryY+shift);
      else for(const cue of item.ranges){const progress=cue.end===cue.start?Number(g.time>=cue.start):Math.max(0,Math.min(1,(g.time-cue.start)/(cue.end-cue.start)));if(!progress)continue;ctx.save();ctx.beginPath();ctx.rect(g.mainX+2+cue.x,0,cue.width*progress,60);ctx.clip();ctx.drawImage(item.lit,g.mainX,g.primaryY+shift);ctx.restore();}
      if(!item.single)ctx.drawImage(item.secondary,g.secondaryX,g.secondaryY+shift);ctx.restore();
    };
    const entryDuration=Math.min(0.18,Math.max(0.01,(snapshot.timing?snapshot.timing.end-snapshot.timing.start:1)*0.2));
    const transition=this.previous&&this.playing&&elapsed<entryDuration&&(!snapshot.timing||snapshot.timing.end-snapshot.timing.start>=0.35);
    const progress=Math.min(1,elapsed/entryDuration),eased=1-(1-progress)**3,layer={item:current,g:geometry};
    // Animate only the incoming line: overlapping old glyphs obscure karaoke text.
    paint(layer,transition?0.9+0.1*eased:1,transition?2*(1-eased):0);this.lastLayer=layer;
    if(!snapshot.isPlaying&&snapshot.state!=='idle'){ctx.fillStyle='#aebed0';ctx.fillRect(width-9,7,2,8);ctx.fillRect(width-5,7,2,8);}
    let nextDelay=null;
    if(this.playing){
      const changingWord=current.ranges.some(cue=>lyricTime>=cue.start&&lyricTime<cue.end),frameDelay=1000/([15,20,30,60].filter(fps=>fps<=Number(options.fps||30)).pop()||15),delays=[];
      if(transition||changingWord)delays.push(frameDelay);
      if(current.mainWidth>available){if(snapshot.timing){if(!current.ranges.length&&lyricTime>=snapshot.timing.start&&lyricTime<snapshot.timing.end-0.3)delays.push(frameDelay);}else{const delay=scrollDelay(current.mainWidth,available,elapsed,frameDelay);if(delay!=null)delays.push(delay);}}
      const auxDelay=scrollDelay(current.secondaryWidth,available,elapsed,frameDelay);if(auxDelay!=null)delays.push(auxDelay);
      delays.push(...current.ranges.filter(cue=>cue.start>lyricTime).map(cue=>(cue.start-lyricTime)*1000));if(delays.length)nextDelay=Math.min(...delays);
    }
    let output=canvas;
    if(options.immersive&&options.rotation===180){output=createCanvas(width,60);const rotated=output.getContext('2d');rotated.imageSmoothingEnabled=false;rotated.translate(width,60);rotated.rotate(Math.PI);rotated.drawImage(canvas,0,0);}
    const png=output.toBuffer('image/png');
    return {png,signature:createHash('sha256').update(png).digest('hex'),nextDelay,pageCount:current.pageCount,readingPageCount:current.readingPageCount,width,height:60,mainScroll,ranges:current.ranges,pageText:current.pageText,pageLocation:current.pageLocation,readingFirstText:current.readingFirstText,geometry,single:current.single,fontSize:current.size,rowHeight:current.primary.height};
  }
}
export function cacheStats() { return {entries:cache.size,bytes:cacheBytes,maximumBytes:MAX_CACHE_BYTES,metricsMeasurements}; }
