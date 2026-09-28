import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { JsonLines, validateSnapshot } from './codec.mjs';
import { monotonic } from './clock.mjs';
export class LyricsBridge {
  constructor({onSnapshot,onSync,onStatus, socketPath = path.join(os.homedir(),'Library/Application Support/LyricsX Next/Flexbar/bridge.sock'), connect = options => net.createConnection(options), now = monotonic}) {
    Object.assign(this,{onSnapshot,onSync,onStatus,socketPath,connect,now});
    this.active = false; this.socket = null; this.retry = null; this.attempt = 0; this.session = null; this.revision = -1; this.generation = 0;
  }
  setActive(active) { if (active === this.active) return; this.active = active; if (active) this.open(); else this.stop(); }
  open() {
    if (!this.active || this.socket) return;
    const token = ++this.generation, nonce = randomUUID();
    this.nonce = nonce;
    const socket = this.connect({path:this.socketPath}); this.socket = socket;
    const parser = new JsonLines(frame => {
      if (frame.kind === 'clockSync') { if (frame.nonce !== nonce) throw new Error('Clock nonce mismatch'); this.onSync(frame); return; }
      const snapshot = validateSnapshot(frame);
      if (snapshot.sessionID !== this.session) { this.session = snapshot.sessionID; this.revision = -1; }
      if (snapshot.revision <= this.revision) return;
      this.revision = snapshot.revision; this.attempt = 0; this.onStatus('connected'); this.onSnapshot(snapshot);
    });
    socket.on('connect', () => { if (this.generation !== token) return; socket.write(JSON.stringify({version:1,kind:'subscribe',clientTime:this.now(),nonce})+'\n'); });
    socket.on('data', chunk => { if (this.generation !== token) return; try { parser.push(chunk); } catch { socket.destroy(); } });
    socket.on('error', () => {});
    socket.on('close', () => {
      if (this.generation !== token) return;
      this.socket = null; this.session = null; this.revision = -1; this.onStatus('disconnected');
      if (this.active && !this.retry) {
        const delay = Math.min(30000, 1000 * 2 ** Math.min(this.attempt++,5));
        this.retry = setTimeout(() => { this.retry = null; this.open(); }, delay);
      }
    });
  }
  stop() {
    this.active = false; this.generation++; clearTimeout(this.retry); this.retry = null;
    this.socket?.destroy(); this.socket = null; this.session = null; this.revision = -1;
  }
}
