# ZeroType v1.5.1

## 本次更新

### 🔄 修復 Antigravity 即時模型目錄刷新
- 修復「Gemini 官方 / Antigravity OAuth」點擊 Refresh 按鈕時未實際發出網路請求、僅回傳固定清單的問題。
- 接通 Antigravity `v1internal:fetchAvailableModels` API，帶入關聯之 Project ID 與 Access Token 即時取得服務端最新可用模型清單。
- 解析服務端模型顯示名稱，並過濾非轉寫之內部程式碼補全模型。
- 斷線或未取得清單時自動優雅退回預設清單保底。

### 💬 重新整理即時狀態回饋
- 點擊「更新模型目錄」時即時發送網路請求並顯示載入指示器。
- 查詢完成後以提示訊息（SnackBar）清楚回饋取得之模型數量，若連線失敗亦能即時呈現錯誤原因。
- 同步支援 Proxy 通道的即時模型重新整理。

### 🏷️ 版本資訊
- 應用程式版本更新為 `1.5.1`，build number 為 `7`。
- 側邊欄顯示目前版本，懸停可查看 build number。

---

## 下載與安裝
- **macOS（Apple Silicon / arm64）**：`ZeroType-macOS.dmg` 或 `ZeroType-macOS-arm64.zip`。
- **Windows（x64）**：解壓縮 `ZeroType-Windows-x64.zip` 後執行應用程式。
- 各檔案 SHA-256 校驗值見 `SHA256SUMS.txt` 與 `SHA256SUMS-Windows.txt`。

macOS 為 ad-hoc 簽章，未經 Developer ID notarization；首次開啟若被 Gatekeeper 阻擋，請參考 README 的安裝說明。
