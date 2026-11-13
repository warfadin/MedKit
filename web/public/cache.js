const maxAge = 24 * 60 * 60 * 1000;
const memory = new Map();
const inflight = new Map();

export function read(key) {
  try {
    const value = localStorage.getItem('medkit.v1.' + key);
    return value === null ? memory.get(key) : JSON.parse(value);
  } catch {
    return memory.get(key);
  }
}

export function write(key, value) {
  memory.set(key, value);
  try { localStorage.setItem('medkit.v1.' + key, JSON.stringify(value)); } catch { /* Private storage may be unavailable. */ }
}

export function cached(key) {
  return read('content.' + key);
}

export function refresh(key, url, validate, force = false) {
  if (inflight.has(key)) return inflight.get(key);
  const run = async () => {
    if (!navigator.onLine) return 'offline';
    const attempt = read('attempt.' + key);
    if (!force && Number.isFinite(attempt) && Date.now() - attempt < maxAge) return 'skipped';
    write('attempt.' + key, Date.now());
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetch(url, { cache: force ? 'reload' : 'no-cache', signal: controller.signal, credentials: 'omit' });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const data = await response.json();
      if (!validate(data)) throw new Error('Beklenmeyen veri biçimi');
      write('content.' + key, { data, fetchedAt: Date.now() });
      return 'updated';
    } catch {
      return 'failed';
    } finally {
      clearTimeout(timeout);
    }
  };
  const job = (navigator.locks ? navigator.locks.request('medkit.v1.' + key, run) : run())
    .catch(() => 'failed')
    .finally(() => inflight.delete(key));
  inflight.set(key, job);
  return job;
}
