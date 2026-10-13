# CLAUDE.md

本文件提供 Coding Agent 在此倉庫工作的架構、實作與驗證指引。

## 專案概覽

ZeroType 是一套 Flutter 桌面系統列（system tray）應用，支援 macOS 與 Windows。使用者按下全域快捷鍵後開始錄音，音檔會送到 OpenAI、Gemini 或 Azure OpenAI Whisper 的語音轉寫 API，轉寫結果與音檔存入本機歷史紀錄，文字複製到剪貼簿，再透過原生平台橋接模擬貼上到先前聚焦的應用程式。使用者介面文案以繁體中文為主。

實作程式碼才是真相來源。`Docs/Requirement.md` 與 `Docs/Tasks.md` 保留歷史規劃，部分敘述已過時：目前沒有獨立的 AI 精修階段，API Key 存在 `SharedPreferences`，不是安全儲存。

本輪文件同步對應 `1.5.5+13`。版本、測試與建置必須以本次提交的實際結果核對；`1.5.4` 各 build 的驗證紀錄保留於 `Docs/task.md`，不能視為新版已完成驗證或發布。

## 語言與協作慣例

文件、對話與程式註解一律使用繁體中文（zh-TW）。下列專有名詞維持原文，不要翻譯：

- 產品與平台：ZeroType、Flutter、Dart、macOS、Windows、NSPanel、SendInput、CGEvent
- 套件與工具：Riverpod、GetIt、AutoRoute、Freezed、Dio、build_runner、SharedPreferences、MethodChannel
- 供應商與模型：OpenAI、Gemini、Azure、`gpt-4o-transcribe`、provider / model id

此語言慣例與 `.agents/rules/flutter-desktop.md` 一致。識別碼、型別、檔名、目錄名與 API 名稱仍維持英文。

## 工具鏈與常用指令

`pubspec.yaml` 要求 Dart `^3.11.0`。請使用內建 Dart 3.11 或更新版本的 Flutter；Flutter 3.38.7 / Dart 3.10.7 無法解析此專案。目前 `.github/workflows/checks.yml` 與 `release.yml` 固定使用 Flutter 3.47.0。`pubspec.lock` 刻意被 `.gitignore` 忽略。

```bash
# 安裝依賴
flutter pub get

# 執行桌面應用（Windows 指令必須在 Windows 主機上執行）
flutter run -d macos
flutter run -d windows

# 建置正式版
flutter build macos
flutter build windows

# 靜態分析與格式化
flutter analyze
dart format lib test
dart format --output=none --set-exit-if-changed lib test

# 跑全部測試、單一檔案，或單一測試名稱
flutter test
flutter test test/path/to_test.dart
flutter test test/path/to_test.dart --plain-name 'test name'

# 重新產生 Riverpod、Freezed、AutoRoute 輸出
dart run build_runner build
# 大量改 annotation 時可改用 watch
dart run build_runner watch

# 更換 assets/icons/icon.png 後重新產生 launcher icon
dart run flutter_launcher_icons
```

測試定位：`test/widget_test.dart` 覆蓋 `SpeechConnectionState.isReady`，不是 Flutter 預設計數器測試。模型目錄與頁面測試另在 `model_catalog_controller_test.dart`、`model_config_page_test.dart`；Gemini 回應回放在 `gemini_speech_recognition_test.dart`。

## 架構

### 啟動與應用殼層

`lib/main.dart` 是組合根：

1. 初始化 `window_manager` 與主視窗。
2. 呼叫 `lib/core/di/injection.dart` 的 `configureDependencies()`。
3. 設定開機啟動，並建立根 Riverpod `ProviderScope`。
4. `_AppInitializer` 啟動全域快捷鍵與系統列服務、清除過期歷史，並在關閉主視窗時隱藏而非退出。

主畫面是 AutoRoute 分頁殼。`lib/core/router/app_router.dart` 宣告路由，`lib/shared/widgets/main_shell.dart` 必須讓 `AutoTabsRouter` 順序與 `NavigationRail` 索引同步。調整分頁順序時，兩個檔案以及硬編碼索引（例如權限提示跳到設定頁）都要一起改。

狀態分兩層：

- GetIt 持有長生命週期基礎設施單例（`SharedPreferences`、`Dio`、轉寫 / 快捷鍵 / 系統列 / 音效、Antigravity 憑證引用、Antigravity OAuth 登入、官方與 Proxy 模型目錄、模型設定 repository，以及歷史 repository）。
- Riverpod provider / controller 持有功能與 UI 狀態，多數使用產生碼；`modelCatalogProvider` 是手寫的 `NotifierProvider`。部分功能 repository 由 Riverpod 直接建構；模型設定 controller 目前也直接建立 `ModelConfigRepositoryImpl`，並未取用 GetIt 中的同型別 repository。改動時應核對實際使用路徑，不能只因註冊於 GetIt 就假設所有呼叫都經過該實例。

功能大致遵循 `features/<feature>/{domain,data,presentation}`：介面在 `domain`、實作在 `data`、Riverpod controller 與頁面在 `presentation`。跨功能的錄音與轉寫編排刻意放在 `lib/core/controllers/zero_type_controller.dart`。

### 錄音到貼上的流程

`ZeroTypeController` 是中央狀態機（`idle → recording → saving → transcribing → done/error`）：

1. `HotkeyService` 透過 `_AppInitializer` 呼叫 `toggleRecording()`。
2. Controller 驗證使用中通道與使用中憑證，並請求麥克風與平台輔助使用權限。
3. `RecordingService` 把 16 kHz AAC/M4A 寫進暫存目錄，並串流正規化後的振幅。
4. 再按一次快捷鍵結束錄音。Controller 把自訂或預設語音提示詞與字典提示詞合併。
5. `SpeechRecognitionService` 依 Provider、通道與使用中憑證組 URL。官方 Gemini API Key 使用 `generativelanguage.googleapis.com` 與 `x-goog-api-key`；Antigravity OAuth 走 Cloud Code 的 `v1internal:generateContent`，payload 包含原始 model ID、project 與內層 request，使用 OAuth Bearer。Proxy 打 `{根}/v1beta/models/{model}:generateContent` 或 OpenAI 的 `{根}/v1/audio/transcriptions`。Azure 僅官方通道，打 `{endpoint}/openai/deployments/{deployment}/audio/transcriptions?api-version={ver}`，認證用 header `api-key`。失敗不切換 API Key／OAuth 憑證方式或官方／Proxy 通道。
6. 有非空逐字稿時，音檔移到持久化歷史目錄，寫入 `TranscriptionRecord`，再用 `model_pricing.dart` 累加花費統計。回傳空文字時走既有錯誤流程並刪除該暫存檔，不寫入歷史；不能概括為所有成功或失敗錄音都會立即刪除。
7. 以 Flutter clipboard API 複製結果，再由原生 `keyboard` channel 模擬 Cmd+V 或 Ctrl+V。

Gemini 官方／Proxy 與 Antigravity 的文字提取共用 `lib/core/services/gemini_transcription_response.dart` 的 `extractGeminiTranscriptionText`。只處理第一個 candidate，依序串接其中非 `thought: true` 的 String 文字 parts，保留片段間原有空白、最後才 trim；不能只取 `parts[0]`，也不能把多個 candidates 合併成逐字稿。`thoughtSignature` 不是思考段落標記，帶簽章的可見文字仍應保留；簽章與思考內容不能進入逐字稿或錯誤訊息。

`finishReason` 為 `STOP` 才明示正常完成；為相容省略該欄位的回應，缺省／null 仍可提取文字。明確提供的空字串、`FINISH_REASON_UNSPECIFIED` 與其他未完成原因不能當成功；封鎖、`MAX_TOKENS`、缺候選、沒有可讀文字或只有思考內容使用 `GeminiTranscriptionException` 的固定訊息。存在可見 String 但全部空白、且沒有 thought 的回應仍回傳空字串，交由既有空結果流程處理，這不證明音檔真的無聲。本修補不改音訊 payload（目前仍使用 `inline_data`／`mime_type`）、提示詞、model ID 或請求重試策略。

Gemini／Antigravity 成功日誌只記 token 用量，不列出逐字稿；Gemini HTTP 錯誤日誌記 Dio 類型與狀態碼，Antigravity 授權讀取／更新的例外日誌記型別。目錄與 Gemini 解析錯誤使用固定分類訊息。維護時不得重新記錄完整模型回應、思考文字、簽章或憑證；上述範圍也不代表應用程式完全不記錄路徑或其他錯誤。

歷史診斷：2026-10-14 以約 4.5 秒合成英文語音在 `gemini-3.5-flash-lite`／Antigravity 重現 HTTP 200 `STOP`、首段空白 thought、第二段為逐字稿的回應；原使用者錄音未讀取、未上傳。完整證據及限制見 `Docs/task.md` 的 build 11 紀錄，不代表逐模型實測。build 10 的 175 個、build 11 的 212 個、build 12 的 213 個測試與舊提交 CI 均為歷史結果，不能代替 `1.5.5+13` 的最終檢查。

取消可能來自快捷鍵、Esc 或 overlay 關閉按鈕。改這段流程時，必須同步 `_cancelled`、timer 清理、錄音器清理、音效 / 背景音樂恢復、Riverpod 狀態與 overlay 顯示。

### 視窗與全域熱鍵

`WindowChromePolicy` 使用可測試的 `TargetPlatform`：Windows 為原生標題列，macOS 保留 hidden 與 44px 內建標題。兩平台 `setPreventClose(true)` 後關閉只 hide，退出仍走系統匣。

`HotkeyService` 透過可注入的 `GlobalHotkeyRegistrar` 註冊：macOS 使用 `hotkey_manager`、預設 Alt+Space；Windows 使用 App 自有 RegisterHotKey channel、預設 Ctrl+Shift+Space。`initialize()` 共用 Future，設定 controller 必須等待它；同步 getter 在建構時即可讀取已存組合。錄製前 pause，paused update 只暫存候選，resume 註冊成功才寫入 `global_hotkey`；失敗恢復舊鍵，恢復也失敗時明示 paused，不當作成功。不要改回「先儲存，再試註冊」。

### 原生平台邊界

Dart 與原生 runner 透過這些固定 MethodChannel 名稱溝通：

- `com.zerotype.app/overlay`
- `com.zerotype.app/control`
- `com.zerotype.app/keyboard`
- `com.zerotype.app/permission`
- Windows-only：`com.zerotype.app/hotkey`（MethodChannel）與 `com.zerotype.app/hotkey_events`（EventChannel）；macOS 不走此路徑。

macOS 由 `macos/Runner/AppDelegate.swift` 負責不搶焦點的 `NSPanel` overlay、全域 / 本機 Esc 監聽、輔助使用檢查與系統設定連結、CGEvent Cmd+V 貼上，以及自訂開機啟動 channel。`MainFlutterWindow.swift` 負責註冊這些 channel。

Windows 由 `windows/runner/channel_handler.cpp` 用 `SendInput` 實作 Ctrl+V，把輔助使用權限回報為已授權，並 stub overlay / control channel。可見的 overlay 改由 `lib/shared/widgets/recording_overlay.dart` 的 Windows-only Flutter widget 繪製，因此只會出現在應用視窗內。`flutter_window.cpp` 會呼叫 `SetupChannels`；新增 C++ 原始檔時也必須寫進 `windows/runner/CMakeLists.txt`。

任何 channel 契約變更都必須同時相容 Dart、macOS 與 Windows。channel 之外也有平台分支：例如音效 / 背景音樂控制使用 macOS 的 `afplay` 與 AppleScript，Windows 歷史播放則開啟預設媒體應用。

### 持久化與設定

沒有資料庫。資料分散在打包資產、`SharedPreferences`，以及 `getApplicationSupportDirectory()` 底下的檔案：

- `assets/config/providers.json`：Provider 設定與官方 API Key 通道的內建模型目錄；Antigravity OAuth 的適用內建清單另由 `OfficialModelCatalogService.antigravityModels` 提供，Proxy 不借用官方內建模型。
- `prompts/SpeechToText.prompt`：內建預設轉寫提示詞。
- `SharedPreferences`：provider、使用中通道、各通道的 model / API Key、官方通道憑證方式、Proxy 根位址、Azure Service Endpoint / API Version、主題、快捷鍵、開機 / 音效設定、保留天數與最長錄音時間。Repository 在新鍵未設定時相容讀取舊的 `custom_endpoint_*`、`api_key_speech_<provider>` 等值；這是讀取回退，不是讀取時立即改寫／刪除舊鍵的遷移。
- Antigravity 憑證有兩種來源：(1) 本機既有登入 `~/.cli-proxy-api/antigravity-*.json` 或 `~/.gemini/oauth_creds.json`；(2) App 內「Antigravity OAuth」按鈕觸發 `AntigravityOauthService`，用內建 Antigravity OAuth client（含 `cclog`、`experimentsandconfigs` scope）走 Google 授權，並以 `loadCodeAssist`（`ideType=ANTIGRAVITY`，查不到時 `onboardUser` 輪詢）取得 project id，落地成 `~/.cli-proxy-api/antigravity-<email>.json`。`AntigravityAuthSource` 統一負責讀取與 access 過期續期（refresh 後寫回同一檔）。
- `dictionary.txt`：排序後的自訂字典詞。
- `SpeechToText_Custom.prompt`：使用者覆寫的提示詞。
- `history.json` 與 `history_audio/`：保留的轉寫中繼資料與音檔。
- `history_stats.json`：累計次數與花費。單筆刪除與過期清除不會減少它；`clearAll()` 才會重設。

官方通道有使用中憑證時，`OfficialModelCatalogService` 向官方 models API 查詢（Gemini：`/v1beta/models`；OpenAI：`/v1/models`；Antigravity：`v1internal:fetchAvailableModels`；Azure：依序嘗試部署／模型與 OpenAI 相容端點，不做 Whisper 過濾）。官方與 Proxy 查詢都回傳 `CatalogFetchResult`，合法空目錄是成功，失敗使用安全分類，不能在 HTTP 層以內建清單偽裝成功。

`modelCatalogProvider` 統一管理來源、最後成功時間、更新中狀態、同來源記憶體快取與過期回應防護。查詢情境依 Provider、通道、endpoint 與憑證身分隔離；失敗先保留同來源成功目錄，再使用適合該通道／憑證方式的內建目錄。選 model 只保存選取，不重新初始化授權或查目錄。`AntigravityAuthSource.catalogIdentityFor(auth)` 將同一次授權結果綁定至不含原始 token、帳號或路徑的識別，正常續期保持穩定；只有 access token 且缺乏帳號／refresh token 時保守隔離不同 token。授權更新依憑證 fingerprint 合併，寫回前核對來源快照，過期請求不得覆寫已更換的授權。

`AntigravityAuthSource` 依候選檔案順序取用有效授權，目前沒有固定帳號／檔案的使用者選擇器。等待中的來源快照若被替換或刪除，該次授權直接失敗，不採用另一份新授權補回該請求。目錄必須使用同一次 auth 的 `catalogIdentityFor(auth)`，不能只靠可能已被並行讀取更新的最近一次 getter。新的隔離索引與快取只留在記憶體，使用雜湊與不含機密的 scope 代號；不能把這項改動描述成 token 已改存安全儲存。

模型只按完整 ID 去重；選單及已排除項目只顯示 ID 並按 ID 排序，不再顯示 API `displayName`。供應商回傳的模型名稱仍留在資料層供診斷，但不能透過標題、副標或 tooltip 重新加入模型選單而造成版本混淆；Provider 選擇按鈕仍保留各供應商名稱。Antigravity 依 `supportedMimeTypes` 判斷當前 `audio/mp4` 錄音格式，能力為支援／不支援／未確認；缺 metadata 不能當成不支援。明確不支援的模型不提供新選擇，已選則保留並警示。不要把目錄結果加入 `SpeechConnectionState.isReady`，不要自動改模型、通道或憑證。Azure 保留內建 Whisper 與手動部署入口，Proxy 保留自訂 ID。實作與驗證見 `Docs/task.md`。

模型欄位的收合高度與展開列高分開：`menuItemHeight = textScaler.scale(64).clamp(kMinInteractiveDimension, double.infinity)`；收合外框高度為 `(menuItemHeight + 2) * 0.6`，即比調整前外框縮短 40%。展開列高仍為 `menuItemHeight`，選單上限仍為視窗高度 60%、最多 420。`isDense` 與 `selectedItemBuilder` 的 compact 樣式只將收合文字行高設為 1，保留原字級與能力提示；不能把需求解讀成字體縮小 40% 或展開選項同時縮小。長 ID 使用省略號並以 tooltip 提供完整 ID，不另加供應商回傳的模型名稱。

新增 Provider 或改轉寫分流時，仍要改 `speech_recognition_service.dart` 與 `model_pricing.dart`；不應因同名模型而改寫歷史 ID、價格映射或把不同模型合併。

## 產生程式與倉庫慣例

不要手改 `*.g.dart`、`*.freezed.dart` 或 `*.gr.dart`。這些產生檔有進版控，改 Riverpod annotation、Freezed model 或 AutoRoute 宣告後要跑 build_runner，並把產生出來的 diff 一併提交。

發布版本時必須同時更新這三處，缺一不可：

1. `pubspec.yaml` 的 `version`（語意化版本 + build number）
2. `RELEASE_NOTES.md`（GitHub Actions 會把它當成 Release body）
3. `README.md` 的「版本更新紀錄」：把新版標成「當前版本」，並寫入該版重點

GitHub 專案首頁渲染的是 README，不是 Releases 頁。v1.3.0 之後曾只更新 `RELEASE_NOTES.md`，導致首頁仍顯示 v1.3.0 為當前版本；這是嚴重的文件疏漏，之後不可再犯。沒有獨立的 v1.4.x tag。

`.agents/rules/flutter-desktop.md` 其餘仍適用的重點：

- 識別碼、型別與檔名用英文：class 用 PascalCase、成員用 camelCase、檔案與目錄用 snake_case。
- 參數與回傳值標明明確 Dart 型別。
- 資料盡量不可變；持久化走 repository 介面；業務與 UI 狀態走 Riverpod controller；長生命週期依賴走 GetIt；導航走 AutoRoute；樣式走 `ThemeData`。
- 函式與 widget 保持小而專注；優先 early return、較淺的 widget tree、抽出可重用 widget，並在可行處使用 `const` constructor。
