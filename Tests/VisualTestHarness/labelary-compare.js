import { readdir, readFile, writeFile, mkdir } from 'fs/promises';
import { join, basename } from 'path';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

const FIXTURES_DIR = './fixtures';
const OUTPUT_DIR = './output';
const LABELARY_DIR = './output/labelary';
const DIFF_DIR = './output/labelary-diffs';

// Labelary API uses dpmm values
const dpiToDpmm = {
    152: 6,
    203: 8,
    300: 12,
    600: 24
};

// Rate limiting: 2 requests per second (Labelary supports 3, but be nice)
const RATE_LIMIT_MS = 500;

// Threshold for acceptable differences between renderers
// Higher than baseline comparison since renderers may differ slightly
const THRESHOLD = 0.05; // 5% difference threshold

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Crop image to specified dimensions (top-left aligned)
function cropImage(png, targetWidth, targetHeight) {
    const cropped = new PNG({ width: targetWidth, height: targetHeight });
    for (let y = 0; y < targetHeight; y++) {
        for (let x = 0; x < targetWidth; x++) {
            const srcIdx = (png.width * y + x) << 2;
            const dstIdx = (targetWidth * y + x) << 2;
            cropped.data[dstIdx] = png.data[srcIdx];
            cropped.data[dstIdx + 1] = png.data[srcIdx + 1];
            cropped.data[dstIdx + 2] = png.data[srcIdx + 2];
            cropped.data[dstIdx + 3] = png.data[srcIdx + 3];
        }
    }
    return cropped;
}

async function renderWithLabelary(zpl, widthInches, heightInches, dpi) {
    const dpmm = dpiToDpmm[dpi] || 8;
    const url = `http://api.labelary.com/v1/printers/${dpmm}dpmm/labels/${widthInches}x${heightInches}/0/`;

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'image/png'
        },
        body: zpl
    });

    if (!response.ok) {
        const text = await response.text();
        throw new Error(`Labelary API error: ${response.status} - ${text}`);
    }

    return Buffer.from(await response.arrayBuffer());
}

async function compareRenderers() {
    // Ensure output directories exist
    await mkdir(LABELARY_DIR, { recursive: true });
    await mkdir(DIFF_DIR, { recursive: true });

    // Get all .zpl files
    let files;
    try {
        files = await readdir(FIXTURES_DIR);
    } catch {
        console.log('No fixtures directory found. Run Swift tests first to generate ZPL files.');
        process.exit(1);
    }

    const zplFiles = files.filter(f => f.endsWith('.zpl'));

    if (zplFiles.length === 0) {
        console.log('No .zpl files found in fixtures/');
        process.exit(1);
    }

    console.log(`Comparing ${zplFiles.length} fixture(s) between zpl-renderer-js and Labelary...`);
    console.log('');

    let failures = 0;
    let skipped = 0;
    let passed = 0;

    for (const file of zplFiles) {
        const zplPath = join(FIXTURES_DIR, file);
        const pngName = basename(file, '.zpl') + '.png';
        const localPath = join(OUTPUT_DIR, pngName);
        const labelaryPath = join(LABELARY_DIR, pngName);
        const diffPath = join(DIFF_DIR, pngName);

        try {
            // Check if local render exists
            let localData;
            try {
                localData = await readFile(localPath);
            } catch {
                console.log(`  ⚠ ${file}: No local render (run 'npm run render' first)`);
                skipped++;
                continue;
            }

            const zpl = await readFile(zplPath, 'utf-8');

            // Parse label dimensions from filename
            const match = file.match(/_(\d+)x(\d+)_(\d+)\.zpl$/);
            const widthInches = match ? parseInt(match[1]) : 4;
            const heightInches = match ? parseInt(match[2]) : 6;
            const dpi = match ? parseInt(match[3]) : 203;

            // Render with Labelary
            const labelaryBuffer = await renderWithLabelary(zpl, widthInches, heightInches, dpi);
            await writeFile(labelaryPath, labelaryBuffer);

            // Compare the two renders
            const localPng = PNG.sync.read(localData);
            const labelaryPng = PNG.sync.read(labelaryBuffer);

            // Handle small dimension differences (renderers may round differently)
            // Use the smaller dimensions for comparison
            const width = Math.min(localPng.width, labelaryPng.width);
            const height = Math.min(localPng.height, labelaryPng.height);

            // Warn if dimensions differ significantly (more than 4 pixels, accounting for higher DPI)
            const widthDiff = Math.abs(localPng.width - labelaryPng.width);
            const heightDiff = Math.abs(localPng.height - labelaryPng.height);
            if (widthDiff > 4 || heightDiff > 4) {
                console.error(`  ✗ ${file}: Significant dimension mismatch`);
                console.error(`      Local: ${localPng.width}x${localPng.height}`);
                console.error(`      Labelary: ${labelaryPng.width}x${labelaryPng.height}`);
                failures++;
                await sleep(RATE_LIMIT_MS);
                continue;
            }

            // Crop both images to common dimensions for comparison
            const localCropped = cropImage(localPng, width, height);
            const labelaryCropped = cropImage(labelaryPng, width, height);

            // Create diff image
            const diff = new PNG({ width, height });

            const numDiffPixels = pixelmatch(
                localCropped.data,
                labelaryCropped.data,
                diff.data,
                width,
                height,
                { threshold: 0.1 }
            );

            const diffPercent = numDiffPixels / (width * height);

            if (diffPercent > THRESHOLD) {
                await writeFile(diffPath, PNG.sync.write(diff));
                console.error(`  ✗ ${file}: ${(diffPercent * 100).toFixed(2)}% different`);
                console.error(`      See: ${labelaryPath} (Labelary)`);
                console.error(`      See: ${diffPath} (diff)`);
                failures++;
            } else if (diffPercent > 0.001) {
                // Minor difference, note but don't fail
                console.log(`  ~ ${file}: ${(diffPercent * 100).toFixed(2)}% different (within tolerance)`);
                passed++;
            } else {
                console.log(`  ✓ ${file}`);
                passed++;
            }

            // Rate limiting
            await sleep(RATE_LIMIT_MS);

        } catch (err) {
            console.error(`  ✗ ${file}: ${err.message}`);
            failures++;
            await sleep(RATE_LIMIT_MS);
        }
    }

    console.log('');
    console.log('Summary:');
    console.log(`  Passed: ${passed}`);
    if (skipped > 0) {
        console.log(`  Skipped: ${skipped}`);
    }
    if (failures > 0) {
        console.error(`  Failed: ${failures}`);
        console.log('');
        console.log('Note: Differences between renderers may be expected due to:');
        console.log('  - Font rendering differences');
        console.log('  - Barcode/QR code implementation variations');
        console.log('  - Anti-aliasing differences');
        process.exit(1);
    } else {
        console.log('');
        console.log('All fixtures rendered consistently between zpl-renderer-js and Labelary.');
    }
}

// Allow running specific fixtures via command line
const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
    console.log('Usage: node labelary-compare.js [options]');
    console.log('');
    console.log('Compares ZPL rendering between local zpl-renderer-js and Labelary API.');
    console.log('');
    console.log('Options:');
    console.log('  --help, -h     Show this help message');
    console.log('');
    console.log('Prerequisites:');
    console.log('  1. Run "npm run render" to generate local renders first');
    console.log('  2. Requires internet access to reach api.labelary.com');
    console.log('');
    console.log('Output:');
    console.log('  output/labelary/      - Labelary-rendered images');
    console.log('  output/labelary-diffs/ - Diff images for failures');
    process.exit(0);
}

compareRenderers().catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
});
