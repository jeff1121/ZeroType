# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概覽

ZeroType 是一套 Flutter 桌面系統列（system tray）應用，支援 macOS 與 Windows。使用者按下全域快捷鍵後開始錄音，音檔會送到 OpenAI 或 Gemini 的語音轉寫 API，轉寫結果與音檔存入本機歷史紀錄，文字複製到剪貼簿，再透過原生平台橋接模擬貼上到先前聚焦的應用程式。使用者介面文案以繁體中文為主。

實作程式碼才是真相來源。`Docs/Requirement.md` 與 `Docs/Tasks.md` 保留歷史規劃，部分敘述已過時：目前沒有獨立的 AI 精修階段，API Key 存在 `SharedPreferences`，不是安全儲存。

## 語言與協作慣例

文件、對話與程式註解一律使用繁體中文（zh-TW）。下列專有名詞維持原文，不要翻譯：

- 產品與平台：ZeroType、Flutter、Dart、macOS、Windows、NSPanel、SendInput、CGEvent
- 套件與工具：Riverpod、GetIt、AutoRoute、Freezed、Dio、build_runner、SharedPreferences、MethodChannel
- 供應商與模型：OpenAI、Gemini、`gpt-4o-transcribe`、provider / model id

這項規則覆寫 `.agents/rules/flutter-desktop.md` 中「程式與文件一律英文」的要求。識別碼、型別、檔名、目錄名與 API 名稱仍維持英文。

## 工具鏈與常用指令

`pubspec.yaml` 要求 Dart `^3.11.0`。請使用內建 Dart 3.11 或更新版本的 Flutter；Flutter 3.38.7 / Dart 3.10.7 無法解析此專案（Flutter 工具目前建議 Flutter 3.47.0）。`pubspec.lock` 刻意被 `.gitignore` 忽略。

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
dart run build_runner build --delete-conflicting-outputs
# 大量改 annotation 時可改用 watch
dart run build_runner watch --delete-conflicting-outputs

# 更換 assets/icons/icon.png 後重新產生 launcher icon
dart run flutter_launcher_icons
```

已知基準問題：`test/widget_test.dart` 仍是 Flutter 產生的計數器測試，引用不存在的 `MyApp`；它不是有效覆蓋，測試套件健康前需要重寫。

## 架構

### 啟動與應用殼層

`lib/main.dart` 是組合根：

1. 初始化 `window_manager` 與主視窗。
2. 呼叫 `lib/core/di/injection.dart` 的 `configureDependencies()`。
3. 設定開機啟動，並建立根 Riverpod `ProviderScope`。
4. `_AppInitializer` 啟動全域快捷鍵與系統列服務、清除過期歷史，並在關閉主視窗時隱藏而非退出。

主畫面是 AutoRoute 分頁殼。`lib/core/router/app_router.dart` 宣告路由，`lib/shared/widgets/main_shell.dart` 必須讓 `AutoTabsRouter` 順序與 `NavigationRail` 索引同步。調整分頁順序時，兩個檔案以及硬編碼索引（例如權限提示跳到設定頁）都要一起改。

狀態分兩層：

- GetIt 持有長生命週期基礎設施單例（`SharedPreferences`、`Dio`、轉寫 / 快捷鍵 / 系統列 / 音效、Antigravity 憑證引用、Antigravity OAuth 登入、Proxy 模型目錄、模型設定 repository，以及歷史 repository）。
- 產生出來的 Riverpod provider / controller 持有功能與 UI 狀態。部分功能 repository 由 Riverpod 直接建構，沒有註冊到 GetIt；改某個功能時沿用該功能既有模式。

功能大致遵循 `features/<feature>/{domain,data,presentation}`：介面在 `domain`、實作在 `data`、Riverpod controller 與頁面在 `presentation`。跨功能的錄音與轉寫編排刻意放在 `lib/core/controllers/zero_type_controller.dart`。

### 錄音到貼上的流程

`ZeroTypeController` 是中央狀態機（`idle → recording → saving → transcribing → done/error`）：

1. `HotkeyService` 透過 `_AppInitializer` 呼叫 `toggleRecording()`。
2. Controller 驗證使用中通道與使用中憑證，並請求麥克風與平台輔助使用權限。
3. `RecordingService` 把 16 kHz AAC/M4A 寫進暫存目錄，並串流正規化後的振幅。
4. 再按一次快捷鍵結束錄音。Controller 把自訂或預設語音提示詞與字典提示詞合併。
5. `SpeechRecognitionService` 依 Provider 與使用中通道組 URL。官方 Gemini 可用 API Key（`x-goog-api-key`）或 OAuth Bearer；Proxy 打 `{根}/v1beta/models/{model}:generateContent` 或 OpenAI 的 `{根}/v1/audio/transcriptions`。憑證失效不改走其他 Key 或通道。
6. 音檔移到持久化歷史目錄，寫入 `TranscriptionRecord`，再用 `model_pricing.dart` 累加花費統計。
7. 以 Flutter clipboard API 複製結果，再由原生 `keyboard` channel 模擬 Cmd+V 或 Ctrl+V。

取消可能來自快捷鍵、Esc 或 overlay 關閉按鈕。改這段流程時，必須同步 `_cancelled`、timer 清理、錄音器清理、音效 / 背景音樂恢復、Riverpod 狀態與 overlay 顯示。

### 原生平台邊界

Dart 與原生 runner 透過這些固定 MethodChannel 名稱溝通：

- `com.zerotype.app/overlay`
- `com.zerotype.app/control`
- `com.zerotype.app/keyboard`
- `com.zerotype.app/permission`

macOS 由 `macos/Runner/AppDelegate.swift` 負責不搶焦點的 `NSPanel` overlay、全域 / 本機 Esc 監聽、輔助使用檢查與系統設定連結、CGEvent Cmd+V 貼上，以及自訂開機啟動 channel。`MainFlutterWindow.swift` 負責註冊這些 channel。

Windows 由 `windows/runner/channel_handler.cpp` 用 `SendInput` 實作 Ctrl+V，把輔助使用權限回報為已授權，並 stub overlay / control channel。可見的 overlay 改由 `lib/shared/widgets/recording_overlay.dart` 的 Windows-only Flutter widget 繪製，因此只會出現在應用視窗內。`flutter_window.cpp` 會呼叫 `SetupChannels`；新增 C++ 原始檔時也必須寫進 `windows/runner/CMakeLists.txt`。

任何 channel 契約變更都必須同時相容 Dart、macOS 與 Windows。channel 之外也有平台分支：例如音效 / 背景音樂控制使用 macOS 的 `afplay` 與 AppleScript，Windows 歷史播放則開啟預設媒體應用。

### 持久化與設定

沒有資料庫。資料分散在打包資產、`SharedPreferences`，以及 `getApplicationSupportDirectory()` 底下的檔案：

- `assets/config/providers.json`：官方通道尚未有使用中憑證、或官方模型目錄查詢失敗時的後備 provider / model 目錄。
- `prompts/SpeechToText.prompt`：內建預設轉寫提示詞。
- `SharedPreferences`：provider、使用中通道、各通道的 model / API Key、官方通道憑證方式、Proxy 根位址、主題、快捷鍵、開機 / 音效設定、保留天數與最長錄音時間。舊的 `custom_endpoint_*` 與 `api_key_speech_<provider>` 會在讀取時遷移。
- Antigravity 憑證有兩種來源：(1) 本機既有登入 `~/.cli-proxy-api/antigravity-*.json` 或 `~/.gemini/oauth_creds.json`；(2) App 內「Antigravity OAuth」按鈕觸發 `AntigravityOauthService`，用內建 Antigravity OAuth client（含 `cclog`、`experimentsandconfigs` scope）走 Google 授權，並以 `loadCodeAssist`（`ideType=ANTIGRAVITY`，查不到時 `onboardUser` 輪詢）取得 project id，落地成 `~/.cli-proxy-api/antigravity-<email>.json`。`AntigravityAuthSource` 統一負責讀取與 access 過期續期（refresh 後寫回同一檔）。
- `dictionary.txt`：排序後的自訂字典詞。
- `SpeechToText_Custom.prompt`：使用者覆寫的提示詞。
- `history.json` 與 `history_audio/`：保留的轉寫中繼資料與音檔。
- `history_stats.json`：累計次數與花費。單筆刪除與過期清除不會減少它；`clearAll()` 才會重設。

官方通道有使用中憑證時，模型下拉由 `OfficialModelCatalogService` 向官方 models API 查詢（Gemini：`/v1beta/models`；OpenAI：`/v1/models`）。查不到或尚未有憑證時才退回 `providers.json`。新增 Provider 或改轉寫分流時，仍要改 `speech_recognition_service.dart` 與 `model_pricing.dart`；後備清單才改 `providers.json`。

## 產生程式與倉庫慣例

不要手改 `*.g.dart`、`*.freezed.dart` 或 `*.gr.dart`。這些產生檔有進版控，改 Riverpod annotation、Freezed model 或 AutoRoute 宣告後要跑 build_runner，並把產生出來的 diff 一併提交。

`.agents/rules/flutter-desktop.md` 其餘仍適用的重點：

- 識別碼、型別與檔名用英文：class 用 PascalCase、成員用 camelCase、檔案與目錄用 snake_case。
- 參數與回傳值標明明確 Dart 型別。
- 資料盡量不可變；持久化走 repository 介面；業務與 UI 狀態走 Riverpod controller；長生命週期依賴走 GetIt；導航走 AutoRoute；樣式走 `ThemeData`。
- 函式與 widget 保持小而專注；優先 early return、較淺的 widget tree、抽出可重用 widget，並在可行處使用 `const` constructor。
