import { createServer } from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { randomBytes, scrypt, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const derive = promisify(scrypt);
const sha = (value) => createHash('sha256').update(value).digest('hex');
const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };
const DAY = 86400000;
// All business dates use the Brazilian calendar, with UTC only for arithmetic.
export const today = () => new Intl.DateTimeFormat('en-CA', {
  timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit',
}).format(new Date());
function string(value, label, min = 1, max = 200) {
  if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max) {
    fail(400, `${label}: informe entre ${min} e ${max} caracteres.`);
  }
  return value.trim();
}
function integer(value, label, min, max) {
  if (!Number.isSafeInteger(value) || value < min || value > max) fail(400, `${label} inválido.`);
  return value;
}
function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) fail(400, 'Data inválida.');
  const stamp = Date.parse(`${value}T00:00:00Z`);
  if (!Number.isFinite(stamp) || new Date(stamp).toISOString().slice(0, 10) !== value) fail(400, 'Data inválida.');
  return stamp;
}
function period(body) {
  const start = date(body.start_date), end = date(body.end_date), base = date(today());
  if (start < base || end <= start || end > base + DAY * 730 || end - start > DAY * 90) {
    fail(400, 'Selecione de 1 a 90 noites, nos próximos dois anos.');
  }
  return (end - start) / DAY;
}
function email(value) {
  const result = string(value, 'E-mail', 3, 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result)) fail(400, 'E-mail inválido.');
  return result;
}
function password(value) {
  if (typeof value !== 'string' || value.length < 10 || value.length > 128) fail(400, 'Use uma senha com 10 a 128 caracteres.');
  return value;
}
async function hashPassword(value) {
  const salt = randomBytes(16).toString('hex');
  const key = await derive(value, salt, 64);
  return `${salt}:${key.toString('hex')}`;
}
async function verifyPassword(value, stored) {
  const [salt, key] = stored.split(':');
  const calculated = await derive(value, salt, 64);
  return timingSafeEqual(Buffer.from(key, 'hex'), calculated);
}
async function readBody(req) {
  if (!req.headers['content-type']?.startsWith('application/json')) fail(415, 'Envie JSON.');
  let size = 0;
  const parts = [];
  for await (const part of req) {
    size += part.length;
    if (size > 4.2 * 1024 * 1024) fail(413, 'Arquivo ou formulário muito grande.');
    parts.push(part);
  }
  let body;
  try { body = JSON.parse(Buffer.concat(parts).toString()); } catch { fail(400, 'JSON inválido.'); }
  if (!body || Array.isArray(body) || typeof body !== 'object') fail(400, 'Objeto JSON esperado.');
  return body;
}

export async function createApp({ dataDir = resolve('data'), allowedOrigins = ['http://localhost:5300'], resetDelivery } = {}) {
  mkdirSync(join(dataDir, 'uploads'), { recursive: true });
  const db = new DatabaseSync(join(dataDir, 'casa_da_praia.sqlite'));
  db.exec(readFileSync(new URL('./schema.sql', import.meta.url), 'utf8'));
  const run = (sql, ...args) => db.prepare(sql).run(...args);
  const one = (sql, ...args) => db.prepare(sql).get(...args);
  const all = (sql, ...args) => db.prepare(sql).all(...args);
  const transaction = (operation) => {
    db.exec('BEGIN IMMEDIATE');
    try { const result = operation(); db.exec('COMMIT'); return result; }
    catch (error) { db.exec('ROLLBACK'); throw error; }
  };
  const publicUser = (user) => ({ id: user.id, name: user.name, email: user.email });
  const tokenFrom = (req) => (req.headers.authorization || '').replace(/^Bearer /, '');
  function currentUser(req) {
    const token = tokenFrom(req);
    if (!/^[a-f0-9]{64}$/.test(token)) fail(401, 'Entre na sua conta para continuar.');
    const user = one(`SELECT u.* FROM users u JOIN sessions s ON u.id = s.user_id
      WHERE s.token_hash = ? AND s.expires_at > ?`, sha(token), Date.now());
    if (!user) fail(401, 'Sua sessão expirou. Entre novamente.');
    return user;
  }
  function session(user) {
    const token = randomBytes(32).toString('hex');
    run('DELETE FROM sessions WHERE expires_at <= ?', Date.now());
    run('INSERT INTO sessions VALUES (?, ?, ?)', sha(token), user.id, Date.now() + 7 * DAY);
    return { token, user: publicUser(user) };
  }
  function house(id) {
    const item = one('SELECT * FROM houses WHERE id = ?', id);
    if (!item) fail(404, 'Casa não encontrada.');
    return { ...item, amenities: JSON.parse(item.amenities), photos: all('SELECT url FROM photos WHERE house_id = ? ORDER BY position', id).map((p) => p.url) };
  }
  function owner(user, id) {
    const item = house(id);
    if (item.owner_id !== user.id) fail(403, 'Você não pode alterar este anúncio.');
    return item;
  }
  function houseInput(body, user) {
    const result = {
      name: string(body.name, 'Nome', 3, 100), city: string(body.city, 'Cidade', 3, 100),
      description: string(body.description, 'Descrição', 20, 4000),
      price_cents: integer(body.price_cents, 'Diária', 100, 10000000),
      guests: integer(body.guests, 'Hóspedes', 1, 30), bedrooms: integer(body.bedrooms, 'Quartos', 1, 20),
      active: body.active === false || body.active === 0 ? 0 : 1,
    };
    if (!Array.isArray(body.amenities) || body.amenities.length > 20) fail(400, 'Comodidades inválidas.');
    result.amenities = [...new Set(body.amenities.map((a) => string(a, 'Comodidade', 1, 50)))];
    if (!Array.isArray(body.photos) || body.photos.length < 1 || body.photos.length > 10) fail(400, 'Adicione de 1 a 10 fotos.');
    result.photos = body.photos.map((url) => {
      string(url, 'Foto', 1, 300);
      if (!/^\/uploads\/[a-f0-9]{32}\.(jpg|png|webp)$/.test(url)) fail(400, 'Envie as fotos pelo aplicativo.');
      if (!one('SELECT filename FROM uploads WHERE filename = ? AND owner_id = ?', url.slice(9), user.id)) fail(403, 'Esta foto não pertence à sua conta.');
      return url;
    });
    return result;
  }
  const attempts = new Map();
  function throttle(req, group, max = 25) {
    const key = `${req.socket.remoteAddress}:${group}`, now = Date.now();
    for (const [key, item] of attempts) if (item.until < now) attempts.delete(key);
    const item = attempts.get(key) || { count: 0, until: now + 15 * 60000 };
    if (++item.count > max) fail(429, 'Muitas tentativas. Aguarde 15 minutos.');
    attempts.set(key, item);
  }
  const dummyHash = await hashPassword(randomBytes(32).toString('hex'));
  const server = createServer(async (req, res) => {
    const json = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(body));
    };
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Origin');
    try {
      const origin = req.headers.origin;
      if (origin && !allowedOrigins.includes(origin)) fail(403, 'Origem não permitida.');
      if (origin) res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
      const url = new URL(req.url, 'http://localhost');
      const path = url.pathname, method = req.method;
      if (method === 'GET' && path === '/health') return json(200, { status: 'ok' });
      if (method === 'GET' && /^\/uploads\/[a-f0-9]{32}\.(jpg|png|webp)$/.test(path)) {
        const file = join(dataDir, path.slice(1));
        if (!existsSync(file)) fail(404, 'Foto não encontrada.');
        res.setHeader('Cache-Control', 'public, max-age=86400');
        res.writeHead(200, { 'Content-Type': path.endsWith('.jpg') ? 'image/jpeg' : path.endsWith('.png') ? 'image/png' : 'image/webp' });
        return res.end(readFileSync(file));
      }
      if (method === 'POST' && path === '/auth/register') {
        throttle(req, 'auth');
        const b = await readBody(req), address = email(b.email), name = string(b.name, 'Nome', 2, 100);
        const hash = await hashPassword(password(b.password));
        let id;
        try { id = Number(run('INSERT INTO users(name,email,password_hash) VALUES (?,?,?)', name, address, hash).lastInsertRowid); }
        catch (e) { if (e.message.includes('UNIQUE')) fail(409, 'Já existe uma conta com esse e-mail.'); throw e; }
        return json(201, session(one('SELECT * FROM users WHERE id = ?', id)));
      }
      if (method === 'POST' && path === '/auth/login') {
        throttle(req, 'auth');
        const b = await readBody(req), address = email(b.email);
        const supplied = typeof b.password === 'string' && b.password.length <= 128 ? b.password : '';
        const user = one('SELECT * FROM users WHERE email = ?', address);
        const valid = await verifyPassword(supplied, user?.password_hash || dummyHash);
        if (!user || !valid) fail(401, 'E-mail ou senha incorretos.');
        return json(200, session(user));
      }
      if (method === 'POST' && path === '/auth/forgot') {
        throttle(req, 'reset', 8);
        if (!resetDelivery) fail(503, 'A recuperação de senha ainda não foi configurada pelo administrador.');
        const b = await readBody(req), address = email(b.email), user = one('SELECT * FROM users WHERE email = ?', address);
        if (user) {
          const token = randomBytes(32).toString('hex');
          transaction(() => { run('DELETE FROM resets WHERE user_id = ? OR expires_at <= ?', user.id, Date.now()); run('INSERT INTO resets VALUES (?,?,?)', sha(token), user.id, Date.now() + 15 * 60000); });
          // Dispatch asynchronously so the HTTP response does not reveal membership.
          Promise.resolve().then(() => resetDelivery(address, token)).catch(() => console.error('Falha na entrega de recuperação.'));
        }
        return json(200, { message: 'Se a conta existir, você receberá um código com validade de 15 minutos.' });
      }
      if (method === 'POST' && path === '/auth/reset') {
        throttle(req, 'reset');
        const b = await readBody(req), token = string(b.token, 'Código', 64, 64);
        const hash = await hashPassword(password(b.password));
        transaction(() => {
          const reset = one('SELECT * FROM resets WHERE token_hash = ? AND expires_at > ?', sha(token), Date.now());
          if (!reset) fail(400, 'Código inválido ou expirado.');
          run('UPDATE users SET password_hash = ? WHERE id = ?', hash, reset.user_id);
          run('DELETE FROM sessions WHERE user_id = ?', reset.user_id);
          run('DELETE FROM resets WHERE user_id = ?', reset.user_id);
        });
        return json(200, { message: 'Senha alterada. Entre novamente.' });
      }
      if (method === 'GET' && path === '/auth/me') return json(200, { user: publicUser(currentUser(req)) });
      if (method === 'POST' && path === '/auth/logout') {
        currentUser(req); run('DELETE FROM sessions WHERE token_hash = ?', sha(tokenFrom(req)));
        return json(200, { message: 'Sessão encerrada.' });
      }
      if (method === 'GET' && path === '/houses') {
        const q = (url.searchParams.get('q') || '').trim().slice(0, 100).toLocaleLowerCase('pt-BR');
        const max = url.searchParams.has('max_price') ? integer(Number(url.searchParams.get('max_price')), 'Preço máximo', 100, 10000000) : 10000000;
        const guests = integer(Number(url.searchParams.get('guests') || 1), 'Hóspedes', 1, 30);
        const items = all('SELECT id FROM houses WHERE active = 1 AND price_cents <= ? AND guests >= ? ORDER BY id DESC', max, guests)
          .map((row) => house(row.id)).filter((h) => `${h.name} ${h.city}`.toLocaleLowerCase('pt-BR').includes(q));
        return json(200, { houses: items });
      }
      let match = path.match(/^\/houses\/(\d+)$/);
      if (method === 'GET' && match) {
        const item = house(Number(match[1]));
        if (!item.active) { const user = currentUser(req); if (user.id !== item.owner_id) fail(404, 'Anúncio indisponível.'); }
        return json(200, { house: item });
      }
      match = path.match(/^\/houses\/(\d+)\/availability$/);
      if (method === 'GET' && match) {
        const id = Number(match[1]), item = house(id);
        if (!item.active) owner(currentUser(req), id);
        // Public availability never exposes guests or booking IDs.
        const ranges = all(`SELECT start_date, end_date FROM bookings WHERE house_id = ? AND status = 'confirmed' AND end_date > ?
          UNION ALL SELECT start_date, end_date FROM blocks WHERE house_id = ? AND end_date > ?`, id, today(), id, today());
        return json(200, { ranges });
      }
      const user = currentUser(req);
      if (method === 'GET' && path === '/host/houses') return json(200, { houses: all('SELECT id FROM houses WHERE owner_id = ? ORDER BY id DESC', user.id).map((r) => house(r.id)) });
      if (method === 'POST' && path === '/uploads') {
        throttle(req, `upload:${user.id}`, 60);
        const b = await readBody(req);
        if (typeof b.base64 !== 'string' || !/^[A-Za-z0-9+/]*={0,2}$/.test(b.base64)) fail(400, 'Imagem inválida.');
        const bytes = Buffer.from(b.base64, 'base64');
        if (bytes.length > 3 * 1024 * 1024 || bytes.length < 12) fail(400, 'Use imagens de até 3 MB.');
        const ext = bytes.subarray(0, 3).equals(Buffer.from([255, 216, 255])) ? 'jpg'
          : bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) ? 'png'
          : bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP' ? 'webp' : null;
        if (!ext) fail(400, 'Use uma imagem JPG, PNG ou WebP.');
        const filename = `${randomBytes(16).toString('hex')}.${ext}`;
        writeFileSync(join(dataDir, 'uploads', filename), bytes, { flag: 'wx' });
        run('INSERT INTO uploads VALUES (?,?)', filename, user.id);
        return json(201, { url: `/uploads/${filename}` });
      }
      match = path.match(/^\/host\/houses\/(\d+)$/);
      if ((method === 'POST' && path === '/host/houses') || (method === 'PUT' && match)) {
        const id = match ? Number(match[1]) : null;
        if (id) owner(user, id);
        const b = houseInput(await readBody(req), user);
        const savedId = transaction(() => {
          let saved = id;
          if (id) run('UPDATE houses SET name=?,city=?,description=?,price_cents=?,guests=?,bedrooms=?,amenities=?,active=? WHERE id=?', b.name,b.city,b.description,b.price_cents,b.guests,b.bedrooms,JSON.stringify(b.amenities),b.active,id);
          else saved = Number(run('INSERT INTO houses(owner_id,name,city,description,price_cents,guests,bedrooms,amenities,active) VALUES (?,?,?,?,?,?,?,?,?)', user.id,b.name,b.city,b.description,b.price_cents,b.guests,b.bedrooms,JSON.stringify(b.amenities),b.active).lastInsertRowid);
          run('DELETE FROM photos WHERE house_id = ?', saved);
          b.photos.forEach((photo, i) => run('INSERT INTO photos(house_id,url,position) VALUES (?,?,?)', saved,photo,i));
          return saved;
        });
        return json(id ? 200 : 201, { house: house(savedId) });
      }
      match = path.match(/^\/host\/houses\/(\d+)\/blocks$/);
      if (match) {
        const id = Number(match[1]); owner(user, id);
        if (method === 'GET') return json(200, { blocks: all('SELECT * FROM blocks WHERE house_id = ? ORDER BY start_date', id) });
        if (method === 'POST') {
          const b = await readBody(req); period(b);
          const result = transaction(() => run('INSERT INTO blocks(house_id,start_date,end_date) VALUES (?,?,?)', id,b.start_date,b.end_date));
          return json(201, { id: Number(result.lastInsertRowid) });
        }
      }
      match = path.match(/^\/host\/blocks\/(\d+)$/);
      if (match && method === 'DELETE') {
        const block = one('SELECT * FROM blocks WHERE id = ?', Number(match[1]));
        if (!block) fail(404, 'Bloqueio não encontrado.');
        owner(user, block.house_id); run('DELETE FROM blocks WHERE id = ?', block.id);
        return json(200, { message: 'Período liberado.' });
      }
      if (method === 'POST' && path === '/bookings') {
        const b = await readBody(req), nights = period(b);
        const id = integer(b.house_id, 'Casa', 1, Number.MAX_SAFE_INTEGER);
        const guests = integer(b.guests, 'Hóspedes', 1, 30);
        const booking = transaction(() => {
          const item = house(id);
          if (!item.active) fail(409, 'Este anúncio não está disponível.');
          if (item.owner_id === user.id) fail(400, 'Você não pode reservar sua própria casa.');
          if (guests > item.guests) fail(400, 'A quantidade de hóspedes excede a capacidade.');
          // Require reconfirmation if the host changed the price after the detail screen loaded.
          if (b.expected_price_cents !== item.price_cents) fail(409, 'A diária mudou. Reabra a casa para conferir o novo valor.');
          const result = run('INSERT INTO bookings(house_id,guest_id,start_date,end_date,guests,nightly_cents,total_cents) VALUES (?,?,?,?,?,?,?)', id,user.id,b.start_date,b.end_date,guests,item.price_cents,item.price_cents*nights);
          return one('SELECT * FROM bookings WHERE id = ?', Number(result.lastInsertRowid));
        });
        return json(201, { booking });
      }
      if (method === 'GET' && (path === '/bookings' || path === '/host/bookings')) {
        const where = path === '/bookings' ? 'b.guest_id = ?' : 'h.owner_id = ?';
        const bookings = all(`SELECT b.*, h.name AS house_name, h.city, u.name AS guest_name
          FROM bookings b JOIN houses h ON h.id=b.house_id JOIN users u ON u.id=b.guest_id
          WHERE ${where} ORDER BY b.created_at DESC, b.id DESC`, user.id);
        return json(200, { bookings });
      }
      match = path.match(/^\/bookings\/(\d+)\/cancel$/);
      if (method === 'POST' && match) {
        transaction(() => {
          const booking = one('SELECT b.*, h.owner_id FROM bookings b JOIN houses h ON h.id=b.house_id WHERE b.id = ?', Number(match[1]));
          if (!booking) fail(404, 'Reserva não encontrada.');
          if (booking.guest_id !== user.id && booking.owner_id !== user.id) fail(403, 'Esta reserva não pertence à sua conta.');
          if (booking.start_date < today()) fail(400, 'Uma estadia já iniciada não pode ser cancelada.');
          run("UPDATE bookings SET status = 'cancelled' WHERE id = ?", booking.id);
        });
        return json(200, { message: 'Reserva cancelada.' });
      }
      fail(404, 'Rota não encontrada.');
    } catch (error) {
      if (error.message?.includes('date_conflict')) return json(409, { error: 'Este período já está reservado ou bloqueado.' });
      if (!error.status) console.error('Erro interno:', error.message);
      if (!res.headersSent) json(error.status || 500, { error: error.status ? error.message : 'Não foi possível concluir. Tente novamente.' });
    }
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  return { server, db };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  let resetDelivery;
  if (process.env.RESET_WEBHOOK_URL) {
    if (!process.env.RESET_WEBHOOK_URL.startsWith('https://')) throw new Error('RESET_WEBHOOK_URL deve usar HTTPS.');
    resetDelivery = async (email, token) => {
      const response = await fetch(process.env.RESET_WEBHOOK_URL, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${process.env.RESET_WEBHOOK_SECRET || ''}` },
        body: JSON.stringify({ email, token, expires_in_minutes: 15 }), signal: AbortSignal.timeout(10000),
      });
      if (!response.ok) throw new Error('Falha no serviço de e-mail.');
    };
  } else if (process.env.NODE_ENV !== 'production' && process.env.DEV_RESET_LOG === 'true') {
    resetDelivery = (email, token) => console.log(`[RECUPERAÇÃO LOCAL] ${email}: ${token}`);
  }
  const { server } = await createApp({
    dataDir: resolve(process.env.DATA_DIR || 'data'),
    allowedOrigins: (process.env.ALLOWED_ORIGINS || 'http://localhost:5300').split(',').map((x) => x.trim()), resetDelivery,
  });
  server.listen(Number(process.env.PORT || 4000), process.env.HOST || '127.0.0.1', () => console.log(`Casa da Praia API: http://${process.env.HOST || '127.0.0.1'}:${process.env.PORT || 4000}`));
}
