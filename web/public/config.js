const root = 'https://raw.githubusercontent.com/warfadin/medkit-data/main/';

export const topics = [
  ['aki', 'Akut Böbrek Hasarı', 'Nefroloji', 'nephrology/aki', 'acute_kidney_injury'],
  ['ckd', 'Kronik Böbrek Hastalığı', 'Nefroloji', 'nephrology/ckd', 'chronic_kidney_disease'],
  ['portal_hypertension', 'Portal Hipertansiyon', 'Gastroenteroloji / Hepatoloji', 'gastroenterology/portal_hypertension'],
  ['mash', 'MASH', 'Gastroenteroloji / Hepatoloji', 'gastroenterology/mash'],
  ['sepsis', 'Sepsis', 'Yoğun Bakım', 'intensive_care/sepsis']
].map(([id, title, specialty, path, remoteId = id]) => ({ id, title, specialty, remoteId, url: root + 'guides/' + path + '.json' }));

export const hospitalURL = root + 'menus/hospital-menu-current.json';
export const universityURL = 'https://uludag.edu.tr/yemek';
