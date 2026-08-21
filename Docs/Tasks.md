# ZeroType — 任務列表

> 標記說明：`[前置]` = 此任務必須先完成才能進行後續任務

---

## 🏗️ 一、專案設定 (Project Setup)

> 其他所有任務的前置條件，優先完成。

- [x] **[前置]** 建立 Flutter 多平台專案（macOS + Windows）
- [x] **[前置]** 設定套件依賴（`pubspec.yaml`）
  - `riverpod` / `flutter_riverpod` — 狀態管理
  - `freezed` / `json_serializable` — UI state model
  - `get_it` — DI
  - `auto_route` — 路由
  - `shared_preferences` — 設定與 API Key 儲存（原規劃 `flutter_secure_storage`，實作改用 `shared_preferences`，非安全儲存）
  - `record` — 錄音
  - `hotkey_manager` — 全局快捷鍵
  - `tray_manager` — 系統列常駐
  - `launch_at_startup` — 開機啟動
  - `dio` — API 呼叫
  - `path_provider` — 暫存音檔路徑
  - `package_info_plus` — 取得 App 資訊（開機啟動用）
- [x] **[前置]** 建立 Clean Architecture 資料夾結構（`features/`, `core/`, `shared/`）
- [x] **[前置]** 設定 `GetIt` 依賴注入容器（`SharedPreferences`；憑證改存 `SharedPreferences`，未使用 `FlutterSecureStorage`）
- [x] **[前置]** 建立 providers config JSON 設定檔（語音辨識的 Provider/Model 清單）
- [x] **[前置]** 設定 `auto_route` 路由（`MainShellPage` + 4 個子頁面）

---

## ⚙️ 二、系統層 / OS 整合 (System Integration)

> 依賴：專案設定完成

- [x] **[前置]** 麥克風權限請求（macOS `Info.plist` 加入 `NSMicrophoneUsageDescription`；`DebugProfile.entitlements` 加入 `audio-input`）
- [x] **[前置]** 輔助使用 (Accessibility) 權限請求流程（macOS：貼上用 `CGEvent` 模擬 `Cmd+V` 所需）
  - `AppDelegate.swift` 已實作 `CGEvent` 貼上；未授權時 overlay 顯示「請先授權輔助使用權限」並提供開啟系統設定的引導
- [x] 全局快捷鍵監聽（`HotkeyService`，預設 `Alt+Space`，`hotkey_manager`）
- [x] 錄音後模擬鍵盤貼上（`Cmd+V`）到游標位置
  - macOS：`AppDelegate.swift` 使用 `CGEvent` 模擬
  - Windows：待實作
- [x] System Tray / Menu Bar 常駐（`TrayService`，`tray_manager`）
  - [x] 主視窗關閉時縮小（hide）而非退出（`onWindowClose` → `windowManager.hide()`）
  - [x] Tray 選單：顯示視窗 / 結束
- [x] 開機啟動開關（`launch_at_startup`，設定頁已實作 UI 開關）

---

## 🎙️ 三、核心業務邏輯 (Core Logic)

> 依賴：專案設定、系統層麥克風權限

### 3.1 錄音模組
- [x] **[前置]** 開始/停止錄音邏輯（`RecordingService`，儲存至系統暫存資料夾，16kHz M4A）
- [x] **[前置]** 音訊振幅取樣（100ms 頻率，正規化至 0.0~1.0，提供給 overlay UI）
- [x] 取消錄音 → 刪除暫存音檔（`cancelRecording()`）
- [x] 錄音完成後自動刪除暫存音檔（辨識完成後 `deleteFile()`）
- [x] 取消旗標（`_cancelled`）：`cancel()` 可中斷任意階段的 async 流程

### 3.2 語音辨識模組（OpenAI / Transcribe）
- [x] **[前置]** 建立 `ModelConfigRepository` 介面（含語音辨識 Provider/Model/Key 存取）
- [x] 實作 OpenAI Transcribe API 串接（`SpeechRecognitionService`，multipart 上傳，回傳純文字）
- [x] API Key 儲存與讀取（`SharedPreferences`，per-provider / per-channel key）
- [x] 錯誤處理：未設定 API Key / Provider/Model 時顯示錯誤 overlay

### 3.3 字典檔模組
- [x] 讀取/寫入字典 txt 檔案（存於 `applicationSupportDirectory`）
- [x] 新增字詞（輸入框 + Enter / 按鈕），重複字詞自動略過
- [x] 字詞列表依字母排序
- [x] 組合字典檔內容至 Prompt（`buildDictionaryPrompt()`，與語音辨識 Prompt 合併）

---

## 🖥️ 四、主視窗 UI (Main Window)

> 依賴：核心業務邏輯、專案設定

### 4.1 Layout 架構
- [x] **[前置]** 左側 `NavigationRail` 導航欄 + 右側內容區 Shell Layout（`MainShellPage`）
- [x] **[前置]** `ThemeData` 深色主題定義（`AppTheme.darkTheme`，主色 `#6C63FF`）

### 4.2 模型設定頁（`ModelConfigPage`）
- [x] 可收合的「語音辨識」Section（`[必填]` 紅標，預設展開）
- [x] Provider 選擇（`ChoiceChip`）→ 展開對應 Model 下拉選單
- [x] API Key 輸入框（密碼遮罩、眼睛圖示切換顯示、儲存至 Keychain）

### 4.3 字典檔頁（`DictionaryPage`）
- [x] 輸入框 + 加入按鈕 / Enter 新增
- [x] 字詞列表（字母排序）+ 刪除按鈕
- [x] 空狀態 UI（書本圖示 + 提示文字）

### 4.4 提示詞修改頁（`PromptPage`）
- [x] 語音辨識系統提示詞編輯區（含中文預設提示詞）
- [x] Dirty tracking（有修改才啟用儲存按鈕）
- [x] 還原預設按鈕（`resetToDefault()`）

### 4.5 設定頁（`SettingsPage`）
- [x] 開機啟動開關（`launch_at_startup`）
- [x] 全局快捷鍵錄製設定（顯示當前快捷鍵、點擊後進入錄製模式）

---

## 🎛️ 五、浮動錄音 Overlay (Floating Overlay)

> 依賴：核心業務邏輯（錄音、辨識）
> 實作方式：macOS `NSPanel`（AppKit），透過 `MethodChannel 'com.zerotype.app/overlay'` 控制

- [x] **[前置]** 浮動視窗基礎（`NSPanel`，無邊框、`level = .floating`，浮在所有視窗之上，不搶 focus）
- [x] 位置：x 軸螢幕置中，y 軸底部往上 60px（`NSRect` 定位，跟隨主螢幕）
- [x] 狀態一：**錄音中** — 脈衝圓點動畫 + 波形視覺化（`WaveformView`，AppKit 繪製）
- [x] 狀態二：**辨識中** — 藍色文字「語音辨識中…」
- [x] 狀態三：**錯誤** — 紅色文字，自動 3 秒後隱藏
- [x] 完成後自動隱藏（綠色「完成！」2 秒後消失）
- [x] `Esc` / 點擊任何地方 → `cancel()` 中止整個流程並隱藏 overlay
- [x] 啟動錄音音效（Tink）、停止音效（Pop）、取消音效（Basso）

---

## ✅ 建議開發順序

```
專案設定
  → 系統層（權限、Tray、快捷鍵）
    → 核心邏輯（錄音 → 語音辨識 → 貼上）
      → 浮動錄音 Overlay（與核心邏輯同步驗證）
        → 主視窗 UI（設定頁、模型設定、字典檔、提示詞）
```

## 📋 待辦清單（尚未實作）

- [x] 設定頁：開機啟動開關 UI
- [x] 設定頁：全局快捷鍵錄製 UI
- [x] Accessibility 權限引導 UI（貼上功能必須）
- [x] Windows 貼上功能（`SendInput`）
- [ ] 錯誤處理細化（網路失敗重試、API 額度不足提示）— *非阻塞 backlog*

> **第九節「Azure OpenAI Whisper Provider」已於本 branch 實作，待真機驗證與 PR 審核。** 其餘 Plan/Task 均已與現有原始碼同步。

---

## 🪟 六、Windows 跨平台兼容（Cross-Platform Windows）

> 跨平台分析發現的 macOS 專屬 API 移植清單。
> macOS 現有流程完全不動，所有修改均透過 `Platform.isWindows` / if-else 分支新增。

### P0 — 必須修復（否則 Windows 核心功能失效）

- [x] **Windows 貼上功能（`com.zerotype.app/keyboard` → `SendInput`）**
  - 建立 `windows/runner/channel_handler.h / .cpp`
  - 實作 `simulatePaste` → Win32 `SendInput` 模擬 `Ctrl+V`
  - macOS 繼續使用 `CGEvent` 模擬 `Cmd+V`（不動）
- [x] **Windows MethodChannel stubs（overlay / permission / control）**
  - 同一 `channel_handler.cpp` 加入所有 channel 的 Windows handler
  - `permission.checkAccessibility` → 回傳 `true`（Windows `SendInput` 不需授權）
  - `overlay`, `control` → 回傳 `nil` stub（避免 `MissingPluginException`）

### P1 — 應修復（功能受損或 UI 缺失）

- [x] **Settings Controller：Windows 輔助使用權限判斷**
  - `_checkAccessibility()` 加入 `Platform.isWindows` guard，直接回傳 `true`
- [x] **Windows 錄音狀態 Overlay（Flutter Widget）**
  - 實作 `recording_overlay.dart`（原為空 stub）
  - `Platform.isWindows` 時顯示 Flutter Widget overlay（底部置中，狀態色 + 波形 + 取消按鈕）
  - macOS 保持原有 NSPanel 行為（`SizedBox.shrink()`）
  - 在 `main_shell.dart` 以 `Stack` 包裹，疊加於主視窗之上

### P2 — 建議修復（穩定性）

- [x] **Prompt 檔案路徑**：自訂提示詞已用 `getApplicationSupportDirectory()` 絕對路徑（`SpeechToText_Custom.prompt`）；預設提示詞走 bundle asset `prompts/SpeechToText.prompt`，Windows 讀取無虞

---

## 📜 七、歷史記錄功能 (History)

> 記錄每次轉寫的文字與音檔，儲存於本地，支援播放、複製、開啟檔案位置與刪除，並可在設定頁設定保留天數。跨平台支援 macOS 與 Windows。

### 7.1 資料模型與儲存層

- [x] 建立 `TranscriptionRecord` 實體（`lib/features/history/domain/entities/transcription_record.dart`）
  - 欄位：`id`（timestamp 字串）、`text`、`audioPath`、`createdAt`、`durationMs`
  - LLM 使用量欄位：`provider`（String）、`model`（String）、`inputTokens`（int?）、`outputTokens`（int?）、`costUsd`（double?）
  - `provider` 存 provider id（如 `"openai"` / `"gemini"`）；`model` 存 model id（如 `"gpt-4o-transcribe"`）
- [x] 建立 `HistoryRepository` 介面（`lib/features/history/domain/repositories/history_repository.dart`）
  - 方法：`getRecords()`、`addRecord()`、`deleteRecord(id)`、`clearAll()`、`purgeExpiredRecords(days)`、`moveAudioFile(srcPath)`
- [x] 實作 `HistoryRepositoryImpl`（`lib/features/history/data/repositories/history_repository_impl.dart`）
  - 歷史清單存為 `applicationSupportDirectory/history.json`（與 dictionary.txt 同目錄，不引入新套件）
  - 音檔移至 `applicationSupportDirectory/history_audio/zerotype_[timestamp].m4a`（移動非複製，節省空間）
  - `purgeExpiredRecords()` 同步刪除過期記錄與對應音檔
  - `path_provider` 的 `applicationSupportDirectory` 在 macOS / Windows 均可用，路徑格式由套件處理，無需額外處理
- [x] 新增成本定價常數（`lib/core/constants/model_pricing.dart`）
  - `Map<String, ({double inputPerM, double outputPerM})> kModelPricing = { 'gpt-4o-transcribe': (inputPerM: 2.5, outputPerM: 10.0), 'gemini-2.5-flash': (inputPerM: 1.0, outputPerM: 2.5), 'gemini-3-flash-preview': (inputPerM: 1.0, outputPerM: 2.5), }`
  - 計算公式：`costUsd = (inputTokens * inputPerM + outputTokens * outputPerM) / 1_000_000`
- [x] 在 `lib/core/di/injection.dart` 中以 GetIt 註冊 `HistoryRepository` singleton
- [x] 在 `lib/core/constants/app_constants.dart` 中新增 `historyRetentionDaysKey = 'history_retention_days'`

### 7.2 核心流程整合

- [x] **`SpeechRecognitionService` 回傳型別擴充**（`lib/core/services/speech_recognition_service.dart`）
  - 新增 `TranscriptionResult` record type：`({String text, int? inputTokens, int? outputTokens})`
  - `transcribe()` 回傳 `Future<TranscriptionResult>` 而非 `Future<String>`
  - **OpenAI** (`_transcribeWithOpenAI`)：將 `response_format` 從 `'text'` 改為 `'json'`，從回應解析 `usage.input_tokens` / `usage.output_tokens`
  - **Gemini** (`_transcribeWithGemini`)：從 `usageMetadata` 解析 `promptTokenCount`（input）/ `candidatesTokenCount`（output）
- [x] `lib/core/services/recording_service.dart`：新增 `moveFileTo(String destPath)` 方法
- [x] `lib/core/controllers/zero_type_controller.dart`：
  - `_transcribe()` 改為回傳 `TranscriptionResult`，捕捉 provider / model / token 資料
  - 轉寫成功後，依 `kModelPricing` 計算 `costUsd`，移動音檔至歷史目錄並儲存完整 `TranscriptionRecord`
  - 取消錄音時仍走原本刪除流程，不儲存記錄

### 7.3 歷史頁面 UI

- [x] 建立 `HistoryPage`（`lib/features/history/presentation/pages/history_page.dart`）
  - 列表顯示，最新在上；每筆顯示：日期時間、文字預覽（最多 2 行）、操作按鈕列、刪除按鈕
  - **操作按鈕列**（每筆記錄右側）：
    - **播放 / 停止按鈕**：切換播放狀態；macOS 用 `Process.start('afplay', [path])` + `.kill()` 停止；Windows 用 `audioplayers` 套件（見 7.7）
    - **複製文字按鈕**（`Icons.copy_outlined`）：`Clipboard.setData(ClipboardData(text: record.text))`，平台通用
    - **開啟檔案位置按鈕**（`Icons.folder_open_outlined`）：在檔案管理員中高亮選取該音檔；macOS：`Process.run('open', ['-R', audioPath])`；Windows：`Process.run('explorer.exe', ['/select,', audioPath])`（注意逗號接在 `/select,` 後面，路徑用 `\` 分隔）
  - **LLM 使用量資訊列**（每筆記錄底部，灰色小字）：
    - 顯示格式：`Provider · ModelName · in: 789 / out: 60 · $0.0009`
    - Provider 顯示 providers.json 內的 `name`（如 `"OpenAI"` / `"Gemini"`）；Model 顯示對應 model 的 `name`（如 `"GPT-4o Transcribe"`）
    - `inputTokens` / `outputTokens` 為 null 時整列隱藏（舊資料或 API 未回傳）
    - `costUsd` 格式化為至多 4 位有效數字（如 `$0.0009`、`$0.0023`）
  - 空狀態：icon + 提示文字
  - 右上角全部清除按鈕（需 Dialog 二次確認）
- [x] **統計橫幅 `_StatsSummaryBar`**（固定於頁面底部，不隨列表捲動）
  - 頁面佈局：`Column` → `Expanded(child: ListView)` + `_StatsSummaryBar()`，bar 自然固定底部
  - 外觀：高度 64px；背景 `colorScheme.surface`；頂端加 1px 分隔線（`onSurface.withOpacity(0.1)`，與現有 card 邊框風格一致）
  - 內容：兩欄以 `VerticalDivider(width: 1)` 分隔，各 `Expanded`，文字水平 + 垂直置中：
    ```
    ┌──────────────────┬──────────────────┐
    │   轉寫次數        │   總花費 (USD)    │
    │      42           │    $0.0847       │
    └──────────────────┴──────────────────┘
    ```
    - 標籤：`fontSize: 11, color: onSurface.withOpacity(0.5)` 置於數字上方（間距 2px）
    - 數字：`fontSize: 20, fontWeight: bold, color: colorScheme.primary`（主色 `#FF7A00`）
    - 總花費無資料（所有 `costUsd` 皆 null）時顯示 `—` 而非 `$0.0000`
    - 金額格式：4 位有效數字（`$0.0847`、`$1.2300`），超過 `$10` 顯示兩位小數即可
  - 統計資料由 `HistoryController` 提供：`totalCount = records.length`；`totalCostUsd = records.fold(0.0, (s, r) => s + (r.costUsd ?? 0))`；`hasCostData = records.any((r) => r.costUsd != null)`
- [x] 建立 `HistoryController`（`lib/features/history/presentation/controllers/history_controller.dart`）
  - 管理播放中狀態（`playingId`）：同時只有一筆在播放，切換時先停止前一筆
  - 提供 `revealInFinder(String audioPath)` 方法（內部依平台分支）
  - 提供 `getProviderName(String providerId)` / `getModelName(String modelId)` 轉換顯示名稱（讀 providers.json）
  - 暴露 `totalCount` / `totalCostUsd` / `hasCostData` getter 供 `_StatsSummaryBar` 使用

### 7.4 路由與導航更新

- [x] `lib/core/router/app_router.dart`：加入 `HistoryRoute`（插入在 `SettingsRoute` 之前）
- [x] 執行 `flutter pub run build_runner build --delete-conflicting-outputs` 重新生成路由
- [x] `lib/shared/widgets/main_shell.dart`：
  - `AutoTabsRouter` routes 插入 `HistoryRoute()`（index 3，設定移至 index 4）
  - `NavigationRail` destinations 插入「歷史」（`Icons.history_outlined` / `Icons.history`，index 3）
  - `_showPermissionPrompt` 中的 `setActiveIndex(3)` 更新為 `setActiveIndex(4)`

### 7.5 設定頁更新（歷史記錄保留時間）

- [x] `settings_state.dart`：加入 `historyRetentionDays`（預設 7）
- [x] `settings_controller.dart`：`build()` 讀取保留天數；新增 `setHistoryRetentionDays(int days)` 方法
- [x] `settings_page.dart`：在一般 section 加入保留天數選項（`SegmentedButton`，選項：7 / 14 / 30 天）

### 7.6 自動清理

- [x] App 啟動時執行 `historyRepo.purgeExpiredRecords(retentionDays)`，刪除超過保留天數的記錄與對應音檔

### 7.7 跨平台支援（Windows）

> macOS 現有流程不動，所有 Windows 分支均以 `Platform.isWindows` 判斷。

- [x] **音檔播放**：macOS 用 `Process.start('afplay', ...)` 可停止；Windows 改以 PowerShell `Start-Process` 開啟預設媒體應用播放（未引入 `audioplayers` 套件）
  - macOS 沿用 `Process.start`，與現有 `SoundService` 模式一致
  - Windows 為「開啟預設應用」行為，無背景播放控制（符合現況需求）
- [x] **開啟檔案位置**：
  - macOS：`Process.run('open', ['-R', audioPath])`（Finder 高亮選取）
  - Windows：`Process.run('explorer.exe', ['/select,', audioPath.replaceAll('/', '\\')])` （需將路徑分隔符轉為 `\`）
- [x] **複製文字**：`Clipboard.setData()` 在 macOS / Windows 均可用，無需額外處理
- [x] **音檔格式**：`record` 套件在 Windows 錄製為 M4A（AAC），以預設媒體應用開啟播放，無需格式轉換

---

## 🌐 八、官方 / Proxy 雙通道與多元憑證（已完成）

> 現行原始碼已實作，於此補記以與 source code 同步。此節全部 `[x]`。

### 8.1 Provider / 通道 / 憑證架構
- [x] `providers.json` 保留為後備 provider/model 目錄（`assets/config/providers.json`，目前含 OpenAI、Gemini）
- [x] 語音辨識支援雙通道 `SpeechChannel { official, proxy }`（`speech_connection.dart`）
- [x] 官方通道憑證方式 `CredentialMethod { apiKey, antigravityOauth }`（Gemini OAuth 已於 v1.2.0 移除）
- [x] 各 provider / channel 的 model、API Key、Proxy 根位址、官方憑證方式獨立保存於 `SharedPreferences`（`ModelConfigRepositoryImpl`），並遷移舊 `custom_endpoint_*` / `api_key_speech_<provider>`

### 8.2 官方 / Proxy 轉寫分流（`SpeechRecognitionService`）
- [x] OpenAI：官方 `https://api.openai.com/v1/audio/transcriptions`；Proxy `{根}/v1/audio/transcriptions`
- [x] Gemini：官方 `.../v1beta/models/{model}:generateContent`（API Key `x-goog-api-key` 或 OAuth Bearer）；Proxy `{根}/v1beta/...`
- [x] Antigravity 直連：`cloudcode-pa` / `daily-cloudcode-pa` 的 `v1internal:generateContent`，帶 project id

### 8.3 官方即時模型目錄（`OfficialModelCatalogService`）
- [x] 有可用憑證時向官方 models API 查詢（Gemini `/v1beta/models`、OpenAI `/v1/models`）；查不到或無憑證時退回 `providers.json`
- [x] Proxy 目錄查詢（`ProxyModelCatalogService`，`{根}/v1/models`）

### 8.4 Antigravity OAuth 一鍵登入落地憑證（v1.2.0）
- [x] `AntigravityOauthService`：Antigravity 專用 OAuth client + `cclog` / `experimentsandconfigs` scope，本機 callback 換 token
- [x] `loadCodeAssist`（`ideType=ANTIGRAVITY`，必要時 `onboardUser` 輪詢）取得 project id
- [x] 落地 `~/.cli-proxy-api/antigravity-<email>.json`，`AntigravityAuthSource` 統一讀取與 access 過期續期
- [x] 亦支援引用本機既有 `~/.cli-proxy-api/antigravity-*.json` 或 `~/.gemini/oauth_creds.json`

---

## 🟦 九、Azure OpenAI Whisper Provider（已實作 — 本 Branch 目標）

> 分支：`azure-openai-whisper`。新增 Azure 作為第三個語音辨識 Provider，走 Azure OpenAI 部署的 Whisper。
> 使用者只需自行填寫 **Service Endpoint、API Key、API Version**（皆為必填）。
> 依 Owner 指示：**不做 Whisper 過濾**（企業私有部署 endpoint/token 本就對應 Whisper 服務），refresh 直接列出部署清單。

### 9.1 需求與 UX
- [x] Provider 列新增 `Azure`（label 直接叫「Azure」）
- [x] 選 Azure 後，通道只顯示「官方」（隱藏 Proxy 並強制 `SpeechChannel.official`）
- [x] 憑證區改為 Azure 專用三欄（皆必填）：**Service Endpoint**、**API Key（Access Token）**、**API Version**
- [x] 「更新模型目錄」可用：呼叫 Azure 部署清單 API，直接列出部署（不過濾），使用者選其一（即 Whisper 部署）
- [x] 查不到部署時提供「手動輸入部署名稱」fallback，仍可完成轉寫

### 9.2 技術細節（已查證）
- 轉寫：`POST {endpoint}/openai/deployments/{deployment}/audio/transcriptions?api-version={apiVersion}`
  - Header：`api-key: {token}`（**非** `Authorization: Bearer`）
  - Body：`multipart/form-data`，`file=...`、`response_format=json`；回應 `{"text": "..."}`
  - `{deployment}` = 使用者選/填的部署名稱（即本 provider 的 model id）
- 部署清單（給 refresh 用）：`GET {endpoint}/openai/deployments?api-version=2023-03-15-preview`，Header `api-key: {token}`
  - 回應 `data[]`，每筆 `id`=部署名稱、`model`=基礎模型；以 `id` 當 model id 列出（不過濾）
  - ⚠️ 此 data-plane 清單 API 在新 api-version 已淡出，故 9.1 的手動輸入 fallback 為必要
- Endpoint 正規化：去除結尾 `/`（例：`https://<res>.openai.azure.com`）
- 預設值建議：轉寫 api-version 使用者填（預設可帶 `2024-10-21`）；清單固定 `2023-03-15-preview`

### 9.3 實作任務（依序）
**Phase 1 — 資料與狀態層**
- [x] `assets/config/providers.json` 新增 `azure` provider（`models` 留空，靠 refresh / 手動輸入）
- [x] `app_constants.dart` 新增 `azureEndpointKey`、`azureApiVersionKey`（per-provider）
- [x] `speech_connection.dart`：新增 `azureEndpoint`、`azureApiVersion` 欄位；`isAzure` 判斷；`isReady` 的 azure 分支（需 endpoint + apiKey + apiVersion + model 皆備）；提供「每 provider 允許通道」
- [x] `model_config_repository(.dart / _impl)`：azure endpoint / api-version 存取

**Phase 2 — 服務層**
- [x] Azure 部署清單查詢 + 解析（新 `AzureModelCatalogService` 或在 `OfficialModelCatalogService` 加 azure 分支），失敗回傳空清單
- [x] `SpeechRecognitionService._transcribeWithAzure`：組 deployment URL、`api-key` header、multipart、解析 `text`
- [x] `model_config_controller.dart`：`build` 載入 endpoint/api-version；`saveAzureEndpoint` / `saveAzureApiVersion`；`selectProvider(azure)` 強制官方通道；`_resolveCatalogAuth` azure 分支（帶 endpoint + api-version）
- [x] `zero_type_controller.dart`：`_resolveAuth` azure 分支回傳 apiKey + endpoint；`_transcribe` / `transcribe` 增加 endpoint / api-version 參數並串接

**Phase 3 — UI（`model_config_page.dart`）**
- [x] Provider 列加入 Azure；選 Azure → 通道只剩官方且自動選官方
- [x] `_AzureCredentials` widget：Endpoint + API Key + API Version 三個輸入與儲存
- [x] `_ModelPicker` azure 分支：refresh 列出部署；查不到時顯示手動輸入部署名稱欄位

**Phase 4 — 驗證**
- [x] 單元測試：部署清單 JSON 解析、Azure 轉寫 URL / header 組裝
- [x] `dart format` / `flutter analyze` / `flutter test`
- [x] build_runner 重新產生（若動到 Riverpod / Freezed / AutoRoute annotation）
- [ ] 真機測試：填 endpoint + key + api-version → refresh 出現部署 → 錄音轉寫成功

### 9.4 注意事項
- Whisper 為每分鐘計價，現有成本統計為 token 制 → Azure 轉寫成本可能顯示空白（可接受，日後再補 duration 計價）
- Token 型別預設當 **api-key**（Azure「Keys & Endpoint」金鑰）；若日後需 AAD，改送 `Authorization: Bearer`
- 完成後推送並開 PR 交 Owner 審核
