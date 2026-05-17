# UX & App Design Direction: "The Twin App"

Based on the brand analysis of Tealive (Playful, Vibrant, Purple/Yellow) and Baskbear (Bold, Urban, Orange/Black), the Loob Unified App must execute a delicate balancing act. It cannot be a generic "food delivery" template; it must feel like a native experience for *both* brands.

## 1. The Core UX Philosophy: "The Three-Tiered Portal"

Instead of forcing users to choose a brand immediately, the app acts as a unified portal utilizing a **3-Tab Navigation System** at the top of the Home Screen: `[ Discover All ] | [ Tealive ] | [ Baskbear ]`.

*   **The Default "Discover All" Tab:** This is the landing page. It operates in the **Neutral "Loob" Theme** (clean whites, soft grays). This tab is highly personalized, surfacing cross-brand bundles (e.g., "Boba & Toastie Combo"), global Master Vouchers, and recent orders from either brand.
*   **The Brand Immersion Tabs:** When the user swipes or taps the Tealive or Baskbear tab, the entire `ThemeData` of the Flutter app dynamically transitions:
    *   *Tealive Tab:* The UI floods with vibrant Purple `#5E2750`, rounded bubbly typography, and playful micro-animations.
    *   *Baskbear Tab:* The UI crossfades into deep Charcoal Black `#1C1C1C` with striking Orange `#FF6B00` accents, using sharper, bolder, "street-style" fonts.

## 2. Structural Design & Layout

### A. The "Neutral Zone" (Discover Tab, Cart & Checkout)
Whenever the user is viewing multi-brand elements, the app utilizes the clean Neutral Theme to prevent visual clashing (e.g., a Purple Tealive Boba and an Orange Baskbear Toastie sitting in the same cart).
*   **Typography:** A highly legible, pan-Asian friendly sans-serif (e.g., Noto Sans or Inter) to gracefully handle English, Thai, and Chinese characters simultaneously.

### B. The Home Feed (Materialized View)
*   **Greeting:** Personalized. "Good Morning, [Name]. Time for a coffee?" (Highlights Baskbear items first in the AM) vs. "Good Afternoon! Craving Boba?" (Highlights Tealive items first in the PM).
*   **Modules (Combined Tab):**
    *   **Dynamic Hero Banner:** Edge-to-edge images served via the CDN (showing cross-promotions).
    *   **"Order Again":** Horizontal scrolling list of previous orders spanning both brands for 1-tap reordering.
    *   **Gamification Hub:** A floating action button or prominent card for the "Daily Check-in" streak that rewards universal Loob points.

### C. The Menu Browsing Experience
*   **Visual Hierarchy:** High-quality, deep-etched product photography. Drink customization (Size, Sugar, Ice) is handled via a bottom sheet modal rather than navigating away to a new page, keeping the user anchored to the menu.
*   **Dietary & Culture Badges:** Small, instantly recognizable icon tags (Halal, Vegan, Contains Dairy) placed next to the price tag.

## 3. Micro-Interactions & "Delight"

To fulfill the "Wishlist" requirement for a rich, modern aesthetic, the app will utilize Flutter's animation capabilities.

*   **The Liquid Transition:** When toggling between brands, instead of a hard cut, use a "liquid" or "reveal" animation where the new brand color sweeps across the screen.
*   **Haptic Feedback:** Subtle vibrations when adding an item to the cart, applying a voucher, or successfully completing the Daily Check-in.
*   **Dynamic App Icon:** When the user indicates a strong preference (e.g., they order Baskbear 80% of the time), a popup asks: *"Make Baskbear your default? We'll update your home screen icon!"* (Utilizing `flutter_dynamic_icon`).

## 4. Multi-Language & Typography Constraints

Southeast Asian expansion requires strict layout rules to prevent broken UI:
*   **No Fixed Heights:** Text containers for product names must use `Expanded` or `Flexible` with `maxLines: 2` and `overflow: TextOverflow.ellipsis`. Thai and Vietnamese use vertical diacritics that get clipped in fixed-height boxes.
*   **Icon-Driven UI:** Where possible, replace text with universally understood iconography (e.g., a thermometer icon for "Hot/Cold", a sugar cube for "Sugar Level") to reduce translation bloat and UI clutter.

## 5. Summary of the User Journey

1.  **Launch:** Neutral Splash Screen -> Instantly fades into the user's last-visited brand theme.
2.  **Discover:** Personalized home feed. User sees a Baskbear "Morning Toastie" promo.
3.  **Switch:** User swipes the top toggle. The screen turns purple. They are now browsing the Tealive menu.
4.  **Add to Cart:** Selects "Signature Boba". Bottom sheet slides up for Sugar/Ice levels. Taps "Add". Haptic buzz.
5.  **Checkout:** Taps the Cart. UI reverts to the clean Neutral Zone. User sees both the Toastie and the Boba. Applies a "Loob Master Voucher".
6.  **Success:** Receives queue number. App enters "Polling Mode" showing a playful animation while the Go ordering worker processes the SQS queue.
