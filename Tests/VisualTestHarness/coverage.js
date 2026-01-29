import { readdir, readFile } from 'fs/promises';
import { join } from 'path';

const FIXTURES_DIR = './fixtures';

// Commands supported by ZPLKit v1.1
const SUPPORTED_COMMANDS = {
    // Label Format
    '^XA': { category: 'Label Format', description: 'Start format', element: 'ZPLLabel' },
    '^XZ': { category: 'Label Format', description: 'End format', element: 'ZPLLabel' },
    '^PW': { category: 'Label Format', description: 'Print width', element: 'ZPLLabel' },
    '^LL': { category: 'Label Format', description: 'Label length', element: 'ZPLLabel' },

    // Field Positioning
    '^FO': { category: 'Field Positioning', description: 'Field origin', element: 'All elements' },
    '^LH': { category: 'Field Positioning', description: 'Label home', element: 'ZPLLabel.labelHome()' },

    // Text and Fonts
    '^A': { category: 'Text/Fonts', description: 'Scalable font', element: 'Text, TextBlock' },
    '^CF': { category: 'Text/Fonts', description: 'Change default font', element: 'ZPLLabel.defaultFont()' },
    '^FD': { category: 'Text/Fonts', description: 'Field data', element: 'All elements' },
    '^FS': { category: 'Text/Fonts', description: 'Field separator', element: 'All elements' },
    '^FB': { category: 'Text/Fonts', description: 'Field block', element: 'TextBlock' },
    '^FH': { category: 'Text/Fonts', description: 'Field hex indicator', element: 'Text (auto)' },
    '^FR': { category: 'Text/Fonts', description: 'Field reverse', element: 'Text.reversed()' },

    // Barcodes
    '^BC': { category: 'Barcodes', description: 'Code 128', element: 'Barcode128' },
    '^BQ': { category: 'Barcodes', description: 'QR Code', element: 'QRCode' },
    '^B3': { category: 'Barcodes', description: 'Code 39', element: 'Code39' },
    '^BX': { category: 'Barcodes', description: 'DataMatrix', element: 'DataMatrix' },
    '^B7': { category: 'Barcodes', description: 'PDF417', element: 'PDF417' },
    '^B2': { category: 'Barcodes', description: 'Interleaved 2 of 5', element: 'Interleaved2of5' },
    '^BY': { category: 'Barcodes', description: 'Barcode defaults', element: 'Barcode128.moduleWidth()' },

    // Graphics
    '^GB': { category: 'Graphics', description: 'Graphic box', element: 'Box, Lines' },
    '^GC': { category: 'Graphics', description: 'Graphic circle', element: 'Circle' },
    '^GE': { category: 'Graphics', description: 'Graphic ellipse', element: 'Ellipse' },
    '^GD': { category: 'Graphics', description: 'Graphic diagonal', element: 'DiagonalLine' },

    // Print Control
    '^PQ': { category: 'Print Control', description: 'Print quantity', element: 'ZPLLabel.printQuantity()' },
    '^MD': { category: 'Print Control', description: 'Media darkness', element: 'ZPLLabel.printDarkness()' },
};

// Known ZPL commands (for tracking what we could support)
const ALL_KNOWN_COMMANDS = [
    // Label Format
    '^XA', '^XZ', '^PW', '^LL', '^LH', '^LS',
    // Field
    '^FO', '^FT', '^FD', '^FS', '^FB', '^FH', '^FR', '^FW', '^FN',
    // Fonts
    '^A', '^CF', '^CW',
    // Barcodes
    '^BC', '^BQ', '^B3', '^BX', '^BY', '^BE', '^B8', '^BU', '^B9', '^BO', '^B7', '^BA', '^B2', '^B1',
    // Graphics
    '^GB', '^GC', '^GD', '^GE', '^GF', '^GS',
    // Print Control
    '^PQ', '^MD', '^PR', '^PH', '^PM', '^PO',
    // Other
    '^CI', '^CV', '^DF', '^XF', '^SF', '^SN',
];

function extractCommands(zpl) {
    const commands = new Set();
    // Match ^XX patterns - commands can be letter + letter/number (e.g., ^B3, ^BQ, ^A0)
    const regex = /\^([A-Z][A-Z0-9]?)/g;
    let match;
    while ((match = regex.exec(zpl)) !== null) {
        let cmd = '^' + match[1];
        // ^A followed by a digit (0-9, A-Z) is the scalable font command
        // Normalize ^A0, ^AA, etc. to ^A for tracking
        if (cmd.match(/^\^A[0-9A-Z]$/)) {
            cmd = '^A';
        }
        commands.add(cmd);
    }
    return commands;
}

async function analyzeCoverage() {
    let files;
    try {
        files = await readdir(FIXTURES_DIR);
    } catch {
        console.log('No fixtures directory found.');
        return;
    }

    const zplFiles = files.filter(f => f.endsWith('.zpl'));

    if (zplFiles.length === 0) {
        console.log('No .zpl files found.');
        return;
    }

    const allUsedCommands = new Set();
    const commandsByFile = {};

    // Analyze each file
    for (const file of zplFiles) {
        const zpl = await readFile(join(FIXTURES_DIR, file), 'utf-8');
        const commands = extractCommands(zpl);
        commandsByFile[file] = commands;
        commands.forEach(cmd => allUsedCommands.add(cmd));
    }

    console.log('═══════════════════════════════════════════════════════════════');
    console.log('                    ZPL COMMAND COVERAGE REPORT                 ');
    console.log('═══════════════════════════════════════════════════════════════\n');

    // Supported commands coverage
    const supportedKeys = Object.keys(SUPPORTED_COMMANDS);
    const usedSupported = supportedKeys.filter(cmd => allUsedCommands.has(cmd));
    const unusedSupported = supportedKeys.filter(cmd => !allUsedCommands.has(cmd));

    console.log(`Fixtures analyzed: ${zplFiles.length}`);
    console.log(`Unique commands found: ${allUsedCommands.size}`);
    console.log(`Supported commands: ${supportedKeys.length}`);
    console.log(`Supported commands exercised: ${usedSupported.length}/${supportedKeys.length} (${Math.round(usedSupported.length/supportedKeys.length*100)}%)\n`);

    // Coverage by category
    const categories = {};
    for (const [cmd, info] of Object.entries(SUPPORTED_COMMANDS)) {
        if (!categories[info.category]) {
            categories[info.category] = { total: 0, used: 0, commands: [] };
        }
        categories[info.category].total++;
        categories[info.category].commands.push({ cmd, used: allUsedCommands.has(cmd) });
        if (allUsedCommands.has(cmd)) {
            categories[info.category].used++;
        }
    }

    console.log('COVERAGE BY CATEGORY:');
    console.log('─────────────────────────────────────────────────────────────────');
    for (const [cat, data] of Object.entries(categories)) {
        const pct = Math.round(data.used / data.total * 100);
        const bar = '█'.repeat(Math.round(pct / 5)) + '░'.repeat(20 - Math.round(pct / 5));
        console.log(`${cat.padEnd(20)} ${bar} ${data.used}/${data.total} (${pct}%)`);
    }

    // Unused supported commands
    if (unusedSupported.length > 0) {
        console.log('\n⚠️  SUPPORTED BUT NOT TESTED IN FIXTURES:');
        console.log('─────────────────────────────────────────────────────────────────');
        for (const cmd of unusedSupported) {
            const info = SUPPORTED_COMMANDS[cmd];
            console.log(`  ${cmd.padEnd(6)} - ${info.description} (${info.element})`);
        }
    }

    // Commands used but not in our supported list
    const unsupportedUsed = [...allUsedCommands].filter(cmd => !SUPPORTED_COMMANDS[cmd]);
    if (unsupportedUsed.length > 0) {
        console.log('\n📋 COMMANDS USED IN FIXTURES BUT NOT IN SUPPORTED LIST:');
        console.log('─────────────────────────────────────────────────────────────────');
        console.log(`  ${unsupportedUsed.join(', ')}`);
    }

    // Detailed command usage
    console.log('\n📊 COMMAND USAGE DETAIL:');
    console.log('─────────────────────────────────────────────────────────────────');
    const usageCounts = {};
    for (const [file, commands] of Object.entries(commandsByFile)) {
        for (const cmd of commands) {
            usageCounts[cmd] = (usageCounts[cmd] || 0) + 1;
        }
    }

    const sortedUsage = Object.entries(usageCounts).sort((a, b) => b[1] - a[1]);
    for (const [cmd, count] of sortedUsage) {
        const supported = SUPPORTED_COMMANDS[cmd] ? '✅' : '❓';
        const desc = SUPPORTED_COMMANDS[cmd]?.description || 'Unknown';
        console.log(`  ${supported} ${cmd.padEnd(6)} used in ${count.toString().padStart(2)} fixture(s) - ${desc}`);
    }

    console.log('\n═══════════════════════════════════════════════════════════════\n');

    // Return exit code based on coverage
    const coveragePct = usedSupported.length / supportedKeys.length;
    if (coveragePct < 0.8) {
        console.log(`⚠️  Coverage is below 80% (${Math.round(coveragePct * 100)}%)`);
        process.exit(1);
    } else {
        console.log(`✅ Coverage is ${Math.round(coveragePct * 100)}% - PASS`);
    }
}

analyzeCoverage().catch(console.error);
