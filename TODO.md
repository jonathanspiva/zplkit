# ZPLKit TODO

## Now
- [ ] Nothing active

## Later
- [ ] GitHub Actions workflow for Labelary comparison (optional CI validation step)
- [ ] Label templates with variable substitution
- [ ] Stored formats (`^DF`, `^XF`)
- [ ] DocC documentation
- [ ] CHANGELOG.md

## Someday
- [ ] Graphics/images (`^GF`, `~DG`) via separate ZPLKitGraphics package
- [ ] Barcode decode verification - use zxing-js to scan rendered barcodes and verify encoded data matches input

## Never

## Done

### v1.0 Scope
- [x] Core ZPL elements (Text, TextBlock, Box, Barcode128, QRCode, DataMatrix, Code39)
- [x] Shapes (Box, HorizontalLine, VerticalLine)
- [x] README with quick start example
- [x] GitHub Actions CI workflow (build/test on macOS + Linux)
- [x] Visual test harness with zpl-renderer-js

### v2.0 Scope
- [x] Additional shapes (Circle, Ellipse, DiagonalLine)
- [x] Additional barcodes (PDF417, Interleaved2of5, EAN13, UPCA, Aztec)
- [x] Serial number support (`^SN`)
- [x] Baseline text positioning (`^FT`)
- [x] Labelary comparison tool for renderer validation
- [x] Additional barcodes (EAN8, UPCE, IntelligentMail)
