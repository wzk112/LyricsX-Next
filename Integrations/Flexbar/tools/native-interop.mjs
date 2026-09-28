import {LyricsBridge} from '../src/bridge.mjs';
import {PlaybackClock} from '../src/clock.mjs';
const clock=new PlaybackClock(),record={nonceVerified:false,events:[]};let originalSession=null,seekSeen=false;
const timeout=setTimeout(()=>{console.error('Native interop timed out '+JSON.stringify(record));bridge.stop();process.exit(1);},5000);
const bridge=new LyricsBridge({socketPath:process.argv[2],onStatus:()=>{},onSync:frame=>{clock.synchronize(frame);record.nonceVerified=true;record.rtt=clock.rtt;},onSnapshot:s=>{
 clock.update(s.clock);
 if(!originalSession){originalSession=s.sessionID;record.events.push({event:'initial',text:s.primary,isPlaying:s.isPlaying,position:clock.position()});}
 if(!s.isPlaying&&!s.suspended&&s.clock?.position===2&&!record.events.some(x=>x.event==='pause'))record.events.push({event:'pause',text:s.primary,rate:s.clock.rate});
 if(!s.isPlaying&&!s.suspended&&s.clock?.position===3){seekSeen=true;if(!record.events.some(x=>x.event==='seek'))record.events.push({event:'seek',position:clock.position()});}
 if(seekSeen&&s.sessionID!==originalSession){record.events.push({event:'reconnect',changedSession:true,text:s.primary});clearTimeout(timeout);bridge.stop();console.log(JSON.stringify(record));process.exit(0);}
}});
bridge.setActive(true);
