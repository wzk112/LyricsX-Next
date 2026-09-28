import WebSocket from 'ws';
export function repairHostTransport(plugin, {onLost = () => {}, onReady = () => {}} = {}) {
  const transport = plugin.transport;
  let stopped = false, retry = null, current = null;
  const clearPending = () => {
    for (const [id, call] of Object.entries(transport.pendingCalls)) { clearTimeout(call.timer); call.reject(new Error('FlexDesigner disconnected')); delete transport.pendingCalls[id]; }
  };
  transport.start = () => {
    if (stopped || current) return;
    const ws = new WebSocket(`ws://127.0.0.1:${transport.port}`); current = ws; transport.ws = ws;
    let lost = false;
    const lose = () => {
      if (lost || stopped) return; lost = true; current = null; clearPending(); onLost();
      if (!retry) retry = setTimeout(() => { retry = null; transport.start(); }, 5000);
    };
    ws.on('open', () => { transport._send('startup',{pluginID:transport.uuid}); onReady(); });
    ws.on('message', bytes => transport._handleMessage(bytes.toString()).catch(() => {}));
    ws.on('close', lose); ws.on('error', () => { ws.terminate(); lose(); });
  };
  return () => { stopped = true; clearTimeout(retry); retry = null; clearPending(); current?.removeAllListeners(); current?.terminate(); current = null; };
}
