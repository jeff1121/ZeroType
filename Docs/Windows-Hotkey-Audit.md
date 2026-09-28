# Windows 視窗與熱鍵複查

日期：2026-09-29。目標版本：`1.5.3+9`。

## 範圍與結論

基準為 `master` 的 `f01aa134`，分支為 `fix/windows-window-chrome-and-hotkey`。審查包含所有未提交修改及新增檔案，不只比較兩個相同的 HEAD。規格以 `Plan.md` 的產品決定為準。

先前實作並未達到「全部完成」：58 個測試未涵蓋正式設定儲存流程，分析全綠亦依賴新增的忽略規則。本次補上會實際失敗的回歸測試、修正確認的缺陷，並重新核對工作清單。這不代表 Windows 實機已驗證，亦不把先前人工測試延伸成對本次新修改的確認。

使用者回報：先前提供的自簽 macOS 測試版人工測試已完成，沒有發現重大問題。未收到 Windows 11 項逐項回報。

## Standards：規範與驗證可信度

1. **不應以降低分析門檻宣稱全綠。** 先前 `analysis_options.yaml` 新增五個 `ignore`，遮蔽 `avoid_print`、deprecated API、未使用命名等診斷。本次還原為與 master 相同的規則；還原時真實分析結果為 89 個 issues，再以不改業務流程的 lint 清理修正。新增與修改的測試沒有使用 skip 或 exclude。
2. **回滾測試假陽性。** Fake registrar 原先失敗時仍保留舊 active 狀態，且 `nextResult` 不會消耗，無法證明「真的恢復舊鍵」。現改成每次換鍵先解除舊組合、一次性失敗與參數紀錄；service 測試另用 scripted fake 控制連續結果。
3. **覆蓋率與實機證據不可混用。** 舊文件只勾「每個分支」，未提供測量。本次實際輸出行與分支覆蓋率；純 Dart 測試與平台覆寫不等於 Win32 實機。
4. **過度隔離測試沒有驗證組裝。** 原 widget 測試只測錄製器，沒有真實 Controller／Shell。新增 `settings_hotkey_controller_test.dart` 與 `settings_shell_test.dart` 驗證正式連接邊界，而非僅用回傳成功的 callback。
5. **重複解析與 Release 不穩定標籤。** 錄製器重複 modifier 判斷，且主鍵名稱依賴 Release 為 null 的 `debugName`。目前預覽與正式徽章共用 combo 標籤，已改成不依賴 debugName 的穩定鍵表。

未更動產生檔與 macOS 原生 runner。跨檔 lint 清理包含日誌、等價 `withAlpha` 色值、冗餘 cast／import、未使用參數、deprecated 參數替換；不是 Azure、Antigravity、錄音、轉寫或貼上功能改版。

## Spec：確認的缺陷、原因與修正

| 問題 | 可驗證原因 | 本次處理／證據 |
|---|---|---|
| macOS 設定頁空白 | MainShell 提前 watch 設定 provider；先前 `_currentCombo` 在非同步註冊完成後才賦值，getter 拋 `LateInitializationError`；設定列 error 分支回空元件 | 建構時同步讀取已存組合，build 等候共用初始化 Future；真實 Controller 延遲 registrar 與 Shell 測試。載入失敗另有原因與重試 |
| 安全預設值仍可能是錯誤快照 | 先前緊急補預設值只避免 late crash，但設定 build 仍可能讀到過時預設，而非持久化／fallback 後的熱鍵 | 等待同一 initialize 完成，再產生 SettingsState；初始化註冊失敗仍可進設定修改 |
| 儲存熱鍵後無效 | start 先 pause；save 呼叫 paused update 後直接關 overlay，沒有 resume | 暫存候選，resume 真正註冊成功後才提交；真實 Shell 儲存後 fake callback 可轉達 |
| 失敗仍覆寫設定／假恢復 | initialize、resume 結果未檢查；paused update 提前寫入；回滾未驗證 | 所有操作回傳結果；註冊／寫入失敗恢復舊鍵；回復亦失敗維持 paused 並顯示原因 |
| preferences 寫入失敗後快取變新鍵 | SharedPreferences 先更新快取，再呼叫持久化 | 寫入失敗回復舊快取與註冊，並測試回復也失敗的錯誤回報 |
| 開始錄製解除失敗後卡住 | paused 已為 true，但 controller 不開 overlay、不恢復舊鍵 | 開始失敗先恢復舊鍵；雙重失敗提供恢復遮罩與上層錯誤對話框 |
| 原生註冊器可繞過保留鍵檢查 | Windows registrar 原先只檢查 vk 非 null | registrar 也執行平台 validate；保留／不支援組合不得送 channel |
| EventChannel 誤觸發／殘留 | 原先任何 payload 都觸發；註冊未成功前已替換 callback | 只接受 id 1；註冊成功後啟用，解除／dispose 清除；測 false、null、PlatformException、1409 與非法 payload |
| macOS 舊鍵資料丟失 | combo 轉換只保留四種 modifier，丟失 Fn／Caps Lock 與 logical key | 保留 legacy HotKey 資訊與既有 JSON；Windows 拒絕其不支援的額外 modifiers |
| 最小視窗錄製溢出 | 固定大字級與垂直間距，700×500 長組合 RenderFlex 溢出 | 測試先重現 266px 溢出，再改可捲動與可換行佈局；700×500 儲存鈕可點 |
| 失敗 SnackBar 消失 | controller 更新狀態移除 overlay，但錯誤已排到即將 dispose 的 messenger | 等狀態重建後選擇仍存在的 messenger；真實 Shell 驗證回滾後訊息仍可見 |
| 切焦點後殘留上一組 Alt | synthesized KeyUp 被過早忽略，未更新全部放開旗標 | 合成／busy 放鍵也同步釋放狀態，忽略合成 KeyDown；先 RED 再 GREEN |
| 錄製仍影響背景控制 | 滑鼠遮罩不會自動移除背景鍵盤焦點，handler 按規格回 false | MainShell 的背景增加 ExcludeFocus，覆蓋層獨立 FocusScope；先重現背景仍有焦點再修正 |
| Windows 原生邊界不完整 | 缺漏 modifiers 可略過、無 HWND 可能註冊到 thread、解除錯誤未傳遞 | 驗證 root HWND／vk／modifier 型別、GetLastError、active event guard、engine 銷毀前 cleanup；僅靜態審查，等待 Windows CI 編譯與實機 |

「始終禁止 Shell watch 頁面 provider」不是本次既定產品規則，也不是修復的必要條件。Plan 允許由 MainShell 放置覆蓋層；真正需要保證的是服務初始化契約、錯誤可見性及生命週期可測試性，不能只以架構口號代替驗證。

## 實作與規格對照

- 11.1–11.2：純視窗策略＋所有平台分支測試；Windows normal、不顯示假標題；macOS hidden、保留 44px 標題；兩平台 preventClose，onWindowClose 仍 hide。
- 11.3–11.4：組合解析、預設、Windows 保留鍵、vk 映射、穩定標籤、JSON 相容、可注入兩平台 registrar 與 fake。
- 11.5：初始化、暫停、待確認候選、resume 提交、失敗回滾、dispose；不能把暫存候選當作成功儲存。
- 11.6：現有 channel_handler.cpp 內加入 Win32 hotkey，不新增 plugin、不改 CMake、不改貼上／overlay／permission channel 行為。
- 11.7–11.8：HardwareKeyboard 錄製、完整遮罩、Esc、權限刷新不重置錄製、UI 失敗原因、GetIt 平台分流；主 callback 仍只呼叫 toggleRecording。
- 11.9–11.10：以下為真實驗證紀錄；Windows 未驗證保留未勾，使用者人工回報註明版本範圍。PR 開立狀態以最終交接與 GitHub 為準。

原 Plan／Tasks 有兩處文字衝突已明示處理：
- paused update「更新資料」指 pending candidate，不能違反 Plan「註冊成功才儲存」。
- parse 失敗不註冊「失敗候選」；允許為恢復舊有效鍵呼叫 registrar。失敗時是否關閉遮罩依 Plan：舊鍵已恢復可關閉並顯示原因；恢復失敗則保留恢復入口。

## 本機驗證紀錄

工具鏈：Flutter 3.47.0、Dart 3.13.0，macOS 開發機。

| 驗證 | 結果 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 73 files，0 changed，exit 0 |
| `flutter analyze` | No issues found，exit 0；沒有本次新增的 ignore |
| `flutter test` | 最終以原始指令重跑，109 個測試全通過，exit 0 |
| `flutter test --coverage --branch-coverage --coverage-path=coverage/lcov.info` | 109 個測試全通過，exit 0 |
| `window_chrome_policy.dart` | 行 10/10，分支 6/6 |
| `hotkey_combo.dart` | 行 153/153，分支 88/88 |
| `HotkeyService` | 行 92/101，分支 43/55；不宣稱此檔 100% |
| 錄製 widget | 行 79/81，分支 25/29；包含成功／失敗／Esc／合成放鍵／最小視窗測試 |
| `flutter build macos --release` | 成功，App 49.7 MB，版本 1.5.3 (9) |
| `codesign --force --deep --sign "ZeroType"` 與驗證 script | Authority=ZeroType；valid on disk；satisfies its Designated Requirement；x86_64 arm64；exit 0 |
| Windows 編譯 | 本機無 Windows，未在本機執行；新增 PR Windows build job，結果以 PR checks 為準 |
| macOS 人工 | 使用者已回報先前測試版完成、無重大問題；本次新增修正未重新人工確認 |
| Windows 人工 | 未在 Windows 執行，11 項逐項狀態見 Tasks 11.9 |

建置仍有套件 `hotkey_manager_macos` 尚未支援 Swift Package Manager 的警告；目前 Release 建置成功，不在本次修復範圍內升級套件。簽署驗證只驗證完整性，不宣稱 Apple notarization 或 Gatekeeper 免警告。

## 文件更正

- `pubspec.yaml`、README 當前版本、RELEASE_NOTES 同步 `1.5.3+9`。
- Plan 保留原始鎖定決定，補記最新使用者發布授權；Tasks 更新待實作標題、矛盾條款與實際證據。
- macOS 安裝文件原寫 ad-hoc，已改為既有的 ZeroType 自簽憑證流程與限制。
- Requirement 標示歷史規劃（非現行已交付功能）；OAuth ADR 標示已不適用於現行 Antigravity 登入，不改 OAuth 實作。

## PR CI 補充紀錄

首次 PR 檢查（run `36456656040`）：Dart gates 通過，Windows Release 編譯失敗。MSVC 在 `channel_handler.cpp` 的 vk 32／64-bit 解析分支偵測同名區域變數 `value` 遮蔽（C4456），因 `/WX` 轉為 C2220。已把兩個變數明確命名為 `value32`／`value64`，保留嚴格警告設定及原解析行為。此項由真實 Windows CI 發現，不是 macOS 本機驗證；修正後結果以後續 PR checks 為準，仍不等同 Windows 人工實測。

## 後續不可省略的檢查

1. 共享 service／Shell／controller 變更需測真實組裝，至少涵蓋初始化未完成、失敗、恢復與 UI 所見資料一致性。
2. 任何全綠結果必須同時核對分析規則、測試輸入與斷言，不得靠 ignore、skip、過度寬鬆 fake 達成。
3. 登錄錯誤及回滾錯誤分開回報；無法恢復時明確停用，不把不確定狀態包裝成成功。
4. 建置、簽章完整、平台模擬、CI 編譯、人工實機是不同證據；每份交接應逐項標示，不互相替代。
5. 發布版本須同步三份版本文件；commit 與 PR 必須包含已修問題、驗證數據、原生／人工未驗證範圍。
