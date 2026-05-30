#!/usr/bin/env python3
"""
DAKKHO Appwrite Functions Deployment Script
Deploys all 10 functions to Appwrite Cloud via REST API.

Steps per function:
1. Install npm dependencies
2. Create tar.gz archive of the function directory
3. Create the function via Appwrite REST API (or skip if exists)
4. Upload deployment (tar.gz) via multipart/form-data
5. Set environment variables

Runtime: node-22 (Appwrite Cloud 1.9.5 does not support node-20.0)
"""

import os
import sys
import json
import subprocess
import tarfile
import tempfile
import time
import requests
from pathlib import Path

# ─── Configuration ────────────────────────────────────────────────────────────

APPWRITE_ENDPOINT = os.environ.get("APPWRITE_ENDPOINT", "https://sgp.cloud.appwrite.io/v1")
APPWRITE_PROJECT_ID = os.environ.get("APPWRITE_PROJECT_ID", "dakkho")
APPWRITE_API_KEY = os.environ.get("APPWRITE_API_KEY", "")

HEADERS = {
    "X-Appwrite-Project": APPWRITE_PROJECT_ID,
    "X-Appwrite-Key": APPWRITE_API_KEY,
    "X-Appwrite-Response-Format": "1.6.0",
    "Content-Type": "application/json",
}

FUNCTIONS_BASE_DIR = Path(__file__).parent / "functions"

RUNTIME = "node-22"
ENTRYPOINT = "entry.js"
BUILD_COMMANDS = "npm install"

# ─── Function Definitions ─────────────────────────────────────────────────────

FUNCTIONS = [
    {
        "functionId": "livekit_token",
        "name": "LiveKit Token Generator",
        "env_vars": {
            "LIVEKIT_API_KEY": os.environ.get("LIVEKIT_API_KEY", ""),
            "LIVEKIT_API_SECRET": os.environ.get("LIVEKIT_API_SECRET", ""),
        },
    },
    {
        "functionId": "device_register",
        "name": "Device Register",
        "env_vars": {
            "APPWRITE_ENDPOINT": os.environ.get("APPWRITE_ENDPOINT", "https://sgp.cloud.appwrite.io/v1"),
            "APPWRITE_PROJECT_ID": os.environ.get("APPWRITE_PROJECT_ID", "dakkho"),
            "APPWRITE_API_KEY": APPWRITE_API_KEY,
            "DEVICE_SWAP_COOLDOWN_DAYS": "7",
        },
    },
    {
        "functionId": "payment_verify_bkash",
        "name": "Payment Verify bKash",
        "env_vars": {},  # Admin will configure payment credentials later
    },
    {
        "functionId": "payment_verify_nagad",
        "name": "Payment Verify Nagad",
        "env_vars": {},  # Admin will configure payment credentials later
    },
    {
        "functionId": "payment_verify_sslcommerz",
        "name": "Payment Verify SSLCommerz",
        "env_vars": {},  # Admin will configure payment credentials later
    },
    {
        "functionId": "ai_quiz_generator",
        "name": "AI Quiz Generator",
        "env_vars": {
            "APPWRITE_ENDPOINT": os.environ.get("APPWRITE_ENDPOINT", "https://sgp.cloud.appwrite.io/v1"),
            "APPWRITE_PROJECT_ID": os.environ.get("APPWRITE_PROJECT_ID", "dakkho"),
            "APPWRITE_API_KEY": APPWRITE_API_KEY,
        },
    },
    {
        "functionId": "email_sender",
        "name": "Email Sender",
        "env_vars": {
            "RESEND_API_KEY": os.environ.get("RESEND_API_KEY", ""),
            "APPWRITE_ENDPOINT": os.environ.get("APPWRITE_ENDPOINT", "https://sgp.cloud.appwrite.io/v1"),
            "APPWRITE_PROJECT_ID": os.environ.get("APPWRITE_PROJECT_ID", "dakkho"),
            "APPWRITE_API_KEY": APPWRITE_API_KEY,
        },
    },
    {
        "functionId": "video_upload_handler",
        "name": "Video Upload Handler",
        "env_vars": {
            "R2_ACCESS_KEY_ID": os.environ.get("R2_ACCESS_KEY_ID", ""),
            "R2_SECRET_ACCESS_KEY": os.environ.get("R2_SECRET_ACCESS_KEY", ""),
            "R2_BUCKET": "dakkho",
            "R2_ENDPOINT": os.environ.get("R2_ENDPOINT", ""),
            "R2_REGION": "auto",
            "APPWRITE_ENDPOINT": os.environ.get("APPWRITE_ENDPOINT", "https://sgp.cloud.appwrite.io/v1"),
            "APPWRITE_PROJECT_ID": os.environ.get("APPWRITE_PROJECT_ID", "dakkho"),
            "APPWRITE_API_KEY": APPWRITE_API_KEY,
        },
    },
    {
        "functionId": "reminder_scheduler",
        "name": "Reminder Scheduler",
        "schedule": "*/15 * * * *",  # Cron every 15 minutes
        "env_vars": {
            "APPWRITE_ENDPOINT": os.environ.get("APPWRITE_ENDPOINT", "https://sgp.cloud.appwrite.io/v1"),
            "APPWRITE_PROJECT_ID": os.environ.get("APPWRITE_PROJECT_ID", "dakkho"),
            "APPWRITE_API_KEY": APPWRITE_API_KEY,
            "ONESIGNAL_APP_ID": os.environ.get("ONESIGNAL_APP_ID", ""),
            "ONESIGNAL_REST_API_KEY": os.environ.get("ONESIGNAL_REST_API_KEY", ""),
        },
    },
    {
        "functionId": "bunny_cdn_upload",
        "name": "Bunny CDN Upload",
        "env_vars": {},  # Admin will configure Bunny CDN credentials later
    },
]

# Map from functionId to directory name
DIR_NAME_MAP = {
    "livekit_token": "livekit-token",
    "device_register": "device-register",
    "payment_verify_bkash": "payment-verify-bkash",
    "payment_verify_nagad": "payment-verify-nagad",
    "payment_verify_sslcommerz": "payment-verify-sslcommerz",
    "ai_quiz_generator": "ai-quiz-generator",
    "email_sender": "email-sender",
    "video_upload_handler": "video-upload-handler",
    "reminder_scheduler": "reminder-scheduler",
    "bunny_cdn_upload": "bunny-cdn-upload",
}


# ─── Helper Functions ─────────────────────────────────────────────────────────

def log(msg, level="INFO"):
    """Print a formatted log message."""
    colors = {"INFO": "\033[94m", "OK": "\033[92m", "WARN": "\033[93m", "ERR": "\033[91m"}
    reset = "\033[0m"
    print(f"{colors.get(level, '')}{level}{reset} {msg}")


def install_npm_deps(func_dir: Path) -> bool:
    """Install npm dependencies in the function directory."""
    log(f"  Installing npm dependencies in {func_dir.name}...")
    try:
        result = subprocess.run(
            ["npm", "install", "--production"],
            cwd=str(func_dir),
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            log(f"  npm install failed: {result.stderr[:200]}", "WARN")
            return False
        log(f"  npm install completed for {func_dir.name}", "OK")
        return True
    except subprocess.TimeoutExpired:
        log(f"  npm install timed out for {func_dir.name}", "WARN")
        return False
    except Exception as e:
        log(f"  npm install error: {e}", "WARN")
        return False


def create_tarball(func_dir: Path, output_path: str) -> bool:
    """Create a tar.gz archive of the function directory (excluding .env files)."""
    try:
        with tarfile.open(output_path, "w:gz") as tar:
            for item in func_dir.iterdir():
                # Skip .env files and .env.example
                if item.name.startswith(".env"):
                    continue
                tar.add(str(item), arcname=item.name)
        return True
    except Exception as e:
        log(f"  Failed to create tarball: {e}", "ERR")
        return False


def check_function_exists(function_id: str) -> dict | None:
    """Check if a function already exists. Returns function data or None."""
    url = f"{APPWRITE_ENDPOINT}/functions/{function_id}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=30)
        if resp.status_code == 200:
            return resp.json()
        return None
    except Exception:
        return None


def create_function(func_def: dict) -> dict | None:
    """Create a function via Appwrite REST API. Returns function data or None.
    First checks if function exists (GET), then creates if not found.
    Returns a dict with '$id' on success, or None on plan limit / error."""
    url = f"{APPWRITE_ENDPOINT}/functions"
    schedule = func_def.get("schedule", "")
    fid = func_def["functionId"]

    # First, check if function already exists
    existing = check_function_exists(fid)
    if existing:
        log(f"  Function already exists: {fid} — using existing", "WARN")
        # Update schedule if needed (for reminder-scheduler)
        if schedule and existing.get("schedule") != schedule:
            log(f"  Updating schedule for {fid} to '{schedule}'")
            try:
                requests.put(
                    f"{url}/{fid}",
                    headers=HEADERS,
                    json={"schedule": schedule},
                    timeout=30,
                )
            except Exception:
                pass
        return existing

    # Function doesn't exist, try to create it
    payload = {
        "functionId": fid,
        "name": func_def["name"],
        "runtime": RUNTIME,
        "execute": ["any"],
        "events": [],
        "schedule": schedule,
        "timeout": 300,
        "entrypoint": ENTRYPOINT,
        "commands": BUILD_COMMANDS,
    }

    try:
        resp = requests.post(url, headers=HEADERS, json=payload, timeout=30)
        if resp.status_code == 201:
            data = resp.json()
            log(f"  Function created: {fid} ($id={data.get('$id', '')})", "OK")
            return data
        elif resp.status_code == 409:
            # Race condition — function was just created
            log(f"  Function just created by another process: {fid}", "WARN")
            existing = check_function_exists(fid)
            return existing or {"$id": fid}
        elif resp.status_code == 403 and 'maximum number' in resp.text.lower():
            log(f"  Plan limit reached — cannot create more functions (free plan allows 2)", "WARN")
            return None
        else:
            log(f"  Failed to create function: {resp.status_code} — {resp.text[:300]}", "ERR")
            return None
    except Exception as e:
        log(f"  API error creating function: {e}", "ERR")
        return None


def create_deployment(function_id: str, tarball_path: str) -> dict | None:
    """Upload a deployment for a function via multipart/form-data."""
    url = f"{APPWRITE_ENDPOINT}/functions/{function_id}/deployments"

    # Use multipart headers (no Content-Type in headers, let requests set it)
    multipart_headers = {
        "X-Appwrite-Project": APPWRITE_PROJECT_ID,
        "X-Appwrite-Key": APPWRITE_API_KEY,
        "X-Appwrite-Response-Format": "1.6.0",
    }

    try:
        with open(tarball_path, "rb") as f:
            files = {
                "code": ("code.tar.gz", f, "application/gzip"),
            }
            data = {
                "activate": "true",
            }
            resp = requests.post(url, headers=multipart_headers, files=files, data=data, timeout=180)

        if resp.status_code in (201, 200, 202):
            deployment_data = resp.json()
            log(f"  Deployment created: $id={deployment_data.get('$id', '')}, status={deployment_data.get('status', '?')}", "OK")
            return deployment_data
        else:
            log(f"  Failed to create deployment: {resp.status_code} — {resp.text[:500]}", "ERR")
            return None
    except Exception as e:
        log(f"  API error creating deployment: {e}", "ERR")
        return None


def set_env_variables(function_id: str, env_vars: dict) -> int:
    """Set environment variables for a function. Returns count of variables set."""
    url = f"{APPWRITE_ENDPOINT}/functions/{function_id}/variables"
    count = 0

    for key, value in env_vars.items():
        try:
            resp = requests.post(
                url,
                headers=HEADERS,
                json={"key": key, "value": value},
                timeout=15,
            )
            if resp.status_code == 201:
                log(f"    Set env var: {key}", "OK")
                count += 1
            elif resp.status_code == 409:
                # Variable already exists, update it
                var_id = None
                # List existing variables to find the ID
                list_resp = requests.get(url, headers=HEADERS, timeout=15)
                if list_resp.status_code == 200:
                    vars_data = list_resp.json()
                    for var in vars_data.get("variables", []):
                        if var.get("key") == key:
                            var_id = var.get("$id")
                            break
                if var_id:
                    update_resp = requests.put(
                        f"{url}/{var_id}",
                        headers=HEADERS,
                        json={"key": key, "value": value},
                        timeout=15,
                    )
                    if update_resp.status_code == 200:
                        log(f"    Updated env var: {key}", "OK")
                        count += 1
                    else:
                        log(f"    Failed to update env var {key}: {update_resp.status_code}", "WARN")
                else:
                    log(f"    Env var {key} exists but couldn't find ID to update", "WARN")
            else:
                log(f"    Failed to set env var {key}: {resp.status_code} — {resp.text[:200]}", "WARN")
        except Exception as e:
            log(f"    Error setting env var {key}: {e}", "WARN")

    return count


def get_function_deployment_status(function_id: str) -> dict | None:
    """Get the current deployment status of a function."""
    url = f"{APPWRITE_ENDPOINT}/functions/{function_id}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        if resp.status_code == 200:
            return resp.json()
        return None
    except Exception:
        return None


# ─── Main Deployment Logic ────────────────────────────────────────────────────

def deploy_all():
    """Deploy all 10 Appwrite functions."""
    print("\n" + "=" * 70)
    print("  DAKKHO Appwrite Functions Deployment")
    print(f"  Runtime: {RUNTIME} | Entrypoint: {ENTRYPOINT}")
    print("=" * 70 + "\n")

    results = {
        "created": [],
        "deployed": [],
        "env_set": [],
        "failed": [],
        "plan_limited": [],
    }
    plan_limit_hit = False

    # Step 0: Verify API connectivity
    log("Verifying Appwrite API connectivity...")
    try:
        resp = requests.get(f"{APPWRITE_ENDPOINT}/functions", headers=HEADERS, timeout=15)
        if resp.status_code == 200:
            data = resp.json()
            existing = data.get("total", 0)
            existing_ids = [f.get("$id", "") for f in data.get("functions", [])]
            log(f"API connection OK — {existing} existing functions: {existing_ids}", "OK")
        else:
            log(f"API returned {resp.status_code}: {resp.text[:200]}", "WARN")
    except Exception as e:
        log(f"Cannot connect to Appwrite API: {e}", "ERR")
        sys.exit(1)

    # Step 1: Install npm dependencies for all functions
    print("\n" + "-" * 70)
    log("STEP 1: Installing npm dependencies")
    print("-" * 70)

    for func_def in FUNCTIONS:
        dir_name = DIR_NAME_MAP[func_def["functionId"]]
        func_dir = FUNCTIONS_BASE_DIR / dir_name
        if not func_dir.exists():
            log(f"  Directory not found: {func_dir}", "ERR")
            results["failed"].append(func_def["functionId"])
            continue
        install_npm_deps(func_dir)

    # Step 2: Create functions
    print("\n" + "-" * 70)
    log("STEP 2: Creating functions on Appwrite")
    print("-" * 70)

    function_ids = {}  # functionId -> Appwrite $id

    for func_def in FUNCTIONS:
        fid = func_def["functionId"]
        if fid in results["failed"]:
            continue

        dir_name = DIR_NAME_MAP[fid]
        func_dir = FUNCTIONS_BASE_DIR / dir_name

        if not func_dir.exists():
            log(f"  Skipping {fid} — directory not found", "ERR")
            results["failed"].append(fid)
            continue

        log(f"\nCreating function: {func_def['name']} ({fid})")
        func_data = create_function(func_def)

        if func_data:
            appwrite_id = func_data.get("$id", fid)
            function_ids[fid] = appwrite_id
            results["created"].append(fid)
        else:
            # Check if it was a plan limit error
            results["plan_limited"].append(fid)
            plan_limit_hit = True

    # Step 3: Create deployments
    print("\n" + "-" * 70)
    log("STEP 3: Deploying function code")
    print("-" * 70)

    for func_def in FUNCTIONS:
        fid = func_def["functionId"]
        if fid not in function_ids:
            continue

        dir_name = DIR_NAME_MAP[fid]
        func_dir = FUNCTIONS_BASE_DIR / dir_name
        appwrite_fid = function_ids[fid]

        log(f"\nDeploying: {func_def['name']} ({fid})")

        # Create tarball
        with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
            tarball_path = tmp.name

        if create_tarball(func_dir, tarball_path):
            # Check tarball size
            tarball_size = os.path.getsize(tarball_path)
            log(f"  Tarball size: {tarball_size / 1024:.1f} KB")

            # Upload deployment
            deployment = create_deployment(appwrite_fid, tarball_path)
            if deployment:
                results["deployed"].append(fid)
            else:
                results["failed"].append(fid)
        else:
            results["failed"].append(fid)

        # Cleanup tarball
        try:
            os.unlink(tarball_path)
        except OSError:
            pass

    # Step 4: Set environment variables
    print("\n" + "-" * 70)
    log("STEP 4: Setting environment variables")
    print("-" * 70)

    for func_def in FUNCTIONS:
        fid = func_def["functionId"]
        if fid not in function_ids:
            continue

        appwrite_fid = function_ids[fid]
        env_vars = func_def["env_vars"]

        if not env_vars:
            log(f"\n{func_def['name']}: No env vars to set (admin will configure later)", "INFO")
            results["env_set"].append(fid)
            continue

        log(f"\nSetting env vars for: {func_def['name']} ({len(env_vars)} vars)")
        count = set_env_variables(appwrite_fid, env_vars)
        if count == len(env_vars):
            results["env_set"].append(fid)
        else:
            log(f"  Only {count}/{len(env_vars)} env vars set for {fid}", "WARN")
            results["env_set"].append(fid)  # Partial success still counts

    # Step 5: Verify deployments
    print("\n" + "-" * 70)
    log("STEP 5: Verifying deployment status")
    print("-" * 70)

    for func_def in FUNCTIONS:
        fid = func_def["functionId"]
        if fid not in function_ids:
            continue

        appwrite_fid = function_ids[fid]
        status = get_function_deployment_status(appwrite_fid)

        if status:
            deployment_id = status.get("deployment", "none")
            is_live = status.get("live", False)
            schedule = status.get("schedule", "")
            log(f"  {func_def['name']}: deployment={deployment_id}, live={is_live}, schedule='{schedule}'", "INFO")
        else:
            log(f"  {func_def['name']}: could not fetch status", "WARN")

    # Summary
    print("\n" + "=" * 70)
    log("DEPLOYMENT SUMMARY")
    print("=" * 70)
    log(f"Functions created:  {len(results['created'])}/10")
    log(f"Deployments:        {len(results['deployed'])}/10")
    log(f"Env vars set:       {len(results['env_set'])}/10")
    if results["plan_limited"]:
        log(f"Plan limited:       {len(results['plan_limited'])}/10 — {results['plan_limited']}", "WARN")
        log("  ⚠ Free plan allows only 2 functions. Upgrade to Pro ($15/mo) for unlimited.", "WARN")
        log("  ⚠ Re-run this script after upgrading to deploy remaining functions.", "WARN")
    if results["failed"]:
        log(f"Failed:             {results['failed']}", "ERR")
    if not results["failed"] and not results["plan_limited"]:
        log("All functions deployed successfully!", "OK")
    print("=" * 70 + "\n")

    return results


if __name__ == "__main__":
    deploy_all()
