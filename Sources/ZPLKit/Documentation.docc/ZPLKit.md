# ``ZPLKit``

Generate and render ZPL (Zebra Programming Language) labels with a declarative, type-safe Swift API.

## Overview

ZPLKit provides four modules:

- **ZPLKit**: Core label generation with result builders
- **ZPLKitRenderer**: Parse ZPL and render to PNG images
- **ZPLKitPrinter**: Send ZPL over TCP, discover printers, query and configure them
- **ZPLKitVerifier**: Verify rendered labels using Vision framework

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Fixtures>

### Core Types

- ``ZPLLabel``
- ``ZPLTemplate``
- ``ZPLElement``

### Text Elements

- ``Text``
- ``TextBlock``

### 1D Barcodes

- ``Barcode128``
- ``Code39``
- ``EAN13``
- ``EAN8``
- ``UPCA``
- ``UPCE``
- ``Interleaved2of5``

### 2D Barcodes

- ``QRCode``
- ``DataMatrix``
- ``PDF417``
- ``Aztec``
- ``IntelligentMail``

### Shapes

- ``Box``
- ``Circle``
- ``Ellipse``
- ``HorizontalLine``
- ``VerticalLine``
- ``DiagonalLine``

### Graphics and Utilities

- ``Graphic``
- ``SerialNumber``
- ``Comment``
- ``PrinterCommand``

### Types

- ``Position``
- ``Dimension``
- ``DPI``
- ``Rotation``
