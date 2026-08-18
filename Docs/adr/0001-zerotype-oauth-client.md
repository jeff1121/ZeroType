# ZeroType 以內建公開 OAuth client 發起 Gemini 官方通道登入

Gemini 官方通道需要一種不貼 API Key 的憑證方式。我們決定由 ZeroType 自己當 desktop public client（PKCE），使用者同意的對象是 ZeroType，而不是去填 Client ID，也不是去複製 Antigravity 的長期 token。

**Status**: accepted

## Considered Options

- **內建公開 client（採用）**：按登入即可；桌面 App 藏不住 secret，必須走 PKCE。要自行維護 Google Cloud 專案與同意畫面。
- **使用者自備 Client ID**：幾乎跟貼 API Key 一樣摩擦，否定了「少一個密鑰步驟」。
- **這版只做 Antigravity 本機登入引用**：交付較快，但沒裝 Antigravity 的人沒有 OAuth 路。

## Consequences

- Client ID 放在 `assets/config/oauth.json`，不把 secret 寫進程式。
- Antigravity 仍是本機登入引用，與這份 client 無關。
- 更換 client 等於使用者全部要重登，所以這份身份一旦發出去就很難改。
