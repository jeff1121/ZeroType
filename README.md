# Zero Type

> 一個 Vibe Coding 出來的繁體中文語音輸入工具。

市面上大多數語音辨識軟體對繁體中文（特別是台灣人慣用的晶晶體中英混用語境）支援度有限，且背後處理邏輯不透明。ZeroType 透過直接串接外部 LLM API，打造一套開放、透明、可自訂的語音辨識輸入系統。

**你只需要自備 API Key，其餘一切開源。**

---

## ✨ 功能特色

### 🎙️ 全局快捷鍵錄音
- 自訂全局快捷鍵（預設 `⌥ Option + Space`），在任何應用程式中觸發錄音
- 錄音中顯示浮動音波 Overlay，提供即時視覺回饋
- 按下 `Esc` 或點擊取消按鈕可中止錄音

### 🧠 AI 驅動的語音辨識
- 支援 **OpenAI**（`gpt-4o-transcribe`）與 **Google Gemini**（`gemini-*`）兩大語音辨識後端
- 辨識完成後，結果自動貼至游標所在位置（模擬 `⌘V`）
- 支援自訂 API Endpoint（可使用 OpenAI-compatible 的第三方服務）

### 🇹🇼 針對繁體中文深度優化的提示詞
內建的轉錄提示詞針對台灣使用情境做了以下優化：

| 功能 | 說明 |
|------|------|
| **晶晶體支援** | 中英文混用語句自然處理，英文單字保留原文不翻譯、不中文化 |
| **智慧過濾廢詞** | 自動剔除「嗯」、「啊」、「呃」、「喔」、「那個」、「然後」、「基本上」等停頓填充詞 |
| **口誤修正偵測** | 偵測到「不對」、「應該是」、「我說錯了」、「才對」等字眼，自動捨棄前段錯誤並保留修正內容 |
| **智慧標點** | 根據語意自動補上逗號、句號，不需手動停頓 |
| **自動條列輸出** | 偵測到序數（第一、第二）或連接詞（首先、然後、最後）時，自動轉為 `1. 2. 3.` 或 `- ` 格式並換行 |
| **格式口語還原** | 說出「大寫」、「小寫」、「空格」、「底線」、「驚嘆號」等，自動還原為對應字元 |
| **空白錄音保護** | 錄音檔為空時直接返回空字串，嚴禁自行幻想內容 |

### 📖 自訂字典
- 可設定個人化的專有名詞字典（人名、品牌、術語）
- 辨識時優先採用字典用字，確保拼寫正確

### ⚙️ 設定頁面
- 深色 / 淺色模式切換
- 開機自動啟動
- 快捷鍵自訂（支援任意組合鍵）
- 麥克風權限與輔助使用權限狀態即時顯示

---

## 🔧 使用前準備

### 系統需求
- macOS 11.0+
- Flutter 3.x（如需自行 build）

### 必要系統授權
1. **麥克風** — 錄音所需
2. **輔助使用（Accessibility）** — 模擬鍵盤輸入（`⌘V` 貼上）所需

### API Key
前往以下任一服務申請 API Key：
- [OpenAI](https://platform.openai.com/api-keys)（支援 Transcribe 語音辨識）
- [Google AI Studio](https://aistudio.google.com/app/apikey)（支援 Gemini 多模態）

---

## 🚀 快速開始

### 方法一：直接下載 macOS ad-hoc 版本

> 目前 macOS 安裝檔使用有效的 ad-hoc 簽章，但尚未加入 Apple Developer Program，因此沒有 Developer ID notarization。從網路下載後，macOS Gatekeeper 會加上 quarantine，第一次開啟可能顯示「App 已損毀」或「無法驗證開發者」。

1. 前往 [Releases](https://github.com/jeff1121/ZeroType/releases) 頁面下載最新的 `.dmg`。
2. 開啟 `.dmg`，將 **Zero Type.app** 拖入 `/Applications`。
3. 開啟 Terminal，移除下載檔案的 quarantine 屬性：

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Zero Type.app"
   open "/Applications/Zero Type.app"
   ```

4. 首次執行時，依照提示授予以下權限：
   - **麥克風** — 語音輸入所需
   - **輔助使用（Accessibility）** — 模擬鍵盤貼上所需
5. 在 App 內的「模型設定」選擇 Provider、通道與憑證，即可開始使用。

Release 頁面同時提供 `SHA256SUMS.txt`，可用以下指令核對下載檔完整性：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

詳細說明請參考 [`Docs/macos-installation.md`](Docs/macos-installation.md)。

### 方法二：從原始碼 Build（進階）

```bash
git clone https://github.com/jeff1121/ZeroType.git
cd ZeroType
flutter pub get
flutter run -d macos
```

---

## 🌍 語言支援 & 貢獻 (Localization & Contribution)

- **地區限制**：目前此 App 主要針對 **台灣使用情境** 設計，輸出內容以 **繁體中文** 與 **英文** 為主。
- **回報問題與協助**：如果你在使用上發現任何問題，或是單純想提供改進建議，歡迎直接發 **Issue** 或發 **Pull Request** 給我。

---

## 📜 版本更新紀錄 (Release Notes)

### [v1.3.0] - 當前版本
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
- **移除 Gemini OAuth 通道** 🧹
  - 該通道目前無法正常使用，暫時移除按鈕與相關程式，讓憑證設定畫面更乾淨（保留 API Key 與 Antigravity OAuth 兩種方式）。
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

MIT — 自由使用、修改、散布，唯需自備 API Key。
