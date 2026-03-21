---
description: How to import CSV products into the app
---

# Importing CSV Products

## CSV File Requirements
- **Encoding**: UTF-16 (like ALL.CSV)
- **Format**: 
  - Column 2: Barcode
  - Column 3: Product Name
  - Column 11: Sell Gross price (e.g., `$ 1.67`)
- **Categories**: Rows with text in Column 0 but empty Column 2

## Steps

1. Open the app
2. Tap the settings/menu icon (top right)
3. Select "Import CSV"
4. Choose your CSV file (e.g., ALL.CSV)
5. Confirm replacement: "Replace all products?"
6. Wait for import to complete
7. Success message: "Imported X products"

## Troubleshooting

### "Invalid CSV format"
- Check file encoding is UTF-16
- Verify column positions match expected format

### "No products imported"
- Ensure barcode column (2) has valid data
- Check price column (11) has valid prices

## Sample File
Use `e:\Backup_POS\ALL.CSV` as reference format
