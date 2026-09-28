import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {Renderer,cacheStats} from '../src/renderer.mjs';
import {graphemes} from '../src/codec.mjs';
const output=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../qa-output');await fs.mkdir(output,{recursive:true});
const base={version:1,kind:'snapshot',sessionID:'qa',revision:1,state:'lyrics',trackRevision:1,documentRevision:1,title:'QA',artist:'Artist',isPlaying:true,suspended:false,primary:'我们在光里，看见完整的世界',translation:'We see the whole world in the light.',nextLine:'下一句歌词'};
const timed=text=>{const count=graphemes(text).length;return {start:0,end:count*.18,offsetMilliseconds:0,words:Array.from({length:count},(_,i)=>({location:i,length:1,start:i*.18,end:(i+1)*.18}))};};
const cases=[
 ['bilingual',base,720,1],['japanese',{...base,primary:'星の光があなたを照らす',translation:'星光照亮你'},720,1],
 ['emoji',{...base,primary:'👩🏽‍🚀 光 é こんにちは 🌌',translation:'组合字与 emoji 完整保留'},720,1],
 ['narrow',{...base,primary:'这是一句需要在窄屏上顺滑阅读的长歌词'},240,2],
 ['long-middle',{...base,primary:'这是一句很长的歌词，当前演唱的文字应该一直保持可见。'.repeat(3)},720,7],
 ['long-end',{...base,primary:'这是一句很长的歌词，当前演唱的文字应该一直保持可见。'.repeat(3)},720,14],
 ['paused',{...base,isPlaying:false},720,1],['immersive',base,2170,1],
 ['loading',{...base,state:'loading',primary:'正在播放的歌曲',translation:null,nextLine:null},720,0],
 ['instrumental',{...base,state:'instrumental',primary:'纯音乐曲目',translation:null,nextLine:null},720,0]
];
const records=[];
for(const [name,raw,width,position] of cases){const s={...raw,timing:raw.state==='lyrics'?timed(raw.primary):null},renderer=new Renderer();const start=performance.now(),frame=renderer.render(s,width,position,position,{secondary:'translation',fps:30});await fs.writeFile(path.join(output,name+'.png'),frame.png);records.push({name,width,height:60,milliseconds:performance.now()-start,pngBytes:frame.png.length,mainScroll:frame.mainScroll});}
const renderer=new Renderer(),s={...base,timing:timed(base.primary)};
for(let i=0;i<60;i++){const frame=renderer.render(s,720,i/30,i/30,{secondary:'translation',fps:30});await fs.writeFile(path.join(output,`karaoke-${String(i).padStart(3,'0')}.png`),frame.png);}
const pauseRenderer=new Renderer(),pause={...base,primary:'暂停时也能点击阅读完整长句，文字不会因为没有播放动画而永远停在前半段。'.repeat(2),translation:null,nextLine:null,isPlaying:false,timing:null};
pauseRenderer.render(pause,240,0,0,{secondary:'off',fps:30});
for(let i=0;i<8;i++){pauseRenderer.nextPage();const frame=pauseRenderer.render(pause,240,0,i+1,{secondary:'off',fps:30});await fs.writeFile(path.join(output,`paused-page-${i}.png`),frame.png);}
const transition=new Renderer();transition.render(s,720,1,1);const next={...s,primary:'下一句已经清晰出现',timing:{...timed('下一句已经清晰出现'),start:2,end:4}};
for(let i=0;i<7;i++){const frame=transition.render(next,720,2+i*.03,2+i*.03);await fs.writeFile(path.join(output,`transition-${i}.png`),frame.png);}
const review=path.join(output,'v020');await fs.mkdir(review,{recursive:true});
const center={...base,isPlaying:false,timing:null};
for(const rotation of [0,180]){const frame=new Renderer().render(center,2170,1,1,{immersive:true,alignment:'center',rotation,secondary:'translation'});await fs.writeFile(path.join(review,`center-dual-${rotation}.png`),frame.png);}
for(const [name,text]of [['single-cjk','星光照亮完整的世界'],['single-latin','Starlight gpjqy é'],['single-emoji','星光 gpjqy é 👩🏽‍🚀 🌌']]){const frame=new Renderer().render({...center,primary:text,translation:null,nextLine:null},2170,0,0,{immersive:true,alignment:'center',secondary:'off'});await fs.writeFile(path.join(review,name+'.png'),frame.png);}
const sung={...base,timing:timed(base.primary)},shortLong=new Renderer(),reviewOptions={immersive:true,alignment:'center',secondary:'translation',fps:30};
await fs.writeFile(path.join(review,'center-highlight.png'),shortLong.render(sung,2170,1.1,1.1,reviewOptions).png);
const long={...sung,primary:'这是一句很长但正在演唱的文字仍然清楚可见的歌词。'.repeat(5)};long.timing=timed(long.primary);
shortLong.render(sung,720,0,1,reviewOptions);
for(const [i,time]of [0,.06,.18].entries())await fs.writeFile(path.join(review,`short-to-long-${i}.png`),shortLong.render(long,720,time,2+time,reviewOptions).png);
shortLong.render(long,720,5,5,reviewOptions);
for(const [i,time]of [0,.06,.18].entries())await fs.writeFile(path.join(review,`long-to-short-${i}.png`),shortLong.render(sung,720,time,6+time,reviewOptions).png);
const reader=new Renderer(),readLine={...center,primary:'暂停时点击阅读整句，最后一页之后自动返回。',translation:null,nextLine:null},readOptions={immersive:true,alignment:'center',secondary:'off'};
let readFrame=reader.render(readLine,240,0,0,readOptions);await fs.writeFile(path.join(review,'reading-auto-before.png'),readFrame.png);let count=readFrame.readingPageCount;
for(let i=1;i<count;i++){reader.nextPage();readFrame=reader.render(readLine,240,0,i,readOptions);await fs.writeFile(path.join(review,`reading-page-${i}.png`),readFrame.png);}
reader.nextPage();await fs.writeFile(path.join(review,'reading-auto-after.png'),reader.render(readLine,240,0,count,readOptions).png);
const benchmarks=[];
for(const width of [240,720,2170]){const r=new Renderer();r.render(s,width,0,0);const cpu=process.cpuUsage(),t=performance.now();let bytes=0;for(let i=0;i<90;i++)bytes+=r.render(s,width,i/30,i/30).png.length;const elapsed=performance.now()-t,c=process.cpuUsage(cpu);benchmarks.push({width,frames:90,wallMilliseconds:elapsed,cpuMilliseconds:(c.user+c.system)/1000,meanMilliseconds:elapsed/90,meanPNGBytes:bytes/90});}
await fs.writeFile(path.join(output,'report.json'),JSON.stringify({scope:'Offline Canvas render/PNG encode; excludes SDK draw, USB and device refresh.',records,benchmarks,cache:cacheStats()},null,2));console.log(output);console.log(JSON.stringify(benchmarks));
