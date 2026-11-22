import { topics, hospitalURL, universityURL } from './config.js';
import { cached, read, refresh, write } from './cache.js';
import { selectGuideEntry, validGuide } from './guide-content.js';
import { agents, calculate, decimal, sliderDose, sliderLimit, sliderProgress } from './calculator.js';
import { meanArterialPressure, oxygenationRatio } from './icu.js';
import { estimatedGfr, serumOsmolality, urineAlbuminCreatinineRatio } from './renal.js';
import { hyponatremiaView } from './hyponatremia-view.js';
import { watchAppUpdates } from './updates.js';

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
const clinicalTools = {
  hiponatremi: {
    title: 'Hiponatremi ve SIADH', description: 'Serum ve idrar bulguları, volüm durumu ve dışlama kriterleri',
    path: 'M12 3C8 9 5 12 5 16a7 7 0 0 0 14 0c0-4-3-7-7-13z',
    render: () => hyponatremiaView(main)
  },
  'yogun-bakim': {
    title: 'Yoğun Bakım Araçları', description: 'Ortalama arter basıncı ve PaO₂/FiO₂ oranı',
    path: 'M2 12h5l3-7 4 14 3-7h5', render: intensiveCare
  },
  nefroloji: {
    title: 'Nefroloji Araçları', description: 'eGFR, idrar albümin/kreatinin oranı ve serum osmolalitesi',
    path: 'M9 4C5 2 3 6 3 10s2 7 5 7c2 0 3-2 3-4V9c0-2-1-4-2-5z M15 4c4-2 6 2 6 6s-2 7-5 7c-2 0-3-2-3-4V9c0-2 1-4 2-5z M9 14v6 M15 14v6',
    render: nephrology
  }
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
  watchAppUpdates(navigator.serviceWorker, () => {
    $('app-update').hidden = false;
  });
  $('app-reload').onclick = () => location.reload();
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
  const tiles = [
    ...Object.entries(desc).map(([id, description]) => [id, labels[id][0], description, labels[id][2]]),
    ...Object.entries(clinicalTools).map(([id, tool]) => ['araclar/' + id, tool.title, tool.description, tool.path])
  ];
  main.innerHTML = '<section class="hero"><h1>Klinik Araçlar</h1><p>Dahiliye ve yoğun bakım için hesaplayıcılar, kılavuz karşılaştırmaları ve BUÜ yemek menüleri.</p></section>' +
    '<h2 class="section-title">Araçlar</h2><div class="tiles">' + tiles.map(([id, name, description, path]) =>
      '<a class="tile" href="#' + id + '"><span class="tile-icon">' + icon(path) + '</span><div><h2>' + name +
      '</h2><p>' + description + '</p></div><span class="arrow">' + arrow + '</span></a>').join('') + '</div>';
}

function nephrology() {
  main.innerHTML = '<p><a href="#araclar">← Araçlar</a></p>' + title(clinicalTools.nefroloji.title) + `
    <div class="grid">
    <section class="card stack" aria-labelledby="egfr-title">
      <h2 id="egfr-title">Tahmini Glomerüler Filtrasyon Hızı (eGFR)</h2>
      <p>CKD-EPI 2021 kreatinin denklemi · 18 yaş ve üzeri</p>
      <div class="fields">
        <label class="field">Yaş (yıl)<input id="egfr-age" inputmode="numeric" autocomplete="off"></label>
        <label class="field">Cinsiyet<select id="egfr-sex">
          <option value="">Seçin</option><option value="female">Kadın</option><option value="male">Erkek</option>
        </select></label>
        <label class="field">Kreatinin birimi<select id="egfr-unit">
          <option value="mg/dL">mg/dL</option><option value="µmol/L">µmol/L</option>
        </select></label>
        <label class="field">Serum kreatinin<input id="egfr-creatinine" inputmode="decimal" autocomplete="off"></label>
      </div>
      <div class="result"><span>eGFR</span><strong id="egfr-value" aria-live="polite">—</strong></div>
      <p class="status" id="egfr-message" role="status"></p>
      <p class="note">Kreatinin hızla değişiyorsa bu tahmin güvenilir değildir. Kronik böbrek hastalığı tanısında sonucu süre ve diğer böbrek hasarı göstergeleriyle birlikte değerlendirin.</p>
      <p class="status"><a href="https://pubmed.ncbi.nlm.nih.gov/34554658/" target="_blank" rel="noopener noreferrer">Inker ve ark. · 2021</a> ·
        <a href="https://www.niddk.nih.gov/research-funding/research-programs/kidney-clinical-research-epidemiology/laboratory/glomerular-filtration-rate-equations/adults" target="_blank" rel="noopener noreferrer">NIDDK · Denklem ve birimler</a> ·
        <a href="https://kdigo.org/guidelines/ckd-evaluation-and-management/" target="_blank" rel="noopener noreferrer">KDIGO · 2024 KBH kılavuzu</a></p>
    </section>
    <section class="card stack" aria-labelledby="uacr-title">
      <h2 id="uacr-title">İdrar Albümin/Kreatinin Oranı (uACR)</h2>
      <p>İki değeri aynı spot idrar örneğinden girin.</p>
      <div class="fields">
        <label class="field">Albümin birimi<select id="uacr-albumin-unit">
          <option value="mg/L">mg/L</option><option value="mg/dL">mg/dL</option>
        </select></label>
        <label class="field">İdrar albümini<input id="uacr-albumin" inputmode="decimal" autocomplete="off"></label>
        <label class="field">Kreatinin birimi<select id="uacr-creatinine-unit">
          <option value="mg/dL">mg/dL</option><option value="g/L">g/L</option>
        </select></label>
        <label class="field">İdrar kreatinini<input id="uacr-creatinine" inputmode="decimal" autocomplete="off"></label>
      </div>
      <div class="result" aria-live="polite"><span>uACR</span><strong id="uacr-value">—</strong><span id="uacr-category"></span></div>
      <p class="status" id="uacr-message" role="status"></p>
      <p class="note">İlk sabah idrarı tercih edilir. Tek bir yüksek sonuçla kroniklik varsaymayın.</p>
      <p class="status"><a href="https://www.niddk.nih.gov/health-information/professionals/advanced-search/quick-reference-uacr-gfr" target="_blank" rel="noopener noreferrer">NIDDK · Hesaplama</a> ·
        <a href="https://kdigo.org/guidelines/ckd-evaluation-and-management/" target="_blank" rel="noopener noreferrer">KDIGO · 2024 albüminüri kategorileri</a></p>
    </section>
    <section class="card stack" aria-labelledby="osm-title">
      <h2 id="osm-title">Serum Osmolalitesi ve Tonisite</h2>
      <div class="fields">
        <label class="field">Ölçülen serum sodyumu (mmol/L)<input id="osm-sodium" inputmode="decimal" autocomplete="off"></label>
        <label class="field">Glukoz birimi<select id="osm-glucose-unit">
          <option value="mg/dL">mg/dL</option><option value="mmol/L">mmol/L</option>
        </select></label>
        <label class="field">Glukoz<input id="osm-glucose" inputmode="decimal" autocomplete="off"></label>
        <label class="field">Üre veya BUN birimi<select id="osm-urea-unit">
          <option value="urea-mg">Üre (mg/dL)</option><option value="urea-mmol">Üre (mmol/L)</option><option value="bun-mg">BUN (mg/dL)</option>
        </select></label>
        <label class="field">Üre veya BUN (isteğe bağlı)<input id="osm-urea" inputmode="decimal" autocomplete="off"></label>
      </div>
      <div class="result" aria-live="polite">
        <span>Efektif osmolalite (tonisite)</span><strong id="osm-tonicity">—</strong>
        <span>Hesaplanan toplam osmolalite</span><strong id="osm-total">—</strong>
      </div>
      <p class="status" id="osm-message" role="status"></p>
      <p>Tonisite = 2 × Na + glukoz. Toplam osmolalite için üre eklenir. Formülde tüm girdiler mmol/L cinsindendir.</p>
      <p class="status"><a href="https://doi.org/10.2337/dci24-0032" target="_blank" rel="noopener noreferrer">ADA/EASD ve ark. · 2024 konsensüsü</a></p>
    </section>
    </div>`;

  const age = $('egfr-age');
  const sex = $('egfr-sex');
  const creatinine = $('egfr-creatinine');
  const unit = $('egfr-unit');
  const format = new Intl.NumberFormat('tr-TR', {maximumFractionDigits: 1});
  function update() {
    const complete = age.value.trim() !== '' && sex.value !== '' && creatinine.value.trim() !== '';
    const result = complete ? estimatedGfr({
      age: decimal(age.value), sex: sex.value, creatinine: decimal(creatinine.value), unit: unit.value
    }) : null;
    $('egfr-value').textContent = result === null ? '—' : format.format(result) + ' mL/dk/1,73 m²';
    $('egfr-message').textContent = complete && result === null ? '18 veya üzeri tam yaş ve pozitif kreatinin girin.' : '';
  }
  age.oninput = creatinine.oninput = sex.onchange = update;
  unit.onchange = () => {
    const hadValue = creatinine.value.trim() !== '';
    creatinine.value = '';
    update();
    if (hadValue) $('egfr-message').textContent = 'Kreatinin değerini seçtiğiniz birimle tekrar girin.';
  };
  bindUrineAlbuminRatio();
  bindSerumOsmolality();
}

function bindSerumOsmolality() {
  const sodium = $('osm-sodium');
  const glucose = $('osm-glucose');
  const urea = $('osm-urea');
  const glucoseUnit = $('osm-glucose-unit');
  const ureaUnit = $('osm-urea-unit');
  const format = new Intl.NumberFormat('tr-TR', {maximumFractionDigits: 1});
  const output = (value) => value == null ? '—' : format.format(value) + ' mOsm/kg';

  function update() {
    const complete = sodium.value.trim() !== '' && glucose.value.trim() !== '';
    const hasUrea = urea.value.trim() !== '';
    const values = { sodium: decimal(sodium.value), glucose: decimal(glucose.value), glucoseUnit: glucoseUnit.value };
    const effective = complete ? serumOsmolality(values) : null;
    const total = effective && hasUrea ? serumOsmolality({
      ...values, urea: decimal(urea.value), ureaUnit: ureaUnit.value
    }) : null;
    $('osm-tonicity').textContent = output(effective?.tonicity);
    $('osm-total').textContent = output(total?.total);
    let message = '';
    if (complete && !effective) message = 'Pozitif sodyum ve glukoz değerleri girin.';
    if (effective && hasUrea && !total) message = 'Üre veya BUN için sıfır ya da pozitif bir sayı girin.';
    $('osm-message').textContent = message;
  }
  sodium.oninput = glucose.oninput = urea.oninput = update;
  for (const [unit, input] of [[glucoseUnit, glucose], [ureaUnit, urea]]) {
    unit.onchange = () => {
      const hadValue = input.value.trim() !== '';
      input.value = '';
      update();
      if (hadValue) $('osm-message').textContent = 'Değeri seçtiğiniz birimle tekrar girin.';
    };
  }
}

function bindUrineAlbuminRatio() {
  const albumin = $('uacr-albumin');
  const creatinine = $('uacr-creatinine');
  const albuminUnit = $('uacr-albumin-unit');
  const creatinineUnit = $('uacr-creatinine-unit');
  const categories = {A1:'Normal veya hafif artmış', A2:'Orta derecede artmış', A3:'Belirgin artmış'};
  function update() {
    const complete = albumin.value.trim() !== '' && creatinine.value.trim() !== '';
    const result = complete ? urineAlbuminCreatinineRatio({
      albumin: decimal(albumin.value), albuminUnit: albuminUnit.value,
      creatinine: decimal(creatinine.value), creatinineUnit: creatinineUnit.value
    }) : null;
    $('uacr-value').textContent = result ? showNumber(result.ratio) + ' mg/g' : '—';
    $('uacr-category').textContent = result ? result.category + ' · ' + categories[result.category] : '';
    $('uacr-message').textContent = complete && !result ? 'Sayısal albümin değeri ve pozitif kreatinin değeri girin.' : '';
  }
  albumin.oninput = creatinine.oninput = update;
  for (const [unit, input] of [[albuminUnit, albumin], [creatinineUnit, creatinine]]) {
    unit.onchange = () => {
      const hadValue = input.value.trim() !== '';
      input.value = '';
      update();
      if (hadValue) $('uacr-message').textContent = 'Değeri seçtiğiniz birimle tekrar girin.';
    };
  }
}

function intensiveCare() {
  main.innerHTML = '<p><a href="#araclar">← Araçlar</a></p>' + title('Yoğun Bakım Araçları') + `
    <div class="grid">
      <section class="card stack" aria-labelledby="map-title">
        <h2 id="map-title">Ortalama Arter Basıncı (MAP)</h2>
        <div class="fields">
          <label class="field">Sistolik basınç (mmHg)<input id="systolic" inputmode="decimal" autocomplete="off"></label>
          <label class="field">Diyastolik basınç (mmHg)<input id="diastolic" inputmode="decimal" autocomplete="off"></label>
        </div>
        <div class="result"><span>Tahmini MAP</span><strong id="map-value" aria-live="polite">—</strong></div>
        <p class="status" id="map-message" role="status"></p>
        <p>MAP ≈ diyastolik basınç + (sistolik − diyastolik) ÷ 3.</p>
        <p class="status"><a href="https://www.ncbi.nlm.nih.gov/books/NBK482189/" target="_blank" rel="noopener noreferrer">Kaynak · StatPearls</a></p>
      </section>
      <section class="card stack" aria-labelledby="pf-title">
        <h2 id="pf-title">PaO₂/FiO₂ Oranı</h2>
        <div class="fields">
          <label class="field">Arteriyel PaO₂ (mmHg)<input id="pao2" inputmode="decimal" autocomplete="off"></label>
          <label class="field">FiO₂ (%)<input id="fio2" inputmode="decimal" autocomplete="off" placeholder="Ör. 40"></label>
        </div>
        <div class="result"><span>PaO₂/FiO₂</span><strong id="pf-value" aria-live="polite">—</strong></div>
        <p class="status" id="pf-message" role="status"></p>
        <p>PaO₂ ÷ (FiO₂ % ÷ 100). FiO₂ değerini kan gazı örneğinin alındığı andaki oksijen desteğine göre girin.</p>
        <p class="status"><a href="https://pubmed.ncbi.nlm.nih.gov/23370826/" target="_blank" rel="noopener noreferrer">Kaynak · Villar ve ark.</a></p>
      </section>
    </div>`;

  function bind(firstId, secondId, calculateValue, outputId, messageId, invalidMessage) {
    const first = $(firstId);
    const second = $(secondId);
    function update() {
      const complete = first.value.trim() !== '' && second.value.trim() !== '';
      const result = complete ? calculateValue(decimal(first.value), decimal(second.value)) : null;
      $(outputId).textContent = result === null ? '—' : showNumber(result) + ' mmHg';
      $(messageId).textContent = complete && result === null ? invalidMessage : '';
    }
    first.oninput = second.oninput = update;
  }
  bind('systolic', 'diastolic', meanArterialPressure, 'map-value', 'map-message',
    'Pozitif basınç değerleri girin. Sistolik basınç diyastolik basınçtan yüksek olmalı.');
  bind('pao2', 'fio2', oxygenationRatio, 'pf-value', 'pf-message',
    'Pozitif bir PaO₂ ve yüzde 21 ile 100 arasında bir FiO₂ girin.');
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

const validMenu = (m) => text(m?.title) && Array.isArray(m.days) &&
  m.days.every((d) => date(d?.date) && Array.isArray(d.lunch) && d.lunch.every(text) &&
    ['ordovr','dinner'].every((key) => d[key] === undefined || Array.isArray(d[key]) && d[key].every(text)));
const keys = (item) => 'guide.' + item.id;
function guideEntry(topic) {
  const key = keys(topic);
  return selectGuideEntry(topic, cached(key), seed[key]);
}
const saved = () => new Set(read('saved') ?? []);
function dataStatus(entry) {
  if (!entry) return navigator.onLine ? 'İçerik yükleniyor veya kaynağa ulaşılamadı.' : 'Çevrimdışı · kayıtlı içerik bulunamadı.';
  const mode = navigator.onLine ? 'Kayıtlı veri' : 'Çevrimdışı · kayıtlı veri';
  return entry.fetchedAt ? mode + ' · son başarılı yenileme ' + time(entry.fetchedAt) : mode + ' · ilk sürüm arşivi';
}
async function loadGuide(items, force, token) {
  const results = await Promise.all(items.map((t) => refresh(keys(t), t.url, (guide) => validGuide(t, guide), force)));
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
  const entry = guideEntry(topic);
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
    const entry = guideEntry(selected);
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
    const sorted = [...topics].sort((a,b) => (guideEntry(b)?.data.lastUpdated ?? '').localeCompare(guideEntry(a)?.data.lastUpdated ?? ''));
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
  const tool = route === 'araclar' && Object.hasOwn(clinicalTools, detail) ? clinicalTools[detail] : null;
  $('crumb').textContent = tool?.title ?? labels[route][0];
  $('nav').querySelectorAll('a').forEach((a) => {
    if (a.hash === '#' + route) a.setAttribute('aria-current','page');
    else a.removeAttribute('aria-current');
  });
  if (tool) tool.render();
  else if (route === 'araclar') home();
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
