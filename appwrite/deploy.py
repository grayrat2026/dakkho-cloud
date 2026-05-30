#!/usr/bin/env python3
"""
DAKKHO Appwrite Database & Collections Deploy Script v3
Deploys: 1 database, 22 collections (with fields + indexes), 5 storage buckets

Key fixes from v2:
- Appwrite rule: cannot set default on required attr → set required=false when default exists
- Free plan bucket maxFileSize: 50MB max
- String size reductions for collections near document size limit
"""

import json
import os
import sys
import time
import requests
from pathlib import Path

# ─── Configuration ────────────────────────────────────────────────────────────
ENDPOINT = os.environ.get("APPWRITE_ENDPOINT", "https://sgp.cloud.appwrite.io/v1")
PROJECT_ID = os.environ.get("APPWRITE_PROJECT_ID", "dakkho")
API_KEY = os.environ.get("APPWRITE_API_KEY", "")
DATABASE_ID = "dakkho_main"
DATABASE_NAME = "DAKKHO Main Database"
COLLECTIONS_DIR = Path(__file__).parent / "collections"
OUTPUT_FILE = Path(__file__).parent / "deployed_resources.json"

HEADERS = {
    "X-Appwrite-Project": PROJECT_ID,
    "X-Appwrite-Key": API_KEY,
    "X-Appwrite-Response-Format": "1.6.0",
    "Content-Type": "application/json",
}

# String size overrides for free plan compatibility (65535 byte document limit)
# Format: {collection_id: {field_key: new_size}}
SIZE_OVERRIDES = {
    "announcements": {"body": 2000, "body_en": 2000},
    "doubts": {"description": 1500, "resolution": 2000, "ai_response": 2000},
    "quiz_questions": {"question_text": 1000, "question_text_en": 1000, "explanation": 1000, "explanation_en": 1000},
    "quiz_attempts": {"answers": 5000},
    "chat_messages": {"content": 2000},
    "audit_logs": {"changes": 5000},
    "courses": {"description": 2000, "tags": 200},
    "payments_config": {"api_key_encrypted": 1000, "api_secret_encrypted": 1000, "instructions_bn": 1000, "instructions_en": 1000},
}

# Track all created resources
deployed = {"database": None, "collections": {}, "buckets": {}}

stats = {"collections_created": 0, "collections_skipped": 0, "fields_created": 0,
         "fields_skipped": 0, "fields_failed": 0, "indexes_created": 0,
         "indexes_skipped": 0, "indexes_failed": 0,
         "buckets_created": 0, "buckets_skipped": 0, "errors": []}


def log(msg, level="INFO"):
    prefix = {"INFO": "ℹ️", "OK": "✅", "WARN": "⚠️", "ERR": "❌", "STEP": "🚀"}.get(level, "•")
    print(f"{prefix}  {msg}", flush=True)


def api_call(method, path, body=None, timeout=30):
    url = f"{ENDPOINT}{path}"
    try:
        resp = requests.request(method, url, headers=HEADERS, json=body, timeout=timeout)
        try:
            data = resp.json()
        except Exception:
            data = {"raw": resp.text}
        return resp.status_code, data
    except requests.exceptions.Timeout:
        return 0, {"message": "Request timed out"}
    except Exception as e:
        return 0, {"message": str(e)}


def is_already_exists(code, data):
    if code == 409:
        return True
    if code == 400 and isinstance(data, dict):
        msg = data.get("message", "").lower()
        if "already exists" in msg or "duplicate" in msg:
            return True
    return False


# ─── Step 1: Create Database ──────────────────────────────────────────────────
def create_database():
    log("Step 1: Creating database...", "STEP")
    code, _ = api_call("GET", f"/databases/{DATABASE_ID}")
    if code == 200:
        log(f"  Database '{DATABASE_ID}' already exists", "WARN")
        deployed["database"] = DATABASE_ID
        return

    code, data = api_call("POST", "/databases", {
        "databaseId": DATABASE_ID,
        "name": DATABASE_NAME,
    })
    if code == 201:
        log(f"  Database '{DATABASE_NAME}' created", "OK")
        deployed["database"] = DATABASE_ID
    elif is_already_exists(code, data):
        deployed["database"] = DATABASE_ID
        log(f"  Database already exists", "WARN")
    else:
        log(f"  Failed: {code} - {data}", "ERR")
        sys.exit(1)


# ─── Step 2: Create Collections & Attributes ──────────────────────────────────
def create_attribute(coll_id, field):
    ftype = field["type"]
    key = field["key"]
    required = field.get("required", False)
    default = field.get("default")
    array = field.get("array", False)
    size = field.get("size", 0)
    elements = field.get("elements", [])

    # CRITICAL: Appwrite rule - cannot set default on required attribute
    # When a default is provided, set required=false (default fills the value)
    if default is not None and required:
        required = False

    base = f"/databases/{DATABASE_ID}/collections/{coll_id}/attributes"

    if ftype == "string":
        body = {"key": key, "size": size if size > 0 else 255, "required": required, "array": array}
        if default is not None:
            body["default"] = default
        return api_call("POST", f"{base}/string", body)

    elif ftype == "integer":
        body = {"key": key, "required": required, "array": array}
        if default is not None:
            body["default"] = int(default) if isinstance(default, str) else default
        return api_call("POST", f"{base}/integer", body)

    elif ftype == "float":
        body = {"key": key, "required": required, "array": array}
        if default is not None:
            body["default"] = float(default) if isinstance(default, str) else default
        return api_call("POST", f"{base}/float", body)

    elif ftype == "boolean":
        body = {"key": key, "required": required, "array": array}
        if default is not None:
            body["default"] = default.lower() == "true" if isinstance(default, str) else default
        return api_call("POST", f"{base}/boolean", body)

    elif ftype == "enum":
        body = {"key": key, "size": size if size > 0 else 50, "required": required,
                "array": array, "elements": elements}
        if default is not None:
            body["default"] = default
        return api_call("POST", f"{base}/enum", body)

    elif ftype == "datetime":
        body = {"key": key, "required": required, "array": array}
        return api_call("POST", f"{base}/datetime", body)

    elif ftype == "url":
        body = {"key": key, "size": size if size > 0 else 500, "required": required, "array": array}
        return api_call("POST", f"{base}/url", body)

    elif ftype == "email":
        body = {"key": key, "size": size if size > 0 else 255, "required": required, "array": array}
        return api_call("POST", f"{base}/email", body)

    elif ftype == "ip":
        body = {"key": key, "size": size if size > 0 else 45, "required": required, "array": array}
        return api_call("POST", f"{base}/ip", body)

    else:
        return 0, {"message": f"Unknown type: {ftype}"}


def apply_size_overrides(schema):
    """Apply string size reductions for free plan compatibility."""
    coll_id = schema["$id"]
    overrides = SIZE_OVERRIDES.get(coll_id, {})
    for field in schema.get("fields", []):
        if field["key"] in overrides and field["type"] in ("string", "enum", "url", "email", "ip"):
            original = field.get("size", 0)
            field["size"] = overrides[field["key"]]
            if original != field["size"]:
                log(f"    Size override: {field['key']} {original} → {field['size']}", "INFO")
    return schema


def create_collections_and_attributes():
    log("Step 2: Creating 22 collections with attributes...", "STEP")
    collection_files = sorted(COLLECTIONS_DIR.glob("*.json"))

    for cf in collection_files:
        with open(cf) as f:
            schema = json.load(f)

        schema = apply_size_overrides(schema)
        coll_id = schema["$id"]
        coll_name = schema["name"]
        fields = schema.get("fields", [])

        # Create collection
        code, data = api_call("POST", f"/databases/{DATABASE_ID}/collections", {
            "collectionId": coll_id,
            "name": coll_name,
            "permissions": ['read("any")', 'create("any")', 'update("any")', 'delete("any")'],
        })

        if code == 201:
            log(f"  ✦ {coll_name} ({len(fields)} fields)", "OK")
            stats["collections_created"] += 1
        elif is_already_exists(code, data):
            log(f"  ✦ {coll_name} (exists, adding missing fields)", "WARN")
            stats["collections_skipped"] += 1
        else:
            log(f"  ✦ {coll_name} FAILED: {code} - {data}", "ERR")
            stats["errors"].append(f"Collection {coll_id}: {code}")
            continue

        deployed["collections"][coll_id] = {"name": coll_name, "fields": [], "indexes": []}

        # Create attributes
        for field in fields:
            code, data = create_attribute(coll_id, field)
            fkey = field["key"]
            if code in (201, 202):
                deployed["collections"][coll_id]["fields"].append(fkey)
                stats["fields_created"] += 1
            elif is_already_exists(code, data):
                deployed["collections"][coll_id]["fields"].append(fkey)
                stats["fields_skipped"] += 1
            else:
                msg = data.get("message", str(data))[:120]
                log(f"    ✗ {fkey}: {msg}", "ERR")
                stats["fields_failed"] += 1
                stats["errors"].append(f"{coll_id}.{fkey}: {msg}")

        time.sleep(0.3)


# ─── Step 3: Wait for attributes ──────────────────────────────────────────────
def wait_for_all_attributes(max_wait=300):
    log("Step 3: Waiting for all attributes to process...", "STEP")
    start = time.time()
    pending = set(deployed["collections"].keys())

    while pending and time.time() - start < max_wait:
        ready = set()
        for cid in pending:
            code, data = api_call("GET", f"/databases/{DATABASE_ID}/collections/{cid}/attributes")
            if code != 200:
                continue
            attrs = data.get("attributes", [])
            if not attrs:
                continue
            processing = [a for a in attrs if a.get("status") not in ("available", "failed")]
            failed = [a for a in attrs if a.get("status") == "failed"]
            if failed:
                for f in failed:
                    log(f"    {cid}.{f.get('key')}: FAILED - {f.get('error','?')}", "ERR")
            if not processing:
                ready.add(cid)

        if ready:
            for c in ready:
                avail = len([a for a in attrs if a.get("status") == "available"])
                log(f"  {c}: {avail} attrs ready", "OK")
            pending -= ready
        else:
            log(f"  Waiting for {len(pending)} collections... ({int(time.time()-start)}s)", "INFO")
            time.sleep(5)

    if pending:
        log(f"  Timeout for: {pending}", "WARN")
    else:
        log(f"  All done in {int(time.time()-start)}s", "OK")


# ─── Step 4: Create Indexes ───────────────────────────────────────────────────
def create_all_indexes():
    log("Step 4: Creating indexes...", "STEP")
    collection_files = sorted(COLLECTIONS_DIR.glob("*.json"))

    for cf in collection_files:
        with open(cf) as f:
            schema = json.load(f)

        coll_id = schema["$id"]
        indexes = schema.get("indexes", [])
        if not indexes or coll_id not in deployed["collections"]:
            continue

        for index in indexes:
            key = index["key"]
            body = {
                "key": key,
                "type": index["type"],
                "attributes": index["attributes"],
                "orders": index.get("orders", ["ASC"] * len(index["attributes"])),
            }
            code, data = api_call("POST", f"/databases/{DATABASE_ID}/collections/{coll_id}/indexes", body)
            if code in (201, 202):
                deployed["collections"][coll_id]["indexes"].append(key)
                stats["indexes_created"] += 1
            elif is_already_exists(code, data):
                deployed["collections"][coll_id]["indexes"].append(key)
                stats["indexes_skipped"] += 1
            else:
                msg = data.get("message", str(data))[:120]
                log(f"    ✗ {coll_id}.{key}: {msg}", "ERR")
                stats["indexes_failed"] += 1
                stats["errors"].append(f"{coll_id} idx {key}: {msg}")

        time.sleep(0.3)


# ─── Step 5: Create Storage Buckets ──────────────────────────────────────────
BUCKETS = [
    {"bucketId": "videos-raw", "name": "Videos Raw",
     "maximumFileSize": 50000000, "allowedFileExtensions": ["mp4", "mkv", "avi", "mov"]},
    {"bucketId": "videos-drm", "name": "Videos DRM",
     "maximumFileSize": 50000000, "allowedFileExtensions": []},
    {"bucketId": "documents", "name": "Documents",
     "maximumFileSize": 50000000, "allowedFileExtensions": ["pdf", "doc", "docx", "ppt", "pptx"]},
    {"bucketId": "avatars", "name": "Avatars",
     "maximumFileSize": 5000000, "allowedFileExtensions": ["jpg", "jpeg", "png", "webp"]},
    {"bucketId": "app-assets", "name": "App Assets",
     "maximumFileSize": 10000000, "allowedFileExtensions": []},
]


def create_buckets():
    log("Step 5: Creating storage buckets...", "STEP")
    for bucket in BUCKETS:
        bid = bucket["bucketId"]
        # Check if exists
        check_code, _ = api_call("GET", f"/storage/buckets/{bid}")
        if check_code == 200:
            log(f"  {bid}: already exists", "WARN")
            deployed["buckets"][bid] = bucket["name"]
            stats["buckets_skipped"] += 1
            continue

        body = dict(bucket)
        body["permissions"] = ['read("any")', 'create("any")', 'update("any")', 'delete("any")']
        body["compression"] = "none"

        code, data = api_call("POST", "/storage/buckets", body)
        if code == 201:
            log(f"  {bid}: created ({bucket['name']})", "OK")
            deployed["buckets"][bid] = bucket["name"]
            stats["buckets_created"] += 1
        elif is_already_exists(code, data):
            deployed["buckets"][bid] = bucket["name"]
            stats["buckets_skipped"] += 1
        else:
            msg = data.get("message", str(data))[:150]
            log(f"  {bid}: FAILED - {msg}", "ERR")
            stats["errors"].append(f"Bucket {bid}: {msg}")
            # Retry without allowedFileExtensions if empty
            if not bucket.get("allowedFileExtensions"):
                body2 = {k: v for k, v in body.items() if k != "allowedFileExtensions"}
                code2, data2 = api_call("POST", "/storage/buckets", body2)
                if code2 == 201:
                    log(f"  {bid}: created (no ext restrictions)", "OK")
                    deployed["buckets"][bid] = bucket["name"]
                    stats["buckets_created"] += 1
                    stats["errors"].pop()


# ─── Verification ─────────────────────────────────────────────────────────────
def verify_deployment():
    log("Verification: Checking deployment...", "STEP")

    # Database
    code, _ = api_call("GET", f"/databases/{DATABASE_ID}")
    log(f"  Database: {'FOUND' if code == 200 else 'NOT FOUND'}", "OK" if code == 200 else "ERR")

    # Collections
    code, data = api_call("GET", f"/databases/{DATABASE_ID}/collections")
    if code == 200:
        colls = data.get("collections", [])
        log(f"  Collections: {len(colls)}")
        for c in colls:
            cid = c.get("$id")
            acode, adata = api_call("GET", f"/databases/{DATABASE_ID}/collections/{cid}/attributes")
            attrs = adata.get("attributes", []) if acode == 200 else []
            avail = len([a for a in attrs if a.get("status") == "available"])
            failed = len([a for a in attrs if a.get("status") == "failed"])
            icode, idata = api_call("GET", f"/databases/{DATABASE_ID}/collections/{cid}/indexes")
            idxs = len(idata.get("indexes", [])) if icode == 200 else 0
            flag = " ⚠️" if failed > 0 else ""
            log(f"    {cid}: {avail} attrs, {idxs} indexes{flag}")

    # Buckets
    code, data = api_call("GET", "/storage/buckets")
    if code == 200:
        bkts = data.get("buckets", [])
        log(f"  Buckets: {len(bkts)}")
        for b in bkts:
            log(f"    {b.get('$id')}: {b.get('name')} (max {b.get('maximumFileSize', 0)/1024/1024:.0f}MB)")


# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    log("=" * 60, "STEP")
    log("DAKKHO Appwrite Deployment v3", "STEP")
    log("=" * 60, "STEP")
    print()

    create_database()
    print()
    create_collections_and_attributes()
    print()
    wait_for_all_attributes()
    print()
    create_all_indexes()
    print()
    create_buckets()
    print()

    # Save results
    with open(OUTPUT_FILE, "w") as f:
        json.dump(deployed, f, indent=2)
    log(f"Results saved to {OUTPUT_FILE}")

    # Verify
    print()
    verify_deployment()

    # Summary
    print()
    log("=" * 60, "STEP")
    log("DEPLOYMENT SUMMARY", "STEP")
    log("=" * 60, "STEP")
    log(f"Database:      {deployed['database']}")
    log(f"Collections:   {stats['collections_created']} created, {stats['collections_skipped']} skipped")
    log(f"Fields:        {stats['fields_created']} created, {stats['fields_skipped']} skipped, {stats['fields_failed']} failed")
    log(f"Indexes:       {stats['indexes_created']} created, {stats['indexes_skipped']} skipped, {stats['indexes_failed']} failed")
    log(f"Buckets:       {stats['buckets_created']} created, {stats['buckets_skipped']} skipped")
    if stats["errors"]:
        log(f"Errors:        {len(stats['errors'])}")
        for e in stats["errors"][:20]:
            log(f"  {e}", "ERR")
        if len(stats["errors"]) > 20:
            log(f"  ... and {len(stats['errors'])-20} more", "ERR")
    else:
        log("Errors:        None 🎉")
    log("=" * 60, "STEP")


if __name__ == "__main__":
    main()
