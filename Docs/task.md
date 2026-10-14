# 模型目錄更新與轉寫修補工作清單

本文件追蹤模型目錄、轉寫修補、ID 唯一標籤、收合高度調整、文件校正與 **`v1.5.5` 正式發布（原始碼版本 `1.5.5+13`）**。[PR #3](https://github.com/jeff1121/ZeroType/pull/3) 已於 2026-10-14 00:54:20（Asia/Taipei；UTC 2026-10-13 16:54:20）合併至 `master`，merge commit 為 `b4164bd`。`1.5.4` 的 build 10／11／12 是合併前未發布的測試歷程，保留原始驗證紀錄；更早工作見 [Tasks.md](Tasks.md)。正式產物以 [v1.5.5 下載頁](https://github.com/jeff1121/ZeroType/releases/tag/v1.5.5) 與下方發布驗收紀錄為準。

## 目前交付範圍（v1.5.5）

- 模型目錄以完整 ID 呈現及排序；API 顯示名稱保留為資料，不顯示在選單、tooltip 或排除清單。
- 收合欄位高度縮短 40%：100% 字級時約 66 → 39.6 logical pixels，字級不變；展開選項保留 64 高度與能力提示，隨系統字級縮放。
- 官方／Proxy 目錄區分成功、空結果與失敗，具同來源快取、授權隔離與過期結果防護。
- Gemini 各通道合併首候選可見文字並排除思考內容，避免首段空白導致整份轉寫被丟棄。
- 說明文件逐項對照目前原始碼；產品能力、歷史計劃、提示詞指令與已完成的驗證分開記錄。
- 2026-10-15 依使用者要求進行正式發布，包含 `v1.5.5` tag、macOS／Windows 發布工作流程及下載產物驗收；PR 合併與正式發布分開記錄。

## 文件核對清單

| 文件 | 核對範圍 |
|---|---|
| `README.md` | 現行功能、v1.5.5 完整修正紀錄、平台需求與已知限制 |
| `RELEASE_NOTES.md` | v1.5.5 變更、版本與驗證狀態 |
| `CLAUDE.md` | 目前架構、持久化、工具鏈及開發規範 |
| `CONTEXT.md` | Provider／通道／憑證、目錄與轉寫領域語意 |
| `.agents/rules/flutter-desktop.md` | 與 CLAUDE 一致的語言規則、Dart 用語與實際本地化狀態 |
| `Docs/Requirement.md` | 歷史需求與現行實作的差異 |
| `Docs/Plan.md` | Windows 修復歷史定位與現行工作入口 |
| `Docs/Tasks.md` | 歷史交付紀錄、過時描述與現行索引 |
| `Docs/task.md` | 本次工作、版本、驗證與限制的單一進度紀錄 |
| `Docs/Windows-Hotkey-Audit.md` | 保留當時缺陷與證據，避免混同為本版實測 |
| `Docs/macos-installation.md` | 實際產物、checksum 路徑、自簽章與安裝步驟 |
| `Docs/adr/0001-zerotype-oauth-client.md` | 歷史 ADR 與現行 Antigravity 登入區分 |

## v1.5.5 驗收進度

- [x] `pubspec.yaml` 升為 `1.5.5+13`，修正 package description 不再宣稱獨立精修。
- [x] 納入已完成的下拉選單收合高度調整，保留文字大小與展開選項高度。
- [x] 完成上述 12 份 Markdown 核對，README 與 Release Notes 同步。
- [x] 本版格式、靜態分析、完整測試與 macOS Release 建置。
- [x] `1.5.5+13` 提交 `007a3ed63906974cb6c85ad7fd4004433b7ec7ef` 已通過 Dart／Windows CI，並經 PR #3 合併至 `master`（`b4164bd`）。

| v1.5.5 檢查 | 結果 |
|---|---|
| 格式、分析、完整測試 | 2026-10-14 實跑：82 files / 0 changed；No issues found；213 tests passed |
| macOS Release 版本 | 成功建置，Info.plist 為 `1.5.5 (13)`，最低 macOS `12.0`，App 49.9 MB |
| macOS 簽章封印與架構 | `EXPECTED_VERSION=1.5.5 bash scripts/verify_macos_release.sh` 通過；`x86_64 arm64`；本機為 ad-hoc 簽章，並非發布 workflow 的 ZeroType 自簽憑證，也不是 notarization |
| 文件相對連結與版本一致性 | 12 份 Markdown、21 個相對連結皆可解析；pubspec／README／Release Notes／工作清單版本一致為 `1.5.5+13` |
| PR Dart gates／Windows Release CI | 提交 `007a3ed63906974cb6c85ad7fd4004433b7ec7ef` 的 [run 38433774347](https://github.com/jeff1121/ZeroType/actions/runs/38433774347) 已完成；`dart-checks` 與 `windows-build` 均成功。此為合併前檢查，不冒充下方正式發布工作流程的結果 |

## v1.5.5 正式發布驗收（2026-10-15）

發布基礎為已合併 PR #3 的 `master`；發布文件經 [PR #4](https://github.com/jeff1121/ZeroType/pull/4) 合併，tag `v1.5.5` 指向 `dc7882e1cd28c7d4c6d1907ae994577729d1c032`，原始碼版本為 `1.5.5+13`。[ZeroType v1.5.5](https://github.com/jeff1121/ZeroType/releases/tag/v1.5.5) 已於 2026-10-15 00:58:48（Asia/Taipei）公開發布，非草稿、非預發佈版本。以下為下載正式附件後的驗收結果；本次補記不移動版本標籤或重建已發布的二進位檔。

- [x] 核對 PR #3 的合併時間、merge commit 與對應提交的 CI 成功結果。
- [x] 發布文件收尾提交已納入發布來源，建立並推送指向正確提交的 `v1.5.5` tag。
- [x] tag 觸發的 [Build and Release Desktop Apps／run 38601947340](https://github.com/jeff1121/ZeroType/actions/runs/38601947340) 中，macOS 與 Windows 工作均成功。
- [x] 正式 Release 已建立，以下五個發布資產全部可下載。
- [x] 已下載正式 DMG、macOS ZIP、Windows ZIP 及兩份 SHA-256 清單，核對版本、架構、簽章與 checksum。

| 平台 | 預期發布資產 | 驗收狀態 |
|---|---|---|
| macOS | `ZeroType-macOS.dmg` | 22,423,754 bytes；SHA-256 與簽章封印均通過；App `1.5.5 (13)`、`x86_64 arm64`、`Authority=ZeroType` |
| macOS | `ZeroType-macOS-arm64.zip` | 20,356,091 bytes；SHA-256 與簽章封印均通過；App `1.5.5 (13)`、`x86_64 arm64`、`Authority=ZeroType` |
| macOS | `SHA256SUMS.txt` | 192 bytes；對應上述 DMG／ZIP，清單內路徑前綴為 `release/` |
| Windows | `ZeroType-Windows-x64.zip` | 13,555,922 bytes；SHA-256 通過；ZIP 中 `zero_type.exe` 的 PE 為 x64，file／product version 均為 `1.5.5.13` |
| Windows | `SHA256SUMS-Windows.txt` | 92 bytes；對應 Windows ZIP，於 macOS 驗證時僅正規化清單的 CRLF 行尾，不修改 ZIP |

發布工作流程使用 `ZeroType` 自簽憑證簽署 macOS App；這不等於 Apple Developer ID 或 notarization。既有 Windows／Azure 真機與桌面流程人工驗證仍維持未驗證，不因建立 tag、發布或 CI 成功而補勾。

兩份 macOS 附件分別以 `EXPECTED_VERSION=1.5.5 bash scripts/verify_macos_release.sh <附件>` 驗證，並核對輸出的 build 13 與簽章身分；Windows ZIP 在記憶體讀取 PE 的 RT_VERSION 資源核對版本，未執行 EXE。Release 頁面另保留本次發布工作流程與資產驗收摘要。

以下 build 10／11／12 均為歷史驗證，未改寫成 v1.5.5 的驗證結果。

## 已確認的問題

1. Antigravity 回應中五個不同 ID 共用 `Gemini 3.5 Flash Lite` 名稱；畫面只有名稱，使用者無法辨識。
2. 解析時遺失 `supportedMimeTypes`，沒有排除明確不接受目前 `audio/mp4` 錄音格式的模型。
3. 端點失敗被轉成內建清單／空值，reload 仍宣稱更新成功。
4. 選模型會重建連線狀態並再次查詢目錄；缺乏可明確驗證的來源隔離與過期請求防護。

## 實作契約

- 保存與發送原始 model ID，只在同一目錄中按完整 ID 去重，不能按名稱合併。
- 能力分為支援／不支援／未確認，依實際 `audio/mp4` 與該通道的資料判斷；缺 metadata 不等於不支援。
- 明確不支援的模型不提供新選擇；既有選取保留並警示，轉寫依既有行為送出。目錄查不到、不列出舊 ID 或能力未知都不是新的轉寫閘門。
- 官方 API Key、Antigravity、Proxy 各自使用適用規則；Azure 保留不過濾部署與手動部署入口。
- 遠端成功、合法空目錄、缺憑證、失敗分開表達。失敗依序使用同來源上次成功清單與適用內建清單，不能宣稱已更新。
- 記憶體快取按 Provider／通道／endpoint／憑證情境隔離；不儲存 token、音檔或帳號到新持久化快取。
- 更新中保留同來源清單，連點合併；舊請求不能覆蓋新來源，也不能發送過期通知。

## 平行工作與順序（build 10 目錄修正）

- [x] A：新增模型能力與明確目錄查詢結果，改寫官方／Proxy 解析與安全錯誤分類。
- [x] A：加入去識別化回應 fixture 與解析／失敗／空清單測試。
- [x] B：建立目錄狀態 controller、同來源記憶體快取、請求序號與同時更新合併。
- [x] B：選取模型不再觸發目錄與授權重新查詢；加入來源切換與競態測試。
- [x] C：初版模型顯示名稱＋ID、能力狀態與完整文字提示；build 12 依使用者要求改為只顯示 ID。
- [x] C：保留已選但不支援／不在清單的 ID、Azure 手動部署與真實頁面測試。
- [x] 整合：加入不含機密的 Antigravity 憑證情境識別；驗證正常 token 續期不改變來源。
- [x] 整合：修正跨帳號共用授權更新與舊授權寫回競態；身分識別綁定同一次授權結果。
- [x] 整合：更新中保留同來源內建清單；舊下拉選單不能選取最新目錄已移除或不支援的候選。
- [x] 整合：更新 README、CONTEXT、CLAUDE、Plan、Requirement、Tasks 與 Release Notes。
- [x] 整合：格式、靜態分析、完整測試。
- [x] 整合：最終 macOS Release 建置。
- [x] 整合：提交 PR 的 Dart gates 與 Windows Release CI 自動驗證；即時結果見下方 PR checks。
- [x] 交付：commit、推送工作分支、建立 PR；保留未完成的人工驗證紀錄。

## 驗收矩陣

| 情境 | 預期 |
|---|---|
| 五個同名 Flash Lite | 保留五個 ID，可辨識且保存正確 ID |
| tiered 缺顯示名稱 | 顯示完整 ID，仍依能力判定 |
| Claude 非音訊格式 | 不提供新選擇；已選保留並警示 |
| Image／GPT-OSS 缺能力欄位 | 未確認，仍可選，不冒稱已驗證 |
| 僅支援 MP3、null／畸形 metadata | 不誤判為支援目前 M4A |
| 首次失敗／已有快取後失敗 | 顯示正確來源與原因，沒有假成功 |
| 合法空目錄／格式錯誤 | 分別為成功空結果／失敗 |
| 連點 reload、連續 reload | 合併進行中請求、不累加項目 |
| 選模型 | 保存 ID，不重新發出目錄請求 |
| A 慢 B 快、切回 A、切憑證 | 舊資料／通知不得覆蓋新來源 |
| 授權更新期間換帳號／刪來源檔 | 不共用其他帳號 token；舊回應不覆寫目前憑證 |
| 已開下拉選單時更新能力／移除候選 | 提示重新選擇，不儲存過期候選 |
| 已選 ID 消失後重現 | 不改選、沒有重複 ID |
| Proxy 別名／Azure 手動部署 | 原有選擇與轉寫契約保持相容 |
| macOS／Windows、窄視窗與鍵盤 | 選單可操作、無溢出；平台模擬與實機測試分開記錄 |

## 驗證紀錄

### 2026-10-13 目錄修正（build 10）

2026-10-13，四位 agent 平行實作並交叉審查，最後由主 agent 整合驗證：

| 檢查 | 實際結果 |
|---|---|
| `dart run build_runner build` | 成功，產生檔由工具更新 |
| `dart format --output=none --set-exit-if-changed lib test` | 80 files，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --reporter expanded` | 175 個測試全部通過，未 skip／exclude |
| `flutter build macos --release --no-pub` | 成功產生 `Zero Type.app`（49.9 MB），版本 `1.5.4 (10)` |
| PR Dart gates／Windows Release CI | [PR #3 checks](https://github.com/jeff1121/ZeroType/pull/3/checks)，以最新 commit 的遠端結果為準 |

新增／擴充測試以模擬 HTTP 傳輸、實際 controller 與真實頁面驗證結果；`test/fixtures/antigravity_catalog.json` 是依 2026-10-13 目錄觀察重建的最小去識別化 fixture，不含帳號、project、配額或憑證。

交叉審查額外補正：內建清單更新時消失、Proxy 多個尾斜線與 cache key 不一致、已開選單儲存過期候選、失效／未知授權識別引發額外查詢、跨帳號並行 token 更新與舊檔寫回。授權與 controller 的新增缺陷案例均先重現失敗再修至通過。

### 驗證範圍

- macOS／Windows 的 700×500 選單、方向鍵／Enter／Escape 以 widget 平台模擬驗證。
- 未在 macOS 或 Windows 逐項人工操作本次新介面；Windows 編譯由 PR CI 驗證，不能等同實機操作。
- 此輪未對遠端模型送出測試音檔。後續 2026-10-14 針對一個模型的合成語音驗證另記於下方；仍未逐模型實測。音訊格式 metadata 只表示目錄宣告的能力，不等於品質、配額或實際轉寫已驗證。
- 此輪未合併 PR、未建立 tag，也未發布安裝檔；當時原始碼版本為 `1.5.4+10`。既有下載 Release 不因分支推送而更新。

### 2026-10-14 空文字回報與修補（build 11）

使用者實測回報轉寫得到空文字。主 agent 以約 4.5 秒的合成英文語音呼叫 Antigravity 的 `gemini-3.5-flash-lite`，取得 HTTP 200、`finishReason: STOP`。第一個候選包含多段回應：`parts[0]` 為 `thought: true` 且文字為空，`parts[1]` 含正確逐字稿與 `thoughtSignature`。既有程式只讀 `parts[0].text`，因此丟掉後續有效文字。

同一診斷也確認最小提示詞搭配 snake_case／camelCase 音訊欄位都能讓服務端讀取合成語音。本次依已重現的解析缺陷修補，不調整音訊 payload、提示詞、使用中模型或既有請求重試策略。原使用者錄音未讀取、未上傳；這次即時測試只使用合成音檔，不代表其他模型或真實使用者錄音皆已驗證。

修補契約：

- Gemini 官方／Proxy 與 Antigravity 共用文字解析，僅讀第一個候選，依原順序串接其可見文字，最後再 trim。
- 排除 `thought: true` 段落；可見文字即使附有 `thoughtSignature` 仍須保留，不將簽章寫入逐字稿。
- 不合併、不改選其他候選；首段空文字不能導致忽略後續逐字稿。
- 封鎖、輸出達上限／截斷、缺候選與未完成回應回報固定安全錯誤，不回傳思考內容、簽章或完整上游回應，也不把部分逐字稿當成功。

平行修補與待驗證項目：

- [x] 主 agent：用合成語音重現多段回應，定位只讀第一段的缺陷。
- [x] 轉寫 agent：完成兩條轉寫分流的共用解析，加入 37 項多段／思考／其他候選／封鎖／截斷回歸測試。
- [x] 文件 agent：更新 README、Release Notes、CLAUDE、CONTEXT 與本清單；版本增加為 `1.5.4+11`。
- [x] 主 agent：修正後以同一模型與合成音檔完成服務層即時轉寫驗證。
- [x] 主 agent：重新執行格式、靜態分析、完整測試，build 11 共 212 項通過。
- [x] 主 agent：重新建置 macOS Release，確認 `1.5.4 (11)` 並重開 App。
- [x] 主 agent：將本次修補納入原 PR #3 交付流程；最新提交的 Dart gates 與 Windows Release CI 由下方連結追蹤。

| build 11 檢查 | 結果 |
|---|---|
| 合成語音即時缺陷重現 | 已重現：HTTP 200 `STOP`，首段空白 thought、後續段落有正確逐字稿 |
| 修正後服務層即時轉寫 | 同模型通過：英文合成音檔＋簡短轉寫指令；中文 16 kHz AAC/M4A 合成音檔＋未修改的內建提示詞 |
| 格式／靜態分析／完整測試 | format 82 files / 0 changed；analyze No issues found；212 tests passed |
| macOS Release 建置／重開 App | 成功建置並啟動 `1.5.4 (11)`，App 49.9 MB |
| PR Dart gates／Windows Release CI | [PR #3 checks](https://github.com/jeff1121/ZeroType/pull/3/checks)，以最新提交結果為準 |

中文即時驗證正確回傳「這是一段語音辨識測試，明天早上九點開會，請記得帶筆記本。」；英文簡短指令回傳對應的會議時間內容。這些呼叫經過正式 `SpeechRecognitionService.transcribe()` 與真實 Antigravity API，但沒有操作實體麥克風／剪貼簿，不稱為完整桌面流程實測。

追蹤決策：2026-10-15 依使用者決定，英文長提示詞／拼字品質觀察移出本輪追蹤；未修改提示詞或模型，未來頻繁重現再評估。

### 2026-10-14 模型標籤調整（build 12）

使用者指出大字顯示供應商名稱、不同 ID 都寫成 3.5 仍會誤導，要求採用較精準的 ID。此需求取代原「名稱＋ID」呈現方案。

- [x] 模型選單、已排除模型與 tooltip 只顯示完整 ID 及能力提示，完全移除供應商標籤。
- [x] 選單與已排除清單依 ID 排序；保留原始 ID、選取行為、Azure 手動部署及長文字可讀性。
- [x] 更新頁面回歸與文件，完成格式、分析、完整測試與 macOS build 12 建置／重開。
- 遠端名稱保留在資料層，這不是重新命名或轉換請求使用的 model ID。
- 自動檢查結果以 [PR #3 checks](https://github.com/jeff1121/ZeroType/pull/3/checks) 最新提交為準。

本機驗證：頁面 17 項測試通過；完整 213 項測試通過；格式 82 files / 0 changed；靜態分析無問題。macOS Release 成功建置並重開 `1.5.4 (12)`，沿用 build 11 的多段轉寫修復。

## 交付

- 已合併的功能來源分支：`fix/model-catalog-reload`；本輪發布文件收尾分支：`release/v1.5.5`。
- 功能提交：`02ac3df`（修正模型目錄更新、語音能力辨識與來源隔離）。
- 轉寫修補：`cef64d3`（正確解析 Gemini 多段轉寫並排除思考內容）。
- ID 標籤：`2421c47`（模型選單只顯示完整 ID，該提交的 Dart／Windows CI 已通過）。
- `v1.5.5` 原始碼提交：`007a3ed63906974cb6c85ad7fd4004433b7ec7ef`，對應 [CI run 38433774347](https://github.com/jeff1121/ZeroType/actions/runs/38433774347) 的 Dart gates 與 Windows Release 編譯皆成功。
- Pull Request：[jeff1121/ZeroType #3](https://github.com/jeff1121/ZeroType/pull/3)，已於 2026-10-14 00:54:20（Asia/Taipei）合併；merge commit：`b4164bd`。
- 交付版本為 `1.5.5+13`，包含上述修正、40% 收合高度調整與 12 份文件同步。正式發布驗收見本文件上方；下載資產以 [v1.5.5 Release](https://github.com/jeff1121/ZeroType/releases/tag/v1.5.5) 為準，舊測試 build 的紀錄保留為歷史。
