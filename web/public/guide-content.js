const text = (value) => typeof value === 'string' && value.trim().length > 0;

export function validGuide(topic, guide) {
  return guide?.schemaVersion === 1 &&
    (guide.id === topic.id || guide.id === topic.remoteId) &&
    text(guide.title) && text(guide.specialty) &&
    typeof guide.lastUpdated === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(guide.lastUpdated) &&
    Number.isFinite(Date.parse(guide.lastUpdated)) &&
    Array.isArray(guide.sources) && guide.sources.every((source) =>
      text(source?.id) && text(source.name) && text(source.url)) &&
    Array.isArray(guide.updates) && guide.updates.every((update) =>
      text(update?.id) && text(update.title));
}

export function selectGuideEntry(topic, entry, snapshot) {
  if (validGuide(topic, entry?.data)) return entry;
  return validGuide(topic, snapshot) ? {data:snapshot} : null;
}
