import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { createApp, today } from '../src/server.js';

const photo = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=';
const day = (n) => new Date(Date.parse(today() + 'T00:00:00Z') + n * 86400000).toISOString().slice(0,10);
test('fluxos reais da API e persistência', async (t) => {
  const dataDir = mkdtempSync(join(tmpdir(), 'casa-praia-'));
  const delivered = [];
  let app = await createApp({ dataDir, resetDelivery: (email, token) => delivered.push({ email, token }) });
  app.server.listen(0, '127.0.0.1'); await once(app.server, 'listening');
  let base = `http://127.0.0.1:${app.server.address().port}`;
  const request = async (path, method = 'GET', body, token, headers = {}) => {
    const res = await fetch(base + path, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: res.status, body: await res.json() };
  };
  let host, guest, other, house, booking, upload;
  try {
    await t.test('cadastro, senha protegida, login e autenticação', async () => {
      for (const name of ['host', 'guest', 'other']) {
        const result = await request('/auth/register','POST',{name, email:`${name}@example.com`, password:'SenhaForte123!'});
        assert.equal(result.status,201);
        if (name === 'host') host = result.body; else if (name === 'guest') guest = result.body; else other = result.body;
      }
      const stored = app.db.prepare('SELECT password_hash FROM users WHERE id=?').get(host.user.id);
      assert.ok(!stored.password_hash.includes('SenhaForte123'));
      assert.equal((await request('/auth/login','POST',{email:'host@example.com',password:'errada'})).status,401);
      assert.equal((await request('/auth/me')).status,401);
      assert.equal((await request('/auth/login','POST',{email:'host@example.com',password:'SenhaForte123!'})).status,200);
      assert.equal((await request('/houses','GET',undefined,undefined,{Origin:'https://bad.example'})).status,403);
    });
    await t.test('upload, anúncio, filtro e isolamento de proprietário', async () => {
      upload = (await request('/uploads','POST',{base64:photo},host.token)).body.url;
      const body = { name:'Casa Brisa do Mar', city:'Guarapari - ES', description:'Casa com varanda e dois quartos próxima à praia.', price_cents:25000, guests:4, bedrooms:2, amenities:['Wi-Fi','Piscina'], photos:[upload] };
      const result = await request('/host/houses','POST',body,host.token);
      assert.equal(result.status,201); house = result.body.house;
      assert.equal((await request(`/host/houses/${house.id}`,'PUT',body,other.token)).status,403);
      assert.equal((await request('/host/houses','POST',body,other.token)).status,403);
      assert.equal((await request('/houses?q=guarapari&guests=4&max_price=30000')).body.houses.length,1);
      assert.equal((await request('/houses?guests=5')).body.houses.length,0);
      assert.equal((await request('/houses?max_price=24000')).body.houses.length,0);
      assert.equal((await request('/uploads','POST',{base64:Buffer.from('<script>alert(1)</script>').toString('base64')},host.token)).status,400);
    });
    await t.test('preço calculado no servidor e datas válidas', async () => {
      const body = { house_id:house.id, start_date:day(10), end_date:day(13),guests:2,expected_price_cents:25000,total_cents:1 };
      assert.equal((await request('/bookings','POST',{...body,start_date:'2027-02-30'},guest.token)).status,400);
      assert.equal((await request('/bookings','POST',{...body,guests:5},guest.token)).status,400);
      assert.equal((await request('/bookings','POST',body,host.token)).status,400);
      assert.equal((await request('/bookings','POST',{...body,expected_price_cents:1},guest.token)).status,409);
      const result = await request('/bookings','POST',body,guest.token);
      assert.equal(result.status,201); booking=result.body.booking;
      assert.equal(booking.total_cents,75000);
      assert.equal((await request('/bookings','GET',undefined,other.token)).body.bookings.length,0);
      assert.equal((await request(`/bookings/${booking.id}/cancel`,'POST',{},other.token)).status,403);
      const availability = await request(`/houses/${house.id}/availability`);
      assert.deepEqual(Object.keys(availability.body.ranges[0]).sort(),['end_date','start_date']);
    });
    await t.test('sobreposição, bordas e concorrência', async () => {
      const b = {house_id:house.id,start_date:day(12),end_date:day(15),guests:1,expected_price_cents:25000};
      assert.equal((await request('/bookings','POST',b,other.token)).status,409);
      assert.equal((await request('/bookings','POST',{...b,start_date:day(13)},other.token)).status,201);
      const concurrent = await Promise.all([guest,other].map(u=>request('/bookings','POST',{...b,start_date:day(30),end_date:day(32)},u.token)));
      assert.deepEqual(concurrent.map(x=>x.status).sort(),[201,409]);
    });
    await t.test('bloqueios respeitam reservas e propriedade', async () => {
      const path=`/host/houses/${house.id}/blocks`;
      assert.equal((await request(path,'POST',{start_date:day(11),end_date:day(12)},host.token)).status,409);
      assert.equal((await request(path,'POST',{start_date:day(20),end_date:day(22)},other.token)).status,403);
      const block=await request(path,'POST',{start_date:day(20),end_date:day(22)},host.token);assert.equal(block.status,201);
      assert.equal((await request('/bookings','POST',{house_id:house.id,start_date:day(19),end_date:day(23),guests:1,expected_price_cents:25000},guest.token)).status,409);
      assert.equal((await request(`/host/blocks/${block.body.id}`,'DELETE',undefined,other.token)).status,403);
      assert.equal((await request(`/host/blocks/${block.body.id}`,'DELETE',undefined,host.token)).status,200);
    });
    await t.test('cancelamento libera noites e preserva histórico', async () => {
      assert.equal((await request(`/bookings/${booking.id}/cancel`,'POST',{},guest.token)).status,200);
      assert.equal((await request('/bookings','POST',{house_id:house.id,start_date:day(10),end_date:day(13),guests:1,expected_price_cents:25000},other.token)).status,201);
      assert.equal((await request('/bookings','GET',undefined,guest.token)).body.bookings.find(b=>b.id===booking.id).status,'cancelled');
    });
    await t.test('edição, pausa e diária contratada preservada', async () => {
      const changes = {...house, active:false, price_cents:30000};
      assert.equal((await request(`/host/houses/${house.id}`,'PUT',changes,host.token)).status,200);
      assert.equal((await request('/houses')).body.houses.length,0);
      assert.equal((await request(`/houses/${house.id}`,'GET',undefined,host.token)).status,200);
      assert.equal((await request(`/houses/${house.id}`,'GET',undefined,other.token)).status,404);
      assert.equal((await request('/bookings','POST',{house_id:house.id,start_date:day(40),end_date:day(42),guests:1,expected_price_cents:30000},other.token)).status,409);
      assert.equal((await request(`/host/houses/${house.id}`,'PUT',{...changes,active:true},host.token)).status,200);
      assert.equal((await request('/houses')).body.houses[0].price_cents,30000);
      const old=(await request('/host/bookings','GET',undefined,host.token)).body.bookings.find(b=>b.id===booking.id);
      assert.equal(old.nightly_cents,25000);assert.equal(old.total_cents,75000);
    });
    await t.test('recuperação usa código único e revoga sessões', async () => {
      assert.equal((await request('/auth/forgot','POST',{email:'guest@example.com'})).status,200);
      assert.equal(delivered.length,1);
      const token=delivered[0].token;
      assert.equal((await request('/auth/reset','POST',{token,password:'NovaSenha123!'})).status,200);
      assert.equal((await request('/auth/me','GET',undefined,guest.token)).status,401);
      assert.equal((await request('/auth/reset','POST',{token,password:'OutraSenha123!'})).status,400);
      assert.equal((await request('/auth/login','POST',{email:'guest@example.com',password:'NovaSenha123!'})).status,200);
    });
    await t.test('dados e sessão sobrevivem ao reinício; logout revoga token', async () => {
      await new Promise(resolve=>app.server.close(resolve)); app.db.close();
      app=await createApp({dataDir});app.server.listen(0,'127.0.0.1');await once(app.server,'listening');base=`http://127.0.0.1:${app.server.address().port}`;
      assert.equal((await request('/houses')).body.houses.length,1);
      assert.equal((await request('/auth/me','GET',undefined,host.token)).status,200);
      assert.ok((await request('/host/bookings','GET',undefined,host.token)).body.bookings.length>=3);
      assert.equal((await fetch(base+upload)).status,200);
      assert.equal((await request('/auth/logout','POST',{},host.token)).status,200);
      assert.equal((await request('/auth/me','GET',undefined,host.token)).status,401);
    });
  } finally { await new Promise(resolve=>app.server.close(resolve));app.db.close();rmSync(dataDir,{recursive:true,force:true}); }
});
