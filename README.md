# Zero Type

> 一個 Vibe Coding 出來的繁體中文語音輸入工具。

ZeroType 是以繁體中文與台灣中英混用情境為目標的桌面語音輸入工具。錄音送往使用者選擇的語音辨識服務，搭配可自訂的提示詞與字典，將轉寫結果複製並貼上。

**可使用自備 API Key；Gemini 官方通道也支援 Antigravity OAuth 登入。程式碼完整開源。**

目前原始碼版本為 **`1.5.5+13`（待發佈）**。截至 2026-10-14，最新已發佈版本仍為 [v1.5.3](https://github.com/jeff1121/ZeroType/releases/tag/v1.5.3)；`1.5.4+10`／`+11`／`+12` 均為同一 PR 的未發佈測試 build，不是 GitHub Release。分支推送與 PR 更新不會自動更新下載頁。

---

## ✨ 功能特色

### 🎙️ 全局快捷鍵錄音

- 自訂全局快捷鍵（macOS 預設 `⌥ Option + Space`；Windows 預設 `Ctrl + Shift + Space`），在其他應用程式中觸發錄音
- macOS 使用原生浮動錄音面板；Windows 的錄音 Overlay 目前只顯示在 ZeroType 視窗內
- 可點擊取消按鈕中止錄音；macOS 支援錄音時的全域 `Esc`，Windows 的 `Esc` 由 App 內 Overlay 接收
- 最長錄音時間可設定為 1–5 分鐘，預設 1 分鐘

### 🧠 AI 驅動的語音辨識

- 支援 **OpenAI**（`gpt-4o-transcribe`）、**Google Gemini**（`gemini-*`）與 **Azure OpenAI Whisper** 三種語音辨識後端
- 辨識完成後先複製結果，再模擬 macOS `⌘ Cmd + V` 或 Windows `Ctrl + V` 貼上
- OpenAI／Gemini 支援官方 / Proxy 雙通道及自訂 Proxy 根位址；Azure 僅有官方通道，以部署名稱呼叫轉寫。
- Gemini 逐字稿支援多段文字回應，略過思考內容；模型封鎖或輸出被截斷時顯示明確錯誤。
- 目前沒有獨立的第二次 AI 精修呼叫；提示詞與字典在同一次轉寫請求中使用。

### 📋 可辨識的即時模型目錄

- 選單以完整 model ID 作為唯一名稱並按 ID 排序，例如 `gemini-3.1-flash-lite`；不顯示可能重複或與 ID 版本不同的供應商標籤。
- Antigravity 依回傳的格式能力判斷是否符合目前 M4A 錄音請求；未提供能力資訊的模型標示「轉寫能力未驗證」，仍可選取。
- 更新時保留同來源清單，失敗明示使用上次目錄或內建清單；合法空目錄不會被當成查詢失敗。
- 切換 Provider、通道、endpoint 或憑證時隔離目錄；選模型不再額外重新查詢。
- 已儲存的模型 ID 不會因更新、清單缺漏或能力變動而被自動改選；Azure 可隨時手動指定部署。
- 收合欄位縮短 40%，不縮小模型 ID 或能力提示的字級；展開選項保留原高度並隨文字縮放調整。

### 🇹🇼 繁體中文轉寫提示詞

內建 [轉寫提示詞](prompts/SpeechToText.prompt) 要求模型遵守下列規則。這些是模型指令，不是逐項保證成功的程式規則；使用者可在提示詞頁編輯自己的版本。

| 功能 | 說明 |
|------|------|
| **晶晶體支援** | 中英文混用語句自然處理，英文單字保留原文不翻譯、不中文化 |
| **過濾填充詞** | 要求剔除「嗯」、「啊」、「呃」、「喔」、「那個」、「然後」、「基本上」等填充詞 |
| **口誤修正** | 依「不對」、「應該是」、「我說錯了」、「才對」等修正訊號，以後者為準 |
| **標點** | 要求依語意補上標點 |
| **條列輸出** | 明確序數，或連接詞串聯三個以上事項時，要求轉成 `1. 2. 3.` 格式並換行 |
| **格式口語還原** | 要求把「大寫」、「小寫」、「空格」、「底線」、「驚嘆號」等描述還原為字元 |
| **空輸入約束** | 提示詞要求空輸入不產生文字；轉寫結果為空時，App 顯示「未能辨識出任何文字」 |

錄音流程沒有在送出前以語音活動偵測（VAD）阻擋靜音；音量資料用於畫面顯示，因此不能把上述空輸入指令視為本機靜音保護。另已觀察到內建長提示詞搭配全英文合成音訊時，可能翻譯或混入提示詞範例；此品質問題尚未解決，多段回應解析修復不代表模型輸出必然正確。

### 📖 自訂字典

- 可設定個人化的專有名詞字典（人名、品牌、術語）
- 轉寫時附加字典，要求模型優先參考；仍需核對實際辨識結果

### 🗂️ 本機歷史與資料儲存

- 成功轉寫的文字、音檔與模型資訊保存在本機，可從歷史頁查看；累計花費依內建價格表與回傳用量估算，不是供應商帳單或即時報價
- API Key 保存在 `SharedPreferences`，目前未使用作業系統安全憑證儲存；Antigravity OAuth 引用本機授權檔，更新授權時寫回同一來源

### ⚙️ 設定頁面

- 深色 / 淺色模式切換
- 開機自動啟動
- 快捷鍵自訂；Windows 需包含修飾鍵，主鍵支援字母、數字、Space、Escape、F1–F12，並排除系統保留組合
- 顯示麥克風權限與 macOS 輔助使用權限狀態；Windows 不使用 macOS 的輔助使用授權流程

---

## 🔧 使用前準備

### 系統需求

- macOS 12.0+（目前專案部署目標）或 Windows x64
- 自行建置請使用專案 CI 所採用的 Flutter `3.47.0`；Dart 版本須符合 `pubspec.yaml` 的 `^3.11.0`，Flutter `3.38.7`／Dart `3.10.7` 無法解析本專案
- macOS 與 Windows 需分別在對應主機建置；Windows 原生互動仍有未完成的實機驗證，見 [工作清單](Docs/task.md)

### 必要系統授權

1. **麥克風** — 錄音所需
2. **macOS 輔助使用（Accessibility）** — 模擬 `⌘V` 貼上所需；Windows 使用 `Ctrl+V`，不需此 macOS 授權

### 服務憑證

使用 API Key 時，向對應供應商取得憑證：

- [OpenAI](https://platform.openai.com/api-keys)（支援 Transcribe 語音辨識）
- [Google AI Studio](https://aistudio.google.com/app/apikey)（支援 Gemini 多模態）
- [Azure OpenAI](https://learn.microsoft.com/azure/ai-foundry/openai/overview)（支援 Whisper 部署；需自行填寫 Service Endpoint、API Key、API Version）

Gemini 官方通道也可選擇「Antigravity OAuth」，由 App 發起 Google 授權或引用本機已有登入；這不是獨立 Provider。Proxy 只支援 API Key 憑證方式，不使用 OAuth。

---

## 🚀 快速開始

### 方法一：直接下載 macOS 版本

> macOS 發布工作流程使用 `ZeroType` 自簽章憑證，並非 Apple Developer ID，也未經 notarization。macOS 可能阻擋首次開啟，請先核對下載來源與雜湊，再依系統提示允許執行。

1. 前往 [Releases](https://github.com/jeff1121/ZeroType/releases) 下載同版 `.dmg` 與 `SHA256SUMS.txt`，先依下方指令核對雜湊。
2. 開啟 `.dmg`，將 **Zero Type.app** 拖入 `/Applications`。
3. 開啟 App；若系統阻擋，於「系統設定 → 隱私權與安全性」依提示選擇「仍要打開」。
4. 首次執行時，依提示授予麥克風與輔助使用權限，供錄音及模擬貼上使用。
5. 在 App 內的「模型設定」選擇 Provider、通道與憑證，即可開始使用。

已核對來源與雜湊、仍需手動解除下載隔離屬性時，才在 Terminal 執行：

```bash
xattr -dr com.apple.quarantine "/Applications/Zero Type.app"
open "/Applications/Zero Type.app"
```

Release 頁面同時提供 `SHA256SUMS.txt`。若只下載 DMG，可在下載目錄計算雜湊，與清單內 `release/ZeroType-macOS.dmg` 那一行對照：

```bash
shasum -a 256 ZeroType-macOS.dmg
```

若 DMG、ZIP 與清單都在同一目錄，可先去除工作流程寫入的 `release/` 前綴，再一次核對兩個檔案；少下載其中一個檔案會顯示找不到該檔，不等同已下載檔案毀損：

```bash
sed 's|  release/|  |' SHA256SUMS.txt | shasum -a 256 -c -
```

詳細說明請參考 [`Docs/macos-installation.md`](Docs/macos-installation.md)。

### 方法二：從原始碼 Build（進階）

以下指令建置目前 checkout 的版本；待發佈的 `1.5.5+13` 改動見 [PR #3](https://github.com/jeff1121/ZeroType/pull/3)，不表示 `master` 或下載頁已更新。

```bash
git clone https://github.com/jeff1121/ZeroType.git
cd ZeroType
flutter pub get
flutter run -d macos
```

在 Windows 主機將最後一行改為 `flutter run -d windows`。正式建置分別使用 `flutter build macos --release` 或 `flutter build windows --release`；自行建置不代表完成 Release 簽署與發布流程。

提交前的 Dart 檢查與 CI 一致：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

---

## 🌍 語言支援 & 貢獻 (Localization & Contribution)

- **地區限制**：目前此 App 主要針對 **台灣使用情境** 設計，輸出內容以 **繁體中文** 與 **英文** 為主。
- **回報問題與協助**：如果你在使用上發現任何問題，或是單純想提供改進建議，歡迎直接發 **Issue** 或發 **Pull Request** 給我。

---

## 📜 版本更新紀錄 (Release Notes)

### [v1.5.5] - 當前原始碼版本（`1.5.5+13`，待發佈）

- **更緊湊的模型欄位**：收合外框高度較原先縮短 40%。在 100% 字級下，由 64 邏輯像素選項高度加 2 像素外框所得的 66，調整為 `(64 + 2) × 0.6 = 39.6`；展開選項仍為 64，模型 ID 與能力提示的字級不縮小，並保留系統文字縮放。
- **修正 Gemini 空文字結果**：Antigravity 可能先回傳空白思考段落，再回傳逐字稿。Gemini 共用解析會依序合併第一個候選的可見文字，略過思考段落；被封鎖或截斷的回應顯示明確錯誤，避免誤當成功。音訊 payload、提示詞、使用中模型與請求重試策略維持既有行為。
- **修正模型目錄辨識**：以完整 model ID 作為唯一選項名稱，移除容易混淆的供應商顯示標籤；僅依 ID 去重並排序。
- **語音格式能力**：Antigravity 區分支援、不支援與未確認；明確不支援目前錄音格式的模型不提供新選擇，既有選取保留並提示。未知能力、Proxy 自訂別名與 Azure 手動部署保持相容。
- **真實更新狀態**：遠端成功、空目錄、缺憑證與失敗各自呈現；快取或內建清單不再冒稱遠端更新成功。
- **來源隔離與更新競態**：同來源記憶體快取、進行中更新合併、過期回應與通知防護；選模型不再觸發額外目錄請求。
- **授權來源一致性**：不同憑證的並行更新不共用結果，寫回前比對來源快照，避免較舊的授權更新覆蓋新帳號。
- **本版本機驗證**：`1.5.5+13` 已完成格式檢查（82 檔、0 變更）、靜態分析與完整 213 項測試。macOS Release 建置及驗證腳本通過，產物為 `1.5.5 (13)`、49.9 MB、最低 macOS 12.0，包含 x86_64／arm64；此次本機簽章為 ad-hoc，不是發布工作流程的自簽憑證產物。
- **驗證邊界與已知限制**：前期修補已用同一模型完成中文合成語音＋內建提示詞、英文合成語音＋簡短指令的服務層即時轉寫；未使用原使用者錄音，也不是完整麥克風到貼上的桌面實測。內建長提示詞處理全英文音訊時仍有品質不一致，不宣稱已解決。Windows 本版 CI 與未完成人工驗證見 [工作清單](Docs/task.md) 及 [PR #3 checks](https://github.com/jeff1121/ZeroType/pull/3/checks)，不沿用舊提交的結果宣稱新版通過。
- **文件與版本**：整合未發佈測試 build 的修正，升為 `1.5.5+13`。校正 macOS 12.0 部署目標、Windows Overlay／貼上差異、提示詞能力界線、API Key 儲存及工具鏈說明。此次提交與 PR 更新不建立 tag、不合併 PR，也不發布安裝檔。

### [v1.5.4] - 未發佈測試 build 紀錄

- `1.5.4+10`：模型目錄、能力判斷與來源隔離修補。
- `1.5.4+11`：Gemini 多段回應與空文字修補；當時完成 212 項測試及 macOS Release 測試建置。
- `1.5.4+12`：模型選單改為只顯示 ID；當時完成 213 項測試及 macOS Release 測試建置。
- 上述均為 [PR #3](https://github.com/jeff1121/ZeroType/pull/3) 開發過程的測試版本，未發布為 GitHub Release；測試數量與建置結果只屬於當時的原始碼，不能替代 `1.5.5+13` 的最終驗證。

以下保留先前已發布版本的歷史說明；當時行為不等同目前原始碼行為。

### [v1.5.3]

- **Windows 原生視窗框與系統匣關閉行為**
  - Windows 改用系統標題列「ZeroType」，提供拖移、調整大小、最小化、最大化與關閉，不再疊加內容區的 44px 假標題。
  - 兩個桌面平台都攔截關閉並隱藏主視窗；真正退出仍由系統匣「結束 ZeroType」處理。
  - macOS 保留隱藏標題列、交通燈與 44px「Zero Type」標題，不改 macOS 原生 runner。
- **Windows 全域熱鍵可靠註冊**
  - 預設改為 `Ctrl+Shift+Space`，舊的 Windows 保留組合自動退回平台預設；macOS 保留 `⌥ Option+Space` 與 `hotkey_manager`。
  - Windows 改走 App 自有 `RegisterHotKey` channel，檢查回傳值與 `GetLastError`，加上 `MOD_NOREPEAT`，並透過 EventChannel 傳遞已註冊熱鍵的觸發事件。
  - 修正 Windows CI 發現的 C++ 區域變數遮蔽（MSVC C4456／C2220），保留警告視為錯誤的嚴格編譯門檻。
  - 拒絕沒有修飾鍵、Alt+Space、Alt+F4、Ctrl+Esc、含 Ctrl+Alt+Delete 與未支援主鍵；註冊被占用時顯示繁體中文原因與可用的錯誤碼，不再靜默宣稱成功。
- **熱鍵儲存／取消／失敗回復**
  - 修正錄製時暫停全域熱鍵後，儲存卻未恢復註冊的缺陷。候選組合必須註冊成功才更新目前熱鍵與 `global_hotkey` 設定。
  - 新鍵註冊或設定寫入失敗時恢復舊鍵；舊鍵也無法恢復則明示失敗並保持暫停，避免顯示假成功。
  - 沿用既有 `HotKey` JSON 格式，保留 macOS 已儲存的合法組合與修飾鍵資訊。
- **設定頁與 macOS 回歸修復**
  - 修正主視窗提前監聽設定狀態造成的初始化競爭，以及只先給預設值仍可能顯示過時熱鍵的問題；設定頁等待同一個初始化工作完成。
  - 設定載入失敗會顯示原因與重試按鈕，不再只有空白卡片。
  - 錄製覆蓋層遮住整個視窗，以 `HardwareKeyboard` 接收按鍵並在卸載時移除 handler；切回視窗不重置錄製，Esc 可取消。
  - 修正最小 700×500 視窗下長組合溢出、覆蓋層關閉時錯誤訊息消失，以及 Release 模式依賴 `debugName` 導致按鍵標籤失真的問題。
- **驗證與文件可信度**
  - 移除先前為取得全綠而加入的 analyzer 忽略規則，實際清理 lint；不變更錄音、轉寫、貼上、Azure 或 Antigravity 的業務流程。
  - 補上真實 SettingsController / MainShell 整合、註冊器 channel、回滾與初始化競爭測試，修正假註冊器讓回滾測試誤過的問題。PR 加入格式、分析、測試與 Windows 編譯檢查。
  - 使用者已回報先前自簽 macOS 測試版人工測試完成、未發現重大問題；本次複查新增修正另以自動化測試驗證。Windows 實機 11 項清單仍未有逐項驗證紀錄，不以 widget 平台模擬或 CI 編譯取代實測。
  - 詳細缺陷、測試證據與未驗證範圍見 [本次複查報告](Docs/Windows-Hotkey-Audit.md) 及 [工作清單第十一節](Docs/Tasks.md)。
- **版本提升**：`1.5.2+8` → `1.5.3+9`。macOS 延續 `ZeroType` 自簽憑證流程；這不等於 Apple Developer ID 或 notarization。

### [v1.5.2]

- **macOS 安裝檔改用自簽章憑證正式簽署** 🔐
  - 建置流程改以自簽章程式碼簽署憑證（Common Name: `ZeroType`）簽署 App，取代先前完全沒有身分資訊的 ad-hoc 簽章。
  - Gatekeeper 評估結果會顯示 `origin=ZeroType`，開啟時走「無法驗證開發者」流程，於「系統設定 → 隱私權與安全性」按一次「仍要打開」即可執行。
  - 這是自簽章憑證，並非 Apple 官方核發的 Developer ID，也未經 notarization；第一次開啟仍需手動允許。
- **修正選單列狀態圖示** 🎨
  - 修復 macOS 選單列常駐圖示顯示為黑白破圖案的問題，改為正確的紅底白色麥克風圖示。
- **版本提升** 🏷️
  - 軟體版本更新為 `1.5.2+8`。

### [v1.5.1]

- **修復 Antigravity 即時模型目錄刷新** 🔄
  - 修復 Gemini 官方 / Antigravity OAuth 點擊 Refresh 時未實際發出網路請求、僅回傳固定清單的問題。
  - 接通 Antigravity `v1internal:fetchAvailableModels`，以 Project ID 與 Access Token 取得最新可用模型，並過濾非轉寫的內部程式碼補全模型。
  - 斷線或未取得清單時，自動退回預設清單。
- **重新整理即時狀態回饋** 💬
  - 更新模型目錄時顯示載入指示器；完成後以 SnackBar 回饋取得數量或錯誤原因。
  - 同步支援 Proxy 通道的即時模型重新整理。
- **版本提升** 🏷️
  - 軟體版本更新為 `1.5.1+7`。

### [v1.5.0]

- **Azure 模型選擇與自訂部署** 🟦
  - 新增內建 `OpenAI Whisper (whisper)` 選項，尚未取得即時目錄時可供選擇。
  - 目錄查詢依序嘗試 `/openai/deployments`、`/openai/models` 與 `/openai/v1/models`；失敗或結果為空時改試下一個端點。
  - 清單有資料時仍可切換「手動指定自訂部署名稱」；已儲存但不在目前目錄中的選項會保留。
- **版本提升** 🏷️
  - 軟體版本更新為 `1.5.0+6`。

### [v1.3.0]

- **Azure OpenAI Whisper 語音辨識** 🟦
  - 新增 Azure 作為第三個語音辨識 Provider（僅官方通道）。
  - 必填 Service Endpoint、API Key、API Version；部署清單可 refresh，失敗時可手動輸入部署名稱。
  - 轉寫使用 Azure OpenAI Whisper 部署與 `api-key` header。
- **側邊欄顯示版本號碼** 🏷️
  - 左側導航欄底部以淡色顯示目前版號。
- **版本提升** 🏷️
  - 軟體版本更新為 `1.3.0+5`。

### [v1.2.0]

- **Antigravity OAuth 一鍵登入落地憑證** 🔑
  - 新增「Antigravity OAuth」憑證方式：直接用 Google 帳號在 App 內完成授權，無需先安裝 Antigravity 或 CLI。
  - 參考開源專案 CLIProxyAPI 做法，使用 Antigravity 專用 OAuth client 與 scope（含 `cclog`、`experimentsandconfigs`），透過本機 callback 完成授權。
  - 自動以 `loadCodeAssist`（`ideType=ANTIGRAVITY`，必要時 `onboardUser` 輪詢）取得 Project ID，並落地成 `~/.cli-proxy-api/antigravity-<email>.json`，供轉寫直接引用與自動續期。
- **移除獨立 Gemini OAuth 登入入口** 🧹
  - 該憑證方式當時無法正常使用，因此移除按鈕與相關程式，保留 API Key 與 Antigravity OAuth 兩種方式。
- **版本提升** 🏷️
  - 軟體版本更新為 `1.2.0+4`。

### [v1.1.1]

- **修復 macOS 安裝檔簽章封印** 🔐
  - 改為乾淨建置後直接打包，不再修改已簽章的 `.app` 內容。
  - 發布前與 DMG 打包後均執行 `codesign --verify --deep --strict`，避免再次發布資源遭修改的損毀 App。
  - 加入 ad-hoc 版本的 Gatekeeper quarantine 移除步驟與 SHA-256 完整性驗證說明。
- **版本提升** 🏷️
  - 軟體版本更新為 `1.1.1+3`。

### [v1.1.0]

- **全新 App 麥克風視覺圖示** 🎙️
  - 替換高解析度麥克風 Icon，並生成 macOS (.icns / .dmg) 與 Windows (.ico) 原生圖示。
- **Gemini 官方 / Proxy 雙通道與多元憑證架構** 🌐
  - **官方通道**：開箱即用，支援直連 Google AI Studio 官方公開 API 與 Google Cloud Code / Antigravity 原生端點。
  - **Proxy 通道**：支援自訂根位址（例如本地 `CLIProxyAPI` 網關），方便轉發任意相容 LLM 提供商。
  - 兩通道設定與模型偏好各自獨立保存，切換時互不干擾。
- **Antigravity 原生直連轉寫** ⚡
  - 自動引用本機現有 Antigravity 憑證與 Project ID。
  - 過期時自動以 Antigravity OAuth Client 續期寫回本機，並提供 10 款專用模型（如 `gemini-3.5-flash-extra-low`、`gemini-3.7-flash-high`）。
- **即時官方模型目錄查詢** 🔄
  - 官方通道自動向 Google / OpenAI API 查詢最新可用轉寫模型。
- **跨平台 GitHub Actions CI** 🚀
  - 加入 macOS 與 Windows 自動化 Release 建置工作流 (.github/workflows/release.yml)。

### [v1.0.2]

- **新增歷史紀錄頁** 🎨
  - 提供歷史產生逐字稿的紀錄語音檔，並可提供檢視。
  - 新增總轉寫次數與總花費（USD）的持久化累計統計。
- **最長錄音自訂** ⏱️
  - 設定中新增「最長錄音時間」選項，範圍 1-5 分鐘，預設為 1 分鐘。
- **編輯器優化** ✍️
  - 提示詞編輯框寬度與高度現在會隨視窗大小自適應，不再固定長度。

### [v1.0.1]

- **錄音音效支援** 🔊 — 可設定錄音開始與結束提示音。
- **功能修復** 🐛 — 修正 macOS 上視窗關閉後無法再次開啟的問題。
- **提示詞優化** 📝 — 進一步精簡轉錄用的系統 Prompt。

---

## 📝 License

MIT — 可依授權條款使用、修改與散布。線上轉寫另需相應服務憑證，使用限制與費用由服務供應商決定。
