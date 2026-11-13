import test from 'node:test';
import assert from 'node:assert/strict';
import {agents,calculate,decimal,sliderDose,sliderLimit,sliderProgress} from '../public/calculator.js';
import {parseUniversity} from '../worker/university.js';
import {cached,refresh} from '../public/cache.js';

test('converts both directions for all Swift presets and accepts decimal comma', () => {
  for (const agent of agents) {
    for (const [mg,volume] of agent.mixes) {
      const base = {weight:70,mg,volume};
      const direct = calculate({...base,input:decimal('0,1'),direction:'dose'});
      assert.equal(direct.concentration,mg * 1000 / volume);
      assert.ok(Math.abs(direct.rate - 420 / direct.concentration) < 1e-10);
      assert.ok(Math.abs(calculate({...base,input:direct.rate,direction:'rate'}).dose - 0.1) < 1e-10);
      const max = sliderLimit(agent,70,direct.concentration);
      assert.ok(Math.abs(sliderProgress(sliderDose(0.72,max,70,direct.concentration),max,70,direct.concentration) - 0.72) < 1e-10);
    }
  }
  assert.equal(calculate({weight:70,mg:8,volume:0,input:1}),null);
  assert.ok(Number.isNaN(decimal('1,000.01')));
});

test('menu parser ignores breakfast, footers and one-day teaser blocks', () => {
  const html = '<h5>Personel Yemek Menüsü</h5><h5>Öğle Yemeği</h5>' +
    '<small>2.11.2026</small><small>Pazartesi</small><p>Çorba (1)</p>' +
    '<small>3.11.2026</small><small>Salı</small><p>Pilav</p><!-- #endregion Personel -->' +
    '<h5>Kahvaltı Menüsü</h5><small>3.11.2026</small><p>Peynir</p>';
  const result = parseUniversity(html);
  assert.equal(result.camlik,null);
  assert.deepEqual(result.personel.days.map((day) => day.lunch),[['Çorba'],['Pilav']]);
  assert.throws(() => parseUniversity('<p>Menü bulunamadı</p>'));
});

test('automatic refresh is deduplicated and stale content survives failure and offline access', async () => {
  let calls = 0;
  const data = new Map();
  Object.defineProperty(globalThis,'localStorage',{configurable:true,value:{getItem:(key) => data.get(key) ?? null,setItem:(key,value) => data.set(key,value)}});
  Object.defineProperty(globalThis,'navigator',{configurable:true,value:{onLine:true}});
  globalThis.fetch = async () => ++calls === 1 ? Response.json({valid:true}) : new Response('',{status:503});
  const load = (force) => refresh('test','https://example.test',(value) => value.valid,force);
  assert.deepEqual(await Promise.all([load(false),load(false)]),['updated','updated']);
  assert.equal(await load(false),'skipped');
  assert.equal(await load(true),'failed');
  assert.equal(await load(false),'skipped');
  navigator.onLine = false;
  assert.equal(await load(true),'offline');
  assert.deepEqual(cached('test').data,{valid:true});
  assert.equal(calls,2);
});
