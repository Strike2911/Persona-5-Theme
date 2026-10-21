export async function waitForConnection(port, timeout, {connectImpl=connect, now=Date.now, sleep=ms=>new Promise(r=>setTimeout(r,ms))}={}) {
  const deadline=now()+timeout;
  let lastError;
  while(now()<deadline) {
    try {return await connectImpl(port);}
    catch(error) {
      if(error.code==='P5_UNSAFE_ENDPOINT') throw error;
      lastError=error;
      await sleep(Math.min(700,Math.max(0,deadline-now())));
    }
  }
  const detail=lastError?.cause?.code || lastError?.code || lastError?.message || 'sin respuesta';
  const error=new Error(`WhatsApp no respondio a la conexion local del tema (${detail}).`,{cause:lastError});
  error.code='P5_CONNECT_TIMEOUT'; throw error;
}
export async function connect(port) {
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw Error('Puerto no valido');
  const targets = await fetch(`http://127.0.0.1:${port}/json/list`, {signal: AbortSignal.timeout(2000)}).then(r => r.json());
  const target = targets.find(t => t.type === 'page' && new URL(t.url).origin === 'https://web.whatsapp.com');
  if (!target) throw Error('La ventana de WhatsApp todavia no esta lista');
  const address = new URL(target.webSocketDebuggerUrl);
  if (address.protocol !== 'ws:' || address.hostname !== '127.0.0.1' || address.port !== String(port)) {
    const error=Error('Destino de depuracion inesperado'); error.code='P5_UNSAFE_ENDPOINT'; throw error;
  }
  const socket = new WebSocket(address);
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { socket.close(); reject(Error('Timeout al conectar')); }, 3000);
    socket.addEventListener('open', () => { clearTimeout(timeout); resolve(); }, {once:true});
    socket.addEventListener('error', () => { clearTimeout(timeout); reject(Error('No se pudo conectar')); }, {once:true});
  });
  let id = 0;
  const pending = new Map();
  const listeners = new Map();
  socket.addEventListener('message', event => {
    const data = JSON.parse(event.data);
    if(data.method) for(const listener of listeners.get(data.method)||[]) { try{listener(data.params);}catch{} }
    const call = pending.get(data.id);
    if (!call) return;
    pending.delete(data.id);
    clearTimeout(call.timeout);
    if (data.error) call.reject(Error(data.error.message)); else call.resolve(data.result);
  });
  socket.addEventListener('close', () => {
    for(const listener of listeners.get('P5.connectionClosed')||[]) {try{listener();}catch{}}
    for (const call of pending.values()) { clearTimeout(call.timeout); call.reject(Error('WhatsApp se cerro')); }
    pending.clear();
  });
  return {
    on(method,listener){if(!listeners.has(method))listeners.set(method,new Set());listeners.get(method).add(listener);return()=>listeners.get(method)?.delete(listener);},
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
