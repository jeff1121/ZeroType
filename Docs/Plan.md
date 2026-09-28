# ZeroType — Windows 視窗與熱鍵修復計畫

> 狀態：原規格已實作，2026-09-29 複查補正並準備 v1.5.3 PR；驗證範圍與限制見 `Tasks.md` 第十一節及 `Windows-Hotkey-Audit.md`。本文件原寫於 2026-09-24，以下保留當時根因與鎖定決定。
> 工作細項在 `Docs/Tasks.md` 第十一節。兩份文件衝突時，以本文件的「已鎖定決定」為準，細項的檔案與測試要求仍要做完。
> 歷史產品願景在 `Docs/Requirement.md`，其中部分敘述已過時，不要照那份改架構。

## 2026-09-29 複查與發布補充

- 使用者已另行授權版本升為 `1.5.3+9`，更新 README、RELEASE_NOTES、commit、推送並開 PR；下方原規則中的「不升版／不改發布文件」只適用於先前實作階段。本次不建立 tag、不自動合併或發布 GitHub Release。
- 使用者回報先前自簽 macOS 測試版人工測試完成、無重大問題；未提供 Windows 逐項實測紀錄。本次複查新增修正不冒稱已被先前人工測試覆蓋。
- Tasks 暫停更新鍵的語意以本文件「註冊成功才儲存」為準：`updateHotkey` 暫存候選，`resume` 註冊成功後才更新有效鍵與 preferences；失敗恢復舊鍵，恢復失敗則明示停用狀態。
- 原生失敗只回傳一次 MethodChannel error（含 GetLastError），不再額外回 false；Dart 仍需處理 false / null 回應。純邏輯只依賴 `HotKey` 資料轉換，不呼叫套件的註冊方法。
- 不更動錄音／轉寫／貼上／OAuth 的業務流程。為恢復原始 analyzer 門檻而進行的跨檔 lint 清理，應與功能修復分開記錄，不再用全域 ignore 偽裝全綠。

## 給實作 Agent 的規則

1. 從乾淨的 `master` 開分支 `fix/windows-window-chrome-and-hotkey`。不要在 `master` 上直接改。
2. 只修本文件列出的 Windows 視窗與全域熱鍵。不要順手改 Azure、OAuth、錄音流程、提示詞或版號。
3. macOS 既有行為必須保持：隱藏標題列、Option+Space 預設熱鍵、`hotkey_manager` 註冊、選單列常駐。
4. 文件、註解、使用者可見文案使用繁體中文。識別碼、檔名、API 名稱維持英文。
5. 不要手改 `*.g.dart`、`*.freezed.dart`、`*.gr.dart`。這次應不需要 `build_runner`；若真的改了 annotation，要重跑並把產生檔一起留下。
6. 不要為了這次修復升 `pubspec.yaml` 版號，也不要改 `README.md` 的版本更新紀錄或 `RELEASE_NOTES.md`。那是發布流程，不是這次範圍。
7. 完成定義不是「程式寫完」。必須跑完第十一節最後的驗證任務，失敗就修，直到該過的檢查全綠。不能把失敗測試留在樹上。
8. 這台開發機是 macOS。Windows 視窗外觀與真實 `RegisterHotKey` 無法在這裡執行。能在 macOS 上跑的測試必須全綠；跑不了的 Windows 手動清單必須在交接說明寫「未在 Windows 執行」，禁止寫成已驗證。

## 問題從哪裡來

Owner 於 Windows 實體機測試目前發行版，回報兩件事：

1. 主視窗沒有標題列，不能拖移、不能縮小、不能關閉、不能調整大小，視窗卡在螢幕正中間。
2. 設定頁的全域快捷鍵無法成功設定與儲存，因此無法開始或停止錄音，後面的功能無法測試。

以下根因是 2026-09-24 讀程式與已解析套件原始碼得到的，不是在 Windows 上再跑過一次。套件版本以當時本機 pub cache 為準：`window_manager` 0.5.2（`pubspec.yaml` 為 `^0.5.1`）、`hotkey_manager` 0.2.3、`hotkey_manager_windows` 0.2.0。若實作當下 `flutter pub get` 解析到別的 patch，先重讀該版的 `SetTitleBarStyle` 與 `RegisterHotKey`，不要照抄過期行號。

## 已鎖定的產品決定

這些已經決定，實作時不要再改方向，也不要回頭問：

| 決定 | 內容 |
|------|------|
| Windows 視窗框 | 使用系統原生標題列（`TitleBarStyle.normal`），標題文字 `ZeroType`。由系統提供拖移、縮放、最小化、最大化、關閉。不要自畫第二套標題列按鈕。 |
| macOS 視窗框 | 維持 `TitleBarStyle.hidden`。不要為了 Windows 改掉 macOS 的隱藏標題列。 |
| 假標題 | `MainShellPage` 上方那條高 44 的「Zero Type」只在 macOS 顯示。Windows 改顯示原生標題列後，這條必須拿掉，避免上下兩條標題。 |
| 關閉主視窗 | 隱藏到系統匣，不結束行程。這是 `Docs/Requirement.md` 原本的產品行為，也是 `lib/main.dart` 的 `onWindowClose` 已經在做的事。真正結束只走系統匣「結束 ZeroType」。 |
| Windows 預設熱鍵 | `Ctrl+Shift+Space`。禁止再把 Alt+Space 當成 Windows 預設。 |
| macOS 預設熱鍵 | 維持 Alt+Space（畫面上是 ⌥ Option + Space）。 |
| 熱鍵註冊失敗 | 必須讓使用者看到繁體中文原因，並繼續使用上一組有效熱鍵。禁止靜默當成儲存成功。 |
| Windows 全域熱鍵實作 | 改走 App 自己的 Win32 `RegisterHotKey`。macOS 繼續用 `hotkey_manager`。不要為了修 Windows 去 fork 或升級整個 `hotkey_manager`。 |

## 問題一：視窗不能拖、不能縮、不能關

### 現況

`lib/main.dart` 的 `_initWindowManager()` 對所有平台都使用：

- `titleBarStyle: TitleBarStyle.hidden`
- `center: true`
- `size: Size(900, 650)`、`minimumSize: Size(700, 500)`
- `title: 'ZeroType'`

`lib/shared/widgets/main_shell.dart` 有一條高 44 的「Zero Type」文字列。它不是視窗標題列，沒有 `DragToMoveArea`，也沒有呼叫 `windowManager.startDragging()`。

`lib/main.dart` 的 `_AppInitializerState.onWindowClose()` 只做 `windowManager.hide()`。全專案沒有呼叫 `windowManager.setPreventClose(true)`。

`windows/runner/main.cpp` 在建立視窗後呼叫 `window.SetQuitOnClose(true)`。視窗收到 `WM_DESTROY` 會 `PostQuitMessage`，行程結束。

### 套件在 Windows 上的行為

`window_manager` 0.5.2 的 Windows 實作裡，`TitleBarStyle.hidden` 會在 `WM_NCCALCSIZE` 把客戶區擴成幾乎整張視窗，系統標題列與最小化、最大化、關閉鈕不再出現。縮放只依賴大約 8px 的非客戶區邊，而且 `WM_NCHITTEST` 沒有把邊緣改成 `HTLEFT` 這類命中碼。滑鼠落在 Flutter 內容上就是客戶區，不能拖、也很難拉邊。`center: true` 讓它一開始就在螢幕正中，所以看起來像卡死。

同一個 `TitleBarStyle.hidden` 在 macOS 只隱藏標題文字，交通燈按鈕與標題列拖移還在。所以這個問題只出現在 Windows。

`WM_CLOSE` 時套件會先送出 `close` 事件。只有 `isPreventClose == true` 才會回傳 `-1` 擋下關閉。目前這個旗標是 `false`，所以 Windows 一旦真的收到關閉，視窗會被銷毀，接著 `SetQuitOnClose(true)` 讓行程結束。`onWindowClose` 裡的 `hide()` 擋不住這件事。

macOS 的 `applicationShouldTerminateAfterLastWindowClosed` 在 `macos/Runner/AppDelegate.swift` 回傳 `false`，所以 macOS 關掉視窗不會結束 App。兩邊目前並不一致。這次要兩邊都 `setPreventClose(true)`，再沿用現有的 `hide()`，關閉語意才都是「收到系統匣」。

### 要改成

1. 依平台決定 `WindowOptions.titleBarStyle`：Windows 為 `normal`，macOS 為 `hidden`。其餘 size、minimumSize、center、title 維持。
2. Windows 不顯示 `MainShellPage` 那條 44px 假標題與其下方分隔線。macOS 保留。
3. 視窗 ready 之後、show 之前或剛 show 時，兩個平台都 `await windowManager.setPreventClose(true)`。
4. `onWindowClose` 維持 `hide()`，不要改成 `exit`。結束行程仍只由 `TrayService` 的「結束 ZeroType」呼叫 `_quit()`。
5. 不要在 Windows 另做自訂最小化、最大化、關閉按鈕。原生標題列已經有。

### 回歸風險

`setPreventClose(true)` 也會改變 macOS：`windowShouldClose` 將回傳 `false`，視窗不會被關掉，而是被 `hide()`。實作後若手邊能開 macOS App，要確認紅燈關閉後行程還在、選單列圖示還在、從選單列可以再把視窗叫出來。不能確認時，在交接說明寫明未在 macOS 手動點過，不要假裝已測。

## 問題二：熱鍵設定不起作用

這是三層疊在一起，不是單一 if 寫錯。

### 層一：錄製 UI 在 Windows 上不可靠

設定頁快捷鍵列在 `lib/features/settings/presentation/pages/settings_page.dart`。點下去呼叫 `SettingsController.startRecordingHotkey()`，畫面疊出 `_HotkeyRecorderOverlay`。

錄製器是 `KeyboardListener` 加 `FocusNode`。`hotkey_manager` 自己的 `HotKeyRecorder` 用的是 `HardwareKeyboard.instance.addHandler`，不依賴焦點。Windows 把 Alt 當成選單鍵，焦點容易短暫離開視窗。

同檔的 `didChangeAppLifecycleState` 在 `resumed` 時呼叫 `_invalidateSettings()`，也就是 `ref.invalidate(settingsControllerProvider)`。`SettingsController.build()` 會重新組出一份新的 `SettingsState`，`isRecordingHotkey` 預設是 `false`。錄製中的狀態因此被清掉，覆蓋層消失。

`saveHotkey()` 若只有修飾鍵、沒有主鍵，只印 log 然後 `stopRecordingHotkey()`，畫面上沒有錯誤。按鍵名稱寫死成 macOS 的 ⌘ Command、⌥ Option、⌃ Control、⇧ Shift。

覆蓋層只蓋住設定頁右側，不是整個視窗，焦點更容易丟。

### 層二：預設熱鍵是 Windows 系統保留組合

`lib/core/services/hotkey_service.dart` 的預設是 `PhysicalKeyboardKey.space` + `HotKeyModifier.alt` + `HotKeyScope.system`，也就是 Alt+Space。

Windows 用 Alt+Space 打開視窗系統選單。`RegisterHotKey(MOD_ALT, VK_SPACE)` 會失敗。`VK_SPACE` 是 `32`（`0x20`）。Flutter `kWindowsToLogicalKey` 裡 space 對應的就是 `32`。

### 層三：註冊失敗被當成成功

`hotkey_manager_windows` 0.2.0 的 `Register()` 呼叫 `RegisterHotKey` 後不看 `BOOL` 傳回值，直接 `result->Success(true)`，並把 id 放進 map。Dart 端因此以為已經註冊。使用者看到的是已儲存，全域熱鍵卻不會觸發，錄音無法開始或停止。

另外，該函式假設 `modifiers` 一定是 list、`keyCode` 一定是 int。`keyCode` 為 null 時 `std::get<int>` 會丟例外。`SettingsController.saveHotkey()` 沒有接住這種失敗。

### 要改成

把「組合鍵是什麼」和「作業系統怎麼註冊」分開。

純邏輯（新檔，見第十一節）負責：

- 從一組 `PhysicalKeyboardKey` 分出修飾鍵與唯一主鍵。
- 每個平台的預設組合。
- Windows 保留組合判斷。
- 畫面上的按鍵名稱。
- 既有 `SharedPreferences` 字串的讀寫仍走 `hotkey_manager` 的 `HotKey.toJson()` / `HotKey.fromJson()`，鍵名維持 `global_hotkey`。不要換一套 JSON，否則已存的 macOS 設定會讀壞。

註冊抽象負責：

- `register` 回傳成功或失敗原因，不可用 `void` 吞掉失敗。
- `unregisterAll`。
- 觸發時呼叫既有的 `HotkeyCallback`。

macOS 實作包住現有 `hotKeyManager.register`。Windows 實作呼叫下面的原生 channel，不要再呼叫 `hotkey_manager` 的 system scope 註冊。

`HotkeyService` 的規則：

- `initialize`：讀舊值；Windows 上若讀到保留組合或註冊失敗，改用 `Ctrl+Shift+Space` 並寫回 preferences，再註冊這一組。macOS 讀到合法舊值就用舊值。
- `updateHotkey`：先向 registrar 註冊新組合。成功才寫入記憶體與 preferences。失敗則重新註冊舊組合，並把失敗原因傳回設定頁。
- `pause`：錄製開始前解除註冊，避免錄製時舊熱鍵觸發錄音。
- `resume` 或取消：註冊目前仍有效的那一組。
- Windows 註冊時加上 `MOD_NOREPEAT`（`0x4000`），避免按住不放時 `toggleRecording()` 被連打。

Windows 原生 channel 加在既有的 `windows/runner/channel_handler.cpp`，不要新建 Flutter plugin。

- MethodChannel 名稱：`com.zerotype.app/hotkey`
- `register` 引數：`vk`（int，Windows virtual-key）、`modifiers`（string list，只允許 `control`、`shift`、`alt`、`meta`）
- `register` 成功回傳 `true`。`RegisterHotKey` 回傳 `FALSE` 時回傳 `false`，並用 `FlutterError` 帶上 `GetLastError()` 的數字（常見 `1409` 是 `ERROR_HOTKEY_ALREADY_REGISTERED`）。不要先把 id 放進 map。
- 每次註冊前先 `UnregisterHotKey` 同一個 id。App 同時只有一個全域熱鍵，id 固定為 `1`。
- `unregisterAll` 解除這個 id。
- HWND 使用與 `hotkey_manager_windows` 相同的 root window：`GetAncestor(native_view, GA_ROOT)`。
- `WM_HOTKEY` 在 `windows/runner/flutter_window.cpp` 的 `FlutterWindow::MessageHandler` 裡交給 `channel_handler`。處理完回傳 `0`。
- 用 EventChannel `com.zerotype.app/hotkey_events` 通知 Dart，payload 至少要能辨識是這一個熱鍵觸發。Dart 收到後呼叫現在的 `HotkeyService` callback。尚未 listen 就收到事件時直接丟掉，不要崩潰。
- 修飾鍵對應：`alt` = `MOD_ALT`（`0x0001`）、`control` = `MOD_CONTROL`（`0x0002`）、`shift` = `MOD_SHIFT`（`0x0004`）、`meta` = `MOD_WIN`（`0x0008`），再 OR 上 `MOD_NOREPEAT`。
- 主鍵 virtual-key 由 Dart 算好再傳。不要在 C++ 再做一套鍵盤表。Dart 對照（與 Flutter `kWindowsToLogicalKey` 一致）：

| 鍵 | virtual-key |
|----|-------------|
| Space | 32 |
| 0–9 | 48–57 |
| A–Z | 65–90 |
| Escape | 27 |
| F1–F12 | 112–123 |

Windows 禁止註冊的組合（判斷放在 Dart，C++ 仍須在 API 失敗時如實回傳）：

- 沒有修飾鍵
- 沒有主鍵，或主鍵本身是修飾鍵
- Alt+Space
- Alt+F4
- Ctrl+Esc
- 任何含有 Ctrl+Alt+Delete 的組合（Delete 的 virtual-key 若有人傳入也要拒）

macOS 不要套用這份保留清單。macOS 仍允許現在的 Alt+Space。

設定頁：

- 錄製中的按鍵改聽 `HardwareKeyboard.instance.addHandler`，在 `dispose` 移除。不要再靠 `KeyboardListener` 的焦點。
- 覆蓋層改成蓋住整個主視窗，而不是只蓋設定頁右側。Esc 單獨按下等於取消。
- `resumed` 時不要 `invalidate` 整個 `settingsControllerProvider`。改呼叫已有的 `refreshPermissions()`。若當時 `isRecordingHotkey == true`，連權限都不要重刷，避免重建狀態。
- `initState` / `didPush` 的 invalidate 若會在錄製中發生，也必須保留 `isRecordingHotkey`。最穩的做法是 `build()` 不要被拿來重置錄製旗標；錄製旗標只由 `startRecordingHotkey`、`stopRecordingHotkey`、`saveHotkey` 改。
- 按鍵名稱依平台顯示。Windows：`Ctrl`、`Alt`、`Shift`、`Win`。macOS：維持 `⌃ Control`、`⌥ Option`、`⇧ Shift`、`⌘ Command`。
- 儲存失敗時用 SnackBar 顯示原因，覆蓋層停留或關閉都可以，但畫面上的熱鍵必須仍是上一組有效組合，而且該組合要處於已註冊狀態。
- 只有修飾鍵時的文案範例：「請同時按住修飾鍵與一個主鍵，例如 Ctrl+Shift+Space。」
- 保留鍵或註冊失敗的文案範例：「這個快捷鍵無法在 Windows 使用（系統保留或已被其他程式占用）。請換一組。」

## 明確不做

- 不改錄音、轉寫、貼上、Overlay 波形、Azure、Antigravity。
- 不改 macOS 的 `TitleBarStyle`、預設熱鍵、`hotkey_manager` 註冊路徑。
- 不加 Windows 自繪標題列按鈕，除非原生標題列方案在實機上失敗。失敗時停下來寫進交接說明，不要偷偷改產品決定。
- 不處理設定頁「輔助使用」文案仍寫 macOS 系統設定路徑。那不是這次的 bug。
- 不升版、不改 README 版本更新紀錄、不發 GitHub Release。
- 不新增與這次無關的套件。

## 測試與完成門檻

可以測的邏輯不要留在 `Platform.isWindows` 裡面。`dart:io` 的 `Platform` 不能用 `debugDefaultTargetPlatformOverride` 翻轉，widget test 會測不到分支。平台差異收成傳入 `TargetPlatform` 或一個可注入的介面；正式環境再把 `Platform.isWindows` / `Platform.isMacOS` 轉進去。

必須新增的測試與覆蓋範圍寫在 `Docs/Tasks.md` 第十一節。門檻是：

- 這次新增的純函式，每個分支都有斷言。目標是這些新檔的 line 與 branch 都覆蓋到，不接受只測快樂路徑。
- `HotkeyService` 的成功、失敗回滾、pause、resume、Windows 保留鍵退回預設，用假 registrar 測，不碰真實 Win32。
- 錄製覆蓋層的按鍵、Esc 取消、只按修飾鍵、Windows 保留鍵，用 widget test 測。
- 既有 `flutter test` 全部仍要通過。
- `flutter analyze` 沒有 issue。
- `dart format --output=none --set-exit-if-changed lib test` 通過。
- 任一項失敗就修，然後重跑，直到全綠。不要用註解或 `skip` 把這次的失敗藏起來。
- 原生 `RegisterHotKey` 與標題列外觀沒有 macOS 上的自動化測試。手動清單見下方。沒有 Windows 機器就明示未測。

## Windows 手動驗證清單

有 Windows 實體機時，用這次分支建置後逐項做。每一項失敗都要修再測，不是記下來就結束。

1. 啟動後視窗有系統標題列「ZeroType」，不在內容區再顯示一條「Zero Type」。
2. 拖標題列可移動視窗。
3. 拖邊緣可調整大小，小於 `700×500` 時被擋住。
4. 最小化後可從工作列叫回。最大化後可還原。
5. 按關閉後行程仍在，系統匣圖示還在，主視窗消失。從系統匣「顯示視窗」可再打開。從系統匣「結束 ZeroType」行程結束。
6. 設定頁熱鍵顯示 Windows 名稱，預設為 Ctrl+Shift+Space，不是 ⌥ Option。
7. 進入錄製後按 Ctrl+Shift+Space，畫面看得到這組鍵，儲存成功，之後在別的 App 按下會開始錄音，再按會停止。
8. 錄製時只按 Shift，不能存成熱鍵，且有錯誤說明。
9. 嘗試 Alt+Space、Alt+F4，不能存成有效熱鍵，且有錯誤說明；原本可用的熱鍵仍可觸發。
10. 錄製進行中按 Alt，覆蓋層不得因為視窗閃一下焦點就消失。
11. 熱鍵按下時錄音覆蓋層仍出現在主視窗底部，Esc 仍可取消錄音。這是既有 Windows overlay，這次不改它，但不得被熱鍵修改弄壞。

## 實作順序

照 `Docs/Tasks.md` 第十一節的編號做。先純邏輯與測試，再接上視窗與原生 channel，最後跑完整驗證。不要先改 C++ 再補測試。
