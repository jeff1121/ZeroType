# ZeroType v1.5.0

## 本次更新

### Azure 模型選擇與自訂部署
- 新增內建 `OpenAI Whisper (whisper)` 選項，尚未取得即時目錄時可供選擇；此選項不是已驗證可用的 Azure 部署。
- 目錄查詢依序嘗試 `/openai/deployments`、`/openai/models` 與 `/openai/v1/models`；查詢失敗或結果為空時嘗試下一個端點。
- 清單有資料時也能切換至「手動指定自訂部署名稱」，不再因目錄非空而隱藏手動輸入入口。
- 保留已儲存但不在目前目錄中的選項，方便沿用自訂部署設定。

### 版本資訊
- 應用程式版本更新為 `1.5.0`，build number 為 `6`。
- 側邊欄顯示目前版本，懸停可查看 build number。

## Azure 使用注意事項
- 填寫 Service Endpoint 與 API Key；API Version 預設為 `2024-10-21`，仍可手動調整。
- 目前轉寫仍使用 Azure deployment-based API：`POST {endpoint}/openai/deployments/{deployment}/audio/transcriptions?api-version={version}`，認證 header 為 `api-key`，不是 Entra Bearer token。
- 模型目錄中的 model id 不一定等於實際部署名稱。若部署名稱為 `whisper-prod` 而非 `whisper`，請手動指定正確部署名稱；取得模型清單不代表該部署已通過轉寫驗證。
- 本次未加入 ARM／Microsoft Entra 登入，也未將轉寫介面改為通用 OpenAI `/v1/audio/transcriptions`。
- 真實 Azure 資源的部署查詢、錄音與轉寫仍需使用者環境驗證。

## 下載與安裝
- **macOS（Apple Silicon / arm64）**：`ZeroType-macOS.dmg` 或 `ZeroType-macOS-arm64.zip`。
- **Windows（x64）**：解壓縮 `ZeroType-Windows-x64.zip` 後執行應用程式。
- SHA-256 校驗值見 `SHA256SUMS.txt` 與 `SHA256SUMS-Windows.txt`。

macOS 為 ad-hoc 簽章，未經 Developer ID notarization；首次開啟若被 Gatekeeper 阻擋，請參考 README 的安裝說明。
