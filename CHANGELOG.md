# Changelog

## [v0.1.7] - 2025-12-16

### ✨ 新增功能 (Features)
- **購物車管理 (Cart Management)**: 
    - **批量刪除**: 新增長按選取模式 (Selection Mode)，支援多選刪除購物車。
    - **滑動刪除**: 支援單一購物車往左滑動刪除 (Swipe to Dismiss)。
- **視覺優化 (UI Refinement)**:
    - **頭像光圈**: 淺色模式下的大頭貼光圈改為 **品牌紫 (Brand Purple)**，提升對比度與質感。

### 📅 產品藍圖更新 (Roadmap Update)
- **Phase 14 - 自動化**: 規劃了「智慧庫存」與「價格追蹤 2.0」。
- **Phase 15 - 智慧分析**: 規劃了「家庭預算管家」與「生活型態分析」。

## [v0.1.6] - 2025-12-15

### 🎨 UI/UX 設計升級 (Visual Overhaul)
- **全新側邊選單 (Glassmorphic Drawer)**:
  - 實作毛玻璃特效的左側功能選單，點擊大頭貼觸發。
  - 整合「個人資料」、「家庭群組 (Placeholder)」、「雲端同步控制」與「主題切換」。
  - 採用半透明背景設計，提升整體質感。

- **AppBar 視覺優化**:
  - **互動式頭像**: 增加動態漸層光圈 (Gradient Ring) 與連線狀態綠點，提示可點擊。
  - **智慧配色**: 標題與圖示顏色現在會根據「太陽/月亮」模式自動切換 (深色/白色)，解決淺色背景下文字看不清的問題。
  - **字體統一**: 全面將 App 字體統一為 `Noto Sans TC`，解決切換主題時字體行高不同導致的畫面跳動問題。

- **主題切換邏輯修復**:
  - 修正了在「系統預設 (System)」模式下，切換按鈕判斷錯誤的問題。現在直接依據當前亮度進行切換。

## [v0.1.5] - 2025-12-15

### ✨ 新增功能 (Features)
- **雲端資料同步 (Cloud Sync)**:
  - 實作 `FirestoreService` 與 `MigrationService`，支援將本機資料 (歷史紀錄、收藏、購物車) 備份至 Firebase Firestore。
  - **自動同步**: 登入時自動執行「上傳與還原 (Merge)」流程。
  - **手動同步**: 首頁 AppBar 新增雲端按鈕，支援隨時手動觸發資料備份。
  - **資料結構**: 採用 `users/{uid}/history` 與 `carts/{id}` 分離架構，為未來的家庭共享鋪路。

### 🐛 修正 (Fixes)
- **序列化修復**: 解決 `Invalid argument: Instance of 'Product'` 錯誤，修正 `SearchRecord` 的 JSON 轉換邏輯。
- **還原邏輯**: 修正同步只上傳不下載的問題，現在更換裝置後可自動還原雲端紀錄。
- **UI 優化**: 移除 `HomeScreen` 未使用的變數並更新過時的 `withOpacity` API。

## [v0.1.4] - 2025-12-15

### ✨ 新增功能 (Features)
- **身分驗證整合 (Firebase Auth)**:
  - 實作 Google 登入功能 (`signInWithGoogle`)。
  - 整合 Firebase 核心初始化流程 (`firebase_core`, `firebase_options`)。
- **全新登入介面 (Login UI)**:
  - 新增 `LoginScreen`，採用星空漸層設計。
  - 首頁頂部整合使用者狀態顯示 (頭像/訪客模式)。
- **資安架構升級**:
  - 確立 Phase 9 安全性藍圖 (Cloud Functions, App Check)。
  - 修復 `google_sign_in` 版本相容性問題。

### 🛠️ 修正 (Fixes)
- **相容性修復**: 降級 `google_sign_in` 至 6.2.1 以解決建構子變更導致的編譯錯誤。
- **配置修正**: 協助排除 Android SHA-1 驗證失敗 (Error 10) 的常見問題。

### 📝 未來規劃 (Next Steps)
- [ ] 雲端資料同步 (Firestore Migration)。
- [ ] 家庭購物車共享功能。

## [v0.1.3] - 2025-12-15
*   **New Feature: Custom Shopping Lists**
    *   Create, rename, and delete multiple shopping carts.
    *   "My Carts" entry point on Home Screen.
    *   Add items directly from Search Results to specific carts.
    *   View total estimated price for each cart.
    *   One-tap navigation to product purchase pages from cart.
*   **UI/UX Improvements**
    *   Fixed Home Screen overflow issue on smaller screens (adjusted flex ratios).
    *   Refined Cart Detail UI: Removed "Checkout" button, centered total price.
    *   Enhanced `ResultScreen` add-to-cart interaction.

## [v0.1.2] - 2025-12-15

### ✨ 新增功能 (Features)
- **AI 智能辨識與搜尋優化 (`GeminiService`)**:
    - **電商選品專家模式**: 升級 Prompt 指令，專注於生成「高搜尋價值」的關鍵字。
    - **智慧推論**: 當品牌模糊時，AI 能根據包裝特徵（形狀、顏色）推論具體商品類別（如：將「紅色條狀物」推論為「鱈魚香絲」），而非回傳無用的視覺描述。
    - **辨識上限提升**: 單次辨識上限提升至 **20 項** 商品。
    - **精準 OCR**: 強制讀取包裝文字，輸出「品牌 + 品名 + 規格」格式。
- **收藏清單管理 (`FavoritesScreen`)**:
    - **批量刪除**: 新增「選取模式」，支援長按或點擊選取按鈕進行多選刪除。
    - **單筆刪除保護**: 商品卡片新增獨立刪除按鈕，並加入「確認刪除」對話框，防止誤觸。

### 💄 介面優化 (UI/UX)
- **搜尋結果頁 (`ResultScreen`)**:
    - **頂部視覺增強**: 新增頂部漸層遮罩 (Gradient Scrim)，確保標題與按鈕在任何背景下皆清晰可見。
    - **AppBar 風格統一**: 標題與圖示改為純白色系並加上陰影，提升整體質感與沈浸感。
    - **卡片優化**: 調整商品列表的陰影與間距，視覺更舒適。

### 🐛 錯誤修復 (Fixes)
- 修復 `ResultScreen` 頂部文字在淺色圖片上無法閱讀的問題。
- 修復 `FavoritesScreen` 可能出現重複 import 的問題。

---

## 待辦事項 (Todo List)
- [ ] **比價功能實作**: 串接真實的電商搜尋 API (如 Google Custom Search 或特定電商 API)。
- [ ] **多圖搜尋**: 支援一次上傳多張圖片進行辨識。
- [ ] **使用者偏好設定**: 儲存排序偏好或主題模式。

---


## [0.1.1] - 2025-12-15

### ✨ 新增功能 (New Features)
- **離線歷史紀錄 (Offline History)**
  - 點擊歷史紀錄不再消耗 API，直接顯示快取結果，實現「秒開」體驗。
  - 即便原始圖片被系統清除，系統也能透過保存的「關鍵字」自動還原搜尋結果。
  - 新增「重新搜尋 (Re-search)」按鈕，允許使用者手動更新舊紀錄的價格與資訊。

### 🛠️ 修正與優化 (Fixes & Improvements)
- **搜尋結果儲存修復 (Persistence Fix)**
  - 修正了歷史紀錄 ID 建立時機過晚，導致第一批搜尋結果無法被儲存的問題。現在搜尋結果會完整保存。
- **結果排序優化 (Ordering Fix)**
  - 修正離線讀取時商品順序錯亂的問題，現在保證與原始搜尋順序一致。
- **錯誤處理 (Error Handling)**
  - 強化圖片遺失時的容錯機制，避免 App 崩潰並自動切換至關鍵字搜尋模式。

## [0.1.0] - 2025-12-15

### ✨ 新增功能 (Features)
- **全面介面統一 (UI Unification)**：
  - 將應用程式所有頁面 (`HistoryScreen`, `FavoritesScreen`, `ResultScreen`) 的風格統一為 **Starry Night (星空黑)** 與 **Pastel Sunset (粉嫩漸層)** 主題。
  - 實作 **Glassmorphism (玻璃擬態)** 設計語言，提升視覺質感。
  - **ResultScreen 改版**：移除舊版灰色背景，改為全透明 AppBar 與動態漸層背景，實現沉浸式搜尋體驗。
- **智能組合優化 (Smart Bundle Optimizer)**：
  - 在詳細頁面中新增 **最佳組合明細 (Bundle Detail Sheet)**。
  - 支援 **互動式排除**：使用者可勾選或取消特定商品，即時重新計算最佳購買組合。
  - 提供 **直接購買連結**：針對組合內的每個商品提供前往賣場的按鈕。

### 🛠️ 修正與優化 (Fixes & Improvements)
- **語法錯誤修復**：徹底解決了 `ResultScreen` 因重構導致的括號錯位、參數定義錯誤與重複引用問題。
- **程式碼品質**：移除多餘的 `import` 並優化了 `flutter analyze` 的檢測結果。
- **架構優化**：將主題相關邏輯 (Gradients) 集中於 `AppTheme`，便於未來維護與擴充。

### 📝 待辦事項 (Coming Soon / TODO)
- [ ] User Authentication (使用者登入系統)
- [ ] Backend Sync (雲端資料同步)
- [ ] iOS Platform Validation (iOS 平台驗證)
