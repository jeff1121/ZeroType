# ZeroType v1.5.3

## 本次更新

### Windows 視窗框與關閉行為
- 主視窗改用 `TitleBarStyle.normal` 與系統標題「ZeroType」，恢復原生拖移、縮放、最小化、最大化與關閉控制；Windows 內容區不再顯示第二條 44px「Zero Type」。
- macOS 維持 `TitleBarStyle.hidden`、交通燈與原本的 44px 標題列。
- 兩平台在顯示視窗前設定 `setPreventClose(true)`；關閉只 hide 到系統匣，真正退出仍走「結束 ZeroType」。

### Windows 全域熱鍵
- Windows 預設為 `Ctrl+Shift+Space`，macOS 預設仍為 `⌥ Option+Space`。
- Windows 改用自有 `com.zerotype.app/hotkey` MethodChannel 呼叫 Win32 `RegisterHotKey`，固定 id 1、root HWND、`MOD_NOREPEAT`；檢查 BOOL 與 `GetLastError`，失敗不宣稱註冊成功。
- `com.zerotype.app/hotkey_events` EventChannel 只轉發有效 id 的觸發；尚無 listener、未註冊或已解除時不觸發。
- Windows 排除無修飾鍵、Alt+Space、Alt+F4、Ctrl+Esc、含 Ctrl+Alt+Delete 與未支援主鍵。舊的保留組合或啟動註冊失敗會依規格退回平台預設。
- 修正 Windows CI 實際發現的 vk 解析區域變數遮蔽（MSVC C4456／C2220）；保留 `/WX`，不以關閉警告跳過編譯錯誤。
- macOS 仍使用 `hotkey_manager`，不變更 macOS 原生 runner。

### 熱鍵儲存與 macOS 設定頁回歸
- 修正錄製前 pause 後儲存未 resume 的問題。候選組合先暫存，原生註冊成功後才提交目前熱鍵與 preferences；註冊／寫入失敗會嘗試恢復舊有效鍵。
- 啟動、暫停、取消與恢復的失敗都回傳結果；連舊鍵也無法恢復時保持暫停並顯示原因，不假裝可用。開始錄製時解除失敗亦會嘗試恢復舊鍵。
- 修正主 Shell 提前讀取設定造成的 `LateInitializationError`，以及只給預設值可能顯示過時熱鍵的後續問題。同步載入持久化組合，設定頁等待共用的初始化工作；載入異常提供可見原因與重試。
- 沿用 `global_hotkey` 與 `HotKey.toJson/fromJson`；macOS 已儲存的 logical key、Fn／Caps Lock 等資訊不被轉換丟棄。
- 錄製覆蓋層覆蓋主視窗、阻擋背景滑鼠與鍵盤焦點；按鍵來源改用 `HardwareKeyboard`，卸載時移除 handler。
- 切回 App 不再 invalidate 錄製狀態；合成放鍵事件可正確清除上一組修飾鍵，單獨 Esc 可取消。
- 錄製介面支援最小 700×500 視窗；儲存失敗的 SnackBar 在覆蓋層關閉後仍可見；按鍵名稱不依賴 Release 模式會為 null 的 `debugName`。

### 測試、文件與驗證誠實性
- 移除先前加入的五個全域 analyzer ignore 規則，恢復原本分析門檻並實際清除診斷。跨檔變更限日誌／型別／未使用 import／等價色值與 deprecated 參數等 lint 清理，不變更錄音、轉寫、貼上、Azure 或 Antigravity 業務流程。
- 修正 Fake registrar 的持續失敗／保留舊 active 狀態，讓回滾測試必須真的重新註冊舊鍵才能通過。
- 補上 service、MethodChannel／EventChannel、真實 SettingsController／MainShell、焦點與生命週期回歸測試；本機完整測試 109 個通過，純邏輯兩檔行與分支覆蓋率均為 100%。
- 新增 PR 格式／分析／測試與 Windows Release 編譯檢查；CI 編譯不是 Windows 人工實測，狀態以 PR checks 為準。
- 校正 Plan／Tasks 狀態、macOS 安裝簽章說明、歷史需求與 OAuth ADR 定位。詳細證據見 `Docs/Windows-Hotkey-Audit.md`。

## 人工測試與限制
- 使用者於 2026-09-29 回報先前自簽 macOS 測試版的人工測試已完成、未發現重大問題；本次複查新增修正未冒稱已被先前人工測試涵蓋。
- 未在 Windows 執行實機 11 項清單；逐項狀態保留於 `Docs/Tasks.md` 第十一節。
- macOS 延續自簽憑證 `ZeroType` 的簽署流程。封印完整性不代表 Gatekeeper 信任，也不等於 Apple Developer ID 或 notarization；首次開啟仍可能需手動允許。

## 版本與下載
- 版本：`1.5.3+9`（上一版 `1.5.2+8`）。
- macOS：發布流程提供 `ZeroType-macOS.dmg`／`ZeroType-macOS-arm64.zip`；以實際產物內的架構資訊為準。
- Windows x64：發布流程提供 `ZeroType-Windows-x64.zip`。
- 校驗值：`SHA256SUMS.txt`／`SHA256SUMS-Windows.txt`。
- 本次提交與 PR 不會自動建立 tag、合併或發布 GitHub Release；下載產物須待獨立發布流程完成。
