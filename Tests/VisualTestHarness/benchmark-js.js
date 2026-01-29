import { readdir, readFile } from 'fs/promises';
import { join, basename } from 'path';
import { ready } from 'zpl-renderer-js';

const FIXTURES_DIR = './fixtures';

const dpiToDpmm = { 152: 6, 203: 8, 300: 12, 600: 24 };

function parseFilename(filename) {
    const match = filename.match(/_(\d+)x(\d+)_(\d+)\.zpl$/);
    return {
        widthInches: match ? parseInt(match[1]) : 4,
        heightInches: match ? parseInt(match[2]) : 6,
        dpi: match ? parseInt(match[3]) : 203
    };
}

async function main() {
    const files = await readdir(FIXTURES_DIR);
    const zplFiles = files.filter(f => f.endsWith('.zpl')).sort();

    console.log(`Loading zpl-renderer-js...`);
    const { api } = await ready;
    console.log(`Benchmarking ${zplFiles.length} fixtures...\n`);

    const times = [];

    for (const file of zplFiles) {
        const { widthInches, heightInches, dpi } = parseFilename(file);
        const zpl = await readFile(join(FIXTURES_DIR, file), 'utf-8');

        const widthMm = widthInches * 25.4;
        const heightMm = heightInches * 25.4;
        const dpmm = dpiToDpmm[dpi] || 8;

        const start = performance.now();
        await api.zplToBase64Async(zpl, widthMm, heightMm, dpmm);
        const elapsed = performance.now() - start;

        times.push({ name: basename(file, '.zpl'), time: elapsed });
        console.log(`  ${file}: ${elapsed.toFixed(1)}ms`);
    }

    const total = times.reduce((sum, t) => sum + t.time, 0);
    const avg = total / times.length;
    const min = Math.min(...times.map(t => t.time));
    const max = Math.max(...times.map(t => t.time));

    console.log(`\n═══════════════════════════════════════════════════`);
    console.log(`  zpl-renderer-js Benchmark (${times.length} fixtures)`);
    console.log(`═══════════════════════════════════════════════════\n`);
    console.log(`                    Min       Avg       Max`);
    console.log(`  ─────────────────────────────────────────────────`);
    console.log(`  Render Time     ${min.toFixed(1).padStart(5)}ms   ${avg.toFixed(1).padStart(5)}ms   ${max.toFixed(1).padStart(5)}ms`);
    console.log(`  ─────────────────────────────────────────────────\n`);
    console.log(`  Total for all ${times.length} fixtures: ${total.toFixed(0)}ms`);
    console.log(`  Throughput: ${(times.length / (total / 1000)).toFixed(0)} labels/second\n`);
}

main().catch(console.error);
