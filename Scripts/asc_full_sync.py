#!/usr/bin/env python3
"""Complete end-to-end App Store Connect sync & submission for PureScan (com.yanghe.purescan)."""
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


def get_all_territories() -> list[str]:
    st, res = asc("GET", "/v1/territories?limit=200")
    if st == 200 and isinstance(res, dict):
        return [t["id"] for t in res.get("data", [])]
    return ["USA", "CHN"]


def find_price_point(endpoint: str, target: float) -> Optional[str]:
    next_url: Optional[str] = endpoint
    best_id, best_diff = None, 99999.0
    for _ in range(6):
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


def upload_binary_asset(reserve_ep: str, commit_ep: str, rtype: str, rel_key: str, rel_type: str, rel_id: str, png: Path) -> None:
    raw = png.read_bytes()
    md5 = hashlib.md5(raw).hexdigest()
    st, res = asc("POST", reserve_ep, {
        "data": {
            "type": rtype,
            "attributes": {"fileSize": len(raw), "fileName": png.name},
            "relationships": {rel_key: {"data": {"type": rel_type, "id": rel_id}}},
        }
    })
    if st not in (200, 201) or not isinstance(res, dict):
        print(f"    ! Reserve failed ({png.name}): {st} {res}")
        return
    aid = res["data"]["id"]
    for op in res["data"]["attributes"].get("uploadOperations", []):
        chunk = raw[op["offset"] : op["offset"] + op["length"]]
        hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        urllib.request.urlopen(urllib.request.Request(op["url"], data=chunk, headers=hdrs, method=op["method"]), timeout=60).read()
    st_c, _ = asc("PATCH", f"{commit_ep}/{aid}", {
        "data": {"type": rtype, "id": aid, "attributes": {"uploaded": True, "sourceFileChecksum": md5}}
    })
    print(f"    ✓ Uploaded {png.name} ({rtype}) -> {st_c}")


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
    if set_id:
        _, existing = asc("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")
        exist_items = existing.get("data", []) if isinstance(existing, dict) else []
        if len(exist_items) == len(pngs):
            print(f"    • {display_type} already has {len(exist_items)} shots, skipping.")
            return
        for item in exist_items:
            asc("DELETE", f"/v1/appScreenshots/{item['id']}")
    else:
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
        for png in pngs:
            upload_binary_asset("/v1/appScreenshots", "/v1/appScreenshots", "appScreenshots", "appScreenshotSet", "appScreenshotSets", set_id, png)


def sync_core_metadata(app_id: str, meta: dict[str, Any], territories: list[str], do_shots: bool) -> str:
    print("[1/5] Syncing Rights, Categories & Age Rating (4+)...")
    asc("PATCH", f"/v1/apps/{app_id}", {
        "data": {
            "type": "apps", "id": app_id,
            "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT", "primaryLocale": "zh-Hans"},
        }
    })
    _, infos = asc("GET", f"/v1/apps/{app_id}/appInfos")
    info_id = infos["data"][0]["id"]
    st_cat, _ = asc("PATCH", f"/v1/appInfos/{info_id}", {
        "data": {
            "type": "appInfos", "id": info_id,
            "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": meta["primaryCategory"]}},
                "secondaryCategory": {"data": {"type": "appCategories", "id": meta["secondaryCategory"]}},
            },
        }
    })
    print(f"  ✓ Categories ({meta['primaryCategory']} / {meta['secondaryCategory']}) -> {st_cat}")

    _, age_res = asc("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    if isinstance(age_res, dict) and age_res.get("data"):
        age_id = age_res["data"]["id"]
        st_age, res_age = asc("PATCH", f"/v1/ageRatingDeclarations/{age_id}", {
            "data": {
                "type": "ageRatingDeclarations", "id": age_id,
                "attributes": {
                    "advertising": False,
                    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
                    "contests": "NONE",
                    "gambling": False,
                    "gamblingSimulated": "NONE",
                    "gunsOrOtherWeapons": "NONE",
                    "healthOrWellnessTopics": False,
                    "kidsAgeBand": None,
                    "lootBox": False,
                    "medicalOrTreatmentInformation": "NONE",
                    "messagingAndChat": False,
                    "parentalControls": False,
                    "profanityOrCrudeHumor": "NONE",
                    "ageAssurance": False,
                    "sexualContentGraphicAndNudity": "NONE",
                    "sexualContentOrNudity": "NONE",
                    "socialMedia": False,
                    "socialMediaAgeRestricted": False,
                    "horrorOrFearThemes": "NONE",
                    "matureOrSuggestiveThemes": "NONE",
                    "unrestrictedWebAccess": False,
                    "userGeneratedContent": False,
                    "violenceCartoonOrFantasy": "NONE",
                    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
                    "violenceRealistic": "NONE",
                },
            }
        })
        print(f"  ✓ Age rating (4+) -> {st_age}")
        if st_age not in (200, 204):
            print("   ", res_age)

    print("[2/5] Setting Global Availability & Free Base Price...")
    st_av, _ = asc("GET", f"/v2/appAvailabilities/{app_id}")
    if st_av == 404:
        st_p, res_p = asc("POST", "/v2/appAvailabilities", {
            "data": {
                "type": "appAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{ta-{t}}}"} for t in territories]},
                },
            },
            "included": [
                {
                    "type": "territoryAvailabilities",
                    "id": f"${{ta-{t}}}",
                    "attributes": {"available": True, "releaseDate": None, "preOrderEnabled": False},
                    "relationships": {"territory": {"data": {"type": "territories", "id": t}}},
                }
                for t in territories
            ],
        })
        print(f"  ✓ Availability ({len(territories)} territories) -> {st_p}")
        if st_p not in (200, 201):
            print("   ", res_p)

    usa_pp = find_price_point(f"/v1/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=50", 0.0)
    chn_pp = find_price_point(f"/v1/apps/{app_id}/appPricePoints?filter[territory]=CHN&limit=50", 0.0)
    if usa_pp:
        mrefs = [{"type": "appPrices", "id": "${p-usa}"}]
        incs = [{"type": "appPrices", "id": "${p-usa}", "attributes": {"startDate": None}, "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": usa_pp}}}}]
        if chn_pp:
            mrefs.append({"type": "appPrices", "id": "${p-chn}"})
            incs.append({"type": "appPrices", "id": "${p-chn}", "attributes": {"startDate": None}, "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": chn_pp}}}})
        st_ps, _ = asc("POST", "/v1/appPriceSchedules", {
            "data": {
                "type": "appPriceSchedules",
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": mrefs},
                },
            },
            "included": incs,
        })
        print(f"  ✓ Base Price FREE -> {st_ps}")

    print("[3/5] Syncing CN + EN Metadata, Screenshots & Review Info...")
    _, vers = asc("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS")
    ver_id = vers["data"][0]["id"]
    asc("PATCH", f"/v1/appStoreVersions/{ver_id}", {
        "data": {"type": "appStoreVersions", "id": ver_id, "attributes": {"versionString": "1.0.0", "copyright": meta["copyright"], "releaseType": "AFTER_APPROVAL"}}
    })

    _, info_locs = asc("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")
    imap = {x["attributes"]["locale"]: x["id"] for x in info_locs.get("data", [])}
    _, ver_locs = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations?limit=50")
    vmap = {x["attributes"]["locale"]: x["id"] for x in ver_locs.get("data", [])}

    for loc, data in meta["localizations"].items():
        iattrs = {"name": data["name"], "subtitle": data["subtitle"], "privacyPolicyUrl": meta["urls"]["privacy"]}
        if loc in imap:
            asc("PATCH", f"/v1/appInfoLocalizations/{imap[loc]}", {"data": {"type": "appInfoLocalizations", "id": imap[loc], "attributes": iattrs}})
        else:
            asc("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": {"locale": loc, **iattrs}, "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}})

        vattrs = {
            "description": data["description"],
            "keywords": data["keywords"],
            "promotionalText": data["promotionalText"],
            "supportUrl": meta["urls"]["support"],
            "marketingUrl": meta["urls"]["marketing"],
        }
        if loc in vmap:
            vloc_id = vmap[loc]
            st_vl, res_vl = asc("PATCH", f"/v1/appStoreVersionLocalizations/{vloc_id}", {"data": {"type": "appStoreVersionLocalizations", "id": vloc_id, "attributes": vattrs}})
            if st_vl not in (200, 204):
                print(f"  ! PATCH vloc {loc} failed ({st_vl}): {res_vl}")
        else:
            st_vl, c = asc("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": {"locale": loc, **vattrs}, "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}}})
            if st_vl not in (200, 201) or not isinstance(c, dict) or "data" not in c:
                print(f"  ! POST vloc {loc} failed ({st_vl}): {c}")
                vloc_id = None
            else:
                vloc_id = c["data"]["id"]
        print(f"  ✓ Localization {loc} synced")
        if do_shots and vloc_id:
            sync_shots(vloc_id, "APP_IPHONE_65", SHOT_ROOT / loc / "iphone65")
            sync_shots(vloc_id, "APP_IPAD_PRO_3GEN_129", SHOT_ROOT / loc / "ipad13")

    review_notes = (
        "PureScan (配料照妖镜) is a 100% offline, on-device ingredient label scanner powered by Apple Vision OCR and a deterministic local rule database (zero generative AI / zero AIGC / zero cloud uploads / zero login required).\n\n"
        "How to test quickly without physical snack packaging:\n"
        "1. On the Scan tab, tap 'Try Live Demo Scan' or any of the 8 built-in real-world label samples (Bakery Toast, Plain Yogurt, Gout Instant Ramen, Pet Food, Skincare Cream) to view the instant scored inspection report, highlighted ingredients, and shareable receipt poster.\n"
        "2. Tap the VS PK tab to test side-by-side supermarket product comparison and preset showdowns.\n"
        "3. Tap the Radar tab to toggle personalized radars (stacking 2+ specialized radars or exporting HD VS posters presents the StoreKit 2 Pro Paywall with Monthly, Annual with 3-day free trial, Lifetime pay-once, Restore Purchases, Privacy Policy & EULA links, and a non-hostile free exit)."
    )
    rattrs = {
        "contactFirstName": "Yang",
        "contactLastName": "He",
        "contactPhone": "+86 196 3394 8182",
        "contactEmail": "a3152557994@gmail.com",
        "demoAccountRequired": False,
        "notes": review_notes,
    }
    st_r, res_r = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreReviewDetail")
    if st_r == 200 and isinstance(res_r, dict) and res_r.get("data"):
        rd_id = res_r["data"]["id"]
        asc("PATCH", f"/v1/appStoreReviewDetails/{rd_id}", {"data": {"type": "appStoreReviewDetails", "id": rd_id, "attributes": rattrs}})
    else:
        asc("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": rattrs, "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}}})
    print("  ✓ App Review Details saved")
    return ver_id


def sync_all_iaps(app_id: str, territories: list[str]) -> None:
    print("[4/5] Syncing Lifetime IAP & Monthly/Yearly Subscriptions (+ 3-Day Free Trial)...")
    review_shot = SHOT_ROOT / "zh-Hans" / "iphone65" / "02_result.png"

    # A. Non-Consumable Lifetime (¥28 / $14.99)
    _, iap_list = asc("GET", f"/v1/apps/{app_id}/inAppPurchasesV2?limit=50")
    emap = {x["attributes"]["productId"]: x["id"] for x in iap_list.get("data", []) if isinstance(iap_list, dict)}
    life_pid = "com.yanghe.purescan.pro.lifetime"
    life_id = emap.get(life_pid)
    if not life_id:
        st, created = asc("POST", "/v2/inAppPurchases", {
            "data": {
                "type": "inAppPurchases",
                "attributes": {
                    "name": "PureScan Pro Lifetime",
                    "productId": life_pid,
                    "inAppPurchaseType": "NON_CONSUMABLE",
                    "familySharable": True,
                    "reviewNote": "Presented inside PaywallView when tapping Upgrade, stacking 2+ specialized radars, or exporting HD VS cards.",
                },
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        })
        if st not in (200, 201):
            print("  ! Failed creating lifetime IAP:", st, created)
        else:
            life_id = created["data"]["id"]
            print(f"  + Created Lifetime IAP ({life_id})")

    if life_id:
        _, cur_l = asc("GET", f"/v2/inAppPurchases/{life_id}/inAppPurchaseLocalizations")
        ex_l = {x["attributes"]["locale"]: x["id"] for x in cur_l.get("data", [])}
        for loc, attrs in {
            "zh-Hans": {"name": "配料照妖镜永久买断 Pro", "description": "一次买断终身解锁全部6大忌口雷达、双品PK与无限扫描"},
            "en-US": {"name": "PureScan Pro Lifetime", "description": "Pay once to own all 6 radars, VS PK & unlimited scans forever"},
        }.items():
            if loc in ex_l:
                asc("PATCH", f"/v1/inAppPurchaseLocalizations/{ex_l[loc]}", {"data": {"type": "inAppPurchaseLocalizations", "id": ex_l[loc], "attributes": attrs}})
            else:
                asc("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations", "attributes": {"locale": loc, **attrs}, "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": life_id}}}}})

        st_ia, _ = asc("GET", f"/v2/inAppPurchases/{life_id}/inAppPurchaseAvailability")
        if st_ia == 404:
            asc("POST", "/v1/inAppPurchaseAvailabilities", {
                "data": {
                    "type": "inAppPurchaseAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": life_id}},
                        "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]},
                    },
                }
            })

        usa_pp = find_price_point(f"/v2/inAppPurchases/{life_id}/pricePoints?filter[territory]=USA&limit=200", 14.99)
        chn_pp = find_price_point(f"/v2/inAppPurchases/{life_id}/pricePoints?filter[territory]=CHN&limit=200", 28.0)
        if usa_pp:
            mrefs = [{"type": "inAppPurchasePrices", "id": "${lp-usa}"}]
            incs = [{"type": "inAppPurchasePrices", "id": "${lp-usa}", "attributes": {"startDate": None}, "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": life_id}}, "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": usa_pp}}}}]
            if chn_pp:
                mrefs.append({"type": "inAppPurchasePrices", "id": "${lp-chn}"})
                incs.append({"type": "inAppPurchasePrices", "id": "${lp-chn}", "attributes": {"startDate": None}, "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": life_id}}, "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": chn_pp}}}})
            st_ip, _ = asc("POST", "/v1/inAppPurchasePriceSchedules", {
                "data": {"type": "inAppPurchasePriceSchedules", "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": life_id}}, "baseTerritory": {"data": {"type": "territories", "id": "USA"}}, "manualPrices": {"data": mrefs}}},
                "included": incs,
            })
            print(f"  ✓ Lifetime price ($14.99 / ¥28) -> {st_ip}")

        st_is, res_is = asc("GET", f"/v2/inAppPurchases/{life_id}/appStoreReviewScreenshot")
        if (st_is == 404 or not (isinstance(res_is, dict) and res_is.get("data"))) and review_shot.exists():
            upload_binary_asset("/v1/inAppPurchaseAppStoreReviewScreenshots", "/v1/inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", "inAppPurchases", life_id, review_shot)

    # B. Subscription Group + Yearly ($9.99 / ¥18 + 3-Day Free Trial) + Monthly ($1.99 / ¥6)
    _, sgs = asc("GET", f"/v1/apps/{app_id}/subscriptionGroups")
    if sgs.get("data"):
        sg_id = sgs["data"][0]["id"]
    else:
        st_sg, res_sg = asc("POST", "/v1/subscriptionGroups", {
            "data": {"type": "subscriptionGroups", "attributes": {"referenceName": "PureScan Pro"}, "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}
        })
        sg_id = res_sg["data"]["id"]
        print(f"  + Created Subscription Group ({sg_id}) -> {st_sg}")

    _, cur_sgl = asc("GET", f"/v1/subscriptionGroups/{sg_id}/subscriptionGroupLocalizations")
    ex_sgl = {x["attributes"]["locale"]: x["id"] for x in cur_sgl.get("data", [])}
    for loc, attrs in {
        "zh-Hans": {"name": "配料照妖镜 Pro", "customAppName": "配料照妖镜"},
        "en-US": {"name": "PureScan Pro", "customAppName": "PureScan"},
    }.items():
        if loc not in ex_sgl:
            asc("POST", "/v1/subscriptionGroupLocalizations", {
                "data": {"type": "subscriptionGroupLocalizations", "attributes": {"locale": loc, **attrs}, "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": sg_id}}}}
            })

    _, subs_res = asc("GET", f"/v1/subscriptionGroups/{sg_id}/subscriptions")
    sub_map = {x["attributes"]["productId"]: x["id"] for x in subs_res.get("data", [])}

    sub_specs = [
        {
            "pid": "com.yanghe.purescan.pro.yearly",
            "ref": "PureScan Pro Annual",
            "period": "ONE_YEAR",
            "groupLevel": 1,
            "usaPrice": 9.99,
            "chnPrice": 18.0,
            "trial3d": True,
            "locs": {
                "zh-Hans": {"name": "配料照妖镜年度会员", "description": "含3天免费试用，全年解锁全部6大忌口雷达与双品PK"},
                "en-US": {"name": "PureScan Pro Annual", "description": "3-day free trial, annual access to all 6 radars & VS PK"},
            },
        },
        {
            "pid": "com.yanghe.purescan.pro.monthly",
            "ref": "PureScan Pro Monthly",
            "period": "ONE_MONTH",
            "groupLevel": 2,
            "usaPrice": 1.99,
            "chnPrice": 6.0,
            "trial3d": False,
            "locs": {
                "zh-Hans": {"name": "配料照妖镜月度会员", "description": "按月解锁全部6大忌口雷达、双品PK与无限离线扫描"},
                "en-US": {"name": "PureScan Pro Monthly", "description": "Monthly access to all 6 radars, VS PK & unlimited scans"},
            },
        },
    ]

    for spec in sub_specs:
        sid = sub_map.get(spec["pid"])
        if not sid:
            st_s, res_s = asc("POST", "/v1/subscriptions", {
                "data": {
                    "type": "subscriptions",
                    "attributes": {
                        "name": spec["ref"],
                        "productId": spec["pid"],
                        "subscriptionPeriod": spec["period"],
                        "groupLevel": spec["groupLevel"],
                        "familySharable": True,
                        "reviewNote": "Presented inside PaywallView with clear price, duration, Restore Purchases, Privacy Policy & EULA.",
                    },
                    "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": sg_id}}},
                }
            })
            if st_s not in (200, 201):
                print(f"  ! Failed creating sub {spec['pid']}: {st_s} {res_s}")
                continue
            sid = res_s["data"]["id"]
            print(f"  + Created Subscription {spec['pid']} ({sid})")

        _, cur_sl = asc("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations")
        ex_sl = {x["attributes"]["locale"]: x["id"] for x in cur_sl.get("data", [])}
        for loc, attrs in spec["locs"].items():
            if loc in ex_sl:
                asc("PATCH", f"/v1/subscriptionLocalizations/{ex_sl[loc]}", {"data": {"type": "subscriptionLocalizations", "id": ex_sl[loc], "attributes": attrs}})
            else:
                asc("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations", "attributes": {"locale": loc, **attrs}, "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})

        st_sa, _ = asc("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability")
        if st_sa == 404:
            asc("POST", "/v1/subscriptionAvailabilities", {
                "data": {
                    "type": "subscriptionAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]},
                    },
                }
            })

        _, cur_sp = asc("GET", f"/v1/subscriptions/{sid}/prices?limit=200")
        if len(cur_sp.get("data", []) if isinstance(cur_sp, dict) else []) < 5:
            usa_sp = find_price_point(f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=USA&limit=200", spec["usaPrice"])
            chn_sp = find_price_point(f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=CHN&limit=200", spec["chnPrice"])
            if usa_sp:
                eq_url: Optional[str] = f"/v1/subscriptionPricePoints/{usa_sp}/equalizations?limit=200&include=territory"
                ter_pp: dict[str, str] = {"USA": usa_sp}
                while eq_url:
                    st_eq, eq_res = asc("GET", eq_url)
                    if st_eq != 200 or not isinstance(eq_res, dict):
                        break
                    for item in eq_res.get("data", []):
                        tid = item.get("relationships", {}).get("territory", {}).get("data", {}).get("id")
                        if tid:
                            ter_pp[tid] = item["id"]
                    eq_url = eq_res.get("links", {}).get("next")
                if chn_sp:
                    ter_pp["CHN"] = chn_sp
                ok_cnt = 0
                for tid, pp_id in ter_pp.items():
                    st_p, _ = asc("POST", "/v1/subscriptionPrices", {
                        "data": {
                            "type": "subscriptionPrices",
                            "attributes": {"preserveCurrentPrice": False, "startDate": None},
                            "relationships": {
                                "subscription": {"data": {"type": "subscriptions", "id": sid}},
                                "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp_id}},
                            },
                        }
                    })
                    if st_p in (200, 201):
                        ok_cnt += 1
                print(f"  ✓ Set {ok_cnt}/{len(ter_pp)} territory prices for {spec['pid']}")

        if spec["trial3d"]:
            _, cur_io = asc("GET", f"/v1/subscriptions/{sid}/introductoryOffers?limit=10")
            if not cur_io.get("data"):
                st_o, _ = asc("POST", "/v1/subscriptionIntroductoryOffers", {
                    "data": {
                        "type": "subscriptionIntroductoryOffers",
                        "attributes": {"duration": "THREE_DAYS", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1, "startDate": None, "endDate": None},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}},
                    }
                })
                if st_o in (200, 201):
                    print(f"  ✓ Added 3-Day Free Trial (global) to {spec['pid']}")
                else:
                    ok_t = 0
                    for tid in ["USA", "CHN", "GBR", "CAN", "AUS", "JPN", "HKG", "TWN", "SGP"]:
                        st_t, _ = asc("POST", "/v1/subscriptionIntroductoryOffers", {
                            "data": {
                                "type": "subscriptionIntroductoryOffers",
                                "attributes": {"duration": "THREE_DAYS", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1, "startDate": None, "endDate": None},
                                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}, "territory": {"data": {"type": "territories", "id": tid}}},
                            }
                        })
                        if st_t in (200, 201):
                            ok_t += 1
                    print(f"  ✓ Added 3-Day Free Trial to {ok_t} key territories on {spec['pid']}")

        st_ss, res_ss = asc("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot")
        if (st_ss == 404 or not (isinstance(res_ss, dict) and res_ss.get("data"))) and review_shot.exists():
            upload_binary_asset("/v1/subscriptionAppStoreReviewScreenshots", "/v1/subscriptionAppStoreReviewScreenshots", "subscriptionAppStoreReviewScreenshots", "subscription", "subscriptions", sid, review_shot)


def wait_and_attach_build(app_id: str, ver_id: str, wait_secs: int = 300) -> bool:
    print("[5/5] Checking/waiting for VALID build to attach...")
    deadline = time.time() + wait_secs
    while True:
        _, blds = asc("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5")
        data = blds.get("data", []) if isinstance(blds, dict) else []
        valid = next((b for b in data if b["attributes"].get("processingState") == "VALID"), None)
        if valid:
            st, res = asc("PATCH", f"/v1/appStoreVersions/{ver_id}/relationships/build", {"data": {"type": "builds", "id": valid["id"]}})
            print(f"  ✓ Attached VALID build {valid['attributes']['version']} ({valid['id']}) -> {st}")
            return st in (200, 204)
        states = [(b["attributes"].get("version"), b["attributes"].get("processingState")) for b in data]
        print(f"  ... builds so far: {states}")
        if time.time() >= deadline:
            return False
        time.sleep(15)


def submit_for_review(app_id: str, ver_id: str) -> None:
    print("[SUBMIT] Submitting PureScan 1.0.0 to Apple App Review...")
    st_rs, res_rs = asc("POST", "/v1/reviewSubmissions", {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    })
    if st_rs not in (200, 201):
        print("  ! reviewSubmissions create returned:", st_rs, res_rs)
        return
    rs_id = res_rs["data"]["id"]
    st_i, res_i = asc("POST", "/v1/reviewSubmissionItems", {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rs_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}},
            },
        }
    })
    print(f"  + Added version item -> {st_i}")
    if st_i not in (200, 201):
        print("   ", res_i)
        return
    st_sub, res_sub = asc("PATCH", f"/v1/reviewSubmissions/{rs_id}", {
        "data": {"type": "reviewSubmissions", "id": rs_id, "attributes": {"submitted": True}}
    })
    print(f"  🚀 Submitted reviewSubmission ({rs_id}) -> {st_sub}")
    if st_sub not in (200, 201):
        print("   ", res_sub)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upload-ipa", action="store_true")
    parser.add_argument("--screenshots", action="store_true")
    parser.add_argument("--submit", action="store_true")
    args = parser.parse_args()

    meta = json.loads(META_PATH.read_text(encoding="utf-8"))
    st, res = asc("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not res.get("data"):
        print(f"ERROR: App shell {BUNDLE_ID} not found in ASC.")
        return 1
    app_id = res["data"][0]["id"]
    print(f"✅ Found PureScan App ID: {app_id}")

    if args.upload_ipa:
        print(f"🚀 Uploading {IPA_PATH} via xcrun altool...")
        subprocess.run([
            "xcrun", "altool", "--upload-app", "-t", "ios",
            "-f", str(IPA_PATH), "--apiKey", KEY_ID, "--apiIssuer", ISSUER_ID,
        ], check=True)
        print("  ✓ IPA upload accepted by Apple!")

    territories = get_all_territories()
    ver_id = sync_core_metadata(app_id, meta, territories, do_shots=args.screenshots)
    sync_all_iaps(app_id, territories)

    if args.submit:
        attached = wait_and_attach_build(app_id, ver_id, wait_secs=240)
        if attached:
            submit_for_review(app_id, ver_id)
        else:
            print("  ! Build still processing; re-run with --submit in 2 minutes once Apple finishes processing.")

    _, iaps = asc("GET", f"/v1/apps/{app_id}/inAppPurchasesV2")
    for x in iaps.get("data", []):
        print("  IAP:", x["attributes"]["productId"], "->", x["attributes"]["state"])
    _, sgs = asc("GET", f"/v1/apps/{app_id}/subscriptionGroups")
    for sg in sgs.get("data", []):
        _, subs = asc("GET", f"/v1/subscriptionGroups/{sg['id']}/subscriptions")
        for x in subs.get("data", []):
            print("  Sub:", x["attributes"]["productId"], "->", x["attributes"]["state"])
    _, vers = asc("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&include=build")
    v = vers["data"][0]
    print("  Version Status:", v["attributes"]["versionString"], v["attributes"]["appStoreState"], "build:", v.get("relationships", {}).get("build", {}).get("data"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
