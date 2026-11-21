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

export function urineAlbuminCreatinineRatio({ albumin, albuminUnit, creatinine, creatinineUnit }) {
  if (!Number.isFinite(albumin) || albumin < 0 || !Number.isFinite(creatinine) || creatinine <= 0) return null;
  if (albuminUnit !== 'mg/L' && albuminUnit !== 'mg/dL') return null;
  if (creatinineUnit !== 'mg/dL' && creatinineUnit !== 'g/L') return null;

  const albuminMgPerL = albuminUnit === 'mg/dL' ? albumin * 10 : albumin;
  const creatinineGPerL = creatinineUnit === 'mg/dL' ? creatinine / 100 : creatinine;
  let ratio = albuminMgPerL / creatinineGPerL;
  if (!Number.isFinite(ratio) || (ratio === 0 && albumin > 0)) return null;

  // Keep equivalent decimal inputs on the same side of KDIGO's boundaries.
  for (const boundary of [30, 300]) {
    if (Math.abs(ratio - boundary) <= 4 * Number.EPSILON * boundary) ratio = boundary;
  }
  const category = ratio < 30 ? 'A1' : ratio <= 300 ? 'A2' : 'A3';
  return { ratio, category };
}

export function serumOsmolality({ sodium, glucose, glucoseUnit, urea, ureaUnit }) {
  if (!Number.isFinite(sodium) || sodium <= 0 || !Number.isFinite(glucose) || glucose <= 0) return null;
  if (glucoseUnit !== 'mg/dL' && glucoseUnit !== 'mmol/L') return null;

  // ADA/EASD 2024 consensus uses 2 × sodium plus glucose, with solutes in mmol/L.
  const tonicity = 2 * sodium + glucose * (glucoseUnit === 'mg/dL' ? 0.05551 : 1);
  if (!Number.isFinite(tonicity)) return null;
  if (urea === undefined) return { tonicity, total: null };
  const ureaFactors = { 'urea-mg': 0.1665, 'bun-mg': 0.357, 'urea-mmol': 1 };
  if (!Number.isFinite(urea) || urea < 0 || !Object.hasOwn(ureaFactors, ureaUnit)) return null;
  const total = tonicity + urea * ureaFactors[ureaUnit];
  return Number.isFinite(total) ? { tonicity, total } : null;
}
