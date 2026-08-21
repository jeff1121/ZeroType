## ✨ 本次更新

### 🔑 Antigravity OAuth 一鍵登入落地憑證
- 新增「Antigravity OAuth」憑證方式：直接用 **Google 帳號**在 App 內完成授權，**無需**先安裝 Antigravity 或 CLI。
- 參考開源專案 CLIProxyAPI 做法，使用 Antigravity 專用 OAuth client 與 scope（含 `cclog`、`experimentsandconfigs`），透過本機 callback 完成授權。
- 自動以 `loadCodeAssist`（`ideType=ANTIGRAVITY`，必要時 `onboardUser` 輪詢）取得 Project ID，並落地成 `~/.cli-proxy-api/antigravity-<email>.json`，供轉寫直接引用與自動續期。

### 🧹 移除 Gemini OAuth 通道
- 該通道目前無法正常使用，暫時移除按鈕與相關程式，讓憑證設定畫面更乾淨。
- 憑證方式現為 **API Key** 與 **Antigravity OAuth** 兩種。

---

### 📦 安裝
- **macOS**：下載 `ZeroType-macOS.dmg`（Apple Silicon / arm64）。
- **Windows**：下載 `ZeroType-Windows-x64.zip`。
- 各檔案 SHA-256 校驗值見 `SHA256SUMS.txt` / `SHA256SUMS-Windows.txt`。

> macOS 為 ad-hoc 簽章，首次開啟若被 Gatekeeper 阻擋，請參考 README 的 quarantine 移除說明。
