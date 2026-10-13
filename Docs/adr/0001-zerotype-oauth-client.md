# ZeroType 以內建公開 OAuth client 發起 Gemini 官方通道登入

**狀態**：歷史決策，未作為現行實作交付（2026-10-14 重新核對）。

> 現行入口為 `AntigravityOauthService.login()`，使用內建 Antigravity client、外部瀏覽器與本機 callback，登入後取得 project id 並落地憑證；也可引用本機既有登入。它不是本文件規劃的 ZeroType 自有 Gemini OAuth client，倉庫也沒有 `assets/config/oauth.json`。目前 `login()` 未實作下方規劃的 PKCE，不能把歷史設計當作既有安全能力。現況請參閱 [CLAUDE.md](../../CLAUDE.md) 的 Antigravity 憑證說明；`1.5.5+13` 最新工作、驗證及 PR 交付狀態見 [task.md](../task.md)。此文件更新不變更 OAuth 程式，也不代表新版本已發布。

## 原決策

Gemini 官方通道需要一種不貼 API Key 的憑證方式。當時規劃由 ZeroType 自己當 desktop public client（PKCE），使用者同意的對象是 ZeroType，而不是去填 Client ID，也不是去複製 Antigravity 的長期 token。以下選項與後果只描述該歷史方案。

## Considered Options

- **內建公開 client（當時決策）**：按登入即可；桌面 App 藏不住 secret，規劃走 PKCE。要自行維護 Google Cloud 專案與同意畫面。
- **使用者自備 Client ID**：幾乎跟貼 API Key 一樣摩擦，否定了「少一個密鑰步驟」。
- **這版只做 Antigravity 本機登入引用**：交付較快，但沒裝 Antigravity 的人沒有 OAuth 路。

## Consequences

- Client ID 放在 `assets/config/oauth.json`，不把 secret 寫進程式。
- Antigravity 仍是本機登入引用，與這份 client 無關。
- 更換 client 等於使用者全部要重登，所以這份身份一旦發出去就很難改。
