export function meanArterialPressure(systolic, diastolic) {
  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic) || diastolic <= 0 || systolic <= diastolic) return null;
  return diastolic + (systolic - diastolic) / 3;
}

export function oxygenationRatio(pao2, fio2Percent) {
  if (!Number.isFinite(pao2) || pao2 <= 0 || !Number.isFinite(fio2Percent) || fio2Percent < 21 || fio2Percent > 100) return null;
  const ratio = pao2 / (fio2Percent / 100);
  return Number.isFinite(ratio) ? ratio : null;
}
