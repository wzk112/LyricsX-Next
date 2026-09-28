import { PlaybackClock, monotonic } from './clock.mjs';
import { LyricsBridge } from './bridge.mjs';
import { Renderer } from './renderer.mjs';
import { DrawScheduler } from './scheduler.mjs';
export const UUID = 'com.wzk112.lyricsxnext';
export const KEY_CARD = UUID+'.lyrics', KEY_SCREEN = UUID+'.immersive';
const idle = () => ({version:1,kind:'snapshot',sessionID:'offline',revision:0,state:'idle',title:'',artist:'',primary:'请打开 LyricsX Next',translation:'在设置中启用 Flexbar',isPlaying:false,suspended:false});
const normalizedFlip=value=>typeof value==='boolean'?value:value===0?false:value===1?true:undefined;
export class LyricsPlugin {
  constructor(plugin,{bridgeFactory=options=>new LyricsBridge(options), now=monotonic,logger={warn:()=>{}}}={}) {
    Object.assign(this,{plugin,now,logger});this.keys=new Map();this.devices=new Map();this.clock=new PlaybackClock(now);this.snapshot=idle();
    this.hostGeneration=0;this.statusRequest=null;this.statusFollowup=false;this.statusDiagnosticGeneration=-1;this.lastTouch=new Map();
    this.bridge=bridgeFactory({onSnapshot:s=>this.receive(s),onSync:s=>this.clock.synchronize(s),onStatus:status=>{if(status==='disconnected'){this.clock.reset();this.snapshot=idle();this.requestAll();}}});
    plugin.on('plugin.alive',p=>this.alive(p));plugin.on('plugin.dead',p=>this.dead(p));
    plugin.on('device.status',devices=>this.deviceStatus(devices));
    plugin.on('device.touch',payload=>{if(payload.state!=='up'&&payload.state!=='end')return;const now=this.now(),last=this.lastTouch.get(payload.serialNumber)??-Infinity;if(now-last<0.25)return;this.lastTouch.set(payload.serialNumber,now);for(const item of this.keys.values())if(item.serialNumber===payload.serialNumber&&item.key.cid===KEY_SCREEN){item.renderer.nextPage();item.scheduler.request();}});
    plugin.on('plugin.data',p=>{const item=this.keys.get(this.identity(p.serialNumber,p.data?.key));if(item&&p.data?.evt==='click'){item.renderer.nextPage();item.scheduler.request();}return {status:'success'};});
  }
  identity(serial,key){return `${serial}:${key?.uid}`;}
  options(key){
    const data=key.data??{},immersive=key.cid===KEY_SCREEN;
    return {secondary:['translation','next','off'].includes(data.secondary)?data.secondary:'translation',fps:[15,20,30,60].includes(Number(data.fps))?Number(data.fps):30,diffUpdate:data.diffUpdate===true,immersive,
      orientation:['auto','normal','flipped'].includes(data.orientation)?data.orientation:'auto',alignment:['center','left'].includes(data.alignment)?data.alignment:immersive?'center':'left',rotation:0};
  }
  effectiveRotation(serial,options){return options.immersive&&(options.orientation==='flipped'||options.orientation==='auto'&&this.devices.get(serial)?.screenFlip===true)?180:0;}
  applyDeviceFlip(serial,flip){
    flip=normalizedFlip(flip);
    if(typeof flip!=='boolean')return;
    const record=this.devices.get(serial)??{revision:0};
    const first=record.screenFlip===undefined;record.screenFlip=flip;this.devices.set(serial,record);
    if(first)this.logger.info?.(`Flexbar screenFlip: ${flip}`);
    for(const item of this.keys.values())if(item.serialNumber===serial){const rotation=this.effectiveRotation(serial,item.options);if(rotation!==item.options.rotation){item.options.rotation=rotation;item.orientationRevision++;item.scheduler.request();}}
  }
  hostReady(){this.logger.info?.('Flexbar hostReady: requesting device orientation');this.refreshDeviceStatus();}
  refreshDeviceStatus(needsFollowup=false){
    if(!this.plugin.transport?.call)return Promise.resolve();
    if(this.statusRequest){if(needsFollowup)this.statusFollowup=true;return this.statusRequest;}
    const generation=this.hostGeneration,revisions=new Map([...this.devices].map(([serial,record])=>[serial,record.revision]));
    // Use the SDK's own timeout so pendingCalls is deleted, rather than racing
    // its unbounded getDeviceStatus() Promise with a separate timeout.
    const request=Promise.resolve().then(()=>generation===this.hostGeneration?this.plugin.transport.call('api-call',{api:'getDeviceStatus',args:null},5000):[]).then(devices=>{
      if(generation!==this.hostGeneration)return;
      if(this.statusDiagnosticGeneration!==generation){
        this.statusDiagnosticGeneration=generation;
        const keys=value=>value&&typeof value==='object'?Object.keys(value):[];
        const shape={type:devices===null?'null':Array.isArray(devices)?'array':typeof devices,count:Array.isArray(devices)?devices.length:null,keys:keys(devices)};
        if(Array.isArray(devices))shape.devices=devices.map(device=>{
          const serial=device?.serialNumber,current=this.devices.get(serial),flip=device?.deviceData?.config?.screenFlip;
          const safeFlip=typeof flip==='boolean'||typeof flip==='number'&&Number.isFinite(flip)||typeof flip==='string'&&['true','false','0','1'].includes(flip)?flip:flip===undefined?'missing':'unknown';
          const skipped=typeof serial!=='string'?'invalidSerial':current?.connected===false?'disconnected':(current?.revision??0)!==(revisions.get(serial)??0)?'staleRevision':null;
          return {serialNumber:typeof serial==='string'?serial:null,keys:keys(device),deviceDataKeys:keys(device?.deviceData),configKeys:keys(device?.deviceData?.config),flipType:typeof flip,screenFlip:safeFlip,skipped};
        });
        this.logger.info?.('Flexbar getDeviceStatus shape: '+JSON.stringify(shape));
      }
      if(!Array.isArray(devices)||!devices.length){this.logger.warn('Flexbar automatic orientation unknown: device status is not a nonempty array');return;}
      for(const device of devices){
        if(!device||typeof device.serialNumber!=='string')continue;const current=this.devices.get(device.serialNumber);
        if(current?.connected===false)continue;
        if((current?.revision??0)!==(revisions.get(device.serialNumber)??0))continue;
        const flip=normalizedFlip(device.deviceData?.config?.screenFlip);if(flip===undefined)this.logger.warn('Flexbar automatic orientation unknown: screenFlip missing for '+device.serialNumber);this.applyDeviceFlip(device.serialNumber,flip);
      }
    }).catch(error=>{if(generation===this.hostGeneration)this.logger.warn('Cannot read Flexbar screen orientation: '+error.message);}).finally(()=>{
      if(this.statusRequest===request)this.statusRequest=null;
      if(generation===this.hostGeneration&&this.statusFollowup){this.statusFollowup=false;this.refreshDeviceStatus();}
    });
    this.statusRequest=request;return request;
  }
  deviceStatus(devices){
    for(const device of devices??[]){
      const record=this.devices.get(device.serialNumber)??{revision:0};record.revision++;if(device.status==='connected'||device.status==='disconnected')record.connected=device.status==='connected';this.devices.set(device.serialNumber,record);
      if(device.status==='disconnected'){record.screenFlip=undefined;this.removeDevice(device.serialNumber);continue;}
      if(normalizedFlip(device.deviceData?.config?.screenFlip)!==undefined)this.applyDeviceFlip(device.serialNumber,device.deviceData.config.screenFlip);
      else if(this.statusRequest)this.statusFollowup=true;
      else if([...this.keys.values()].some(item=>item.serialNumber===device.serialNumber&&item.options.immersive))this.refreshDeviceStatus();
    }
  }
  alive({serialNumber,keys}) {
    const record=this.devices.get(serialNumber)??{revision:0};record.connected=true;this.devices.set(serialNumber,record);
    let immersive=false;
    for(const key of keys??[]) {
      if(![KEY_CARD,KEY_SCREEN].includes(key.cid))continue;
      const identity=this.identity(serialNumber,key);this.keys.get(identity)?.scheduler.stop();
      const renderer=new Renderer(),options=this.options(key),width=options.immersive?2170:Math.max(120,Math.min(1000,Number(key.width||key.style?.width||720)));
      options.rotation=this.effectiveRotation(serialNumber,options);immersive ||= options.immersive;
      const item={key,renderer,serialNumber,options,orientationRevision:0,completedOrientationRevision:-1,scheduler:null,drawMeasurements:{samples:0,total:0,max:0}};
      item.scheduler=new DrawScheduler({render:()=>renderer.render(this.snapshot,width,this.clock.position(),this.now(),options),draw:async frame=>{
        const revision=item.orientationRevision,data='data:image/png;base64,'+frame.png.toString('base64'),started=this.now();
        if(options.immersive)await this.plugin.directDraw(serialNumber,key,data,options.diffUpdate&&item.completedOrientationRevision===revision,0);
        else await this.plugin.draw(serialNumber,key,'base64',data);
        if(this.keys.get(identity)===item&&item.drawMeasurements.samples<30){
          const stats=item.drawMeasurements,duration=Math.max(0,(this.now()-started)*1000);stats.samples++;stats.total+=duration;stats.max=Math.max(stats.max,duration);
          if(stats.samples===1||stats.samples===30)this.logger.info?.('Flexbar draw API ACK (not physical display): '+JSON.stringify({serialNumber,uid:key.uid,mode:options.immersive?'directDraw':'card',samples:stats.samples,meanMilliseconds:stats.total/stats.samples,maxMilliseconds:stats.max}));
        }
        if(this.keys.get(identity)===item&&item.orientationRevision===revision)item.completedOrientationRevision=revision;
      },onError:error=>this.logger.warn('Flexbar draw failed: '+error.message)});
      this.keys.set(identity,item);item.scheduler.request();
    }
    this.reconcileDemand();if(immersive)this.refreshDeviceStatus(true);
  }
  reconcileDemand(){const active=this.keys.size>0;if(!active){this.clock.reset();this.snapshot=idle();}this.bridge.setActive(active);}
  dead({serialNumber,keys}) {for(const key of keys??[])this.remove(this.identity(serialNumber,key));this.reconcileDemand();}
  remove(identity){const item=this.keys.get(identity);if(item){item.scheduler.stop();this.keys.delete(identity);}}
  removeDevice(serial){this.lastTouch.delete(serial);for(const [identity,item]of this.keys)if(item.serialNumber===serial)this.remove(identity);this.reconcileDemand();}
  receive(snapshot){if(snapshot.sessionID!==this.snapshot.sessionID){for(const item of this.keys.values())item.renderer.reset();}this.snapshot=snapshot;this.clock.update(snapshot.clock);this.requestAll();}
  requestAll(){for(const item of this.keys.values())item.scheduler.request();}
  hostLost(){this.hostGeneration++;this.statusRequest=null;this.statusFollowup=false;this.devices.clear();this.lastTouch.clear();for(const identity of [...this.keys.keys()])this.remove(identity);this.bridge.setActive(false);this.clock.reset();this.snapshot=idle();}
  stop(){this.hostLost();this.bridge.stop();}
}
