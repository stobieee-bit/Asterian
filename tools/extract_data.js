#!/usr/bin/env node
/**
 * extract_data.js — Extracts all game data from RunEscape's game.js into JSON files
 * for the Godot migration project.
 *
 * Usage: node tools/extract_data.js
 *
 * This script reads game.js, evaluates the data-defining portions in a
 * sandboxed context, then writes clean JSON to RunEscape-Godot/data/
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');

// Paths
const GAME_JS = path.join(__dirname, '..', '..', 'RunEscape', 'js', 'game.js');
const DATA_DIR = path.join(__dirname, '..', 'data');

// Ensure output dir exists
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

console.log('Reading game.js...');
const src = fs.readFileSync(GAME_JS, 'utf8');

// ─────────────────────────────────────────────────────
// Helper: extract a code block by variable name
// ─────────────────────────────────────────────────────
function extractBlock(varName, src) {
    // Find "var NAME =" or "const NAME ="
    const re = new RegExp('(?:var|const|let)\\s+' + varName + '\\s*=');
    const match = re.exec(src);
    if (!match) return null;
    let start = match.index;
    // Find the FIRST opening bracket (either { or [), whichever comes first
    let braceIdx = src.indexOf('{', start);
    let bracketIdx = src.indexOf('[', start);
    if (braceIdx === -1 && bracketIdx === -1) return null;
    let i;
    if (braceIdx === -1) i = bracketIdx;
    else if (bracketIdx === -1) i = braceIdx;
    else i = Math.min(braceIdx, bracketIdx);

    // Track ALL bracket types with a stack for proper nesting
    const stack = [];
    const openers = { '{': '}', '[': ']' };
    const closers = new Set(['}', ']']);
    stack.push(src[i]);
    let j = i + 1;
    while (j < src.length && stack.length > 0) {
        const ch = src[j];
        // Skip string literals (single-quoted, double-quoted, and template)
        if (ch === "'" || ch === '"' || ch === '`') {
            j++;
            while (j < src.length && src[j] !== ch) {
                if (src[j] === '\\') j++; // skip escaped chars
                j++;
            }
            j++; // skip closing quote
            continue;
        }
        // Skip single-line comments
        if (ch === '/' && src[j + 1] === '/') {
            while (j < src.length && src[j] !== '\n') j++;
            j++;
            continue;
        }
        // Skip multi-line comments
        if (ch === '/' && src[j + 1] === '*') {
            j += 2;
            while (j < src.length && !(src[j] === '*' && src[j + 1] === '/')) j++;
            j += 2;
            continue;
        }
        if (openers[ch]) {
            stack.push(ch);
        } else if (closers.has(ch)) {
            const expected = openers[stack[stack.length - 1]];
            if (ch === expected) {
                stack.pop();
            }
        }
        j++;
    }
    // Include the semicolon if present
    if (j < src.length && src[j] === ';') j++;
    return src.substring(start, j);
}

// ─────────────────────────────────────────────────────
// Build a sandbox context with minimal stubs
// ─────────────────────────────────────────────────────
const sandbox = {
    Math: Math,
    Object: Object,
    Array: Array,
    String: String,
    Number: Number,
    parseInt: parseInt,
    parseFloat: parseFloat,
    JSON: JSON,
    console: { log: () => {}, warn: () => {}, error: () => {} },
    document: { createElement: () => ({ style: {}, appendChild: () => {}, addEventListener: () => {} }), getElementById: () => null, querySelectorAll: () => [] },
    window: {},
    setTimeout: () => {},
    setInterval: () => {},
    THREE: { Color: function() { return { set: () => {}, lerp: () => {} }; } },
    // Stubs for game references
    player: {
        skills: { nano: { level: 1 }, tesla: { level: 1 }, void: { level: 1 }, astromining: { level: 1 }, bioforge: { level: 1 }, circuitry: { level: 1 }, xenocook: { level: 1 } },
        equipment: { head: null, body: null, legs: null, boots: null, gloves: null, weapon: null, offhand: null },
        prestige: { tier: 0 },
        credits: 0,
        stats: {},
        achievements: [],
        collectionLog: [],
        bossKillLog: {},
        areasVisited: [],
        unlockedSynergies: [],
        combatStyle: 'nano',
        slayerPoints: 0,
        slayerUnlocks: [],
        slayerPreferred: [],
        slayerBlocked: []
    },
    DungeonState: { active: false, maxFloorReached: 0 },
    HousingState: { active: false },
    GameState: { deltaTime: 0.016, ambientLight: null, dirLight: null, scene: null, skyDome: null },
    EventBus: { emit: () => {}, on: () => {} },
    playSound: () => {},
    addItem: () => true,
    countItem: () => 0,
    removeItem: () => {},
    addCredits: () => {},
    gainXp: () => {},
    renderItemIcon: () => '',
    getItem: (id) => sandbox.ITEMS ? sandbox.ITEMS[id] : null,
    // These will be populated by evaluation
    ITEMS: {},
    RECIPES: {},
    ENEMY_TYPES: {},
    QUESTS: {},
    BOARD_QUESTS: {},
    QUEST_CHAINS: [],
    ACHIEVEMENTS: [],
};

vm.createContext(sandbox);

// ─────────────────────────────────────────────────────
// Step 1: Extract simple data constants directly
// ─────────────────────────────────────────────────────
console.log('Extracting data constants...');

// Build evaluation script from game.js snippets
let evalScript = '';

// Enums & constants
const simpleVars = [
    'ItemType', 'EquipSlot', 'CombatStyle', 'Tiers',
    'PRESTIGE_CONFIG', 'PRESTIGE_PASSIVES', 'PRESTIGE_SHOP_ITEMS',
    'PET_DEFS', 'DURABILITY_BY_TIER',
    'AREAS', 'CORRUPTED_AREAS', 'AREA_ATMOSPHERE', 'CORRIDORS',
    'AREA_LEVEL_RANGES', 'ENEMY_SUB_ZONES', 'PROCESSING_STATIONS',
    'DUNGEON_THEMES', 'AREA_DUNGEON_THEME', 'DUNGEON_MODIFIERS',
    'DUNGEON_CONFIG', 'DUNGEON_TRAP_TYPES', 'DUNGEON_LOOT_TIERS',
    'SKILL_DEFS', 'SYNERGY_DEFS', 'SKILL_UNLOCKS',
    'WEAPON_STATS', 'ARMOR_STATS', 'OFFHAND_STATS',
    'TIER_DEFS', 'SLOT_DEFS', 'STYLE_NAMES',
    'WEAPON_DEFS_GEN', 'OFFHAND_DEFS_GEN',
    'ENEMY_BIO_MAT', 'ENEMY_ORE', 'ENEMY_FOOD',
    'SLAYER_SHOP', 'RELIC_RECIPES',
];

for (const v of simpleVars) {
    const block = extractBlock(v, src);
    if (block) {
        evalScript += block + '\n';
    } else {
        console.warn(`  WARNING: Could not find ${v}`);
    }
}

// ITEMS need defineItem + all the item definitions + procedural generation
evalScript += `
var ITEMS = {};
function defineItem(id, props) { ITEMS[id] = Object.assign({ id: id }, props); }
`;

// Extract defineItem calls — everything from first defineItem to the line before RECIPES
const firstDefine = src.indexOf("defineItem('stellarite_ore'");
const recipesStart = src.indexOf('var RECIPES = {};');
if (firstDefine !== -1 && recipesStart !== -1) {
    evalScript += src.substring(firstDefine, recipesStart) + '\n';
}

// RECIPES
evalScript += 'var RECIPES = {};\n';
const recipesBlock = src.substring(recipesStart + 'var RECIPES = {};'.length);
// Get all RECIPES.xxx = {...} lines and the forEach loops
const recipesEnd = src.indexOf("var ORE_TO_BAR=");
if (recipesEnd !== -1) {
    evalScript += recipesBlock.substring(0, recipesEnd - recipesStart - 'var RECIPES = {};'.length) + '\n';
}

// XP_TABLE (generated via loop — grab declaration + for loop)
const xpTableStart = src.indexOf("const XP_TABLE = [0];");
if (xpTableStart !== -1) {
    // Grab from "const XP_TABLE = [0];" through the end of the for loop "}"
    const forStart = src.indexOf('for (', xpTableStart);
    if (forStart !== -1) {
        // Find the closing brace of the for loop body
        const forBodyOpen = src.indexOf('{', forStart);
        let depth = 1, k = forBodyOpen + 1;
        while (k < src.length && depth > 0) {
            if (src[k] === '{') depth++;
            else if (src[k] === '}') depth--;
            k++;
        }
        evalScript += src.substring(xpTableStart, k) + '\n';
    }
}
// Also grab xpForLevel helper
const xpForLevelStart = src.indexOf('function xpForLevel(');
if (xpForLevelStart !== -1) {
    const xpForLevelEnd = src.indexOf('}', xpForLevelStart) + 1;
    evalScript += src.substring(xpForLevelStart, xpForLevelEnd) + '\n';
}

// NPC_DEFS
const npcBlock = extractBlock('NPC_DEFS', src);
if (npcBlock) evalScript += npcBlock + '\n';

// QUESTS + QUEST_CHAINS + BOARD_QUESTS
const questsBlock = extractBlock('QUESTS', src);
if (questsBlock) evalScript += questsBlock + '\n';
const chainsBlock = extractBlock('QUEST_CHAINS', src);
if (chainsBlock) evalScript += chainsBlock + '\n';
const boardBlock = extractBlock('BOARD_QUESTS', src);
if (boardBlock) evalScript += boardBlock + '\n';

// ACHIEVEMENTS (has function references, need special handling)
const achieveBlock = extractBlock('ACHIEVEMENTS', src);
if (achieveBlock) evalScript += achieveBlock + '\n';

// Helper: extract a function by name (finds balanced braces)
function extractFunction(funcName, src) {
    const idx = src.indexOf('function ' + funcName + '(');
    if (idx === -1) return null;
    const braceStart = src.indexOf('{', idx);
    if (braceStart === -1) return null;
    let depth = 1, j = braceStart + 1;
    while (j < src.length && depth > 0) {
        const ch = src[j];
        if (ch === "'" || ch === '"' || ch === '`') {
            j++;
            while (j < src.length && src[j] !== ch) { if (src[j] === '\\') j++; j++; }
            j++; continue;
        }
        if (ch === '/' && src[j+1] === '/') { while (j < src.length && src[j] !== '\n') j++; j++; continue; }
        if (ch === '/' && src[j+1] === '*') { j += 2; while (j < src.length && !(src[j] === '*' && src[j+1] === '/')) j++; j += 2; continue; }
        if (ch === '{') depth++;
        else if (ch === '}') depth--;
        j++;
    }
    return src.substring(idx, j);
}

// Enemy system: computeEnemyStats, generateLootTable, lookupByLevel, getEquipTierForLevel, ENEMY_DEFS, ENEMY_TYPES builder
for (const fn of ['computeEnemyStats', 'lookupByLevel', 'getEquipTierForLevel', 'generateLootTable']) {
    const block = extractFunction(fn, src);
    if (block) {
        evalScript += block + '\n';
    } else {
        console.warn(`  WARNING: Could not find function ${fn}`);
    }
}

const enemyDefsBlock = extractBlock('ENEMY_DEFS', src);
if (enemyDefsBlock) evalScript += enemyDefsBlock + '\n';

// ENEMY_TYPES builder IIFE
const etBuildStart = src.indexOf('var ENEMY_TYPES = {};');
const etBuildEnd = src.indexOf('})();', etBuildStart) + 5;
evalScript += src.substring(etBuildStart, etBuildEnd) + '\n';

// ─────────────────────────────────────────────────────
// Step 2: Evaluate in sandbox
// ─────────────────────────────────────────────────────
console.log('Evaluating game data in sandbox...');

// Convert const/let to var to avoid block-scoping issues in VM context
evalScript = evalScript.replace(/\b(const|let)\s+/g, 'var ');

// Write debug script before eval (for troubleshooting)
fs.writeFileSync(path.join(DATA_DIR, '_debug_eval.js'), evalScript);

try {
    vm.runInContext(evalScript, sandbox, { timeout: 15000 });
} catch (e) {
    console.error('Sandbox eval error:', e.message);
    // Find the approximate line number of the error
    if (e.stack) {
        const match = e.stack.match(/:(\d+)/);
        if (match) {
            const lineNum = parseInt(match[1]);
            const lines = evalScript.split('\n');
            console.error('Near line', lineNum, ':', lines[lineNum - 1]);
            console.error('Context:', lines.slice(Math.max(0, lineNum - 3), lineNum + 2).join('\n'));
        }
    }
    console.log('Debug script written to data/_debug_eval.js');
    process.exit(1);
}

// ─────────────────────────────────────────────────────
// Step 3: Clean and write JSON files
// ─────────────────────────────────────────────────────

function cleanFunctions(obj) {
    // Recursively remove function values, replace with string description
    if (obj === null || obj === undefined) return obj;
    if (typeof obj === 'function') return '[function]';
    if (Array.isArray(obj)) return obj.map(cleanFunctions);
    if (typeof obj === 'object') {
        const clean = {};
        for (const key of Object.keys(obj)) {
            const val = obj[key];
            if (typeof val === 'function') {
                // For check functions in achievements, try to extract desc instead
                clean[key] = '[function]';
            } else {
                clean[key] = cleanFunctions(val);
            }
        }
        return clean;
    }
    return obj;
}

function writeJSON(filename, data) {
    const cleaned = cleanFunctions(data);
    const filepath = path.join(DATA_DIR, filename);
    fs.writeFileSync(filepath, JSON.stringify(cleaned, null, 2));
    const size = fs.statSync(filepath).size;
    console.log(`  ${filename} (${(size / 1024).toFixed(1)} KB)`);
}

console.log('\nWriting JSON files:');

// Items
writeJSON('items.json', sandbox.ITEMS);

// Recipes
writeJSON('recipes.json', sandbox.RECIPES);

// Enemies
writeJSON('enemies.json', sandbox.ENEMY_TYPES);

// Enemy definitions (raw, for reference)
writeJSON('enemy_defs.json', sandbox.ENEMY_DEFS);

// Areas
writeJSON('areas.json', {
    areas: sandbox.AREAS,
    corrupted_areas: sandbox.CORRUPTED_AREAS,
    atmosphere: sandbox.AREA_ATMOSPHERE,
    corridors: sandbox.CORRIDORS,
    level_ranges: sandbox.AREA_LEVEL_RANGES,
    sub_zones: sandbox.ENEMY_SUB_ZONES,
    processing_stations: sandbox.PROCESSING_STATIONS
});

// Skills
writeJSON('skills.json', {
    skill_defs: sandbox.SKILL_DEFS,
    synergies: sandbox.SYNERGY_DEFS,
    unlocks: sandbox.SKILL_UNLOCKS,
    xp_table: sandbox.XP_TABLE
});

// Quests
writeJSON('quests.json', {
    quests: sandbox.QUESTS,
    quest_chains: sandbox.QUEST_CHAINS,
    board_quests: sandbox.BOARD_QUESTS,
    slayer_shop: sandbox.SLAYER_SHOP,
    relic_recipes: sandbox.RELIC_RECIPES
});

// NPCs
writeJSON('npcs.json', sandbox.NPC_DEFS);

// Achievements
writeJSON('achievements.json', sandbox.ACHIEVEMENTS);

// Prestige
writeJSON('prestige.json', {
    config: sandbox.PRESTIGE_CONFIG,
    passives: sandbox.PRESTIGE_PASSIVES,
    shop_items: sandbox.PRESTIGE_SHOP_ITEMS
});

// Dungeons
writeJSON('dungeons.json', {
    themes: sandbox.DUNGEON_THEMES,
    area_theme_map: sandbox.AREA_DUNGEON_THEME,
    modifiers: sandbox.DUNGEON_MODIFIERS,
    config: {
        roomSize: sandbox.DUNGEON_CONFIG ? sandbox.DUNGEON_CONFIG.roomSize : 15,
        corridorWidth: sandbox.DUNGEON_CONFIG ? sandbox.DUNGEON_CONFIG.corridorWidth : 4,
        roomSpacing: sandbox.DUNGEON_CONFIG ? sandbox.DUNGEON_CONFIG.roomSpacing : 22
    },
    trap_types: sandbox.DUNGEON_TRAP_TYPES,
    loot_tiers: sandbox.DUNGEON_LOOT_TIERS
});

// Pets
writeJSON('pets.json', sandbox.PET_DEFS);

// Equipment data (for Godot equipment generation)
writeJSON('equipment.json', {
    weapon_stats: sandbox.WEAPON_STATS,
    armor_stats: sandbox.ARMOR_STATS,
    offhand_stats: sandbox.OFFHAND_STATS,
    tier_defs: sandbox.TIER_DEFS,
    slot_defs: sandbox.SLOT_DEFS,
    style_names: sandbox.STYLE_NAMES,
    weapon_defs_gen: sandbox.WEAPON_DEFS_GEN,
    offhand_defs_gen: sandbox.OFFHAND_DEFS_GEN,
    tiers: sandbox.Tiers,
    durability_by_tier: sandbox.DURABILITY_BY_TIER,
    enums: {
        item_type: sandbox.ItemType,
        equip_slot: sandbox.EquipSlot,
        combat_style: sandbox.CombatStyle
    }
});

// Enemy loot lookup tables
writeJSON('enemy_loot_tables.json', {
    bio_mat: sandbox.ENEMY_BIO_MAT,
    ore: sandbox.ENEMY_ORE,
    food: sandbox.ENEMY_FOOD
});

// Summary
const itemCount = Object.keys(sandbox.ITEMS || {}).length;
const recipeCount = Object.keys(sandbox.RECIPES || {}).length;
const enemyCount = Object.keys(sandbox.ENEMY_TYPES || {}).length;
const questCount = Object.keys(sandbox.QUESTS || {}).length;
const npcCount = Object.keys(sandbox.NPC_DEFS || {}).length;
const achieveCount = (sandbox.ACHIEVEMENTS || []).length;
const petCount = (sandbox.PET_DEFS || []).length;

console.log('\n=== Extraction Summary ===');
console.log(`Items:        ${itemCount}`);
console.log(`Recipes:      ${recipeCount}`);
console.log(`Enemies:      ${enemyCount}`);
console.log(`Quests:       ${questCount} main + ${Object.keys(sandbox.BOARD_QUESTS || {}).length} board`);
console.log(`NPCs:         ${npcCount}`);
console.log(`Achievements: ${achieveCount}`);
console.log(`Pets:         ${petCount}`);
console.log(`Skills:       ${Object.keys(sandbox.SKILL_DEFS || {}).length}`);
console.log('\nDone! JSON files written to: ' + DATA_DIR);
