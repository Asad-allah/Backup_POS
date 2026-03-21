# Backup POS - Project Context

## Overview
A Flutter mobile app that serves as an **offline backup POS system** for when the main system is down. The app processes sales offline, generates PDF receipts, then allows re-entering transactions into the main system by displaying barcodes one-by-one.

## Core Workflow
```
1. Import CSV → Products stored in SQLite
2. Customer arrives → Scan/Search items → Build cart → Generate PDF receipt → Save transaction
3. System back online → Open "Pending" tab → Display barcodes item-by-item → Scan into main POS → Mark as synced
```

## Architecture

### Tech Stack
- **Framework**: Flutter 3.38+
- **State Management**: Provider pattern
- **Database**: SQLite (sqflite)
- **Barcode Scanning**: mobile_scanner
- **Barcode Display**: barcode_widget
- **PDF Generation**: pdf + printing packages

### Key Features
- ✅ 100% Offline functionality
- ✅ CSV import with full replace
- ✅ Continuous barcode scanning
- ✅ Cart with +/- quantity controls
- ✅ PDF receipt generation (thermal format)
- ✅ 3-tab navigation with badge on Pending tab
- ✅ Re-entry mode with scannable barcodes
- ✅ Arabic text support (RTL)

## Data Structure

### CSV Format (ALL.CSV)
- **Encoding**: UTF-16
- **Column 2**: Barcode
- **Column 3**: Product Name (Arabic/English)
- **Column 11**: Sell Gross price
- **Categories**: Rows where Column 0 has text but Column 2 is empty

### Database Tables
1. `products` - Imported from CSV
2. `transactions` - Sale records (pending/synced)
3. `transaction_items` - Items per transaction

## File Structure
```
backup_pos/
├── lib/
│   ├── main.dart
│   ├── models/          # Data models
│   ├── providers/       # State management
│   ├── services/        # Database, CSV, PDF
│   ├── screens/         # UI screens
│   └── widgets/         # Reusable components
└── assets/              # Sample data
```

## UI Specifications
- **Colors**: Primary Blue #2196F3, Success Green #4CAF50
- **Touch Targets**: Minimum 48x48 dp
- **Barcode Display**: 300x100 dp minimum, black on white
