# tools/asc + tools/screenshots — App Store Connect 自动化

和 AquaLife / Latent / Symptio 一套写法:官方 ASC REST API(ES256 JWT),HTTP 走标准库,
只依赖 `cryptography`(见 `requirements.txt`);截图加框依赖 `pillow`。

| 脚本 | 用途 |
|---|---|
| `tools/screenshots/capture_raw.sh` | 模拟器采集原图:每语言 6 张,自动切语言/深浅色/统一状态栏 |
| `tools/screenshots/make_captioned.py` | 给原图加渐变底 + 顶部标语 + 圆角阴影,产出 1284×2778 成品 |
| `tools/asc/asc_upload.py` | 写 App 元数据(六语言名称/副标题/描述/关键词/宣传/URL)+ 上传截图 |

App:`greenCross.NoDiary`(ASC App ID `1412453660`)。

## 凭据(只从环境变量读,绝不硬编码)

脚本会自动加载 `~/.appstoreconnect/env.sh`(已存在,和其他 App 共用),里面是:

```bash
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   # ASC → 用户和访问 → 集成
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
```

密钥角色需 **App 管理(App Manager)** 及以上。`.p8` 不要放进仓库,脚本任何路径都不打印私钥。

## 六个语言

| ASC locale | Xcode 本地化 | 截图目录 | 站点页面 |
|---|---|---|---|
| `en-US` | `en` | `AppStoreScreenshots/en-captioned/` | `/nodiary/` |
| `zh-Hans` | `zh-Hans` | `zh-Hans-captioned/` | `/zh/nodiary/` |
| `zh-Hant` | `zh-Hant` | `zh-Hant-captioned/` | `/zh-Hant/nodiary/` |
| `ja` | `ja` | `ja-captioned/` | `/ja/nodiary/` |
| `ko` | `ko` | `ko-captioned/` | `/ko/nodiary/` |
| `es-ES` | `es` | `es-captioned/` | `/es/nodiary/` |

## 完整流程(加一个新语言)

```bash
pip3 install -r tools/asc/requirements.txt pillow

# 1) 采原图(Debug 构建,演示模式在 #if DEBUG 里)
./tools/screenshots/capture_raw.sh ja

# 2) 加标语 → AppStoreScreenshots/ja-captioned/
python3 tools/screenshots/make_captioned.py ja

# 3) 先只读看一眼线上现状
python3 tools/asc/asc_upload.py --dump

# 4) 预览要写什么(不写)
python3 tools/asc/asc_upload.py --locales ja --dry-run --screenshots

# 5) 真写(元数据 + 截图)
python3 tools/asc/asc_upload.py --locales ja --screenshots
```

**`--locales` 请一直带上。** 不带就会把 `app_metadata.json` 里所有六个语言都写一遍,
包括已经上线的 en-US / zh-Hans —— 那两个语言的描述在 JSON 里是线上原文,但关键词是新写的,
会覆盖 ASC 里现有的关键词。

## 注意:目前没有「可编辑版本」

`--dump` 显示线上 2.2 已发布、没有处于 `PREPARE_FOR_SUBMISSION` 的版本记录。这意味着:

- **App 信息级**字段(名称 `name`、副标题 `subtitle`、隐私政策 URL)可以随时写。
- **版本级**字段(描述、关键词、宣传文本、支持/营销 URL、更新说明、**截图**)必须先有一个
  可编辑版本。`asc_upload.py` 会按 `Version.xcconfig` 的 `MARKETING_VERSION` 自动
  `POST /v1/appStoreVersions` 建一个 —— 但 `Version.xcconfig` 现在还是 `2.2`,而 2.2 已上线,
  直接跑会撞 409 重复版本号。

所以推新语言前,先把 `Version.xcconfig` 的 `MARKETING_VERSION` 升到 `2.3`(或在 ASC 网页手工
建 2.3 版本记录),再跑上面第 4/5 步。

`app_metadata.json` 里的 `whatsNew` 写的就是「NoDiary 现在支持六种语言」这一版的更新说明。

## 已知需要修的线上数据

`--dump` 显示 en-US / zh-Hans 的隐私政策 URL 还是拼错的旧域名 `/nodairy/privacy/`(现在 404)。
`app_metadata.json` 里已经改成 `/nodiary/privacy/`,跑一次元数据写入就会修正。

## 元数据上限(脚本会先校验,超限直接退出)

名称 ≤30、副标题 ≤30、关键词 ≤100(逗号后**不要**留空格,白占字符)、
宣传文本 ≤170、描述 ≤4000、更新说明 ≤4000。

## 截图规格

只管 iPhone 6.7 吋(`APP_IPHONE_67`,1284×2778),6 张,文件名字典序 = App Store 展示序:

```
1-home  2-flock  3-editor  4-stats  5-home-dark  6-privacy
```

iPad 截图**不在**脚本管理范围(`DISPLAY_TYPES` 里没有),已有的 iPad 截图不会被删。
上传时会先清空对应语言的 6.7 吋截图组,再按文件名顺序重传,保证顺序和内容确定。
