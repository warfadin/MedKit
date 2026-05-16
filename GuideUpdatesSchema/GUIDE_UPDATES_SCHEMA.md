# Guide Updates Canonical Schema

Guide Updates content is a guideline diff format. It is not a general guideline summary format. New JSON files must follow the canonical schema and the example files in this folder.

If data is missing, keep the existing field and use `null`, an empty string, or an empty array. Do not invent replacement fields. If the schema intentionally changes, increase `schemaVersion` and keep Swift Codable compatibility in mind.

## Remote Layout

```text
/guide-updates/index.json
/guide-updates/topics/<topic-file>.json
```

The app loads `index.json` first. Topic JSON files are lazy-loaded when the user opens a topic.

## Index Object

Required fields:

| Field | Type |
| --- | --- |
| `schemaVersion` | integer |
| `contentVersion` | string |
| `lastUpdated` | string, `YYYY-MM-DD` |
| `topics` | array of topic summaries |

## Topic Summary

Required fields:

| Field | Type |
| --- | --- |
| `id` | string |
| `title` | string |
| `specialty` | enum string |
| `file` | string |
| `lastUpdated` | string, `YYYY-MM-DD` |
| `latestGuide` | string |
| `previousGuide` | string |
| `importance` | enum string |
| `updateCount` | integer |
| `tags` | array of strings |

## Topic Detail

Required fields:

| Field | Type |
| --- | --- |
| `schemaVersion` | integer |
| `id` | string |
| `title` | string |
| `specialty` | enum string |
| `lastUpdated` | string, `YYYY-MM-DD` |
| `overview` | string |
| `sources` | array of guideline sources |
| `updates` | array of update items |

## Guideline Source

Required fields:

| Field | Type |
| --- | --- |
| `id` | string |
| `name` | string |
| `organization` | string |
| `year` | integer |
| `url` | string |
| `version` | string |

## Guide Update Item

Required fields:

| Field | Type |
| --- | --- |
| `id` | string |
| `title` | string |
| `summary` | string |
| `oldRecommendation` | string |
| `newRecommendation` | string |
| `whatChanged` | string |
| `clinicalImpact` | string |
| `changeType` | enum string |
| `importance` | enum string |
| `evidenceLevel` | string |
| `tags` | array of strings |
| `sourceIds` | array of strings |
| `relevantSetting` | array of strings |
| `examRelevant` | boolean |

## Enums

`changeType`:

- `newRecommendation`
- `removedRecommendation`
- `modifiedThreshold`
- `expandedIndication`
- `narrowedIndication`
- `changedDrugOrDose`
- `changedTerminology`
- `changedEvidenceLevel`
- `noMajorChange`
- `practicePoint`

`importance`:

- `practiceChanging`
- `important`
- `moderate`
- `minor`

`specialty`:

- `Gastroenterology / Hepatology`
- `Nephrology`
- `Cardiology`
- `Critical Care`
- `Infectious Diseases`
- `Endocrinology`
- `Pulmonology`
- `Hematology`
- `Oncology`
- `General Internal Medicine`

## Validation

Run:

```bash
python3 scripts/validate-guide-json.py GuideUpdatesSchema/guide-updates-index.example.json GuideUpdatesSchema/guide-topic.example.json
```
