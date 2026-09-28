import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {PlaybackClock} from '../src/clock.mjs';
import {JsonLines,graphemes,validateSnapshot} from '../src/codec.mjs';
import {Renderer,cacheStats} from '../src/renderer.mjs';
import {DrawScheduler} from '../src/scheduler.mjs';
import {LyricsPlugin,KEY_CARD,KEY_SCREEN} from '../src/lifecycle.mjs';
import {LyricsBridge} from '../src/bridge.mjs';
const sample=(changes={})=>({version:1,kind:'snapshot',sessionID:'session',revision:1,state:'lyrics',trackRevision:1,documentRevision:1,title:'Song',artist:'Artist',primary:'光芒照亮世界',translation:'Light reaches the world',nextLine:'下一句',isPlaying:true,suspended:false,clock:{hostUptime:100,position:1,rate:1},timing:{start:0,end:4,offsetMilliseconds:0,words:[{location:0,length:2,start:0,end:2},{location:2,length:4,start:2,end:4}]},...changes});
const settle=()=>new Promise(resolve=>setImmediate(resolve));
test('clock maps independent origins and pause/seek anchors',()=>{
 const clock=new PlaybackClock(()=>12);clock.synchronize({echoClientTime:10,serverUptime:1010.01},10.02);
 assert.ok(Math.abs(clock.offset-1000)<1e-10);assert.ok(Math.abs(clock.rtt-.02)<1e-10);
 clock.update({hostUptime:1010,position:5,rate:1});assert.ok(Math.abs(clock.position(12)-7)<1e-9);
 clock.update({hostUptime:1012,position:8,rate:0});assert.equal(clock.position(100),8);
 clock.update({hostUptime:1012,position:3,rate:1});assert.equal(clock.position(12),3);
});
test('JSONL split and joined frames cap incomplete data',()=>{
 const values=[], parser=new JsonLines(x=>values.push(x));parser.push(Buffer.from('{"a":'));parser.push(Buffer.from('1}\n{"b":2}\n'));assert.deepEqual(values,[{a:1},{b:2}]);assert.throws(()=>parser.push(Buffer.alloc(65537,120)));
});
test('grapheme ranges preserve emoji and combining characters',()=>{
 const text='👩🏽‍🚀光é';assert.equal(graphemes(text).length,3);
 const valid=sample({primary:text,timing:{start:0,end:2,offsetMilliseconds:0,words:[{location:0,length:1,start:0,end:1}]}});assert.equal(validateSnapshot(valid),valid);
 assert.throws(()=>validateSnapshot({...valid,timing:{...valid.timing,words:[{location:2,length:2,start:0,end:1}]}}));
});
test('clock correction preserves transition and scrolling origins',()=>{
 const renderer=new Renderer();renderer.render(sample(),720,1,10);const started=renderer.started;
 renderer.render(sample({revision:2,clock:{hostUptime:101,position:1.1,rate:1}}),720,1.1,10.1);assert.equal(renderer.started,started);
 renderer.render(sample({isPlaying:false}),720,1.1,10.2);const frame=renderer.render(sample({isPlaying:false}),720,1.1,100);assert.equal(frame.nextDelay,null);
});
test('timed long lines follow the singing word in narrow viewport',()=>{
 const primary='这是一段很长的歌词，需要当前演唱的文字始终出现在屏幕中。'.repeat(3), count=graphemes(primary).length;
 const words=Array.from({length:count},(_,i)=>({location:i,length:1,start:i*.1,end:(i+1)*.1}));
 const s=sample({primary,timing:{start:0,end:count*.1,offsetMilliseconds:0,words}}),renderer=new Renderer();
 for(const index of [Math.floor(count/2),count-2]){const position=index*.1+.05,frame=renderer.render(s,240,position,position);const cue=frame.ranges[index];const visibleX=12-frame.mainScroll+cue.x+cue.width*.5;assert.ok(visibleX>=10&&visibleX<=222,`word outside viewport: ${visibleX}`);}
 renderer.nextPage();renderer.render(sample({primary:'Different line',timing:null}),240,0,100);assert.equal(renderer.page,0);assert.ok(cacheStats().bytes<=cacheStats().maximumBytes);
});
test('narrow emoji render is 60px, pause and static untimed stop timers',()=>{
 const renderer=new Renderer(),s=sample({primary:'👩🏽‍🚀 光 é 日本語',timing:null,translation:'こんにちは'});
 const image=renderer.render(s,240,1,10);assert.equal(image.height,60);assert.ok(image.png.length>100);
 const paused=renderer.render({...s,isPlaying:false},240,1,11);assert.equal(paused.nextDelay,null);
 const staticFrame=new Renderer().render(sample({primary:'短句',translation:'短句',timing:null}),720,0,10);assert.equal(staticFrame.nextDelay,null);
});
test('scheduler bounds slow draw, only commits success, and latest wins',async()=>{
 let revision=1,finish,drawn=[];const scheduler=new DrawScheduler({render:()=>({signature:String(revision),nextDelay:null}),draw:frame=>{drawn.push(frame.signature);return new Promise(resolve=>finish=resolve);}});
 scheduler.request();revision=2;scheduler.request();revision=3;scheduler.request();assert.equal(scheduler.pendingFrames,2);finish();await settle();assert.deepEqual(drawn,['1','3']);finish();await settle();scheduler.request();assert.equal(drawn.length,2);scheduler.stop();assert.equal(scheduler.timer,null);
 let fail=true;const failed=new DrawScheduler({render:()=>({signature:'same',nextDelay:null}),draw:()=>fail?Promise.reject(new Error('fail')):Promise.resolve()});failed.request();await settle();assert.equal(failed.successSignature,null);fail=false;failed.request();await settle();assert.equal(failed.successSignature,'same');failed.stop();
});
test('scheduler subtracts completed drawing from frame deadline',async()=>{
 let now=0,delay;const scheduler=new DrawScheduler({render:()=>({signature:'one',nextDelay:1000/30}),draw:async()=>{now+=30;},now:()=>now,setTimer:(_callback,value)=>{delay=value;return 1;},clearTimer:()=>{}});scheduler.request();await settle();assert.ok(delay<5,`extra frame delay ${delay}`);scheduler.stop();
});
test('alive/dead device identity, hidden cancellation and forced reconnect draw',async()=>{
 const handlers={},draws=[];let active=false,stopped=false;
 const host={on:(event,fn)=>handlers[event]=fn,draw:async(serial,key)=>draws.push(`${serial}:${key.uid}`),directDraw:async(serial,key)=>draws.push(`screen:${serial}:${key.uid}`)};
 const application=new LyricsPlugin(host,{bridgeFactory:()=>({setActive:value=>active=value,stop:()=>stopped=true}),now:()=>1});
 handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_CARD,uid:1,width:240}]});handlers['plugin.alive']({serialNumber:'B',keys:[{cid:KEY_SCREEN,uid:1}]});await settle();assert.equal(application.keys.size,2);assert.equal(active,true);assert.ok(draws.includes('A:1')&&draws.includes('screen:B:1'));
 handlers['plugin.dead']({serialNumber:'A',keys:[{uid:1}]});assert.equal(application.keys.size,1);
 handlers['device.status']([{serialNumber:'B',status:'disconnected'}]);assert.equal(application.keys.size,0);assert.equal(active,false);
 application.stop();assert.equal(stopped,true);
});
test('bridge revision filtering and no consumers cancels reconnect',async()=>{
 const socket=new EventEmitter();socket.write=()=>{};socket.destroy=()=>socket.emit('close');const values=[],sync=[];
 const bridge=new LyricsBridge({connect:()=>socket,now:()=>1,onSnapshot:s=>values.push(s),onSync:s=>sync.push(s),onStatus:()=>{}});bridge.setActive(true);socket.emit('connect');
 socket.emit('data',Buffer.from(JSON.stringify({...sample(),revision:2})+'\n'+JSON.stringify(sample())+'\n'));assert.equal(values.length,1);
 socket.emit('close');assert.ok(bridge.retry);bridge.setActive(false);assert.equal(bridge.retry,null);assert.equal(bridge.socket,null);
});
test('last dead key clears old clock and lyrics before a failed reconnect',async()=>{
 const handlers={},host={on:(event,fn)=>handlers[event]=fn,draw:async()=>{},directDraw:async()=>{}};
 const application=new LyricsPlugin(host,{bridgeFactory:()=>({setActive:()=>{},stop:()=>{}}),now:()=>100});
 handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_CARD,uid:1,width:240}]});application.receive(sample());await settle();
 handlers['plugin.dead']({serialNumber:'A',keys:[{uid:1}]});assert.equal(application.snapshot.state,'idle');assert.equal(application.clock.anchor,null);
 handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_CARD,uid:1,width:240}]});await settle();
 assert.equal(application.snapshot.state,'idle');const item=application.keys.get('A:1');assert.equal(item.scheduler.lastRender.nextDelay,null);assert.equal(item.scheduler.timer,null);application.stop();
});
test('completed timed overflow stops rendering and short cue has no obscuring fade',()=>{
 const primary='長い歌詞'.repeat(18),count=graphemes(primary).length,renderer=new Renderer();
 const words=Array.from({length:count},(_,i)=>({location:i,length:1,start:i*.05,end:(i+1)*.05}));
 const s=sample({primary,translation:null,nextLine:null,timing:{start:0,end:count*.05,offsetMilliseconds:0,words}});
 const done=renderer.render(s,240,count*.05+1,100,{secondary:'off',fps:30});assert.equal(done.nextDelay,null);
 renderer.render(sample(),240,0,110);const short=renderer.render(sample({primary:'短',timing:{start:0,end:.08,offsetMilliseconds:0,words:[]},translation:null,nextLine:null}),240,0,111,{secondary:'off',fps:30});assert.equal(short.nextDelay,null);
});
test('paused overflow click pages cover the entire line and return to auto',()=>{
 const primary='窄屏也必须能阅读完整的一句歌词'.repeat(5),renderer=new Renderer(),s=sample({primary,isPlaying:false,timing:null,translation:null,nextLine:null});
 const original=renderer.render(s,240,1,10,{secondary:'off',fps:30}),segments=[original.readingFirstText];renderer.nextPage();let frame=renderer.render(s,240,1,11,{secondary:'off',fps:30});assert.notEqual(frame.signature,original.signature);assert.ok(frame.pageCount>1);
 const count=frame.pageCount;for(let i=1;i<count;i++){segments.push(frame.pageText);renderer.nextPage();frame=renderer.render(s,240,1,12+i,{secondary:'off',fps:30});assert.equal(frame.nextDelay,null);}
 assert.equal(segments.join(''),primary);assert.equal(renderer.manualPage,false);assert.equal(frame.signature,original.signature);
});
