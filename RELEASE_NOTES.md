# ZeroType v1.5.2

## 本次更新

### 🔐 macOS 安裝檔改用自簽章憑證正式簽署
- 建置流程改為使用自簽章程式碼簽署憑證（Common Name: `ZeroType`）簽署 App，取代先前完全沒有身分資訊的 ad-hoc 簽章。
- 實測 Gatekeeper 評估結果從完全沒有來源資訊，變成明確的 `origin=ZeroType`，開啟時會走正常的「無法驗證開發者」流程，於「系統設定 → 隱私權與安全性」按一次「仍要打開」即可正常執行。
- **注意**：這是自簽章憑證，並非 Apple 官方核發的 Developer ID，也未經 Apple 公證（notarization）。完全沒有安裝過這張憑證的 Mac，第一次開啟仍會看到「無法驗證開發者」提示，需手動允許——這是自簽章的既定限制，不是尚未修好的問題。

### 🎨 修正選單列狀態圖示
- 修復 macOS 選單列右上角常駐狀態圖示顯示為黑白破圖案的問題，改為正確的紅底白色麥克風圖示，與 App 主要品牌圖示一致。

### 🏷️ 版本資訊
- 應用程式版本更新為 `1.5.2`，build number 為 `8`。

---

## 下載與安裝
- **macOS（Apple Silicon / arm64）**：`ZeroType-macOS.dmg` 或 `ZeroType-macOS-arm64.zip`。
- **Windows（x64）**：解壓縮 `ZeroType-Windows-x64.zip` 後執行應用程式。
- 各檔案 SHA-256 校驗值見 `SHA256SUMS.txt` 與 `SHA256SUMS-Windows.txt`。

macOS 首次開啟若顯示「無法驗證開發者」，請至「系統設定 → 隱私權與安全性」找到 Zero Type 的提示，點選「仍要打開」；或於 Terminal 執行 `xattr -dr com.apple.quarantine "/Applications/Zero Type.app"` 後再開啟。
