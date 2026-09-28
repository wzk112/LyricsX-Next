export const MAX_FRAME = 65536;
export const graphemes = text => [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(text)].map(x => x.segment);
export class JsonLines {
  constructor(onFrame) { this.pending = Buffer.alloc(0); this.onFrame = onFrame; }
  push(chunk) {
    this.pending = Buffer.concat([this.pending, chunk]);
    let end;
    while ((end = this.pending.indexOf(10)) >= 0) {
      if (end > MAX_FRAME) throw new Error('Frame exceeds 64 KiB');
      const frame = this.pending.subarray(0, end); this.pending = this.pending.subarray(end + 1);
      this.onFrame(JSON.parse(frame.toString('utf8')));
    }
    if (this.pending.length > MAX_FRAME) throw new Error('Incomplete frame exceeds 64 KiB');
  }
}
export function validateSnapshot(value) {
  if (!value || value.version !== 1 || value.kind !== 'snapshot' || typeof value.sessionID !== 'string' || !Number.isSafeInteger(value.revision)) throw new Error('Invalid snapshot envelope');
  if (!['idle','loading','lyrics','song','instrumental','notFound'].includes(value.state)) throw new Error('Invalid content state');
  for (const key of ['title','artist','primary','translation','nextLine']) {
    if (value[key] != null && (typeof value[key] !== 'string' || graphemes(value[key]).length > 4096 || Buffer.byteLength(value[key]) > 8192)) throw new Error('Invalid text field');
  }
  if (value.clock && (!Number.isFinite(value.clock.hostUptime) || !Number.isFinite(value.clock.position) || ![0,1].includes(value.clock.rate))) throw new Error('Invalid clock');
  if (value.timing) {
    const timing = value.timing, count = graphemes(value.primary).length;
    if (!Number.isFinite(timing.start) || !Number.isFinite(timing.end) || !Number.isFinite(timing.offsetMilliseconds) || !Array.isArray(timing.words) || timing.words.length > 128) throw new Error('Invalid timing');
    for (const word of timing.words) if (!Number.isInteger(word.location) || !Number.isInteger(word.length) || word.location < 0 || word.length < 1 || word.location + word.length > count || !Number.isFinite(word.start) || !Number.isFinite(word.end) || word.end < word.start) throw new Error('Invalid word range');
  }
  return value;
}
export function presentationSignature(s) {
  return JSON.stringify([s.state,s.primary,s.translation,s.nextLine,s.title,s.artist,s.timing]);
}
