# ZeroType

桌面語音轉寫輸入的領域語言。這裡只定義概念，不含實作細節。

## Language

**Provider**：
語音轉寫後端供應商。目前是 `openai` 與 `gemini`。它決定文字由哪套模型家族產生，不決定走官方或 Proxy，也不決定怎麼登入。
_Avoid_: 串接方式、帳號、登入來源、通道

**通道**：
某個 Provider 底下，請求實際打去哪裡。每個 Provider 都有官方與 Proxy 兩條通道。**官方通道**打該 Provider 的官方 API；**Proxy 通道**打使用者提供的根位址。兩邊的模型可以同名，互不覆蓋。OAuth 仍只存在於 Gemini 官方通道。
_Avoid_: Provider、自訂 endpoint（舊說法）

**官方通道**：
打 Provider 官方 API 的通道。Gemini 的 API Key、Gemini OAuth、Antigravity OAuth 都只活在這條通道。
_Avoid_: 官方 Provider

**Proxy 通道**：
打自訂 endpoint 的通道。只使用 API Key，不使用 OAuth。
_Avoid_: 第三方 Provider、gemini-proxy

**Proxy 根位址**：
使用者為 Proxy 通道填的主機根。模型目錄與轉寫呼叫都從這個根推導，不必填兩個位址。
_Avoid_: 完整轉寫 URL、列模型 URL

**使用中通道**：
某個 Provider 當下實際拿來轉寫的那一條通道。官方與 Proxy 的設定同時保存，但一次只有一條使用中通道。切換通道不丟另一邊的設定，也不自動改選。
_Avoid_: 自動挑選、自訂 endpoint 開關

**模型目錄**：
某個通道可選的模型集合。官方通道用使用中憑證向該 Provider 官方 API 查詢；尚未有使用中憑證、或查詢失敗時，退回內建目錄。Proxy 通道向該通道查詢。兩邊目錄互不覆蓋。目錄暫時查不到時，仍可沿用該通道上次選的模型來轉寫。
_Avoid_: Provider 清單、轉寫前置閘門、Antigravity 別名目錄

**轉寫呼叫**：
把音檔交給使用中通道、換回文字的那一次請求。模型目錄怎麼查，可以跟轉寫呼叫的表面不同。
_Avoid_: 列模型

**憑證方式**：
證明有權呼叫某個通道的方式。Gemini 官方通道同時存在 API Key 與 OAuth；Gemini Proxy 通道與 OpenAI 目前只有 API Key。
_Avoid_: Provider、串接方式

**API Key**：
使用者自行貼上的長期密鑰。它是一種憑證方式，不是 Provider。官方通道與 Proxy 通道各自保存自己的 API Key，互不覆蓋。
_Avoid_: Token、帳號

**OAuth 憑證**：
用 Google 帳號取得、用來呼叫 Gemini 官方通道的授權狀態。它是一種憑證方式，與 API Key 並列。Gemini OAuth 在 ZeroType 內只對應一個 Google 帳號；再次登入會取代既有憑證。
_Avoid_: API Key、帳號列表

**登入來源**：
OAuth 憑證從哪裡來。**Gemini OAuth** 由 ZeroType 自己發起 Google 授權；**Antigravity OAuth** 沿用本機 Antigravity 既有登入。兩者都不是新 Provider。
_Avoid_: Provider、供應商

**ZeroType OAuth client**：
ZeroType 用來發起 Gemini OAuth 的公開應用身份。使用者同意的對象是 ZeroType，不是 Antigravity。
_Avoid_: 使用者自備 Client ID、API Key

**使用中憑證**：
使用中通道當下實際拿來轉寫的那一份憑證。各通道的憑證分開保存。失效時轉寫必須失敗，不得改用其他已存憑證，也不得改走另一條通道。
_Avoid_: 預設 Provider、自動挑選

**憑證失效**：
使用中憑證當下無法取得有效授權。這是轉寫失敗原因，不是自動改選其他憑證或通道的信號。
_Avoid_: 未設定、網路錯誤

**未選擇**：
使用中通道目前沒有使用中憑證。轉寫視為尚未完成設定，不是憑證失效。
_Avoid_: 憑證失效

**中斷連線**：
移除 ZeroType 持有的 Gemini OAuth 憑證。若它是使用中憑證，使用中變為未選擇。停止使用 Antigravity 只是改選使用中憑證，不會登出 Antigravity。
_Avoid_: 登出 Antigravity

**轉寫紀錄**：
一次成功轉寫留下的本機紀錄。包含文字、音檔、Provider、通道、model、當時的憑證方式，以及用量與花費。不包含 Google 帳號 email。
_Avoid_: 帳號紀錄

**本機登入引用**：
Antigravity OAuth 的取用方式。ZeroType 每次轉寫前讀本機 `oauth_creds.json`，不把 refresh_token 複製進 ZeroType。來源登出、檔案消失，或 refresh 失敗即失效。
_Avoid_: 匯入、複製 token 到 ZeroType 儲存

**更新授權**：
在不重新走登入來源的前提下，把既有短期授權換成新的。Gemini OAuth 更新 ZeroType 自己持有的憑證。Antigravity OAuth 用本機檔的 refresh_token 向 Google 換新，並把新的 access_token 與 expiry_date 寫回同一檔。失敗才成為憑證失效。
_Avoid_: 重新登入、自動改用 API Key
