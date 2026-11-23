export function assessHyponatremia(values) {
  const { sodium, serumOsm, urineOsm, urineSodium } = values;
  const positive = [sodium, serumOsm, urineOsm];
  if (positive.some((value) => value !== undefined && (!Number.isFinite(value) || value <= 0)) ||
      urineSodium !== undefined && (!Number.isFinite(urineSodium) || urineSodium < 0)) return null;

  if (sodium === undefined) return 'need-sodium';
  if (sodium >= 135) return 'no-hyponatremia';
  if (serumOsm === undefined) return 'need-serum-osm';
  if (serumOsm >= 275) return 'check-tonicity';
  if (urineOsm === undefined) return 'need-urine-osm';
  if (urineOsm <= 100) return 'dilute-urine';
  if (urineSodium === undefined) return 'need-urine-sodium';
  if (urineSodium <= 30) return 'low-effective-volume';
  if (values.volume === 'low' || values.volume === 'high') return 'volume-disorder';

  const exclusions = ['adrenal', 'thyroid', 'renal', 'diuretics', 'intake'];
  if (exclusions.some((key) => values[key] === 'no')) return 'confounded';
  if (values.volume !== 'normal' || exclusions.some((key) => values[key] !== 'yes')) return 'incomplete';
  return 'siadh-compatible';
}
