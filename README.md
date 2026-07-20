# FoodSnap

拍下食材照片，用 Claude 自動辨識、翻譯、估算熱量，再生成食譜——一個 Flutter + Firebase + Claude API 的個人練習專案。

## 功能

- 拍照 / 從相簿選取 / 手動輸入食材，AI 辨識食材名稱、估算克數與熱量
- 確認食材後生成多個菜名候選，可先看 YouTube 影片參考，再決定要不要生成完整文字食譜
- 食譜可分享、可存進個人歷史紀錄
- 每份食譜看滿 3 次算「熟悉」，依料理分類（台式／中式／日式／韓式／西式／東南亞／甜點烘焙／其他）累積星星，集滿合成銅／銀／金徽章
- 匿名登入即可使用，登入 Google／Apple 帳號解鎖更高的每日使用次數（帳號升級會保留原本的匿名資料，不會遺失）

## 技術棧

- **Client**：Flutter
- **後端**：Firebase（Authentication、Firestore、Cloud Functions）
- **AI**：Anthropic Claude API
  - `claude-opus-4-8`：食材辨識（含圖片）、完整食譜生成
  - `claude-haiku-4-5`：輕量的菜名候選生成（便宜、夠用，不需要動用到 Opus）

## 流程

```
拍照／相簿／手動輸入
  → analyzeFood（Claude Opus 視覺辨識，手動輸入則跳過這步）
  → 確認食材頁（可勾選、編輯、手動新增）
  → suggestDishNames（Claude Haiku，生成 3-5 個菜名候選）
  → 選一個菜名
      ├─ 看影片參考（開啟 YouTube 搜尋，純外部連結不花 API 成本）
      └─ generateRecipe（Claude Opus，生成完整食譜）
  → 食譜頁（可分享、可加入我的紀錄）
      → 歷史紀錄頁（看滿 3 次 → 熟悉 → 該分類星星 +1）
      → 成就頁（8 個分類的星星／徽章進度）
```

**額度限制**：`analyzeFood`／`generateRecipe`／`suggestDishNames` 共用同一組每日額度，用 Firestore transaction 在 Cloud Function 端原子性檢查與扣除（`users/{uid}/usage/{date}`），前端無法竄改。匿名帳號每日 3 次，登入 Google／Apple 後 20 次。

## 開發踩坑紀錄

- **CocoaPods `Error in the HTTP2 framing layer`**：`pod install` 在解析 Firebase 這種大型依賴樹時會平行發出大量請求，單一請求用 curl 測試是正常的，但大量併發請求會被路由器／網路環境卡住。換一個網路（例如手機熱點）就解決了，判斷是路由器處理不了太多併發 HTTP/2 連線，不是程式或設定的問題。
- **Firestore Console「文件不存在」但底下有子集合**：因為程式只直接寫入巢狀路徑（例如 `users/{uid}/usage/{date}`），從沒寫過 `users/{uid}` 這個父層文件本身。Firestore 允許這種狀態，Console 會顯示「這份文件不存在」，但子集合清單裡看得到資料，點進子集合才是正確路徑。
- **Sign in with Apple 需要付費 Apple Developer Program 帳號**：免費 Personal Team 帳號在 Xcode 裡完全無法加上這個 capability，不是設定問題，是 Apple 的硬性限制。
- **啟用新的登入方式後，設定檔要重新下載**：在 Firebase Console 啟用 Google 登入後，`GoogleService-Info.plist`（iOS）與 `google-services.json`（Android）都要重新下載才會補上 `CLIENT_ID`／`oauth_client` 等欄位，舊檔案不會自動更新。
- **Android Google 登入需要額外登記 SHA-1**：沒有在 Firebase Console 登記簽名金鑰的 SHA-1 指紋，正式簽名的 build 在原生登入流程會直接失敗（`DEVELOPER_ERROR`）。
- **匿名登入撐不住重灌**：`signInAnonymously()` 產生的帳號綁在裝置本機，砍掉 App 重新安裝就會拿到全新帳號、額度形同重置。解法是用 `linkWithCredential` 把 Google／Apple 帳號「升級」到既有的匿名帳號上，uid 不變、資料不會遺失，而不是直接另外 `signIn`。

## 設計上刻意「先不做」的決定

- 生成食譜目前完全靠 Claude 自身知識，沒有接 web search 去參考真實網路食譜——延遲和成本的增加還沒被證實划算，先觀察使用情況再說。
- 目前沒有內購／付費解鎖機制——App Store 內購本身就需要付費 Developer 帳號（跟 Sign in with Apple 同一個前提），加上目前的每日額度已經把最壞情況的成本鎖住了，等有真實使用者、真的有人一直卡在額度上限，再回頭做也不遲。
