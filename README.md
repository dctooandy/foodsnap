# FoodSnap

拍下食材照片，用 Claude 自動辨識、翻譯、估算熱量，再生成食譜——一個 Flutter + Firebase + Claude API 的個人練習專案。

## 功能

- 拍照 / 從相簿選取 / 手動輸入食材，AI 辨識食材名稱、估算克數與熱量
- 拍照後先在裝置端（Google ML Kit）判斷有沒有拍到食物、自動裁切到食物主體再送出辨識，避免浪費每日額度在無意義的照片上
- 確認食材後生成多個菜名候選，可先看 YouTube 影片參考，再決定要不要生成完整文字食譜
- 食譜可分享、可存進個人歷史紀錄
- 選菜名頁、食譜頁都有「回首頁」按鈕，看完影片或看完食譜可以直接跳回拍照首頁，不用一路按返回鍵
- 每份食譜看滿 3 次算「熟悉」，依料理分類（台式／中式／日式／韓式／西式／東南亞／甜點烘焙／其他）累積星星，集滿合成銅／銀／金徽章
- 匿名登入即可使用，登入 Google／Apple 帳號解鎖更高的每日使用次數（帳號升級會保留原本的匿名資料，不會遺失）

## 技術棧

- **Client**：Flutter
- **後端**：Firebase（Authentication、Firestore、Cloud Functions）
- **AI（雲端）**：Anthropic Claude API
  - `claude-opus-4-8`：食材辨識（含圖片）、完整食譜生成
  - `claude-haiku-4-5`：輕量的菜名候選生成（便宜、夠用，不需要動用到 Opus）
- **AI（裝置端）**：Google ML Kit Object Detection——拍照後本地跑，離線也能動，用來判斷照片有沒有食物、算出食物區域再裁切，不佔用 Claude API 額度

## 流程

```
拍照／相簿／手動輸入
  → (裝置端) ML Kit 物件偵測：判斷有沒有食物、算出食物區域
      ├─ 沒偵測到食物 → 跳確認提示，使用者可選重新選擇（不消耗額度）或仍要送出
      └─ 偵測到食物但只占畫面一部分 → 自動裁切到食物主體
  → analyzeFood（Claude Opus 視覺辨識，手動輸入則跳過這步）
  → 確認食材頁（可勾選、編輯、手動新增）
  → suggestDishNames（Claude Haiku，生成 3-5 個菜名候選）
  → 選一個菜名（頁面右上角可「回首頁」）
      ├─ 看影片參考（開啟 YouTube 搜尋，純外部連結不花 API 成本）
      └─ generateRecipe（Claude Opus，生成完整食譜）
  → 食譜頁（可分享、可加入我的紀錄、可「回首頁」）
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
- **Google ML Kit 的 CocoaPods 在 Apple Silicon 模擬器缺 arm64 slice**：`flutter build ios --simulator` 能編譯成功，但 GoogleMLKit／MLKitVision／MLKitObjectDetection 這幾個 pod 目前沒有模擬器用的 arm64 版本，模擬器上的偵測結果不可靠。這類 on-device AI 功能要用真機測，不能只看模擬器。另外 `google_mlkit_object_detection` 要求 iOS 15.5+，把原本 13.0 的 deployment target 往上調了。

## 設計上刻意「先不做」的決定

- 生成食譜目前完全靠 Claude 自身知識，沒有接 web search 去參考真實網路食譜——延遲和成本的增加還沒被證實划算，先觀察使用情況再說。
- 目前沒有內購／付費解鎖機制——App Store 內購本身就需要付費 Developer 帳號（跟 Sign in with Apple 同一個前提），加上目前的每日額度已經把最壞情況的成本鎖住了，等有真實使用者、真的有人一直卡在額度上限，再回頭做也不遲。

## 更新歷程

上面各節都只描述「目前」的狀態；這節按批次記錄每次更新做了什麼、為什麼做。從這次更新開始記錄，之前的 commit 歷史不在此列。

### 批次 1（2026-07-20）：On-device 食物照片預檢 + 物件框選/裁切

**原因**：整個 App 的 AI 推論原本全部在雲端（Claude API），沒有 on-device 這塊——這次刻意補上，同時也順便解決一個實際問題：使用者拍到不相關或食物只占畫面一小角的照片時，還是照樣送出去給 Claude 辨識，白白燒掉一次每日額度。

- **功能**：拍照/選圖後，先在裝置端跑 ML Kit 物件偵測——完全沒偵測到食物就跳確認提示（可選「重新選擇」，不消耗額度）；有偵測到食物但只占畫面一部分就自動裁切到食物主體再送出。
- **技術棧**：新增 `google_mlkit_object_detection`（On-device AI，離線可跑）、`image`（裁切/重新編碼 JPEG）。
- **流程**：在「拍照／相簿／手動輸入」和「analyzeFood」之間插入一段裝置端偵測，見上面流程圖。Cloud Function（`analyzeFood.ts`）合約不變，純 client 端優化。
- **踩坑紀錄**：`google_mlkit_object_detection` 要求 iOS 15.5+，把原本 13.0 的 deployment target 調高；Google ML Kit 的 CocoaPods 在 Apple Silicon 模擬器缺 arm64 slice，模擬器上的偵測結果不可靠，要用真機測。

### 批次 2（2026-07-20）：選菜名頁／食譜頁加「回首頁」按鈕

**原因**：批次 1 做完後回頭看整個流程，發現使用者在食譜頁看完食譜、或在選菜名頁看完影片參考後，如果想開始下一輪拍照，得照原路一路按返回鍵退好幾層（食譜頁 → 選菜名頁 → 確認食材頁 → 拍照首頁），體驗不好。

- **功能**：選菜名頁、食譜頁的 AppBar 都加了「回首頁」圖示按鈕，點下去直接跳回拍照首頁。
- **技術棧**：無變動，純 `Navigator.popUntil((route) => route.isFirst)`。
- **流程**：不影響原本的辨識/生成流程，只是多一條「隨時可以跳回首頁」的捷徑，見上面流程圖裡標注的位置。
- **踩坑紀錄**：無。
