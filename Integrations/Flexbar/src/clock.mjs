export const monotonic = () => Number(process.hrtime.bigint()) / 1e9;
export class PlaybackClock {
  constructor(now = monotonic) { this.now = now; this.offset = null; this.rtt = null; this.anchor = null; }
  synchronize({echoClientTime,serverUptime}, received = this.now()) {
    if (!Number.isFinite(echoClientTime) || !Number.isFinite(serverUptime) || received < echoClientTime) throw new Error('Invalid clock synchronization');
    this.rtt = received - echoClientTime; this.offset = serverUptime - (echoClientTime + received) / 2;
  }
  update(anchor) { this.anchor = anchor ?? null; }
  position(now = this.now()) {
    if (!this.anchor) return 0;
    if (this.offset == null || !this.anchor.rate) return this.anchor.position;
    return Math.max(0, this.anchor.position + (now + this.offset - this.anchor.hostUptime) * this.anchor.rate);
  }
  reset() { this.anchor = null; this.offset = null; this.rtt = null; }
}
