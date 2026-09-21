export async function connect(port) {
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw Error('Puerto no valido');
  const targets = await fetch(`http://127.0.0.1:${port}/json/list`, {signal: AbortSignal.timeout(2000)}).then(r => r.json());
  const target = targets.find(t => t.type === 'page' && new URL(t.url).origin === 'https://web.whatsapp.com');
  if (!target) throw Error('La ventana de WhatsApp todavia no esta lista');
  const address = new URL(target.webSocketDebuggerUrl);
  if (address.hostname !== '127.0.0.1' || address.port !== String(port)) throw Error('Destino de depuracion inesperado');
  const socket = new WebSocket(address);
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { socket.close(); reject(Error('Timeout al conectar')); }, 3000);
    socket.addEventListener('open', () => { clearTimeout(timeout); resolve(); }, {once:true});
    socket.addEventListener('error', () => { clearTimeout(timeout); reject(Error('No se pudo conectar')); }, {once:true});
  });
  let id = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const data = JSON.parse(event.data);
    const call = pending.get(data.id);
    if (!call) return;
    pending.delete(data.id);
    clearTimeout(call.timeout);
    if (data.error) call.reject(Error(data.error.message)); else call.resolve(data.result);
  });
  socket.addEventListener('close', () => {
    for (const call of pending.values()) { clearTimeout(call.timeout); call.reject(Error('WhatsApp se cerro')); }
    pending.clear();
  });
  return {
    close: () => socket.close(),
    send(method, params = {}) {
      return new Promise((resolve, reject) => {
        const messageId = ++id;
        const timeout = setTimeout(() => { pending.delete(messageId); reject(Error(`Timeout: ${method}`)); }, 10000);
        pending.set(messageId, {resolve, reject, timeout});
        socket.send(JSON.stringify({id: messageId, method, params}));
      });
    }
  };
}
