# ZeroType

桌面語音轉寫輸入的領域語言。這裡只定義概念，不含實作細節。

## Language

**Provider**：
語音轉寫後端供應商。目前是 `openai`、`gemini` 與 `azure`。它決定轉寫使用的後端，不決定憑證方式；Azure 只提供官方通道。
_Avoid_: 串接方式、帳號、登入來源、通道

**通道**：
某個 Provider 底下，請求實際打去哪裡。OpenAI 與 Gemini 有官方與 Proxy 兩條通道，Azure 只有官方通道。**官方通道**打該 Provider 的官方 API；**Proxy 通道**打使用者提供的根位址。兩邊的模型可以同名，互不覆蓋。OAuth 仍只存在於 Gemini 官方通道。
_Avoid_: Provider、自訂 endpoint（舊說法）

**官方通道**：
打 Provider 官方 API 的通道。Gemini 的 API Key 與 Antigravity OAuth 都只活在這條通道；舊的獨立 Gemini OAuth 選項已移除。
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
某個通道提供的模型集合，以原始 model ID 識別。選單只顯示完整 ID 並依 ID 排序；供應商顯示名稱可能重複或與 ID 版本不同，僅留在資料層，不用作選項標籤。ID 是請求識別碼，也不能單憑 ID 推定供應商實際路由到哪個底層版本。官方通道用使用中憑證向該 Provider 官方 API 查詢，Proxy 通道向該通道查詢。成功的空目錄與查詢失敗是不同結果。失敗時先沿用同來源上次成功的記憶體目錄，再採用適合該通道與憑證方式的內建目錄；來源必須明示，不能宣稱遠端更新成功。Provider、通道、endpoint 與憑證情境不同的目錄互不覆蓋。目錄暫時查不到時，仍可沿用該通道上次選的模型來轉寫。
_Avoid_: Provider 清單、轉寫前置閘門、Antigravity 別名目錄

**轉寫能力判定**：
模型是否符合目前轉寫請求的已知能力。Antigravity 依有效的 `supportedMimeTypes` 判斷目前送出的 `audio/mp4`；分為支援、不支援、未確認。沒有能力欄位或無法判讀時為未確認，不得視為不支援；支援輸入格式也不等於已完成實際音檔測試。不同通道使用自己的能力契約，Azure 部署維持不按模型名稱過濾。
_Avoid_: 只看名稱猜能力、所有模型已驗證可用

**保留選取**：
更新目錄不改寫上次選擇的原始 ID。目錄未列出時單獨保留；若最新能力判定為不支援，保留並警示但不提供為新選擇。既有轉寫流程保持不變，目錄結果不加入 `isReady`，不自動選另一個模型、通道或憑證。
_Avoid_: 更新後自動改選、按顯示名稱合併

**轉寫呼叫**：
把音檔交給使用中通道、換回文字的那一次請求。模型目錄怎麼查，可以跟轉寫呼叫的表面不同。
_Avoid_: 列模型

**可見轉寫文字**：
模型正式回傳給使用者的逐字稿，與思考內容及其簽章分開。Gemini 的第一個候選可含多段內容；逐字稿依序合併該候選的可見文字，不混入思考段落，也不拼接其他候選。帶思考簽章的文字不必然是思考內容。首段空白不等於整份逐字稿為空；封鎖、輸出截斷、只有思考或沒有可讀文字都不能當成完整逐字稿。正常文字片段全為空白時走空結果流程，但不能僅憑空文字推定錄音沒有聲音。
_Avoid_: 只取第一段文字、合併多個候選、將思考內容貼上、截斷回應視為成功

**憑證方式**：
證明有權呼叫某個通道的方式。Gemini 官方通道可選 API Key 或 Antigravity OAuth；Gemini Proxy 通道、OpenAI 與 Azure 使用 API Key。
_Avoid_: Provider、串接方式

**API Key**：
使用者自行貼上的長期密鑰。它是一種憑證方式，不是 Provider。官方通道與 Proxy 通道各自保存自己的 API Key，互不覆蓋。
_Avoid_: Token、帳號

**OAuth 憑證**：
用 Google 帳號取得、用來呼叫 Gemini 官方通道的授權狀態。現行由 Antigravity OAuth 登入或引用本機授權，與 API Key 並列；舊的獨立 Gemini OAuth 入口已於 v1.2.0 移除。
_Avoid_: API Key、帳號列表

**登入來源**：
OAuth 憑證從哪裡來。現行 **Antigravity OAuth** 可由 App 發起 Google 授權並落地憑證，或引用本機既有登入；它不是新 Provider。**Gemini OAuth** 為已移除的歷史入口。
_Avoid_: Provider、供應商

**ZeroType OAuth client**：
歷史設計詞彙，現行未啟用 ZeroType 自有 Gemini OAuth client；目前登入使用 Antigravity OAuth client。見 `Docs/adr/0001-zerotype-oauth-client.md` 的歷史決策註記。
_Avoid_: 使用者自備 Client ID、API Key

**使用中憑證**：
使用中通道當下實際拿來轉寫的那份授權。各通道設定分開保存；無法透過使用中的憑證方式取得有效授權時，轉寫失敗，不自動改選 API Key／OAuth 或另一條通道。Antigravity 的本機引用會從其候選來源取用授權，不代表 App 已固定綁定某個帳號或檔案。
_Avoid_: 預設 Provider、自動挑選

**憑證失效**：
使用中憑證當下無法取得有效授權。這是轉寫失敗原因，不是自動改選其他憑證或通道的信號。
_Avoid_: 未設定、網路錯誤

**未選擇**：
使用中通道目前沒有使用中憑證。轉寫視為尚未完成設定，不是憑證失效。
_Avoid_: 憑證失效

**中斷連線**：
移除 ZeroType 自有 Gemini OAuth 憑證的歷史設計。現行停止使用 Antigravity 是改選使用中憑證，不會登出或刪除 Antigravity 的本機登入。
_Avoid_: 登出 Antigravity

**轉寫紀錄**：
一次成功轉寫留下的本機紀錄。包含文字、音檔、Provider、通道、model、當時的憑證方式，以及用量與花費。不包含 Google 帳號 email。
_Avoid_: 帳號紀錄

**本機登入引用**：
Antigravity OAuth 的取用方式。ZeroType 每次轉寫前優先引用 `~/.cli-proxy-api/antigravity-*.json`，亦支援 `~/.gemini/oauth_creds.json`，依候選順序尋找可用授權；不把 refresh_token 複製到 App 設定。無法取得有效授權時視為失效。已在等待更新的來源若被替換或刪除，該次請求不再沿用舊授權，也不以另一份新授權補回結果。
_Avoid_: 匯入、複製 token 到 ZeroType 儲存

**更新授權**：
在不重新登入的前提下，把既有短期授權換成新的。Antigravity OAuth 用本機檔的 refresh_token 向 Google 換新，核對來源仍是同一份後，將新授權與到期時間寫回。同一來源的正常續期不改變模型目錄所屬情境；另一帳號或來源的授權不能混入該次更新。
_Avoid_: 重新登入、自動改用 API Key

**目錄來源情境**：
判斷某份模型目錄可以沿用的範圍，由 Provider、通道、根位址及憑證身分共同決定。它與選取哪個 model ID 不同；選模型不會另查目錄。更新中可沿用同情境的清單，失敗時的來源與原因必須可辨識；不同情境與晚到的舊請求不能覆蓋目前目錄。
_Avoid_: 只按 Provider 共用快取、以顯示名稱判定來源、選模型就重新登入
