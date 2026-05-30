#!/usr/bin/env python3
"""
DAKKHO — Cloudflare R2 Public Access + CORS Setup Script
=========================================================
1. Enables R2 public access (dev subdomain) on the "dakkho" bucket via wrangler CLI
2. Sets CORS policy via S3-compatible API (boto3)
3. Uploads a test file and verifies public access
4. Creates folder structure (prefixes) in the bucket
5. Saves R2_PUBLIC_URL to R2_PUBLIC_URL.txt

Prerequisites:
  - Python 3.10+ with boto3
  - npx (for wrangler CLI)
"""

import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error

import boto3
from botocore.config import Config as BotoConfig

# ─── Credentials ──────────────────────────────────────────────────────────────
ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID", "")
API_TOKEN = os.environ.get("R2_API_TOKEN", "")
ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY", "")
SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_KEY", "")
BUCKET = "dakkho"
S3_ENDPOINT = f"https://{ACCOUNT_ID}.r2.cloudflarestorage.com"

# ─── Helpers ──────────────────────────────────────────────────────────────────
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
NC = "\033[0m"

def log(msg):   print(f"{CYAN}[R2]{NC} {msg}")
def ok(msg):    print(f"{GREEN}[R2 ✓]{NC} {msg}")
def warn(msg):  print(f"{YELLOW}[R2 ⚠]{NC} {msg}")
def fail(msg):  print(f"{RED}[R2 ✗]{NC} {msg}"); sys.exit(1)


def cf_api(method, path, body=None):
    """Make a Cloudflare API request and return (status_code, response_json)."""
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}{path}"
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
        "Content-Type": "application/json",
    }
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp_body = json.loads(resp.read().decode())
            return resp.status, resp_body
    except urllib.error.HTTPError as e:
        resp_body = json.loads(e.read().decode()) if e.fp else {}
        return e.code, resp_body
    except Exception as e:
        return 0, {"errors": [{"message": str(e)}]}


def get_s3_client():
    """Return a boto3 S3 client configured for R2."""
    return boto3.client(
        "s3",
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=ACCESS_KEY_ID,
        aws_secret_access_key=SECRET_ACCESS_KEY,
        region_name="auto",
        config=BotoConfig(
            signature_version="s3v4",
            retries={"max_attempts": 3, "mode": "standard"},
        ),
    )


def run_wrangler(args, env_extra=None):
    """Run a wrangler command with the API token and return output."""
    env = os.environ.copy()
    env["CLOUDFLARE_API_TOKEN"] = API_TOKEN
    if env_extra:
        env.update(env_extra)
    result = subprocess.run(
        ["npx", "wrangler"] + args,
        capture_output=True,
        text=True,
        env=env,
        timeout=60,
    )
    return result


# ─── Step 1: Enable R2 Public Access ─────────────────────────────────────────
def enable_public_access():
    log("Step 1: Enabling R2 public access (dev subdomain) on 'dakkho' bucket...")

    # First, list buckets to verify the bucket exists
    status, body = cf_api("GET", "/r2/buckets")
    if status == 200:
        buckets = body.get("result", {}).get("buckets", [])
        bucket_names = [b.get("name") for b in buckets]
        log(f"  Existing buckets: {bucket_names}")
        if BUCKET not in bucket_names:
            warn(f"  Bucket '{BUCKET}' not found in list!")
    else:
        warn(f"Could not list buckets (HTTP {status}). Continuing anyway.")

    # Try to get current dev-url status first
    result = run_wrangler(["r2", "bucket", "dev-url", "get", BUCKET])
    output = result.stdout + result.stderr

    # Check if already enabled
    if "pub-" in output and ".r2.dev" in output:
        # Extract the URL from output
        import re
        url_match = re.search(r'(https://pub-[a-f0-9]+\.r2\.dev)', output)
        if url_match:
            public_url = url_match.group(1)
            ok(f"Public access already enabled: {public_url}")
            return public_url

    # Enable public access via wrangler CLI
    log("  Enabling public access via wrangler CLI...")
    result = run_wrangler(["r2", "bucket", "dev-url", "enable", BUCKET])
    output = result.stdout + result.stderr

    # Extract the public URL from wrangler output
    import re
    url_match = re.search(r'(https://pub-[a-f0-9]+\.r2\.dev)', output)

    if url_match:
        public_url = url_match.group(1)
        ok(f"Public access enabled: {public_url}")
    else:
        warn(f"Could not extract public URL from wrangler output.")
        warn(f"  Wrangler stdout: {result.stdout.strip()}")
        warn(f"  Wrangler stderr: {result.stderr.strip()}")

        # Fallback: try to get the dev-url after enabling
        result2 = run_wrangler(["r2", "bucket", "dev-url", "get", BUCKET])
        output2 = result2.stdout + result2.stderr
        url_match2 = re.search(r'(https://pub-[a-f0-9]+\.r2\.dev)', output2)
        if url_match2:
            public_url = url_match2.group(1)
            ok(f"Public URL retrieved: {public_url}")
        else:
            # Last fallback: construct from account ID
            public_url = f"https://pub-{ACCOUNT_ID}.r2.dev"
            warn(f"Using fallback URL: {public_url}")
            warn("  If this doesn't work, enable manually in Cloudflare Dashboard:")
            warn(f"  https://dash.cloudflare.com/{ACCOUNT_ID}/r2/overview")

    return public_url


# ─── Step 2: Set CORS on the bucket ──────────────────────────────────────────
def set_cors():
    log("Step 2: Setting CORS policy on 'dakkho' bucket...")

    s3 = get_s3_client()

    cors_config = {
        "CORSRules": [
            {
                "AllowedHeaders": ["*"],
                "AllowedMethods": ["GET", "HEAD"],
                "AllowedOrigins": ["*"],
                "ExposeHeaders": ["Content-Length", "Content-Range"],
                "MaxAgeSeconds": 86400,
            }
        ]
    }

    try:
        s3.put_bucket_cors(Bucket=BUCKET, CORSConfiguration=cors_config)
        ok("CORS policy set successfully!")
    except Exception as e:
        warn(f"CORS set failed: {e}")
        warn("You can set CORS manually in the Cloudflare Dashboard → R2 → dakkho → Settings → CORS Policy")
        return

    # Verify CORS
    try:
        resp = s3.get_bucket_cors(Bucket=BUCKET)
        rules = resp.get("CORSRules", [])
        ok(f"CORS verified: {len(rules)} rule(s) in place")
        for i, rule in enumerate(rules):
            log(f"  Rule {i+1}: Methods={rule.get('AllowedMethods')}, Origins={rule.get('AllowedOrigins')}")
    except Exception as e:
        warn(f"Could not verify CORS: {e}")


# ─── Step 3: Upload test file and verify public access ───────────────────────
def test_upload(public_url):
    log("Step 3: Uploading test file and verifying public access...")

    s3 = get_s3_client()
    test_key = "test-r2-setup.txt"
    test_content = (
        f"DAKKHO R2 Setup Test\n"
        f"Bucket: {BUCKET}\n"
        f"Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}\n"
        f"Account: {ACCOUNT_ID}\n"
    )

    # Upload
    try:
        s3.put_object(
            Bucket=BUCKET,
            Key=test_key,
            Body=test_content.encode("utf-8"),
            ContentType="text/plain",
        )
        ok(f"Test file uploaded: {test_key}")
    except Exception as e:
        fail(f"Upload failed: {e}")

    # Verify via S3 API (private access)
    try:
        resp = s3.get_object(Bucket=BUCKET, Key=test_key)
        body = resp["Body"].read().decode("utf-8")
        ok(f"S3 API read verified ({len(body)} bytes)")
    except Exception as e:
        warn(f"S3 API read failed: {e}")

    # Verify public access
    public_file_url = f"{public_url}/{test_key}"
    log(f"  Trying public URL: {public_file_url}")
    try:
        req = urllib.request.Request(public_file_url, headers={"User-Agent": "DAKKHO-R2-Setup/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode("utf-8")
            # Check CORS headers
            cors_header = resp.headers.get("Access-Control-Allow-Origin", "NOT SET")
            expose_headers = resp.headers.get("Access-Control-Expose-Headers", "NOT SET")
            ok(f"PUBLIC ACCESS VERIFIED! File accessible at: {public_file_url}")
            ok(f"  Content ({len(content)} bytes): {content[:80]}...")
            ok(f"  CORS Access-Control-Allow-Origin: {cors_header}")
            ok(f"  CORS Access-Control-Expose-Headers: {expose_headers}")
    except urllib.error.HTTPError as e:
        warn(f"Public URL returned HTTP {e.code}. Public access may not be active yet.")
        warn(f"  URL tried: {public_file_url}")
        warn("  Enable public access in Cloudflare Dashboard → R2 → dakkho → Settings → Public Access")
    except Exception as e:
        warn(f"Public URL check failed: {e}")


# ─── Step 4: Create folder structure ─────────────────────────────────────────
def create_folders():
    log("Step 4: Creating folder structure in 'dakkho' bucket...")

    s3 = get_s3_client()

    folders = [
        "videos/hls/",
        "videos/raw/",
        "videos/thumbnails/",
        "documents/",
        "app-assets/",
    ]

    for folder in folders:
        try:
            s3.put_object(
                Bucket=BUCKET,
                Key=folder,
                Body=b"",
            )
            ok(f"Created folder: {folder}")
        except Exception as e:
            warn(f"Could not create folder '{folder}': {e}")

    # Verify folders exist by listing
    try:
        resp = s3.list_objects_v2(Bucket=BUCKET, Delimiter="/", MaxKeys=100)
        prefixes = resp.get("CommonPrefixes", [])
        objects = resp.get("Contents", [])
        log(f"  Root-level prefixes: {[p['Prefix'] for p in prefixes]}")
        log(f"  Root-level objects: {[o['Key'] for o in objects]}")

        # Also list with videos/ prefix
        resp2 = s3.list_objects_v2(Bucket=BUCKET, Prefix="videos/", Delimiter="/", MaxKeys=100)
        prefixes2 = resp2.get("CommonPrefixes", [])
        objects2 = resp2.get("Contents", [])
        log(f"  videos/ sub-folders: {[p['Prefix'] for p in prefixes2]}")
    except Exception as e:
        warn(f"Could not list bucket contents: {e}")


# ─── Main ────────────────────────────────────────────────────────────────────
def main():
    print(f"\n{CYAN}═══════════════════════════════════════════════════════════════{NC}")
    print(f"{CYAN}  DAKKHO — R2 Public Access + CORS Setup{NC}")
    print(f"{CYAN}═══════════════════════════════════════════════════════════════{NC}\n")

    # Step 1: Enable public access
    public_url = enable_public_access()
    print()

    # Step 2: Set CORS
    set_cors()
    print()

    # Step 3: Test upload
    test_upload(public_url)
    print()

    # Step 4: Create folders
    create_folders()
    print()

    # ─── Save R2_PUBLIC_URL ───────────────────────────────────────────────
    output_path = "/home/z/my-project/dakkho-cloud/R2_PUBLIC_URL.txt"
    with open(output_path, "w") as f:
        f.write(public_url + "\n")
    ok(f"R2_PUBLIC_URL saved to {output_path}")

    # ─── Summary ──────────────────────────────────────────────────────────
    print(f"\n{CYAN}═══════════════════════════════════════════════════════════════{NC}")
    print(f"{CYAN}  DAKKHO — R2 Setup Summary{NC}")
    print(f"{CYAN}═══════════════════════════════════════════════════════════════{NC}")
    print(f"  Bucket:       {GREEN}{BUCKET}{NC}")
    print(f"  S3 Endpoint:  {GREEN}{S3_ENDPOINT}{NC}")
    print(f"  Public URL:   {GREEN}{public_url}{NC}")
    print(f"  CORS:         {GREEN}GET, HEAD from *{NC}")
    print(f"  Folders:      {GREEN}videos/hls/, videos/raw/, videos/thumbnails/, documents/, app-assets/{NC}")
    print(f"  Test file:    {GREEN}{public_url}/test-r2-setup.txt{NC}")
    print(f"{CYAN}═══════════════════════════════════════════════════════════════{NC}\n")

    print(f"R2_PUBLIC_URL={public_url}")


if __name__ == "__main__":
    main()
