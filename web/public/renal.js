export function estimatedGfr({ age, sex, creatinine, unit }) {
  if (!Number.isInteger(age) || age < 18 || !Number.isFinite(creatinine) || creatinine <= 0) return null;
  if (sex !== 'female' && sex !== 'male') return null;
  if (unit !== 'mg/dL' && unit !== 'µmol/L') return null;

  const female = sex === 'female';
  const mgPerDl = unit === 'µmol/L' ? creatinine / 88.4 : creatinine;
  const ratio = mgPerDl / (female ? 0.7 : 0.9);
  // 2021 CKD-EPI creatinine equation, Inker et al.
  const estimate = 142 * Math.min(ratio, 1) ** (female ? -0.241 : -0.302) *
    Math.max(ratio, 1) ** -1.2 * 0.9938 ** age * (female ? 1.012 : 1);
  return Number.isFinite(estimate) && estimate > 0 ? estimate : null;
}
