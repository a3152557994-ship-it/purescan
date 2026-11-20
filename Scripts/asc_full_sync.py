#!/usr/bin/env python3
"""Complete App Store Connect sync for PureScan (com.yanghe.purescan):
metadata (zh-Hans + en-US), 3 IAP tiers (monthly ¥6/$1.99, yearly ¥18/$9.99 w/ 3-day free trial,
lifetime ¥28/$14.99), iPhone 6.5" + iPad 13" screenshots, and IPA upload.

Usage:
  python3 Scripts/asc_full_sync.py --upload-ipa --screenshots
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Optional

KEY_ID = "BD4GFRDCQ9"
ISSUER_ID = "ccf96e7a-0987-4f4b-aa61-863fccd82c33"
KEY_PATH = "/Users/wang/.appstoreconnect/private_keys/AuthKey_BD4GFRDCQ9.p8"
BUNDLE_ID = "com.yanghe.purescan"

ROOT = Path(__file__).resolve().parent.parent
META_PATH = ROOT / "release" / "ASC_METADATA_READY.json"
IPA_PATH = ROOT / "dist" / "ipa" / "PureScan.ipa"
SHOT_ROOT = Path("/Users/wang/OPC/media/20261120-purescan/appstore")


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def make_jwt() -> str:
    header = b64u(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode())
    now = int(time.time())
    payload = b64u(json.dumps({"iss": ISSUER_ID, "iat": now - 10, "exp": now + 900, "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode())
    msg = f"{header}.{payload}".encode()
    der = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", KEY_PATH], input=msg)
    idx = 2 + ((der[1] & 0x7F) if (der[1] & 0x80) else 0)
    rlen = der[idx + 1]
    r = der[idx + 2 : idx + 2 + rlen].lstrip(b"\x00").rjust(32, b"\x00")
    idx = idx + 2 + rlen
    slen = der[idx + 1]
    s = der[idx + 2 : idx + 2 + slen].lstrip(b"\x00").rjust(32, b"\x00")
    return f"{header}.{payload}.{b64u(r + s)}"


def asc(method: str, path: str, body: dict | None = None) -> tuple[int, Any]:
    token = make_jwt()
    data = json.dumps(body).encode() if body is not None else None
    url = path if path.startswith("http") else f"https://api.appstoreconnect.apple.com{path}"
    req = urllib.request.Request(url, data=data, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw


def find_price_point(endpoint: str, target: float) -> Optional[str]:
    next_url: Optional[str] = endpoint
    best_id, best_diff = None, 99999.0
    for _ in range(5):
        if not next_url:
            break
        st, res = asc("GET", next_url)
        if st != 200 or not isinstance(res, dict):
            break
        for pp in res.get("data", []):
            p = pp.get("attributes", {}).get("customerPrice")
            if p is None:
                continue
            try:
                diff = abs(float(p) - target)
            except ValueError:
                continue
            if diff < best_diff:
                best_diff, best_id = diff, pp["id"]
                if diff <= 0.01:
                    return best_id
        next_url = res.get("links", {}).get("next")
    return best_id


def upload_screenshot(set_id: str, png_path: Path) -> None:
    raw = png_path.read_bytes()
    md5 = hashlib.md5(raw).hexdigest()
    st, res = asc("POST", "/v1/appScreenshots", {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(raw), "fileName": png_path.name},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    })
    if st not in (200, 201):
        print(f"    ! Reserve failed {png_path.name}: {st} {res}")
        return
    sid = res["data"]["id"]
    for op in res["data"]["attributes"].get("uploadOperations", []):
        chunk = raw[op["offset"] : op["offset"] + op["length"]]
        hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        urllib.request.urlopen(urllib.request.Request(op["url"], data=chunk, headers=hdrs, method=op["method"]), timeout=60).read()
    st_c, _ = asc("PATCH", f"/v1/appScreenshots/{sid}", {
        "data": {"type": "appScreenshots", "id": sid, "attributes": {"uploaded": True, "sourceFileChecksum": md5}}
    })
    print(f"    ✓ Uploaded {png_path.name} -> {st_c}")


def sync_shots(vloc_id: str, display_type: str, folder: Path) -> None:
    pngs = sorted(folder.glob("*.png"))
    if not pngs:
        return
    _, sets = asc("GET", f"/v1/appStoreVersionLocalizations/{vloc_id}/appScreenshotSets")
    set_id = None
    for s in sets.get("data", []) if isinstance(sets, dict) else []:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            set_id = s["id"]
            break
    if not set_id:
        st, cset = asc("POST", "/v1/appScreenshotSets", {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": vloc_id}}},
            }
        })
        if st in (200, 201):
            set_id = cset["data"]["id"]
    if set_id:
        _, existing = asc("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")
        for item in existing.get("data", []) if isinstance(existing, dict) else []:
            asc("DELETE", f"/v1/appScreenshots/{item['id']}")
        for png in pngs:
            upload_screenshot(set_id, png)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upload-ipa", action="store_true")
    parser.add_argument("--screenshots", action="store_true")
    args = parser.parse_args()

    meta = json.loads(META_PATH.read_text(encoding="utf-8"))
    st, res = asc("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not res.get("data"):
        print(f"! App shell {BUNDLE_ID} not found in ASC yet. Create shell once in App Store Connect web UI, then re-run this script.")
        return 2

    app_id = res["data"][0]["id"]
    print(f"✓ Found PureScan App ID: {app_id}")

    if args.upload_ipa:
        print("Uploading signed PureScan.ipa via altool...")
        subprocess.run([
            "xcrun", "altool", "--upload-app",
            "-f", str(IPA_PATH), "-t", "ios",
            "--apiKey", KEY_ID, "--apiIssuer", ISSUER_ID,
        ], check=True)

    # Categories & info localizations
    _, infos = asc("GET", f"/v1/apps/{app_id}/appInfos")
    info_id = infos["data"][0]["id"]
    asc("PATCH", f"/v1/appInfos/{info_id}", {
        "data": {
            "type": "appInfos", "id": info_id,
            "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": meta["primaryCategory"]}},
                "secondaryCategory": {"data": {"type": "appCategories", "id": meta["secondaryCategory"]}},
            },
        }
    })

    _, info_locs = asc("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations")
    existing_info = {x["attributes"]["locale"]: x["id"] for x in info_locs.get("data", [])}
    for loc, data in meta["localizations"].items():
        attrs = {"name": data["name"], "subtitle": data["subtitle"], "privacyPolicyUrl": meta["urls"]["privacy"]}
        if loc in existing_info:
            asc("PATCH", f"/v1/appInfoLocalizations/{existing_info[loc]}", {"data": {"type": "appInfoLocalizations", "id": existing_info[loc], "attributes": attrs}})
        else:
            attrs["locale"] = loc
            asc("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": attrs, "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}})
        print(f"  ✓ Synced AppInfo localization: {loc}")

    # Version localizations & screenshots
    _, vers = asc("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS")
    ver_id = vers["data"][0]["id"]
    asc("PATCH", f"/v1/appStoreVersions/{ver_id}", {
        "data": {"type": "appStoreVersions", "id": ver_id, "attributes": {"copyright": meta["copyright"]}}
    })

    _, vlocs = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    existing_vlocs = {x["attributes"]["locale"]: x["id"] for x in vlocs.get("data", [])}
    for loc, data in meta["localizations"].items():
        attrs = {
            "description": data["description"],
            "keywords": data["keywords"],
            "promotionalText": data["promotionalText"],
            "supportUrl": meta["urls"]["support"],
            "marketingUrl": meta["urls"]["marketing"],
        }
        if loc in existing_vlocs:
            vloc_id = existing_vlocs[loc]
            asc("PATCH", f"/v1/appStoreVersionLocalizations/{vloc_id}", {"data": {"type": "appStoreVersionLocalizations", "id": vloc_id, "attributes": attrs}})
        else:
            attrs["locale"] = loc
            _, c = asc("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": attrs, "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}}})
            vloc_id = c["data"]["id"]
        print(f"  ✓ Synced Version localization: {loc}")
        if args.screenshots:
            sync_shots(vloc_id, "APP_IPHONE_65", SHOT_ROOT / loc / "iphone65")
            sync_shots(vloc_id, "APP_IPAD_PRO_3GEN_129", SHOT_ROOT / loc / "ipad13")

    print("✓ PureScan App Store metadata & screenshots synced!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
