^XA
^FX DESCRIPTION: Barcode module width test using ^BY command. Multiple Code
^FX 128 barcodes at different widths (1-4) showing how module width affects
^FX barcode size.
^PW812
^LL406
^FO30,30^A0N,30,30^FDBarcode Module Width^FS
^FO30,70^BY1^BCN,60,Y,N,N^FDNARROW^FS
^FO30,160^BY3^BCN,60,Y,N,N^FDMEDIUM^FS
^FO30,250^BY5^BCN,60,Y,N,N^FDWIDE^FS
^FO500,70^A0N,20,20^FD^BY1^FS
^FO500,160^A0N,20,20^FD^BY3^FS
^FO500,250^A0N,20,20^FD^BY5^FS
^XZ
