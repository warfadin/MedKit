import { decimal } from './calculator.js';
import { assessHyponatremia } from './hyponatremia.js';

const outcomes = {
  'need-sodium': ['Serum sodyumunu girin', 'Değerlendirmeye serum sodyumuyla başlayın. Semptomları laboratuvar sonuçlarını beklemeden değerlendirin.'],
  'need-serum-osm': ['Hiponatremi var; hipotonisite değerlendirilmeli', 'Ölçülen serum osmolalitesini girin. Osmolalite sınıflandırması sonraki tanısal adımı belirler.'],
  'need-urine-osm': ['Hipotonik hiponatremi; idrar osmolalitesi gerekli', 'Serum osmolalitesi <275 mOsm/kg. Sıradaki adımda idrarın seyrelme yanıtını değerlendirmek için idrar osmolalitesini girin.'],
  'need-urine-sodium': ['İdrar seyrelmemiş; spot idrar sodyumu gerekli', 'Hipotonik hiponatremiye rağmen idrar osmolalitesi >100 mOsm/kg. Sıradaki adımda spot idrar sodyumunu girin.'],
  'no-hyponatremia': ['Sodyum hiponatremi aralığında değil', 'Girilen serum sodyumu 135 mmol/L veya üzerinde.'],
  'check-tonicity': ['Hipotonisite doğrulanmalı', 'Ölçülen osmolalite 275 mOsm/kg veya üzerinde. Glukozu, diğer etkili osmolleri ve psödohiponatremi olasılığını değerlendirin. Yüksek üre varsa efektif osmolaliteyi ayrıca değerlendirin.'],
  'dilute-urine': ['İdrar uygun şekilde seyrelmiş', 'İdrar osmolalitesi ≤100 mOsm/kg. Fazla su alımı ve düşük solüt alımını değerlendirin. Bu örnek klasik SIADH örüntüsünü karşılamıyor.'],
  'low-effective-volume': ['Düşük efektif dolaşım hacmini değerlendirin', 'Spot idrar sodyumu ≤30 mmol/L. Hipovolemi, kalp yetersizliği veya siroz gibi nedenleri klinik volüm durumuyla birlikte değerlendirin. Düşük tuz alımı ve diüretikler yorumu etkileyebilir.'],
  'volume-disorder': ['Volüm bozukluğu ön planda', 'Hipovolemi veya hipervolemi seçildi. Volüm bozukluğunun nedenini ve renal tuz kaybı, diüretik veya adrenal yetmezlik olasılığını değerlendirin. Klinik volüm değerlendirmesi hatalı olabilir.'],
  confounded: ['SIADH değerlendirmesini etkileyen koşul var', 'Diüretik kullanımı, böbrek işlev bozukluğu, adrenal/tiroid bozukluğu veya düşük solüt alımı klasik SIADH kriterlerinin yorumunu etkiler. İşaretlediğiniz koşulları açıklığa kavuşturun.'],
  incomplete: ['SIADH ile uyumlu laboratuvar örüntüsü; değerlendirme eksik', 'Hipotonik hiponatremi, idrar osmolalitesi >100 ve idrar sodyumu >30 mevcut. Övolemi, adrenal ve tiroid işlevleri, böbrek işlevi, diüretik öyküsü ve normal tuz/su alımı doğrulanmalı.'],
  'siadh-compatible': ['SIADH temel kriterleriyle uyumlu', 'Girilen değerler ve doğruladığınız dışlama koşulları SIADH ile uyumlu. Klinik tanıyı örneklerin zamanlaması, ilaç öyküsü ve altta yatan nedenlerle birlikte değerlendirin.']
};

export function hyponatremiaView(main) {
  const field = (id, label) => '<label class="field">' + label +
    '<input id="' + id + '" inputmode="decimal" autocomplete="off"></label>';
  const check = (id, label) => '<label class="field">' + label + '<select id="' + id +
    '"><option value="">Bilinmiyor / değerlendirilmedi</option><option value="yes">Evet</option><option value="no">Hayır</option></select></label>';
  main.innerHTML = `<p><a href="#araclar">← Araçlar</a></p>
    <header class="page-head"><h1>Hiponatremi ve SIADH</h1><p>Erişkinlerde tanısal değerlendirme</p></header>
    <div class="grid">
      <section class="card stack">
        <h2>Laboratuvar ve klinik değerlendirme</h2>
        <p>Serum ve spot idrar örneklerini mümkünse aynı zamanda, tedavi öncesinde değerlendirin.</p>
        <label class="field">Semptomlar<select id="hypo-symptoms">
          <option value="">Değerlendirilmedi</option>
          <option value="none">Belirgin semptom yok</option>
          <option value="moderate">Konfüzyon, baş ağrısı veya kusmasız bulantı</option>
          <option value="severe">Nöbet, belirgin bilinç azalması, sürekli kusma veya kardiyorespiratuvar bozulma</option>
        </select></label>
        <p id="hypo-urgent" class="note" role="alert" hidden></p>
        <div class="fields">
          ${field('hypo-sodium','Serum sodyumu (mmol/L)')}
          ${field('hypo-serumOsm','Ölçülen serum osmolalitesi (mOsm/kg)')}
          ${field('hypo-urineOsm','İdrar osmolalitesi (mOsm/kg)')}
          ${field('hypo-urineSodium','Spot idrar sodyumu (mmol/L)')}
        </div>
        <label class="field">Klinik volüm durumu<select id="hypo-volume">
          <option value="">Bilinmiyor</option><option value="normal">Övolemik</option>
          <option value="low">Hipovolemik</option><option value="high">Hipervolemik</option>
        </select></label>
        ${check('hypo-adrenal','Adrenal yetmezlik dışlandı mı?')}
        ${check('hypo-thyroid','Ciddi hipotiroidi dışlandı mı?')}
        ${check('hypo-renal','Böbrek işlevi normal mi?')}
        ${check('hypo-diuretics','Yakın zamanda diüretik kullanılmadığı doğrulandı mı?')}
        ${check('hypo-intake','Normal tuz ve su alımı doğrulandı mı?')}
      </section>
      <section class="card stack">
        <h2>Değerlendirme</h2>
        <div role="status" aria-live="polite"><h3 id="hypo-result"></h3><p id="hypo-reason"></p></div>
        <p>SIADH bir dışlama tanısıdır. İdrar sodyumu özellikle diüretik kullanımı ve böbrek işlev bozukluğunda yanıltıcı olabilir.</p>
        <p>Pnömoni ve diğer akciğer hastalıkları, santral sinir sistemi hastalıkları, maligniteler ve ilaçlar olası nedenler arasında araştırılır. Ağrı ve bulantı da antidiürezi tetikleyebilir.</p>
        <a href="#araclar/nefroloji">Serum osmolalitesi ve tonisite hesaplayıcısı</a>
        <p class="status"><a href="https://doi.org/10.1530/EJE-13-1020" target="_blank" rel="noopener noreferrer">Avrupa hiponatremi kılavuzu · 2014</a> ·
        <a href="https://www.kjim.org/journal/view.php?number=170730&amp;viewtype=pubreader" target="_blank" rel="noopener noreferrer">KSN önerileri · 2022, Tablo 3</a> ·
        <a href="https://www.endocrinology.org/media/xhrhxhxm/emergency-management-of-severe-and-moderately-severely-symptomatic-hyponatraemia-in-adult-patients-2022.pdf" target="_blank" rel="noopener noreferrer">Society for Endocrinology · 2022</a></p>
      </section>
    </div>`;
  const get = (key) => main.querySelector('#hypo-' + key);
  const numeric = ['sodium', 'serumOsm', 'urineOsm', 'urineSodium'];
  const clinical = ['volume', 'adrenal', 'thyroid', 'renal', 'diuretics', 'intake'];
  function update() {
    const symptoms = get('symptoms').value;
    const urgent = get('urgent');
    urgent.hidden = symptoms !== 'moderate' && symptoms !== 'severe';
    urgent.textContent = symptoms === 'severe'
      ? 'Acil değerlendirme gerekir. Ağır semptomlarda tanısal incelemeler acil tedaviyi geciktirmemeli; monitörizasyon ve seri sodyum takibi gerekir.'
      : 'Gecikmeden klinik değerlendirme gerekir. Semptomların hiponatremiyle ilişkisini ve diğer nedenleri değerlendirin.';
    const values = Object.fromEntries(numeric.map((key) => [
      key, get(key).value.trim() === '' ? undefined : decimal(get(key).value)
    ]));
    for (const key of clinical) values[key] = get(key).value;
    const result = assessHyponatremia(values);
    const [title, reason] = result ? outcomes[result] : [
      'Girdileri kontrol edin',
      'Girilen sodyum ve osmolalite değerleri pozitif, idrar sodyumu sıfır veya pozitif sayılar olmalı.'
    ];
    get('result').textContent = title;
    get('reason').textContent = reason;
  }
  main.querySelectorAll('input').forEach((input) => { input.oninput = update; });
  main.querySelectorAll('select').forEach((select) => { select.onchange = update; });
  update();
}
