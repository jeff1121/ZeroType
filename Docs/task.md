# 模型目錄更新與轉寫修補工作清單

本文件追蹤 2026-10-13 模型目錄審查後的實作，以及 2026-10-14 使用者實測空文字回報的修補，目標版本 `1.5.4+11`。目錄修正的 `1.5.4+10` 驗證紀錄保留於下方；更早工作紀錄保留於 [Tasks.md](Tasks.md)。兩次修改沿用待發布的 [PR #3](https://github.com/jeff1121/ZeroType/pull/3)。

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
- [x] C：模型顯示名稱＋ID、能力狀態、合理選單高度與完整文字提示。
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

另觀察到內建長範例提示詞搭配全英文合成音檔時，曾出現翻譯或混入範例的輸出；這是仍待處理的模型／提示詞品質問題，不在本次多段回應解析修補中宣稱解決。本次沒有覆寫使用者自訂提示詞，也沒有修改內建提示詞或音訊 payload。

## 交付

- 分支：`fix/model-catalog-reload`，已推送 `origin`。
- 功能提交：`02ac3df`（修正模型目錄更新、語音能力辨識與來源隔離）。
- Pull Request：[jeff1121/ZeroType #3](https://github.com/jeff1121/ZeroType/pull/3)。
- build 10 的既有提交與驗證保留為歷史；build 11 的新增轉寫修補另行提交，完成狀態依上方清單記錄。CI 連結持續反映 PR 最新提交，避免複製過時的檢查狀態。
