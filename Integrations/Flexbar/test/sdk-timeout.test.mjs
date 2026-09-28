import test from 'node:test';
import assert from 'node:assert/strict';
import {LyricsPlugin} from '../src/lifecycle.mjs';
test('bounded orientation query uses SDK timeout cleanup and one inflight request',async()=>{
 const originalArgs=[...process.argv];process.argv.push('--uid=lyricsx-timeout-test','--port=1','--dir=/tmp');
 const {plugin}=await import('@eniac/flexdesigner');process.argv.splice(0,process.argv.length,...originalArgs);
 const transport=plugin.transport,originalCall=transport.call.bind(transport);let receivedTimeout,calls=0;
 transport._send=()=>`timeout-test-${++calls}`;
 // Shorten only this test's actual timer while recording the production timeout.
 transport.call=(command,payload,timeout)=>{receivedTimeout=timeout;return originalCall(command,payload,10);};
 const app=new LyricsPlugin(plugin,{bridgeFactory:()=>({setActive:()=>{},stop:()=>{}}),logger:{warn:()=>{}}});
 app.hostReady();const first=app.statusRequest;app.hostReady();assert.equal(app.statusRequest,first);await first;
 assert.equal(receivedTimeout,5000);assert.equal(calls,1);assert.equal(Object.keys(transport.pendingCalls).length,0);app.stop();
});
