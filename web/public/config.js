const root = 'https://raw.githubusercontent.com/warfadin/medkit-data/main/';

export const topics = [
  ['aki', 'Akut Böbrek Hasarı', 'Nefroloji', 'nephrology/aki'],
  ['ckd', 'Kronik Böbrek Hastalığı', 'Nefroloji', 'nephrology/ckd'],
  ['portal_hypertension', 'Portal Hipertansiyon', 'Gastroenteroloji / Hepatoloji', 'gastroenterology/portal_hypertension'],
  ['mash', 'MASH', 'Gastroenteroloji / Hepatoloji', 'gastroenterology/mash'],
  ['sepsis', 'Sepsis', 'Yoğun Bakım', 'intensive_care/sepsis']
].map(([id, title, specialty, path]) => ({ id, title, specialty, url: root + 'guides/' + path + '.json' }));

export const hospitalURL = root + 'menus/hospital-menu-current.json';
export const universityURL = 'https://uludag.edu.tr/yemek';
