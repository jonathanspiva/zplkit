import { readdir, readFile, writeFile, mkdir } from 'fs/promises';
import { join, basename } from 'path';
import { ready } from 'zpl-renderer-js';

const FIXTURES_DIR = './fixtures';
const OUTPUT_DIR = './output';

// DPI to DPMM conversion
const dpiToDpmm = {
    152: 6,
    203: 8,
    300: 12,
    600: 24
};

async function renderAll() {
    // Ensure output directory exists
    await mkdir(OUTPUT_DIR, { recursive: true });

    // Get all .zpl files
    let files;
    try {
        files = await readdir(FIXTURES_DIR);
    } catch {
        console.log('No fixtures directory found. Run Swift tests first to generate ZPL files.');
        return;
    }

    const zplFiles = files.filter(f => f.endsWith('.zpl'));

    if (zplFiles.length === 0) {
        console.log('No .zpl files found in fixtures/');
        return;
    }

    console.log(`Rendering ${zplFiles.length} ZPL file(s)...`);
    console.log('Loading ZPL renderer...');

    const { api } = await ready;

    console.log('Renderer ready.\n');

    for (const file of zplFiles) {
        const zplPath = join(FIXTURES_DIR, file);
        const pngName = basename(file, '.zpl') + '.png';
        const pngPath = join(OUTPUT_DIR, pngName);

        try {
            const zpl = await readFile(zplPath, 'utf-8');

            // Parse label dimensions from filename or use defaults
            // Format: name_WxH_DPI.zpl (e.g., test_4x6_203.zpl)
            const match = file.match(/_(\d+)x(\d+)_(\d+)\.zpl$/);
            const widthInches = match ? parseInt(match[1]) : 4;
            const heightInches = match ? parseInt(match[2]) : 6;
            const dpi = match ? parseInt(match[3]) : 203;

            // Convert to mm and dpmm for the renderer
            const widthMm = widthInches * 25.4;
            const heightMm = heightInches * 25.4;
            const dpmm = dpiToDpmm[dpi] || 8;

            const base64 = await api.zplToBase64Async(zpl, widthMm, heightMm, dpmm);
            const buffer = Buffer.from(base64, 'base64');

            await writeFile(pngPath, buffer);
            console.log(`  ✓ ${file} → ${pngName}`);
        } catch (err) {
            console.error(`  ✗ ${file}: ${err.message}`);
        }
    }

    console.log('\nDone.');
}

renderAll().catch(console.error);
