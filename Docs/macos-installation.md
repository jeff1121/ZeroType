# macOS 安裝說明

## 目前的簽章狀態

ZeroType 自 v1.5.2 起使用自簽章程式碼簽署憑證（Common Name：`ZeroType`）簽署 macOS App，不再使用純 ad-hoc 簽章。發布流程會驗證 App 與 DMG 內的簽章封印。

這張憑證不是 Apple 核發的 Developer ID Application，App 也尚未經 Apple notarization。簽章封印驗證通過只代表簽署後內容完整，不代表 Gatekeeper 已信任開發者，亦不能保證免除所有安全提示。從網路下載後若被阻擋，請先核對來源與 SHA-256，再於「系統設定 → 隱私權與安全性」依系統提示選擇「仍要打開」。

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

目前發布流程採用 `ZeroType` 自簽憑證，並未執行 Developer ID 簽署與 notarization。未來若改採 Apple 信任的發行方式，仍須完成上述流程；不要把本機自簽章封印驗證當成 Apple 公證。
