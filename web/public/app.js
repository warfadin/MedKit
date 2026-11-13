import { topics, hospitalURL, universityURL } from './config.js';
import { cached, read, refresh, write } from './cache.js';
import { agents, calculate, decimal, sliderDose, sliderLimit, sliderProgress } from './calculator.js';

const $ = (id) => document.getElementById(id);
const main = $('main');
const labels = {
  araclar: ['Araçlar', 'Araçlar', 'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z'],
  hesaplayici: ['Vazoaktif Ajan Hesaplayıcı', 'Hesaplayıcı', 'M5 3h14v18H5z M8 7h8 M8 11h2 M14 11h2 M8 15h2 M14 15h2 M8 18h2 M14 18h2'],
  kilavuzlar: ['Kılavuz Güncellemeleri', 'Kılavuzlar', 'M12 7c-3-3-6-3-10-3v15c4 0 7 0 10 2 3-2 6-2 10-2V4c-4 0-7 0-10 3z M12 7v14'],
  menuler: ['Yemek Menüleri', 'Menüler', 'M4 3v6a3 3 0 0 0 6 0V3 M7 3v18 M19 21V3c-3 0-5 4-5 9h5']
};
const desc = {
  hesaplayici: 'Doz, infüzyon hızı ve karışım konsantrasyonu',
  kilavuzlar: 'Klinik değişiklikler, karşılaştırmalar ve kaynaklar',
  menuler: 'BUÜ Hastane, Çamlık ve Personel menüleri'
};
const importance = {
  practiceChanging:'Pratiği değiştirebilir', high:'Çok önemli', important:'Çok önemli',
  moderate:'Nispeten önemli', minor:'Küçük değişiklik', low:'Düşük öncelik', editorial:'Editoryal'
};
const changeType = {
  newRecommendation:'Yeni öneri', removedRecommendation:'Kaldırılan öneri', modifiedThreshold:'Değişen eşik',
  expandedIndication:'Genişleyen endikasyon', narrowedIndication:'Daralan endikasyon', changedDrugOrDose:'İlaç veya doz değişikliği',
  changedTerminology:'Terminoloji değişikliği', changedEvidenceLevel:'Kanıt düzeyi değişikliği',
  noMajorChange:'Büyük değişiklik yok', practicePoint:'Pratik nokta'
};
const icon = (path) => '<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="' + path + '"/></svg>';
const arrow = icon('M4 12h15 M13 6l6 6-6 6');
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[char]);
const link = (value) => {
  try { const url = new URL(value); return url.protocol === 'https:' ? esc(url.href) : ''; } catch { return ''; }
};
const title = (name, description = '') => '<header class="page-head"><h1>' + esc(name) + '</h1>' + (description ? '<p>' + esc(description) + '</p>' : '') + '</header>';
const button = (label, id, pressed) => '<button type="button" id="' + id + '"' + (pressed === undefined ? '' : ' aria-pressed="' + pressed + '"') + '>' + esc(label) + '</button>';
const text = (value) => typeof value === 'string' && value.trim().length > 0;
const date = (value) => /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value));
const today = () => new Intl.DateTimeFormat('sv-SE', {timeZone:'Europe/Istanbul'}).format(new Date());
const prettyDay = (value) => date(value) ? new Intl.DateTimeFormat('tr-TR', {dateStyle:'long', timeZone:'UTC'}).format(new Date(value)) : '';
const time = (value) => new Intl.DateTimeFormat('tr-TR', {dateStyle:'short',timeStyle:'short',timeZone:'Europe/Istanbul'}).format(value);
const number = new Intl.NumberFormat('tr-TR', {maximumSignificantDigits: 7});
const showNumber = (value) => value > 0 && value < 0.000001 ? value.toExponential(4).replace('.', ',') : number.format(value);
let route = '';
let detail = '';
let screen = 0;
let guideTab = 'recent';
let menu = 'hospital';
let mealDate = '';
const expanded = new Set();
let toastTimer;
let seed = {};
const seedReady = fetch('./snapshot.json').then((r) => r.ok ? r.json() : {}).then((data) => { seed = data; }).catch(() => {});
const available = (key) => cached(key) ?? (seed[key] ? {data:seed[key]} : null);

function notify(message) {
  $('toast').textContent = message;
  $('toast').hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { $('toast').hidden = true; }, 4500);
}

function updateConnection() {
  document.body.toggleAttribute('data-offline', !navigator.onLine);
  $('connection').textContent = navigator.onLine ? 'Çevrimiçi' : 'Çevrimdışı';
  $('offline-ready').textContent = navigator.onLine ? offlineReady ? 'Çevrimdışı kullanıma hazır' : '' : 'Çevrimdışı · kayıtlı içerik';
}
let offlineReady = false;
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('./sw.js').then(() => navigator.serviceWorker.ready).then(() => {
    offlineReady = true;
    updateConnection();
  }).catch(() => {});
}
$('theme').value = read('theme') ?? 'system';
function updateTheme() { document.documentElement.dataset.theme = $('theme').value; }
updateTheme();
$('theme').onchange = () => { write('theme', $('theme').value); updateTheme(); };
$('share').onclick = async () => {
  try {
    if (navigator.share) await navigator.share({title:'MedKit+', url:location.href});
    else if (navigator.clipboard) { await navigator.clipboard.writeText(location.href); notify('Bağlantı kopyalandı.'); }
    else window.prompt('Bağlantıyı kopyala', location.href);
  } catch (error) {
    if (error.name !== 'AbortError') window.prompt('Bağlantıyı kopyala', location.href);
  }
};
$('nav').innerHTML = Object.entries(labels).map(([id, [,name,path]]) =>
  '<a href="#' + id + '">' + icon(path) + '<span>' + name + '</span></a>').join('');
document.querySelector('.skip').onclick = (event) => { event.preventDefault(); main.focus(); };
for (const event of ['online','offline']) window.addEventListener(event, () => {
  updateConnection();
  if (route === 'kilavuzlar' || route === 'menuler') draw();
});

function home() {
  main.innerHTML = '<section class="hero"><h1>Klinik Araçlar</h1><p>Dahiliye ve yoğun bakım için hesaplayıcılar, kılavuz karşılaştırmaları ve BUÜ yemek menüleri.</p></section>' +
    '<h2 class="section-title">Araçlar</h2><div class="tiles">' + Object.entries(desc).map(([id, description]) =>
      '<a class="tile" href="#' + id + '"><span class="tile-icon">' + icon(labels[id][2]) + '</span><div><h2>' + labels[id][0] +
      '</h2><p>' + description + '</p></div><span class="arrow">' + arrow + '</span></a>').join('') + '</div>';
}

function calculator() {
  main.innerHTML = title(labels.hesaplayici[0], 'İnfüzyon dozu ve pompa hızı arasında dönüşüm yapın.') +
    '<div class="grid"><section class="card stack"><h2>Karışım</h2><div class="fields">' +
    '<label class="field">Ajan<select id="agent">' + agents.map((agent,i) => '<option value="' + i + '">' + agent.name + '</option>').join('') + '</select></label>' +
    '<label class="field">Hasta ağırlığı (kg)<input id="weight" inputmode="decimal" autocomplete="off" placeholder="Ör. 70"></label>' +
    '<label class="field wide">Hazırlama seçeneği<select id="mix"></select></label>' +
    '<label class="field manual" hidden>Etkin madde (mg)<input id="mg" inputmode="decimal" autocomplete="off"></label>' +
    '<label class="field manual" hidden>Son toplam hacim (mL)<input id="volume" inputmode="decimal" autocomplete="off"></label></div>' +
    '<p class="status" id="mix-summary"></p><p class="note">Hazır karışımları, ürünün etkin madde miktarını ve son toplam hacmi kurum protokolüyle doğrulayın.</p></section>' +
    '<section class="card stack"><h2>İnfüzyon dönüşümü</h2><div class="row">' +
    button('Doz → hız','dose-mode',true) + button('Hız → doz','rate-mode',false) + '</div>' +
    '<label class="field"><span id="input-label">Doz (µg/kg/dk)</span><input id="quantity" inputmode="decimal" autocomplete="off"></label>' +
    '<label class="field" id="slider-row" hidden>Doz kaydırıcısı<input id="slider" type="range" min="0" max="1000" step="1" value="0"></label>' +
    '<div class="result" aria-live="polite"><span id="result-label"></span><strong id="result"></strong><span id="concentration"></span></div>' +
    '<p id="calc-message" class="status"></p><details><summary>Hesaplama formülü</summary><p>Konsantrasyon (µg/mL) = mg × 1.000 ÷ son hacim (mL).</p><p>Hız (mL/sa) = doz (µg/kg/dk) × kg × 60 ÷ konsantrasyon (µg/mL).</p></details></section></div>';

  let direction = 'dose';
  const getAgent = () => agents[Number($('agent').value)];
  const getInputs = () => {
    const manual = $('mix').value === 'manual';
    const [mg, volume] = manual ? [decimal($('mg').value), decimal($('volume').value)] : getAgent().mixes[Number($('mix').value)];
    return { weight:decimal($('weight').value), mg, volume };
  };
  function update() {
    const manual = $('mix').value === 'manual';
    document.querySelectorAll('.manual').forEach((field) => { field.hidden = !manual; });
    const values = getInputs();
    const base = calculate({...values,input:0,direction});
    const result = calculate({...values,input:decimal($('quantity').value),direction});
    $('mix-summary').textContent = base ? showNumber(values.mg) + ' mg / ' + showNumber(values.volume) + ' mL son hacim' : '';
    $('result-label').textContent = direction === 'rate' ? 'Hesaplanan doz' : 'Hesaplanan hız';
    $('result').textContent = result ? showNumber(direction === 'rate' ? result.dose : result.rate) + (direction === 'rate' ? ' µg/kg/dk' : ' mL/sa') : '—';
    $('concentration').textContent = base ? 'Konsantrasyon ' + showNumber(base.concentration) + ' µg/mL' : '';
    $('calc-message').textContent = result ? '' : base ? 'Dönüştürmek istediğiniz değeri girin.' : 'Pozitif ağırlık, etkin madde ve son hacim girin.';
    $('slider-row').hidden = direction !== 'dose' || !base || !Number.isFinite(sliderLimit(getAgent(), values.weight, base.concentration) * values.weight * 60 / base.concentration);
    if (!$('slider-row').hidden) $('slider').value = result ? Math.round(sliderProgress(result.dose,sliderLimit(getAgent(),values.weight,base.concentration),values.weight,base.concentration) * 1000) : 0;
  }
  function setAgent() {
    const agent = getAgent();
    $('mix').innerHTML = agent.mixes.map(([mg,ml],i) => '<option value="' + i + '">' + mg + ' mg / ' + ml + ' mL ' + agent.solvent + '</option>').join('') +
      '<option value="manual">Manuel karışım</option>';
    $('mg').value = agent.mixes[0][0];
    $('volume').value = agent.mixes[0][1];
    $('quantity').value = '';
    update();
  }
  function setDirection(next) {
    if (direction === next) return;
    const result = calculate({...getInputs(),input:decimal($('quantity').value),direction});
    direction = next;
    $('dose-mode').setAttribute('aria-pressed', direction === 'dose');
    $('rate-mode').setAttribute('aria-pressed', direction === 'rate');
    $('input-label').textContent = direction === 'dose' ? 'Doz (µg/kg/dk)' : 'Hız (mL/sa)';
    $('quantity').value = result ? Number((direction === 'dose' ? result.dose : result.rate).toPrecision(12)).toLocaleString('en-US',{useGrouping:false,maximumSignificantDigits:12}) : '';
    update();
  }
  $('slider').oninput = (event) => {
    const values = getInputs();
    const {concentration} = calculate({...values,input:0,direction});
    const dose = sliderDose(Number(event.target.value)/1000,sliderLimit(getAgent(),values.weight,concentration),values.weight,concentration);
    $('quantity').value = dose.toFixed(5).replace(/\.?0+$/, '') || '0';
    update();
  };
  $('agent').onchange = setAgent;
  $('mix').onchange = update;
  for (const id of ['weight','mg','volume','quantity']) $(id).oninput = update;
  $('dose-mode').onclick = () => setDirection('dose');
  $('rate-mode').onclick = () => setDirection('rate');
  setAgent();
}

const validGuide = (g) => g?.schemaVersion === 1 && text(g.id) && text(g.title) && text(g.specialty) && date(g.lastUpdated) &&
  Array.isArray(g.sources) && g.sources.every((s) => text(s?.id) && text(s.name) && text(s.url)) &&
  Array.isArray(g.updates) && g.updates.every((u) => text(u?.id) && text(u.title));
const validMenu = (m) => text(m?.title) && Array.isArray(m.days) &&
  m.days.every((d) => date(d?.date) && Array.isArray(d.lunch) && d.lunch.every(text) &&
    ['ordovr','dinner'].every((key) => d[key] === undefined || Array.isArray(d[key]) && d[key].every(text)));
const keys = (item) => 'guide.' + item.id;
const saved = () => new Set(read('saved') ?? []);
function dataStatus(entry) {
  if (!entry) return navigator.onLine ? 'İçerik yükleniyor veya kaynağa ulaşılamadı.' : 'Çevrimdışı · kayıtlı içerik bulunamadı.';
  const mode = navigator.onLine ? 'Kayıtlı veri' : 'Çevrimdışı · kayıtlı veri';
  return entry.fetchedAt ? mode + ' · son başarılı yenileme ' + time(entry.fetchedAt) : mode + ' · ilk sürüm arşivi';
}
async function loadGuide(items, force, token) {
  const results = await Promise.all(items.map((t) => refresh(keys(t), t.url, validGuide, force)));
  if (screen !== token) return;
  if (force) notify(results.includes('offline') ? 'Çevrimdışısınız. Kayıtlı içerik gösteriliyor.' :
    results.includes('failed') ? 'Bazı kaynaklar yenilenemedi. Varsa kayıtlı içerik korundu.' : 'Kılavuz içeriği yenilendi.');
  if (results.some((result) => result === 'updated')) guides();
  else if ($('refresh')) $('refresh').disabled = false;
}
function guideSource(s) {
  const url = link(s.url);
  const label = esc([s.name,s.year,s.version].filter(Boolean).join(' · '));
  return '<li>' + (url ? '<a href="' + url + '" target="_blank" rel="noopener noreferrer">' + label + '</a>' : label) + '</li>';
}
function guideUpdate(update, sources, topicId) {
  const key = topicId + '/' + update.id;
  const sections = [['Özet',update.summary],['Ne değişti?',update.whatChanged],['Klinik etki',update.clinicalImpact],['Kanıt düzeyi',update.evidenceLevel]];
  const sourcesHere = sources.filter((s) => Array.isArray(update.sourceIds) && update.sourceIds.includes(s.id));
  return '<details class="card update" data-update="' + esc(key) + '"' + (expanded.has(key) ? ' open' : '') +
    '><summary>' + esc(update.title) + '</summary>' +
    '<div class="row">' + [Object.hasOwn(changeType,update.changeType) ? changeType[update.changeType] : '', Object.hasOwn(importance,update.importance) ? importance[update.importance] : '', update.examRelevant ? 'Sınavla ilgili' : ''].filter(Boolean).map((v) => '<span class="badge">' + v + '</span>').join('') + '</div>' +
    sections.filter(([,value]) => text(value)).map(([name,value]) => '<h3>' + name + '</h3><p>' + esc(value) + '</p>').join('') +
    (update.oldRecommendation || update.newRecommendation ? '<div class="grid"><div><h3>Önceki</h3><p>' + esc(update.oldRecommendation || '—') +
      '</p></div><div><h3>Güncel</h3><p>' + esc(update.newRecommendation || '—') + '</p></div></div>' : '') +
    (sourcesHere.length ? '<h3>İlgili kaynaklar</h3><ul>' + sourcesHere.map(guideSource).join('') + '</ul>' : '') + '</details>';
}
function topicCard(topic, savedIds) {
  const entry = available(keys(topic));
  const data = entry?.data;
  return '<article class="card topic"><a href="#kilavuzlar/' + topic.id + '"><span class="status">' + esc(topic.specialty) + '</span><h2>' + esc(topic.title) +
    '</h2><span class="status">' + (data ? data.updates.length + ' değişiklik · ' + prettyDay(data.lastUpdated) : 'İçerik bekleniyor') +
    '</span></a><button type="button" data-save="' + topic.id + '" aria-pressed="' + savedIds.has(topic.id) + '" aria-label="' + esc(topic.title + ' kaydı') +
    '">' + (savedIds.has(topic.id) ? 'Kaydedildi' : 'Kaydet') + '</button></article>';
}
function guides() {
  const selected = topics.find((t) => t.id === detail);
  const items = selected ? [selected] : topics;
  const savedIds = saved();
  const refreshControl = '<button type="button" id="refresh">İçeriği yenile</button>';
  if (selected) {
    const entry = available(keys(selected));
    const data = entry?.data;
    const draft = data?.sources.some((source) => /draft|taslak/i.test([source.name,source.version].join(' ')));
    main.innerHTML = '<p><a href="#kilavuzlar">← Kılavuzlar</a></p>' + title(selected.title, selected.specialty) + '<div class="stack">' +
      '<div class="row"><button type="button" data-save="' + selected.id + '" aria-pressed="' + savedIds.has(selected.id) + '">' +
      (savedIds.has(selected.id) ? 'Kaydedildi' : 'Kaydet') + '</button>' + refreshControl + '</div><p class="status">' + dataStatus(entry) + '</p>' +
      (data ? '<p class="status">İçerik tarihi ' + prettyDay(data.lastUpdated) + '</p>' +
      (draft ? '<p class="note">Bu karşılaştırma taslak kılavuz içeriği içeriyor.</p>' : '') +
      (data.overview ? '<section class="card"><h2>Özet</h2><p>' + esc(data.overview) + '</p></section>' : '') +
      data.updates.map((update) => guideUpdate(update,data.sources,selected.id)).join('') +
      (data.sources.length ? '<section class="card"><h2>Kaynaklar</h2><ul>' + data.sources.map(guideSource).join('') + '</ul></section>' : '') : '') + '</div>';
  } else {
    const tabs = {recent:'Güncel',specialties:'Branşlar',topics:'Konular',saved:'Kaydedilenler'};
    const sorted = [...topics].sort((a,b) => (available(keys(b))?.data.lastUpdated ?? '').localeCompare(available(keys(a))?.data.lastUpdated ?? ''));
    const visible = guideTab === 'saved' ? sorted.filter((t) => savedIds.has(t.id)) : guideTab === 'topics' ?
      [...topics].sort((a,b) => a.title.localeCompare(b.title,'tr')) : sorted;
    const grouped = [...new Set(topics.map((t) => t.specialty))].map((specialty) =>
      '<section class="stack"><h2>' + specialty + '</h2>' + visible.filter((t) => t.specialty === specialty).map((t) => topicCard(t,savedIds)).join('') + '</section>');
    main.innerHTML = title(labels.kilavuzlar[0], 'Önceki ve güncel kılavuz önerilerini karşılaştırın.') + '<div class="stack"><div class="row spread"><div class="row">' +
      Object.entries(tabs).map(([id,label]) => button(label,'tab-' + id,guideTab === id)).join('') + '</div>' + refreshControl + '</div>' +
      '<p class="status">Kaynak: <a href="https://github.com/warfadin/medkit-data" target="_blank" rel="noopener noreferrer">warfadin/medkit-data</a></p>' +
      (guideTab === 'specialties' ? grouped.join('') : visible.map((t) => topicCard(t,savedIds)).join('') || '<p class="card">Kaydedilmiş konu bulunamadı.</p>') + '</div>';
    for (const id of Object.keys(tabs)) $('tab-' + id).onclick = () => { guideTab = id; guides(); $('tab-' + id).focus(); };
  }
  main.querySelectorAll('[data-save]').forEach((control) => {
    control.onclick = () => {
      const id = control.dataset.save;
      if (savedIds.has(id)) savedIds.delete(id);
      else savedIds.add(id);
      write('saved',[...savedIds]);
      guides();
      (main.querySelector('[data-save="' + id + '"]') ?? $('tab-saved'))?.focus();
    };
  });
  main.querySelectorAll('[data-update]').forEach((panel) => { panel.ontoggle = () => {
    if (panel.open) expanded.add(panel.dataset.update);
    else expanded.delete(panel.dataset.update);
  }; });
  $('refresh').onclick = () => { $('refresh').disabled = true; void loadGuide(items,true,screen); };
}

const menuLabels = {hospital:'BUÜ Hastane',camlik:'Çamlık',personel:'Personel'};
function menuEntry() {
  const entry = available(menu === 'hospital' ? 'hospital' : 'university');
  return {entry, data:menu === 'hospital' ? entry?.data : entry?.data[menu]};
}
function meals() {
  const {entry,data} = menuEntry();
  const days = data?.days ?? [];
  const current = today();
  if (!days.some((day) => day.date === mealDate)) mealDate = days.find((day) => day.date >= current)?.date ?? days.at(-1)?.date ?? '';
  const selected = days.find((day) => day.date === mealDate);
  const isCurrent = days.some((day) => day.date.slice(0,7) === current.slice(0,7));
  const meal = (label, items) => '<section class="card"><h2>' + label + '</h2>' +
    (items?.length ? '<ul>' + items.map((item) => '<li>' + esc(item) + '</li>').join('') + '</ul>' : '<p class="muted">Bu öğün için kayıt yok.</p>') + '</section>';
  main.innerHTML = title(labels.menuler[0], 'Öğünleri tarihe göre görüntüleyin.') +
    '<div class="stack"><div class="row spread"><div class="row">' +
    Object.entries(menuLabels).map(([id,label]) => button(label,'menu-' + id,menu === id)).join('') +
    '</div><button type="button" id="refresh">Menüyü yenile</button></div><p class="status">' + dataStatus(entry) + '</p>' +
    (days.length && !isCurrent ? '<p class="note">Arşiv menüsü · içinde bulunduğumuz aya ait kayıt yok.</p>' :
      days.length && !days.some((day) => day.date === current) ? '<p class="note">Bugün için menü kaydı bulunmuyor.</p>' : '') +
    (selected ? '<label class="field card">Tarih<select id="meal-date">' + days.map((day) =>
      '<option value="' + day.date + '"' + (day.date === mealDate ? ' selected' : '') + '>' + prettyDay(day.date) + ' · ' + esc(day.weekday) + '</option>').join('') +
      '</select></label><div class="grid">' + meal('Öğle',selected.lunch) +
      (menu === 'camlik' ? meal('Ordövr',selected.ordovr) : meal('Akşam',selected.dinner)) + '</div>' :
      '<p class="card">' + (entry && menu === 'camlik' ? 'Üniversite kaynağında Çamlık menüsü yayımlanmıyor.' : 'Bu menü için gösterilebilecek kayıt yok.') + '</p>') +
    '<p class="status"><a href="' + (menu === 'hospital' ? hospitalURL : universityURL) + '" target="_blank" rel="noopener noreferrer">Menü kaynağı</a></p></div>';
  if ($('meal-date')) $('meal-date').onchange = () => { mealDate = $('meal-date').value; meals(); $('meal-date').focus(); };
  for (const id of Object.keys(menuLabels)) $('menu-' + id).onclick = () => {
    if (menu === id) return;
    menu = id;
    mealDate = '';
    const token = ++screen;
    meals();
    $('menu-' + id).focus();
    void loadMenu(false,token);
  };
  $('refresh').onclick = () => { $('refresh').disabled = true; void loadMenu(true,screen); };
}
async function loadMenu(force, token) {
  const result = menu === 'hospital'
    ? await refresh('hospital',hospitalURL,validMenu,force)
    : await refresh('university','./api/university-menu',
      (m) => (m?.camlik === null || validMenu(m?.camlik)) && (m?.personel === null || validMenu(m?.personel)) && (m.camlik || m.personel),force);
  if (screen !== token) return;
  if (result === 'updated') meals();
  if ($('refresh')) $('refresh').disabled = false;
  if (force) notify({
    updated:'Menü yenilendi.', failed:'Kaynağa ulaşılamadı. Varsa kayıtlı menü korundu.',
    offline:'Çevrimdışısınız. Kayıtlı menü gösteriliyor.'
  }[result] ?? 'Kayıtlı menü gösteriliyor.');
}

function draw(focus = false) {
  const [name,id] = location.hash.slice(1).split('/');
  const next = Object.hasOwn(labels,name) ? name : 'araclar';
  if (route === next && next === 'hesaplayici') return;
  route = next;
  detail = id ?? '';
  const token = ++screen;
  $('crumb').textContent = labels[route][0];
  $('nav').querySelectorAll('a').forEach((a) => {
    if (a.hash === '#' + route) a.setAttribute('aria-current','page');
    else a.removeAttribute('aria-current');
  });
  if (route === 'araclar') home();
  if (route === 'hesaplayici') calculator();
  if (route === 'kilavuzlar') {
    guides();
    const selected = topics.find((t) => t.id === detail);
    void seedReady.then(() => { if (screen === token) guides(); });
    void loadGuide(selected ? [selected] : topics,false,token);
  }
  if (route === 'menuler') {
    meals();
    void seedReady.then(() => { if (screen === token) meals(); });
    void loadMenu(false,token);
  }
  if (focus) { window.scrollTo(0,0); main.focus({preventScroll:true}); }
}
window.addEventListener('hashchange', () => draw(true));
updateConnection();
draw();
