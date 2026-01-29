import { readdir, readFile, writeFile, mkdir } from 'fs/promises';
import { join, basename } from 'path';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

const OUTPUT_DIR = './output';
const BASELINES_DIR = './baselines';
const DIFF_DIR = './output/diffs';
const THRESHOLD = 0.001; // 0.1% difference threshold

async function compareAll() {
    // Ensure diff directory exists
    await mkdir(DIFF_DIR, { recursive: true });

    // Get all output PNGs
    const outputFiles = await readdir(OUTPUT_DIR);
    const pngFiles = outputFiles.filter(f => f.endsWith('.png') && !f.includes('/diffs/'));

    if (pngFiles.length === 0) {
        console.log('No .png files found in output/');
        return;
    }

    console.log(`Comparing ${pngFiles.length} image(s)...`);

    let failures = 0;
    let newBaselines = 0;

    for (const file of pngFiles) {
        const outputPath = join(OUTPUT_DIR, file);
        const baselinePath = join(BASELINES_DIR, file);
        const diffPath = join(DIFF_DIR, file);

        try {
            const outputData = await readFile(outputPath);
            const outputPng = PNG.sync.read(outputData);

            let baselineData;
            try {
                baselineData = await readFile(baselinePath);
            } catch {
                console.log(`  ⚠ ${file}: No baseline (run 'npm run update-baselines' to create)`);
                newBaselines++;
                continue;
            }

            const baselinePng = PNG.sync.read(baselineData);

            // Check dimensions match
            if (outputPng.width !== baselinePng.width || outputPng.height !== baselinePng.height) {
                console.error(`  ✗ ${file}: Dimension mismatch (${outputPng.width}x${outputPng.height} vs ${baselinePng.width}x${baselinePng.height})`);
                failures++;
                continue;
            }

            // Create diff image
            const { width, height } = outputPng;
            const diff = new PNG({ width, height });

            const numDiffPixels = pixelmatch(
                outputPng.data,
                baselinePng.data,
                diff.data,
                width,
                height,
                { threshold: 0.1 }
            );

            const diffPercent = numDiffPixels / (width * height);

            if (diffPercent > THRESHOLD) {
                // Write diff image for review
                await writeFile(diffPath, PNG.sync.write(diff));
                console.error(`  ✗ ${file}: ${(diffPercent * 100).toFixed(2)}% different (see ${diffPath})`);
                failures++;
            } else {
                console.log(`  ✓ ${file}`);
            }
        } catch (err) {
            console.error(`  ✗ ${file}: ${err.message}`);
            failures++;
        }
    }

    console.log('');
    if (newBaselines > 0) {
        console.log(`${newBaselines} new baseline(s) needed.`);
    }
    if (failures > 0) {
        console.error(`${failures} comparison(s) failed.`);
        process.exit(1);
    } else {
        console.log('All comparisons passed.');
    }
}

compareAll().catch(err => {
    console.error(err);
    process.exit(1);
});
