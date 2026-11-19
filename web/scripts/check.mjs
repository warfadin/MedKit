import test from 'node:test';
import assert from 'node:assert/strict';
import {agents,calculate,decimal,sliderDose,sliderLimit,sliderProgress} from '../public/calculator.js';
import {parseUniversity} from '../worker/university.js';
import {cached,refresh} from '../public/cache.js';
import {topics} from '../public/config.js';
import {selectGuideEntry,validGuide} from '../public/guide-content.js';
import {meanArterialPressure,oxygenationRatio} from '../public/icu.js';
import {estimatedGfr} from '../public/renal.js';

test('2021 creatinine eGFR matches both equation branches and both units', () => {
  for (const [age,sex,creatinine,expected] of [
    [60,'male',1.2,69.2311275675], [50,'female',0.6,109.2830113378],
    [75,'female',2,25.5726032537], [40,'male',0.8,114.7350482313]
  ]) {
    assert.ok(Math.abs(estimatedGfr({age,sex,creatinine,unit:'mg/dL'}) - expected) < 1e-8);
    assert.ok(Math.abs(estimatedGfr({age,sex,creatinine:creatinine * 88.4,unit:'µmol/L'}) - expected) < 1e-8);
  }
  const example = {age:18,sex:'female',creatinine:0.7,unit:'mg/dL'};
  assert.ok(estimatedGfr(example) > 0);
  for (const invalid of [{age:17},{age:18.5},{sex:''},{creatinine:0},{creatinine:Infinity},{unit:'mmol/L'}]) {
    assert.equal(estimatedGfr({...example,...invalid}),null);
  }
});

test('ICU calculators handle percentage conversion and invalid values', () => {
  assert.equal(meanArterialPressure(120, 60), 80);
  assert.equal(meanArterialPressure(60, 120), null);
  assert.equal(meanArterialPressure(120, 0), null);
  assert.equal(meanArterialPressure(NaN, 60), null);
  assert.equal(oxygenationRatio(80, 40), 200);
  assert.equal(oxygenationRatio(90, 100), 90);
  assert.equal(oxygenationRatio(80, 0.4), null);
  assert.equal(oxygenationRatio(80, 101), null);
  assert.equal(oxygenationRatio(0, 40), null);
});

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

test('guide validation accepts each configured ID and rejects a different topic', () => {
  const guide = {
    schemaVersion:1, title:'Örnek konu', specialty:'Örnek branş',
    lastUpdated:'2026-11-16', sources:[], updates:[{id:'sample',title:'Örnek güncelleme'}]
  };
  for (const [id,remoteId] of [
    ['aki','acute_kidney_injury'], ['ckd','chronic_kidney_disease'],
    ['portal_hypertension','portal_hypertension'], ['mash','mash'], ['sepsis','sepsis']
  ]) {
    const topic = topics.find((candidate) => candidate.id === id);
    assert.ok(validGuide(topic,{...guide,id}));
    assert.ok(validGuide(topic,{...guide,id:remoteId}));
    const differentId = id === 'sepsis' ? 'acute_kidney_injury' : 'sepsis';
    assert.equal(validGuide(topic,{...guide,id:differentId}),false);
    assert.equal(validGuide(topic,{...guide,id,updates:[null]}),false);
  }
});

test('a mismatched guide cannot replace a valid cache or take precedence over the snapshot', async (t) => {
  const topic = topics.find((candidate) => candidate.id === 'aki');
  const correct = {
    schemaVersion:1, id:'acute_kidney_injury', title:'Örnek konu',
    specialty:'Örnek branş', lastUpdated:'2026-11-16', sources:[], updates:[]
  };
  const wrong = {...correct, id:'sepsis'};
  const wrongEntry = {data:wrong, fetchedAt:1};
  assert.deepEqual(selectGuideEntry(topic,wrongEntry,correct),{data:correct});
  assert.equal(selectGuideEntry(topic,wrongEntry,wrong),null);

  const previousNavigator = Object.getOwnPropertyDescriptor(globalThis,'navigator');
  Object.defineProperty(globalThis,'navigator',{configurable:true,value:{onLine:true}});
  t.after(() => Object.defineProperty(globalThis,'navigator',previousNavigator));
  const load = () => refresh('guide.aki',topic.url,(value) => validGuide(topic,value),true);
  const upstream = t.mock.method(globalThis,'fetch',async () => Response.json(correct));
  assert.equal(await load(),'updated');
  const validEntry = cached('guide.aki');
  upstream.mock.mockImplementation(async () => Response.json(wrong));
  assert.equal(await load(),'failed');
  assert.deepEqual(cached('guide.aki'),validEntry);
  assert.deepEqual(selectGuideEntry(topic,cached('guide.aki'),wrong),validEntry);
});
