# ZeroType — 任務列表

> 標記說明：`[前置]` = 此任務必須先完成才能進行後續任務
> 第一至十節含歷史規劃／交付紀錄，不等同本次重新逐功能驗收。2026-09-29 已核對本次 Windows／熱鍵修復（第十一節），並更正可確認的過時敘述；舊規劃中的精確 UI、計價樣例以目前實作為準。未取得的 Windows／Azure 真機結果不因使用者一般性人工回報而補勾。

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
- [x] **[前置]** 設定 `auto_route` 路由（`MainShellPage`，目前 5 個導航分頁；另有 TestingRoute 非導航入口）

---

## ⚙️ 二、系統層 / OS 整合 (System Integration)

> 依賴：專案設定完成

- [x] **[前置]** 麥克風權限請求（macOS `Info.plist` 加入 `NSMicrophoneUsageDescription`；`DebugProfile.entitlements` 加入 `audio-input`）
- [x] **[前置]** 輔助使用 (Accessibility) 權限請求流程（macOS：貼上用 `CGEvent` 模擬 `Cmd+V` 所需）
  - `AppDelegate.swift` 已實作 `CGEvent` 貼上；未授權時 overlay 顯示「請先授權輔助使用權限」並提供開啟系統設定的引導
- [x] 全局快捷鍵監聽（macOS：`Alt+Space`／`hotkey_manager`；Windows：`Ctrl+Shift+Space`／App 自有 `RegisterHotKey` channel，見第十一節）
- [x] 錄音後模擬鍵盤貼上到游標位置
  - macOS：`AppDelegate.swift` 使用 `CGEvent` 模擬 `Cmd+V`
  - Windows：`channel_handler.cpp` 使用 `SendInput` 模擬 `Ctrl+V`（已實作，人工測試另計）
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
- [x] 成功轉寫後將音檔移至持久化歷史目錄；空結果／取消等清理路徑刪除暫存檔，不是成功後一律刪除音檔
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
- [x] **[前置]** `ThemeData` 深色主題定義（`AppTheme.darkTheme`，主色 `#FF7A00`）

### 4.2 模型設定頁（`ModelConfigPage`）
- [x] 可收合的「語音辨識」Section（`[必填]` 紅標，預設展開）
- [x] Provider 選擇（`ChoiceChip`）→ 展開對應 Model 下拉選單
- [x] API Key 輸入框（密碼遮罩、眼睛圖示切換顯示、儲存至 SharedPreferences；不是 Keychain／安全儲存）

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

- [x] **[前置]** 浮動視窗基礎（`NSPanel`，無邊框、`level = .statusBar`，浮在所有視窗之上，不搶 focus）
- [x] 位置：x 軸螢幕置中，y 軸底部往上 60px（`NSRect` 定位，跟隨主螢幕）
- [x] 狀態一：**錄音中** — 脈衝圓點動畫 + 波形視覺化（`WaveformView`，AppKit 繪製）
- [x] 狀態二：**辨識中** — 藍色文字「語音辨識中…」
- [x] 狀態三：**錯誤** — 紅色文字，自動 3 秒後隱藏
- [x] 完成後自動隱藏（綠色「完成！」2 秒後消失）
- [x] `Esc` / 點擊取消按鈕 → `cancel()` 中止流程並隱藏 overlay（不是點擊任何地方）
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

> **目前要做的是第十一節。** 規格在 `Docs/Plan.md`（2026-09-24，Windows 視窗與熱鍵）。第六節是已完成的舊跨平台項目，不要重做。第九節 Azure 已實作，真機驗證仍另計，不是這次範圍。

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

> 本段保留最初 UI 規劃，精確尺寸與元件命名不再作現行契約。現行使用 `_StatsSummaryCard` 與 `historyStatsProvider` 讀取 `history_stats.json` 的累計統計，不是 `records.length`／現存列表總和；單筆刪除與過期清除不扣累計，`clearAll()` 才重設。下方 `_StatsSummaryBar`、getter 與公式屬舊規劃，不應據此修改現在的累計行為。

- [x] 建立 `HistoryPage`（`lib/features/history/presentation/pages/history_page.dart`）
  - 列表顯示，最新在上；每筆顯示：日期時間、文字預覽（最多 2 行）、操作按鈕列、刪除按鈕
  - **操作按鈕列**（每筆記錄右側）：
    - **播放 / 停止按鈕**：切換播放狀態；macOS 用 `Process.start('afplay', [path])` + `.kill()` 停止；Windows 用預設媒體應用播放、不可由 App 控制停止（見 7.7）
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
- [x] `providers.json` 保留為後備 provider/model 目錄（`assets/config/providers.json`，目前含 OpenAI、Gemini、Azure）
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

## 🟦 九、Azure OpenAI Whisper Provider（歷史實作；非本次分支範圍）

> 分支：`azure-openai-whisper`。新增 Azure 作為第三個語音辨識 Provider，走 Azure OpenAI 部署的 Whisper。
> 使用者只需自行填寫 **Service Endpoint、API Key、API Version**（皆為必填）。
> 依 Owner 指示：**不做 Whisper 過濾**（企業私有部署 endpoint/token 本就對應 Whisper 服務），refresh 直接列出部署清單。

### 9.1 需求與 UX
- [x] Provider 列新增 `Azure`（label 直接叫「Azure」）
- [x] 選 Azure 後，通道只顯示「官方」（隱藏 Proxy 並強制 `SpeechChannel.official`）
- [x] 憑證區改為 Azure 專用三欄（皆必填）：**Service Endpoint**、**API Key（Access Token）**、**API Version**
- [x] 預設提供 `OpenAI Whisper (whisper)` 模型選項，亦可點擊「更新模型目錄」向 Azure 查詢可用部署與模型
- [x] 隨時提供「手動指定自訂部署名稱」入口，即使企業有自訂部署名稱也能直接填寫並使用
- [x] 查不到部署時自動退回內建清單或提供手動輸入，絕不阻塞轉寫設定

### 9.2 技術細節（原規劃與後續補充）

> 2026-09-29 核對：現行清單依序嘗試 deployments、`/openai/models`、`/openai/v1/models`，失敗／空清單繼續下一個來源；Endpoint 正規化為 origin，不只刪除末尾斜線。以下部署端點說明為其中一條路徑，並非唯一來源。
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
- [x] `assets/config/providers.json` 新增 `azure` provider（提供預設 OpenAI Whisper 模型，亦支援 refresh 與手動自訂部署名稱）
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

---

## 🚨 十、README 版本更新紀錄未同步（嚴重文件疏漏）

> 發現時間：2026-09-17。GitHub 專案首頁（README）的「版本更新紀錄」停在 **v1.3.0**，但實際已發布 **v1.5.0 / v1.5.1 / v1.5.2**（`pubspec.yaml` 為 `1.5.2+8`）。沒有 v1.4.x tag。

- **現象**：訪客在 GitHub 第一頁看到的當前版本仍是 v1.3.0；Releases 頁與 `RELEASE_NOTES.md` 已是 v1.5.2。
- **原因**：發布流程只更新 `pubspec.yaml` 與 `RELEASE_NOTES.md`（CI 用後者當 Release body），沒有同步 `README.md` 的版本更新紀錄。
- **處理**：
  - [x] 於 `README.md` 補齊 v1.5.0、v1.5.1、v1.5.2，並將「當前版本」改為 v1.5.2
  - [x] 於 `CLAUDE.md` 寫入發布文件三處同步規則，避免再犯

---

## 🪟 十一、Windows 視窗框與全域熱鍵（v1.5.3 修復與驗證紀錄）

> 規格來源：`Docs/Plan.md`。Owner 在 Windows 實體機確認兩個問題：主視窗不能拖、不能縮、不能關；設定頁熱鍵不能成功設定，因此無法開始錄音。
> 根因已在 Plan 寫明。本節是實作清單。全部做完且驗證全綠才算完成。不要只改視窗、熱鍵卻留下失敗測試。
>
> 分支：從乾淨的 `master` 開 `fix/windows-window-chrome-and-hotkey`。
> 原實作階段不升版；2026-09-29 使用者另行授權升至 `1.5.3+9`、同步 README / RELEASE_NOTES、commit、推送分支並開 PR。不建立 release tag、不自動合併。
> macOS 的隱藏標題列、Alt+Space 預設熱鍵、`hotkey_manager` 註冊路徑維持不變。
> 核對原則：下列「現況」描述保留為修復前問題；`[x]` 需有實作／測試證據，不代表 Windows 已實機驗證。2026-09-29 已撤回先前靠全域 analyzer ignore 得出的全綠判定，並補上真實 controller / Shell 測試。詳細缺陷與驗證紀錄見 `Docs/Windows-Hotkey-Audit.md`。

### 11.1 視窗策略純函式與測試

- [x] **新增可單測的視窗策略，不要把分支寫死在 `dart:io` 的 `Platform` 上**
  - 新增 `lib/core/window/window_chrome_policy.dart`。
  - 輸入用 `TargetPlatform` 或自訂 enum，正式呼叫端再把 `Platform.isWindows` / `Platform.isMacOS` 轉成這個輸入。widget test 無法翻轉 `dart:io` 的 `Platform`。
  - 回傳至少要能表達：
    - `titleBarStyle`：Windows = `TitleBarStyle.normal`；macOS = `TitleBarStyle.hidden`。
    - `showInAppHeader`：Windows = `false`；macOS = `true`。那條高 44 的「Zero Type」就是這個 header。
    - `preventClose`：兩個桌面平台都是 `true`。
  - 不回傳自訂最小化、最大化、關閉按鈕。Windows 用系統標題列。
- [x] **測試 `test/window_chrome_policy_test.dart`，每個平台分支都要斷言**
  - Windows：原生標題列、不顯示假標題、要攔截關閉。
  - macOS：隱藏標題列、顯示假標題、要攔截關閉。
  - 若函式還處理 Linux 或其他值，測它不會被誤判成 Windows。
  - 這一檔的分支都要被執行到。不接受只測 Windows。

### 11.2 套用原生標題列與關閉收進系統匣

- [x] **改 `lib/main.dart` 的 `_initWindowManager()`**
  - 現況：所有平台都是 `TitleBarStyle.hidden`、`center: true`、`Size(900, 650)`、`minimumSize: Size(700, 500)`、`title: 'ZeroType'`。
  - 改成使用 11.1 的策略。Windows 變成 `TitleBarStyle.normal`。macOS 仍是 `hidden`。
  - size、minimumSize、center、title、backgroundColor、skipTaskbar 維持。
  - `windowOptions` 不能再是全域 `const` 時就不要硬留 `const`。
  - 在 `waitUntilReadyToShow` 的 callback 裡、`show()` 之前，呼叫 `await windowManager.setPreventClose(true)`。兩個平台都要。現況全專案沒有這行，所以 Windows 的關閉會落到 `windows/runner/main.cpp` 的 `SetQuitOnClose(true)`，`WM_DESTROY` 時行程直接結束。
- [x] **`onWindowClose` 維持 `windowManager.hide()`**
  - 不要改成 `exit(0)`。結束行程只保留系統匣「結束 ZeroType」那條路（`_AppInitializerState._quit`）。
  - `windows/runner/main.cpp` 的 `SetQuitOnClose(true)` 不要刪。攔截關閉之後，正常按關閉不會走到 `WM_DESTROY`；系統匣結束仍用 `exit(0)`。
- [x] **改 `lib/shared/widgets/main_shell.dart`**
  - Windows 不建置高度 44 的「Zero Type」`Container`，也不建置它正下方那條 `Divider`。
  - macOS 這兩塊維持原樣、原樣式。
  - 判斷同樣走 11.1，不要在 widget 裡直接寫無法被測試翻轉的邏輯後就沒有測試。
- [x] **不要做的事**
  - 不要加 `DragToMoveArea` 或自繪最小化、最大化、關閉按鈕。原生標題列就是這次的修法。
  - 不要改 `RecordingOverlay`、權限對話框文案、NavigationRail。

### 11.3 熱鍵組合純邏輯與測試

- [x] **新增 `lib/core/hotkey/hotkey_combo.dart`**
  - 責任只有組合鍵資料與規則，不呼叫 `hotkey_manager`、不碰 MethodChannel。
  - 能從 `List<PhysicalKeyboardKey>` 得到結果。修飾鍵是 Control、Alt、Shift、Meta 的左右鍵。最後一個非修飾鍵是主鍵。
  - 沒有主鍵時回傳失敗，原因要能區分「只有修飾鍵」與「什麼都沒按」。不要只回傳 `null` 讓 UI 無話可說。
  - 兩個以上非修飾鍵時，沿用現況：最後一個當主鍵。
  - 預設組合：
    - macOS：Alt+Space。
    - Windows：Ctrl+Shift+Space。
  - Windows 保留組合，命中就失敗，不得進入註冊：
    - 沒有任何修飾鍵。
    - Alt+Space。
    - Alt+F4。
    - Ctrl+Esc。
    - 含 Ctrl+Alt+Delete。
  - macOS 不使用這份保留清單。Alt+Space 在 macOS 是合法預設。
  - 顯示名稱函式：
    - Windows：`Ctrl`、`Alt`、`Shift`、`Win`，主鍵 Space 顯示 `Space`，字母大寫。
    - macOS：`⌃ Control`、`⌥ Option`、`⇧ Shift`、`⌘ Command`，與現在設定頁徽章一致。
  - virtual-key 函式只給 Windows 註冊用，數值固定如下，並為每個列舉的鍵寫測試：
    - Space = 32
    - 0–9 = 48–57
    - A–Z = 65–90
    - Escape = 27
    - F1–F12 = 112–123
  - 不在上表的主鍵，virtual-key 函式回傳失敗，讓 UI 要求換鍵。不要把 `null` 送到 C++。
  - 修飾鍵 flag 字串只輸出 `control`、`shift`、`alt`、`meta`，順序固定，方便測試。
- [x] **與既有持久化相容**
  - `SharedPreferences` 鍵名維持 `global_hotkey`（`HotkeyService` 與 `AppConstants.hotkeyKey` 現在都是這個字串）。
  - 仍用 `hotkey_manager` 的 `HotKey.toJson()` / `HotKey.fromJson()` 產生與讀取 JSON。不要自創另一種 map。
  - 提供函式把純邏輯組合轉成 `HotKey`（`scope` 仍是 `HotKeyScope.system`），以及從 `HotKey` 轉回純邏輯組合。
- [x] **測試 `test/hotkey_combo_test.dart`，下面每一條都是獨立斷言**
  - 空列表失敗。
  - 只有 Shift 失敗，原因是只有修飾鍵。
  - 左右 Alt 都視為 Alt。左右 Control、Shift、Meta 同樣。
  - Alt+Space 在 macOS 成功，在 Windows 失敗。
  - Ctrl+Shift+Space 在 Windows 成功，virtual-key 是 32，修飾鍵是 control 與 shift。
  - Alt+F4、Ctrl+Esc、Ctrl+Alt+Delete 在 Windows 失敗。
  - 沒有修飾鍵的單一字母在 Windows 失敗，在 macOS 成功。
  - A 的 virtual-key 是 65，0 是 48，F1 是 112，F12 是 123，Escape 是 27。
  - 未支援的主鍵（例如方向鍵，若沒有列進表）取 virtual-key 失敗。
  - Windows 顯示字串含 `Ctrl`、`Alt`、`Win`，不含 `Option`、不含 `⌘`。
  - macOS 顯示字串含 `⌥ Option` 與 `⌘ Command`。
  - 預設組合：Windows 是 Ctrl+Shift+Space，macOS 是 Alt+Space。
  - 轉成 `HotKey` 再轉回，主鍵與修飾鍵相同。
  - `HotKey.toJson()` 再 `HotKey.fromJson()` 後仍得到同一組主鍵與修飾鍵。

### 11.4 可注入的熱鍵註冊器

- [x] **新增註冊器介面，例如 `lib/core/hotkey/global_hotkey_registrar.dart`**
  - `register` 回傳成功或失敗。失敗要帶得回 UI 的原因字串。禁止用未檢查的 `void`。
  - `unregisterAll`。
  - 註冊時附上觸發 callback。同一時間只保留一組。
- [x] **macOS 實作包住現有 `hotKeyManager`**
  - 仍使用 `HotKeyScope.system`。
  - 不要改 macOS 原生碼。
  - `hotkey_manager` 在 macOS 若丟出例外，轉成失敗結果，不要讓設定頁變成未處理例外。
- [x] **Windows 實作不要呼叫 `hotkey_manager.register`**
  - 改呼叫 11.5 的 MethodChannel。
  - 收到 EventChannel 事件時呼叫 callback。
  - channel 回傳 `false` 或 `PlatformException` 都是失敗，訊息保留 `GetLastError` 數字，讓上層可以顯示。
- [x] **測試用假註冊器**
  - 可設定下一次 `register` 成功或失敗。
  - 記錄 `register` 與 `unregisterAll` 的呼叫順序與參數。
  - 可手動觸發 callback，用來斷言熱鍵會叫到 `toggleRecording` 的那層 callback。

### 11.5 改 `HotkeyService` 使用註冊器

- [x] **檔案：`lib/core/services/hotkey_service.dart`**
  - 建構子改為接收 registrar，或由 `lib/core/di/injection.dart` 依平台注入。GetIt 註冊處要一起改。
  - `initialize`：
    - 讀 `global_hotkey`。JSON 壞掉就用該平台預設，並寫 log。
    - macOS：註冊讀到的組合；註冊失敗就保留預設並讓呼叫端知道。既有 Alt+Space 必須仍會被註冊。
    - Windows：讀到保留組合，或註冊失敗時，改為 Ctrl+Shift+Space，寫回 preferences，再註冊這一組。不要對 Alt+Space 呼叫原生註冊。
  - `updateHotkey`：
    - 先註冊新組合。
    - 成功才更新記憶體中的目前熱鍵並 `setString`。
    - 失敗不寫入新組合，並重新註冊舊組合。回傳失敗原因。
    - 現況是先 `unregisterAll`、改記憶體、寫 preferences，再視 `_isPaused` 決定是否註冊。這個順序會在註冊失敗時把壞組合存下去，必須改掉。
  - `pause`：仍在錄製前解除全部註冊，並立刻把暫停旗標設上，避免進行中的 callback 又開始錄音。
  - `resume`：只註冊目前有效組合，然後才清除暫停旗標。
  - `dispose`：解除註冊。
- [x] **測試 `test/hotkey_service_test.dart`，使用假 registrar 與記憶體版 preferences 或可替換的儲存**
  - 若 `SharedPreferences` 不好在單元測試建立，把讀寫抽成小介面再注入。不要為了測得到去起一整個 Flutter binding 卻仍碰真實 channel。
  - 案例：
    - 沒有舊資料時，macOS 註冊 Alt+Space，Windows 註冊 Ctrl+Shift+Space。
    - Windows 舊資料是 Alt+Space 時，不註冊 Alt+Space，改註冊並存下 Ctrl+Shift+Space。
    - `updateHotkey` 成功：preferences 變成新組合，registrar 最後註冊的是新組合。
    - `updateHotkey` 失敗：preferences 仍是舊組合，registrar 最後註冊的是舊組合，失敗原因有回傳。
    - `pause` 呼叫 `unregisterAll`；暫停期間 `updateHotkey` 只暫存待驗證候選，不註冊，也不覆寫目前有效鍵或 preferences；`resume` 註冊成功後才提交新組合。此為遵守 Plan「註冊成功才儲存」的安全解讀，不可把候選當成已儲存成功。
    - `resume` 在未暫停時不會重複註冊。
    - 假 registrar 觸發 callback 時，服務有把呼叫轉給 `setCallback` 設上的函式。
    - callback 在暫停期間若仍被呼叫，服務不得再轉給外層。

### 11.6 Windows 原生 `RegisterHotKey`

- [x] **擴充 `windows/runner/channel_handler.h` 與 `channel_handler.cpp`**
  - 維持現有 `com.zerotype.app/keyboard`、`permission`、`overlay`、`control` 行為不變。
  - 新增 MethodChannel `com.zerotype.app/hotkey`：
    - `register`：引數 `vk`（int）與 `modifiers`（string list）。
    - `unregisterAll`。
  - 新增 EventChannel `com.zerotype.app/hotkey_events`。
  - 熱鍵 id 固定為 `1`。`register` 前先 `UnregisterHotKey` 同一個 HWND 與 id。
  - `RegisterHotKey` 的 modifier 是 list 轉成的 `MOD_ALT` `0x0001`、`MOD_CONTROL` `0x0002`、`MOD_SHIFT` `0x0004`、`MOD_WIN` `0x0008`，再 OR `MOD_NOREPEAT` `0x4000`。
  - HWND 用 root window。`flutter_window.cpp` 在 `OnCreate` 裡 `SetupChannels` 時，把 `FlutterWindow` 的 HWND 傳進 channel handler，或在第一次 `register` 時從 registrar 取 root。不要用一個尚未建立的 HWND。
  - `RegisterHotKey` 回傳 `FALSE`：不要記錄這個 id 為已註冊，`FlutterError` 的 code 用 `hotkey_register_failed`，message 含 `GetLastError()` 十進位數字，details 可放 vk 與 modifiers。Method result 不要回 `true`。
  - `RegisterHotKey` 回傳成功才回 `true`。
  - 未知 modifier 字串直接失敗，不要默默忽略。
- [x] **在 `windows/runner/flutter_window.cpp` 的 `MessageHandler` 處理 `WM_HOTKEY`**
  - 轉給 channel handler。若是我們的 id `1`，對 EventChannel sink 送出事件，並回傳 `0`。
  - 還沒有 listener 時不要崩潰。
  - 其他訊息仍走原本的 `HandleTopLevelWindowProc` 與 `Win32Window::MessageHandler`。
- [x] **CMake**
  - `channel_handler.cpp` 已經在 `windows/runner/CMakeLists.txt`。不要新增 cpp 卻忘了加進 `add_executable`。若邏輯都放在既有 cpp，就不要改 CMake。
- [x] **原生程式這次沒有可在 macOS 執行的 C++ 測試**
  - 不要為了覆蓋率去建一套跑不起來的 gtest。
  - Dart 側 11.3 與 11.5 必須覆蓋所有會送到原生層的參數組合與失敗回滾。
  - 真實 `RegisterHotKey` 是否生效，只放在 11.9 的 Windows 手動清單。

### 11.7 設定頁錄製、文案與生命週期

- [x] **改 `lib/features/settings/presentation/pages/settings_page.dart`**
  - `_HotkeyRecorderOverlay` 不要再用 `KeyboardListener` 與 `FocusNode` 當唯一的按鍵來源。
  - 在 `initState` 註冊 `HardwareKeyboard.instance.addHandler`，`dispose` 一定移除。handler 回傳 `false`，不要吃掉與錄製無關的系統行為；但 Esc 單獨按下要呼叫取消。
  - 覆蓋層改掛在會蓋住整個主視窗的那一層。現在它在設定頁 `Stack` 裡，只蓋住右側內容。可改由 `MainShellPage` 或 `lib/main.dart` 的外層 `Stack` 顯示，條件仍是 `isRecordingHotkey`。不要讓 NavigationRail 在錄製時還能被點到而把頁面切走。
  - 按鍵徽章改呼叫 11.3 的顯示函式。Windows 不得再出現 `⌥ Option` 或 `⌘ Command`。
  - 儲存鈕呼叫 controller 後，若結果是失敗，顯示 SnackBar，文案使用 Plan 裡的兩句繁體中文（只有修飾鍵、以及系統保留或被占用）。目前熱鍵徽章維持舊組合。
  - 成功才顯示新組合；失敗若已恢復舊鍵，可依 Plan 關閉覆蓋層並顯示 SnackBar。舊鍵也無法恢復時保持暫停、保留覆蓋層與失敗原因，不宣稱熱鍵可用。
- [x] **改 `lib/features/settings/presentation/controllers/settings_controller.dart`**
  - `startRecordingHotkey`：先 `HotkeyService.pause()`，再把 `isRecordingHotkey` 設為 `true`。
  - `stopRecordingHotkey`：`isRecordingHotkey` 設為 `false`，並 `resume()` 舊熱鍵。
  - `saveHotkey`：先走 11.3 的解析。解析失敗不得對候選鍵呼叫 registrar 或寫入 preferences；為恢復錄製前的有效鍵，允許重新註冊舊鍵，回傳原因並依 SnackBar 契約處理。
  - 解析成功才 `updateHotkey`。registrar 失敗時同樣不得更新畫面上的熱鍵。
  - 刪除「先寫入熱鍵、失敗也不告訴 UI」的路徑。
- [x] **生命週期不得清掉錄製**
  - `settings_page.dart` 的 `didChangeAppLifecycleState` 在 `resumed` 時，現在會 `_invalidateSettings()`。這會讓 `build()` 產生一份 `isRecordingHotkey == false` 的新狀態，Windows 按 Alt 時覆蓋層會消失。
  - 改為呼叫已存在的 `refreshPermissions()`。
  - 若當下 `isRecordingHotkey` 已是 `true`，不要 invalidate，也不要 `refreshPermissions()`。
  - `initState`、`didPush`、`didPopNext` 若仍要重讀權限，用 `refreshPermissions()`，不要用會重置錄製旗標的 `invalidate`。
- [x] **widget 測試 `test/hotkey_recorder_test.dart`**
  - 用 `tester.sendKeyDownEvent` / `sendKeyUpEvent` 或等同方式驅動 `HardwareKeyboard` handler。
  - 覆蓋層出現後，按下 Control、Shift、Space，畫面文字含 Windows 或由測試注入的平台標籤，且含 Space。
  - 只按下 Shift 再按儲存，不會出現成功儲存；找得到失敗文案。
  - 只按下 Escape，覆蓋層關閉，沒有儲存。
  - 注入 Windows 平台時，Alt+Space 不能變成已儲存熱鍵，且找得到保留鍵文案。
  - 注入 macOS 平台時，Alt+Space 的顯示含 Option，且可以被視為合法組合。若儲存路徑需要 registrar，使用 11.4 的假註冊器讓它成功。
  - 測試結束後 handler 不得殘留。連續跑兩次測試不能因此收到兩次按鍵。

### 11.8 把策略接到正式啟動路徑

- [x] **`lib/core/di/injection.dart` 注入平台對應的 registrar 與 `HotkeyService`**
  - macOS 用 `hotkey_manager` 實作。
  - Windows 用 channel 實作。
  - 測試可改註冊假 registrar，不影響正式 `main()`。
- [x] **確認 `lib/main.dart` 的 `_onHotkeyActivated` 仍只呼叫 `toggleRecording()`**
  - 不要在熱鍵 callback 裡加第二段錄音邏輯。
- [x] **搜尋確認 Windows 路徑沒有再呼叫 `hotKeyManager.register`**
  - macOS 路徑仍要呼叫。
  - 這條用測試或程式結構保證：Windows registrar 的型別不依賴 `hotkey_manager` 的 `register`。

### 11.9 驗證、修到全綠、手動清單

- [x] **在本機重複執行，直到全部通過。失敗就修，然後從失敗的那一項重跑，最後再整批跑一次**
  - `dart format --output=none --set-exit-if-changed lib test`
  - `flutter analyze`
  - `flutter test`
  - 不使用 `--exclude` 跳過這次新增的測試。
  - 既有 `test/widget_test.dart`、`test/azure_speech_service_test.dart`、`test/antigravity_auth_source_test.dart`、`test/official_model_catalog_service_test.dart` 必須仍通過。
  - 2026-09-29 最終重跑：format 73 files / 0 changed；analyze No issues found；flutter test 109 個通過。三個原始指令皆 exit 0，未用 no-fatal／skip／exclude。
- [x] **覆蓋率**
  - `flutter test --coverage --branch-coverage --coverage-path=coverage/lcov.info` 實測：`window_chrome_policy.dart` 行 10/10、分支 6/6；`hotkey_combo.dart` 行 153/153、分支 88/88。其他檔案不宣稱 100%。
  - `window_chrome_policy.dart` 與 `hotkey_combo.dart` 的每個分支都有對應斷言。
  - `HotkeyService` 的成功、失敗回滾、pause、resume、暫停期間 callback、Windows 保留預設，都有測試。
  - 錄製 widget 的成功路徑、只按修飾鍵、Esc、Windows 保留鍵、macOS 合法 Alt+Space，都有測試。
  - 不要為了數字去給未改動的 Azure、OAuth、轉寫服務補測試。那不是這次範圍。
  - 不要把 C++ `RegisterHotKey` 算進 Dart 覆蓋率，也不要因此宣稱 Windows 實機已測過。
- [ ] **Windows 實體機手動清單：未在 Windows 執行**
  - 本機為 macOS；使用者本次沒有明確提供 Windows 逐項測試紀錄，以下 11 項全部保留未驗證，不由 macOS widget 平台模擬推定通過。
  1. 啟動後有系統標題列「ZeroType」，內容區沒有第二條「Zero Type」。
  2. 拖標題列可移動。
  3. 拖邊緣可調整大小，不能小於 700×500。
  4. 最小化可從工作列叫回；最大化可還原。
  5. 關閉後行程仍在，系統匣還在，視窗消失；「顯示視窗」可再開；「結束 ZeroType」才結束行程。
  6. 設定頁預設熱鍵顯示 Ctrl+Shift+Space，不是 Option。
  7. 錄製 Ctrl+Shift+Space 並儲存後，在其他 App 按下可開始錄音，再按可停止。
  8. 只按 Shift 不能儲存，且有錯誤說明。
  9. Alt+Space 與 Alt+F4 不能成為有效熱鍵，舊的有效熱鍵仍可觸發。
  10. 錄製中按 Alt，覆蓋層不消失。
  11. 熱鍵啟動錄音時，既有 Windows 底部錄音覆蓋層仍出現，Esc 仍可取消。
- [x] **macOS 使用者人工測試回報（2026-09-29；先前提供的自簽測試版）**
  - 使用者回報：「人工測試的部分目前都完成，沒有發現什麼太大的問題」。這是使用者回報，不是 agent 逐項操作紀錄；也不涵蓋本次複查後新增的修正。新版另以自動化回歸測試與建置驗證，後續仍可人工複驗。
  - 標題列仍是隱藏樣式，交通燈還在，44px「Zero Type」還在。
  - 紅燈關閉後 App 不結束，選單列可再打開視窗。
  - 預設或已儲存的 Alt+Space 仍可開始與停止錄音。
  - 做不到就寫「未在 macOS 手動確認」，不要留空。

### 11.10 交接

- [x] 複查報告：`Docs/Windows-Hotkey-Audit.md`，記錄之前的 macOS 回歸、測試假陽性、analyzer 規則遮蔽、修正證據與未測範圍。
- [x] 新增真實 controller／Shell 與 registrar channel 測試；補上取消恢復、保存失敗、合成放鍵、最小視窗、背景焦點與可見錯誤。
- [x] `1.5.3+9` 同步至 pubspec、README、RELEASE_NOTES；新增 PR checks（Dart 檢查與 Windows build），CI 結果另看 PR。
- [x] 首次 Windows CI 發現 C4456／C2220 區域變數遮蔽，已以 `value32`／`value64` 修正；不關閉 `/WX`。首次 run `36456656040` 的 Dart gates 通過，Windows 編譯失敗；補正後結果另行追蹤。
- [x] 本機 macOS Release 重新建置 1.5.3 (9)，以 ZeroType 自簽憑證簽署並通過驗證 script，架構 x86_64 arm64。不代表 Apple notarization，也未重跑人工操作。

- [x] **完成時在回覆裡列出**
  - 分支名稱與改到的檔案。
  - `dart format`、`flutter analyze`、`flutter test` 的結果。測試數量以指令輸出為準，不要手寫一個沒跑過的數字。
  - Windows 手動清單 11 項各自是通過、失敗已修、或未執行。
  - macOS 手動確認是通過或未執行。
  - 已知未做事項只允許兩種：沒有 Windows 機器所以沒跑手動清單、沒有改 macOS 實機。其他未完成項視同這次沒做完，繼續修。
