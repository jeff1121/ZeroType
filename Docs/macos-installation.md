# macOS 安裝說明

> 2026-10-14 已核對 [.github/workflows/release.yml](../.github/workflows/release.yml) 與 [verify_macos_release.sh](../scripts/verify_macos_release.sh)。目前開發目標 `1.5.5+13` 的驗證與交付見 [task.md](task.md)；此版本號不表示已發布同版 DMG／ZIP。安裝時以 GitHub Releases 實際提供的產物為準。

## 目前的簽章狀態

ZeroType 自 v1.5.2 起的發布流程使用自簽章程式碼簽署憑證（Common Name：`ZeroType`）簽署 macOS App，不再使用純 ad-hoc 簽章。流程先匯入憑證，再以 `codesign --force --deep --sign "ZeroType"` 簽署 App，驗證建置後 App 與 DMG 內 App 的簽章封印；這不代表所有本機 `flutter build macos` 產物都已經過同一簽署步驟。

這張憑證不是 Apple 核發的 Developer ID Application，App 也尚未經 Apple notarization。簽章封印驗證通過只代表簽署後內容完整，不代表 Gatekeeper 已信任開發者，亦不能保證免除所有安全提示。從網路下載後若被阻擋，請先核對來源與 SHA-256，再於「系統設定 → 隱私權與安全性」依系統提示選擇「仍要打開」。

## 安裝步驟

1. 從 [GitHub Releases](https://github.com/jeff1121/ZeroType/releases) 下載實際已發布版本的 `ZeroType-macOS.dmg` 與 `SHA256SUMS.txt`，依下一節核對雜湊。
2. 開啟 DMG，將 `Zero Type.app` 拖入 `/Applications`；也可下載同版 ZIP，解壓後移入 App。
3. 開啟 App。若 macOS 阻擋自簽開發者，於「系統設定 → 隱私權與安全性」依提示選擇「仍要打開」。
4. 依畫面提示授予麥克風與輔助使用權限。

已核對來源與雜湊、仍需要手動解除下載隔離屬性時，可在 Terminal 執行：

```bash
xattr -dr com.apple.quarantine "/Applications/Zero Type.app"
open "/Applications/Zero Type.app"
```

## 發布產物與觸發方式

目前 workflow 打包 `ZeroType-macOS.dmg`、`ZeroType-macOS-arm64.zip` 與 `SHA256SUMS.txt`。ZIP 檔名不等同只含單一架構；驗證 script 會印出實際架構，並要求至少包含 arm64。

推送 `v*` tag 或手動啟動 release workflow 會建置並上傳 Actions artifact；只有 tag 執行才上傳 GitHub Release。一般分支推送、PR 更新或只改 `pubspec.yaml` 不會發布新版安裝檔。

## 驗證下載檔完整性

下載一個產物時，可先計算雜湊，與同版 `SHA256SUMS.txt` 對應檔名那一行的雜湊比較：

```bash
shasum -a 256 ZeroType-macOS.dmg
```

目前 workflow 的雜湊清單包含 `release/` 路徑前綴。若 DMG、ZIP 與清單都下載到同一目錄，可去掉該前綴後一次驗證兩個檔案：

```bash
sed 's|  release/|  |' SHA256SUMS.txt | shasum -a 256 -c -
```

每個檔案顯示 `OK` 才表示雜湊相符；只下載其中一個檔案時，另一個會回報找不到，不能據此判定已下載的檔案毀損。雜湊一致表示內容與該份清單相符，不代表 Apple 已信任此開發者。

也可以驗證安裝後 App 的 code signature 封印：

```bash
codesign --verify --deep --strict --verbose=2 "/Applications/Zero Type.app"
```

成功時會顯示：

```text
valid on disk
satisfies its Designated Requirement
```

## 為什麼不能直接雙擊開啟？

若要改採 Apple Developer ID 與 notarization 的發行流程，需要：

1. Apple Developer Program 付費 Team。
2. Developer ID Application 憑證與 private key。
3. Hardened Runtime 簽章。
4. 將 App 提交 Apple notarization。
5. 把 notarization ticket staple 到 App／DMG。

目前發布流程採用 `ZeroType` 自簽憑證，並未執行 Developer ID 簽署與 notarization。未來若改採 Apple 信任的發行方式，仍須完成上述流程；不要把本機自簽章封印驗證當成 Apple 公證。
