# macOS 安裝說明

## 目前的簽章狀態

ZeroType v1.1.1 使用完整且可驗證的 ad-hoc code signature，但尚未加入 Apple Developer Program，因此目前沒有 Developer ID Application 簽章與 Apple notarization。

這不代表應用程式內容損毀。從 GitHub 下載 DMG 時，瀏覽器會為檔案加上 `com.apple.quarantine` 屬性；macOS Gatekeeper 對未 notarize 的 App 進行檢查時，可能顯示「App 已損毀」或「無法驗證開發者」。

## 安裝步驟

1. 從 [GitHub Releases](https://github.com/jeff1121/ZeroType/releases) 下載最新版 `.dmg`。
2. 開啟 DMG，將 `Zero Type.app` 拖入 `/Applications`。
3. 開啟 Terminal，執行：

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Zero Type.app"
   open "/Applications/Zero Type.app"
   ```

4. 依畫面提示授予麥克風與輔助使用權限。

## 驗證下載檔完整性

Release 頁面會附上 `SHA256SUMS.txt`。將它與 DMG／ZIP 放在同一個目錄後執行：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

若顯示 `OK`，代表下載內容與發布檔一致。

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

正式免警告發行需要：

1. Apple Developer Program 付費 Team。
2. Developer ID Application 憑證與 private key。
3. Hardened Runtime 簽章。
4. 將 App 提交 Apple notarization。
5. 把 notarization ticket staple 到 App／DMG。

目前帳號只有 Personal Team，因此暫時採用 ad-hoc 發布。未來取得 Developer ID Application 後，將改為完整簽章與 notarization 流程。
