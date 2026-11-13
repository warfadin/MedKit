export const agents = [
  { name: 'Nöradrenalin', solvent: 'SF', mixes: [[8,100],[16,100],[4,50],[32,250]], slider: [0.8,1.5,2.1] },
  { name: 'Adrenalin', solvent: 'SF', mixes: [[4,100],[8,100],[4,50],[10,250]], slider: [0.6,1.2,2] },
  { name: 'Dobutamin', solvent: '%5 Dex', mixes: [[250,250],[500,250],[250,50],[500,500]] },
  { name: 'Dopamin', solvent: '%5 Dex', mixes: [[400,250],[800,250],[200,100],[400,500]] }
];

export function decimal(text) {
  const value = text.trim();
  if (!/^\d*(?:[,.]\d+)?$/.test(value) || !value) return NaN;
  return Number(value.replace(',', '.'));
}

export function calculate({ weight, mg, volume, input, direction }) {
  if (![weight, mg, volume].every(value => Number.isFinite(value) && value > 0)
      || !Number.isFinite(input) || input < 0) return null;
  const concentration = mg * 1000 / volume;
  const factor = weight * 60 / concentration;
  const dose = direction === 'rate' ? input / factor : input;
  const rate = direction === 'rate' ? input : input * factor;
  return concentration > 0 && factor > 0 && [concentration, factor, dose, rate].every(Number.isFinite)
    ? { concentration, dose, rate }
    : null;
}

export function sliderLimit(agent, weight, concentration) {
  if (!agent.slider) return 25;
  const [low, high, factor] = agent.slider;
  return Math.max(low, Math.min(high, 30 * concentration / (weight * 60) * factor));
}

export function sliderDose(progress, maxDose, weight, concentration) {
  const maxRate = maxDose * weight * 60 / concentration;
  if (maxRate <= 30) return progress * maxDose;
  const rate = progress <= 0.72 ? progress / 0.72 * 30 : 30 + (progress - 0.72) / 0.28 * (maxRate - 30);
  return rate * concentration / (weight * 60);
}

export function sliderProgress(dose, maxDose, weight, concentration) {
  const maxRate = maxDose * weight * 60 / concentration;
  const rate = Math.min(dose, maxDose) * weight * 60 / concentration;
  if (maxRate <= 30) return rate / maxRate;
  return rate <= 30 ? rate / 30 * 0.72 : 0.72 + (rate - 30) / (maxRate - 30) * 0.28;
}
