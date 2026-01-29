# ``ZPLKit``

Generate and render ZPL (Zebra Programming Language) labels with a declarative, type-safe Swift API.

## Overview

ZPLKit provides three modules:

- **ZPLKit**: Core label generation with result builders
- **ZPLKitRenderer**: Parse ZPL and render to PNG images
- **ZPLVerifier**: Verify rendered labels using Vision framework

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Fixtures>

### Core Types

- ``ZPLLabel``
- ``ZPLTemplate``
- ``ZPLElement``

### Elements

- ``Text``
- ``TextBlock``
- ``Barcode128``
- ``Code39``
- ``QRCode``
- ``Box``
- ``Circle``

### Types

- ``Position``
- ``Dimension``
- ``DPI``
- ``Rotation``
