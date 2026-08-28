#!/usr/bin/env python3
"""把 tools/asc/app_metadata.json 的元数据 + AppStoreScreenshots 的截图写入 App Store Connect。

用法:
  python3 tools/asc/asc_upload.py --dump                     # 只读:打印线上现有各语言元数据
  python3 tools/asc/asc_upload.py --dry-run                  # 预览要写什么,不写
  python3 tools/asc/asc_upload.py --locales ja,ko,zh-Hant,es # 只写这几个语言(推荐:不碰已上线的 en/zh-Hans)
  python3 tools/asc/asc_upload.py --locales ja --screenshots  # 元数据 + 截图
  python3 tools/asc/asc_upload.py --locales ja --iap          # 元数据 + 内购显示名/描述
  python3 tools/asc/asc_upload.py                            # 全部语言的元数据

前置:
  1) ASC 协议在有效期内(网页「协议、税务和银行业务」),否则一切请求 403。
  2) App 记录已存在(官方 API 不能新建 App)。
  3) 密钥角色需 App 管理(App Manager)及以上。
  4) 新语言要先在 ASC 该 App 的「App 信息 → 本地化」里可用——本脚本 POST
     appInfoLocalizations 时会自动创建,无需网页手动添加。

凭据只从环境变量读(或 ~/.appstoreconnect/env.sh):ASC_ISSUER_ID / ASC_KEY_ID / ASC_KEY_PATH。
"""
import argparse
import base64
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request


# --- shared ASC credentials (~/.appstoreconnect/env.sh), auto-loaded when env vars are unset ---
def _load_shared_asc_env():
    path = os.path.expanduser("~/.appstoreconnect/env.sh")
    if not os.path.exists(path):
        return
    for line in open(path):
        m = re.match(r'\s*export\s+(ASC_\w+)="?([^"\n]+)"?', line)
        if m and m.group(1) not in os.environ:
            os.environ[m.group(1)] = os.path.expandvars(m.group(2))


_load_shared_asc_env()

from cryptography.hazmat.primitives import hashes, serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric import ec  # noqa: E402
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature  # noqa: E402

# ============================== 凭证与常量 ==============================

ISSUER_ID = os.environ.get("ASC_ISSUER_ID") or sys.exit("缺少环境变量 ASC_ISSUER_ID")
KEY_ID = os.environ.get("ASC_KEY_ID") or sys.exit("缺少环境变量 ASC_KEY_ID")
KEY_PATH = os.environ.get("ASC_KEY_PATH") or sys.exit("缺少环境变量 ASC_KEY_PATH")

BUNDLE_ID = "greenCross.NoDiary"
API = "https://api.appstoreconnect.apple.com"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SHOTS = os.path.join(REPO, "AppStoreScreenshots")

# 元数据单一来源。下划线开头的是非语言块(_note / _iap),不当作 locale 处理。
_RAW = json.load(open(os.path.join(HERE, "app_metadata.json")))
METADATA = {k: v for k, v in _RAW.items() if not k.startswith("_")}
IAP = _RAW.get("_iap") or {}

# ASC locale → AppStoreScreenshots 下的子目录(加过标语的成品图)
SHOT_DIRS = {
    "en-US": "en-captioned",
    "zh-Hans": "zh-Hans-captioned",
    "zh-Hant": "zh-Hant-captioned",
    "ja": "ja-captioned",
    "ko": "ko-captioned",
    "es-ES": "es-captioned",
}
# 只管 6.5 吋这一档。1284×2778 对 APP_IPHONE_65 和 APP_IPHONE_67 都合法,这里跟已经上传过的
# en-US / zh-Hans 保持一致用 65 —— 传成 67 会多出一个内容重复的截图组,而不是替换原有的那组。
# iPad 以及旧的 5.5/5.8 吋截图组不在本脚本管理范围内,不会被删。
DISPLAY_TYPES = {"APP_IPHONE_65": ""}

# ============================== API 基础 ==============================


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


_token_cache = {"token": None, "exp": 0}


def token() -> str:
    if _token_cache["token"] and time.time() < _token_cache["exp"] - 60:
        return _token_cache["token"]
    with open(KEY_PATH, "rb") as f:
        priv = serialization.load_pem_private_key(f.read(), password=None)
    now = int(time.time())
    signing = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"},
                                separators=(",", ":")).encode()) \
        + "." + b64url(json.dumps({"iss": ISSUER_ID, "iat": now, "exp": now + 1200,
                                   "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode())
    der = priv.sign(signing.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der)
    tok = signing + "." + b64url(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    _token_cache.update(token=tok, exp=now + 1200)
    return tok


# 截图上传是「先删后传」,一次网络抖动就能把某个语言的截图组留在半残状态
# (旧图已删、新图没传完)。所以瞬时故障必须重试,而不是直接退出。
RETRIABLE_STATUS = {408, 429, 500, 502, 503, 504}
MAX_ATTEMPTS = 4


def request(method: str, path: str, body=None, raw_url=None, headers=None, data_bytes=None):
    url = raw_url or (API + path)
    if body is not None:
        data_bytes = json.dumps(body).encode()

    last = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        # 上传分块走 Apple 资产存储的预签名 URL:不能附带 ASC Bearer(与 X-Amz 签名冲突 → 400)
        h = {} if (raw_url and not raw_url.startswith(API)) else {"Authorization": f"Bearer {token()}"}
        if body is not None:
            h["Content-Type"] = "application/json"
        if headers:
            h.update(headers)
        req = urllib.request.Request(url, data=data_bytes, headers=h, method=method)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                text = resp.read()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode()[:600]
            if e.code in RETRIABLE_STATUS and attempt < MAX_ATTEMPTS:
                last = f"HTTP {e.code}"
            else:
                raise SystemExit(f"HTTP {e.code} {method} {url}\n{detail}")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            # SSL EOF / 连接重置 / DNS 抖动都归到这里
            if attempt >= MAX_ATTEMPTS:
                raise SystemExit(f"{method} {url} 连续 {MAX_ATTEMPTS} 次失败: {e}")
            last = str(e)
        wait = 2 ** attempt
        print(f"  ! {method} {url.split('?')[0][-60:]} 失败({last}),{wait}s 后重试 "
              f"({attempt}/{MAX_ATTEMPTS - 1})")
        time.sleep(wait)


def get(path):
    return request("GET", path)


def get_all(path):
    out, url = [], API + path
    while url:
        page = request("GET", "", raw_url=url)
        out += page.get("data", [])
        url = page.get("links", {}).get("next")
    return out


# ============================== 各步骤 ==============================


def marketing_version():
    """新版本号唯一来源 Version.xcconfig(写死会在上架后撞 409 重复)。"""
    for line in open(os.path.join(REPO, "Version.xcconfig")):
        m = re.match(r"\s*MARKETING_VERSION\s*=\s*([\d.]+)", line)
        if m:
            return m.group(1)
    raise SystemExit("Version.xcconfig 里找不到 MARKETING_VERSION")


def find_app():
    data = get(f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not data:
        raise SystemExit(f"未找到 {BUNDLE_ID} 的 App 记录(官方 API 不能新建 App)。")
    return data[0]["id"]


EDITABLE_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
                   "METADATA_REJECTED", "WAITING_FOR_REVIEW", "INVALID_BINARY"}


def editable_version(app_id, create=True):
    versions = get(f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    for v in versions:
        a = v["attributes"]
        if a["appStoreState"] in EDITABLE_STATES or a.get("appVersionState") in EDITABLE_STATES:
            return v["id"], a["versionString"]
    if not create:
        return None, None
    version = marketing_version()
    used = {v["attributes"]["versionString"] for v in versions}
    if version in used:
        raise SystemExit(
            f"没有可编辑版本,而 Version.xcconfig 的 MARKETING_VERSION = {version} 已经用过了。\n"
            f"  把 MARKETING_VERSION 升到下一个版本号(或在 ASC 网页手工建一个新版本记录),再重跑。\n"
            f"  提示:App 信息级字段(name / subtitle / privacyPolicyUrl)不需要版本记录,\n"
            f"  但描述 / 关键词 / 宣传文本 / 更新说明 / 截图都需要。")
    body = {"data": {"type": "appStoreVersions",
                     "attributes": {"platform": "IOS", "versionString": version},
                     "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    v = request("POST", "/v1/appStoreVersions", body)["data"]
    print(f"已创建新版本记录 v{v['attributes']['versionString']}(PREPARE_FOR_SUBMISSION)")
    return v["id"], v["attributes"]["versionString"]


def editable_app_info(app_id):
    infos = get(f"/v1/apps/{app_id}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("appStoreState") in
                 ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "METADATA_REJECTED")), infos[0])
    return info["id"]


def dump(app_id):
    """只读:打印线上每个语言的元数据,方便对照后再决定写什么。"""
    info_id = editable_app_info(app_id)
    infos = {l["attributes"]["locale"]: l["attributes"]
             for l in get_all(f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")}
    version_id, version = editable_version(app_id, create=False)
    vlocs = {}
    if version_id:
        vlocs = {l["attributes"]["locale"]: l["attributes"] for l in get_all(
            f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")}
        print(f"可编辑版本: v{version}")
    else:
        print("没有可编辑版本(线上版本已发布)——版本级字段无法读取/写入,先在 ASC 建新版本")
    for locale in sorted(set(infos) | set(vlocs)):
        i, v = infos.get(locale, {}), vlocs.get(locale, {})
        print(f"\n--- {locale} ---")
        print(f"  name      : {i.get('name')}")
        print(f"  subtitle  : {i.get('subtitle')}")
        print(f"  privacy   : {i.get('privacyPolicyUrl')}")
        print(f"  keywords  : {v.get('keywords')}")
        print(f"  promo     : {(v.get('promotionalText') or '')[:120]}")
        print(f"  support   : {v.get('supportUrl')}  marketing: {v.get('marketingUrl')}")
        print(f"  desc      : {len(v.get('description') or '')} 字")
        print(f"  whatsNew  : {len(v.get('whatsNew') or '')} 字")
    if IAP:
        found = [p for p in get_all(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=50")
                 if p["attributes"].get("productId") == IAP["productId"]]
        if found:
            print(f"\n=== 内购 {IAP['productId']} "
                  f"(state={found[0]['attributes'].get('state')}) ===")
            for l in sorted(get_all(f"/v2/inAppPurchases/{found[0]['id']}"
                                    f"/inAppPurchaseLocalizations?limit=50"),
                            key=lambda x: x["attributes"]["locale"]):
                la = l["attributes"]
                print(f"  {la['locale']:8} {la.get('name')} — {la.get('description')} "
                      f"[{la.get('state')}]")


def sync_app_info(app_id, locales, dry):
    info_id = editable_app_info(app_id)
    existing = {l["attributes"]["locale"]: l["id"]
                for l in get_all(f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")}
    for locale in locales:
        meta = METADATA[locale]
        attrs = {"name": meta["name"], "subtitle": meta["subtitle"],
                 "privacyPolicyUrl": meta["privacyPolicyUrl"]}
        verb = "PATCH" if locale in existing else "POST"
        if dry:
            print(f"[dry] appInfo {locale} ({verb}): {attrs['name']} / {attrs['subtitle']}")
            continue
        if locale in existing:
            request("PATCH", f"/v1/appInfoLocalizations/{existing[locale]}",
                    {"data": {"type": "appInfoLocalizations", "id": existing[locale],
                              "attributes": attrs}})
        else:
            request("POST", "/v1/appInfoLocalizations",
                    {"data": {"type": "appInfoLocalizations",
                              "attributes": {"locale": locale, **attrs},
                              "relationships": {"appInfo": {
                                  "data": {"type": "appInfos", "id": info_id}}}}})
        print(f"appInfo {locale} ✓ ({verb})")


def sync_version_localizations(version_id, locales, dry):
    existing = {} if version_id is None else {
        l["attributes"]["locale"]: l["id"] for l in get_all(
            f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")}
    loc_ids = {}
    for locale in locales:
        meta = METADATA[locale]
        attrs = {"description": meta["description"], "keywords": meta["keywords"],
                 "promotionalText": meta["promotionalText"],
                 "supportUrl": meta["supportUrl"], "marketingUrl": meta["marketingUrl"]}
        # 首版(1.0)填 whatsNew 会被 ASC 拒——仅在有值时写
        if meta.get("whatsNew"):
            attrs["whatsNew"] = meta["whatsNew"]
        verb = "PATCH" if locale in existing else "POST"
        if dry:
            print(f"[dry] versionLoc {locale} ({verb}): 描述 {len(meta['description'])} 字 · "
                  f"关键词 {len(meta['keywords'])} 字符 · "
                  f"更新说明 {len(meta.get('whatsNew') or '')} 字")
            loc_ids[locale] = existing.get(locale)
            continue
        if locale in existing:
            request("PATCH", f"/v1/appStoreVersionLocalizations/{existing[locale]}",
                    {"data": {"type": "appStoreVersionLocalizations", "id": existing[locale],
                              "attributes": attrs}})
            loc_ids[locale] = existing[locale]
        else:
            created = request("POST", "/v1/appStoreVersionLocalizations",
                              {"data": {"type": "appStoreVersionLocalizations",
                                        "attributes": {"locale": locale, **attrs},
                                        "relationships": {"appStoreVersion": {
                                            "data": {"type": "appStoreVersions",
                                                     "id": version_id}}}}})
            loc_ids[locale] = created["data"]["id"]
        print(f"versionLoc {locale} ✓ ({verb})")
    return loc_ids


def upload_screenshots(loc_ids, locales, dry):
    for locale in locales:
        folder = SHOT_DIRS.get(locale)
        loc_id = loc_ids.get(locale)
        if not folder:
            print(f"跳过截图 {locale}(SHOT_DIRS 无映射)")
            continue
        if not loc_id:
            print(f"跳过截图 {locale}(无本地化记录——先跑一次不带 --dry-run 的元数据写入)")
            continue
        sets = {s["attributes"]["screenshotDisplayType"]: s["id"] for s in get_all(
            f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=50")}
        for display_type, subdir in DISPLAY_TYPES.items():
            shot_dir = os.path.join(SHOTS, folder, subdir)
            files = sorted(f for f in os.listdir(shot_dir)
                           if f.endswith(".png")) if os.path.isdir(shot_dir) else []
            if not files:
                print(f"跳过截图 {locale} {display_type}(目录空或不存在: {shot_dir})")
                continue
            if dry:
                print(f"[dry] {locale} {display_type}: {len(files)} 张 ← {shot_dir}")
                continue
            set_id = sets.get(display_type)
            if not set_id:
                set_id = request("POST", "/v1/appScreenshotSets", {"data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {"appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]["id"]
            # 清掉旧图,保证顺序与内容确定(文件名字典序 = 展示序)
            for old in get_all(f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=50"):
                request("DELETE", f"/v1/appScreenshots/{old['id']}")
            for name in files:
                blob = open(os.path.join(shot_dir, name), "rb").read()
                reserved = request("POST", "/v1/appScreenshots", {"data": {
                    "type": "appScreenshots",
                    "attributes": {"fileName": name, "fileSize": len(blob)},
                    "relationships": {"appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
                for op in reserved["attributes"]["uploadOperations"]:
                    chunk = blob[op["offset"]: op["offset"] + op["length"]]
                    request(op["method"], "", raw_url=op["url"], data_bytes=chunk,
                            headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
                request("PATCH", f"/v1/appScreenshots/{reserved['id']}", {"data": {
                    "type": "appScreenshots", "id": reserved["id"],
                    "attributes": {"uploaded": True,
                                   "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
                print(f"  {locale}/{display_type}/{name} ✓")
            print(f"{locale} {display_type}: {len(files)} 张 ✓")


def sync_iap(app_id, locales, dry):
    """内购的显示名/描述本地化。

    走 inAppPurchasesV2:先按 productId 找到内购,再按 locale 建/改
    inAppPurchaseLocalizations。已审核通过的语言原样 PATCH 回去是无害的,新增语言会随
    下一次 App 提交一起送审——线上已批准的版本在那之前照常生效。
    """
    if not IAP:
        print("app_metadata.json 里没有 _iap 块,跳过内购")
        return
    product_id = IAP["productId"]
    found = [p for p in get_all(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=50")
             if p["attributes"].get("productId") == product_id]
    if not found:
        raise SystemExit(f"未找到内购 {product_id}(先在 ASC 网页创建)")
    iap_id = found[0]["id"]
    print(f"内购 {product_id} ({iap_id}) state={found[0]['attributes'].get('state')}")

    existing = {l["attributes"]["locale"]: l["id"] for l in get_all(
        f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations?limit=50")}
    table = IAP["localizations"]
    for locale in locales:
        meta = table.get(locale)
        if not meta:
            print(f"跳过内购 {locale}(_iap.localizations 里没有)")
            continue
        if len(meta["name"]) > 30:
            raise SystemExit(f"内购 {locale} 显示名超 30: {len(meta['name'])}")
        if len(meta["description"]) > 45:
            raise SystemExit(f"内购 {locale} 描述超 45: {len(meta['description'])}")
        attrs = {"name": meta["name"], "description": meta["description"]}
        verb = "PATCH" if locale in existing else "POST"
        if dry:
            print(f"[dry] iapLoc {locale} ({verb}): {attrs['name']} — {attrs['description']}")
            continue
        if locale in existing:
            request("PATCH", f"/v1/inAppPurchaseLocalizations/{existing[locale]}",
                    {"data": {"type": "inAppPurchaseLocalizations", "id": existing[locale],
                              "attributes": attrs}})
        else:
            request("POST", "/v1/inAppPurchaseLocalizations",
                    {"data": {"type": "inAppPurchaseLocalizations",
                              "attributes": {"locale": locale, **attrs},
                              "relationships": {"inAppPurchaseV2": {
                                  "data": {"type": "inAppPurchases", "id": iap_id}}}}})
        print(f"iapLoc {locale} ✓ ({verb})")


LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotionalText": 170,
          "description": 4000, "whatsNew": 4000}


def validate(locales):
    for locale in locales:
        if locale not in METADATA:
            raise SystemExit(f"app_metadata.json 里没有 {locale}")
        meta = METADATA[locale]
        for field, limit in LIMITS.items():
            value = meta.get(field) or ""
            if len(value) > limit:
                raise SystemExit(f"{locale} {field} 超 {limit}: {len(value)}")
        for field in ("name", "subtitle", "keywords", "description",
                      "privacyPolicyUrl", "supportUrl", "marketingUrl"):
            if not meta.get(field):
                raise SystemExit(f"{locale} 缺 {field}")
        # 关键词逗号后留空格会白占字符
        if ", " in meta["keywords"]:
            raise SystemExit(f"{locale} keywords 逗号后不要留空格(白占字符)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--dump", action="store_true", help="只读:打印线上现有元数据后退出")
    ap.add_argument("--screenshots", action="store_true", help="同时上传截图")
    ap.add_argument("--iap", action="store_true", help="同时写内购的显示名/描述本地化")
    ap.add_argument("--locales", help="只处理这些 ASC locale,逗号分隔(默认全部)")
    args = ap.parse_args()

    app_id = find_app()
    print(f"App 记录: {app_id}")

    if args.dump:
        dump(app_id)
        return

    locales = [l.strip() for l in args.locales.split(",")] if args.locales else list(METADATA)
    validate(locales)
    print("语言: " + ", ".join(locales))

    # 干跑绝不写:不新建版本记录(那是一次真实写入)
    version_id, version = editable_version(app_id, create=not args.dry_run)
    if version_id:
        print(f"可编辑版本: {version} ({version_id})")
    else:
        print(f"[dry] 目前没有可编辑版本 —— 真跑时会按 Version.xcconfig 的 "
              f"v{marketing_version()} 新建一个(若该版本号已用过则会报错退出)")

    sync_app_info(app_id, locales, args.dry_run)
    loc_ids = sync_version_localizations(version_id, locales, args.dry_run)
    if args.screenshots:
        upload_screenshots(loc_ids, locales, args.dry_run)
    if args.iap:
        sync_iap(app_id, locales, args.dry_run)
    print("完成" + ("(dry-run,未写入)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
