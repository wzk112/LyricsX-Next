export class DrawScheduler {
  constructor({render,draw,onError=()=>{},now=()=>performance.now(),setTimer=setTimeout,clearTimer=clearTimeout}) {
    Object.assign(this,{render,draw,onError,now,setTimer,clearTimer});
    this.active=true;this.timer=null;this.busy=false;this.latest=false;this.successSignature=null;this.lastRender=null;this.latency=0;this.failures=0;this.drawCount=0;this.skipped=0;this.generation=0;
  }
  request() {
    if(!this.active)return;
    this.clearTimer(this.timer);this.timer=null;
    if(this.busy){this.latest=true;return;}
    this.run();
  }
  async run() {
    if(!this.active||this.busy)return;
    const frameStarted=this.now();const result=this.render();this.lastRender=result;
    if(result.signature===this.successSignature){this.skipped++;this.schedule(result.nextDelay,this.now()-frameStarted);return;}
    this.busy=true;this.latest=false;const token=this.generation,start=this.now();
    try{await this.draw(result);if(this.active&&this.generation===token){this.successSignature=result.signature;this.failures=0;this.drawCount++;this.latency=this.now()-start;}}
    catch(error){if(this.active&&this.generation===token){this.failures++;this.onError(error);}}
    finally{
      this.busy=false;
      if(!this.active||this.generation!==token)return;
      if(this.failures){this.schedule(Math.min(10000,250*2**Math.min(this.failures-1,5)));}
      else if(this.latest){this.latest=false;this.run();}
      else this.schedule(result.nextDelay,this.now()-frameStarted);
    }
  }
  schedule(delay,elapsed=0){if(!this.active||delay==null)return;this.clearTimer(this.timer);this.timer=this.setTimer(()=>{this.timer=null;this.run();},Math.max(0,Math.max(delay,this.latency*1.15)-elapsed));}
  stop(){this.active=false;this.generation++;this.latest=false;this.clearTimer(this.timer);this.timer=null;}
  get pendingFrames(){return Number(this.busy)+Number(this.latest);}
}
