import test from 'node:test';
import assert from 'node:assert/strict';
import {WebSocketServer} from 'ws';
import {spawn} from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {loadImage} from '@napi-rs/canvas';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
test('packaged CJS starts under host arguments and resolves portable Canvas',async()=>{
 const directory=await fs.mkdtemp('/tmp/lx-flex-host-'),server=new WebSocketServer({port:0,host:'127.0.0.1'});await new Promise(resolve=>server.once('listening',resolve));
 const child=spawn(process.execPath,[path.join(root,'com.wzk112.lyricsxnext.plugin/backend/plugin.cjs'),`--port=${server.address().port}`,'--uid=com.wzk112.lyricsxnext',`--dir=${directory}`],{stdio:['ignore','pipe','pipe']});let output='';child.stdout.on('data',chunk=>output+=chunk);child.stderr.on('data',chunk=>output+=chunk);
 const seen=[];let statusRequested=false;
 try {
  await new Promise((resolve,reject)=>{
   const timeout=setTimeout(()=>reject(new Error('Bundle host mock timed out: '+output)),4000);
   child.once('exit',code=>{if(code){clearTimeout(timeout);reject(new Error('Bundle exited '+code+': '+output));}});
   server.on('connection',socket=>socket.on('message',bytes=>{
    const command=JSON.parse(bytes.toString());
    if(command.type==='api-call'&&command.payload.api==='getDeviceStatus'){statusRequested=true;socket.send(JSON.stringify({uuid:command.uuid,status:'success',payload:[{serialNumber:'MOCK',deviceData:{config:{screenFlip:true}}}]}));}
    if(command.type==='startup')socket.send(JSON.stringify({uuid:'alive',type:'plugin.alive',payload:{serialNumber:'MOCK',keys:[{cid:'com.wzk112.lyricsxnext.lyrics',uid:1,width:720},{cid:'com.wzk112.lyricsxnext.immersive',uid:2,width:2170}]}}));
    if(command.type==='draw'||command.type==='direct-draw'){
     seen.push(command);socket.send(JSON.stringify({uuid:command.uuid,status:'success',payload:{}}));
     if(seen.length===2){clearTimeout(timeout);resolve();}
    }
   }));
  });
  assert.equal(seen.length,2);
  assert.equal(statusRequested,true,'hostReady must call the official getDeviceStatus transport API');
  for(const command of seen){const data=command.payload.base64??command.payload.data;assert.ok(data.startsWith('data:image/png;base64,'));const image=await loadImage(Buffer.from(data.split(',')[1],'base64'));assert.equal(image.height,60);assert.equal(image.width,command.type==='draw'?720:2170);}
 } finally {
  child.kill('SIGTERM');await new Promise(resolve=>child.once('exit',resolve));for(const client of server.clients)client.terminate();await new Promise(resolve=>server.close(resolve));await fs.rm(directory,{recursive:true,force:true});
 }
});
