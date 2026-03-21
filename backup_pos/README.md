# Backup POS

Offline backup POS system for when main system is down.

## Quick Start
```bash
cd backup_pos
flutter pub get
flutter run -d chrome
```

## Features
- CSV product import
- Barcode scanning
- Cart with quantity controls
- PDF receipt generation
- Re-entry mode with scannable barcodes

## Workflows
See `.agent/workflows/` for detailed guides:
- `/run-app` - Running the app
- `/import-csv` - Importing products
- `/process-sale` - Processing sales
- `/reentry` - Re-entering transactions
