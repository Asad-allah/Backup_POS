# Backup POS — Agent Context

> **Sheikh Al Jabal** offline-first Point of Sale system for a grocery/retail store in Lebanon.  
> Built with Flutter (Dart). Runs on Android tablets/phones.

---

## Project Identity

| Key | Value |
|-----|-------|
| **Name** | `backup_pos` |
| **Purpose** | Offline POS for daily sales, debt tracking, inventory, and order management |
| **Business** | Sheikh Al Jabal (شيخ الجبل) — grocery/retail store |
| **Location** | Lebanon (LBP ↔ USD dual currency display) |
| **Language** | UI is English, WhatsApp messages are Arabic |
| **Platform** | Android (tablets + phones) |
| **State mgmt** | Provider (ChangeNotifier) |
| **Database** | SQLite via `sqflite` (local), migrating to Supabase (cloud) |
| **Auth** | Currently hardcoded (`121362` = admin, `123` = staff) → migrating to Supabase Auth |
| **Version** | DB version 7 |

---

## Architecture

```
lib/
├── main.dart                    # Entry point, MultiProvider setup, AuthWrapper
├── models/                      # Pure data classes with toMap/fromMap/copyWith
│   ├── cart_item.dart
│   ├── customer.dart            # id, name, phone, created_at
│   ├── customer_debt.dart       # uuid(PK), customer_id, amount, type, shift_id, is_archived
│   ├── expiration_date.dart
│   ├── product.dart             # barcode-keyed, sell_price, buy_price, quantity
│   ├── purchase_order.dart
│   ├── purchase_order_item.dart
│   ├── shift.dart               # id(text PK), role, started_at, ended_at
│   ├── transaction.dart
│   └── transaction_item.dart
├── providers/                   # ChangeNotifier state managers
│   ├── cart_provider.dart       # In-memory cart for active sale
│   ├── debt_provider.dart       # Customers, debts, shifts, balances, daily/shift totals
│   ├── expiration_provider.dart # Expiry date tracking and notifications
│   ├── product_provider.dart    # Product CRUD + CSV import
│   ├── purchase_order_provider.dart  # Purchase order management
│   ├── settings_provider.dart   # Exchange rate (USD→LBP), stored in SharedPreferences
│   └── transaction_provider.dart     # Sales transactions
├── repositories/
│   └── debt_repository.dart     # All SQLite queries for customers, debts, shifts
├── screens/                     # UI screens (see Screen Map below)
├── services/                    # Business logic services
│   ├── csv_importer.dart        # Product CSV import
│   ├── database_csv_service.dart    # Full DB export/import via CSV
│   ├── database_helper.dart     # SQLite schema (7 tables, migrations v1→v7)
│   ├── debt_csv_service.dart    # Debt-specific CSV export/import with UUID sync
│   ├── debt_pdf_service.dart    # PDF statement generation for customers
│   ├── expiration_csv_service.dart  # Expiry data CSV
│   ├── notification_service.dart    # Local notifications for expiry alerts
│   ├── pdf_generator.dart       # Sale receipt PDF generation
│   └── purchase_order_csv_service.dart  # Order CSV export/import
├── theme/
│   └── theme_constants.dart     # AppTheme.darkTheme — dark monochrome + silver accent
└── widgets/                     # Reusable UI components
    ├── cart_item_tile.dart
    ├── compact_cart_card.dart
    └── transaction_tile.dart
```

---

## Database Schema (SQLite v7)

### Tables

```sql
-- Products (imported from CSV, barcode is natural key)
products (id PK, barcode UNIQUE, name, category, sell_price, buy_price, quantity)

-- Sales
transactions (id PK, transaction_number UNIQUE, date, total, item_count, status, synced_at, pdf_path)
transaction_items (id PK, transaction_id FK, barcode, product_name, quantity, unit_price, total_price, re_entered)

-- Expiration Tracking
expiration_dates (id PK, barcode, product_name, expiry_date, created_at, is_read)

-- Purchase Orders
purchase_orders (id PK, name, date, category, status)
purchase_order_items (id PK, order_id FK, type, barcode, name, quantity, status, estimated_price)

-- Customer Debt System
customers (id PK AUTOINCREMENT, name UNIQUE, phone, created_at)
customer_debts (uuid TEXT PK, customer_id FK, amount, note, date, shift_id, type, is_archived, target_record_uuid)
shifts (id TEXT PK, role, started_at, ended_at)
```

### Key Conventions
- `customer_debts.uuid` is generated as `{timestamp}_{random5}` — used for cross-device dedup
- `amount > 0` = debt, `amount < 0` = payment (type field also tracks: 'debt', 'payment', 'individual_payment')
- `is_archived` = soft-delete after "Pay All" — records stay for history
- `shift_id` links every transaction to who was working
- All dates stored as ISO 8601 strings

---

## Screen Map

| Screen | Purpose | Access |
|--------|---------|--------|
| `LoginScreen` | Password entry → role assignment → shift creation | Everyone |
| `HomeScreen` | Bottom nav hub (6 tabs, some admin-only) | Everyone |
| `NewSaleScreen` | Barcode scanning + cart + checkout | Everyone |
| `QuickKeysScreen` | Grid of frequently-sold items (no barcode needed) | Everyone |
| `PendingScreen` | Unsynced transactions queue | Everyone |
| `ExpirationScreen` | Expiry date tracking with category filters | Everyone |
| `PurchaseOrdersScreen` | Multi-order management | Everyone |
| `PurchaseOrderDetailScreen` | Order items + WhatsApp sharing | Everyone |
| `BuyPriceScreen` | Buy price editor (margin analysis) | Admin only |
| `DebtsDashboardScreen` | 3-tab view: My Shift / Current Day / Shift History | Everyone |
| `CustomersListScreen` | Customer directory with search + balance display | Everyone |
| `CustomerLedgerScreen` | Per-customer debt/payment history + actions | Everyone |
| `SettingsScreen` | CSV import/export, exchange rate, data management | Everyone |
| `DashboardScreen` | Sales analytics with charts | Admin only |

---

## Role System

| Role | Capabilities |
|------|-------------|
| **admin** | Full access: delete any record, pay debts, see buy prices, close business day, manage settings, generate reports |
| **staff** | Can add debts, scan sales, view expiry. Can only delete own debt records within 5 minutes. Cannot pay debts or see buy prices |

---

## Session & Shift Flow

```
Login → password check → determine role (admin/staff)
     → generate shift_id = "{timestamp}_{random}"
     → save to SharedPreferences: user_role, is_logged_in, current_shift_id
     → ensure business_day_start exists (set on first login of the day)
     → insert shift record to DB
     → navigate to HomeScreen

Logout (Close Shift) → end shift in DB (set ended_at)
                     → clear SharedPreferences session keys
                     → navigate to LoginScreen

Close Day (Admin) → close shift + clear business_day_start
```

---

## Key Patterns & Conventions

### Code Style
- **Dark theme everywhere**: `Color(0xFF121212)` background, `Color(0xFF1E1E1E)` cards, `Color(0xFF2C2C2C)` inputs
- **Animations**: `flutter_animate` used extensively — `.fadeIn()`, `.slideX()`, `.shake()` for errors
- **Typography**: Google Fonts — `Outfit` for headers, `Inter` for body
- **Haptics**: `HapticFeedback.lightImpact()` on tab switches
- **Sounds**: `flutter_ringtone_player` for payment confirmation

### Data Flow
```
Screen → Provider (ChangeNotifier) → Repository → SQLite (sqflite)
                                       ↑
                                  Services (CSV, PDF, etc.)
```

### WhatsApp Integration
- Used for: debt notifications, payment confirmations, order reports, customer statements
- Pattern: build message string → URL encode → `launchUrl('https://wa.me/{phone}?text={encoded}')`
- Messages are bilingual: Arabic for customer-facing, English for reports

### Currency Display
- Primary: USD (`$`) — stored in DB
- Secondary: LBP (Lebanese Pounds) — calculated via `SettingsProvider.exchangeRate` (default 90,000)
- Format: `$5.00 ≈ 450,000 L.L`

### CSV Sync (Current)
- Export: dumps all records to CSV in Downloads folder
- Import: additive merge using UUID dedup — never overwrites, only adds new records
- Archive sync: one-way (if remote is archived but local isn't → archive locally)

---

## External Dependencies

| Package | Purpose |
|---------|---------|
| `sqflite` | Local SQLite database |
| `provider` | State management |
| `shared_preferences` | Session persistence (login state, shift ID, settings) |
| `flutter_animate` | UI animations |
| `google_fonts` | Typography (Outfit, Inter) |
| `mobile_scanner` | Barcode/QR scanning |
| `barcode_widget` | Barcode display in receipts |
| `pdf` + `printing` | PDF receipt/report generation |
| `csv` + `file_picker` | CSV import/export |
| `intl` | Date formatting |
| `fl_chart` | Sales analytics charts |
| `url_launcher` | WhatsApp deep links |
| `flutter_ringtone_player` | Payment sound effects |
| `flutter_local_notifications` | Expiry alerts |
| `flutter_svg` | SVG logo rendering |
| `path_provider` + `path` | File system paths |

---

## Supabase Integration (In Progress)

| Key | Value |
|-----|-------|
| **Project** | `bwysjqzwuyqmxqxebuci` |
| **URL** | `https://bwysjqzwuyqmxqxebuci.supabase.co` |
| **Tables created** | `customers`, `customer_debts`, `shifts` (mirror of local schema + `updated_at`, `device_id`) |
| **Strategy** | Online-first with local SQLite as offline cache |
| **Auth** | Migrating from hardcoded passwords to Supabase Auth with `user_profiles` table |

---

## Common Gotchas

1. **Weighted barcodes**: EAN-13 starting with "2" encode weight in last 6 digits. `normalizeWeightedBarcode()` strips them to match the product DB.
2. **Amount sign convention**: debts = positive, payments = negative. The `type` field is the source of truth, but `amount > 0` is used widely in UI for color/icon decisions.
3. **Business day ≠ calendar day**: `business_day_start` is set on first login and cleared on "Close Day". A business day can span midnight.
4. **Shift ID format**: `{millisecondsSinceEpoch}_{random5}` — not a proper UUID but unique enough for single-device use.
5. **Navigator vs routes**: The app uses `MaterialPageRoute` push/pop, NOT named routes (except `pushNamedAndRemoveUntil('/')` for full resets).
6. **Camera disposal**: `HomeScreen._buildCurrentScreen()` recreates screens on demand (not cached) to ensure proper camera/scanner disposal.
7. **`context.read` after `await`**: Several screens use `context.read` after async gaps. Works but triggers `use_build_context_synchronously` warnings.
