# User Stories: Loob Unified App

This document outlines the core user stories based on the four mandatory modules required for the assessment, plus wishlist enhancements.

## Module 1: Menu
**Epic:** As a customer, I want to easily browse and customise beverages and food items so that I can order exactly what I want.
- **US1.1:** As a user, I want to toggle between the Tealive and Baskbear storefronts from the home screen so that I can view brand-specific menus.
- **US1.2:** As a user, I want the app UI to comfortably display my native language (Thai, Vietnamese, Chinese, Indonesian, etc.) without cutting off text or breaking the layout.
- **US1.3:** As a user, I want to browse items grouped by category and see dietary tags (e.g., Vegan, Halal).
- **US1.4:** As a user, I want to customise my beverage (size, ice, sugar, toppings).

## Module 2: Ordering
**Epic:** As a customer, I want to manage my cart and place orders efficiently, even during busy periods.
- **US2.1:** As a user, I want to add items from both Tealive and Baskbear into a single, unified shopping cart grouped by location.
- **US2.2:** As a user, I want to choose my fulfillment method: Dine-in, Takeaway, or Delivery.
- **US2.3:** As a user, I want to track the real-time status of my order and view my past order history.
- **US2.4 (Peak Load / Flash Sale):** As a user participating in a high-traffic campaign, I want to see clear queueing UI feedback during checkout rather than experiencing app crashes.

## Module 3: Vouchers, Loyalty & Campaigns
**Epic:** As a customer, I want to participate in loyalty programs, discover campaigns, and apply discounts to maximize value.
- **US3.1:** As a user, I want to view dynamic promotional banners (Banner Delivery System) relevant to my region and current brand context.
- **US3.2:** As a user, I want to perform a "Daily Check-in" to earn loyalty points or unlock gamified rewards.
- **US3.3:** As a user, I want to view my "Voucher Wallet" and apply percentage or fixed-amount discounts.
- **US3.4:** As a user, I want to interact with embedded social media feeds (`flutter_social_embed`) directly within the app to see the latest community trends.
- **US3.5:** As a user, I want to participate in webview-based mini-games for special campaigns without needing to update the app.

## Module 4: Multi-Country & App Experience
**Epic:** As a regional customer, I want the app to feel native to my location, deeply integrated with my device, and adhere to local business rules.
- **US4.1 (Smart Detection):** As a new user, I want the app to automatically detect my country (even if I deny GPS permission) so I instantly see the correct currency and language.
- **US4.2 (Dynamic Branding):** As a user, I want to choose my preferred brand and have the app dynamically update its App Icon and Splash Screen on my phone to match.
- **US4.3:** As a user, I want the app to automatically apply the correct regional tax rules (e.g., SST in Malaysia, VAT in Thailand) at checkout based on my detected/selected region.
- **US4.4:** As a user, I want to see store opening hours correctly adjusted to my local timezone.
- **US4.5 (Language Configuration):** As an admin, I want to configure a specific list of supported languages for each country (e.g., Malaysia supports ms, en, zh; Thailand supports th, en) so that users only see relevant language options.