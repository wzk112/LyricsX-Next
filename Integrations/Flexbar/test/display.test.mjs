import test from 'node:test';
import assert from 'node:assert/strict';
import {createCanvas,loadImage} from '@napi-rs/canvas';
import {Renderer,cacheStats} from '../src/renderer.mjs';
import {LyricsPlugin,KEY_CARD,KEY_SCREEN} from '../src/lifecycle.mjs';
const sample=(changes={})=>({version:1,kind:'snapshot',sessionID:'display',revision:1,state:'lyrics',trackRevision:1,documentRevision:1,title:'Song',artist:'Artist',primary:'星光照亮你',translation:'Starlight reaches you',nextLine:null,isPlaying:false,suspended:false,timing:null,...changes});
const settle=()=>new Promise(resolve=>setImmediate(resolve));
const bridgeFactory=()=>({setActive:()=>{},stop:()=>{}});
async function pixels(png){const image=await loadImage(png),canvas=createCanvas(image.width,image.height);canvas.getContext('2d').drawImage(image,0,0);return canvas.getContext('2d').getImageData(0,0,image.width,image.height).data;}
test('immersive 180 rotates exact pixels; card never rotates automatically',async()=>{
 const s=sample(),normal=new Renderer().render(s,2170,0,0,{immersive:true,rotation:0,alignment:'center',secondary:'translation'}),flipped=new Renderer().render(s,2170,0,0,{immersive:true,rotation:180,alignment:'center',secondary:'translation'});
 const a=await pixels(normal.png),b=await pixels(flipped.png);for(let i=0;i<a.length;i+=4)for(let c=0;c<4;c++)assert.equal(a[i+c],b[b.length-i-4+c]);assert.notEqual(normal.signature,flipped.signature);
 const cardA=new Renderer().render(s,720,0,0,{rotation:0}),cardB=new Renderer().render(s,720,0,0,{rotation:180});assert.equal(cardA.signature,cardB.signature);
});
test('primary and secondary center independently; overflow follows real words',()=>{
 const s=sample(),r=new Renderer(),frame=r.render(s,720,0,0,{immersive:true,alignment:'center',secondary:'translation'});
 assert.ok(Math.abs(frame.geometry.mainX+2+ r.lastLayout.mainWidth/2-360)<1e-8);assert.ok(Math.abs(frame.geometry.secondaryX+2+r.lastLayout.secondaryWidth/2-360)<1e-8);
 const long='这是一句很长的歌词'.repeat(6),word={location:30,length:1,start:1,end:2};const overflow=r.render(sample({primary:long,isPlaying:true,timing:{start:0,end:4,offsetMilliseconds:0,words:[word]}}),240,1.5,2,{immersive:true,alignment:'center',secondary:'off'});const cue=overflow.ranges[0],x=overflow.geometry.mainX+2+cue.x+cue.width/2;assert.ok(x>=12&&x<=228);
});
test('transition keeps incoming geometry and never overlays outgoing glyphs',()=>{
 const r=new Renderer(),short=sample({isPlaying:true}),options={immersive:true,alignment:'center',secondary:'translation'};
 const first=r.render(short,720,0,1,options),oldX=first.geometry.mainX;
 r.render(sample({primary:'很长的一句'.repeat(12),isPlaying:true}),720,0,2,options);assert.equal(r.previous.g.mainX,oldX);
 const longFrame=r.render(sample({primary:'很长的一句'.repeat(12),isPlaying:true}),720,0,4,options),longX=longFrame.geometry.mainX;
 r.render(sample({primary:'短句',isPlaying:true}),720,0,5,options);assert.equal(r.previous.g.mainX,longX);assert.notEqual(r.lastLayer.g.mainX,longX);
 const other=new Renderer();other.render(sample({primary:'完全不同的旧句',isPlaying:true}),720,0,4,options);
 other.render(sample({primary:'短句',isPlaying:true}),720,0,5,options);
 const mid=r.render(sample({primary:'短句',isPlaying:true}),720,0,5.06,options),otherMid=other.render(sample({primary:'短句',isPlaying:true}),720,0,5.06,options);
 assert.equal(mid.signature,otherMid.signature);
});
test('single 36px line uses true ascent/descent without cutting CJK descenders or emoji',async()=>{
 const s=sample({primary:'星光 gpjqy é 👩🏽‍🚀 🌌',translation:null}),r=new Renderer(),frame=r.render(s,720,0,0,{immersive:true,secondary:'off',alignment:'center'});
 assert.equal(frame.single,true);assert.equal(frame.fontSize,36);assert.ok(frame.rowHeight<=60);assert.equal(frame.geometry.primaryY,(60-frame.rowHeight)/2);
 const data=await pixels(frame.png),ys=[];for(let y=0;y<60;y++)for(let x=12;x<708;x++){const i=(y*720+x)*4;if(data[i]>100&&data[i+1]>100){ys.push(y);break;}}
 assert.ok(Math.min(...ys)>0&&Math.max(...ys)<59);assert.ok(Math.abs((Math.min(...ys)+Math.max(...ys))/2-29.5)<=2);
});
test('single-page click remains auto with no animation timer',()=>{
 const r=new Renderer(),s=sample({primary:'短句',translation:null});const before=r.render(s,720,0,0,{secondary:'off'});r.nextPage();const after=r.render(s,720,0,1,{secondary:'off'});assert.equal(r.manualPage,false);assert.equal(after.signature,before.signature);assert.equal(after.nextDelay,null);
});
test('automatic screen flip is per-device and ordinary card stays normal',async()=>{
 const handlers={},calls=[],messages=[],host={on:(name,fn)=>handlers[name]=fn,transport:{call:async(command,payload,timeout)=>{calls.push({command,payload,timeout});return[{serialNumber:'A',deviceData:{config:{screenFlip:true,otherSetting:'PRIVATE_VALUE_NOT_LOGGED'}}},{serialNumber:'B',deviceData:{config:{screenFlip:false}}}];}},draw:async()=>{},directDraw:async()=>{}};
 const app=new LyricsPlugin(host,{bridgeFactory,logger:{info:message=>messages.push(message),warn:()=>{}}});app.hostReady();handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_SCREEN,uid:1},{cid:KEY_CARD,uid:2}]});handlers['plugin.alive']({serialNumber:'B',keys:[{cid:KEY_SCREEN,uid:1}]});await app.statusRequest;await settle();assert.equal(calls.length,2);assert.equal(calls[0].timeout,5000);
 await app.refreshDeviceStatus();assert.equal(messages.filter(message=>message.includes('getDeviceStatus shape')).length,1);assert.ok(messages.some(message=>message.includes('"count":2')));assert.equal(messages.join('').includes('PRIVATE_VALUE_NOT_LOGGED'),false);
 assert.equal(app.keys.get('A:1').options.rotation,180);assert.equal(app.keys.get('A:2').options.rotation,0);assert.equal(app.keys.get('B:1').options.rotation,0);assert.equal(app.keys.get('A:1').options.alignment,'center');assert.equal(app.keys.get('A:2').options.alignment,'left');app.stop();
});
test('late query cannot overwrite newer config, disconnected serial or host epoch',async()=>{
 const handlers={};let resolve;const host={on:(name,fn)=>handlers[name]=fn,transport:{call:()=>new Promise(done=>resolve=done)},draw:async()=>{},directDraw:async()=>{}};
 const app=new LyricsPlugin(host,{bridgeFactory});handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_SCREEN,uid:1}]});handlers['plugin.alive']({serialNumber:'B',keys:[{cid:KEY_SCREEN,uid:1}]});await settle();
 handlers['device.status']([{serialNumber:'A',status:'connected',deviceData:{config:{screenFlip:true}}},{serialNumber:'B',status:'disconnected'}]);resolve([{serialNumber:'A',deviceData:{config:{screenFlip:false}}},{serialNumber:'B',deviceData:{config:{screenFlip:true}}}]);await app.statusRequest;
 assert.equal(app.keys.get('A:1').options.rotation,180);assert.equal(app.keys.has('B:1'),false);assert.equal(app.devices.get('B').screenFlip,undefined);
 const pending=app.refreshDeviceStatus();await settle();app.hostLost();resolve([{serialNumber:'A',deviceData:{config:{screenFlip:true}}}]);await pending;assert.equal(app.devices.size,0);app.stop();
});
test('inflight old orientation cannot consume the new full-refresh requirement',async()=>{
 const handlers={},calls=[];let finish;const host={on:(name,fn)=>handlers[name]=fn,draw:async()=>{},directDraw:(_serial,_key,_data,diff)=>{calls.push(diff);return new Promise(resolve=>finish=resolve);}};
 const app=new LyricsPlugin(host,{bridgeFactory});handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_SCREEN,uid:1,data:{diffUpdate:true}}]});assert.deepEqual(calls,[false]);handlers['device.status']([{serialNumber:'A',status:'connected',deviceData:{config:{screenFlip:true}}}]);finish();await settle();assert.deepEqual(calls,[false,false]);finish();await settle();assert.equal(app.keys.get('A:1').completedOrientationRevision,1);app.stop();
});
test('new hostReady is not swallowed by the previous unsettled status query',async()=>{
 const handlers={},resolvers=[];let calls=0;const host={on:(name,fn)=>handlers[name]=fn,transport:{call:()=>{calls++;return new Promise(resolve=>resolvers.push(resolve));}},draw:async()=>{},directDraw:async()=>{}};
 const app=new LyricsPlugin(host,{bridgeFactory});app.hostReady();const old=app.statusRequest;await settle();app.hostLost();app.hostReady();const fresh=app.statusRequest;await settle();assert.equal(calls,2);
 resolvers[0]([{serialNumber:'A',deviceData:{config:{screenFlip:true}}}]);await old;assert.equal(app.devices.size,0);assert.equal(app.statusRequest,fresh);
 resolvers[1]([{serialNumber:'A',deviceData:{config:{screenFlip:false}}}]);await fresh;assert.equal(app.devices.get('A').screenFlip,false);app.stop();
});

test('manual playing pages reuse all text metrics between animation frames',()=>{
 const s=sample({primary:'当前歌词页面的所有字体测量都应只进行一次'.repeat(12),translation:null,isPlaying:true}),r=new Renderer();r.render(s,240,0,1,{secondary:'off'});r.nextPage();r.render(s,240,0,2,{secondary:'off'});const measured=cacheStats().metricsMeasurements;
 for(let i=0;i<30;i++)r.render(s,240,i/30,2+i/30,{secondary:'off'});assert.equal(cacheStats().metricsMeasurements,measured);
});
test('hostLost cancels a status read scheduled before its transport call',async()=>{
 let calls=0;const host={on:()=>{},transport:{call:async()=>{calls++;return[];}},draw:async()=>{},directDraw:async()=>{}};const app=new LyricsPlugin(host,{bridgeFactory});app.hostReady();const pending=app.statusRequest;app.hostLost();await pending;assert.equal(calls,0);app.stop();
});
test('numeric flip and startup stale query use one event-authorized followup',async()=>{
 const handlers={},pending=[];let calls=0;
 const host={on:(name,fn)=>handlers[name]=fn,transport:{call:()=>{calls++;return new Promise(resolve=>pending.push(resolve));}},draw:async()=>{},directDraw:async()=>{}};
 const app=new LyricsPlugin(host,{bridgeFactory});app.hostReady();await settle();
 handlers['device.status']([{serialNumber:'A',status:'connected',deviceData:{config:{}}}]);
 pending.shift()([{serialNumber:'A',deviceData:{config:{screenFlip:1}}}]);await settle();assert.equal(calls,2);assert.equal(app.devices.get('A').screenFlip,undefined);
 pending.shift()([{serialNumber:'A',deviceData:{config:{screenFlip:1}}}]);await settle();assert.equal(app.devices.get('A').screenFlip,true);await settle();assert.equal(calls,2);
 handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_SCREEN,uid:1}]});assert.equal(app.keys.get('A:1').options.rotation,180);await settle();
 pending.shift()([{serialNumber:'A',deviceData:{config:{screenFlip:0}}}]);await settle();assert.equal(app.keys.get('A:1').options.rotation,0);
 handlers['device.status']([{serialNumber:'A',status:'connected',deviceData:{config:{screenFlip:1}}}]);assert.equal(app.keys.get('A:1').options.rotation,180);
 for(const invalid of [2,'1','true']){app.applyDeviceFlip('A',invalid);assert.equal(app.devices.get('A').screenFlip,true);}
 const request=app.refreshDeviceStatus();await settle();pending.shift()([{serialNumber:'A',deviceData:{config:{screenFlip:2}}}]);await request;await settle();assert.equal(app.devices.get('A').screenFlip,true);assert.equal(app.statusRequest,null);app.stop();
});
test('optional 60fps targets 16.67ms; legacy 30 and static cancellation stay intact',()=>{
 const s=sample({primary:'星',translation:null,isPlaying:true,timing:{start:0,end:2,offsetMilliseconds:0,words:[{location:0,length:1,start:0,end:2}]}});
 const r=new Renderer(),o={secondary:'off',fps:60};const frame=r.render(s,720,1,0,o);assert.equal(frame.nextDelay,1000/60);
 assert.equal(new Renderer().render(s,720,1,0,{secondary:'off',fps:30}).nextDelay,1000/30);
 assert.equal(new Renderer().render({...s,isPlaying:false},720,1,0,o).nextDelay,null);
 assert.equal(new Renderer().render({...s,suspended:true},720,1,0,o).nextDelay,null);
 assert.equal(new Renderer().render({...s,timing:null},720,1,0,o).nextDelay,null);
 const app=new LyricsPlugin({on:()=>{}},{bridgeFactory});assert.equal(app.options({cid:KEY_CARD,data:{fps:60}}).fps,60);assert.equal(app.options({cid:KEY_SCREEN,data:{fps:60}}).fps,60);assert.equal(app.options({cid:KEY_CARD}).fps,30);app.stop();
});
test('draw ACK diagnostics are bounded at 30 successes with only first and summary logs',async()=>{
 const handlers={},messages=[];let time=0;const host={on:(name,fn)=>handlers[name]=fn,draw:async()=>{time+=0.01;},directDraw:async()=>{time+=0.01;}};
 const app=new LyricsPlugin(host,{bridgeFactory,now:()=>time,logger:{info:message=>messages.push(message),warn:()=>{}}});
 handlers['plugin.alive']({serialNumber:'A',keys:[{cid:KEY_CARD,uid:1}]});await settle();
 for(let i=0;i<35;i++){app.receive(sample({primary:'静止 '+i}));await settle();}
 const item=app.keys.get('A:1'),logs=messages.filter(message=>message.includes('API ACK'));assert.equal(item.drawMeasurements.samples,30);assert.equal(logs.length,2);assert.ok(logs[0].includes('"samples":1'));assert.ok(logs[1].includes('"samples":30'));assert.ok(logs[1].includes('not physical display'));assert.equal(item.scheduler.timer,null);app.stop();
});
