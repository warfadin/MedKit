#!/usr/bin/env python3
import json
import sys
from pathlib import Path

INDEX_FIELDS = {
    "schemaVersion": int,
    "contentVersion": str,
    "lastUpdated": str,
    "topics": list,
}

TOPIC_SUMMARY_FIELDS = {
    "id": str,
    "title": str,
    "specialty": str,
    "file": str,
    "lastUpdated": str,
    "latestGuide": str,
    "previousGuide": str,
    "importance": str,
    "updateCount": int,
    "tags": list,
}

TOPIC_DETAIL_FIELDS = {
    "schemaVersion": int,
    "id": str,
    "title": str,
    "specialty": str,
    "lastUpdated": str,
    "overview": str,
    "sources": list,
    "updates": list,
}

SOURCE_FIELDS = {
    "id": str,
    "name": str,
    "organization": str,
    "year": int,
    "url": str,
    "version": str,
}

UPDATE_FIELDS = {
    "id": str,
    "title": str,
    "summary": str,
    "oldRecommendation": str,
    "newRecommendation": str,
    "whatChanged": str,
    "clinicalImpact": str,
    "changeType": str,
    "importance": str,
    "evidenceLevel": str,
    "tags": list,
    "sourceIds": list,
    "relevantSetting": list,
    "examRelevant": bool,
}

CHANGE_TYPES = {
    "newRecommendation",
    "removedRecommendation",
    "modifiedThreshold",
    "expandedIndication",
    "narrowedIndication",
    "changedDrugOrDose",
    "changedTerminology",
    "changedEvidenceLevel",
    "noMajorChange",
    "practicePoint",
}

IMPORTANCE_VALUES = {"practiceChanging", "important", "moderate", "minor"}

SPECIALTIES = {
    "Gastroenterology / Hepatology",
    "Nephrology",
    "Cardiology",
    "Critical Care",
    "Infectious Diseases",
    "Endocrinology",
    "Pulmonology",
    "Hematology",
    "Oncology",
    "General Internal Medicine",
}


def is_type(value, expected):
    if expected is int:
        return type(value) is int
    if expected is bool:
        return type(value) is bool
    return isinstance(value, expected)


def validate_object(obj, fields, path, errors):
    if not isinstance(obj, dict):
        errors.append(f"{path}: expected object")
        return

    missing = sorted(set(fields) - set(obj))
    extra = sorted(set(obj) - set(fields))
    for field in missing:
        errors.append(f"{path}: missing required field '{field}'")
    for field in extra:
        errors.append(f"{path}: schema field not allowed '{field}'")

    for field, expected_type in fields.items():
        if field in obj and not is_type(obj[field], expected_type):
            errors.append(
                f"{path}.{field}: expected {expected_type.__name__}, got {type(obj[field]).__name__}"
            )


def validate_string_array(value, path, errors):
    if not isinstance(value, list):
        return
    for index, item in enumerate(value):
        if not isinstance(item, str):
            errors.append(f"{path}[{index}]: expected string")


def validate_summary(summary, path, errors):
    validate_object(summary, TOPIC_SUMMARY_FIELDS, path, errors)
    validate_string_array(summary.get("tags"), f"{path}.tags", errors)
    if summary.get("importance") not in IMPORTANCE_VALUES:
        errors.append(f"{path}.importance: invalid enum value '{summary.get('importance')}'")
    if summary.get("specialty") not in SPECIALTIES:
        errors.append(f"{path}.specialty: invalid enum value '{summary.get('specialty')}'")


def validate_source(source, path, errors):
    validate_object(source, SOURCE_FIELDS, path, errors)


def validate_update(update, path, errors):
    validate_object(update, UPDATE_FIELDS, path, errors)
    for field in ("tags", "sourceIds", "relevantSetting"):
        validate_string_array(update.get(field), f"{path}.{field}", errors)
    if update.get("changeType") not in CHANGE_TYPES:
        errors.append(f"{path}.changeType: invalid enum value '{update.get('changeType')}'")
    if update.get("importance") not in IMPORTANCE_VALUES:
        errors.append(f"{path}.importance: invalid enum value '{update.get('importance')}'")


def validate_index(data, label, errors):
    validate_object(data, INDEX_FIELDS, label, errors)
    if "schemaVersion" not in data:
        errors.append(f"{label}: schemaVersion is required")
    topics = data.get("topics")
    if not isinstance(topics, list):
        errors.append(f"{label}.topics: expected array")
        return
    for index, summary in enumerate(topics):
        validate_summary(summary, f"{label}.topics[{index}]", errors)


def validate_topic(data, label, errors):
    validate_object(data, TOPIC_DETAIL_FIELDS, label, errors)
    if "schemaVersion" not in data:
        errors.append(f"{label}: schemaVersion is required")
    if data.get("specialty") not in SPECIALTIES:
        errors.append(f"{label}.specialty: invalid enum value '{data.get('specialty')}'")

    sources = data.get("sources")
    if isinstance(sources, list):
        for index, source in enumerate(sources):
            validate_source(source, f"{label}.sources[{index}]", errors)
    else:
        errors.append(f"{label}.sources: expected array")

    updates = data.get("updates")
    if isinstance(updates, list):
        for index, update in enumerate(updates):
            validate_update(update, f"{label}.updates[{index}]", errors)
    else:
        errors.append(f"{label}.updates: expected array")


def detect_and_validate(data, label, errors):
    if isinstance(data, dict) and "topics" in data:
        validate_index(data, label, errors)
    elif isinstance(data, dict) and "updates" in data:
        validate_topic(data, label, errors)
    else:
        errors.append(f"{label}: expected index JSON or topic JSON")


def main():
    if len(sys.argv) < 2:
        print("Usage: validate-guide-json.py <json-file> [<json-file> ...]")
        return 2

    errors = []
    for filename in sys.argv[1:]:
        path = Path(filename)
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"{path}: failed to read JSON: {exc}")
            continue
        detect_and_validate(data, str(path), errors)

    if errors:
        print("Guide Updates JSON validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Guide Updates JSON validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
