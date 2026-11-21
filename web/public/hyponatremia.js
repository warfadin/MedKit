export function assessHyponatremia(values) {
  const { sodium, serumOsm, urineOsm, urineSodium } = values;
  if (![sodium, serumOsm, urineOsm, urineSodium].every(Number.isFinite) ||
      sodium <= 0 || serumOsm <= 0 || urineOsm <= 0 || urineSodium < 0) return null;

  if (sodium >= 135) return 'no-hyponatremia';
  if (serumOsm >= 275) return 'check-tonicity';
  if (urineOsm <= 100) return 'dilute-urine';
  if (urineSodium <= 30) return 'low-effective-volume';
  if (values.volume === 'low' || values.volume === 'high') return 'volume-disorder';

  const exclusions = ['adrenal', 'thyroid', 'renal', 'diuretics', 'intake'];
  if (exclusions.some((key) => values[key] === 'no')) return 'confounded';
  if (values.volume !== 'normal' || exclusions.some((key) => values[key] !== 'yes')) return 'incomplete';
  return 'siadh-compatible';
}
