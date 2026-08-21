## ✨ 本次更新

### 🟦 Azure OpenAI Whisper 語音辨識
- 新增 **Azure** 作為第三個語音辨識 Provider；選 Azure 後通道只顯示「官方」。
- 必填 **Service Endpoint**、**API Key（Access Token）**、**API Version**（預設 `2024-10-21`）。
- 「更新模型目錄」會列出 Azure 部署（不過濾）；查不到時可手動輸入部署名稱。
- 轉寫走 `POST {endpoint}/openai/deployments/{deployment}/audio/transcriptions`，認證使用 header `api-key`。
- Endpoint 會正規化為 origin，避免誤貼完整 API 路徑導致 404。

### 🏷️ 側邊欄顯示版本
- 左側導航欄最底部以淡色顯示目前版號（例如 `v1.3.0`），懸停可看 build number。

---

### 📦 安裝
- **macOS**：下載 `ZeroType-macOS.dmg`（Apple Silicon / arm64）。
- **Windows**：下載 `ZeroType-Windows-x64.zip`。
- 各檔案 SHA-256 校驗值見 `SHA256SUMS.txt` / `SHA256SUMS-Windows.txt`。

> macOS 為 ad-hoc 簽章，首次開啟若被 Gatekeeper 阻擋，請參考 README 的 quarantine 移除說明。
