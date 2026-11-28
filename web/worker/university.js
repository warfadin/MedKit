const dayNames = /^(Pazartesi|Salı|Çarşamba|Perşembe|Cuma|Cumartesi|Pazar)$/i;
const datePattern = /^(\d{1,2})\.(\d{1,2})\.(\d{4})$/;
const sections = new Map([['Öğle Yemeği','lunch'],['Akşam Yemeği','dinner'],['Ordövr','ordovr']]);
const names = new Map([['Çamlık Yemek Menüsü','camlik'],['Personel Yemek Menüsü','personel']]);
const named = {amp:'&',quot:'"',apos:"'",lt:'<',gt:'>',nbsp:' ',ccedil:'ç',ouml:'ö',uuml:'ü',scedil:'ş',gbreve:'ğ',imath:'ı',Idot:'İ'};

function decode(value) {
  return value.replace(/&(#x[\da-f]+|#\d+|[a-z]+);/gi, (full,code) => {
    if (code[0] !== '#') return named[code] ?? named[code.toLowerCase()]?.toLocaleUpperCase('tr') ?? full;
    const point = code[1].toLowerCase() === 'x' ? parseInt(code.slice(2),16) : Number(code.slice(1));
    return point <= 0x10ffff ? String.fromCodePoint(point) : full;
  });
}

export function parseUniversity(html) {
  const lines = html.replace(/<!--\s*#endregion[^>]*-->/gi,'\nEND_MENU\n').replace(/<!--[\s\S]*?-->|<(script|style)\b[^>]*>[\s\S]*?<\/\1>/gi,'\n')
    .replace(/<[^>]*>/g,'\n').split(/\r?\n/).map((line) => decode(line).trim()).filter(Boolean);
  const menus = {camlik:null,personel:null};
  let candidate = null;
  let section = null;
  let day = null;
  const settle = () => {
    if (!candidate) return;
    const days = [...candidate.days.values()].filter((d) => d.lunch.length || d.dinner.length || d.ordovr.length)
      .sort((a,b) => a.date.localeCompare(b.date));
    if (days.length > (menus[candidate.key]?.days.length ?? 1)) menus[candidate.key] = {title:candidate.title,days};
  };
  for (const line of lines) {
    if (line === 'END_MENU' || /(?:Yemek|Kahvaltı) Menüsü$/i.test(line)) {
      settle();
      candidate = names.has(line) ? {key:names.get(line),title:line,days:new Map()} : null;
      section = null;
      day = null;
      continue;
    }
    if (!candidate) continue;
    if (sections.has(line)) { section = sections.get(line); day = null; continue; }
    const parts = line.match(datePattern);
    if (parts && section) {
      const iso = parts[3] + '-' + parts[2].padStart(2,'0') + '-' + parts[1].padStart(2,'0');
      if (!Number.isFinite(Date.parse(iso)) || new Date(iso).toISOString().slice(0,10) !== iso) { day = null; continue; }
      day = candidate.days.get(iso) ?? {date:iso,weekday:'',lunch:[],dinner:[],ordovr:[]};
      candidate.days.set(iso,day);
    } else if (day && dayNames.test(line)) {
      day.weekday = line;
    } else if (day && line !== '-' && line !== '* * *' && !/^(Alerjen|\(?\d[\d,\s]*\)?$)/i.test(line)) {
      const item = line.replace(/^[-•]\s*/, '').replace(/\s*\(\s*\d+(?:\s*,\s*\d+)*\s*\)$/, '').trim();
      if (item && day[section].length < 10) day[section].push(item);
    }
  }
  settle();
  if (!menus.camlik && !menus.personel) throw new Error('Menu unavailable');
  return menus;
}
