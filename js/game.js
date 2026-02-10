(function() {
'use strict';

// ========================================
// Asterian - Consolidated Game File
// ========================================

// ----------------------------------------
// Event Bus
// ----------------------------------------
const EventBus = {
    _listeners: {},
    on(event, fn) { (this._listeners[event] ||= []).push(fn); },
    off(event, fn) {
        if (!this._listeners[event]) return;
        this._listeners[event] = this._listeners[event].filter(f => f !== fn);
    },
    emit(event, data) { (this._listeners[event] || []).forEach(fn => fn(data)); }
};

// ----------------------------------------
// Game State
// ----------------------------------------
const GameState = {
    scene: null, camera: null, renderer: null, clock: null,
    player: null, world: null,
    enemies: [], npcs: [], groundItems: [], resourceNodes: [],
    currentArea: 'station-hub', paused: false,
    deltaTime: 0, elapsedTime: 0,
    mouse: new THREE.Vector2(),
    raycaster: new THREE.Raycaster(),
};

// ----------------------------------------
// Dungeon State & Constants
// ----------------------------------------
const DungeonState = {
    active: false, floor: 0, maxFloorReached: 0,
    grid: [], gridSize: 0, rooms: [], corridors: [],
    entranceRoom: null, bossRoom: null,
    meshes: [],        // all Three.js objects for cleanup
    enemies: [],       // refs to dungeon enemies (also in GameState.enemies)
    traps: [],         // trap objects with position/damage/timer
    bossGate: null,    // {mesh, position, lockLight}
    enemiesAlive: 0, bossGateOpen: false,
    savedPlayerPos: null, savedArea: '',
    dungeonLight: null,
};

var killStreak = { count: 0, timer: 0 };

const DUNGEON_CONFIG = {
    roomSize: 15, corridorWidth: 4, roomSpacing: 22,
    getGridSize: function(f) { return Math.min(3 + Math.floor(f / 3), 5); },
    getMinRooms: function(f) { return Math.min(4 + Math.floor(f / 2), 12); },
    getEnemiesPerRoom: function(f) { return Math.min(2 + Math.floor(f / 2), 6); },
    getTrapChance: function(f) { return Math.min(0.15 + f * 0.05, 0.5); },
    getTrapsPerRoom: function(f) { return Math.min(1 + Math.floor(f / 3), 4); },
};

const DUNGEON_TRAP_TYPES = {
    fire:   { name:'Fire Vent',    color:0xff4400, emissive:0x881100, dmg:8,  tick:0.5, radius:1.5, effect:'damage',  scale:1.15 },
    slow:   { name:'Stasis Field', color:0x4488ff, emissive:0x112288, dmg:3,  tick:0.8, radius:2.0, effect:'slow',    scale:1.10 },
    poison: { name:'Toxic Puddle', color:0x44ff44, emissive:0x116611, dmg:5,  tick:1.0, radius:1.8, effect:'poison',  scale:1.12 },
};

const DUNGEON_LOOT_TIERS = [
    { minFloor:1, maxFloor:3, enemyLoot:[
        {itemId:'chitin_shard',chance:0.6,min:1,max:3},{itemId:'stellarite_ore',chance:0.3,min:1,max:2},{itemId:'space_lichen',chance:0.25,min:1,max:2}
    ], bossLoot:[
        {itemId:'chitin_shard',chance:1.0,min:3,max:6},{itemId:'ferrite_ore',chance:0.5,min:2,max:4},{itemId:'ferrite_nanoblade',chance:0.05,min:1,max:1},{itemId:'ferrite_coilgun',chance:0.05,min:1,max:1},{itemId:'ferrite_voidstaff',chance:0.05,min:1,max:1},{itemId:'ferrite_energy_shield',chance:0.04,min:1,max:1}
    ]},
    { minFloor:4, maxFloor:6, enemyLoot:[
        {itemId:'cobaltium_ore',chance:0.5,min:1,max:3},{itemId:'jelly_membrane',chance:0.4,min:1,max:2},{itemId:'duranite_ore',chance:0.2,min:1,max:2}
    ], bossLoot:[
        {itemId:'duranite_ore',chance:1.0,min:3,max:6},{itemId:'jelly_membrane',chance:0.6,min:2,max:4},{itemId:'duranium_nanoblade',chance:0.04,min:1,max:1},{itemId:'duranium_coilgun',chance:0.04,min:1,max:1},{itemId:'duranium_voidstaff',chance:0.04,min:1,max:1},{itemId:'cobalt_helmet',chance:0.03,min:1,max:1},{itemId:'cobalt_vest',chance:0.03,min:1,max:1},{itemId:'duranium_capacitor',chance:0.03,min:1,max:1},{itemId:'duranium_dark_orb',chance:0.03,min:1,max:1}
    ]},
    { minFloor:7, maxFloor:9, enemyLoot:[
        {itemId:'titanex_ore',chance:0.5,min:1,max:3},{itemId:'spore_gland',chance:0.4,min:1,max:2},{itemId:'plasmite_ore',chance:0.2,min:1,max:2}
    ], bossLoot:[
        {itemId:'plasmite_ore',chance:1.0,min:3,max:5},{itemId:'spore_gland',chance:0.6,min:2,max:4},{itemId:'titanex_nanoblade',chance:0.04,min:1,max:1},{itemId:'titanex_coilgun',chance:0.04,min:1,max:1},{itemId:'titanex_voidstaff',chance:0.04,min:1,max:1},{itemId:'plasmite_helmet',chance:0.03,min:1,max:1},{itemId:'plasmite_vest',chance:0.03,min:1,max:1},{itemId:'titanex_energy_shield',chance:0.03,min:1,max:1},{itemId:'plasmite_capacitor',chance:0.03,min:1,max:1}
    ]},
    { minFloor:10, maxFloor:999, enemyLoot:[
        {itemId:'quantite_ore',chance:0.5,min:1,max:3},{itemId:'neutronium_ore',chance:0.3,min:1,max:2},{itemId:'gravity_residue',chance:0.3,min:1,max:2},{itemId:'neural_tissue',chance:0.2,min:1,max:1}
    ], bossLoot:[
        {itemId:'neutronium_ore',chance:1.0,min:3,max:6},{itemId:'neural_tissue',chance:0.6,min:2,max:4},{itemId:'neutronium_nanoblade',chance:0.03,min:1,max:1},{itemId:'neutronium_coilgun',chance:0.03,min:1,max:1},{itemId:'neutronium_voidstaff',chance:0.03,min:1,max:1},{itemId:'quantum_helmet',chance:0.02,min:1,max:1},{itemId:'quantum_vest',chance:0.02,min:1,max:1},{itemId:'neutronium_boots',chance:0.02,min:1,max:1},{itemId:'neutronium_gloves',chance:0.02,min:1,max:1},{itemId:'neutronium_dark_orb',chance:0.02,min:1,max:1},{itemId:'quantum_energy_shield',chance:0.02,min:1,max:1}
    ]},
];

function getDungeonLootTier(floor) {
    for (var i = 0; i < DUNGEON_LOOT_TIERS.length; i++) {
        var t = DUNGEON_LOOT_TIERS[i];
        if (floor >= t.minFloor && floor <= t.maxFloor) return t;
    }
    return DUNGEON_LOOT_TIERS[DUNGEON_LOOT_TIERS.length - 1];
}

function scaleDungeonEnemy(baseType, floor) {
    var base = ENEMY_TYPES[baseType];
    if (!base) return null;
    var scale = 1 + (floor - 1) * 0.2;
    var tier = getDungeonLootTier(floor);
    return {
        name: base.name, type: baseType, level: Math.round(base.level * scale),
        hp: Math.round(base.hp * scale), maxHp: Math.round(base.hp * scale),
        damage: Math.round(base.damage * scale), defense: Math.round(base.defense * scale),
        attackSpeed: base.attackSpeed, aggroRange: base.aggroRange, leashRange: 25,
        combatStyle: base.combatStyle, respawnTime: 9999, isBoss: false,
        isDungeonEnemy: true, isDungeonBoss: false,
        area: 'dungeon', desc: base.desc,
        lootTable: tier.enemyLoot,
    };
}

function scaleDungeonBoss(baseType, floor) {
    var base = ENEMY_TYPES[baseType];
    if (!base) return null;
    var scale = 1 + (floor - 1) * 0.2;
    var tier = getDungeonLootTier(floor);
    return {
        name: base.name + ' (Boss)', type: baseType, level: Math.round(base.level * scale),
        hp: Math.round(base.hp * scale * 2), maxHp: Math.round(base.hp * scale * 2),
        damage: Math.round(base.damage * scale * 1.5), defense: Math.round(base.defense * scale),
        attackSpeed: base.attackSpeed * 0.9, aggroRange: 15, leashRange: 30,
        combatStyle: base.combatStyle, respawnTime: 9999, isBoss: true,
        isDungeonEnemy: true, isDungeonBoss: true,
        area: 'dungeon', desc: base.desc,
        lootTable: tier.bossLoot,
    };
}

function getDungeonEnemyTypes(floor) {
    var targetLevel=3+floor*6;
    var candidates=[];
    for(var id in ENEMY_TYPES){
        var et=ENEMY_TYPES[id];
        if(et.isCorrupted||et.isBoss)continue;
        if(et.area==='the-abyss')continue; // no abyss enemies in dungeons
        if(Math.abs(et.level-targetLevel)<=10){candidates.push(id);}
    }
    if(candidates.length===0) return ['chithari','chithari_warrior'];
    // Pick 2-3 random from candidates
    var shuffled=candidates.sort(function(){return Math.random()-0.5;});
    return shuffled.slice(0,Math.min(3,shuffled.length));
}

function getDungeonBossType(floor) {
    var targetLevel=3+floor*6+5;
    var bestId='neuroworm',bestDiff=999;
    for(var id in ENEMY_TYPES){
        var et=ENEMY_TYPES[id];
        if(et.isCorrupted)continue;
        if(et.area==='the-abyss')continue;
        if(et.isBoss){
            var diff=Math.abs(et.level-targetLevel);
            if(diff<bestDiff){bestDiff=diff;bestId=id;}
        }
    }
    return bestId;
}

// ----------------------------------------
// Item Types & Constants
// ----------------------------------------
const ItemType = { WEAPON:'weapon', ARMOR:'armor', OFFHAND:'offhand', FOOD:'food', RESOURCE:'resource', MATERIAL:'material', TOOL:'tool' };
const EquipSlot = { HEAD:'head', BODY:'body', LEGS:'legs', BOOTS:'boots', GLOVES:'gloves', WEAPON:'weapon', OFFHAND:'offhand' };
const CombatStyle = { NANO:'nano', TESLA:'tesla', VOID:'void' };
const Tiers = {
    1:{name:'Scrap',color:'#888888',levelReq:1},
    2:{name:'Ferrite',color:'#44cc66',levelReq:10},
    3:{name:'Cobalt',color:'#4488ff',levelReq:20},
    4:{name:'Duranium',color:'#66aacc',levelReq:30},
    5:{name:'Titanex',color:'#88cc44',levelReq:40},
    6:{name:'Plasmite',color:'#aa44ff',levelReq:50},
    7:{name:'Quantum',color:'#ff8844',levelReq:60},
    8:{name:'Neutronium',color:'#ff4488',levelReq:70},
    9:{name:'Darkmatter',color:'#cc44ff',levelReq:80},
    10:{name:'Voidsteel',color:'#ff8800',levelReq:90},
    11:{name:'Ascendant',color:'#44ffdd',levelReq:91},
    12:{name:'Corrupted',color:'#ff2266',levelReq:93},
};

// ========================================
// Prestige / New Game+ System
// ========================================
const PRESTIGE_CONFIG = {
    maxTier: 10,
    xpRatePerTier: 0.05,
    damagePerTier: 0.02,
    reductionPerTier: 0.01,
    pointsPerTotalLevel: 10,
    startingCredits: 500,
    minTotalLevel: 500,
};

const PRESTIGE_PASSIVES = {
    1:{id:'echo_of_knowledge',name:'Echo of Knowledge',desc:'5% chance to gain double XP from any action',color:'#88ccff'},
    2:{id:'hardened',name:'Hardened',desc:'Start with 120 max HP instead of 100',color:'#44ff88'},
    3:{id:'efficient',name:'Efficient',desc:'10% faster gathering speed',color:'#ff8844'},
    4:{id:'wealthy',name:'Wealthy',desc:'Enemies drop 15% more credits',color:'#ffcc44'},
    5:{id:'corrupted_vision',name:'Corrupted Vision',desc:'Access to Corrupted Areas',color:'#ff4444'},
    6:{id:'adrenaline_rush',name:'Adrenaline Rush',desc:'10% faster attack speed',color:'#ff44aa'},
    7:{id:'fortunes_favor',name:"Fortune's Favor",desc:'10% better drop rates',color:'#44ffaa'},
    8:{id:'undying',name:'Undying',desc:'Survive lethal hit once per 5 minutes (1 HP)',color:'#ffaaaa'},
    9:{id:'transcendent',name:'Transcendent',desc:'All skill bonuses are 20% more effective',color:'#aa88ff'},
    10:{id:'ascended',name:'Ascended',desc:'Golden aura, +50% XP, all prestige bonuses doubled',color:'#ffd700'},
};

const PRESTIGE_SHOP_ITEMS = [
    {id:'particle_red',name:'Red Aura Particles',cost:50,type:'cosmetic',color:0xff4444},
    {id:'particle_blue',name:'Blue Aura Particles',cost:50,type:'cosmetic',color:0x4444ff},
    {id:'particle_green',name:'Green Aura Particles',cost:50,type:'cosmetic',color:0x44ff44},
    {id:'particle_purple',name:'Purple Aura Particles',cost:50,type:'cosmetic',color:0xaa44ff},
    {id:'particle_white',name:'White Aura Particles',cost:50,type:'cosmetic',color:0xffffff},
    {id:'bank_slots',name:'Extra Bank Slots (+10)',cost:100,type:'bank',value:10,repeatable:true},
    {id:'credit_bonus',name:'Starting Credit Bonus (+100)',cost:75,type:'credits',value:100,repeatable:true},
    {id:'title_pioneer',name:'Title: Pioneer',cost:30,type:'title',value:'Pioneer'},
    {id:'title_ascendant',name:'Title: Ascendant',cost:150,type:'title',value:'Ascendant'},
    {id:'title_eternal',name:'Title: Eternal',cost:300,type:'title',value:'Eternal'},
    {id:'xp_token',name:'XP Boost Token (2x, 10 min)',cost:25,type:'xp_token',repeatable:true},
];

// ----------------------------------------
// Gear Decay Constants
// ----------------------------------------
const DURABILITY_BY_TIER = { 1:100, 2:150, 3:200, 4:300, 5:400, 6:500, 7:650, 8:800, 9:1000, 10:1200, 11:1500, 12:2000 };
const BROKEN_STAT_PENALTY = 0.5;
const DURABILITY_WARN_THRESHOLD = 0.25;

function initDurability(itemDef) {
    if (!itemDef) return {};
    var maxDur = DURABILITY_BY_TIER[itemDef.tier] || 100;
    return { durability: maxDur, maxDurability: maxDur };
}

// ----------------------------------------
// Shop Economy Config
// ----------------------------------------
const SHOP_ECONOMY_CONFIG = {
    priceFloor: 0.5,
    priceCeiling: 2.0,
    restockInterval: 60,
    buyPriceIncrease: 0.05,
    sellPriceDecrease: 0.03,
    meanReversionRate: 0.002,
};
var shopEconomy = {};

// ----------------------------------------
// Item Definitions
// ----------------------------------------
const ITEMS = {};
function defineItem(id, props) { ITEMS[id] = { id, ...props }; }

// Resources (Astromining)
defineItem('stellarite_ore',{name:'Stellarite Ore',type:ItemType.RESOURCE,icon:'\u26AA',stackable:true,value:15,tier:1,skillReq:{astromining:1},desc:'Common space ore with a dull metallic sheen.'});
defineItem('ferrite_ore',{name:'Ferrite Ore',type:ItemType.RESOURCE,icon:'\uD83D\uDFE2',stackable:true,value:35,tier:2,skillReq:{astromining:10},desc:'Green-tinged ferrous ore from iron-rich asteroids.'});
defineItem('cobaltium_ore',{name:'Cobaltium Ore',type:ItemType.RESOURCE,icon:'\uD83D\uDD37',stackable:true,value:65,tier:3,skillReq:{astromining:20},desc:'Blue-tinged ore found in deep asteroid pockets.'});
defineItem('duranite_ore',{name:'Duranite Ore',type:ItemType.RESOURCE,icon:'\uD83D\uDD35',stackable:true,value:110,tier:4,skillReq:{astromining:30},desc:'Teal crystalline ore of extreme hardness.'});
defineItem('titanex_ore',{name:'Titanex Ore',type:ItemType.RESOURCE,icon:'\uD83D\uDFE1',stackable:true,value:180,tier:5,skillReq:{astromining:40},desc:'Yellow-green ore with reactive titanium compounds.'});
defineItem('plasmite_ore',{name:'Plasmite Ore',type:ItemType.RESOURCE,icon:'\uD83D\uDFE3',stackable:true,value:280,tier:6,skillReq:{astromining:50},desc:'Superheated ore glowing with inner plasma.'});
defineItem('quantite_ore',{name:'Quantite Ore',type:ItemType.RESOURCE,icon:'\uD83D\uDFE0',stackable:true,value:420,tier:7,skillReq:{astromining:60},desc:'Quantum-entangled ore that flickers between states.'});
defineItem('neutronium_ore',{name:'Neutronium Ore',type:ItemType.RESOURCE,icon:'\u26AB',stackable:true,value:600,tier:8,skillReq:{astromining:70},desc:'Ultra-dense ore from collapsed star fragments.'});
defineItem('darkmatter_shard',{name:'Darkmatter Shard',type:ItemType.RESOURCE,icon:'\uD83D\uDC8E',stackable:true,value:850,tier:9,skillReq:{astromining:80},desc:'Exotic shard of condensed dark matter.'});
defineItem('voidsteel_ore',{name:'Voidsteel Ore',type:ItemType.RESOURCE,icon:'\u2B50',stackable:true,value:1200,tier:10,skillReq:{astromining:90},desc:'Void-touched ore radiating dimensional energy.'});

// Materials (bars)
defineItem('stellarite_bar',{name:'Stellarite Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:30,tier:1,desc:'Smelted stellarite ingot.'});
defineItem('ferrite_bar',{name:'Ferrite Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:70,tier:2,desc:'Refined ferrite alloy.'});
defineItem('cobaltium_bar',{name:'Cobaltium Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:130,tier:3,desc:'Polished cobaltium alloy.'});
defineItem('duranite_bar',{name:'Duranite Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:220,tier:4,desc:'Tempered duranite composite.'});
defineItem('titanex_bar',{name:'Titanex Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:360,tier:5,desc:'Pressurized titanex ingot.'});
defineItem('plasmite_bar',{name:'Plasmite Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:560,tier:6,desc:'Plasma-forged metal ingot.'});
defineItem('quantite_bar',{name:'Quantite Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:840,tier:7,desc:'Quantum-stabilized alloy.'});
defineItem('neutronium_bar',{name:'Neutronium Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:1200,tier:8,desc:'Super-dense neutronium block.'});
defineItem('darkmatter_bar',{name:'Darkmatter Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:1700,tier:9,desc:'Compressed dark matter ingot.'});
defineItem('voidsteel_bar',{name:'Voidsteel Bar',type:ItemType.MATERIAL,icon:'\u25AC',stackable:true,value:2400,tier:10,desc:'Void-infused steel of immense power.'});

// Combo alloys (crafted, not mined)
defineItem('ascendant_alloy',{name:'Ascendant Alloy',type:ItemType.MATERIAL,icon:'\u25C6',stackable:true,value:2000,tier:11,desc:'Transcendent alloy fused from the three rarest metals.'});
defineItem('corrupted_ingot',{name:'Corrupted Ingot',type:ItemType.MATERIAL,icon:'\u25C6',stackable:true,value:3500,tier:12,desc:'Reality-warped ingot pulsing with dark energy.'});
defineItem('corrupted_essence',{name:'Corrupted Essence',type:ItemType.RESOURCE,icon:'\uD83D\uDD34',stackable:true,value:500,tier:12,desc:'Raw corruption crystallized from dimensional rifts.'});

// Bio materials
defineItem('chitin_shard',{name:'Chitin Shard',type:ItemType.RESOURCE,icon:'\uD83E\uDDB4',stackable:true,value:10,tier:1,desc:'Sharp fragment from Chithari exoskeleton.'});
defineItem('jelly_membrane',{name:'Jelly Membrane',type:ItemType.RESOURCE,icon:'\uD83E\uDEE7',stackable:true,value:35,tier:2,desc:'Translucent membrane from a Voidjelly.'});
defineItem('spore_gland',{name:'Spore Gland',type:ItemType.RESOURCE,icon:'\uD83C\uDF44',stackable:true,value:80,tier:3,desc:'Toxic gland from a Sporeclaw.'});
defineItem('gravity_residue',{name:'Gravity Residue',type:ItemType.RESOURCE,icon:'\uD83C\uDF00',stackable:true,value:200,tier:4,desc:'Warped matter left by a Gravlurk.'});
defineItem('neural_tissue',{name:'Neural Tissue',type:ItemType.RESOURCE,icon:'\uD83E\uDDE0',stackable:true,value:400,tier:5,desc:'Psionic tissue from a Neuroworm.'});
defineItem('corrupted_essence',{name:'Corrupted Essence',type:ItemType.RESOURCE,icon:'\uD83D\uDD25',stackable:true,value:600,tier:6,desc:'Warped essence from reality-bent creatures.'});
defineItem('abyssal_ichor',{name:'Abyssal Ichor',type:ItemType.RESOURCE,icon:'\uD83C\uDF0C',stackable:true,value:800,tier:7,desc:'Dark fluid harvested from creatures of the abyss.'});
defineItem('primordial_shard',{name:'Primordial Shard',type:ItemType.RESOURCE,icon:'\uD83D\uDC8E',stackable:true,value:2000,tier:8,desc:'Fragment of primordial creation energy.'});
defineItem('primordial_fragment',{name:'Primordial Fragment',type:ItemType.RESOURCE,icon:'\u2728',stackable:true,value:5000,tier:9,desc:'Solidified essence of cosmic dawn.'});

// Raw food
defineItem('space_lichen',{name:'Space Lichen',type:ItemType.RESOURCE,icon:'\uD83C\uDF3F',stackable:true,value:5,tier:1,desc:'Edible lichen scraped from station walls.'});
defineItem('nebula_fruit',{name:'Nebula Fruit',type:ItemType.RESOURCE,icon:'\uD83C\uDF47',stackable:true,value:15,tier:2,desc:'Purple fruit grown in zero-g.'});
defineItem('alien_steak',{name:'Alien Steak',type:ItemType.RESOURCE,icon:'\uD83E\uDD69',stackable:true,value:40,tier:3,desc:'Thick slab of unidentified alien meat.'});
defineItem('plasma_pepper',{name:'Plasma Pepper',type:ItemType.RESOURCE,icon:'\uD83C\uDF36',stackable:true,value:80,tier:4,desc:'A pepper that generates its own heat.'});
defineItem('void_truffle',{name:'Void Truffle',type:ItemType.RESOURCE,icon:'\uD83C\uDF44',stackable:true,value:200,tier:5,desc:'Extremely rare fungus from the void.'});

// Cooked food
defineItem('lichen_wrap',{name:'Lichen Wrap',type:ItemType.FOOD,icon:'\uD83C\uDF2F',stackable:true,value:15,tier:1,heals:50,desc:'Simple lichen wrap. Heals 50 HP.'});
defineItem('nebula_smoothie',{name:'Nebula Smoothie',type:ItemType.FOOD,icon:'\uD83E\uDD64',stackable:true,value:40,tier:2,heals:150,desc:'Blended nebula fruit. Heals 150 HP.'});
defineItem('alien_burger',{name:'Alien Burger',type:ItemType.FOOD,icon:'\uD83C\uDF54',stackable:true,value:100,tier:3,heals:350,desc:'Grilled alien steak burger. Heals 350 HP.'});
defineItem('plasma_curry',{name:'Plasma Curry',type:ItemType.FOOD,icon:'\uD83C\uDF5B',stackable:true,value:200,tier:4,heals:600,desc:'Fiery plasma curry. Heals 600 HP.'});
defineItem('void_feast',{name:'Void Feast',type:ItemType.FOOD,icon:'\uD83C\uDF71',stackable:true,value:500,tier:5,heals:1000,desc:'Exquisite void truffle feast. Heals 1000 HP.'});

// ========================================
// Data-Driven Equipment Generation
// ========================================
var WEAPON_STATS = {
    1:{nanoDmg:8,nanoAcc:70,teslaDmg:7,teslaAcc:75,voidDmg:9,voidAcc:65,val:50},
    2:{nanoDmg:14,nanoAcc:74,teslaDmg:12,teslaAcc:78,voidDmg:16,voidAcc:70,val:180},
    3:{nanoDmg:22,nanoAcc:78,teslaDmg:20,teslaAcc:82,voidDmg:24,voidAcc:74,val:400},
    4:{nanoDmg:32,nanoAcc:82,teslaDmg:28,teslaAcc:86,voidDmg:35,voidAcc:78,val:750},
    5:{nanoDmg:42,nanoAcc:85,teslaDmg:38,teslaAcc:89,voidDmg:46,voidAcc:82,val:1200},
    6:{nanoDmg:54,nanoAcc:88,teslaDmg:50,teslaAcc:92,voidDmg:58,voidAcc:85,val:1800},
    7:{nanoDmg:68,nanoAcc:91,teslaDmg:62,teslaAcc:94,voidDmg:72,voidAcc:88,val:2800},
    8:{nanoDmg:82,nanoAcc:93,teslaDmg:76,teslaAcc:96,voidDmg:88,voidAcc:91,val:4000},
    9:{nanoDmg:98,nanoAcc:95,teslaDmg:90,teslaAcc:97,voidDmg:105,voidAcc:93,val:5500},
    10:{nanoDmg:115,nanoAcc:97,teslaDmg:108,teslaAcc:98,voidDmg:120,voidAcc:95,val:7500},
    11:{nanoDmg:125,nanoAcc:98,teslaDmg:118,teslaAcc:99,voidDmg:132,voidAcc:96,val:10000},
    12:{nanoDmg:140,nanoAcc:99,teslaDmg:130,teslaAcc:99,voidDmg:148,voidAcc:98,val:15000},
};
var ARMOR_STATS = {
    1:{head:3,body:5,legs:4,boots:2,gloves:2},
    2:{head:6,body:10,legs:8,boots:4,gloves:4},
    3:{head:10,body:16,legs:13,boots:7,gloves:7},
    4:{head:14,body:23,legs:18,boots:10,gloves:10},
    5:{head:19,body:31,legs:24,boots:14,gloves:14},
    6:{head:25,body:40,legs:31,boots:18,gloves:18},
    7:{head:32,body:50,legs:39,boots:23,gloves:23},
    8:{head:39,body:62,legs:48,boots:28,gloves:28},
    9:{head:48,body:75,legs:58,boots:34,gloves:34},
    10:{head:57,body:90,legs:70,boots:41,gloves:41},
    11:{head:65,body:102,legs:79,boots:46,gloves:46},
    12:{head:75,body:115,legs:90,boots:52,gloves:52},
};
var OFFHAND_STATS = {
    1: {shield:{armor:4,damage:2},capacitor:{accuracy:35,damage:2},orb:{damage:5,accuracy:30},val:40},
    2: {shield:{armor:8,damage:4},capacitor:{accuracy:38,damage:4},orb:{damage:9,accuracy:34},val:140},
    3: {shield:{armor:13,damage:7},capacitor:{accuracy:42,damage:6},orb:{damage:14,accuracy:38},val:320},
    4: {shield:{armor:18,damage:10},capacitor:{accuracy:45,damage:9},orb:{damage:20,accuracy:42},val:600},
    5: {shield:{armor:24,damage:14},capacitor:{accuracy:48,damage:12},orb:{damage:26,accuracy:45},val:960},
    6: {shield:{armor:31,damage:18},capacitor:{accuracy:50,damage:16},orb:{damage:33,accuracy:48},val:1440},
    7: {shield:{armor:39,damage:22},capacitor:{accuracy:52,damage:20},orb:{damage:41,accuracy:50},val:2240},
    8: {shield:{armor:48,damage:27},capacitor:{accuracy:54,damage:25},orb:{damage:50,accuracy:52},val:3200},
    9: {shield:{armor:58,damage:32},capacitor:{accuracy:56,damage:30},orb:{damage:60,accuracy:54},val:4400},
    10:{shield:{armor:68,damage:38},capacitor:{accuracy:58,damage:36},orb:{damage:70,accuracy:56},val:6000},
    11:{shield:{armor:76,damage:42},capacitor:{accuracy:59,damage:40},orb:{damage:78,accuracy:57},val:8000},
    12:{shield:{armor:86,damage:48},capacitor:{accuracy:60,damage:44},orb:{damage:88,accuracy:58},val:12000},
};
var TIER_DEFS = [
    {tier:1,prefix:'scrap',name:'Scrap',lvl:1},
    {tier:2,prefix:'ferrite',name:'Ferrite',lvl:10},
    {tier:3,prefix:'cobalt',name:'Cobalt',lvl:20},
    {tier:4,prefix:'duranium',name:'Duranium',lvl:30},
    {tier:5,prefix:'titanex',name:'Titanex',lvl:40},
    {tier:6,prefix:'plasmite',name:'Plasmite',lvl:50},
    {tier:7,prefix:'quantum',name:'Quantum',lvl:60},
    {tier:8,prefix:'neutronium',name:'Neutronium',lvl:70},
    {tier:9,prefix:'darkmatter',name:'Darkmatter',lvl:80},
    {tier:10,prefix:'voidsteel',name:'Voidsteel',lvl:90},
    {tier:11,prefix:'ascendant',name:'Ascendant',lvl:91},
    {tier:12,prefix:'corrupted',name:'Corrupted',lvl:93},
];
var SLOT_DEFS = [
    {slot:'head',sname:'Helmet',icon:'\u26D1\uFE0F',key:'helmet'},
    {slot:'body',sname:'Vest',icon:'\uD83E\uDDBA',key:'vest'},
    {slot:'legs',sname:'Greaves',icon:'\uD83D\uDC56',key:'legs'},
    {slot:'boots',sname:'Boots',icon:'\uD83E\uDD7E',key:'boots'},
    {slot:'gloves',sname:'Gloves',icon:'\uD83E\uDDE4',key:'gloves'},
];
var STYLE_NAMES = {nano:'Nano',tesla:'Tesla','void':'Void'};
var WEAPON_DEFS_GEN = [
    {suffix:'nanoblade',sname:'Nanoblade',icon:'\u2694\uFE0F',style:'nano',dmgKey:'nanoDmg',accKey:'nanoAcc',dsc:' blade infused with nanobot swarm.'},
    {suffix:'coilgun',sname:'Coilgun',icon:'\uD83D\uDD2B',style:'tesla',dmgKey:'teslaDmg',accKey:'teslaAcc',dsc:' coilgun with tesla capacitors.'},
    {suffix:'voidstaff',sname:'Voidstaff',icon:'\uD83E\uDE84',style:'void',dmgKey:'voidDmg',accKey:'voidAcc',dsc:' staff channeling dark energy.'},
];
var OFFHAND_DEFS_GEN = [
    {suffix:'energy_shield',sname:'Energy Shield',icon:'\uD83D\uDEE1\uFE0F',style:'nano',statKey:'shield',dsc:' energy barrier projector.'},
    {suffix:'capacitor',sname:'Capacitor',icon:'\u26A1',style:'tesla',statKey:'capacitor',dsc:' tesla capacitor bank.'},
    {suffix:'dark_orb',sname:'Dark Orb',icon:'\uD83D\uDD2E',style:'void',statKey:'orb',dsc:' channeling orb of dark energy.'},
];
TIER_DEFS.forEach(function(t){
    var ws=WEAPON_STATS[t.tier],as=ARMOR_STATS[t.tier];
    WEAPON_DEFS_GEN.forEach(function(w){
        defineItem(t.prefix+'_'+w.suffix,{name:t.name+' '+w.sname,type:ItemType.WEAPON,icon:w.icon,slot:EquipSlot.WEAPON,style:CombatStyle[w.style.toUpperCase()],tier:t.tier,damage:ws[w.dmgKey],accuracy:ws[w.accKey],levelReq:t.lvl,value:ws.val,desc:t.name+w.dsc});
    });
    // Offhand items (style-specific)
    var os=OFFHAND_STATS[t.tier];
    OFFHAND_DEFS_GEN.forEach(function(oh){
        var st=os[oh.statKey];
        defineItem(t.prefix+'_'+oh.suffix,{name:t.name+' '+oh.sname,type:ItemType.OFFHAND,icon:oh.icon,slot:EquipSlot.OFFHAND,style:CombatStyle[oh.style.toUpperCase()],tier:t.tier,armor:st.armor||0,damage:st.damage||0,accuracy:st.accuracy||0,levelReq:t.lvl,value:os.val,desc:t.name+oh.dsc});
    });
    SLOT_DEFS.forEach(function(s){
        var armorVal=as[s.key==='helmet'?'head':s.key==='vest'?'body':s.key];
        var valMult={helmet:0.6,vest:1.0,legs:0.8,boots:0.4,gloves:0.4}[s.key]||0.5;
        defineItem(t.prefix+'_'+s.key,{name:t.name+' '+s.sname,type:ItemType.ARMOR,icon:s.icon,slot:s.slot,tier:t.tier,armor:armorVal,levelReq:t.lvl,value:Math.round(ws.val*valMult),desc:t.name+' '+s.sname.toLowerCase()+'.'});
    });
    ['nano','tesla','void'].forEach(function(style){
        var sn=STYLE_NAMES[style];
        SLOT_DEFS.forEach(function(s){
            var armorVal=as[s.key==='helmet'?'head':s.key==='vest'?'body':s.key];
            var styleArmor=Math.round(armorVal*0.85);
            var valMult={helmet:0.65,vest:1.1,legs:0.85,boots:0.45,gloves:0.45}[s.key]||0.55;
            defineItem(t.prefix+'_'+style+'_'+s.key,{name:t.name+' '+sn+' '+s.sname,type:ItemType.ARMOR,icon:s.icon,slot:s.slot,tier:t.tier,armor:styleArmor,armorStyle:style,levelReq:t.lvl,value:Math.round(ws.val*valMult),desc:t.name+' '+s.sname.toLowerCase()+' with '+sn.toLowerCase()+' enhancements.'});
        });
    });
});
// Tools
// Tier 1 Tools (basic)
defineItem('mining_laser',{name:'Mining Laser',type:ItemType.TOOL,icon:'\u26CF\uFE0F',stackable:false,value:25,tier:1,toolSkill:'astromining',gatherSpeed:1.0,desc:'Basic mining laser for asteroid extraction.'});
defineItem('bio_scanner',{name:'Bio Scanner',type:ItemType.TOOL,icon:'\uD83D\uDD2C',stackable:false,value:25,tier:1,toolSkill:'bioforge',gatherSpeed:1.0,desc:'Scans and harvests biological specimens.'});
defineItem('circuit_welder',{name:'Circuit Welder',type:ItemType.TOOL,icon:'\uD83D\uDD27',stackable:false,value:25,tier:1,toolSkill:'circuitry',gatherSpeed:1.0,desc:'Precision welder for circuitry work.'});
defineItem('xeno_stove',{name:'Portable Stove',type:ItemType.TOOL,icon:'\uD83C\uDF73',stackable:false,value:25,tier:1,toolSkill:'xenocook',gatherSpeed:1.0,desc:'Compact heating unit for xenocooking.'});
// Tier 2 Tools (ferrite - 30% faster)
defineItem('ferrite_mining_laser',{name:'Ferrite Mining Laser',type:ItemType.TOOL,icon:'\u26CF\uFE0F',stackable:false,value:100,tier:2,toolSkill:'astromining',gatherSpeed:1.3,desc:'Ferrite-reinforced laser. Gathers 30% faster.'});
defineItem('ferrite_bio_scanner',{name:'Ferrite Bio Scanner',type:ItemType.TOOL,icon:'\uD83D\uDD2C',stackable:false,value:100,tier:2,toolSkill:'bioforge',gatherSpeed:1.3,desc:'Enhanced scanner with ferrite optics. Gathers 30% faster.'});
// Tier 3 Tools (cobalt - 60% faster)
defineItem('cobalt_mining_laser',{name:'Cobalt Mining Laser',type:ItemType.TOOL,icon:'\u26CF\uFE0F',stackable:false,value:280,tier:3,toolSkill:'astromining',gatherSpeed:1.6,desc:'Cobaltium-powered drill. Gathers 60% faster.'});
defineItem('cobalt_bio_scanner',{name:'Cobalt Bio Scanner',type:ItemType.TOOL,icon:'\uD83D\uDD2C',stackable:false,value:280,tier:3,toolSkill:'bioforge',gatherSpeed:1.6,desc:'Cobalt-lens scanner. Gathers 60% faster.'});
// Tier 5 Tools (boss drop - 2x speed + 1% instant gather per tick)
defineItem('voidtouched_mining_laser',{name:'Void-Touched Mining Laser',type:ItemType.TOOL,icon:'\u26CF\uFE0F',stackable:false,value:800,tier:5,toolSkill:'astromining',gatherSpeed:2.0,instantChance:0.01,desc:'Gravlurk-infused laser. 2x speed, 1% instant gather per tick.'});
defineItem('voidtouched_bio_scanner',{name:'Void-Touched Bio Scanner',type:ItemType.TOOL,icon:'\uD83D\uDD2C',stackable:false,value:800,tier:5,toolSkill:'bioforge',gatherSpeed:2.0,instantChance:0.01,desc:'Neuroworm-infused scanner. 2x speed, 1% instant gather per tick.'});

// Currency
defineItem('credits',{name:'Credits',type:ItemType.RESOURCE,icon:'\uD83D\uDCB0',stackable:true,value:1,desc:'Universal galactic currency.'});

function getItem(id) { return ITEMS[id] || null; }

// Recipes
var RECIPES = {};

// Food recipes (unchanged)
RECIPES.cook_lichen_wrap={skill:'xenocook',level:1,xp:20,input:{space_lichen:1},output:{lichen_wrap:1},name:'Cook Lichen Wrap'};
RECIPES.cook_nebula_smoothie={skill:'xenocook',level:10,xp:50,input:{nebula_fruit:1},output:{nebula_smoothie:1},name:'Blend Nebula Smoothie'};
RECIPES.cook_alien_burger={skill:'xenocook',level:25,xp:100,input:{alien_steak:1},output:{alien_burger:1},name:'Grill Alien Burger'};
RECIPES.cook_plasma_curry={skill:'xenocook',level:45,xp:180,input:{plasma_pepper:1,alien_steak:1},output:{plasma_curry:1},name:'Cook Plasma Curry'};
RECIPES.cook_void_feast={skill:'xenocook',level:65,xp:320,input:{void_truffle:1,plasma_pepper:1},output:{void_feast:1},name:'Prepare Void Feast'};
RECIPES.craft_bio_pouch={skill:'bioforge',level:1,xp:20,input:{chitin_shard:3},output:{lichen_wrap:2},name:'Bioforge Lichen Wraps'};
RECIPES.craft_jelly_salve={skill:'bioforge',level:15,xp:60,input:{jelly_membrane:2},output:{nebula_smoothie:2},name:'Bioforge Jelly Salve'};

// Tool crafting recipes
RECIPES.craft_ferrite_mining_laser={skill:'circuitry',level:10,xp:50,input:{ferrite_bar:2,stellarite_bar:1},output:{ferrite_mining_laser:1},name:'Forge Ferrite Mining Laser'};
RECIPES.craft_ferrite_bio_scanner={skill:'circuitry',level:10,xp:50,input:{ferrite_bar:2,stellarite_bar:1},output:{ferrite_bio_scanner:1},name:'Forge Ferrite Bio Scanner'};
RECIPES.craft_cobalt_mining_laser={skill:'circuitry',level:20,xp:100,input:{cobaltium_bar:3,ferrite_bar:1},output:{cobalt_mining_laser:1},name:'Forge Cobalt Mining Laser'};
RECIPES.craft_cobalt_bio_scanner={skill:'circuitry',level:20,xp:100,input:{cobaltium_bar:3,ferrite_bar:1},output:{cobalt_bio_scanner:1},name:'Forge Cobalt Bio Scanner'};

// Data-driven smelting, weapon, armor, and style armor recipes
var ORE_IDS={1:'stellarite_ore',2:'ferrite_ore',3:'cobaltium_ore',4:'duranite_ore',5:'titanex_ore',6:'plasmite_ore',7:'quantite_ore',8:'neutronium_ore',9:'darkmatter_shard',10:'voidsteel_ore'};
var BAR_IDS={1:'stellarite_bar',2:'ferrite_bar',3:'cobaltium_bar',4:'duranite_bar',5:'titanex_bar',6:'plasmite_bar',7:'quantite_bar',8:'neutronium_bar',9:'darkmatter_bar',10:'voidsteel_bar',11:'ascendant_alloy',12:'corrupted_ingot'};
var SMELT_XP={1:15,2:30,3:50,4:75,5:105,6:140,7:185,8:240,9:310,10:400};
var CRAFT_XP_BASE={1:25,2:50,3:80,4:120,5:170,6:230,7:300,8:380,9:470,10:580,11:700,12:850};
var BAR_COST={1:2,2:3,3:3,4:4,5:4,6:5,7:5,8:6,9:6,10:7,11:8,12:8};
var BIO_MAT={1:'chitin_shard',2:'chitin_shard',3:'jelly_membrane',4:'jelly_membrane',5:'spore_gland',6:'spore_gland',7:'gravity_residue',8:'gravity_residue',9:'neural_tissue',10:'neural_tissue',11:'corrupted_essence',12:'corrupted_essence'};
TIER_DEFS.forEach(function(t){
    var barId=BAR_IDS[t.tier];
    if(t.tier<=10){
        RECIPES['smelt_'+t.prefix]={skill:'circuitry',level:t.lvl,xp:SMELT_XP[t.tier],input:{[ORE_IDS[t.tier]]:1},output:{[barId]:1},name:'Smelt '+t.name};
    }
    WEAPON_DEFS_GEN.forEach(function(w){
        var inp={};inp[barId]=BAR_COST[t.tier];
        RECIPES['craft_'+t.prefix+'_'+w.suffix]={skill:'circuitry',level:t.lvl,xp:CRAFT_XP_BASE[t.tier],input:inp,output:{[t.prefix+'_'+w.suffix]:1},name:'Forge '+t.name+' '+w.sname};
    });
    var slotMults={helmet:0.6,vest:1.0,legs:0.8,boots:0.4,gloves:0.4};
    SLOT_DEFS.forEach(function(s){
        var bars=Math.max(1,Math.round(BAR_COST[t.tier]*slotMults[s.key]));
        var inp={};inp[barId]=bars;
        RECIPES['craft_'+t.prefix+'_'+s.key]={skill:'circuitry',level:t.lvl,xp:Math.round(CRAFT_XP_BASE[t.tier]*slotMults[s.key]),input:inp,output:{[t.prefix+'_'+s.key]:1},name:'Forge '+t.name+' '+s.sname};
    });
    ['nano','tesla','void'].forEach(function(style){
        var sn=STYLE_NAMES[style];
        SLOT_DEFS.forEach(function(s){
            var bars=Math.max(1,Math.round(BAR_COST[t.tier]*slotMults[s.key]*0.8));
            var bioQty=Math.max(1,Math.round(bars*0.5));
            var inp={};inp[barId]=bars;inp[BIO_MAT[t.tier]]=bioQty;
            RECIPES['craft_'+t.prefix+'_'+style+'_'+s.key]={skill:'bioforge',level:t.lvl,xp:Math.round(CRAFT_XP_BASE[t.tier]*slotMults[s.key]*1.1),input:inp,output:{[t.prefix+'_'+style+'_'+s.key]:1},name:'Bioforge '+t.name+' '+sn+' '+s.sname};
        });
    });
});
// Combo alloy recipes
RECIPES.craft_ascendant_alloy={skill:'circuitry',level:91,xp:600,input:{neutronium_bar:2,darkmatter_bar:2,voidsteel_bar:2},output:{ascendant_alloy:1},name:'Forge Ascendant Alloy'};
RECIPES.craft_corrupted_ingot={skill:'circuitry',level:93,xp:900,input:{ascendant_alloy:2,corrupted_essence:1},output:{corrupted_ingot:1},name:'Forge Corrupted Ingot'};

var ORE_TO_BAR={stellarite_ore:'stellarite_bar',ferrite_ore:'ferrite_bar',cobaltium_ore:'cobaltium_bar',duranite_ore:'duranite_bar',titanex_ore:'titanex_bar',plasmite_ore:'plasmite_bar',quantite_ore:'quantite_bar',neutronium_ore:'neutronium_bar',darkmatter_shard:'darkmatter_bar',voidsteel_ore:'voidsteel_bar'};

// ========================================
// XP Table (RS3-style)
// ========================================
const XP_TABLE = [0];
for (let level = 1; level <= 99; level++) {
    const xpForLvl = Math.floor(level + 300 * Math.pow(2, level / 7));
    XP_TABLE.push((XP_TABLE[level - 1] || 0) + Math.floor(xpForLvl / 4));
}
function xpForLevel(level) { return XP_TABLE[Math.min(level - 1, 99)] || 0; }
function levelForXp(xp) {
    for (let l = 1; l <= 99; l++) { if (xp < XP_TABLE[l]) return l; }
    return 99;
}

// ========================================
// Player
// ========================================
const MOVE_SPEED = 24;
const player = {
    mesh: null,
    hp: 100, maxHp: 100, energy: 100, maxEnergy: 100, credits: 500,
    combatStyle: 'nano', combatTarget: null, inCombat: false, autoAttackTimer: 0,
    moveTarget: null, isMoving: false,
    isGathering: false, gatherTarget: null, gatherProgress: 0, gatherDuration: 3, activeTool: null,
    pendingGather: null, pendingNPC: null, pendingDungeon: false,
    skills: {
        nano:{level:1,xp:0}, tesla:{level:1,xp:0}, void:{level:1,xp:0},
        astromining:{level:1,xp:0}, bioforge:{level:1,xp:0}, circuitry:{level:1,xp:0}, xenocook:{level:1,xp:0},
        chronomancy:{level:1,xp:0},
    },
    equipment: { head:null, body:null, legs:null, boots:null, gloves:null, weapon:null, offhand:null },
    inventory: new Array(28).fill(null),
    attackBonus: 0, armorBonus: 0, damageBonus: 0,
    walkPhase: 0, currentArea: 'station-hub',
    unlockedSynergies: [],
    psionicsUnlocked: false,
    mindControlTarget: null, mindControlTimer: 0,
    psionicCooldowns: { tkPush:0, mindControl:0, timeDilate:0 },
    timeLoopData: { attempts:0, damageBonus:0, active:false, bossType:'neuroworm' },
    pendingTimeLoop: false,
    panelLocks: {},
    panelPositions: {},
    minimapExpanded: false,
    panelSizes: {},
    minimapSize: { width: 180, height: 180 },
    chatSize: null,
    chatPosition: null,
    chatLocked: false,
    autoEat: false,
    autoEatThreshold: 0.5,
    autoRetaliate: true,
    styleDmgMult: 1, styleAccMult: 1, styleSetBonus: {pieces:0,style:null,full:false},
    deathRecap: { lastDamageSource:'', totalDamageTaken:0, combatDuration:0, killCount:0 },
    quickSlots: [null,null,null,null,null],
    bestiary: {},
    xpTracker: { startTime:0, xpGains:{}, active:false },
    waypoint: null,
    prestige: {
        tier: 0,
        points: 0,
        totalPointsEarned: 0,
        totalPrestiges: 0,
        totalLevelsGained: 0,
        fastestPrestigeTime: Infinity,
        currentRunStart: Date.now(),
        purchasedItems: [],
        extraBankSlots: 0,
        extraStartCredits: 0,
        selectedAura: null,
        selectedTitle: null,
        xpBoostEnd: 0,
        undyingCooldown: 0,
        questHistory: [],
    },
};

function getPlayer() { return player; }

function buildPlayerMesh() {
    const g = new THREE.Group();
    // Body (named — used by animations + tier coloring)
    const body = new THREE.Mesh(new THREE.BoxGeometry(0.8,1.0,0.5), new THREE.MeshLambertMaterial({color:0x4a5a6a}));
    body.position.y=1.8; body.castShadow=true; body.name='body'; g.add(body);
    // Head (named — used by breathing anim + tier coloring)
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.35,12,10), new THREE.MeshLambertMaterial({color:0xd4a574}));
    head.position.y=2.75; head.castShadow=true; head.name='head'; g.add(head);
    // Visor (named — used by tier coloring)
    const visor = new THREE.Mesh(new THREE.CylinderGeometry(0.36,0.36,0.14,8,1,true,-Math.PI*0.4,Math.PI*0.8), new THREE.MeshBasicMaterial({color:0x00c8ff,transparent:true,opacity:0.85}));
    visor.position.set(0,2.75,0.12); visor.rotation.x=0.1; visor.name='visor'; g.add(visor);
    // Arms (named — used by walk/attack anims + tier coloring)
    const armMat = new THREE.MeshLambertMaterial({color:0x4a5a6a});
    const la = new THREE.Mesh(new THREE.CapsuleGeometry(0.11,0.55,4,8),armMat); la.position.set(-0.55,1.7,0); la.name='leftArm'; g.add(la);
    const ra = new THREE.Mesh(new THREE.CapsuleGeometry(0.11,0.55,4,8),armMat.clone()); ra.position.set(0.55,1.7,0); ra.name='rightArm'; g.add(ra);
    // Legs (named — used by walk anim + tier coloring)
    const legMat = new THREE.MeshLambertMaterial({color:0x3a4a5a});
    const ll = new THREE.Mesh(new THREE.CapsuleGeometry(0.13,0.6,4,8),legMat); ll.position.set(-0.2,0.7,0); ll.name='leftLeg'; g.add(ll);
    const rl = new THREE.Mesh(new THREE.CapsuleGeometry(0.13,0.6,4,8),legMat.clone()); rl.position.set(0.2,0.7,0); rl.name='rightLeg'; g.add(rl);
    // --- Detail meshes (unnamed, not referenced by animation code) ---
    var detailMat=new THREE.MeshLambertMaterial({color:0x5a6a7a});
    // Shoulder pads
    var lShoulder=new THREE.Mesh(new THREE.BoxGeometry(0.32,0.08,0.32),detailMat);lShoulder.position.set(-0.48,2.35,0);g.add(lShoulder);
    var rShoulder=new THREE.Mesh(new THREE.BoxGeometry(0.32,0.08,0.32),detailMat);rShoulder.position.set(0.48,2.35,0);g.add(rShoulder);
    // Collar / neck guard
    var collar=new THREE.Mesh(new THREE.BoxGeometry(0.5,0.08,0.35),detailMat);collar.position.set(0,2.38,0);g.add(collar);
    // Belt + buckle
    var belt=new THREE.Mesh(new THREE.BoxGeometry(0.85,0.1,0.55),new THREE.MeshLambertMaterial({color:0x3a3a3a}));belt.position.set(0,1.25,0);g.add(belt);
    var buckle=new THREE.Mesh(new THREE.BoxGeometry(0.12,0.08,0.1),new THREE.MeshBasicMaterial({color:0xccaa44}));buckle.position.set(0,1.25,0.28);g.add(buckle);
    // Backpack unit
    var backpack=new THREE.Mesh(new THREE.BoxGeometry(0.35,0.4,0.15),new THREE.MeshLambertMaterial({color:0x3a4a3a}));backpack.position.set(0,1.9,-0.33);g.add(backpack);
    // Ear covers
    var earMat=new THREE.MeshLambertMaterial({color:0x4a5a6a});
    var lEar=new THREE.Mesh(new THREE.BoxGeometry(0.06,0.14,0.12),earMat);lEar.position.set(-0.34,2.72,0);g.add(lEar);
    var rEar=new THREE.Mesh(new THREE.BoxGeometry(0.06,0.14,0.12),earMat);rEar.position.set(0.34,2.72,0);g.add(rEar);
    // Knee guards
    var kneeMat=new THREE.MeshLambertMaterial({color:0x5a6a7a});
    var lKnee=new THREE.Mesh(new THREE.BoxGeometry(0.15,0.1,0.08),kneeMat);lKnee.position.set(-0.2,0.95,0.18);g.add(lKnee);
    var rKnee=new THREE.Mesh(new THREE.BoxGeometry(0.15,0.1,0.08),kneeMat);rKnee.position.set(0.2,0.95,0.18);g.add(rKnee);
    // Boots (named — for tier coloring)
    var bootMat=new THREE.MeshLambertMaterial({color:0x2a2a2a});
    var lBoot=new THREE.Mesh(new THREE.BoxGeometry(0.2,0.3,0.32),bootMat);lBoot.position.set(-0.2,0.22,0.02);lBoot.name='leftBoot';g.add(lBoot);
    var rBoot=new THREE.Mesh(new THREE.BoxGeometry(0.2,0.3,0.32),bootMat.clone());rBoot.position.set(0.2,0.22,0.02);rBoot.name='rightBoot';g.add(rBoot);
    // Gloves (named — for tier coloring)
    var gloveMat=new THREE.MeshLambertMaterial({color:0x4a5a6a});
    var lGlove=new THREE.Mesh(new THREE.BoxGeometry(0.18,0.2,0.18),gloveMat);lGlove.position.set(-0.55,1.25,0);lGlove.name='leftGlove';g.add(lGlove);
    var rGlove=new THREE.Mesh(new THREE.BoxGeometry(0.18,0.2,0.18),gloveMat.clone());rGlove.position.set(0.55,1.25,0);rGlove.name='rightGlove';g.add(rGlove);
    g.userData.entityType='player';
    return g;
}

function recalcStats() {
    let armor=0,damage=0,accuracy=0;
    var weaponStyle=player.equipment.weapon?player.equipment.weapon.style:null;
    var styleCount=0;
    var armorSlots=['head','body','legs','boots','gloves'];
    for (var slotName of Object.keys(player.equipment)) {
        var item=player.equipment[slotName];
        if (!item) continue;
        var broken = (item.durability !== undefined && item.durability <= 0);
        var mult = broken ? BROKEN_STAT_PENALTY : 1;
        if (item.armor) armor += Math.round(item.armor * mult);
        if (item.damage) damage += Math.round(item.damage * mult);
        if (item.accuracy) accuracy += Math.round(item.accuracy * mult);
        if (weaponStyle && item.armorStyle === weaponStyle && armorSlots.indexOf(slotName) >= 0) styleCount++;
    }
    player.armorBonus=armor; player.damageBonus=damage; player.attackBonus=accuracy;
    // Style set bonus
    player.styleSetBonus={pieces:styleCount,style:weaponStyle,full:styleCount>=5};
    if(styleCount>=5){player.styleDmgMult=1.10;player.styleAccMult=1.05;}
    else if(styleCount>=2){player.styleDmgMult=1.05;player.styleAccMult=1.03;}
    else{player.styleDmgMult=1;player.styleAccMult=1;}
    const cl = getCombatLevel();
    var baseHp=hasPrestigePassive(2)?120:100;
    player.maxHp=baseHp+cl*10; player.maxEnergy=100+cl*5;
    EventBus.emit('statsChanged');
}

function gainXp(skill, amount) {
    if (!player.skills[skill]) return;
    // Prestige skill gates
    if(skill === 'psionics' && !player.psionicsUnlocked) return;
    if(skill === 'chronomancy'){
        var maxCombatLv = Math.max(player.skills.nano.level, player.skills.tesla.level, player.skills.void.level);
        if(maxCombatLv < 10) return;
    }
    // Prestige XP rate modifiers
    if(skill === 'psionics') amount = Math.max(1, Math.round(amount * 0.6));
    if(skill === 'chronomancy') amount = Math.max(1, Math.round(amount * 0.8));
    // Prestige XP multiplier
    if(player.prestige.tier>0) amount=Math.max(1,Math.round(amount*getPrestigeXpMultiplier()));
    // Tier 1: Echo of Knowledge — 5% chance double XP
    if(hasPrestigePassive(1)&&Math.random()<0.05){amount*=2;EventBus.emit('chat',{type:'skill',text:'Echo of Knowledge! Double XP!'});}
    const s = player.skills[skill];
    const oldLevel = s.level;
    s.xp += amount;
    s.level = levelForXp(s.xp);
    EventBus.emit('xpGained',{skill,amount,totalXp:s.xp,level:s.level});
    if (s.level > oldLevel) {
        EventBus.emit('levelUp',{skill,level:s.level});
        EventBus.emit('chat',{type:'skill',text:'Congratulations! Your '+skill+' level is now '+s.level+'!'});
        triggerLevelUpEffect(skill,s.level);
        playSound('levelup');
        recalcStats();
        checkSynergies();
    }
}

function triggerLevelUpEffect(skill,newLevel){
    const pos=player.mesh.position.clone().add(new THREE.Vector3(0,2,0));
    spawnParticles(pos,0xffcc44,50,6,2.0,0.15);
    spawnParticles(pos,0xffffff,30,4,1.5,0.1);
    spawnParticles(pos.clone().add(new THREE.Vector3(0,1,0)),0x00ff88,20,3,1.0,0.08);
    // Rising spiral particles
    for(let i=0;i<20;i++){
        const angle=(i/20)*Math.PI*4;
        const delay=i*0.05;
        setTimeout(()=>{
            if(!player.mesh)return;
            const spiralPos=player.mesh.position.clone().add(new THREE.Vector3(Math.cos(angle)*1.5,0.5+i*0.15,Math.sin(angle)*1.5));
            spawnParticles(spiralPos,0xffcc44,2,1,0.8,0.06);
        },delay*1000);
    }
    triggerScreenShake(0.5,0.4);
    triggerScreenFlash('rgba(255,215,0,0.3)',200);
    showLevelUpOverlay(skill,newLevel);
}

function showLevelUpOverlay(skill,level){
    const overlay=document.createElement('div');
    overlay.className='level-up-overlay';
    const skillNames={nano:'Nanotech',tesla:'Tesla',void:'Void',astromining:'Astromining',bioforge:'Bioforge',circuitry:'Circuitry',xenocook:'Xenocook',psionics:'Psionics',chronomancy:'Chronomancy'};
    overlay.innerHTML='<div class="level-up-text">LEVEL UP!</div><div class="level-up-skill">'+(skillNames[skill]||skill)+'</div><div class="level-up-level">Level '+level+'</div>';
    document.getElementById('ui-overlay').appendChild(overlay);
    setTimeout(()=>overlay.remove(),3000);
}

function playerTakeDamage(amount) {
    // Temporal Shield - chance to negate damage
    if(player.skills.chronomancy){
        var shieldChance=getSkillBonus('chronomancy','temporalShield');
        if(hasSkillMilestone('chronomancy','timeLord'))shieldChance*=1.25;
        if(shieldChance>0&&Math.random()<Math.min(0.30,shieldChance)){
            spawnParticles(player.mesh.position.clone().add(new THREE.Vector3(0,2,0)),0x44ffff,15,3,0.5,0.1);
            EventBus.emit('chat',{type:'info',text:'Temporal Shield! Damage negated!'});
            gainXp('chronomancy',Math.round(amount*0.3));
            return;
        }
    }
    // Psychic Barrier - damage reduction
    if(player.psionicsUnlocked&&player.skills.psionics){
        var psychicReduction=getSkillBonus('psionics','psychicBarrier');
        if(psychicReduction>0)amount=Math.round(amount*(1-psychicReduction));
    }
    var reduced = Math.max(1, amount - player.armorBonus * 0.5);
    // Prestige damage reduction
    if(player.prestige.tier>0){var pRed=getPrestigeReduction();if(pRed>0)reduced=Math.round(reduced*(1-pRed));}
    // Tier 8: Undying — survive lethal hit once per 5 min
    if(hasPrestigePassive(8)&&player.prestige.undyingCooldown<=0&&player.hp>0&&player.hp-reduced<=0){
        player.hp=1;player.prestige.undyingCooldown=300;
        spawnParticles(player.mesh.position.clone().add(new THREE.Vector3(0,2,0)),0xffaaaa,40,5,1.5,0.15);
        EventBus.emit('chat',{type:'system',text:'Undying! You survive with 1 HP!'});
        playSound('levelup');return;
    }
    player.hp = Math.max(0, player.hp - reduced);
    player.hitFlash=0.2;
    triggerScreenFlash('rgba(255,0,0,0.3)',150);
    player.deathRecap.totalDamageTaken+=Math.round(reduced);
    degradeArmor();
    EventBus.emit('playerDamaged',{amount:Math.round(reduced)});
    if (player.hp <= 0) playerDie();
    return Math.round(reduced);
}

function playerHeal(amount) {
    player.hp = Math.min(player.maxHp, player.hp + amount);
    EventBus.emit('playerHealed',{amount});
}

function playerDie() {
    // Death recap (Feature 4)
    var recap=player.deathRecap;
    var recapTime=Math.round(recap.combatDuration);
    EventBus.emit('chat',{type:'system',text:'--- DEATH RECAP ---'});
    EventBus.emit('chat',{type:'combat',text:'Killed by: '+(recap.lastDamageSource||'Unknown')});
    EventBus.emit('chat',{type:'combat',text:'Damage taken: '+recap.totalDamageTaken+' | Enemies killed: '+recap.killCount+' | Combat time: '+recapTime+'s'});
    EventBus.emit('chat',{type:'system',text:'-------------------'});
    playSound('death');
    if (DungeonState.active) {
        if(player.timeLoopData.active){
            player.timeLoopData.attempts++;
            player.timeLoopData.damageBonus=Math.min(0.50,player.timeLoopData.attempts*0.05);
            EventBus.emit('chat',{type:'system',text:'The time loop resets... Attempt '+player.timeLoopData.attempts+' complete. +5% damage next attempt.'});
            player.timeLoopData.active=false;
        }
        EventBus.emit('chat',{type:'combat',text:'Defeated in the Abyssal Depths! Returning to surface...'});
        exitDungeon();
        player.hp=player.maxHp; player.energy=player.maxEnergy;
        player.combatTarget=null; player.inCombat=false; player.isMoving=false;
        player.moveTarget=null; player.isGathering=false;
        EventBus.emit('playerRespawned');
        return;
    }
    EventBus.emit('chat',{type:'combat',text:'You have been defeated! Respawning at Station Hub...'});
    player.mesh.position.set(0,0,5);
    player.hp=player.maxHp; player.energy=player.maxEnergy;
    player.combatTarget=null; player.inCombat=false; player.isMoving=false;
    player.moveTarget=null; player.isGathering=false;
    player.currentArea='station-hub'; GameState.currentArea='station-hub';
    EventBus.emit('areaChanged','station-hub'); EventBus.emit('playerRespawned');
}

function moveTo(point) {
    var destX = point.x, destZ = point.z;
    if (!isValidPosition(destX, destZ)) {
        if (DungeonState.active) {
            // In dungeon: find nearest valid room center to click
            var nearRoom = null, nearDist = Infinity;
            for (var dri = 0; dri < DungeonState.rooms.length; dri++) {
                var dr = DungeonState.rooms[dri];
                var ddx = destX - dr.worldX, ddz = destZ - dr.worldZ;
                var dd = Math.sqrt(ddx * ddx + ddz * ddz);
                if (dd < nearDist) { nearDist = dd; nearRoom = dr; }
            }
            if (nearRoom) {
                destX = Math.max(nearRoom.worldX - nearRoom.width / 2 + 1, Math.min(nearRoom.worldX + nearRoom.width / 2 - 1, destX));
                destZ = Math.max(nearRoom.worldZ - nearRoom.depth / 2 + 1, Math.min(nearRoom.worldZ + nearRoom.depth / 2 - 1, destZ));
            }
        } else {
        // Clamp to nearest area edge
        var bestX = destX, bestZ = destZ, bestDist = Infinity;
        for (var aid in AREAS) {
            var a = AREAS[aid];
            var adx = destX - a.center.x, adz = destZ - a.center.z;
            var adist = Math.sqrt(adx * adx + adz * adz);
            if (adist < a.radius) { bestDist = -1; bestX = destX; bestZ = destZ; break; }
            var edgeDist = adist - a.radius;
            if (edgeDist < bestDist) {
                bestDist = edgeDist;
                bestX = a.center.x + (adx / adist) * (a.radius - 1);
                bestZ = a.center.z + (adz / adist) * (a.radius - 1);
            }
        }
        for (var ci = 0; ci < CORRIDORS.length; ci++) {
            var c = CORRIDORS[ci];
            var cx = Math.max(c.minX, Math.min(c.maxX, destX));
            var cz = Math.max(c.minZ, Math.min(c.maxZ, destZ));
            var cdist = Math.sqrt(Math.pow(destX - cx, 2) + Math.pow(destZ - cz, 2));
            if (cdist < bestDist) { bestDist = cdist; bestX = cx; bestZ = cz; }
        }
        destX = bestX; destZ = bestZ;
        }
    }
    player.moveTarget = new THREE.Vector3(destX, 0, destZ);
    player.isMoving = true; player.isGathering = false; player.gatherTarget = null; player.gatherProgress = 0;
    checkTutorialEvent('playerMoved');
}

function updatePlayerMovement() {
    if (!player.isMoving || player.isGathering) return;
    const pos=player.mesh.position;
    if(!player.moveTarget)return;
    const tgt=player.moveTarget;
    const dx=tgt.x-pos.x, dz=tgt.z-pos.z, dist=Math.sqrt(dx*dx+dz*dz);
    if (dist<0.5) { player.isMoving=false; player.moveTarget=null; return; }
    player.mesh.rotation.y=Math.atan2(dx,dz);
    var moveSpd = (DungeonState.active && player._dungeonSlowed) ? MOVE_SPEED * 0.5 : MOVE_SPEED;
    const step=Math.min(moveSpd*GameState.deltaTime, dist);
    pos.x+=(dx/dist)*step; pos.z+=(dz/dist)*step;
    // Boundary check: allow movement through areas and corridors
    if (!isValidPosition(pos.x, pos.z)) {
        if (DungeonState.active) {
            // In dungeon: stop movement at boundary
            pos.x -= (dx/dist)*step; pos.z -= (dz/dist)*step;
            player.isMoving = false; player.moveTarget = null;
        } else {
        var bestX = pos.x, bestZ = pos.z, bestDist = Infinity;
        for (var baid in AREAS) {
            var ba = AREAS[baid];
            var badx = pos.x - ba.center.x, badz = pos.z - ba.center.z;
            var badist = Math.sqrt(badx * badx + badz * badz);
            if (badist < ba.radius) { bestDist = -1; break; }
            var bedge = badist - ba.radius;
            if (bedge < bestDist) {
                bestDist = bedge;
                bestX = ba.center.x + (badx / badist) * (ba.radius - 0.5);
                bestZ = ba.center.z + (badz / badist) * (ba.radius - 0.5);
            }
        }
        for (var bci = 0; bci < CORRIDORS.length; bci++) {
            var bc = CORRIDORS[bci];
            var bcx = Math.max(bc.minX, Math.min(bc.maxX, pos.x));
            var bcz = Math.max(bc.minZ, Math.min(bc.maxZ, pos.z));
            var bcdist = Math.sqrt(Math.pow(pos.x - bcx, 2) + Math.pow(pos.z - bcz, 2));
            if (bcdist < bestDist) { bestDist = bcdist; bestX = bcx; bestZ = bcz; }
        }
        if (bestDist >= 0) {
            pos.x = bestX; pos.z = bestZ;
            player.isMoving = false; player.moveTarget = null;
        }
        }
    }
    // Area transition detection (skip in dungeon)
    if (DungeonState.active) { /* skip area transitions in dungeon */ }
    else {
    var newArea = getAreaAtPosition(pos.x, pos.z);
    if (newArea && newArea !== player.currentArea) {
        player.currentArea = newArea;
        GameState.currentArea = newArea;
        var areaName = AREAS[newArea] ? AREAS[newArea].name : newArea;
        triggerAreaTransition(areaName);
        EventBus.emit('areaChanged', newArea);
        EventBus.emit('chat', { type: 'system', text: 'You enter ' + areaName + '.' });
        if (typeof saveGame === 'function') saveGame();
    }
    }
    player.walkPhase+=GameState.deltaTime*8;
    const swing=Math.sin(player.walkPhase)*0.3;
    const la=player.mesh.getObjectByName('leftArm'), ra=player.mesh.getObjectByName('rightArm');
    const ll=player.mesh.getObjectByName('leftLeg'), rl=player.mesh.getObjectByName('rightLeg');
    if(la)la.rotation.x=swing; if(ra)ra.rotation.x=-swing;
    if(ll)ll.rotation.x=-swing; if(rl)rl.rotation.x=swing;
    // Walking dust puffs
    if(!player._dustTimer)player._dustTimer=0;
    player._dustTimer+=GameState.deltaTime;
    if(player._dustTimer>0.25){
        player._dustTimer=0;
        var fp=player.mesh.position;
        spawnParticles(new THREE.Vector3(fp.x+(Math.random()-0.5)*0.3,0.1,fp.z+(Math.random()-0.5)*0.3),0x888888,2,0.4,0.6,0.05);
    }
}

function resetWalkAnimation() {
    var la=player.mesh.getObjectByName('leftArm'),ra=player.mesh.getObjectByName('rightArm');
    var ll=player.mesh.getObjectByName('leftLeg'),rl=player.mesh.getObjectByName('rightLeg');
    // Attack animation override
    if(player.attackAnim>0){
        player.attackAnim-=GameState.deltaTime;
        var t=Math.max(0,player.attackAnim)/0.25;
        if(ra)ra.rotation.x=-1.2*t;
        if(la)la.rotation.x=0.3*t;
        if(ll)ll.rotation.x=0;if(rl)rl.rotation.x=0;
        return;
    }
    // Idle breathing when standing still
    var breathe=Math.sin(GameState.elapsedTime*1.5)*0.02;
    var body=player.mesh.getObjectByName('body'),head=player.mesh.getObjectByName('head');
    if(body)body.position.y=1.8+breathe;
    if(head)head.position.y=2.75+breathe;
    if(la)la.rotation.x=0;if(ra)ra.rotation.x=0;
    if(ll)ll.rotation.x=0;if(rl)rl.rotation.x=0;
}

function updatePlayerEnergy() {
    if(!player.inCombat&&player.energy<player.maxEnergy) player.energy=Math.min(player.maxEnergy,player.energy+5*GameState.deltaTime);
    if(!player.inCombat&&player.hp<player.maxHp) player.hp=Math.min(player.maxHp,player.hp+1*GameState.deltaTime);
}

function getTierColor(tier) {
    return {1:0x5a5a5a,2:0x2a6a3a,3:0x2a4a8a,4:0x3a6a7a,5:0x5a7a2a,6:0x6a2a8a,7:0x8a4a2a,8:0x8a2a4a,9:0x7a2a8a,10:0x8a5a1a,11:0x2a8a7a,12:0x8a1a3a}[tier]||0x4a5a6a;
}

function updateMeshColors() {
    const bodyItem=player.equipment.body, legItem=player.equipment.legs, headItem=player.equipment.head, weapon=player.equipment.weapon;
    const bc=bodyItem?getTierColor(bodyItem.tier):0x4a5a6a;
    const lc=legItem?getTierColor(legItem.tier):0x3a4a5a;
    const hc=headItem?getTierColor(headItem.tier):0xd4a574;
    ['body','leftArm','rightArm'].forEach(n=>{const m=player.mesh.getObjectByName(n);if(m)m.material.color.setHex(bc);});
    ['leftLeg','rightLeg'].forEach(n=>{const m=player.mesh.getObjectByName(n);if(m)m.material.color.setHex(lc);});
    const visor=player.mesh.getObjectByName('visor');
    if(visor)visor.material.color.setHex(headItem?getTierColor(headItem.tier):0x00c8ff);
    // Boot + glove tier coloring
    const bootItem=player.equipment.boots;const bootColor=bootItem?getTierColor(bootItem.tier):0x2a2a2a;
    ['leftBoot','rightBoot'].forEach(n=>{const m=player.mesh.getObjectByName(n);if(m)m.material.color.setHex(bootColor);});
    const gloveItem=player.equipment.gloves;const gloveColor=gloveItem?getTierColor(gloveItem.tier):0x4a5a6a;
    ['leftGlove','rightGlove'].forEach(n=>{const m=player.mesh.getObjectByName(n);if(m)m.material.color.setHex(gloveColor);});
    // Remove old weapon mesh
    const oldWep=player.mesh.getObjectByName('weaponMesh');if(oldWep)player.mesh.remove(oldWep);
    // Add style-specific weapon
    if(weapon){
        const wc={nano:0x44ff88,tesla:0x44aaff,void:0xaa44ff}[weapon.style]||0xffffff;
        const wg=new THREE.Group();wg.name='weaponMesh';
        if(weapon.style==='nano'){
            var blade=new THREE.Mesh(new THREE.ConeGeometry(0.06,0.7,5),new THREE.MeshBasicMaterial({color:wc,transparent:true,opacity:0.8}));blade.rotation.x=Math.PI;
            var hilt=new THREE.Mesh(new THREE.CylinderGeometry(0.04,0.04,0.2,4),new THREE.MeshLambertMaterial({color:0x444444}));hilt.position.y=-0.45;
            wg.add(blade);wg.add(hilt);
        }else if(weapon.style==='tesla'){
            var barrel=new THREE.Mesh(new THREE.CylinderGeometry(0.04,0.06,0.75,6),new THREE.MeshLambertMaterial({color:0x666666}));
            var muzzle=new THREE.Mesh(new THREE.RingGeometry(0.03,0.07,6),new THREE.MeshBasicMaterial({color:wc,side:THREE.DoubleSide}));muzzle.position.y=0.38;muzzle.rotation.x=Math.PI/2;
            var coil=new THREE.Mesh(new THREE.TorusGeometry(0.07,0.015,4,8),new THREE.MeshBasicMaterial({color:wc,transparent:true,opacity:0.5}));coil.position.y=0.15;coil.rotation.x=Math.PI/2;
            wg.add(barrel);wg.add(muzzle);wg.add(coil);
        }else{
            var shaft=new THREE.Mesh(new THREE.CylinderGeometry(0.025,0.025,0.7,4),new THREE.MeshLambertMaterial({color:0x444444}));
            var orb=new THREE.Mesh(new THREE.SphereGeometry(0.1,6,6),new THREE.MeshBasicMaterial({color:wc,transparent:true,opacity:0.7}));orb.position.y=0.4;
            wg.add(shaft);wg.add(orb);
        }
        wg.position.set(0.55,2.3,0.2);player.mesh.add(wg);
    }
}

// ========================================
// Inventory
// ========================================
function addItem(itemId, quantity) {
    quantity = quantity || 1;
    const def = getItem(itemId); if(!def) return false;
    if (def.stackable) {
        for (let i=0;i<player.inventory.length;i++) {
            if(player.inventory[i]&&player.inventory[i].itemId===itemId){player.inventory[i].quantity+=quantity;EventBus.emit('inventoryChanged');showPickupToast(def.name,def.icon,quantity);return true;}
        }
    }
    for (let i=0;i<player.inventory.length;i++) {
        if(player.inventory[i]===null){player.inventory[i]={itemId,quantity:def.stackable?quantity:1};EventBus.emit('inventoryChanged');if(!def.stackable&&quantity>1)addItem(itemId,quantity-1);else showPickupToast(def.name,def.icon,quantity);return true;}
    }
    EventBus.emit('chat',{type:'info',text:'Your inventory is full!'});return false;
}

function removeItem(itemId, quantity) {
    quantity=quantity||1;
    for(let i=0;i<player.inventory.length;i++){
        if(player.inventory[i]&&player.inventory[i].itemId===itemId){player.inventory[i].quantity-=quantity;if(player.inventory[i].quantity<=0)player.inventory[i]=null;EventBus.emit('inventoryChanged');return true;}
    }
    return false;
}

function hasItem(itemId, quantity) {
    quantity=quantity||1; let count=0;
    for(const s of player.inventory){if(s&&s.itemId===itemId)count+=s.quantity;}
    return count>=quantity;
}

function countItem(itemId) {
    let c=0; for(const s of player.inventory){if(s&&s.itemId===itemId)c+=s.quantity;} return c;
}

function hasEmptySlot() { return player.inventory.some(s=>s===null); }

function equipItem(slotIndex) {
    const invSlot=player.inventory[slotIndex]; if(!invSlot)return;
    const def=getItem(invSlot.itemId); if(!def||!def.slot)return;
    if(def.levelReq){
        var checkLvl,reqSkill;
        if(def.type==='weapon'){reqSkill=def.style;checkLvl=player.skills[def.style]?player.skills[def.style].level:getCombatLevel();}
        else if(def.armorStyle){reqSkill=def.armorStyle;checkLvl=player.skills[def.armorStyle]?player.skills[def.armorStyle].level:getCombatLevel();}
        else{reqSkill='combat';checkLvl=getCombatLevel();}
        if(checkLvl<def.levelReq){var rn=reqSkill==='combat'?'Combat':reqSkill.charAt(0).toUpperCase()+reqSkill.slice(1);EventBus.emit('chat',{type:'info',text:'You need '+rn+' level '+def.levelReq+' to equip this.'});return;}
    }
    const es=def.slot, cur=player.equipment[es];
    // Unequip current item back to inventory, carrying durability
    if(cur){
        var unequipSlot = {itemId:cur.id, quantity:1};
        if (cur.durability !== undefined) { unequipSlot.durability = cur.durability; unequipSlot.maxDurability = cur.maxDurability; }
        player.inventory[slotIndex] = unequipSlot;
    } else {
        player.inventory[slotIndex]=null;
    }
    // Clone item def for per-instance durability
    var equipped = Object.assign({}, def);
    // Carry durability from inventory slot or init fresh
    if (invSlot.durability !== undefined) {
        equipped.durability = invSlot.durability;
        equipped.maxDurability = invSlot.maxDurability;
    } else if (equipped.type === ItemType.WEAPON || equipped.type === ItemType.ARMOR) {
        var dur = initDurability(equipped);
        equipped.durability = dur.durability;
        equipped.maxDurability = dur.maxDurability;
    }
    player.equipment[es]=equipped;
    if(def.type==='weapon'&&def.style){player.combatStyle=def.style;EventBus.emit('styleChanged',def.style);}
    recalcStats();updateMeshColors();EventBus.emit('inventoryChanged');EventBus.emit('equipmentChanged');
    playSound('equip');
    EventBus.emit('chat',{type:'info',text:'You equip the '+def.name+'.'});
}

function unequipItem(slot) {
    const item=player.equipment[slot]; if(!item)return;
    if(!hasEmptySlot()){EventBus.emit('chat',{type:'info',text:'Your inventory is full!'});return;}
    // Add to inventory with durability info
    var added = false;
    for (var ui = 0; ui < player.inventory.length; ui++) {
        if (player.inventory[ui] === null) {
            var invSlot = { itemId: item.id, quantity: 1 };
            if (item.durability !== undefined) { invSlot.durability = item.durability; invSlot.maxDurability = item.maxDurability; }
            player.inventory[ui] = invSlot;
            added = true;
            break;
        }
    }
    if (!added) { EventBus.emit('chat',{type:'info',text:'Your inventory is full!'}); return; }
    player.equipment[slot]=null;
    recalcStats();updateMeshColors();EventBus.emit('inventoryChanged');EventBus.emit('equipmentChanged');
    EventBus.emit('chat',{type:'info',text:'You unequip the '+item.name+'.'});
}

function dropItem(slotIndex) {
    const invSlot=player.inventory[slotIndex]; if(!invSlot)return;
    const def=getItem(invSlot.itemId); player.inventory[slotIndex]=null;
    EventBus.emit('inventoryChanged');EventBus.emit('chat',{type:'info',text:'You drop the '+def.name+'.'});
}

function useItem(slotIndex) {
    const invSlot=player.inventory[slotIndex]; if(!invSlot)return;
    const def=getItem(invSlot.itemId); if(!def)return;
    if(def.type==='food'&&def.heals){
        if(player.hp>=player.maxHp){EventBus.emit('chat',{type:'info',text:'You already have full health.'});return;}
        var healAmount = def.heals;
        var healBonus = getSynergyValue('heal_bonus', {}) + getSkillBonus('xenocook','healBonus');
        healAmount = Math.round(healAmount * (1 + healBonus));
        const oldHp=player.hp; player.hp=Math.min(player.maxHp,player.hp+healAmount);
        const healed=Math.round(player.hp-oldHp);
        invSlot.quantity-=1; if(invSlot.quantity<=0)player.inventory[slotIndex]=null;
        EventBus.emit('playerHealed',{amount:healed});EventBus.emit('inventoryChanged');
        playSound('eat');
        EventBus.emit('chat',{type:'info',text:'You eat the '+def.name+' and heal '+healed+' HP.'});
    }
}

function addCredits(amount){player.credits+=amount;EventBus.emit('creditsChanged');}
function removeCredits(amount){if(player.credits<amount)return false;player.credits-=amount;EventBus.emit('creditsChanged');return true;}

// ----------------------------------------
// Gear Degradation
// ----------------------------------------
var durabilityWarned = {};
function degradeWeapon(amount) {
    var weapon = player.equipment.weapon;
    if (!weapon || weapon.durability === undefined) return;
    if (weapon.durability <= 0) return; // already broken
    weapon.durability = Math.max(0, weapon.durability - amount);
    // Warning at threshold
    var pct = weapon.durability / weapon.maxDurability;
    if (pct <= DURABILITY_WARN_THRESHOLD && pct > 0 && !durabilityWarned[weapon.id + '_warn']) {
        durabilityWarned[weapon.id + '_warn'] = true;
        EventBus.emit('chat', { type: 'info', text: 'Your ' + weapon.name + ' is getting worn! (' + weapon.durability + '/' + weapon.maxDurability + ')' });
    }
    if (weapon.durability <= 0) {
        weapon.durability = 0;
        durabilityWarned[weapon.id + '_warn'] = false;
        EventBus.emit('chat', { type: 'combat', text: 'Your ' + weapon.name + ' has BROKEN! Repair it at a Repair Station.' });
        recalcStats();
        EventBus.emit('equipmentChanged');
    }
}

function degradeArmor() {
    var armorSlots = ['head', 'body', 'legs', 'boots', 'gloves'];
    var worn = [];
    for (var ai = 0; ai < armorSlots.length; ai++) {
        var piece = player.equipment[armorSlots[ai]];
        if (piece && piece.durability !== undefined && piece.durability > 0) worn.push(armorSlots[ai]);
    }
    if (worn.length === 0) return;
    var slot = worn[Math.floor(Math.random() * worn.length)];
    var armor = player.equipment[slot];
    armor.durability = Math.max(0, armor.durability - 1);
    var pct = armor.durability / armor.maxDurability;
    if (pct <= DURABILITY_WARN_THRESHOLD && pct > 0 && !durabilityWarned[armor.id + '_' + slot + '_warn']) {
        durabilityWarned[armor.id + '_' + slot + '_warn'] = true;
        EventBus.emit('chat', { type: 'info', text: 'Your ' + armor.name + ' is getting worn! (' + armor.durability + '/' + armor.maxDurability + ')' });
    }
    if (armor.durability <= 0) {
        armor.durability = 0;
        durabilityWarned[armor.id + '_' + slot + '_warn'] = false;
        EventBus.emit('chat', { type: 'combat', text: 'Your ' + armor.name + ' has BROKEN! Repair it at a Repair Station.' });
        recalcStats();
        EventBus.emit('equipmentChanged');
    }
}

// ========================================
// Bank System (48-slot storage)
// ========================================
const bankStorage=new Array(48).fill(null);
let bankOpen=false;

function openBank(){
    bankOpen=true;
    document.getElementById('bank-panel').style.display='flex';
    renderBank();
}
function closeBank(){bankOpen=false;document.getElementById('bank-panel').style.display='none';}
function depositItem(invIdx){
    const inv=player.inventory[invIdx];if(!inv)return;
    const def=getItem(inv.itemId);
    // Try stack first
    if(def.stackable){
        for(let i=0;i<bankStorage.length;i++){
            if(bankStorage[i]&&bankStorage[i].itemId===inv.itemId){bankStorage[i].quantity+=inv.quantity;player.inventory[invIdx]=null;EventBus.emit('inventoryChanged');renderBank();return;}
        }
    }
    for(let i=0;i<bankStorage.length;i++){
        if(bankStorage[i]===null){bankStorage[i]={itemId:inv.itemId,quantity:inv.quantity};player.inventory[invIdx]=null;EventBus.emit('inventoryChanged');renderBank();return;}
    }
    EventBus.emit('chat',{type:'info',text:'Bank is full!'});
}
function withdrawItem(bankIdx){
    const bk=bankStorage[bankIdx];if(!bk)return;
    const def=getItem(bk.itemId);
    if(def.stackable){
        for(let i=0;i<player.inventory.length;i++){
            if(player.inventory[i]&&player.inventory[i].itemId===bk.itemId){player.inventory[i].quantity+=bk.quantity;bankStorage[bankIdx]=null;EventBus.emit('inventoryChanged');renderBank();return;}
        }
    }
    for(let i=0;i<player.inventory.length;i++){
        if(player.inventory[i]===null){player.inventory[i]={itemId:bk.itemId,quantity:bk.quantity};bankStorage[bankIdx]=null;EventBus.emit('inventoryChanged');renderBank();return;}
    }
    EventBus.emit('chat',{type:'info',text:'Inventory is full!'});
}
function renderBank(){
    const bg=document.getElementById('bank-grid'),bi=document.getElementById('bank-inv-grid');
    bg.innerHTML='<div class="bank-section-label bank" style="display:flex;justify-content:space-between;align-items:center;">\uD83C\uDFE6 Bank Storage<button id="bank-stack-btn" style="background:rgba(0,100,200,0.3);border:1px solid #0066aa;border-radius:3px;color:#00c8ff;font-size:9px;padding:2px 8px;cursor:pointer;">Stack All</button></div>';
    for(let i=0;i<48;i++){
        const s=document.createElement('div');s.className='inv-slot';
        const bk=bankStorage[i];
        if(bk){const def=getItem(bk.itemId);s.classList.add('has-item');s.innerHTML='<span class="item-icon">'+def.icon+'</span>'+(bk.quantity>1?'<span class="item-count">'+bk.quantity+'</span>':'');s.title=def.name+(bk.quantity>1?' x'+bk.quantity:'');
            s.dataset.itemName=def.name.toLowerCase();
            s.addEventListener('click',()=>withdrawItem(i));
        } else {
            s.dataset.itemName='';
        }
        bg.appendChild(s);
    }
    bi.innerHTML='<div class="bank-section-label inv">\uD83C\uDF92 Inventory (click to deposit)</div>';
    player.inventory.forEach((inv,idx)=>{
        const s=document.createElement('div');s.className='inv-slot';
        if(inv){const def=getItem(inv.itemId);s.classList.add('has-item');s.innerHTML='<span class="item-icon">'+def.icon+'</span>'+(inv.quantity>1?'<span class="item-count">'+inv.quantity+'</span>':'');s.title=def.name;
            s.addEventListener('click',()=>depositItem(idx));
        }
        bi.appendChild(s);
    });
    // Stack All button (Feature 12)
    var stackBtn=document.getElementById('bank-stack-btn');
    if(stackBtn)stackBtn.addEventListener('click',stackAllBank);
}

function eatBestFood() {
    if(player.hp>=player.maxHp)return;
    for(let i=0;i<player.inventory.length;i++){
        const s=player.inventory[i]; if(!s)continue;
        const def=getItem(s.itemId);
        if(def&&def.type==='food'&&def.heals){useItem(i);return;}
    }
}

// ========================================
// Input & Camera
// ========================================
const cameraState = {
    distance:30, minDistance:10, maxDistance:60,
    angle:Math.PI/4, pitch:Math.PI/4, minPitch:0.15, maxPitch:Math.PI/2.2,
    targetPos:new THREE.Vector3(0,0,0), smoothSpeed:5,
    isDragging:false, dragStart:{x:0,y:0}, sensitivity:0.005,
};
const keys={};
let contextMenuVisible=false;

function showContextMenu(x,y,options){
    const menu=document.getElementById('context-menu');
    const list=document.getElementById('context-options');
    list.innerHTML='';
    options.forEach(opt=>{
        const li=document.createElement('li'); li.textContent=opt.label;
        if(opt.disabled){li.classList.add('disabled');}
        else{li.addEventListener('click',()=>{opt.action();hideContextMenu();});}
        list.appendChild(li);
    });
    menu.style.display='block'; menu.style.left=x+'px'; menu.style.top=y+'px';
    const rect=menu.getBoundingClientRect();
    if(rect.right>window.innerWidth)menu.style.left=(x-rect.width)+'px';
    if(rect.bottom>window.innerHeight)menu.style.top=(y-rect.height)+'px';
    contextMenuVisible=true;
}
function hideContextMenu(){if(contextMenuVisible){document.getElementById('context-menu').style.display='none';contextMenuVisible=false;}}

function raycastWorld(e){
    const mouse=new THREE.Vector2((e.clientX/window.innerWidth)*2-1,-(e.clientY/window.innerHeight)*2+1);
    GameState.raycaster.setFromCamera(mouse,GameState.camera);
    const clickables=[];
    GameState.enemies.forEach(en=>{if(en.mesh&&en.alive)clickables.push(en.mesh);});
    GameState.npcs.forEach(npc=>{if(npc.mesh)clickables.push(npc.mesh);});
    GameState.resourceNodes.forEach(n=>{if(n.mesh&&!n.depleted)clickables.push(n.mesh);});
    if(world.processingStations)world.processingStations.forEach(m=>{clickables.push(m);});
    if(world.questBoard)clickables.push(world.questBoard);
    if(world.dungeonEntrance)clickables.push(world.dungeonEntrance);
    GameState.scene.children.forEach(function(child){if(child.userData&&child.userData.entityType==='corruptedPortal')clickables.push(child);});
    const entityHits=GameState.raycaster.intersectObjects(clickables,true);
    if(entityHits.length>0){
        let obj=entityHits[0].object;
        while(obj.parent&&!obj.userData.entityType)obj=obj.parent;
        return{type:obj.userData.entityType||'unknown',entity:obj.userData.entity,point:entityHits[0].point,object:obj};
    }
    if(DungeonState.active){
        // Raycast dungeon floor meshes
        var dungeonFloors=DungeonState.meshes.filter(function(m){return m.userData&&m.userData.isGround;});
        if(dungeonFloors.length>0){
            var dgh=GameState.raycaster.intersectObjects(dungeonFloors,true);
            if(dgh.length>0)return{type:'ground',point:dgh[0].point};
        }
    }
    if(GameState.world&&GameState.world.ground){
        const gh=GameState.raycaster.intersectObject(GameState.world.ground,true);
        if(gh.length>0)return{type:'ground',point:gh[0].point};
    }
    return null;
}

function updateCamera(){
    if(!player.mesh)return;
    cameraState.targetPos.lerp(player.mesh.position,cameraState.smoothSpeed*GameState.deltaTime);
    const d=cameraState.distance,p=cameraState.pitch,a=cameraState.angle;
    GameState.camera.position.set(
        cameraState.targetPos.x+d*Math.cos(p)*Math.sin(a),
        cameraState.targetPos.y+d*Math.sin(p),
        cameraState.targetPos.z+d*Math.cos(p)*Math.cos(a)
    );
    GameState.camera.lookAt(cameraState.targetPos);
}

function initInput(){
    const canvas=document.getElementById('game-canvas');
    canvas.addEventListener('mousedown',e=>{
        if(e.button===1){cameraState.isDragging=true;cameraState.dragStart.x=e.clientX;cameraState.dragStart.y=e.clientY;e.preventDefault();}
    });
    window.addEventListener('mouseup',e=>{if(e.button===1)cameraState.isDragging=false;});
    let hoverThrottle=0;
    window.addEventListener('mousemove',e=>{
        GameState.mouse.x=(e.clientX/window.innerWidth)*2-1;
        GameState.mouse.y=-(e.clientY/window.innerHeight)*2+1;
        if(cameraState.isDragging){
            cameraState.angle-=(e.clientX-cameraState.dragStart.x)*cameraState.sensitivity;
            cameraState.pitch=Math.max(cameraState.minPitch,Math.min(cameraState.maxPitch,cameraState.pitch+(e.clientY-cameraState.dragStart.y)*cameraState.sensitivity));
            cameraState.dragStart.x=e.clientX;cameraState.dragStart.y=e.clientY;
        }
        // Throttled hover detection for mouseover labels
        const now=performance.now();
        if(now-hoverThrottle<50)return; // 20 fps hover updates
        hoverThrottle=now;
        if(e.target.closest&&e.target.closest('#ui-overlay')&&!e.target.closest('#game-canvas')){hideHoverLabel();return;}
        const hit=raycastWorld(e);
        updateHoverLabel(hit);
        canvas.style.cursor=(hit&&hit.type!=='ground')?'pointer':'default';
    });
    canvas.addEventListener('wheel',e=>{cameraState.distance=Math.max(cameraState.minDistance,Math.min(cameraState.maxDistance,cameraState.distance+e.deltaY*0.02));},{passive:true});
    canvas.addEventListener('click',e=>{
        if(e.target.closest('#ui-overlay')&&!e.target.closest('#game-canvas'))return;
        hideContextMenu();
        const hit=raycastWorld(e); if(hit)EventBus.emit('leftClick',hit);
    });
    canvas.addEventListener('contextmenu',e=>{
        e.preventDefault();
        if(e.target.closest('#ui-overlay')&&!e.target.closest('#game-canvas'))return;
        const hit=raycastWorld(e); if(hit)EventBus.emit('rightClick',{hit,screenX:e.clientX,screenY:e.clientY});
    });
    window.addEventListener('keydown',e=>{
        var chatFocused=document.activeElement&&document.activeElement.id==='mp-chat-input';
        // Enter key: focus/unfocus chat input
        if(e.key==='Enter'){
            var chatIn=document.getElementById('mp-chat-input');
            if(chatIn){
                if(chatFocused){
                    // If chat has text, send it (handled by multiplayer.js keydown); then blur
                    if(!chatIn.value.trim())chatIn.blur();
                } else {
                    e.preventDefault();
                    chatIn.focus();
                }
            }
            return;
        }
        // Escape blurs chat, then skip other game keybinds while typing
        if(chatFocused){
            if(e.key==='Escape'){document.activeElement.blur();}
            return;
        }
        keys[e.key.toLowerCase()]=true;
        // Number keys 1-9 no longer trigger abilities (OSRS auto-attack only)
        if(e.key==='Escape'){EventBus.emit('escape');hideContextMenu();}
        if(e.key==='Tab'){e.preventDefault();EventBus.emit('tabTarget');}
        if(e.key===' '){e.preventDefault();EventBus.emit('eatFood');}
        if(e.key==='F5'){e.preventDefault();if(typeof saveGame==='function'){saveGame();EventBus.emit('chat',{type:'system',text:'Game saved!'});createLootToast('Game Saved!','💾');}}
        if(e.key==='F9'){e.preventDefault();if(typeof loadGame==='function'&&hasSave()){loadGame();EventBus.emit('chat',{type:'system',text:'Save loaded!'});createLootToast('Save Loaded!','📂');}}
        // Quick slots 1-5 (Feature 5)
        if(e.key>='1'&&e.key<='5'){var qIdx=parseInt(e.key)-1;useQuickSlot(qIdx);}
        // Auto-eat toggle (Feature 3)
        if(e.key==='v'){player.autoEat=!player.autoEat;EventBus.emit('chat',{type:'info',text:'Auto-eat '+(player.autoEat?'ENABLED (below 50% HP)':'DISABLED')});}
        // Auto-retaliate toggle
        if(e.key==='r'){player.autoRetaliate=!player.autoRetaliate;EventBus.emit('chat',{type:'info',text:'Auto-retaliate '+(player.autoRetaliate?'ENABLED':'DISABLED')});}
        // XP tracker reset (Feature 7)
        if(e.key==='x'){player.xpTracker={startTime:0,xpGains:{},active:false};var xpEl=document.getElementById('xp-tracker');if(xpEl)xpEl.style.display='none';EventBus.emit('chat',{type:'info',text:'XP tracker reset.'});}
        // World map (Feature 14)
        if(e.key==='m'){toggleWorldMap();}
        // Quest log
        if(e.key==='q'){var qp=document.getElementById('quest-panel'),qb=document.getElementById('btn-quests');if(qp){var qVis=qp.style.display!=='none';qp.style.display=qVis?'none':'flex';if(qb)qb.classList.toggle('active',!qVis);if(!qVis)renderQuestPanel();}}
    });
    window.addEventListener('keyup',e=>{keys[e.key.toLowerCase()]=false;});
    window.addEventListener('mousedown',e=>{if(e.button===1)e.preventDefault();});
    window.addEventListener('click',e=>{if(!e.target.closest('#context-menu'))hideContextMenu();});

    // ── Mobile Touch Support ──────────────────────────────
    var isMobile='ontouchstart' in window || navigator.maxTouchPoints > 0;
    if(isMobile){
        canvas.style.touchAction='none';
        var touchState={startX:0,startY:0,startTime:0,pinchDist:0,longPressTimer:null,isTap:true,isDragging:false,touches:0,lastX:0,lastY:0};

        canvas.addEventListener('touchstart',function(e){
            e.preventDefault();
            var t=e.touches;
            touchState.touches=t.length;
            if(t.length===1){
                touchState.startX=t[0].clientX;
                touchState.startY=t[0].clientY;
                touchState.lastX=t[0].clientX;
                touchState.lastY=t[0].clientY;
                touchState.startTime=Date.now();
                touchState.isTap=true;
                touchState.isDragging=false;
                // Long press for context menu
                touchState.longPressTimer=setTimeout(function(){
                    touchState.isTap=false;
                    var fake={clientX:touchState.startX,clientY:touchState.startY};
                    var hit=raycastWorld(fake);
                    if(hit) EventBus.emit('rightClick',{hit:hit,screenX:touchState.startX,screenY:touchState.startY});
                },600);
            } else if(t.length===2){
                clearTimeout(touchState.longPressTimer);
                touchState.longPressTimer=null;
                touchState.isTap=false;
                touchState.isDragging=false;
                var dx=t[1].clientX-t[0].clientX,dy=t[1].clientY-t[0].clientY;
                touchState.pinchDist=Math.sqrt(dx*dx+dy*dy);
                touchState.lastX=(t[0].clientX+t[1].clientX)/2;
                touchState.lastY=(t[0].clientY+t[1].clientY)/2;
            }
        },{passive:false});

        canvas.addEventListener('touchmove',function(e){
            e.preventDefault();
            var t=e.touches;
            if(t.length===1){
                var mx=t[0].clientX-touchState.startX,my=t[0].clientY-touchState.startY;
                var moveDist=Math.sqrt(mx*mx+my*my);
                if(moveDist>10){
                    // Cancel tap/long-press, start drag orbit
                    clearTimeout(touchState.longPressTimer);
                    touchState.longPressTimer=null;
                    touchState.isTap=false;
                    touchState.isDragging=true;
                }
                if(touchState.isDragging){
                    // Single-finger drag = orbit camera
                    var dx=t[0].clientX-touchState.lastX;
                    var dy=t[0].clientY-touchState.lastY;
                    cameraState.angle-=dx*cameraState.sensitivity;
                    cameraState.pitch=Math.max(cameraState.minPitch,Math.min(cameraState.maxPitch,cameraState.pitch+dy*cameraState.sensitivity));
                    touchState.lastX=t[0].clientX;
                    touchState.lastY=t[0].clientY;
                }
            }
            if(t.length===2){
                // Pinch zoom
                var dx2=t[1].clientX-t[0].clientX,dy2=t[1].clientY-t[0].clientY;
                var dist=Math.sqrt(dx2*dx2+dy2*dy2);
                var pinchDelta=(touchState.pinchDist-dist)*0.05;
                cameraState.distance=Math.max(cameraState.minDistance,Math.min(cameraState.maxDistance,cameraState.distance+pinchDelta));
                touchState.pinchDist=dist;
                // Two-finger drag to orbit
                var cx=(t[0].clientX+t[1].clientX)/2;
                var cy=(t[0].clientY+t[1].clientY)/2;
                var orbitDx=cx-touchState.lastX,orbitDy=cy-touchState.lastY;
                cameraState.angle-=orbitDx*cameraState.sensitivity;
                cameraState.pitch=Math.max(cameraState.minPitch,Math.min(cameraState.maxPitch,cameraState.pitch+orbitDy*cameraState.sensitivity));
                touchState.lastX=cx;touchState.lastY=cy;
            }
        },{passive:false});

        canvas.addEventListener('touchend',function(e){
            clearTimeout(touchState.longPressTimer);
            touchState.longPressTimer=null;
            if(touchState.isTap&&touchState.touches===1&&!touchState.isDragging&&(Date.now()-touchState.startTime)<300){
                // Single tap = left click (move/attack)
                var fake={clientX:touchState.startX,clientY:touchState.startY};
                hideContextMenu();
                var hit=raycastWorld(fake);
                if(hit) EventBus.emit('leftClick',hit);
            }
            touchState.touches=e.touches.length;
            touchState.isDragging=false;
        },{passive:false});

        // Show mobile eat button
        var eatBtn=document.getElementById('mobile-eat-btn');
        if(eatBtn) eatBtn.style.display='flex';
    }
}

// ========================================
// World Generation
// ========================================
const world = { ground:null, processingStations:[] };

function noise2D(x,z){const n=Math.sin(x*12.9898+z*78.233)*43758.5453;return n-Math.floor(n);}
function smoothNoise(x,z,scale){
    scale=scale||1; x*=scale; z*=scale;
    const ix=Math.floor(x),iz=Math.floor(z),fx=x-ix,fz=z-iz;
    const sx=fx*fx*(3-2*fx),sz=fz*fz*(3-2*fz);
    const a=noise2D(ix,iz),b=noise2D(ix+1,iz),c=noise2D(ix,iz+1),d=noise2D(ix+1,iz+1);
    return a+(b-a)*sx+(c-a)*sz+(a-b-c+d)*sx*sz;
}

const AREAS = {
    'station-hub':{name:'Station Hub',center:{x:0,z:0},radius:35,groundColor:0x1a2030,floorY:0},
    'asteroid-mines':{name:'Asteroid Mines',center:{x:300,z:0},radius:200,groundColor:0x2a1a10,floorY:-2},
    'alien-wastes':{name:'Alien Wastes',center:{x:0,z:-300},radius:700,groundColor:0x0a1a10,floorY:-1},
    'bio-lab':{name:'Bio-Lab',center:{x:-20,z:20},radius:18,groundColor:0x0a2020,floorY:0},
    'the-abyss':{name:'The Abyss',center:{x:0,z:-1200},radius:400,groundColor:0x050510,floorY:-3},
};

const CORRUPTED_AREAS = {
    'corrupted-mines':{name:'Corrupted Mines',base:'asteroid-mines',center:{x:300,z:280},radius:60,groundColor:0x3a0a0a,floorY:-2,fogColor:0x440000},
    'corrupted-wastes':{name:'Corrupted Wastes',base:'alien-wastes',center:{x:560,z:-300},radius:60,groundColor:0x1a0808,floorY:-1,fogColor:0x330000},
    'corrupted-lab':{name:'Corrupted Lab',base:'bio-lab',center:{x:-50,z:40},radius:25,groundColor:0x200a0a,floorY:0,fogColor:0x440000},
};

const AREA_ATMOSPHERE = {
    'station-hub':     {ambientColor:0x1a2a4a,ambientInt:0.6,dirColor:0xaaccff,dirInt:0.8,fogColor:0x020810,fogDensity:0.004,skyTop:0x000510,skyBottom:0x020810},
    'asteroid-mines':  {ambientColor:0x2a1a0a,ambientInt:0.5,dirColor:0xffaa66,dirInt:0.6,fogColor:0x0a0804,fogDensity:0.002,skyTop:0x0a0400,skyBottom:0x0a0804},
    'alien-wastes':    {ambientColor:0x0a2a1a,ambientInt:0.55,dirColor:0x66ffaa,dirInt:0.5,fogColor:0x040a06,fogDensity:0.002,skyTop:0x000a04,skyBottom:0x040a06},
    'bio-lab':         {ambientColor:0x0a2a2a,ambientInt:0.65,dirColor:0x44ddbb,dirInt:0.7,fogColor:0x040808,fogDensity:0.005,skyTop:0x000808,skyBottom:0x040808},
    'corrupted-mines': {ambientColor:0x2a0a0a,ambientInt:0.45,dirColor:0xff6644,dirInt:0.5,fogColor:0x0a0202,fogDensity:0.007,skyTop:0x0a0000,skyBottom:0x0a0202},
    'corrupted-wastes':{ambientColor:0x1a0808,ambientInt:0.4,dirColor:0xff4422,dirInt:0.45,fogColor:0x080202,fogDensity:0.007,skyTop:0x080000,skyBottom:0x080202},
    'corrupted-lab':   {ambientColor:0x200a0a,ambientInt:0.45,dirColor:0xff5544,dirInt:0.5,fogColor:0x0a0404,fogDensity:0.006,skyTop:0x0a0000,skyBottom:0x0a0404},
    'the-abyss':       {ambientColor:0x0a0520,ambientInt:0.3,dirColor:0x4422aa,dirInt:0.3,fogColor:0x020108,fogDensity:0.003,skyTop:0x000005,skyBottom:0x020108},
};
var _targetAtmo=null;
var _atmoColors={ambC:new THREE.Color(),dirC:new THREE.Color(),fogC:new THREE.Color(),skyT:new THREE.Color(),skyB:new THREE.Color()};
function setAreaAtmosphere(areaId){
    _targetAtmo=AREA_ATMOSPHERE[areaId]||AREA_ATMOSPHERE['station-hub'];
    _atmoColors.ambC.set(_targetAtmo.ambientColor);
    _atmoColors.dirC.set(_targetAtmo.dirColor);
    _atmoColors.fogC.set(_targetAtmo.fogColor);
    _atmoColors.skyT.set(_targetAtmo.skyTop);
    _atmoColors.skyB.set(_targetAtmo.skyBottom);
    // Area color grading via CSS filter
    var areaFilters={'station-hub':'saturate(1.05) brightness(1.0)','asteroid-mines':'saturate(1.1) brightness(0.95) sepia(0.05)','alien-wastes':'saturate(1.15) brightness(0.95) hue-rotate(5deg)','bio-lab':'saturate(1.1) brightness(1.0)','corrupted-mines':'saturate(1.2) brightness(0.9) hue-rotate(-5deg)','corrupted-wastes':'saturate(1.15) brightness(0.85)','corrupted-lab':'saturate(1.2) brightness(0.9)','the-abyss':'saturate(0.8) brightness(0.75) hue-rotate(20deg)'};
    var cv=document.getElementById('game-canvas');if(cv)cv.style.filter=areaFilters[areaId]||'';
    // Crossfade music to new area
    crossfadeToArea(areaId);
}
function updateAreaAtmosphere(){
    if(!_targetAtmo||!GameState.ambientLight)return;
    var s=Math.min(2.0*GameState.deltaTime,1);
    GameState.ambientLight.color.lerp(_atmoColors.ambC,s);
    GameState.ambientLight.intensity+=((_targetAtmo.ambientInt)-GameState.ambientLight.intensity)*s;
    GameState.dirLight.color.lerp(_atmoColors.dirC,s);
    GameState.dirLight.intensity+=((_targetAtmo.dirInt)-GameState.dirLight.intensity)*s;
    GameState.scene.fog.color.lerp(_atmoColors.fogC,s);
    GameState.scene.fog.density+=((_targetAtmo.fogDensity)-GameState.scene.fog.density)*s;
    if(GameState.skyDome){
        var su=GameState.skyDome.material.uniforms;
        su.topColor.value.lerp(_atmoColors.skyT,s);
        su.bottomColor.value.lerp(_atmoColors.skyB,s);
    }
}

var corruptedAreaBuilt=false;

const CORRIDORS = [
    {id:'hub-to-mines', from:'station-hub', to:'asteroid-mines',
     minX:33, maxX:102, minZ:-6, maxZ:6, floorY:-1, groundColor:0x1a1a28,
     label:'Asteroid Mines \u2192', labelPos:{x:65,z:0}},
    {id:'hub-to-wastes', from:'station-hub', to:'alien-wastes',
     minX:-6, maxX:6, minZ:-52, maxZ:-33, floorY:-0.5, groundColor:0x0a1518,
     label:'Alien Wastes \u2193', labelPos:{x:0,z:-42}},
    {id:'wastes-to-abyss', from:'alien-wastes', to:'the-abyss',
     minX:-6, maxX:6, minZ:-1010, maxZ:-800, floorY:-2, groundColor:0x0a0818,
     label:'The Abyss \u2193', labelPos:{x:0,z:-900}},
];

var AREA_LEVEL_RANGES = {
    'station-hub':     {min:0, max:0, label:'Safe Zone'},
    'asteroid-mines':  {min:1, max:99, label:'Lv 1-99 Mining'},
    'alien-wastes':    {min:1, max:60, label:'Lv 1-60 Combat'},
    'bio-lab':         {min:1, max:99, label:'Crafting Hub'},
    'the-abyss':       {min:100, max:150, label:'Lv 100+ Combat'},
    'corrupted-mines': {min:80, max:99, label:'Lv 80-99 Prestige'},
    'corrupted-wastes':{min:80, max:99, label:'Lv 80-99 Prestige'},
    'corrupted-lab':   {min:80, max:99, label:'Lv 80-99 Prestige'},
};

function isInCorridor(x, z) {
    for (var ci = 0; ci < CORRIDORS.length; ci++) {
        var c = CORRIDORS[ci];
        if (x >= c.minX && x <= c.maxX && z >= c.minZ && z <= c.maxZ) return c;
    }
    return null;
}

function isValidPosition(x, z) {
    if (DungeonState.active) return isDungeonValidPosition(x, z);
    for (var ai in AREAS) {
        var a = AREAS[ai];
        var dx = x - a.center.x, dz = z - a.center.z;
        if (Math.sqrt(dx * dx + dz * dz) < a.radius) return true;
    }
    if(corruptedAreaBuilt){
        for(var cid in CORRUPTED_AREAS){
            var ca=CORRUPTED_AREAS[cid];
            var cdx=x-ca.center.x;var cdz=z-ca.center.z;
            if(Math.sqrt(cdx*cdx+cdz*cdz)<=ca.radius)return true;
        }
    }
    return isInCorridor(x, z) !== null;
}

const PROCESSING_STATIONS = [
    {id:'bioforge_1',name:'Bioforge Station',skill:'bioforge',position:{x:-20-4,z:20-3},interactRadius:3,icon:'\uD83E\uDDEC'},
    {id:'bioforge_2',name:'Bioforge Station',skill:'bioforge',position:{x:-20+4,z:20-3},interactRadius:3,icon:'\uD83E\uDDEC'},
    {id:'xenocook_1',name:'Xenocook Range',skill:'xenocook',position:{x:-20-4,z:20-5},interactRadius:3,icon:'\uD83C\uDF73'},
    {id:'xenocook_2',name:'Xenocook Range',skill:'xenocook',position:{x:-20+4,z:20-5},interactRadius:3,icon:'\uD83C\uDF73'},
    {id:'smelter_1',name:'Smelting Furnace',skill:'circuitry',position:{x:-20,z:20+5},interactRadius:3,icon:'\uD83D\uDD27'},
    {id:'repair_1',name:'Repair Station',skill:'repair',position:{x:-20+6,z:20+5},interactRadius:3,icon:'\uD83D\uDD28'},
];

function getAreaAtPosition(x, z) {
    if (DungeonState.active) return 'dungeon';
    for (var aid in AREAS) {
        var a = AREAS[aid];
        var dx = x - a.center.x, dz = z - a.center.z;
        if (Math.sqrt(dx * dx + dz * dz) < a.radius) return aid;
    }
    if(corruptedAreaBuilt){
        for(var cid in CORRUPTED_AREAS){
            var ca=CORRUPTED_AREAS[cid];
            var cdx=x-ca.center.x;var cdz=z-ca.center.z;
            if(Math.sqrt(cdx*cdx+cdz*cdz)<=ca.radius)return cid;
        }
    }
    var corr = isInCorridor(x, z);
    if (corr) {
        var fromA = AREAS[corr.from], toA = AREAS[corr.to];
        var dFrom = Math.sqrt(Math.pow(x - fromA.center.x, 2) + Math.pow(z - fromA.center.z, 2));
        var dTo = Math.sqrt(Math.pow(x - toA.center.x, 2) + Math.pow(z - toA.center.z, 2));
        return dTo < dFrom ? corr.to : corr.from;
    }
    return null;
}


function buildGround(){
    const size=1800,seg=300,geo=new THREE.PlaneGeometry(size,size,seg,seg);
    geo.rotateX(-Math.PI/2);
    const pos=geo.attributes.position,colors=new Float32Array(pos.count*3);
    for(let i=0;i<pos.count;i++){
        const x=pos.getX(i),z=pos.getZ(i);let y=0;const color=new THREE.Color(0x0a0f18);
        let inArea=false;
        for(const[areaId,area]of Object.entries(AREAS)){
            const dx=x-area.center.x,dz=z-area.center.z,dist=Math.sqrt(dx*dx+dz*dz);
            if(dist<area.radius){inArea=true;const ef=Math.max(0,1-dist/area.radius);
                if(areaId==='station-hub'){y=area.floorY;color.setHex(area.groundColor);color.multiplyScalar(0.8+ef*0.4);}
                else if(areaId==='asteroid-mines'){y=area.floorY+smoothNoise(x,z,0.08)*3;color.setHex(area.groundColor);color.multiplyScalar(0.6+smoothNoise(x,z,0.15)*0.6);}
                else if(areaId==='alien-wastes'){y=area.floorY+Math.sin(x*0.1)*Math.cos(z*0.1)*2;color.set(0.04+smoothNoise(x,z,0.1)*0.06,0.1+smoothNoise(x+100,z,0.1)*0.08,0.04);}
                else if(areaId==='bio-lab'){y=area.floorY;color.setHex(area.groundColor);color.multiplyScalar(0.7+ef*0.3);}
                else if(areaId==='the-abyss'){y=area.floorY+smoothNoise(x,z,0.06)*2-1;color.set(0.02+smoothNoise(x,z,0.08)*0.03,0.01+smoothNoise(x+50,z,0.12)*0.02,0.06+smoothNoise(x,z+50,0.1)*0.04);}
                break;
            }
        }
        if(!inArea){
            var corr=isInCorridor(x,z);
            if(corr){y=corr.floorY;color.setHex(corr.groundColor);color.multiplyScalar(0.7+smoothNoise(x,z,0.1)*0.3);}
            else{y=-5+smoothNoise(x,z,0.03)*2;color.set(0.02,0.03,0.05);}
        }
        pos.setY(i,y);colors[i*3]=color.r;colors[i*3+1]=color.g;colors[i*3+2]=color.b;
    }
    geo.setAttribute('color',new THREE.BufferAttribute(colors,3));geo.computeVertexNormals();
    const mat=new THREE.MeshLambertMaterial({vertexColors:true,side:THREE.DoubleSide});
    const ground=new THREE.Mesh(geo,mat);ground.receiveShadow=true;ground.userData.isGround=true;
    GameState.scene.add(ground);world.ground=ground;
}

function buildStarfield(){
    const ct=4000,geo=new THREE.BufferGeometry(),p=new Float32Array(ct*3),c=new Float32Array(ct*3),sz=new Float32Array(ct);
    // Star color palette: blue-white, yellow-white, white, faint red
    var starColors=[[0.7,0.8,1],[1,0.95,0.8],[1,1,1],[1,0.7,0.6],[0.6,0.9,1],[1,0.85,0.7]];
    for(let i=0;i<ct;i++){
        const th=Math.random()*Math.PI*2,ph=Math.acos(2*Math.random()-1),r=380+Math.random()*80;
        p[i*3]=r*Math.sin(ph)*Math.cos(th);p[i*3+1]=r*Math.sin(ph)*Math.sin(th);p[i*3+2]=r*Math.cos(ph);
        var sc=starColors[Math.floor(Math.random()*starColors.length)];
        var br=0.3+Math.random()*0.7;
        c[i*3]=sc[0]*br;c[i*3+1]=sc[1]*br;c[i*3+2]=sc[2]*br;
        sz[i]=0.8+Math.random()*2.0;
    }
    geo.setAttribute('position',new THREE.BufferAttribute(p,3));geo.setAttribute('color',new THREE.BufferAttribute(c,3));
    geo.setAttribute('size',new THREE.BufferAttribute(sz,1));
    // Main stars layer
    GameState.scene.add(new THREE.Points(geo,new THREE.PointsMaterial({size:1.5,vertexColors:true,sizeAttenuation:false,transparent:true,opacity:0.9})));
    // Bright star clusters — sparse, bigger points for depth
    var ct2=200,geo2=new THREE.BufferGeometry(),p2=new Float32Array(ct2*3),c2=new Float32Array(ct2*3);
    for(let i=0;i<ct2;i++){
        var th2=Math.random()*Math.PI*2,ph2=Math.acos(2*Math.random()-1),r2=350+Math.random()*60;
        p2[i*3]=r2*Math.sin(ph2)*Math.cos(th2);p2[i*3+1]=r2*Math.sin(ph2)*Math.sin(th2);p2[i*3+2]=r2*Math.cos(ph2);
        var bright=0.8+Math.random()*0.2;
        c2[i*3]=bright;c2[i*3+1]=bright;c2[i*3+2]=bright*1.1;
    }
    geo2.setAttribute('position',new THREE.BufferAttribute(p2,3));geo2.setAttribute('color',new THREE.BufferAttribute(c2,3));
    GameState.scene.add(new THREE.Points(geo2,new THREE.PointsMaterial({size:3,vertexColors:true,sizeAttenuation:false,transparent:true,opacity:0.6})));
}

function buildSkyDome(){
    var skyGeo=new THREE.SphereGeometry(380,32,16);
    var skyMat=new THREE.ShaderMaterial({
        uniforms:{
            topColor:{value:new THREE.Color(0x000510)},
            bottomColor:{value:new THREE.Color(0x020810)},
            offset:{value:20},
            exponent:{value:0.6}
        },
        vertexShader:'varying vec3 vWorldPosition;void main(){vec4 wp=modelMatrix*vec4(position,1.0);vWorldPosition=wp.xyz;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',
        fragmentShader:'uniform vec3 topColor;uniform vec3 bottomColor;uniform float offset;uniform float exponent;varying vec3 vWorldPosition;void main(){float h=normalize(vWorldPosition+offset).y;gl_FragColor=vec4(mix(bottomColor,topColor,max(pow(max(h,0.0),exponent),0.0)),1.0);}',
        side:THREE.BackSide,
        depthWrite:false
    });
    var skyMesh=new THREE.Mesh(skyGeo,skyMat);
    skyMesh.renderOrder=-1;
    GameState.scene.add(skyMesh);
    GameState.skyDome=skyMesh;
}

function buildStationHub(){
    const cx=0,cz=0;
    const plat=new THREE.Mesh(new THREE.CylinderGeometry(12,14,0.5,8),new THREE.MeshLambertMaterial({color:0x2a3848}));
    plat.position.set(cx,0.25,cz);plat.receiveShadow=true;GameState.scene.add(plat);
    for(let i=0;i<6;i++){
        const a=(i/6)*Math.PI*2,px=cx+Math.cos(a)*15,pz=cz+Math.sin(a)*15;
        const pil=new THREE.Mesh(new THREE.CylinderGeometry(0.5,0.6,8,6),new THREE.MeshLambertMaterial({color:0x3a4a5a}));
        pil.position.set(px,4,pz);pil.castShadow=true;GameState.scene.add(pil);
        const ls=new THREE.Mesh(new THREE.SphereGeometry(0.3,8,8),new THREE.MeshBasicMaterial({color:0x00c8ff}));
        ls.position.set(px,8.2,pz);GameState.scene.add(ls);
        const pl=new THREE.PointLight(0x00c8ff,0.2,15);pl.position.set(px,8,pz);GameState.scene.add(pl);
    }
    [{x:cx+10,z:cz-10,c:0x4a3a2a},{x:cx-10,z:cz-10,c:0x2a4a3a},{x:cx-10,z:cz+10,c:0x2a3a4a}].forEach(sp=>{
        const ct=new THREE.Mesh(new THREE.BoxGeometry(4,1.2,2),new THREE.MeshLambertMaterial({color:sp.c}));
        ct.position.set(sp.x,0.6,sp.z);ct.castShadow=true;GameState.scene.add(ct);
        const aw=new THREE.Mesh(new THREE.BoxGeometry(5,0.1,3),new THREE.MeshLambertMaterial({color:0x1a2a3a,transparent:true,opacity:0.7}));
        aw.position.set(sp.x,3,sp.z);GameState.scene.add(aw);
    });
    const bank=new THREE.Mesh(new THREE.BoxGeometry(3,4,3),new THREE.MeshLambertMaterial({color:0x1a3050}));
    bank.position.set(cx+10,2,cz+10);bank.castShadow=true;GameState.scene.add(bank);
    const bs=new THREE.Mesh(new THREE.PlaneGeometry(2,2),new THREE.MeshBasicMaterial({color:0x00ff88}));
    bs.position.set(cx+8.49,2.5,cz+10);bs.rotation.y=-Math.PI/2;GameState.scene.add(bs);
    // Quest Board
    const boardGroup=new THREE.Group();
    const boardBack=new THREE.Mesh(new THREE.BoxGeometry(2,3,0.2),new THREE.MeshLambertMaterial({color:0x3a2a1a}));
    boardBack.position.y=2;boardGroup.add(boardBack);
    for(let i=0;i<6;i++){
        const nx=-0.6+((i%3)*0.6),ny=1.3+Math.floor(i/3)*0.9;
        const note=new THREE.Mesh(new THREE.PlaneGeometry(0.4,0.5),new THREE.MeshLambertMaterial({color:[0xffffcc,0xccffcc,0xffcccc,0xccccff,0xffeecc,0xeeccff][i]}));
        note.position.set(nx,ny,0.11);boardGroup.add(note);
    }
    boardGroup.position.set(0,0,18);
    boardGroup.userData.entityType='questBoard';
    boardGroup.userData.entity={name:'Quest Board',type:'questBoard'};
    GameState.scene.add(boardGroup);
    world.questBoard=boardGroup;
    const boardCanvas=document.createElement('canvas');boardCanvas.width=256;boardCanvas.height=64;
    const bCtx=boardCanvas.getContext('2d');bCtx.fillStyle='#ffcc44';bCtx.font='bold 28px monospace';bCtx.textAlign='center';bCtx.fillText('Quest Board',128,40);
    const boardTex=new THREE.CanvasTexture(boardCanvas);
    const boardLabel=new THREE.Sprite(new THREE.SpriteMaterial({map:boardTex,transparent:true}));
    boardLabel.position.set(0,4.2,18);boardLabel.scale.set(3,0.75,1);
    GameState.scene.add(boardLabel);
    // Dungeon Entrance Portal — "Abyssal Depths"
    var portalGroup = new THREE.Group();
    var pillarMat = new THREE.MeshLambertMaterial({color:0x3a1a4a, emissive:0x1a0a2a, emissiveIntensity:0.3});
    var pillar1 = new THREE.Mesh(new THREE.BoxGeometry(0.6, 5, 0.6), pillarMat);
    pillar1.position.set(-1.5, 2.5, 0); portalGroup.add(pillar1);
    var pillar2 = new THREE.Mesh(new THREE.BoxGeometry(0.6, 5, 0.6), pillarMat);
    pillar2.position.set(1.5, 2.5, 0); portalGroup.add(pillar2);
    var topBar = new THREE.Mesh(new THREE.BoxGeometry(3.6, 0.5, 0.6), pillarMat);
    topBar.position.set(0, 5.25, 0); portalGroup.add(topBar);
    var portalPlane = new THREE.Mesh(
        new THREE.PlaneGeometry(2.4, 4.5),
        new THREE.MeshBasicMaterial({color:0x8844ff, transparent:true, opacity:0.5, side:THREE.DoubleSide})
    );
    portalPlane.position.set(0, 2.5, 0); portalGroup.add(portalPlane);
    world.dungeonPortalPlane=portalPlane;
    var portalLight = new THREE.PointLight(0x8844ff, 0.6, 12);
    portalLight.position.set(0, 3, 1); portalGroup.add(portalLight);
    portalGroup.position.set(0, 0, -18);
    portalGroup.userData.entityType = 'dungeonEntrance';
    GameState.scene.add(portalGroup);
    world.dungeonEntrance = portalGroup;
    // Dungeon portal label
    var dLabelCanvas=document.createElement('canvas');dLabelCanvas.width=256;dLabelCanvas.height=64;
    var dCtx=dLabelCanvas.getContext('2d');dCtx.fillStyle='#aa44ff';dCtx.font='bold 24px monospace';dCtx.textAlign='center';dCtx.fillText('Abyssal Depths',128,40);
    var dLabelTex=new THREE.CanvasTexture(dLabelCanvas);
    var dLabel=new THREE.Sprite(new THREE.SpriteMaterial({map:dLabelTex,transparent:true}));
    dLabel.position.set(0,6.5,-18);dLabel.scale.set(3,0.75,1);
    GameState.scene.add(dLabel);
}

function buildAsteroidMines(){
    const cx=300,cz=0,rad=200;
    // Floating asteroids scattered throughout the expanded mines
    for(let i=0;i<60;i++){
        const a=Math.random()*Math.PI*2,dist=5+Math.random()*(rad-15),sz=1+Math.random()*4;
        const ast=new THREE.Mesh(new THREE.DodecahedronGeometry(sz,0),new THREE.MeshLambertMaterial({color:0x4a3a2a+Math.floor(Math.random()*0x101010)}));
        ast.position.set(cx+Math.cos(a)*dist,2+Math.random()*8,cz+Math.sin(a)*dist);ast.rotation.set(Math.random()*Math.PI,Math.random()*Math.PI,0);ast.castShadow=true;GameState.scene.add(ast);
    }
    // Crystal formations scattered across the mines
    for(let i=0;i<40;i++){
        const a=Math.random()*Math.PI*2,dist=5+Math.random()*(rad-20);
        const cc=[0x44aaff,0xaa44ff,0x44ffaa,0xff44aa][Math.floor(Math.random()*4)];
        const cr=new THREE.Mesh(new THREE.ConeGeometry(0.4+Math.random()*0.5,1.5+Math.random()*2.5,5),new THREE.MeshLambertMaterial({color:cc,emissive:cc,emissiveIntensity:0.3}));
        cr.position.set(cx+Math.cos(a)*dist,0.8,cz+Math.sin(a)*dist);cr.castShadow=true;GameState.scene.add(cr);
    }
    // Dim ambient lights to illuminate the larger space
    for(let i=0;i<6;i++){
        const a=(i/6)*Math.PI*2,dist=rad*0.5;
        const al=new THREE.PointLight(0xffaa66,0.15,80);
        al.position.set(cx+Math.cos(a)*dist,8,cz+Math.sin(a)*dist);GameState.scene.add(al);
    }
}

function buildAlienWastes(){
    const cx=0,cz=-300,rad=250;
    // Bioluminescent alien plants scattered across the vast wastes
    for(let i=0;i<120;i++){
        const a=Math.random()*Math.PI*2,dist=3+Math.random()*(rad-15);
        const px=cx+Math.cos(a)*dist,pz=cz+Math.sin(a)*dist;
        const pc=Math.random()>0.5?0x22ff66:0x8844ff;
        const st=new THREE.Mesh(new THREE.CylinderGeometry(0.05,0.1,1+Math.random()*2.5,4),new THREE.MeshLambertMaterial({color:0x1a3a1a}));
        st.position.set(px,0.8,pz);GameState.scene.add(st);
        const bulb=new THREE.Mesh(new THREE.SphereGeometry(0.2+Math.random()*0.3,6,6),new THREE.MeshBasicMaterial({color:pc}));
        bulb.position.set(px,1.5+Math.random(),pz);GameState.scene.add(bulb);
        if(i<25){const gl=new THREE.PointLight(pc,0.12,10);gl.position.copy(bulb.position);GameState.scene.add(gl);}
    }
    // Alien bone arches / ribs
    for(let i=0;i<25;i++){
        const a=Math.random()*Math.PI*2,dist=8+Math.random()*(rad-20);
        const rib=new THREE.Mesh(new THREE.TorusGeometry(2+Math.random()*2,0.15,4,8,Math.PI),new THREE.MeshLambertMaterial({color:0x8a8a7a}));
        rib.position.set(cx+Math.cos(a)*dist,2,cz+Math.sin(a)*dist);rib.rotation.y=Math.random()*Math.PI;GameState.scene.add(rib);
    }
    // Toxic pools
    for(let i=0;i<20;i++){
        const a=Math.random()*Math.PI*2,dist=10+Math.random()*(rad-25);
        const pool=new THREE.Mesh(new THREE.CircleGeometry(1.5+Math.random()*3,8),new THREE.MeshBasicMaterial({color:0x22aa44,transparent:true,opacity:0.6}));
        pool.rotation.x=-Math.PI/2;pool.position.set(cx+Math.cos(a)*dist,0.05,cz+Math.sin(a)*dist);GameState.scene.add(pool);
    }
    // Ambient area lights for the larger space
    for(let i=0;i<8;i++){
        const a=(i/8)*Math.PI*2,dist=rad*0.5;
        const al=new THREE.PointLight(0x22ff66,0.1,80);
        al.position.set(cx+Math.cos(a)*dist,6,cz+Math.sin(a)*dist);GameState.scene.add(al);
    }
}

function buildTheAbyss(){
    var cx=0,cz=-650,rad=200;
    // Void crystals — tall dark spikes
    for(var i=0;i<60;i++){
        var a=Math.random()*Math.PI*2,dist=5+Math.random()*(rad-20);
        var px=cx+Math.cos(a)*dist,pz=cz+Math.sin(a)*dist;
        var h=2+Math.random()*5;
        var crystal=new THREE.Mesh(new THREE.ConeGeometry(0.3+Math.random()*0.4,h,5),new THREE.MeshLambertMaterial({color:0x1a0a3a,emissive:0x0a0520,emissiveIntensity:0.3}));
        crystal.position.set(px,h/2-2,pz);crystal.rotation.z=(Math.random()-0.5)*0.3;GameState.scene.add(crystal);
    }
    // Abyssal vents — glowing fissures
    for(var i=0;i<20;i++){
        var a=Math.random()*Math.PI*2,dist=10+Math.random()*(rad-30);
        var px=cx+Math.cos(a)*dist,pz=cz+Math.sin(a)*dist;
        var vent=new THREE.Mesh(new THREE.CircleGeometry(1+Math.random()*2,6),new THREE.MeshBasicMaterial({color:0x4422aa,transparent:true,opacity:0.5}));
        vent.rotation.x=-Math.PI/2;vent.position.set(px,-2.5,pz);GameState.scene.add(vent);
        if(i<8){var gl=new THREE.PointLight(0x4422aa,0.15,12);gl.position.set(px,-1,pz);GameState.scene.add(gl);}
    }
    // Reality tears — vertical semi-transparent planes
    for(var i=0;i<15;i++){
        var a=Math.random()*Math.PI*2,dist=15+Math.random()*(rad-30);
        var px=cx+Math.cos(a)*dist,pz=cz+Math.sin(a)*dist;
        var tear=new THREE.Mesh(new THREE.PlaneGeometry(0.5+Math.random()*1.5,3+Math.random()*4),new THREE.MeshBasicMaterial({color:0xaa44ff,transparent:true,opacity:0.15+Math.random()*0.15,side:THREE.DoubleSide}));
        tear.position.set(px,1,pz);tear.rotation.y=Math.random()*Math.PI;GameState.scene.add(tear);
    }
    // Ruined pillars
    for(var i=0;i<15;i++){
        var a=Math.random()*Math.PI*2,dist=10+Math.random()*(rad-25);
        var px=cx+Math.cos(a)*dist,pz=cz+Math.sin(a)*dist;
        var h=3+Math.random()*4;
        var pillar=new THREE.Mesh(new THREE.CylinderGeometry(0.5,0.7,h,6),new THREE.MeshLambertMaterial({color:0x0a0818}));
        pillar.position.set(px,h/2-3,pz);GameState.scene.add(pillar);
    }
    // Dim ambient lights
    for(var i=0;i<6;i++){
        var a=(i/6)*Math.PI*2,dist=rad*0.5;
        var al=new THREE.PointLight(0x4422aa,0.08,60);
        al.position.set(cx+Math.cos(a)*dist,4,cz+Math.sin(a)*dist);GameState.scene.add(al);
    }
}

function buildBioLab(){
    const cx=-20,cz=20;
    const walls=new THREE.Mesh(new THREE.BoxGeometry(16,4,16),new THREE.MeshLambertMaterial({color:0x1a2a2a,transparent:true,opacity:0.25}));
    walls.position.set(cx,2,cz);GameState.scene.add(walls);
    const fl=new THREE.Mesh(new THREE.PlaneGeometry(16,16),new THREE.MeshLambertMaterial({color:0x1a3030}));
    fl.rotation.x=-Math.PI/2;fl.position.set(cx,0.05,cz);GameState.scene.add(fl);
    for(let i=0;i<4;i++){
        const bx=cx-4+(i%2)*8,bz=cz-3+Math.floor(i/2)*6;
        const bench=new THREE.Mesh(new THREE.BoxGeometry(2.5,0.9,1.2),new THREE.MeshLambertMaterial({color:0x3a5050}));
        bench.position.set(bx,0.45,bz);bench.castShadow=true;
        if(i<2){const sid='bioforge_'+(i+1);const st=PROCESSING_STATIONS.find(s=>s.id===sid);if(st){bench.userData.entityType='processingStation';bench.userData.entity=st;world.processingStations.push(bench);}}
        GameState.scene.add(bench);
    }
    for(let i=0;i<2;i++){
        const px=cx+(i===0?-3:3),pz=cz+5;
        const pod=new THREE.Mesh(new THREE.CylinderGeometry(0.7,0.7,2.5,8),new THREE.MeshLambertMaterial({color:0x22aa88,transparent:true,opacity:0.3,emissive:0x11aa66,emissiveIntensity:0.2}));
        pod.position.set(px,1.25,pz);GameState.scene.add(pod);
        const podL=new THREE.PointLight(0x22aa88,0.15,5);podL.position.set(px,1.8,pz);GameState.scene.add(podL);
    }
    for(let i=0;i<2;i++){
        const sx=cx+(i===0?-4:4),sz=cz-5;
        const stove=new THREE.Mesh(new THREE.BoxGeometry(1.8,1,1.8),new THREE.MeshLambertMaterial({color:0x4a3a2a}));
        stove.position.set(sx,0.5,sz);
        const stid='xenocook_'+(i+1);const stData=PROCESSING_STATIONS.find(s=>s.id===stid);if(stData){stove.userData.entityType='processingStation';stove.userData.entity=stData;world.processingStations.push(stove);}
        GameState.scene.add(stove);
        const flame=new THREE.Mesh(new THREE.ConeGeometry(0.25,0.5,4),new THREE.MeshBasicMaterial({color:0xff6622}));
        flame.position.set(sx,1.3,sz);GameState.scene.add(flame);
    }
    // Smelting furnace
    const furnace=new THREE.Mesh(new THREE.CylinderGeometry(1,1.2,2.5,8),new THREE.MeshLambertMaterial({color:0x5a3a1a,emissive:0x331100,emissiveIntensity:0.3}));
    furnace.position.set(cx,1.25,cz+5);furnace.castShadow=true;
    furnace.userData.entityType='processingStation';furnace.userData.entity=PROCESSING_STATIONS.find(s=>s.id==='smelter_1');
    GameState.scene.add(furnace);world.processingStations.push(furnace);
    const furnaceGlow=new THREE.Mesh(new THREE.CylinderGeometry(0.5,0.5,0.2,8),new THREE.MeshBasicMaterial({color:0xff4400,transparent:true,opacity:0.6}));
    furnaceGlow.position.set(cx,2.6,cz+5);GameState.scene.add(furnaceGlow);
    const furnaceLight=new THREE.PointLight(0xff4400,0.3,6);furnaceLight.position.set(cx,3,cz+5);GameState.scene.add(furnaceLight);
    // Repair station (anvil/bench shape)
    var repairStDef=PROCESSING_STATIONS.find(function(s){return s.id==='repair_1';});
    if(repairStDef){
        var anvil=new THREE.Mesh(new THREE.BoxGeometry(2,0.8,1.5),new THREE.MeshLambertMaterial({color:0x5a5a6a}));
        anvil.position.set(repairStDef.position.x,0.4,repairStDef.position.z);anvil.castShadow=true;
        anvil.userData.entityType='processingStation';anvil.userData.entity=repairStDef;
        GameState.scene.add(anvil);world.processingStations.push(anvil);
        var anvilTop=new THREE.Mesh(new THREE.BoxGeometry(2.2,0.2,1.7),new THREE.MeshLambertMaterial({color:0x7a7a8a}));
        anvilTop.position.set(repairStDef.position.x,0.9,repairStDef.position.z);GameState.scene.add(anvilTop);
        var hammerMesh=new THREE.Mesh(new THREE.BoxGeometry(0.15,0.6,0.15),new THREE.MeshLambertMaterial({color:0x8a6a3a}));
        hammerMesh.position.set(repairStDef.position.x+0.5,1.3,repairStDef.position.z);hammerMesh.rotation.z=0.3;GameState.scene.add(hammerMesh);
        var repairLight=new THREE.PointLight(0xffaa44,0.2,6);repairLight.position.set(repairStDef.position.x,2,repairStDef.position.z);GameState.scene.add(repairLight);
    }
    // Clickable markers for all processing stations (large invisible hitboxes + visible ground rings)
    PROCESSING_STATIONS.forEach(function(station){
        // Large invisible hitbox matching station size
        const hitbox=new THREE.Mesh(new THREE.BoxGeometry(3,3,3),new THREE.MeshBasicMaterial({visible:false}));
        hitbox.position.set(station.position.x,1.5,station.position.z);
        hitbox.userData.entityType='processingStation';
        hitbox.userData.entity=station;
        GameState.scene.add(hitbox);
        world.processingStations.push(hitbox);
        // Visible ground ring indicator
        const ring=new THREE.Mesh(new THREE.RingGeometry(1.2,1.5,16),new THREE.MeshBasicMaterial({color:0x00c8ff,transparent:true,opacity:0.35,side:THREE.DoubleSide}));
        ring.rotation.x=-Math.PI/2;ring.position.set(station.position.x,0.06,station.position.z);
        GameState.scene.add(ring);
    });
}


function buildCorridors(){
    CORRIDORS.forEach(function(corr){
        // Signpost at corridor entrance (near the hub side)
        var signGroup=new THREE.Group();
        var post=new THREE.Mesh(new THREE.CylinderGeometry(0.1,0.1,3,6),new THREE.MeshLambertMaterial({color:0x5a5a5a}));
        post.position.y=1.5;signGroup.add(post);
        var board=new THREE.Mesh(new THREE.BoxGeometry(2.5,0.8,0.1),new THREE.MeshLambertMaterial({color:0x3a2a1a}));
        board.position.y=2.8;signGroup.add(board);
        var label=createTextSprite(corr.label,'#ffcc44');
        label.position.set(0,4.2,0);label.scale.set(5,1.2,1);signGroup.add(label);
        signGroup.position.set(corr.labelPos.x,0,corr.labelPos.z);
        GameState.scene.add(signGroup);

        // Guide lights along corridor
        var isHoriz=(corr.maxX-corr.minX)>(corr.maxZ-corr.minZ);
        var midX=(corr.minX+corr.maxX)/2,midZ=(corr.minZ+corr.maxZ)/2;
        for(var li=0;li<=3;li++){
            var t=li/3;
            var lx,lz;
            if(isHoriz){lx=corr.minX+(corr.maxX-corr.minX)*t;lz=midZ;}
            else{lx=midX;lz=corr.minZ+(corr.maxZ-corr.minZ)*t;}
            // Left side lamp
            var lamp1=new THREE.Mesh(new THREE.SphereGeometry(0.12,6,6),new THREE.MeshBasicMaterial({color:0x44aaff}));
            lamp1.position.set(lx+(isHoriz?0:-4),0.8,lz+(isHoriz?-4:0));GameState.scene.add(lamp1);
            // Right side lamp
            var lamp2=new THREE.Mesh(new THREE.SphereGeometry(0.12,6,6),new THREE.MeshBasicMaterial({color:0x44aaff}));
            lamp2.position.set(lx+(isHoriz?0:4),0.8,lz+(isHoriz?4:0));GameState.scene.add(lamp2);
            // Light
            if(li%2===0){
                var pl=new THREE.PointLight(0x2266aa,0.15,10);
                pl.position.set(lx,1.5,lz);GameState.scene.add(pl);
            }
        }

        // Low walls/rails along corridor edges
        var wallMat=new THREE.MeshLambertMaterial({color:0x2a3a4a,transparent:true,opacity:0.6});
        if(isHoriz){
            var wallLen=corr.maxX-corr.minX;
            var wall1=new THREE.Mesh(new THREE.BoxGeometry(wallLen,0.6,0.2),wallMat);
            wall1.position.set(midX,0.3,corr.minZ-0.1);GameState.scene.add(wall1);
            var wall2=new THREE.Mesh(new THREE.BoxGeometry(wallLen,0.6,0.2),wallMat);
            wall2.position.set(midX,0.3,corr.maxZ+0.1);GameState.scene.add(wall2);
        }else{
            var wallLen=corr.maxZ-corr.minZ;
            var wall1=new THREE.Mesh(new THREE.BoxGeometry(0.2,0.6,wallLen),wallMat);
            wall1.position.set(corr.minX-0.1,0.3,midZ);GameState.scene.add(wall1);
            var wall2=new THREE.Mesh(new THREE.BoxGeometry(0.2,0.6,wallLen),wallMat);
            wall2.position.set(corr.maxX+0.1,0.3,midZ);GameState.scene.add(wall2);
        }
    });
}

function buildResourceNodes(){
    // Ore zones: each ore type clusters in a specific region of the expanded asteroid mines
    // Arranged by tier — lower tiers near entrance (west), higher tiers deeper (east/north/south)
    var minesCx=300,minesCz=0;
    var oreZones=[
        {resource:'stellarite_ore',level:1,xp:10,color:0x888888,cx:minesCx-120,cz:minesCz,spread:15},
        {resource:'ferrite_ore',level:10,xp:20,color:0x44cc66,cx:minesCx-80,cz:minesCz-60,spread:15},
        {resource:'cobaltium_ore',level:20,xp:35,color:0x4488ff,cx:minesCx-80,cz:minesCz+60,spread:15},
        {resource:'duranite_ore',level:30,xp:55,color:0x66aacc,cx:minesCx-20,cz:minesCz-100,spread:18},
        {resource:'titanex_ore',level:40,xp:80,color:0x88cc44,cx:minesCx-20,cz:minesCz+100,spread:18},
        {resource:'plasmite_ore',level:50,xp:110,color:0xaa44ff,cx:minesCx+40,cz:minesCz-60,spread:18},
        {resource:'quantite_ore',level:60,xp:150,color:0xff8844,cx:minesCx+40,cz:minesCz+60,spread:18},
        {resource:'neutronium_ore',level:70,xp:200,color:0xff4488,cx:minesCx+100,cz:minesCz-40,spread:20},
        {resource:'darkmatter_shard',level:80,xp:260,color:0xcc44ff,cx:minesCx+100,cz:minesCz+40,spread:20},
        {resource:'voidsteel_ore',level:90,xp:340,color:0xff8800,cx:minesCx+160,cz:minesCz,spread:20},
    ];
    // Each ore spawns 10 nodes tightly clustered in its zone
    oreZones.forEach(function(zone){
        var count=10;
        for(var i=0;i<count;i++){
            var a=Math.random()*Math.PI*2,dist=2+Math.random()*zone.spread;
            var nx=zone.cx+Math.cos(a)*dist,nz=zone.cz+Math.sin(a)*dist;
            buildOreNode({area:'asteroid-mines',type:'astromining',resource:zone.resource,level:zone.level,xp:zone.xp,color:zone.color},nx,nz);
        }
    });
    // Gathering/bio nodes in alien wastes (unchanged)
    var gatherDefs=[
        {area:'alien-wastes',type:'gathering',resource:'space_lichen',level:1,xp:5,count:6,color:0x44aa44,shape:'bush'},
        {area:'alien-wastes',type:'gathering',resource:'nebula_fruit',level:10,xp:15,count:4,color:0x8844ff,shape:'bush'},
        {area:'alien-wastes',type:'gathering',resource:'alien_steak',level:25,xp:30,count:3,color:0xff4444,shape:'bush'},
        {area:'alien-wastes',type:'gathering',resource:'chitin_shard',level:1,xp:8,count:4,color:0xaa8844,shape:'deposit'},
    ];
    gatherDefs.forEach(function(def){
        var area=AREAS[def.area];
        for(var i=0;i<def.count;i++){
            var a=Math.random()*Math.PI*2,dist=5+Math.random()*(area.radius-10);
            var nx=area.center.x+Math.cos(a)*dist,nz=area.center.z+Math.sin(a)*dist;
            buildGatherNode(def,nx,nz);
        }
    });
}

function buildGatherNode(def,nx,nz){
    var mesh;
    if(def.shape==='bush'){
        mesh=new THREE.Group();
        var b=new THREE.Mesh(new THREE.SphereGeometry(0.8,6,6),new THREE.MeshLambertMaterial({color:def.color,emissive:def.color,emissiveIntensity:0.15}));
        b.position.y=0.8;mesh.add(b);
        var s=new THREE.Mesh(new THREE.CylinderGeometry(0.1,0.15,0.8,4),new THREE.MeshLambertMaterial({color:0x2a4a2a}));
        s.position.y=0.3;mesh.add(s);
    } else if(def.shape==='deposit'){
        mesh=new THREE.Group();
        var r=new THREE.Mesh(new THREE.DodecahedronGeometry(0.6,0),new THREE.MeshLambertMaterial({color:def.color}));
        r.position.y=0.4;mesh.add(r);
    }
    mesh.position.set(nx,0,nz);mesh.castShadow=true;
    var nodeData={mesh:mesh,type:def.type,resource:def.resource,level:def.level,xp:def.xp,depleted:false,respawnTimer:0,respawnTime:15+Math.random()*15,position:new THREE.Vector3(nx,0,nz)};
    mesh.userData.entityType='resource';mesh.userData.entity=nodeData;
    GameState.scene.add(mesh);GameState.resourceNodes.push(nodeData);
}

function buildOreNode(def,nx,nz){
    var mesh=new THREE.Group();
    // Rock base varies by ore tier (scales across 10 ore tiers)
    var rockSize=def.level>=70?1.7:def.level>=50?1.5:def.level>=30?1.4:def.level>=10?1.3:1.1;
    var rockDetail=def.level>=30?1:0;
    var rockColor=def.level>=70?0x2a1525:def.level>=50?0x4a3020:def.level>=30?0x2a2035:def.level>=10?0x253545:0x3a3025;
    var r=new THREE.Mesh(new THREE.DodecahedronGeometry(rockSize,rockDetail),new THREE.MeshLambertMaterial({color:rockColor}));
    r.position.y=rockSize*0.8;mesh.add(r);
    // Crystal veins - more and bigger for higher tier ores
    var crystalCount=Math.min(7,1+Math.floor(def.level/15));
    var crystalSize=0.3+def.level*0.003;
    var emissiveStr=0.2+def.level*0.006;
    for(var ci=0;ci<crystalCount;ci++){
        var cAngle=(ci/crystalCount)*Math.PI*2+Math.random()*0.5;
        var cElev=0.3+Math.random()*0.6;
        var cGeo=def.level>=30?new THREE.OctahedronGeometry(crystalSize,0):new THREE.DodecahedronGeometry(crystalSize,0);
        var cMat=new THREE.MeshLambertMaterial({color:def.color,emissive:def.color,emissiveIntensity:emissiveStr,transparent:def.level>=30,opacity:def.level>=30?0.85:1});
        var crystal=new THREE.Mesh(cGeo,cMat);
        crystal.position.set(Math.cos(cAngle)*rockSize*0.6,rockSize*cElev+0.4,Math.sin(cAngle)*rockSize*0.6);
        crystal.rotation.set(Math.random()*Math.PI,Math.random()*Math.PI,Math.random()*Math.PI);
        mesh.add(crystal);
    }
    // Mid-tier glow (level 30-59)
    if(def.level>=30&&def.level<60){var midGlow=new THREE.PointLight(def.color,0.25,5);midGlow.position.set(0,rockSize+0.3,0);mesh.add(midGlow);}
    // High-tier point light glow (level 60+)
    if(def.level>=60){
        var glow=new THREE.PointLight(def.color,0.5+def.level*0.004,6);
        glow.position.set(0,rockSize+0.5,0);mesh.add(glow);
    }
    // Aura ring for mid-high tier ores (30-69)
    if(def.level>=30&&def.level<70){
        var auraGeo=new THREE.RingGeometry(1.2,1.8,16);
        var auraMat=new THREE.MeshBasicMaterial({color:def.color,transparent:true,opacity:0.15,side:THREE.DoubleSide});
        var aura=new THREE.Mesh(auraGeo,auraMat);
        aura.rotation.x=-Math.PI/2;aura.position.y=0.05;mesh.add(aura);
    }
    // Top-tier ores (70+) get pulsing outer ring
    if(def.level>=70){
        var auraGeo2=new THREE.RingGeometry(1.5,2.2,20);
        var auraMat2=new THREE.MeshBasicMaterial({color:def.color,transparent:true,opacity:0.2,side:THREE.DoubleSide});
        var aura2=new THREE.Mesh(auraGeo2,auraMat2);
        aura2.rotation.x=-Math.PI/2;aura2.position.y=0.05;mesh.add(aura2);
    }
    mesh.position.set(nx,0,nz);mesh.castShadow=true;
    var nodeData={mesh:mesh,type:def.type,resource:def.resource,level:def.level,xp:def.xp,depleted:false,respawnTimer:0,respawnTime:15+Math.random()*15,position:new THREE.Vector3(nx,0,nz)};
    mesh.userData.entityType='resource';mesh.userData.entity=nodeData;
    GameState.scene.add(mesh);GameState.resourceNodes.push(nodeData);
}

function initWorld(){
    buildGround();buildStarfield();buildSkyDome();buildStationHub();buildAsteroidMines();buildAlienWastes();buildTheAbyss();buildBioLab();buildCorridors();buildResourceNodes();
    GameState.world=world;
}

function updateWorld(){
    var t=GameState.elapsedTime;
    GameState.resourceNodes.forEach(function(n){
        if(n.depleted){n.respawnTimer-=GameState.deltaTime;if(n.respawnTimer<=0){n.depleted=false;n.mesh.visible=true;}}
        if(!n.depleted&&n.level>=25&&n.mesh){
            n.mesh.children.forEach(function(child){
                if(child.isPointLight){child.intensity=0.3+Math.sin(t*2+n.position.x)*0.2;}
            });
        }
    });
}

// ========================================
// Dungeon System — Procedural "Abyssal Depths"
// ========================================

// --- Floor Generation ---
function createRoom(id, gridX, gridZ, type) {
    return {
        id: id, gridX: gridX, gridZ: gridZ,
        worldX: gridX * DUNGEON_CONFIG.roomSpacing,
        worldZ: gridZ * DUNGEON_CONFIG.roomSpacing,
        width: DUNGEON_CONFIG.roomSize, depth: DUNGEON_CONFIG.roomSize,
        type: type || 'normal',
        connected: [], enemySpawns: [], trapSpawns: [],
    };
}

function generateDungeonFloor(floor) {
    var gridSize = DUNGEON_CONFIG.getGridSize(floor);
    var minRooms = DUNGEON_CONFIG.getMinRooms(floor);
    var grid = [];
    for (var gx = 0; gx < gridSize; gx++) {
        grid[gx] = [];
        for (var gz = 0; gz < gridSize; gz++) grid[gx][gz] = null;
    }
    // Place entrance at bottom-center
    var entranceX = Math.floor(gridSize / 2), entranceZ = 0;
    var roomId = 0;
    var entrance = createRoom(roomId++, entranceX, entranceZ, 'entrance');
    grid[entranceX][entranceZ] = entrance;
    var rooms = [entrance];
    // Random walk to place rooms
    var cx = entranceX, cz = entranceZ;
    var dirs = [[1,0],[-1,0],[0,1],[0,-1]];
    var attempts = 0;
    while (rooms.length < minRooms && attempts < 200) {
        attempts++;
        var d = dirs[Math.floor(Math.random() * dirs.length)];
        var nx = cx + d[0], nz = cz + d[1];
        if (nx < 0 || nx >= gridSize || nz < 0 || nz >= gridSize) continue;
        if (!grid[nx][nz]) {
            var room = createRoom(roomId++, nx, nz, 'normal');
            grid[nx][nz] = room;
            rooms.push(room);
        }
        cx = nx; cz = nz;
    }
    // Designate farthest room as boss
    var farthest = entrance, maxDist = 0;
    for (var ri = 1; ri < rooms.length; ri++) {
        var rm = rooms[ri];
        var dist = Math.abs(rm.gridX - entranceX) + Math.abs(rm.gridZ - entranceZ);
        if (dist > maxDist) { maxDist = dist; farthest = rm; }
    }
    farthest.type = 'boss';
    // Mark some rooms as trap rooms
    for (var ri2 = 1; ri2 < rooms.length; ri2++) {
        if (rooms[ri2].type === 'boss') continue;
        if (Math.random() < DUNGEON_CONFIG.getTrapChance(floor)) rooms[ri2].type = 'trap';
    }
    // Connect adjacent rooms (boss room gets exactly ONE corridor)
    var corridors = [];
    var bossConnected = false;
    for (var ri3 = 0; ri3 < rooms.length; ri3++) {
        var r = rooms[ri3];
        // Check 4 neighbors
        for (var di = 0; di < dirs.length; di++) {
            var ngx = r.gridX + dirs[di][0], ngz = r.gridZ + dirs[di][1];
            if (ngx < 0 || ngx >= gridSize || ngz < 0 || ngz >= gridSize) continue;
            var neighbor = grid[ngx][ngz];
            if (!neighbor) continue;
            // Boss room: only allow ONE corridor in
            if (neighbor.type === 'boss' && bossConnected) continue;
            if (r.type === 'boss' && bossConnected) continue;
            // Avoid duplicates
            var alreadyConnected = false;
            for (var ci = 0; ci < r.connected.length; ci++) {
                if (r.connected[ci] === neighbor.id) { alreadyConnected = true; break; }
            }
            if (alreadyConnected) continue;
            r.connected.push(neighbor.id);
            neighbor.connected.push(r.id);
            corridors.push({ fromId: r.id, toId: neighbor.id, fromRoom: r, toRoom: neighbor });
            if (r.type === 'boss' || neighbor.type === 'boss') bossConnected = true;
        }
    }
    // Ensure all rooms are connected via BFS from entrance
    var visited = {};
    var queue = [entrance.id];
    visited[entrance.id] = true;
    while(queue.length > 0){
        var current = queue.shift();
        var currentRoom = null;
        for(var vi=0;vi<rooms.length;vi++){if(rooms[vi].id===current){currentRoom=rooms[vi];break;}}
        if(!currentRoom)continue;
        for(var ci2=0;ci2<currentRoom.connected.length;ci2++){
            var connId=currentRoom.connected[ci2];
            if(!visited[connId]){visited[connId]=true;queue.push(connId);}
        }
    }
    // Connect any unreachable rooms to nearest reachable room
    for(var ri5=0;ri5<rooms.length;ri5++){
        var unr=rooms[ri5];
        if(visited[unr.id])continue;
        // Find nearest reachable room
        var nearestDist=9999,nearestRoom=null;
        for(var ri6=0;ri6<rooms.length;ri6++){
            if(!visited[rooms[ri6].id])continue;
            var dx2=Math.abs(unr.gridX-rooms[ri6].gridX)+Math.abs(unr.gridZ-rooms[ri6].gridZ);
            if(dx2<nearestDist){nearestDist=dx2;nearestRoom=rooms[ri6];}
        }
        if(nearestRoom){
            // Skip if boss room already connected
            if((unr.type==='boss'&&bossConnected)||(nearestRoom.type==='boss'&&bossConnected))continue;
            unr.connected.push(nearestRoom.id);
            nearestRoom.connected.push(unr.id);
            corridors.push({fromId:unr.id,toId:nearestRoom.id,fromRoom:unr,toRoom:nearestRoom});
            if(unr.type==='boss'||nearestRoom.type==='boss')bossConnected=true;
            visited[unr.id]=true;
            // Re-run BFS from newly connected room to pick up any chains
            queue=[unr.id];
            while(queue.length>0){
                var curr2=queue.shift();
                var currRoom2=null;
                for(var vi2=0;vi2<rooms.length;vi2++){if(rooms[vi2].id===curr2){currRoom2=rooms[vi2];break;}}
                if(!currRoom2)continue;
                for(var ci3=0;ci3<currRoom2.connected.length;ci3++){
                    var cid2=currRoom2.connected[ci3];
                    if(!visited[cid2]){visited[cid2]=true;queue.push(cid2);}
                }
            }
        }
    }
    // Populate enemy spawns
    var enemyTypes = getDungeonEnemyTypes(floor);
    var enemiesPerRoom = DUNGEON_CONFIG.getEnemiesPerRoom(floor);
    for (var ri4 = 0; ri4 < rooms.length; ri4++) {
        var rm2 = rooms[ri4];
        if (rm2.type === 'entrance') continue;
        if (rm2.type === 'boss') {
            rm2.enemySpawns.push({ type: getDungeonBossType(floor), isBoss: true });
            continue;
        }
        var count = Math.max(1, enemiesPerRoom - Math.floor(Math.random() * 2));
        for (var ei = 0; ei < count; ei++) {
            rm2.enemySpawns.push({ type: enemyTypes[Math.floor(Math.random() * enemyTypes.length)], isBoss: false });
        }
    }
    // Populate trap spawns
    var trapsPerRoom = DUNGEON_CONFIG.getTrapsPerRoom(floor);
    var trapKeys = Object.keys(DUNGEON_TRAP_TYPES);
    for (var ri5 = 0; ri5 < rooms.length; ri5++) {
        var rm3 = rooms[ri5];
        if (rm3.type === 'entrance' || rm3.type === 'boss') continue;
        var numTraps = (rm3.type === 'trap') ? trapsPerRoom : Math.floor(trapsPerRoom * 0.5);
        for (var ti = 0; ti < numTraps; ti++) {
            var trapType = trapKeys[Math.floor(Math.random() * trapKeys.length)];
            var tx = rm3.worldX + (Math.random() - 0.5) * (rm3.width - 3);
            var tz = rm3.worldZ + (Math.random() - 0.5) * (rm3.depth - 3);
            rm3.trapSpawns.push({ type: trapType, x: tx, z: tz });
        }
    }
    return { grid: grid, gridSize: gridSize, rooms: rooms, corridors: corridors, entranceRoom: entrance, bossRoom: farthest };
}

// --- Dungeon Mesh Building ---
function buildDungeonFloor(floorData, floor) {
    var meshes = [];
    var floorHue = Math.max(0.55, 0.75 - floor * 0.02);
    var floorColor = new THREE.Color().setHSL(floorHue, 0.3, 0.08);
    var wallColor = new THREE.Color().setHSL(floorHue, 0.2, 0.12);
    var wallH = 4;
    // Dungeon ambient light
    var dLight = new THREE.AmbientLight(0x112244, 0.3);
    GameState.scene.add(dLight); meshes.push(dLight);
    DungeonState.dungeonLight = dLight;
    // Build rooms
    for (var ri = 0; ri < floorData.rooms.length; ri++) {
        var room = floorData.rooms[ri];
        // Floor plane
        var floorGeo = new THREE.PlaneGeometry(room.width, room.depth);
        var floorMat = new THREE.MeshLambertMaterial({ color: floorColor.clone() });
        var floorMesh = new THREE.Mesh(floorGeo, floorMat);
        floorMesh.rotation.x = -Math.PI / 2;
        floorMesh.position.set(room.worldX, 0.01, room.worldZ);
        floorMesh.userData.isGround = true; floorMesh.userData.isDungeon = true;
        GameState.scene.add(floorMesh); meshes.push(floorMesh);
        // Check which directions have corridors
        var hasRight = false, hasLeft = false, hasForward = false, hasBack = false;
        for (var ci = 0; ci < floorData.corridors.length; ci++) {
            var corr = floorData.corridors[ci];
            var other = null;
            if (corr.fromRoom === room) other = corr.toRoom;
            else if (corr.toRoom === room) other = corr.fromRoom;
            if (!other) continue;
            var dx = other.gridX - room.gridX, dz = other.gridZ - room.gridZ;
            if (dx === 1) hasRight = true;
            if (dx === -1) hasLeft = true;
            if (dz === 1) hasForward = true;
            if (dz === -1) hasBack = true;
        }
        // Walls
        var wallMat = new THREE.MeshLambertMaterial({ color: wallColor.clone() });
        buildRoomWalls(room, wallMat, wallH, hasRight, hasLeft, hasForward, hasBack, meshes);
        // Ceiling light
        var lightColor = room.type === 'boss' ? 0xff2244 : room.type === 'trap' ? 0xffaa22 : 0x4466aa;
        var cLight = new THREE.PointLight(lightColor, 0.4, room.width * 1.2);
        cLight.position.set(room.worldX, wallH - 0.5, room.worldZ);
        cLight.userData.isDungeon = true;
        GameState.scene.add(cLight); meshes.push(cLight);
        // Entrance pad
        if (room.type === 'entrance') {
            var padGeo = new THREE.CircleGeometry(2, 16);
            var padMat = new THREE.MeshBasicMaterial({ color: 0x22ff66, transparent: true, opacity: 0.4, side: THREE.DoubleSide });
            var pad = new THREE.Mesh(padGeo, padMat);
            pad.rotation.x = -Math.PI / 2; pad.position.set(room.worldX, 0.05, room.worldZ);
            pad.userData.isDungeon = true;
            GameState.scene.add(pad); meshes.push(pad);
            var padLight = new THREE.PointLight(0x22ff66, 0.3, 6);
            padLight.position.set(room.worldX, 1, room.worldZ);
            padLight.userData.isDungeon = true;
            GameState.scene.add(padLight); meshes.push(padLight);
        }
        // Boss room glow
        if (room.type === 'boss') {
            var bossGlow = new THREE.PointLight(0xff2244, 0.5, 20);
            bossGlow.position.set(room.worldX, 2, room.worldZ);
            bossGlow.userData.isDungeon = true;
            GameState.scene.add(bossGlow); meshes.push(bossGlow);
        }
    }
    // Build corridors
    for (var ci2 = 0; ci2 < floorData.corridors.length; ci2++) {
        buildDungeonCorridor(floorData.corridors[ci2], floorColor, wallColor, meshes);
    }
    DungeonState.meshes = meshes;
}

function buildRoomWalls(room, wallMat, wallH, hasRight, hasLeft, hasForward, hasBack, meshes) {
    var hw = room.width / 2, hd = room.depth / 2;
    var cw = DUNGEON_CONFIG.corridorWidth / 2;
    var wx = room.worldX, wz = room.worldZ;
    // Right wall (+X)
    if (!hasRight) {
        var w = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, room.depth), wallMat);
        w.position.set(wx + hw, wallH / 2, wz); w.userData.isDungeon = true;
        GameState.scene.add(w); meshes.push(w);
    } else {
        var seg1 = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, hd - cw), wallMat);
        seg1.position.set(wx + hw, wallH / 2, wz - (hd + cw) / 2); seg1.userData.isDungeon = true;
        GameState.scene.add(seg1); meshes.push(seg1);
        var seg2 = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, hd - cw), wallMat);
        seg2.position.set(wx + hw, wallH / 2, wz + (hd + cw) / 2); seg2.userData.isDungeon = true;
        GameState.scene.add(seg2); meshes.push(seg2);
    }
    // Left wall (-X)
    if (!hasLeft) {
        var w2 = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, room.depth), wallMat);
        w2.position.set(wx - hw, wallH / 2, wz); w2.userData.isDungeon = true;
        GameState.scene.add(w2); meshes.push(w2);
    } else {
        var seg3 = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, hd - cw), wallMat);
        seg3.position.set(wx - hw, wallH / 2, wz - (hd + cw) / 2); seg3.userData.isDungeon = true;
        GameState.scene.add(seg3); meshes.push(seg3);
        var seg4 = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, hd - cw), wallMat);
        seg4.position.set(wx - hw, wallH / 2, wz + (hd + cw) / 2); seg4.userData.isDungeon = true;
        GameState.scene.add(seg4); meshes.push(seg4);
    }
    // Forward wall (+Z)
    if (!hasForward) {
        var w3 = new THREE.Mesh(new THREE.BoxGeometry(room.width, wallH, 0.5), wallMat);
        w3.position.set(wx, wallH / 2, wz + hd); w3.userData.isDungeon = true;
        GameState.scene.add(w3); meshes.push(w3);
    } else {
        var seg5 = new THREE.Mesh(new THREE.BoxGeometry(hw - cw, wallH, 0.5), wallMat);
        seg5.position.set(wx - (hw + cw) / 2, wallH / 2, wz + hd); seg5.userData.isDungeon = true;
        GameState.scene.add(seg5); meshes.push(seg5);
        var seg6 = new THREE.Mesh(new THREE.BoxGeometry(hw - cw, wallH, 0.5), wallMat);
        seg6.position.set(wx + (hw + cw) / 2, wallH / 2, wz + hd); seg6.userData.isDungeon = true;
        GameState.scene.add(seg6); meshes.push(seg6);
    }
    // Back wall (-Z)
    if (!hasBack) {
        var w4 = new THREE.Mesh(new THREE.BoxGeometry(room.width, wallH, 0.5), wallMat);
        w4.position.set(wx, wallH / 2, wz - hd); w4.userData.isDungeon = true;
        GameState.scene.add(w4); meshes.push(w4);
    } else {
        var seg7 = new THREE.Mesh(new THREE.BoxGeometry(hw - cw, wallH, 0.5), wallMat);
        seg7.position.set(wx - (hw + cw) / 2, wallH / 2, wz - hd); seg7.userData.isDungeon = true;
        GameState.scene.add(seg7); meshes.push(seg7);
        var seg8 = new THREE.Mesh(new THREE.BoxGeometry(hw - cw, wallH, 0.5), wallMat);
        seg8.position.set(wx + (hw + cw) / 2, wallH / 2, wz - hd); seg8.userData.isDungeon = true;
        GameState.scene.add(seg8); meshes.push(seg8);
    }
}

function buildDungeonCorridor(corr, floorColor, wallColor, meshes) {
    var fromR = corr.fromRoom, toR = corr.toRoom;
    var cw = DUNGEON_CONFIG.corridorWidth;
    var wallH = 4;
    var midX = (fromR.worldX + toR.worldX) / 2;
    var midZ = (fromR.worldZ + toR.worldZ) / 2;
    var dx = toR.worldX - fromR.worldX, dz = toR.worldZ - fromR.worldZ;
    var isHoriz = Math.abs(dx) > Math.abs(dz);
    var length = Math.abs(isHoriz ? dx : dz) - DUNGEON_CONFIG.roomSize;
    if (length <= 0) return;
    // Floor
    var fGeo, fMesh;
    if (isHoriz) {
        fGeo = new THREE.PlaneGeometry(length, cw);
    } else {
        fGeo = new THREE.PlaneGeometry(cw, length);
    }
    fMesh = new THREE.Mesh(fGeo, new THREE.MeshLambertMaterial({ color: floorColor.clone().multiplyScalar(0.9) }));
    fMesh.rotation.x = -Math.PI / 2; fMesh.position.set(midX, 0.01, midZ);
    fMesh.userData.isGround = true; fMesh.userData.isDungeon = true;
    GameState.scene.add(fMesh); meshes.push(fMesh);
    // Walls
    var wMat = new THREE.MeshLambertMaterial({ color: wallColor.clone() });
    if (isHoriz) {
        var w1 = new THREE.Mesh(new THREE.BoxGeometry(length, wallH, 0.5), wMat);
        w1.position.set(midX, wallH / 2, midZ - cw / 2); w1.userData.isDungeon = true;
        GameState.scene.add(w1); meshes.push(w1);
        var w2 = new THREE.Mesh(new THREE.BoxGeometry(length, wallH, 0.5), wMat);
        w2.position.set(midX, wallH / 2, midZ + cw / 2); w2.userData.isDungeon = true;
        GameState.scene.add(w2); meshes.push(w2);
    } else {
        var w3 = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, length), wMat);
        w3.position.set(midX - cw / 2, wallH / 2, midZ); w3.userData.isDungeon = true;
        GameState.scene.add(w3); meshes.push(w3);
        var w4 = new THREE.Mesh(new THREE.BoxGeometry(0.5, wallH, length), wMat);
        w4.position.set(midX + cw / 2, wallH / 2, midZ); w4.userData.isDungeon = true;
        GameState.scene.add(w4); meshes.push(w4);
    }
    // Corridor light
    var corrLight = new THREE.PointLight(0x334466, 0.2, cw * 3);
    corrLight.position.set(midX, wallH - 1, midZ); corrLight.userData.isDungeon = true;
    GameState.scene.add(corrLight); meshes.push(corrLight);
}

function buildTrapMesh(trapSpawn) {
    var trapDef = DUNGEON_TRAP_TYPES[trapSpawn.type];
    var group = new THREE.Group();
    var circle = new THREE.Mesh(
        new THREE.CircleGeometry(trapDef.radius, 16),
        new THREE.MeshBasicMaterial({ color: trapDef.color, transparent: true, opacity: 0.35, side: THREE.DoubleSide })
    );
    circle.rotation.x = -Math.PI / 2; circle.position.y = 0.03; group.add(circle);
    var center = new THREE.Mesh(
        new THREE.SphereGeometry(0.3, 8, 8),
        new THREE.MeshBasicMaterial({ color: trapDef.emissive, transparent: true, opacity: 0.6 })
    );
    center.position.y = 0.3; group.add(center);
    var light = new THREE.PointLight(trapDef.color, 0.3, trapDef.radius * 2);
    light.position.y = 0.5; group.add(light);
    group.position.set(trapSpawn.x, 0, trapSpawn.z);
    group.userData.isDungeon = true;
    GameState.scene.add(group);
    return {
        mesh: group, type: trapSpawn.type, def: trapDef,
        x: trapSpawn.x, z: trapSpawn.z, radius: trapDef.radius,
        dmg: trapDef.dmg, tick: trapDef.tick, effect: trapDef.effect,
        timer: 0, circleRef: circle,
    };
}

function buildBossGate(floorData) {
    if (!floorData.bossRoom || floorData.bossRoom.connected.length === 0) return null;
    var bossRoom = floorData.bossRoom;
    // Find the corridor connecting to boss room — use first connection
    var connId = bossRoom.connected[0];
    var connRoom = null;
    for (var ri = 0; ri < floorData.rooms.length; ri++) {
        if (floorData.rooms[ri].id === connId) { connRoom = floorData.rooms[ri]; break; }
    }
    if (!connRoom) return null;
    var dx = bossRoom.worldX - connRoom.worldX, dz = bossRoom.worldZ - connRoom.worldZ;
    var gateX, gateZ;
    if (Math.abs(dx) > Math.abs(dz)) {
        gateX = bossRoom.worldX - Math.sign(dx) * bossRoom.width / 2;
        gateZ = bossRoom.worldZ;
    } else {
        gateX = bossRoom.worldX;
        gateZ = bossRoom.worldZ - Math.sign(dz) * bossRoom.depth / 2;
    }
    var gateGroup = new THREE.Group();
    var isXWall = Math.abs(dz) > Math.abs(dx);
    var barCount = 6, barSpacing = DUNGEON_CONFIG.corridorWidth / (barCount + 1);
    for (var bi = 0; bi < barCount; bi++) {
        var barMat = new THREE.MeshLambertMaterial({ color: 0x884422, emissive: 0x441100, emissiveIntensity: 0.3 });
        var bar = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 3.5, 6), barMat);
        if (isXWall) {
            bar.position.set(-DUNGEON_CONFIG.corridorWidth / 2 + (bi + 1) * barSpacing, 1.75, 0);
        } else {
            bar.position.set(0, 1.75, -DUNGEON_CONFIG.corridorWidth / 2 + (bi + 1) * barSpacing);
        }
        gateGroup.add(bar);
    }
    gateGroup.position.set(gateX, 0, gateZ);
    gateGroup.userData.isDungeon = true;
    GameState.scene.add(gateGroup);
    DungeonState.meshes.push(gateGroup);
    var lockLight = new THREE.PointLight(0xff2222, 0.5, 6);
    lockLight.position.set(gateX, 2, gateZ);
    lockLight.userData.isDungeon = true;
    GameState.scene.add(lockLight);
    DungeonState.meshes.push(lockLight);
    return { mesh: gateGroup, x: gateX, z: gateZ, lockLight: lockLight, isXWall: isXWall };
}

// --- Core Dungeon Lifecycle ---
function hideOverworld() {
    // Hide all non-dungeon scene children (except lights, camera, and player)
    GameState.scene.children.forEach(function(child) {
        if (child.userData && child.userData.isDungeon) return;
        if (child.isCamera) return;
        if (child === player.mesh) return; // Keep player visible!
        // Keep ambient/directional lights
        if (child.isAmbientLight || child.isDirectionalLight) return;
        child._wasVisible = child.visible;
        child.visible = false;
    });
}

function showOverworld() {
    // Restore all scene children visibility
    GameState.scene.children.forEach(function(child) {
        if (child.userData && child.userData.isDungeon) return;
        if (child._wasVisible !== undefined) {
            child.visible = child._wasVisible;
            delete child._wasVisible;
        } else {
            child.visible = true;
        }
    });
}

function enterDungeon() {
    if (DungeonState.active) return;
    // Save player position + area
    DungeonState.savedPlayerPos = player.mesh.position.clone();
    DungeonState.savedArea = player.currentArea;
    // Stop activities
    player.combatTarget = null; player.inCombat = false;
    player.isMoving = false; player.moveTarget = null;
    player.isGathering = false; player.gatherTarget = null; player.gatherProgress = 0;
    // Hide overworld
    hideOverworld();
    // Activate dungeon
    DungeonState.active = true;
    DungeonState.floor = 1;
    DungeonState.bossGateOpen = false;
    loadDungeonFloor(1);
    playSound('portal');
    triggerAreaTransition('Abyssal Depths - Floor 1');
    showDungeonHUD();
    EventBus.emit('chat', { type: 'system', text: 'You enter the Abyssal Depths...' });
    EventBus.emit('chat', { type: 'info', text: 'Kill all enemies to unlock the boss gate. Defeat the boss to advance.' });
    EventBus.emit('chat', { type: 'info', text: 'Beware of traps! Death returns you to the surface.' });
}

function exitDungeon() {
    if (!DungeonState.active) return;
    cleanupDungeonFloor();
    showOverworld();
    DungeonState.active = false;
    DungeonState.floor = 0;
    // Restore position to Station Hub near dungeon portal
    if (DungeonState.savedPlayerPos) {
        player.mesh.position.copy(DungeonState.savedPlayerPos);
    } else {
        player.mesh.position.set(0, 0, -15);
    }
    player.currentArea = DungeonState.savedArea || 'station-hub';
    GameState.currentArea = player.currentArea;
    hideDungeonHUD();
    triggerAreaTransition('Station Hub');
    EventBus.emit('areaChanged', player.currentArea);
    EventBus.emit('chat', { type: 'system', text: 'You return to the surface.' });
}

function advanceDungeonFloor() {
    if (!DungeonState.active) return;
    cleanupDungeonFloor();
    DungeonState.floor++;
    if (DungeonState.floor > DungeonState.maxFloorReached) {
        DungeonState.maxFloorReached = DungeonState.floor;
    }
    DungeonState.bossGateOpen = false;
    loadDungeonFloor(DungeonState.floor);
    triggerAreaTransition('Floor ' + DungeonState.floor);
    EventBus.emit('chat', { type: 'system', text: 'Descending to Floor ' + DungeonState.floor + '...' });
    updateDungeonHUD();
}

function loadDungeonFloor(floor) {
    var floorData = generateDungeonFloor(floor);
    DungeonState.grid = floorData.grid;
    DungeonState.gridSize = floorData.gridSize;
    DungeonState.rooms = floorData.rooms;
    DungeonState.corridors = floorData.corridors;
    DungeonState.entranceRoom = floorData.entranceRoom;
    DungeonState.bossRoom = floorData.bossRoom;
    DungeonState.enemiesAlive = 0;
    // Build meshes
    buildDungeonFloor(floorData, floor);
    // Spawn enemies
    DungeonState.enemies = [];
    for (var ri = 0; ri < floorData.rooms.length; ri++) {
        var room = floorData.rooms[ri];
        for (var ei = 0; ei < room.enemySpawns.length; ei++) {
            var spawn = room.enemySpawns[ei];
            var stats = spawn.isBoss ? scaleDungeonBoss(spawn.type, floor) : scaleDungeonEnemy(spawn.type, floor);
            if (!stats) continue;
            var mesh = buildEnemyMesh(spawn.type);
            var sx = room.worldX + (Math.random() - 0.5) * (room.width - 4);
            var sz = room.worldZ + (Math.random() - 0.5) * (room.depth - 4);
            mesh.position.set(sx, 0, sz);
            mesh.userData.isDungeon = true;
            var enemy = {
                name: stats.name, type: stats.type, level: stats.level,
                hp: stats.hp, maxHp: stats.maxHp, damage: stats.damage, defense: stats.defense,
                attackSpeed: stats.attackSpeed, aggroRange: stats.aggroRange, leashRange: stats.leashRange,
                combatStyle: stats.combatStyle, respawnTime: stats.respawnTime,
                isBoss: stats.isBoss, isDungeonEnemy: true, isDungeonBoss: stats.isDungeonBoss,
                area: 'dungeon', desc: stats.desc, lootTable: stats.lootTable,
                mesh: mesh, alive: true, spawnPos: new THREE.Vector3(sx, 0, sz),
                state: 'idle', wanderTarget: null, wanderTimer: Math.random() * 5,
                attackTimer: stats.attackSpeed, stunTimer: 0, respawnTimer: 0,
                animPhase: Math.random() * Math.PI * 2, deathAnim: 0,
            };
            mesh.userData.entityType = 'enemy'; mesh.userData.entity = enemy;
            GameState.scene.add(mesh);
            GameState.enemies.push(enemy);
            DungeonState.enemies.push(enemy);
            DungeonState.meshes.push(mesh);
            if (!spawn.isBoss) DungeonState.enemiesAlive++;
        }
    }
    // Spawn traps
    DungeonState.traps = [];
    for (var ri2 = 0; ri2 < floorData.rooms.length; ri2++) {
        var room2 = floorData.rooms[ri2];
        for (var ti = 0; ti < room2.trapSpawns.length; ti++) {
            var trap = buildTrapMesh(room2.trapSpawns[ti]);
            DungeonState.traps.push(trap);
            DungeonState.meshes.push(trap.mesh);
        }
    }
    // Build boss gate
    DungeonState.bossGate = buildBossGate(floorData);
    // Position player at entrance
    if (floorData.entranceRoom) {
        player.mesh.position.set(floorData.entranceRoom.worldX, 0, floorData.entranceRoom.worldZ);
    }
    player.currentArea = 'dungeon';
    GameState.currentArea = 'dungeon';
    updateDungeonHUD();
}

function cleanupDungeonFloor() {
    // Remove all dungeon meshes
    for (var i = 0; i < DungeonState.meshes.length; i++) {
        var m = DungeonState.meshes[i];
        GameState.scene.remove(m);
        if (m.geometry) m.geometry.dispose();
        if (m.material) {
            if (Array.isArray(m.material)) m.material.forEach(function(mt) { mt.dispose(); });
            else m.material.dispose();
        }
        // Also dispose children
        if (m.children) {
            m.traverse(function(child) {
                if (child.geometry) child.geometry.dispose();
                if (child.material) {
                    if (Array.isArray(child.material)) child.material.forEach(function(mt) { mt.dispose(); });
                    else child.material.dispose();
                }
            });
        }
    }
    DungeonState.meshes = [];
    // Remove dungeon enemies from GameState.enemies
    for (var ei = GameState.enemies.length - 1; ei >= 0; ei--) {
        if (GameState.enemies[ei].isDungeonEnemy) {
            GameState.enemies.splice(ei, 1);
        }
    }
    DungeonState.enemies = [];
    DungeonState.traps = [];
    DungeonState.bossGate = null;
    DungeonState.dungeonLight = null;
    // Remove dungeon ground items
    for (var gi = GameState.groundItems.length - 1; gi >= 0; gi--) {
        if (GameState.groundItems[gi].isDungeonItem) {
            GameState.scene.remove(GameState.groundItems[gi].mesh);
            GameState.groundItems.splice(gi, 1);
        }
    }
    DungeonState.rooms = [];
    DungeonState.corridors = [];
    DungeonState.grid = [];
}

// --- Dungeon Movement Validation ---
function isDungeonValidPosition(x, z) {
    // Check rooms
    for (var ri = 0; ri < DungeonState.rooms.length; ri++) {
        var room = DungeonState.rooms[ri];
        var hw = room.width / 2 - 0.5, hd = room.depth / 2 - 0.5;
        if (x >= room.worldX - hw && x <= room.worldX + hw && z >= room.worldZ - hd && z <= room.worldZ + hd) {
            // Check boss gate collision
            if (DungeonState.bossGate && !DungeonState.bossGateOpen) {
                var gate = DungeonState.bossGate;
                var gdx = Math.abs(x - gate.x), gdz = Math.abs(z - gate.z);
                if (gate.isXWall) {
                    if (gdx < DUNGEON_CONFIG.corridorWidth / 2 && gdz < 0.8) return false;
                } else {
                    if (gdz < DUNGEON_CONFIG.corridorWidth / 2 && gdx < 0.8) return false;
                }
            }
            return true;
        }
    }
    // Check corridors
    for (var ci = 0; ci < DungeonState.corridors.length; ci++) {
        var corr = DungeonState.corridors[ci];
        var fr = corr.fromRoom, tr = corr.toRoom;
        var midX = (fr.worldX + tr.worldX) / 2;
        var midZ = (fr.worldZ + tr.worldZ) / 2;
        var dx = tr.worldX - fr.worldX, dz = tr.worldZ - fr.worldZ;
        var isHoriz = Math.abs(dx) > Math.abs(dz);
        var length = Math.abs(isHoriz ? dx : dz);
        var cw = DUNGEON_CONFIG.corridorWidth / 2 - 0.3;
        if (isHoriz) {
            if (x >= midX - length / 2 && x <= midX + length / 2 && z >= midZ - cw && z <= midZ + cw) {
                // Check boss gate
                if (DungeonState.bossGate && !DungeonState.bossGateOpen) {
                    var gate2 = DungeonState.bossGate;
                    var gdx2 = Math.abs(x - gate2.x), gdz2 = Math.abs(z - gate2.z);
                    if (gate2.isXWall) {
                        if (gdx2 < DUNGEON_CONFIG.corridorWidth / 2 && gdz2 < 0.8) return false;
                    } else {
                        if (gdz2 < DUNGEON_CONFIG.corridorWidth / 2 && gdx2 < 0.8) return false;
                    }
                }
                return true;
            }
        } else {
            if (z >= midZ - length / 2 && z <= midZ + length / 2 && x >= midX - cw && x <= midX + cw) {
                if (DungeonState.bossGate && !DungeonState.bossGateOpen) {
                    var gate3 = DungeonState.bossGate;
                    var gdx3 = Math.abs(x - gate3.x), gdz3 = Math.abs(z - gate3.z);
                    if (gate3.isXWall) {
                        if (gdx3 < DUNGEON_CONFIG.corridorWidth / 2 && gdz3 < 0.8) return false;
                    } else {
                        if (gdz3 < DUNGEON_CONFIG.corridorWidth / 2 && gdx3 < 0.8) return false;
                    }
                }
                return true;
            }
        }
    }
    return false;
}

// --- Trap Update ---
function updateDungeonTraps() {
    if (!DungeonState.active) return;
    var dt = GameState.deltaTime;
    var pp = player.mesh.position;
    // Clear slow effect each frame, re-apply if still on trap
    player._dungeonSlowed = false;
    for (var i = 0; i < DungeonState.traps.length; i++) {
        var trap = DungeonState.traps[i];
        var dx = pp.x - trap.x, dz = pp.z - trap.z;
        var dist = Math.sqrt(dx * dx + dz * dz);
        // Pulsing animation
        trap.timer -= dt;
        var pulse = 0.3 + Math.sin(GameState.elapsedTime * 3 + i) * 0.15;
        if (trap.circleRef) trap.circleRef.material.opacity = pulse;
        if (dist < trap.radius) {
            if (trap.timer <= 0) {
                trap.timer = trap.tick;
                var dmgScale = 1 + (DungeonState.floor - 1) * 0.15;
                var actualDmg = playerTakeDamage(Math.round(trap.dmg * dmgScale));
                createFloatText(pp.clone().add(new THREE.Vector3(0, 2, 0)), '-' + actualDmg + ' (' + trap.def.name + ')', 'damage');
                EventBus.emit('chat', { type: 'combat', text: trap.def.name + ' hits you for ' + actualDmg + ' damage!' });
            }
            if (trap.effect === 'slow') {
                player._dungeonSlowed = true;
            }
        }
    }
}

// --- Boss Gate ---
function checkBossGateUnlock() {
    if (!DungeonState.active) return;
    if (DungeonState.bossGateOpen) return;
    if (DungeonState.enemiesAlive <= 0) {
        DungeonState.bossGateOpen = true;
        if (DungeonState.bossGate) {
            DungeonState.bossGate.mesh.visible = false;
            if (DungeonState.bossGate.lockLight) {
                DungeonState.bossGate.lockLight.color.setHex(0x22ff44);
            }
        }
        EventBus.emit('chat', { type: 'system', text: 'The boss gate has been unlocked!' });
        createLootToast('Boss Gate Unlocked!', '\u26A0\uFE0F');
        updateDungeonHUD();
    }
}

// --- Dungeon HUD ---
function showDungeonHUD() {
    var hud = document.getElementById('dungeon-hud');
    if (hud) hud.style.display = 'flex';
}
function hideDungeonHUD() {
    var hud = document.getElementById('dungeon-hud');
    if (hud) hud.style.display = 'none';
}
function updateDungeonHUD() {
    var floorLabel = document.getElementById('dungeon-floor-label');
    var enemiesLabel = document.getElementById('dungeon-enemies-left');
    if (floorLabel) floorLabel.textContent = 'Floor ' + DungeonState.floor;
    if (enemiesLabel) {
        if (DungeonState.bossGateOpen) {
            enemiesLabel.textContent = 'Gate: OPEN';
            enemiesLabel.style.color = '#44ff88';
        } else {
            enemiesLabel.textContent = 'Enemies: ' + DungeonState.enemiesAlive;
            enemiesLabel.style.color = '#ff6644';
        }
    }
}

// ========================================
// Skills & Gathering
// ========================================
const SKILL_DEFS = {
    nano:{name:'Nanotech',icon:'\uD83D\uDD2C',color:'#44ff88',type:'combat'},
    tesla:{name:'Tesla',icon:'\u26A1',color:'#44aaff',type:'combat'},
    void:{name:'Void',icon:'\uD83C\uDF00',color:'#aa44ff',type:'combat'},
    astromining:{name:'Astromining',icon:'\u26CF\uFE0F',color:'#ff8844',type:'gathering'},
    bioforge:{name:'Bioforge',icon:'\uD83E\uDDEC',color:'#44ffaa',type:'production'},
    circuitry:{name:'Circuitry',icon:'\uD83D\uDD27',color:'#ffaa44',type:'production'},
    xenocook:{name:'Xenocook',icon:'\uD83C\uDF73',color:'#ff4488',type:'production'},
    psionics:{name:'Psionics',icon:'\uD83E\uDDE0',color:'#ff44ff',type:'prestige',locked:true,lockText:'Complete the Psionic Awakening quest chain.'},
    chronomancy:{name:'Chronomancy',icon:'\u23F3',color:'#44ffff',type:'prestige',softGate:true,softGateText:'Requires Level 10 in any combat skill.'},
};

// ----------------------------------------
// Cross-Skill Synergy Definitions
// ----------------------------------------
const SYNERGY_DEFS = [
    { id: 'double_ore', name: 'Rich Veins', desc: '15% chance to mine double ores', requirement: function() { return player.skills.astromining.level >= 20; }, reqText: 'Astromining 20+', type: 'gathering_bonus', value: 0.15 },
    { id: 'weapon_durability', name: 'Precision Forge', desc: 'Crafted weapons get +5% durability', requirement: function() { return player.skills.circuitry.level >= 15; }, reqText: 'Circuitry 15+', type: 'durability_bonus_weapon', value: 0.05 },
    { id: 'armor_durability', name: 'Bio-Reinforcement', desc: 'Crafted armor gets +5% durability', requirement: function() { return player.skills.bioforge.level >= 15; }, reqText: 'Bioforge 15+', type: 'durability_bonus_armor', value: 0.05 },
    { id: 'food_heal_bonus', name: 'Gourmet Touch', desc: 'Food heals 10% more', requirement: function() { return player.skills.xenocook.level >= 10; }, reqText: 'Xenocook 10+', type: 'heal_bonus', value: 0.10 },
    { id: 'combat_damage_nano', name: 'Nano Mastery', desc: '+5% nano damage', requirement: function() { return player.skills.nano.level >= 20; }, reqText: 'Nanotech 20+', type: 'combat_damage', value: 0.05, style: 'nano' },
    { id: 'combat_damage_tesla', name: 'Tesla Mastery', desc: '+5% tesla damage', requirement: function() { return player.skills.tesla.level >= 20; }, reqText: 'Tesla 20+', type: 'combat_damage', value: 0.05, style: 'tesla' },
    { id: 'combat_damage_void', name: 'Void Mastery', desc: '+5% void damage', requirement: function() { return player.skills.void.level >= 20; }, reqText: 'Void 20+', type: 'combat_damage', value: 0.05, style: 'void' },
    { id: 'cross_combat_accuracy', name: 'Combat Versatility', desc: '+5% accuracy', requirement: function() { var count = 0; if (player.skills.nano.level >= 10) count++; if (player.skills.tesla.level >= 10) count++; if (player.skills.void.level >= 10) count++; return count >= 2; }, reqText: '2+ combat skills at 10+', type: 'combat_accuracy', value: 0.05 },
    { id: 'smelting_xp_bonus', name: 'Forge Synergy', desc: 'Smelting gives +10% XP', requirement: function() { return player.skills.astromining.level >= 15 && player.skills.circuitry.level >= 15; }, reqText: 'Astromining 15+ AND Circuitry 15+', type: 'xp_bonus', value: 0.10, skill: 'circuitry' },
    { id: 'psionic_combat', name: 'Mind Over Matter', desc: '+3% psionic proc in combat', requirement: function() { return player.psionicsUnlocked && player.skills.psionics && player.skills.psionics.level >= 20 && Math.max(player.skills.nano.level, player.skills.tesla.level, player.skills.void.level) >= 30; }, reqText: 'Psionics 20+ AND any combat 30+', type: 'psionic_synergy', value: 0.03 },
    { id: 'temporal_efficiency', name: 'Temporal Efficiency', desc: '+5% gathering speed', requirement: function() { return player.skills.chronomancy && player.skills.chronomancy.level >= 15 && player.skills.astromining.level >= 20; }, reqText: 'Chronomancy 15+ AND Astromining 20+', type: 'gathering_bonus', value: 0.05 },
    { id: 'chrono_craft', name: 'Accelerated Production', desc: '+8% crafting XP', requirement: function() { return player.skills.chronomancy && player.skills.chronomancy.level >= 20 && player.skills.circuitry.level >= 20; }, reqText: 'Chronomancy 20+ AND Circuitry 20+', type: 'xp_bonus', value: 0.08 },
    { id: 'psionic_temporal', name: 'Paradox Mind', desc: '+5% damage + 5% speed', requirement: function() { return player.psionicsUnlocked && player.skills.psionics && player.skills.psionics.level >= 40 && player.skills.chronomancy && player.skills.chronomancy.level >= 40; }, reqText: 'Psionics 40+ AND Chronomancy 40+', type: 'prestige_synergy', value: 0.05 },
];

const SKILL_UNLOCKS={
astromining:[
{level:1,type:'item',desc:'Mine Stellarite Ore'},
{level:3,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:5,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:8,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:10,type:'item',desc:'Mine Ferrite Ore'},
{level:12,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:15,type:'passive',desc:'3% chance double ore',bonusType:'doubleOre',value:0.03},
{level:18,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:20,type:'item',desc:'Mine Cobaltium Ore'},
{level:22,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:25,type:'synergy',desc:'Rich Veins (15% double ore)'},
{level:28,type:'passive',desc:'5% chance double ore',bonusType:'doubleOre',value:0.05},
{level:30,type:'item',desc:'Mine Duranite Ore'},
{level:33,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:35,type:'passive',desc:'Prospect: see node details',bonusType:'prospect',value:1},
{level:38,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:40,type:'item',desc:'Mine Titanex Ore'},
{level:42,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:45,type:'passive',desc:'5% chance gem drop (bonus credits)',bonusType:'gemDrop',value:0.05},
{level:48,type:'passive',desc:'+10% mining speed',bonusType:'miningSpeed',value:0.10},
{level:50,type:'item',desc:'Mine Plasmite Ore'},
{level:53,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:55,type:'passive',desc:'10% chance skip ore to bar directly',bonusType:'rockCrush',value:0.10},
{level:58,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:60,type:'item',desc:'Mine Quantite Ore'},
{level:63,type:'passive',desc:'+5% mining speed',bonusType:'miningSpeed',value:0.05},
{level:65,type:'passive',desc:'5% chance double ore',bonusType:'doubleOre',value:0.05},
{level:68,type:'passive',desc:'+10% mining speed',bonusType:'miningSpeed',value:0.10},
{level:70,type:'item',desc:'Mine Neutronium Ore'},
{level:75,type:'milestone',desc:'Mining mastery: bonuses enhanced 25%',bonusType:'masteryEnhance',value:0.25},
{level:80,type:'item',desc:'Mine Darkmatter Shards'},
{level:85,type:'passive',desc:'5% chance double ore',bonusType:'doubleOre',value:0.05},
{level:90,type:'item',desc:'Mine Voidsteel Ore'},
{level:92,type:'passive',desc:'Auto-smelt: 5% ore becomes bar',bonusType:'autoSmelt',value:0.05},
{level:95,type:'milestone',desc:'Elite miner: speed bonuses doubled',bonusType:'eliteMiner',value:1},
{level:99,type:'mastery',desc:'Astromining Mastery: +50% mining speed',bonusType:'miningSpeed',value:0.50},
],
circuitry:[
{level:1,type:'item',desc:'Smelt Stellarite Bar, Craft Scrap gear'},
{level:3,type:'passive',desc:'+3% crafting XP',bonusType:'craftXp',value:0.03},
{level:5,type:'passive',desc:'3% chance save materials',bonusType:'saveMaterials',value:0.03},
{level:7,type:'passive',desc:'+3% crafting XP',bonusType:'craftXp',value:0.03},
{level:10,type:'item',desc:'Smelt Ferrite Bar, Craft Ferrite gear'},
{level:12,type:'passive',desc:'+3% crafting XP',bonusType:'craftXp',value:0.03},
{level:15,type:'synergy',desc:'Precision Forge synergy'},
{level:17,type:'passive',desc:'3% double bar smelting chance',bonusType:'doubleBar',value:0.03},
{level:20,type:'item',desc:'Smelt Cobaltium Bar, Craft Cobalt gear'},
{level:22,type:'passive',desc:'+5% crafting XP',bonusType:'craftXp',value:0.05},
{level:25,type:'passive',desc:'3% chance save materials',bonusType:'saveMaterials',value:0.03},
{level:28,type:'passive',desc:'3% double bar chance',bonusType:'doubleBar',value:0.03},
{level:30,type:'item',desc:'Smelt Duranite Bar, Craft Duranium gear'},
{level:33,type:'passive',desc:'+5% crafting XP',bonusType:'craftXp',value:0.05},
{level:35,type:'passive',desc:'3% chance save materials',bonusType:'saveMaterials',value:0.03},
{level:38,type:'passive',desc:'+5% crafting XP',bonusType:'craftXp',value:0.05},
{level:40,type:'item',desc:'Smelt Titanex Bar, Craft Titanex gear'},
{level:43,type:'passive',desc:'5% double bar chance',bonusType:'doubleBar',value:0.05},
{level:45,type:'passive',desc:'5% chance save materials',bonusType:'saveMaterials',value:0.05},
{level:48,type:'passive',desc:'+5% crafting XP',bonusType:'craftXp',value:0.05},
{level:50,type:'item',desc:'Smelt Plasmite Bar, Craft Plasmite gear'},
{level:53,type:'passive',desc:'5% double bar chance',bonusType:'doubleBar',value:0.05},
{level:55,type:'passive',desc:'+5% crafting XP',bonusType:'craftXp',value:0.05},
{level:58,type:'passive',desc:'5% chance save materials',bonusType:'saveMaterials',value:0.05},
{level:60,type:'item',desc:'Smelt Quantite Bar, Craft Quantum gear'},
{level:63,type:'passive',desc:'+5% crafting XP',bonusType:'craftXp',value:0.05},
{level:65,type:'passive',desc:'5% double bar chance',bonusType:'doubleBar',value:0.05},
{level:68,type:'passive',desc:'5% chance save materials',bonusType:'saveMaterials',value:0.05},
{level:70,type:'item',desc:'Smelt Neutronium Bar, Craft Neutronium gear'},
{level:75,type:'milestone',desc:'Master smith: save chances doubled',bonusType:'masterSmith',value:1},
{level:80,type:'item',desc:'Smelt Darkmatter Bar, Craft Darkmatter gear'},
{level:85,type:'passive',desc:'5% chance extra item',bonusType:'extraProduct',value:0.05},
{level:90,type:'item',desc:'Smelt Voidsteel Bar, Craft Voidsteel gear'},
{level:91,type:'item',desc:'Forge Ascendant Alloy, Craft Ascendant gear'},
{level:93,type:'item',desc:'Forge Corrupted Ingot, Craft Corrupted gear'},
{level:95,type:'milestone',desc:'Elite engineer: +20% XP, 10% double bar',bonusType:'eliteEngineer',value:1},
{level:99,type:'mastery',desc:'Circuitry Mastery: all bonuses doubled',bonusType:'circuitryMastery',value:1},
],
xenocook:[
{level:1,type:'item',desc:'Cook Lichen Wrap'},
{level:3,type:'passive',desc:'+5% cooking XP',bonusType:'cookXp',value:0.05},
{level:5,type:'passive',desc:'3% chance save ingredient',bonusType:'saveIngredient',value:0.03},
{level:7,type:'passive',desc:'+3% heal bonus',bonusType:'healBonus',value:0.03},
{level:10,type:'item',desc:'Cook Nebula Smoothie'},
{level:12,type:'passive',desc:'+5% cooking XP',bonusType:'cookXp',value:0.05},
{level:15,type:'passive',desc:'3% chance cook double food',bonusType:'doubleCook',value:0.03},
{level:18,type:'passive',desc:'+5% heal bonus',bonusType:'healBonus',value:0.05},
{level:20,type:'passive',desc:'3% chance save ingredient',bonusType:'saveIngredient',value:0.03},
{level:22,type:'passive',desc:'+5% cooking XP',bonusType:'cookXp',value:0.05},
{level:25,type:'item',desc:'Cook Alien Burger'},
{level:28,type:'passive',desc:'3% chance cook double',bonusType:'doubleCook',value:0.03},
{level:30,type:'passive',desc:'+5% heal bonus',bonusType:'healBonus',value:0.05},
{level:33,type:'passive',desc:'+5% cooking XP',bonusType:'cookXp',value:0.05},
{level:35,type:'passive',desc:'5% chance save ingredient',bonusType:'saveIngredient',value:0.05},
{level:38,type:'passive',desc:'+5% heal bonus',bonusType:'healBonus',value:0.05},
{level:40,type:'passive',desc:'3% chance cook double',bonusType:'doubleCook',value:0.03},
{level:43,type:'passive',desc:'+5% cooking XP',bonusType:'cookXp',value:0.05},
{level:45,type:'item',desc:'Cook Plasma Curry'},
{level:48,type:'passive',desc:'+5% heal bonus',bonusType:'healBonus',value:0.05},
{level:50,type:'passive',desc:'5% chance cook double',bonusType:'doubleCook',value:0.05},
{level:55,type:'passive',desc:'+10% heal bonus',bonusType:'healBonus',value:0.10},
{level:60,type:'passive',desc:'5% chance save ingredient',bonusType:'saveIngredient',value:0.05},
{level:65,type:'item',desc:'Cook Void Feast'},
{level:70,type:'passive',desc:'+10% heal bonus',bonusType:'healBonus',value:0.10},
{level:75,type:'milestone',desc:'Master Chef: save/double chances doubled',bonusType:'masterChef',value:1},
{level:80,type:'passive',desc:'+10% cooking XP, +10% heal',bonusType:'healBonus',value:0.10},
{level:85,type:'passive',desc:'5% chance cook triple food',bonusType:'tripleCook',value:0.05},
{level:90,type:'milestone',desc:'Seasoned Pro: +25% heal bonus',bonusType:'healBonus',value:0.25},
{level:95,type:'milestone',desc:'Elite cook: all bonuses enhanced',bonusType:'eliteCook',value:1},
{level:99,type:'mastery',desc:'Xenocook Mastery: food heals +50%',bonusType:'healBonus',value:0.50},
],
bioforge:[
{level:1,type:'item',desc:'Craft Bio Pouch (Lichen Wraps), Scrap style armor'},
{level:3,type:'passive',desc:'+5% bioforge XP',bonusType:'bioXp',value:0.05},
{level:5,type:'passive',desc:'3% chance extra product',bonusType:'bioExtraProduct',value:0.03},
{level:8,type:'passive',desc:'+5% bioforge XP',bonusType:'bioXp',value:0.05},
{level:10,type:'item',desc:'Ferrite style armor recipes'},
{level:12,type:'passive',desc:'3% chance save materials',bonusType:'bioSaveMaterials',value:0.03},
{level:15,type:'item',desc:'Jelly Salve recipe'},
{level:18,type:'passive',desc:'+5% bioforge XP',bonusType:'bioXp',value:0.05},
{level:20,type:'item',desc:'Cobalt style armor recipes'},
{level:22,type:'passive',desc:'3% chance extra product',bonusType:'bioExtraProduct',value:0.03},
{level:25,type:'passive',desc:'3% chance save materials',bonusType:'bioSaveMaterials',value:0.03},
{level:28,type:'passive',desc:'+5% bioforge XP',bonusType:'bioXp',value:0.05},
{level:30,type:'item',desc:'Duranium style armor recipes'},
{level:33,type:'passive',desc:'+10% bioforge XP',bonusType:'bioXp',value:0.10},
{level:35,type:'passive',desc:'5% chance extra product',bonusType:'bioExtraProduct',value:0.05},
{level:38,type:'passive',desc:'+5% bioforge XP',bonusType:'bioXp',value:0.05},
{level:40,type:'item',desc:'Titanex style armor recipes'},
{level:43,type:'passive',desc:'5% save materials',bonusType:'bioSaveMaterials',value:0.05},
{level:45,type:'passive',desc:'+10% bioforge XP',bonusType:'bioXp',value:0.10},
{level:48,type:'passive',desc:'5% chance extra product',bonusType:'bioExtraProduct',value:0.05},
{level:50,type:'item',desc:'Plasmite style armor recipes'},
{level:55,type:'passive',desc:'+10% bioforge XP',bonusType:'bioXp',value:0.10},
{level:60,type:'item',desc:'Quantum style armor recipes'},
{level:65,type:'passive',desc:'+10% bioforge XP',bonusType:'bioXp',value:0.10},
{level:70,type:'item',desc:'Neutronium style armor recipes'},
{level:75,type:'milestone',desc:'Bioforge master: all bonuses +25%',bonusType:'bioforgeMaster',value:0.25},
{level:80,type:'item',desc:'Darkmatter style armor recipes'},
{level:85,type:'passive',desc:'5% extra product',bonusType:'bioExtraProduct',value:0.05},
{level:90,type:'item',desc:'Voidsteel style armor recipes'},
{level:91,type:'item',desc:'Ascendant style armor recipes'},
{level:93,type:'item',desc:'Corrupted style armor recipes'},
{level:95,type:'milestone',desc:'Elite bioforger: all bonuses enhanced',bonusType:'eliteBioforger',value:1},
{level:99,type:'mastery',desc:'Bioforge Mastery: all bonuses doubled',bonusType:'bioforgeMastery',value:1},
],
nano:[
{level:1,type:'item',desc:'Equip Scrap Nanoblade & Nano armor'},
{level:3,type:'passive',desc:'+1 Nano damage',bonusType:'combatDamage',value:1},
{level:5,type:'passive',desc:'+2% Nano accuracy',bonusType:'combatAccuracy',value:0.02},
{level:7,type:'passive',desc:'+1 Nano damage',bonusType:'combatDamage',value:1},
{level:10,type:'item',desc:'Equip Ferrite Nanoblade & Nano armor'},
{level:12,type:'passive',desc:'+2% Nano accuracy',bonusType:'combatAccuracy',value:0.02},
{level:15,type:'passive',desc:'+2 Nano damage',bonusType:'combatDamage',value:2},
{level:18,type:'passive',desc:'+2% Nano accuracy',bonusType:'combatAccuracy',value:0.02},
{level:20,type:'item',desc:'Equip Cobalt Nanoblade & Nano armor'},
{level:22,type:'passive',desc:'+2 Nano damage',bonusType:'combatDamage',value:2},
{level:25,type:'synergy',desc:'Nano Mastery synergy (+5% damage)'},
{level:28,type:'passive',desc:'+3% Nano accuracy',bonusType:'combatAccuracy',value:0.03},
{level:30,type:'item',desc:'Equip Duranium Nanoblade & Nano armor'},
{level:33,type:'passive',desc:'+3% Nano accuracy',bonusType:'combatAccuracy',value:0.03},
{level:35,type:'passive',desc:'+3 Nano damage',bonusType:'combatDamage',value:3},
{level:38,type:'passive',desc:'+3% Nano accuracy',bonusType:'combatAccuracy',value:0.03},
{level:40,type:'item',desc:'Equip Titanex Nanoblade & Nano armor'},
{level:43,type:'passive',desc:'+3% Nano accuracy',bonusType:'combatAccuracy',value:0.03},
{level:45,type:'passive',desc:'+4 Nano damage',bonusType:'combatDamage',value:4},
{level:48,type:'passive',desc:'+4 Nano damage',bonusType:'combatDamage',value:4},
{level:50,type:'item',desc:'Equip Plasmite Nanoblade & Nano armor'},
{level:55,type:'passive',desc:'+4% Nano accuracy',bonusType:'combatAccuracy',value:0.04},
{level:58,type:'passive',desc:'+5 Nano damage',bonusType:'combatDamage',value:5},
{level:60,type:'item',desc:'Equip Quantum Nanoblade & Nano armor'},
{level:65,type:'passive',desc:'+5% Nano accuracy',bonusType:'combatAccuracy',value:0.05},
{level:68,type:'passive',desc:'+6 Nano damage',bonusType:'combatDamage',value:6},
{level:70,type:'item',desc:'Equip Neutronium Nanoblade & Nano armor'},
{level:75,type:'passive',desc:'+5% Nano accuracy',bonusType:'combatAccuracy',value:0.05},
{level:80,type:'item',desc:'Equip Darkmatter Nanoblade & Nano armor'},
{level:85,type:'passive',desc:'+8 Nano damage',bonusType:'combatDamage',value:8},
{level:90,type:'item',desc:'Equip Voidsteel Nanoblade & Nano armor'},
{level:91,type:'item',desc:'Equip Ascendant Nanoblade & Nano armor'},
{level:93,type:'item',desc:'Equip Corrupted Nanoblade & Nano armor'},
{level:95,type:'passive',desc:'+5% Nano accuracy',bonusType:'combatAccuracy',value:0.05},
{level:99,type:'mastery',desc:'Nano Mastery: +15 damage, +10% accuracy',bonusType:'combatDamage',value:15},
],
tesla:[
{level:1,type:'item',desc:'Equip Scrap Coilgun & Tesla armor'},
{level:3,type:'passive',desc:'+1 Tesla damage',bonusType:'combatDamage',value:1},
{level:5,type:'passive',desc:'+2% Tesla accuracy',bonusType:'combatAccuracy',value:0.02},
{level:7,type:'passive',desc:'+1 Tesla damage',bonusType:'combatDamage',value:1},
{level:10,type:'item',desc:'Equip Ferrite Coilgun & Tesla armor'},
{level:12,type:'passive',desc:'+2% Tesla accuracy',bonusType:'combatAccuracy',value:0.02},
{level:15,type:'passive',desc:'+2 Tesla damage',bonusType:'combatDamage',value:2},
{level:18,type:'passive',desc:'+2% Tesla accuracy',bonusType:'combatAccuracy',value:0.02},
{level:20,type:'item',desc:'Equip Cobalt Coilgun & Tesla armor'},
{level:22,type:'passive',desc:'+2 Tesla damage',bonusType:'combatDamage',value:2},
{level:25,type:'synergy',desc:'Tesla Mastery synergy (+5% damage)'},
{level:28,type:'passive',desc:'+3% Tesla accuracy',bonusType:'combatAccuracy',value:0.03},
{level:30,type:'item',desc:'Equip Duranium Coilgun & Tesla armor'},
{level:33,type:'passive',desc:'+3% Tesla accuracy',bonusType:'combatAccuracy',value:0.03},
{level:35,type:'passive',desc:'+3 Tesla damage',bonusType:'combatDamage',value:3},
{level:38,type:'passive',desc:'+3% Tesla accuracy',bonusType:'combatAccuracy',value:0.03},
{level:40,type:'item',desc:'Equip Titanex Coilgun & Tesla armor'},
{level:43,type:'passive',desc:'+3% Tesla accuracy',bonusType:'combatAccuracy',value:0.03},
{level:45,type:'passive',desc:'+4 Tesla damage',bonusType:'combatDamage',value:4},
{level:48,type:'passive',desc:'+4 Tesla damage',bonusType:'combatDamage',value:4},
{level:50,type:'item',desc:'Equip Plasmite Coilgun & Tesla armor'},
{level:55,type:'passive',desc:'+4% Tesla accuracy',bonusType:'combatAccuracy',value:0.04},
{level:58,type:'passive',desc:'+5 Tesla damage',bonusType:'combatDamage',value:5},
{level:60,type:'item',desc:'Equip Quantum Coilgun & Tesla armor'},
{level:65,type:'passive',desc:'+5% Tesla accuracy',bonusType:'combatAccuracy',value:0.05},
{level:68,type:'passive',desc:'+6 Tesla damage',bonusType:'combatDamage',value:6},
{level:70,type:'item',desc:'Equip Neutronium Coilgun & Tesla armor'},
{level:75,type:'passive',desc:'+5% Tesla accuracy',bonusType:'combatAccuracy',value:0.05},
{level:80,type:'item',desc:'Equip Darkmatter Coilgun & Tesla armor'},
{level:85,type:'passive',desc:'+8 Tesla damage',bonusType:'combatDamage',value:8},
{level:90,type:'item',desc:'Equip Voidsteel Coilgun & Tesla armor'},
{level:91,type:'item',desc:'Equip Ascendant Coilgun & Tesla armor'},
{level:93,type:'item',desc:'Equip Corrupted Coilgun & Tesla armor'},
{level:95,type:'passive',desc:'+5% Tesla accuracy',bonusType:'combatAccuracy',value:0.05},
{level:99,type:'mastery',desc:'Tesla Mastery: +15 damage, +10% accuracy',bonusType:'combatDamage',value:15},
],
void:[
{level:1,type:'item',desc:'Equip Scrap Voidstaff & Void armor'},
{level:3,type:'passive',desc:'+1 Void damage',bonusType:'combatDamage',value:1},
{level:5,type:'passive',desc:'+2% Void accuracy',bonusType:'combatAccuracy',value:0.02},
{level:7,type:'passive',desc:'+1 Void damage',bonusType:'combatDamage',value:1},
{level:10,type:'item',desc:'Equip Ferrite Voidstaff & Void armor'},
{level:12,type:'passive',desc:'+2% Void accuracy',bonusType:'combatAccuracy',value:0.02},
{level:15,type:'passive',desc:'+2 Void damage',bonusType:'combatDamage',value:2},
{level:18,type:'passive',desc:'+2% Void accuracy',bonusType:'combatAccuracy',value:0.02},
{level:20,type:'item',desc:'Equip Cobalt Voidstaff & Void armor'},
{level:22,type:'passive',desc:'+2 Void damage',bonusType:'combatDamage',value:2},
{level:25,type:'synergy',desc:'Void Mastery synergy (+5% damage)'},
{level:28,type:'passive',desc:'+3% Void accuracy',bonusType:'combatAccuracy',value:0.03},
{level:30,type:'item',desc:'Equip Duranium Voidstaff & Void armor'},
{level:33,type:'passive',desc:'+3% Void accuracy',bonusType:'combatAccuracy',value:0.03},
{level:35,type:'passive',desc:'+3 Void damage',bonusType:'combatDamage',value:3},
{level:38,type:'passive',desc:'+3% Void accuracy',bonusType:'combatAccuracy',value:0.03},
{level:40,type:'item',desc:'Equip Titanex Voidstaff & Void armor'},
{level:43,type:'passive',desc:'+3% Void accuracy',bonusType:'combatAccuracy',value:0.03},
{level:45,type:'passive',desc:'+4 Void damage',bonusType:'combatDamage',value:4},
{level:48,type:'passive',desc:'+4 Void damage',bonusType:'combatDamage',value:4},
{level:50,type:'item',desc:'Equip Plasmite Voidstaff & Void armor'},
{level:55,type:'passive',desc:'+4% Void accuracy',bonusType:'combatAccuracy',value:0.04},
{level:58,type:'passive',desc:'+5 Void damage',bonusType:'combatDamage',value:5},
{level:60,type:'item',desc:'Equip Quantum Voidstaff & Void armor'},
{level:65,type:'passive',desc:'+5% Void accuracy',bonusType:'combatAccuracy',value:0.05},
{level:68,type:'passive',desc:'+6 Void damage',bonusType:'combatDamage',value:6},
{level:70,type:'item',desc:'Equip Neutronium Voidstaff & Void armor'},
{level:75,type:'passive',desc:'+5% Void accuracy',bonusType:'combatAccuracy',value:0.05},
{level:80,type:'item',desc:'Equip Darkmatter Voidstaff & Void armor'},
{level:85,type:'passive',desc:'+8 Void damage',bonusType:'combatDamage',value:8},
{level:90,type:'item',desc:'Equip Voidsteel Voidstaff & Void armor'},
{level:91,type:'item',desc:'Equip Ascendant Voidstaff & Void armor'},
{level:93,type:'item',desc:'Equip Corrupted Voidstaff & Void armor'},
{level:95,type:'passive',desc:'+5% Void accuracy',bonusType:'combatAccuracy',value:0.05},
{level:99,type:'mastery',desc:'Void Mastery: +15 damage, +10% accuracy',bonusType:'combatDamage',value:15},
],
psionics:[
{level:1,type:'item',desc:'Psionic Sense: See enemy combat level'},
{level:3,type:'passive',desc:'+3% psionic damage proc chance',bonusType:'psionicProcChance',value:0.03},
{level:5,type:'item',desc:'Telekinetic Push: Stun + knockback (right-click)'},
{level:8,type:'passive',desc:'+5% psionic bonus damage',bonusType:'psionicDamage',value:0.05},
{level:10,type:'passive',desc:'+2% psionic proc chance',bonusType:'psionicProcChance',value:0.02},
{level:12,type:'passive',desc:'Psionic Sense+: See exact enemy HP numbers',bonusType:'psionicSensePlus',value:1},
{level:15,type:'passive',desc:'+5% quest XP (Telepathy)',bonusType:'questXpBonus',value:0.05},
{level:18,type:'passive',desc:'+5% psionic damage',bonusType:'psionicDamage',value:0.05},
{level:20,type:'item',desc:'Mind Control: Turn weak enemies to allies (right-click)'},
{level:22,type:'passive',desc:'+3% psionic proc',bonusType:'psionicProcChance',value:0.03},
{level:25,type:'passive',desc:'Mind Control duration +5s',bonusType:'mindControlDuration',value:5},
{level:28,type:'passive',desc:'+5% psionic damage',bonusType:'psionicDamage',value:0.05},
{level:30,type:'passive',desc:'Mind Control HP threshold +20%',bonusType:'mindControlThreshold',value:0.20},
{level:33,type:'passive',desc:'+5% psionic damage',bonusType:'psionicDamage',value:0.05},
{level:35,type:'passive',desc:'Telepathy+: +5% all combat XP',bonusType:'allCombatXpBonus',value:0.05},
{level:40,type:'item',desc:'Mass Telekinesis: AoE psionic proc on hit'},
{level:42,type:'passive',desc:'+10% AoE damage',bonusType:'massKinesisDamage',value:0.10},
{level:45,type:'passive',desc:'Psychic Barrier: -5% damage taken',bonusType:'psychicBarrier',value:0.05},
{level:50,type:'passive',desc:'+10% psionic damage',bonusType:'psionicDamage',value:0.10},
{level:55,type:'passive',desc:'-5% damage taken',bonusType:'psychicBarrier',value:0.05},
{level:60,type:'item',desc:'Mind Shatter: Execute enemies below 15% HP'},
{level:62,type:'passive',desc:'Execute threshold 15%',bonusType:'mindShatterThreshold',value:0.15},
{level:65,type:'passive',desc:'+10% psionic damage',bonusType:'psionicDamage',value:0.10},
{level:70,type:'passive',desc:'-5% damage taken',bonusType:'psychicBarrier',value:0.05},
{level:75,type:'milestone',desc:'Psionic Ascendancy: Control stronger enemies',bonusType:'psionicAscendancy',value:1},
{level:80,type:'passive',desc:'+15% psionic damage',bonusType:'psionicDamage',value:0.15},
{level:85,type:'passive',desc:'Execute threshold +5%',bonusType:'mindShatterThreshold',value:0.05},
{level:90,type:'passive',desc:'-10% damage taken',bonusType:'psychicBarrier',value:0.10},
{level:95,type:'milestone',desc:'Psionic Supremacy: +5% all combat XP',bonusType:'allCombatXpBonus',value:0.05},
{level:99,type:'mastery',desc:'Psionics Mastery: +10% all combat XP, execute <20% HP',bonusType:'allCombatXpBonus',value:0.10},
],
chronomancy:[
{level:1,type:'item',desc:'Time Sense: See enemy attack cooldowns'},
{level:3,type:'passive',desc:'-5% enemy attack speed (Time Slow)',bonusType:'chronoSlowAura',value:0.05},
{level:5,type:'passive',desc:'+5% gathering speed (Haste)',bonusType:'chronoGatherSpeed',value:0.05},
{level:8,type:'passive',desc:'-3% enemy attack speed',bonusType:'chronoSlowAura',value:0.03},
{level:10,type:'passive',desc:'+5% gathering speed',bonusType:'chronoGatherSpeed',value:0.05},
{level:12,type:'passive',desc:'+5% crafting XP (Time Warp)',bonusType:'chronoCraftXp',value:0.05},
{level:15,type:'passive',desc:'5% chance negate damage (Temporal Shield)',bonusType:'temporalShield',value:0.05},
{level:18,type:'passive',desc:'-5% attack cooldown (Quicken)',bonusType:'chronoAttackSpeed',value:0.05},
{level:20,type:'passive',desc:'+5% crafting XP',bonusType:'chronoCraftXp',value:0.05},
{level:22,type:'passive',desc:'+5% gathering speed',bonusType:'chronoGatherSpeed',value:0.05},
{level:25,type:'passive',desc:'-5% enemy attack speed',bonusType:'chronoSlowAura',value:0.05},
{level:28,type:'passive',desc:'+3% temporal shield',bonusType:'temporalShield',value:0.03},
{level:30,type:'passive',desc:'-5% attack cooldown',bonusType:'chronoAttackSpeed',value:0.05},
{level:33,type:'passive',desc:'+5% crafting XP',bonusType:'chronoCraftXp',value:0.05},
{level:35,type:'passive',desc:'+5% gathering speed',bonusType:'chronoGatherSpeed',value:0.05},
{level:40,type:'item',desc:'Time Dilate: Freeze nearby enemies 3s (right-click, 60s CD)'},
{level:42,type:'passive',desc:'Time freeze base duration',bonusType:'timeFreezeDuration',value:3},
{level:45,type:'passive',desc:'+5% ALL timer bonuses (Temporal Mastery)',bonusType:'temporalMastery',value:0.05},
{level:50,type:'passive',desc:'-5% attack cooldown',bonusType:'chronoAttackSpeed',value:0.05},
{level:55,type:'passive',desc:'-5% enemy attack speed',bonusType:'chronoSlowAura',value:0.05},
{level:60,type:'passive',desc:'+5% temporal shield',bonusType:'temporalShield',value:0.05},
{level:65,type:'passive',desc:'+5% all timer bonuses',bonusType:'temporalMastery',value:0.05},
{level:70,type:'passive',desc:'-5% attack cooldown',bonusType:'chronoAttackSpeed',value:0.05},
{level:75,type:'milestone',desc:'Chrono Adept: freeze duration doubled',bonusType:'chronoAdept',value:1},
{level:80,type:'passive',desc:'+10% gathering speed',bonusType:'chronoGatherSpeed',value:0.10},
{level:85,type:'passive',desc:'+5% temporal shield',bonusType:'temporalShield',value:0.05},
{level:90,type:'passive',desc:'+10% all timer bonuses',bonusType:'temporalMastery',value:0.10},
{level:95,type:'milestone',desc:'Time Lord: all chrono bonuses +25%',bonusType:'timeLord',value:0.25},
{level:99,type:'mastery',desc:'Chronomancy Mastery: Time-Loop Dungeon, +20% all timers',bonusType:'temporalMastery',value:0.20},
],
};

function getSkillBonus(skill,bonusType){
    var unlocks=SKILL_UNLOCKS[skill];if(!unlocks)return 0;
    var lvl=player.skills[skill]?player.skills[skill].level:1;
    var total=0;
    for(var i=0;i<unlocks.length;i++){var u=unlocks[i];if(u.level>lvl)continue;if(u.bonusType===bonusType&&(u.type==='passive'||u.type==='mastery'||u.type==='milestone'))total+=u.value;}
    if(hasPrestigePassive(9))total*=1.20;
    return total;
}
function hasSkillMilestone(skill,bonusType){
    var unlocks=SKILL_UNLOCKS[skill];if(!unlocks)return false;
    var lvl=player.skills[skill]?player.skills[skill].level:1;
    for(var i=0;i<unlocks.length;i++){var u=unlocks[i];if(u.level>lvl)continue;if(u.bonusType===bonusType&&(u.type==='milestone'||u.type==='mastery'))return true;}
    return false;
}

function checkSynergies() {
    SYNERGY_DEFS.forEach(function(syn) {
        if (player.unlockedSynergies.indexOf(syn.id) >= 0) return;
        if (syn.requirement()) {
            player.unlockedSynergies.push(syn.id);
            EventBus.emit('chat', { type: 'skill', text: 'Synergy unlocked: ' + syn.name + ' - ' + syn.desc });
            playSound('mine_success');
        }
    });
}

function hasSynergy(id) {
    return player.unlockedSynergies.indexOf(id) >= 0;
}

function getSynergyValue(type, context) {
    var total = 0;
    SYNERGY_DEFS.forEach(function(syn) {
        if (player.unlockedSynergies.indexOf(syn.id) < 0) return;
        if (syn.type !== type) return;
        // For combat_damage, check style match
        if (type === 'combat_damage' && context && context.style && syn.style !== context.style) return;
        // For xp_bonus, check skill match
        if (type === 'xp_bonus' && context && context.skill && syn.skill !== context.skill) return;
        total += syn.value;
    });
    return total;
}

function startGathering(node){
    if(!hasEmptySlot()){EventBus.emit('chat',{type:'info',text:'Your inventory is full!'});return;}
    const skillName=node.type==='astromining'?'astromining':'bioforge';
    if(player.skills[skillName].level<node.level){EventBus.emit('chat',{type:'info',text:'You need '+SKILL_DEFS[skillName].name+' level '+node.level+' to gather this.'});return;}
    const dist=player.mesh.position.distanceTo(node.position);
    if(dist>3){moveTo(node.position);player.pendingGather=node;return;}
    beginGathering(node);
}

function getBestTool(skillName){
    var bestTool=null,bestSpeed=0;
    player.inventory.forEach(function(slot){
        if(!slot)return;
        var def=getItem(slot.itemId);
        if(!def||def.type!==ItemType.TOOL)return;
        if(!def.toolSkill)return;
        // astromining nodes use astromining tools, bioforge nodes use bioforge tools
        if(def.toolSkill===skillName&&def.gatherSpeed>bestSpeed){bestSpeed=def.gatherSpeed;bestTool=def;}
    });
    return bestTool;
}

function beginGathering(node){
    player.isGathering=true;player.gatherTarget=node;player.gatherProgress=0;
    const skillName=node.type==='astromining'?'astromining':'bioforge';
    const ld=player.skills[skillName].level-node.level;
    var baseDuration=Math.max(1.5,4-ld*0.1);
    // Apply tool speed bonus
    var tool=getBestTool(skillName);
    if(tool&&tool.gatherSpeed>1){baseDuration=baseDuration/tool.gatherSpeed;}
    var miningSpeedBonus=getSkillBonus(skillName,'miningSpeed');if(hasSkillMilestone(skillName,'eliteMiner'))miningSpeedBonus*=2;if(hasSkillMilestone(skillName,'masteryEnhance'))miningSpeedBonus*=1.25;if(miningSpeedBonus>0)baseDuration=baseDuration/(1+miningSpeedBonus);
    player.gatherDuration=Math.max(0.8,baseDuration);
    if(hasPrestigePassive(3))player.gatherDuration*=0.9;
    // Chronomancy gathering speed bonus
    if(player.skills.chronomancy){
        var chronoGatherBonus=getSkillBonus('chronomancy','chronoGatherSpeed');
        var temporalBonus=getSkillBonus('chronomancy','temporalMastery');
        if(hasSkillMilestone('chronomancy','timeLord')){chronoGatherBonus*=1.25;temporalBonus*=1.25;}
        if(chronoGatherBonus+temporalBonus>0){
            player.gatherDuration=player.gatherDuration/(1+chronoGatherBonus+temporalBonus);
            gainXp('chronomancy',Math.round(2+player.skills.chronomancy.level*0.1));
        }
    }
    player.activeTool=tool||null;
    const dx=node.position.x-player.mesh.position.x,dz=node.position.z-player.mesh.position.z;
    player.mesh.rotation.y=Math.atan2(dx,dz);
    if(tool&&tool.gatherSpeed>1){EventBus.emit('chat',{type:'info',text:'Using '+tool.name+' ('+Math.round(tool.gatherSpeed*100)+'% speed).'});}
    EventBus.emit('gatherStart',{node,duration:player.gatherDuration});
}

function stopGathering(){player.isGathering=false;player.gatherTarget=null;player.gatherProgress=0;EventBus.emit('gatherStop');}

function updateGathering(){
    if(player.pendingGather&&!player.isMoving){
        const node=player.pendingGather;player.pendingGather=null;
        if(!node.depleted)beginGathering(node);return;
    }
    if(!player.isGathering||!player.gatherTarget)return;
    const node=player.gatherTarget;
    if(node.depleted){stopGathering();return;}
    player.gatherProgress+=GameState.deltaTime;
    // Instant gather check (boss tools: 1% per tick)
    if(player.activeTool&&player.activeTool.instantChance&&Math.random()<player.activeTool.instantChance){
        player.gatherProgress=player.gatherDuration;
        spawnParticles(node.position.clone().add(new THREE.Vector3(0,1.5,0)),0xff00ff,20,4,1.0,0.15);
        EventBus.emit('chat',{type:'skill',text:'Instant gather! Your '+player.activeTool.name+' surges with power!'});
    }
    // Mining tick sparks
    if(Math.random()<GameState.deltaTime*2){spawnParticles(node.position.clone().add(new THREE.Vector3((Math.random()-0.5)*0.5,0.5+Math.random(),(Math.random()-0.5)*0.5)),0xffaa44,3,1.5,0.3,0.05);playSound('mine');}
    var gatherColors={astromining:0xff8844,bioforge:0x44ffaa,fishing:0x4488ff};var gc=gatherColors[node.type]||0xffcc44;if(Math.random()<GameState.deltaTime*4)spawnParticles(node.position.clone().add(new THREE.Vector3((Math.random()-0.5)*0.8,0.8+Math.random()*0.5,(Math.random()-0.5)*0.8)),gc,2,2,0.4,0.04);
    EventBus.emit('gatherProgress',{progress:player.gatherProgress/player.gatherDuration});
    if(player.gatherProgress>=player.gatherDuration){
        const skillName=node.type==='astromining'?'astromining':'bioforge';
        const success=Math.random()<0.85+player.skills[skillName].level*0.002;
        // Mining sparks
        const sparkColor=node.type==='astromining'?0xff8844:0x44ffaa;
        spawnParticles(node.position.clone().add(new THREE.Vector3(0,1,0)),sparkColor,15,3,0.6,0.1);
        spawnParticles(node.position.clone().add(new THREE.Vector3(0,0.5,0)),0xffcc44,8,2,0.4,0.06);
        if(success){
            var gatherQty = 1;
            // Double ore synergy check
            var doubleChance = getSynergyValue('gathering_bonus', {});
            if (doubleChance > 0 && Math.random() < doubleChance) { gatherQty = 2; }
            var passiveDoubleOre=getSkillBonus(skillName,'doubleOre');if(hasSkillMilestone(skillName,'masteryEnhance'))passiveDoubleOre*=1.25;if(gatherQty===1&&passiveDoubleOre>0&&Math.random()<passiveDoubleOre)gatherQty=2;
            if(addItem(node.resource,gatherQty)){const def=getItem(node.resource);gainXp(skillName,node.xp);if(gatherQty>1){EventBus.emit('chat',{type:'skill',text:'You gather some '+def.name+' x'+gatherQty+'! (Rich Veins!)'});createLootToast(def.name+' x'+gatherQty+' (double!)',def.icon);}else{EventBus.emit('chat',{type:'skill',text:'You gather some '+def.name+'.'});createLootToast(def.name,def.icon);}updateQuestProgress('gather',{item:node.resource});
            var gemChance=getSkillBonus(skillName,'gemDrop');if(gemChance>0&&Math.random()<gemChance){var gemCr=Math.floor(10+node.level*5);player.credits+=gemCr;EventBus.emit('chat',{type:'skill',text:'You find a gem worth '+gemCr+' credits!'});}
            var autoSmeltChance=getSkillBonus(skillName,'autoSmelt');var barId=ORE_TO_BAR[node.resource];if(barId&&autoSmeltChance>0&&Math.random()<autoSmeltChance){removeItem(node.resource,1);addItem(barId,1);EventBus.emit('chat',{type:'skill',text:'Auto-smelt! Your ore transforms into a bar!'});}}
            playSound('mine_success');
        } else{EventBus.emit('chat',{type:'info',text:'You fail to gather anything useful.'});playSound('mine');}
        node.depleted=true;node.respawnTimer=node.respawnTime;node.mesh.visible=false;
        stopGathering();
    }
}

function getAvailableRecipes(skill){
    return Object.entries(RECIPES).filter(([,r])=>r.skill===skill).map(([id,r])=>{
        const canCraft=player.skills[r.skill].level>=r.level&&Object.entries(r.input).every(([iid,qty])=>hasItem(iid,qty));
        return{id,...r,canCraft};
    });
}

function craft(recipeId){
    const recipe=RECIPES[recipeId];if(!recipe)return false;
    const isProduction=recipe.skill==='circuitry'||recipe.skill==='bioforge'||recipe.skill==='xenocook';
    if(isProduction&&(!craftingFromStation||(player.currentArea!=='bio-lab'&&player.currentArea!=='station-hub'))){EventBus.emit('chat',{type:'info',text:'You must use a processing station in the Bio-Lab to craft this. Right-click a station.'});return false;}
    if(player.skills[recipe.skill].level<recipe.level){EventBus.emit('chat',{type:'info',text:'You need '+SKILL_DEFS[recipe.skill].name+' level '+recipe.level+'.'});return false;}
    for(const[iid,qty]of Object.entries(recipe.input)){if(!hasItem(iid,qty)){EventBus.emit('chat',{type:'info',text:'You need '+qty+'x '+getItem(iid).name+'.'});return false;}}
    if(!hasEmptySlot()){EventBus.emit('chat',{type:'info',text:'Your inventory is full!'});return false;}
    for(const[iid,qty]of Object.entries(recipe.input))removeItem(iid,qty);
    for(const[iid,qty]of Object.entries(recipe.output)){
        addItem(iid,qty);
        var cdef=getItem(iid);
        // Apply durability synergy to crafted gear
        if(cdef&&(cdef.type===ItemType.WEAPON||cdef.type===ItemType.ARMOR)){
            var durType=cdef.type===ItemType.WEAPON?'durability_bonus_weapon':'durability_bonus_armor';
            var durBonus=getSynergyValue(durType,{});
            for(var ci=0;ci<player.inventory.length;ci++){
                if(player.inventory[ci]&&player.inventory[ci].itemId===iid&&player.inventory[ci].durability===undefined){
                    var baseDur=initDurability(cdef);
                    var bonusDur=Math.round(baseDur.maxDurability*(1+durBonus));
                    player.inventory[ci].durability=bonusDur;
                    player.inventory[ci].maxDurability=bonusDur;
                    break;
                }
            }
        }
        EventBus.emit('chat',{type:'skill',text:'You craft: '+cdef.name+' x'+qty+'.'});createLootToast(cdef.name+' x'+qty,cdef.icon);
    }
    // Apply XP bonus synergy
    var xpAmount=recipe.xp;
    var xpBonus=getSynergyValue('xp_bonus',{skill:recipe.skill});
    xpBonus+=getSkillBonus(recipe.skill,'craftXp')+getSkillBonus(recipe.skill,'cookXp')+getSkillBonus(recipe.skill,'bioXp');
    xpAmount=Math.round(xpAmount*(1+xpBonus));
    // Chronomancy crafting XP bonus
    if(player.skills.chronomancy){
        var chronoCraftB=getSkillBonus('chronomancy','chronoCraftXp');
        var chronoTempB=getSkillBonus('chronomancy','temporalMastery');
        if(hasSkillMilestone('chronomancy','timeLord')){chronoCraftB*=1.25;chronoTempB*=1.25;}
        if(chronoCraftB+chronoTempB>0){
            xpAmount=Math.round(xpAmount*(1+chronoCraftB+chronoTempB));
            gainXp('chronomancy',Math.round(recipe.xp*0.15));
        }
    }
    gainXp(recipe.skill,xpAmount);updateQuestProgress('craft',{recipe:recipeId});playSound('mine_success');EventBus.emit('craftComplete',{recipeId});spawnParticles(player.mesh.position.clone().add(new THREE.Vector3(0,2,0)),0x44ddff,15,3,0.7,0.1);spawnParticles(player.mesh.position.clone().add(new THREE.Vector3(0,1.5,0)),0xffcc44,10,2,0.5,0.06);triggerScreenFlash('rgba(0,200,255,0.2)',150);
    // Crafting passive bonuses
    if(recipe.skill==='circuitry'){var saveChance=getSkillBonus('circuitry','saveMaterials');if(hasSkillMilestone('circuitry','masterSmith'))saveChance*=2;if(saveChance>0&&Math.random()<saveChance){for(var ri in recipe.input){addItem(ri,1);break;}EventBus.emit('chat',{type:'skill',text:'Material saved! You kept some resources.'});}}
    if(recipeId.indexOf('smelt_')===0){var dblBar=getSkillBonus('circuitry','doubleBar');if(hasSkillMilestone('circuitry','eliteEngineer'))dblBar+=0.10;if(dblBar>0&&Math.random()<dblBar){for(var oi in recipe.output){addItem(oi,1);}EventBus.emit('chat',{type:'skill',text:'Double bar! You produced an extra bar.'});}}
    if(recipe.skill==='bioforge'){var bioExtra=getSkillBonus('bioforge','bioExtraProduct');if(bioExtra>0&&Math.random()<bioExtra){for(var bi in recipe.output){addItem(bi,1);}EventBus.emit('chat',{type:'skill',text:'Extra product! Bioforge yields bonus output.'});}var bioSave=getSkillBonus('bioforge','bioSaveMaterials');if(bioSave>0&&Math.random()<bioSave){for(var bri in recipe.input){addItem(bri,1);break;}EventBus.emit('chat',{type:'skill',text:'Material saved! Bioforge conserves resources.'});}}
    if(recipe.skill==='xenocook'){var saveIng=getSkillBonus('xenocook','saveIngredient');if(hasSkillMilestone('xenocook','masterChef'))saveIng*=2;if(saveIng>0&&Math.random()<saveIng){for(var ci in recipe.input){addItem(ci,1);break;}EventBus.emit('chat',{type:'skill',text:'Ingredient saved!'});}var dblCook=getSkillBonus('xenocook','doubleCook');if(hasSkillMilestone('xenocook','masterChef'))dblCook*=2;if(dblCook>0&&Math.random()<dblCook){for(var co in recipe.output){addItem(co,1);}EventBus.emit('chat',{type:'skill',text:'Double cook! Extra portion prepared.'});}var triCook=getSkillBonus('xenocook','tripleCook');if(triCook>0&&Math.random()<triCook){for(var to in recipe.output){addItem(to,2);}EventBus.emit('chat',{type:'skill',text:'Triple cook! Two extra portions!'}); }}
    return true;
}

// ========================================
// Combat System
// ========================================
const TRIANGLE={nano:{strong:'tesla',weak:'void'},tesla:{strong:'void',weak:'nano'},void:{strong:'nano',weak:'tesla'}};
const STYLE_BONUS=0.15;
const AUTO_ATTACK_INTERVAL=2.4;
const GCD=1.8;
let gcdTimer=0;
const activeEffects=[];
const cooldowns={};

const ABILITIES = {
    nano_basic:{id:'nano_basic',name:'Swarm Bite',style:'nano',type:'basic',cost:0,cooldown:0,damage:1.0,range:4,desc:'Command nanobots to bite.',icon:'\uD83E\uDDA0'},
    tesla_basic:{id:'tesla_basic',name:'Spark',style:'tesla',type:'basic',cost:0,cooldown:0,damage:1.0,range:8,desc:'Fire a spark.',icon:'\u26A1'},
    void_basic:{id:'void_basic',name:'Gravity Bolt',style:'void',type:'basic',cost:0,cooldown:0,damage:1.1,range:10,desc:'Compressed gravity bolt.',icon:'\uD83C\uDF11'},
};

function getStyleAbilities(style){return[ABILITIES[style+'_basic'],ABILITIES[style+'_threshold'],ABILITIES[style+'_ultimate']].filter(Boolean);}
function getCooldown(abilityId){return cooldowns[abilityId]||0;}
function switchStyle(style){player.combatStyle=style;EventBus.emit('styleChanged',style);EventBus.emit('chat',{type:'system',text:'Combat style: '+style.charAt(0).toUpperCase()+style.slice(1)});}

function applyDamageToEnemy(enemy,damage){
    enemy.hp-=damage;
    if (enemy.alive && enemy.state !== 'aggro') {
        enemy.state = 'aggro'; enemy.wanderTarget = null;
    }
    const hitPos=enemy.mesh.position.clone().add(new THREE.Vector3(0,1.5,0));
    const styleColors={nano:0x44ff88,tesla:0x44aaff,void:0xaa44ff};
    const vfxStyle=player.equipment.weapon?player.equipment.weapon.style:'nano';
    spawnParticles(hitPos,styleColors[vfxStyle]||0xff4444,8,2,0.6);
    spawnDirectedParticles(player.mesh.position,enemy.mesh.position,styleColors[vfxStyle]||0xff4444,5,6,0.4);
    spawnImpactRing(enemy.mesh.position.clone().add(new THREE.Vector3(0,0.3,0)),styleColors[vfxStyle]||0xff4444);
    spawnCombatVFX(hitPos,vfxStyle,'hit');
    enemy.hitFlash=0.15;
    playSound('hit');
    // Hit splat instead of float text
    var isBigHit=damage>enemy.maxHp*0.3;
    createHitSplat(hitPos,damage,isBigHit?'crit':'damage');
    if(isBigHit){
        spawnParticles(hitPos,0xffffff,25,5,0.5,0.12);
        spawnParticles(hitPos,0xffcc44,10,3,0.6,0.08);
        var critScale=Math.min(1.0,damage/enemy.maxHp);
        triggerScreenShake(0.2+critScale*0.4,0.15+critScale*0.15);
        triggerScreenFlash('rgba(255,255,255,0.08)',60);
        spawnStyleBurst(hitPos,vfxStyle);
    }
    EventBus.emit('enemyDamaged',{enemy,damage});
    // Psionic Mind Shatter execute
    if(player.psionicsUnlocked&&player.skills.psionics&&enemy.hp>0&&enemy.alive){
        var executeThreshold=getSkillBonus('psionics','mindShatterThreshold');
        if(executeThreshold>0&&(enemy.hp/enemy.maxHp)<executeThreshold){
            spawnParticles(enemy.mesh.position.clone().add(new THREE.Vector3(0,2,0)),0xff00ff,30,5,1.0,0.15);
            EventBus.emit('chat',{type:'combat',text:'Mind Shatter! '+enemy.name+"'s psyche obliterated!"});
            enemy.hp=0;
        }
    }
    // Broadcast attack to multiplayer
    if(enemy.enemyId&&window.AsterianMP&&window.AsterianMP.sendAttack){
        window.AsterianMP.sendAttack(enemy.enemyId,damage,vfxStyle);
    }
    if(enemy.hp<=0){enemy.hp=0;killEnemy(enemy);}
}

function killEnemy(enemy){
    enemy.alive=false;enemy.respawnTimer=enemy.respawnTime;
    // Broadcast kill to multiplayer
    if(enemy.enemyId&&window.AsterianMP&&window.AsterianMP.sendKill){
        window.AsterianMP.sendKill(enemy.enemyId);
    }
    // Death dissolve animation instead of instant hide
    enemy.deathAnim=1.0; // 1 second dissolve
    // Death explosion particles — bigger burst with enemy-colored shards
    const deathPos=enemy.mesh.position.clone().add(new THREE.Vector3(0,1,0));
    spawnParticles(deathPos,0xff4444,30,5,1.0,0.14);
    spawnParticles(deathPos,0xffcc44,18,3.5,0.9,0.1);
    spawnParticles(deathPos,0xffffff,8,6,0.4,0.06);
    // Expanding death ring at feet
    var deathRingGeo=new THREE.RingGeometry(0.2,0.8,16);
    var deathRingMat=new THREE.MeshBasicMaterial({color:0xff6644,transparent:true,opacity:0.7,side:THREE.DoubleSide});
    var deathRing=new THREE.Mesh(deathRingGeo,deathRingMat);
    deathRing.position.copy(enemy.mesh.position).add(new THREE.Vector3(0,0.2,0));deathRing.rotation.x=-Math.PI/2;
    GameState.scene.add(deathRing);
    particles.push({mesh:deathRing,velocity:new THREE.Vector3(0,0,0),life:0.6,maxLife:0.6,gravity:0,isRing:true,expandSpeed:10});
    // Kill streak
    killStreak.count++;killStreak.timer=3.0;
    var ksEl=document.getElementById('kill-streak');
    if(ksEl&&killStreak.count>=2){ksEl.textContent='x'+killStreak.count+' KILLS';ksEl.style.opacity='1';ksEl.style.fontSize=Math.min(40,28+killStreak.count*2)+'px';}
    if(enemy.isBoss||enemy.isDungeonBoss)triggerScreenFlash('rgba(255,255,255,0.2)',100);
    if(player.combatTarget===enemy){player.combatTarget=null;player.inCombat=false;}
    // Drop loot on ground instead of directly to inventory
    if(enemy.lootTable){
        enemy.lootTable.forEach(loot=>{
            var dropChance=loot.chance;
            if(hasPrestigePassive(7))dropChance*=1.10;
            if(Math.random()<dropChance){
                const qty=loot.min+Math.floor(Math.random()*(loot.max-loot.min+1));
                spawnGroundItem(enemy.mesh.position,loot.itemId,qty);
            }
        });
        var cd=Math.floor(enemy.level*(2+Math.random()*3));
        if(hasPrestigePassive(4))cd=Math.round(cd*1.15);
        player.credits+=cd;EventBus.emit('chat',{type:'loot',text:'Loot: '+cd+' Credits'});EventBus.emit('creditsChanged');
    }
    const wepStyle=player.equipment.weapon?player.equipment.weapon.style:'nano';
    var xpAmount = enemy.level * 5;
    if (enemy.isDungeonEnemy) xpAmount = Math.round(xpAmount * 1.25); // 25% dungeon XP bonus
    if(enemy.isCorrupted)xpAmount*=2;
    gainXp(wepStyle, xpAmount);
    updateQuestProgress('kill',{type:enemy.type});
    player.deathRecap.killCount++;
    // Bestiary tracking (Feature 6)
    if(!player.bestiary[enemy.type])player.bestiary[enemy.type]={name:enemy.name,kills:0,level:enemy.level};
    player.bestiary[enemy.type].kills++;
    EventBus.emit('enemyKilled',{enemy});EventBus.emit('chat',{type:'combat',text:'You defeat the '+enemy.name+'!'});
    // Dungeon tracking
    if (enemy.isDungeonEnemy && !enemy.isDungeonBoss) {
        DungeonState.enemiesAlive--;
        checkBossGateUnlock();
        updateDungeonHUD();
    }
    if(enemy.isTimeLoopBoss&&player.timeLoopData.active){
        player.timeLoopData.active=false;
        var tlXp=Math.round(5000+player.timeLoopData.attempts*500);
        gainXp('chronomancy',tlXp);
        EventBus.emit('chat',{type:'system',text:'TEMPORAL RIFT CONQUERED! Attempt '+(player.timeLoopData.attempts+1)+'. Chronomancy XP: +'+tlXp});
        createLootToast('Temporal Rift Cleared!','\u23F3');
        player.timeLoopData.attempts=0;player.timeLoopData.damageBonus=0;
        setTimeout(function(){exitDungeon();},2000);
        return;
    }
    if (enemy.isDungeonBoss) {
        EventBus.emit('chat', { type: 'system', text: 'Floor ' + DungeonState.floor + ' Complete!' });
        createLootToast('Floor ' + DungeonState.floor + ' Complete!', '\u2B50');
        if (DungeonState.floor >= DungeonState.maxFloorReached) DungeonState.maxFloorReached = DungeonState.floor;
        setTimeout(advanceDungeonFloor, 2000);
    }
}

function calculateDamage(defender){
    const weapon=player.equipment.weapon;
    const weaponDmg=weapon?weapon.damage:5;
    const style=weapon?weapon.style:'nano';
    const level=player.skills[style].level;
    const accuracy=weapon?weapon.accuracy:60;
    // Apply accuracy synergy bonus
    var accuracyBonus = getSynergyValue('combat_accuracy', {});
    var passiveAccBonus=getSkillBonus(style,'combatAccuracy');
    const hitChance=Math.min(0.95,(accuracy/100+level*0.005+accuracyBonus+passiveAccBonus)*(player.styleAccMult||1));
    if(Math.random()>hitChance)return{hit:false,damage:0};
    const maxHit=weaponDmg+level*0.5;
    var dmg=1+Math.random()*(maxHit-1);
    // Apply combat damage synergy bonus
    var dmgBonus = getSynergyValue('combat_damage', { style: style });
    dmg *= (1 + dmgBonus);
    // Style set bonus
    if(player.styleDmgMult>1)dmg*=player.styleDmgMult;
    if(defender.combatStyle){
        const tri=TRIANGLE[style];
        if(tri.strong===defender.combatStyle)dmg*=1.15;
        else if(tri.weak===defender.combatStyle)dmg*=0.85;
    }
    if(defender.defense)dmg=Math.max(1,dmg-defender.defense*0.3);
    dmg+=getSkillBonus(style,'combatDamage');
    if(player.timeLoopData&&player.timeLoopData.active&&player.timeLoopData.damageBonus>0)dmg*=(1+player.timeLoopData.damageBonus);
    // Prestige damage bonus
    if(player.prestige.tier>0) dmg*=getPrestigeDamageMultiplier();
    return{hit:true,damage:Math.round(dmg)};
}

function useAbility(abilityId){
    // OSRS style: no abilities, auto-attack only
}

function attackTarget(enemy){
    if(player.combatTarget===enemy&&player.inCombat)return;
    if(!player.inCombat){player.deathRecap={lastDamageSource:'',totalDamageTaken:0,combatDuration:0,killCount:0};}
    player.combatTarget=enemy;player.autoAttackTimer=Math.max(player.autoAttackTimer,0.6);player.inCombat=true;EventBus.emit('targetChanged',enemy);
    checkTutorialEvent('combatStarted');
}

// ----------------------------------------
// Prestige Skill Abilities
// ----------------------------------------
function performTKPush(enemy){
    if(!enemy.alive)return;
    var dist=player.mesh.position.distanceTo(enemy.mesh.position);
    if(dist>12)return;
    player.psionicCooldowns.tkPush=8;
    var stunDur=2+player.skills.psionics.level*0.02;
    enemy.stunTimer=Math.max(enemy.stunTimer||0,stunDur);
    var tkDmg=Math.round(5+player.skills.psionics.level*0.5);
    applyDamageToEnemy(enemy,tkDmg);
    var dir=enemy.mesh.position.clone().sub(player.mesh.position).normalize();
    var newPos=enemy.mesh.position.clone().add(dir.multiplyScalar(3));
    if(!DungeonState.active||isDungeonValidPosition(newPos.x,newPos.z)){enemy.mesh.position.copy(newPos);}
    spawnParticles(enemy.mesh.position.clone().add(new THREE.Vector3(0,1.5,0)),0xff44ff,20,4,0.8,0.12);
    EventBus.emit('chat',{type:'combat',text:'Telekinetic Push! '+enemy.name+' is stunned!'});
    gainXp('psionics',Math.round(10+enemy.level*0.5));
    playSound('hit');
}

function performMindControl(enemy){
    if(!enemy.alive||player.mindControlTarget)return;
    player.psionicCooldowns.mindControl=45;
    player.mindControlTarget=enemy;
    var baseDuration=10+getSkillBonus('psionics','mindControlDuration');
    player.mindControlTimer=baseDuration;
    enemy._prevState=enemy.state;
    enemy.state='mind_controlled';
    enemy.mesh.traverse(function(c){
        if(c.material&&c.material.color){
            c.material._origColor=c.material.color.clone();
            c.material.color.lerp(new THREE.Color(0xff44ff),0.5);
            if(c.material.emissive){c.material._origEmissive=c.material.emissive.clone();c.material.emissive=new THREE.Color(0x440044);c.material.emissiveIntensity=0.3;}
        }
    });
    spawnParticles(enemy.mesh.position.clone().add(new THREE.Vector3(0,2,0)),0xff44ff,30,5,1.0,0.15);
    EventBus.emit('chat',{type:'combat',text:'Mind Control! '+enemy.name+' fights for you!'});
    gainXp('psionics',Math.round(20+enemy.level));
    playSound('levelup');
}

function releaseMindControl(){
    if(!player.mindControlTarget)return;
    var enemy=player.mindControlTarget;
    enemy.mesh.traverse(function(c){
        if(c.material&&c.material._origColor){
            c.material.color.copy(c.material._origColor);
            delete c.material._origColor;
            if(c.material._origEmissive){c.material.emissive.copy(c.material._origEmissive);c.material.emissiveIntensity=0;delete c.material._origEmissive;}
        }
    });
    if(enemy.alive)enemy.state='idle';
    player.mindControlTarget=null;
    player.mindControlTimer=0;
    EventBus.emit('chat',{type:'info',text:'Mind control fades...'});
}

function performTimeDilate(){
    player.psionicCooldowns.timeDilate=60;
    var freezeDur=getSkillBonus('chronomancy','timeFreezeDuration');
    if(freezeDur<=0)freezeDur=3;
    if(hasSkillMilestone('chronomancy','chronoAdept'))freezeDur*=2;
    var frozenCount=0;
    GameState.enemies.forEach(function(enemy){
        if(!enemy.alive)return;
        if(enemy.mesh.position.distanceTo(player.mesh.position)>10)return;
        if(enemy.state==='mind_controlled')return;
        enemy.stunTimer=Math.max(enemy.stunTimer||0,freezeDur);
        spawnParticles(enemy.mesh.position.clone().add(new THREE.Vector3(0,1,0)),0x44ffff,15,3,0.6,0.1);
        frozenCount++;
    });
    spawnParticles(player.mesh.position.clone().add(new THREE.Vector3(0,0.5,0)),0x44ffff,40,8,1.5,0.15);
    EventBus.emit('chat',{type:'combat',text:'Time Dilate! '+frozenCount+' enemies frozen for '+freezeDur.toFixed(1)+'s!'});
    gainXp('chronomancy',Math.round(15+frozenCount*5));
    playSound('portal');
}

function updatePrestigeTimers(){
    var dt=GameState.deltaTime;
    if(player.psionicCooldowns){
        for(var k in player.psionicCooldowns){
            if(player.psionicCooldowns[k]>0)player.psionicCooldowns[k]-=dt;
        }
    }
    if(player.mindControlTimer>0){
        player.mindControlTimer-=dt;
        if(player.mindControlTimer<=0)releaseMindControl();
    }
    if(player.prestige&&player.prestige.undyingCooldown>0)player.prestige.undyingCooldown-=GameState.deltaTime;
}

// ========================================
// Prestige / New Game+ Core Functions
// ========================================
function getTotalLevel(){
    var total=0;
    for(var sk in player.skills){
        if(SKILL_DEFS[sk]&&SKILL_DEFS[sk].type!=='prestige') total+=player.skills[sk].level;
    }
    return total;
}

function hasPrestigePassive(tierId){
    return player.prestige.tier>=tierId;
}

function getPrestigeXpMultiplier(){
    var tier=player.prestige.tier;
    if(tier<=0)return 1;
    var mult=1+tier*PRESTIGE_CONFIG.xpRatePerTier;
    if(hasPrestigePassive(10))mult+=0.50;
    if(player.prestige.xpBoostEnd>Date.now())mult*=2;
    return mult;
}

function getPrestigeDamageMultiplier(){
    var tier=player.prestige.tier;
    if(tier<=0)return 1;
    var mult=1+tier*PRESTIGE_CONFIG.damagePerTier;
    if(hasPrestigePassive(10))mult+=tier*PRESTIGE_CONFIG.damagePerTier;
    return mult;
}

function getPrestigeReduction(){
    var tier=player.prestige.tier;
    if(tier<=0)return 0;
    var red=tier*PRESTIGE_CONFIG.reductionPerTier;
    if(hasPrestigePassive(10))red*=2;
    return Math.min(red,0.30);
}

function depositEquipToBank(equippedItem){
    if(!equippedItem)return;
    var bankItem={itemId:equippedItem.id,quantity:1};
    if(equippedItem.durability!==undefined){bankItem.durability=equippedItem.durability;bankItem.maxDurability=equippedItem.maxDurability;}
    for(var i=0;i<bankStorage.length;i++){
        if(bankStorage[i]===null){bankStorage[i]=bankItem;return;}
    }
    EventBus.emit('chat',{type:'info',text:'Bank full! '+equippedItem.name+' was lost.'});
}

function depositInvToBank(invSlot){
    if(!invSlot)return;
    // Try stacking first
    for(var i=0;i<bankStorage.length;i++){
        if(bankStorage[i]&&bankStorage[i].itemId===invSlot.itemId){
            bankStorage[i].quantity+=invSlot.quantity;
            return;
        }
    }
    for(var j=0;j<bankStorage.length;j++){
        if(bankStorage[j]===null){
            bankStorage[j]={itemId:invSlot.itemId,quantity:invSlot.quantity};
            return;
        }
    }
    EventBus.emit('chat',{type:'info',text:'Bank full! '+invSlot.itemId+' was lost.'});
}

function confirmPrestige(){
    var totalLvl=getTotalLevel();
    var points=totalLvl*PRESTIGE_CONFIG.pointsPerTotalLevel;
    if(!confirm('PRESTIGE to Tier '+(player.prestige.tier+1)+'?\n\nYou earn: '+points+' Prestige Points\n\nRESET: All 7 base skills, equipment, inventory, credits, synergies, quests, dungeon progress, shop economy.\n\nKEPT: Bank (equipment/inventory moved there first), Psionics, Chronomancy, Bestiary, Prestige unlocks.\n\nThis cannot be undone!'))return;
    executePrestige(points);
}

function executePrestige(points){
    var tier=player.prestige.tier+1;
    var runTime=Date.now()-player.prestige.currentRunStart;

    // Track stats
    player.prestige.totalPrestiges++;
    player.prestige.totalLevelsGained+=getTotalLevel();
    if(runTime<player.prestige.fastestPrestigeTime)player.prestige.fastestPrestigeTime=runTime;

    // Move equipment to bank
    for(var slot in player.equipment){
        if(player.equipment[slot]){
            depositEquipToBank(player.equipment[slot]);
            player.equipment[slot]=null;
        }
    }

    // Move inventory to bank
    for(var i=0;i<player.inventory.length;i++){
        if(player.inventory[i]){
            depositInvToBank(player.inventory[i]);
            player.inventory[i]=null;
        }
    }

    // Save quest history
    player.prestige.questHistory.push({tier:tier-1,completed:questState.completed.slice()});

    // Reset base skills
    var baseSkills=['nano','tesla','void','astromining','bioforge','circuitry','xenocook'];
    baseSkills.forEach(function(sk){
        player.skills[sk]={level:1,xp:0};
    });

    // Reset state
    player.credits=PRESTIGE_CONFIG.startingCredits+player.prestige.extraStartCredits;
    player.unlockedSynergies=[];
    player.combatStyle='nano';

    // Reset quests
    questState.vexQuest=null;
    questState.vexProgress=[];
    questState.boardQuest=null;
    questState.boardProgress=[];
    questState.slayerTask=null;
    questState.slayerProgress=0;
    questState.slayerStreak=0;
    questState.completed=[];

    // Reset dungeon
    DungeonState.maxFloorReached=0;

    // Reset shop economy
    initShopEconomy();

    // Apply prestige
    player.prestige.tier=tier;
    player.prestige.points+=points;
    player.prestige.totalPointsEarned+=points;
    player.prestige.currentRunStart=Date.now();

    // Recalc and teleport
    recalcStats();
    player.hp=player.maxHp;
    player.energy=player.maxEnergy;
    player.mesh.position.set(0,0,5);
    player.currentArea='station-hub';
    player.inCombat=false;
    player.combatTarget=null;
    player.isMoving=false;
    player.isGathering=false;
    player.gatherTarget=null;

    // Give starter gear
    addItem('scrap_nanoblade',1);
    addItem('lichen_wrap',20);
    addItem('mining_laser',1);

    checkSynergies();

    // VFX
    var pos=player.mesh.position.clone();pos.y+=2;
    var tierColor=PRESTIGE_PASSIVES[tier]?parseInt(PRESTIGE_PASSIVES[tier].color.replace('#',''),16):0xffd700;
    spawnParticles(pos,0xffd700,100,8,3.0,0.2);
    spawnParticles(pos,tierColor,80,6,2.5,0.15);
    spawnParticles(pos,0xffffff,50,4,2.0,0.1);
    triggerScreenShake(1.0,0.8);
    showPrestigeOverlay(tier);

    // Chat
    EventBus.emit('chat',{type:'system',text:'========== PRESTIGE TIER '+tier+' =========='});
    EventBus.emit('chat',{type:'system',text:'You have ascended! +'+points+' Prestige Points earned.'});
    EventBus.emit('chat',{type:'system',text:'Passive unlocked: '+PRESTIGE_PASSIVES[tier].name+' — '+PRESTIGE_PASSIVES[tier].desc});
    EventBus.emit('chat',{type:'system',text:'================================'});
    playSound('levelup');

    saveGame();
    renderSkills();
    EventBus.emit('statsChanged');
    EventBus.emit('inventoryChanged');
    EventBus.emit('equipmentChanged');
}

function showPrestigeOverlay(tier){
    var overlay=document.createElement('div');
    overlay.className='prestige-overlay';
    var pasColor=(PRESTIGE_PASSIVES[tier]||{}).color||'#ffd700';
    overlay.innerHTML='<div class="prestige-text">PRESTIGE</div><div class="prestige-tier-text" style="color:'+pasColor+'">TIER '+tier+'</div><div class="prestige-passive-unlock">'+PRESTIGE_PASSIVES[tier].name+'</div>';
    document.getElementById('ui-overlay').appendChild(overlay);
    setTimeout(function(){if(overlay.parentNode)overlay.remove();},5000);
}

function initCorruptedEnemies(){
    // Generate corrupted versions of non-abyss enemy types
    for(var type in ENEMY_TYPES){
        var base=ENEMY_TYPES[type];
        if(!base||base.area==='dungeon')continue;
        if(base.area==='the-abyss')continue; // Skip abyss enemies
        if(base.isCorrupted)continue;
        var cLoot=(base.lootTable||[]).map(function(l){return{itemId:l.itemId,chance:l.chance,min:l.min||1,max:l.max||1};});
        cLoot.push({itemId:'corrupted_essence',chance:0.08,min:1,max:2});
        ENEMY_TYPES['corrupted_'+type]={
            name:'Corrupted '+base.name,level:base.level,hp:Math.round(base.hp*2),maxHp:Math.round(base.hp*2),
            damage:Math.round(base.damage*1.5),defense:Math.round((base.defense||0)*1.5),xp:Math.round((base.xp||base.level*10)*2),
            attackSpeed:base.attackSpeed,aggroRange:(base.aggroRange||6)+2,leashRange:base.leashRange||20,
            combatStyle:base.combatStyle,respawnTime:base.respawnTime||15,
            area:'corrupted',isCorrupted:true,baseType:type,
            lootTable:cLoot,
        };
    }
}

function buildCorruptedAreas(){
    if(corruptedAreaBuilt)return;
    if(!hasPrestigePassive(5))return;
    corruptedAreaBuilt=true;
    for(var cid in CORRUPTED_AREAS){
        var ca=CORRUPTED_AREAS[cid];
        // Ground plane
        var ground=new THREE.Mesh(new THREE.CircleGeometry(ca.radius,32),new THREE.MeshLambertMaterial({color:ca.groundColor}));
        ground.rotation.x=-Math.PI/2;ground.position.set(ca.center.x,ca.floorY,ca.center.z);ground.receiveShadow=true;
        GameState.scene.add(ground);
        // Red fog light
        var fogLight=new THREE.PointLight(ca.fogColor,0.6,ca.radius*1.5);
        fogLight.position.set(ca.center.x,5,ca.center.z);GameState.scene.add(fogLight);
        // Portal in base area
        buildCorruptedPortal(ca,cid);
    }
    spawnCorruptedEnemies();
}

function buildCorruptedPortal(ca,cid){
    var baseArea=AREAS[ca.base];
    if(!baseArea)return;
    var portalGroup=new THREE.Group();
    var pillarMat=new THREE.MeshLambertMaterial({color:0x5a0a0a,emissive:0x3a0000,emissiveIntensity:0.5});
    var p1=new THREE.Mesh(new THREE.BoxGeometry(0.5,4,0.5),pillarMat);p1.position.set(-1,2,0);portalGroup.add(p1);
    var p2=new THREE.Mesh(new THREE.BoxGeometry(0.5,4,0.5),pillarMat);p2.position.set(1,2,0);portalGroup.add(p2);
    var top=new THREE.Mesh(new THREE.BoxGeometry(2.5,0.4,0.5),pillarMat);top.position.set(0,4.2,0);portalGroup.add(top);
    var plane=new THREE.Mesh(new THREE.PlaneGeometry(1.8,3.5),new THREE.MeshBasicMaterial({color:0xff2244,transparent:true,opacity:0.4,side:THREE.DoubleSide}));
    plane.position.set(0,2,0);portalGroup.add(plane);
    portalGroup.userData.portalPlane=plane;
    var light=new THREE.PointLight(0xff2244,0.5,10);light.position.set(0,2,1);portalGroup.add(light);
    // Position at edge of base area toward corrupted area
    var dx=ca.center.x-baseArea.center.x;var dz=ca.center.z-baseArea.center.z;
    var dist=Math.sqrt(dx*dx+dz*dz);
    var px=baseArea.center.x+(dx/dist)*(baseArea.radius-5);
    var pz=baseArea.center.z+(dz/dist)*(baseArea.radius-5);
    portalGroup.position.set(px,0,pz);
    portalGroup.userData.entityType='corruptedPortal';
    portalGroup.userData.entity={name:ca.name+' Portal',targetAreaId:cid,targetArea:ca};
    GameState.scene.add(portalGroup);
}

function spawnCorruptedEnemies(){
    for(var cid in CORRUPTED_AREAS){
        var ca=CORRUPTED_AREAS[cid];
        var baseArea=AREAS[ca.base];
        if(!baseArea)continue;
        // Collect eligible types, then pick 5-8 to spawn (not all ~100+)
        var eligible=[];
        for(var type in ENEMY_TYPES){
            var et=ENEMY_TYPES[type];
            if(et.isCorrupted||et.area==='dungeon'||et.area==='the-abyss')continue;
            if(et.area!==ca.base)continue;
            if(!ENEMY_TYPES['corrupted_'+type])continue;
            eligible.push(type);
        }
        // Shuffle and pick up to 8
        eligible.sort(function(){return Math.random()-0.5;});
        var picked=eligible.slice(0,Math.min(8,eligible.length));
        for(var pi=0;pi<picked.length;pi++){
            var type=picked[pi];
            var cType=ENEMY_TYPES['corrupted_'+type];
            if(!cType)continue;
            var count=2;
            for(var i=0;i<count;i++){
                var sx=ca.center.x+(Math.random()-0.5)*ca.radius*1.4;
                var sz=ca.center.z+(Math.random()-0.5)*ca.radius*1.4;
                var mesh=buildEnemyMesh(type);
                // Red tint
                mesh.traverse(function(child){
                    if(child.isMesh&&child.material){
                        child.material=child.material.clone();
                        if(child.material.emissive)child.material.emissive.set(0x440000);
                        if(child.material.emissiveIntensity!==undefined)child.material.emissiveIntensity=0.4;
                    }
                });
                mesh.position.set(sx,0,sz);
                var enemy={
                    type:'corrupted_'+type,name:cType.name,level:cType.level,
                    hp:cType.hp,maxHp:cType.maxHp,damage:cType.damage,defense:cType.defense,
                    xp:cType.xp,attackSpeed:cType.attackSpeed,aggroRange:cType.aggroRange,
                    leashRange:cType.leashRange,combatStyle:cType.combatStyle,
                    respawnTime:cType.respawnTime,lootTable:cType.lootTable,
                    mesh:mesh,alive:true,spawnPos:new THREE.Vector3(sx,0,sz),
                    state:'idle',wanderTarget:null,wanderTimer:Math.random()*5,
                    attackTimer:cType.attackSpeed,stunTimer:0,respawnTimer:0,
                    animPhase:Math.random()*Math.PI*2,deathAnim:0,
                    isCorrupted:true,area:cid,
                };
                mesh.userData.entityType='enemy';
                mesh.userData.entity=enemy;
                GameState.scene.add(mesh);
                GameState.enemies.push(enemy);
            }
        }
    }
}

// ----------------------------------------
// Time-Loop Dungeon
// ----------------------------------------
function enterTimeLoopDungeon(){
    if(!player.skills.chronomancy||player.skills.chronomancy.level<99){
        EventBus.emit('chat',{type:'info',text:'You need Chronomancy level 99 to enter the Time-Loop Dungeon.'});return;
    }
    if(DungeonState.active){EventBus.emit('chat',{type:'info',text:'You are already in a dungeon!'});return;}
    player.timeLoopData.active=true;
    player.timeLoopData.damageBonus=Math.min(0.50,player.timeLoopData.attempts*0.05);
    DungeonState.savedPlayerPos=player.mesh.position.clone();
    DungeonState.savedArea=player.currentArea;
    player.combatTarget=null;player.inCombat=false;
    player.isMoving=false;player.moveTarget=null;
    player.isGathering=false;player.gatherTarget=null;
    hideOverworld();
    DungeonState.active=true;DungeonState.floor=99;
    DungeonState.bossGateOpen=true;
    loadTimeLoopFloor();
    playSound('portal');
    triggerAreaTransition('Temporal Rift - Attempt '+(player.timeLoopData.attempts+1));
    showDungeonHUD();
    if(player.timeLoopData.attempts>0){
        EventBus.emit('chat',{type:'system',text:'Time loops again... Attempt '+(player.timeLoopData.attempts+1)+'. Damage bonus: +'+Math.round(player.timeLoopData.damageBonus*100)+'%'});
    } else {
        EventBus.emit('chat',{type:'system',text:'You step into the Temporal Rift...'});
    }
}

function loadTimeLoopFloor(){
    cleanupDungeonFloor();
    var roomSize=25;
    var floorGeo=new THREE.PlaneGeometry(roomSize,roomSize);
    var floorMat=new THREE.MeshLambertMaterial({color:0x112233});
    var flr=new THREE.Mesh(floorGeo,floorMat);flr.rotation.x=-Math.PI/2;flr.userData.isDungeon=true;
    GameState.scene.add(flr);DungeonState.meshes.push(flr);
    var wallMat=new THREE.MeshLambertMaterial({color:0x224466,emissive:0x112244,emissiveIntensity:0.2});
    var wallPositions=[[0,2.5,-roomSize/2,roomSize,5,1],[0,2.5,roomSize/2,roomSize,5,1],[-roomSize/2,2.5,0,1,5,roomSize],[roomSize/2,2.5,0,1,5,roomSize]];
    wallPositions.forEach(function(wp){
        var w=new THREE.Mesh(new THREE.BoxGeometry(wp[3],wp[4],wp[5]),wallMat);
        w.position.set(wp[0],wp[1],wp[2]);w.userData.isDungeon=true;
        GameState.scene.add(w);DungeonState.meshes.push(w);
    });
    DungeonState.dungeonLight=new THREE.PointLight(0x44ffff,1.5,30);
    DungeonState.dungeonLight.position.set(0,8,0);DungeonState.dungeonLight.userData.isDungeon=true;
    GameState.scene.add(DungeonState.dungeonLight);DungeonState.meshes.push(DungeonState.dungeonLight);
    var bossType=player.timeLoopData.bossType||'neuroworm';
    var bossStats=scaleDungeonBoss(bossType,15);
    var bossMesh=buildEnemyMesh(bossType);
    bossMesh.position.set(0,0,-8);bossMesh.userData.isDungeon=true;
    GameState.scene.add(bossMesh);
    var boss=Object.assign({},bossStats,{
        type:bossType,mesh:bossMesh,alive:true,hp:bossStats.hp,
        spawnPos:new THREE.Vector3(0,0,-8),state:'aggro',
        wanderTarget:null,wanderTimer:0,attackTimer:bossStats.attackSpeed,
        stunTimer:0,respawnTimer:0,animPhase:0,deathAnim:0,
        isDungeonEnemy:true,isDungeonBoss:true,isTimeLoopBoss:true
    });
    GameState.enemies.push(boss);DungeonState.enemies.push(boss);
    DungeonState.enemiesAlive=1;
    player.mesh.position.set(0,0,8);
    player.currentArea='dungeon';GameState.currentArea='dungeon';
}

function getAttackSpeed(){
    var weapon=player.equipment.weapon;
    var wStyle=weapon?weapon.style:'nano';
    var base=wStyle==='nano'?2.4:wStyle==='tesla'?3.0:3.6;
    if(player.skills.chronomancy){
        var quicken=getSkillBonus('chronomancy','chronoAttackSpeed');
        var temporal=getSkillBonus('chronomancy','temporalMastery');
        if(hasSkillMilestone('chronomancy','timeLord')){quicken*=1.25;temporal*=1.25;}
        base=base*(1-Math.min(0.40,quicken+temporal));
    }
    return Math.max(1.2,base);
}

function updateAutoAttack(){
    if(!player.combatTarget||!player.combatTarget.alive){if(player.inCombat){player.inCombat=false;player.combatTarget=null;}return;}
    const target=player.combatTarget,dist=player.mesh.position.distanceTo(target.mesh.position);
    const weapon=player.equipment.weapon;
    const wStyle=weapon?weapon.style:'nano';
    const range=wStyle==='nano'?3:wStyle==='tesla'?8:10;
    if(dist>range){moveTo(target.mesh.position);return;}
    // Block attacking boss through closed gate
    if(DungeonState.active&&!DungeonState.bossGateOpen&&target.isDungeonBoss){
        EventBus.emit('chat',{type:'info',text:'The boss gate blocks your attack! Defeat all enemies first.'});
        player.combatTarget=null;player.inCombat=false;return;
    }
    player.isMoving=false;player.inCombat=true;
    player.deathRecap.combatDuration+=GameState.deltaTime;
    const dx=target.mesh.position.x-player.mesh.position.x,dz=target.mesh.position.z-player.mesh.position.z;
    player.mesh.rotation.y=Math.atan2(dx,dz);
    player.autoAttackTimer-=GameState.deltaTime;
    if(player.autoAttackTimer<=0){
        const atkSpeed=getAttackSpeed();
        player.autoAttackTimer=atkSpeed;
        if(hasPrestigePassive(6))player.autoAttackTimer*=0.9;
        const result=calculateDamage(target);
        if(result.hit){applyDamageToEnemy(target,result.damage);gainXp(wStyle,Math.round(result.damage*0.4));degradeWeapon(1);player.attackAnim=0.25;
            // Psionic damage proc
            if(player.psionicsUnlocked&&player.skills.psionics){
                var procChance=getSkillBonus('psionics','psionicProcChance');
                if(procChance>0&&Math.random()<procChance){
                    var psiDmg=Math.round((player.skills.psionics.level*0.8)*(1+getSkillBonus('psionics','psionicDamage')));
                    applyDamageToEnemy(target,psiDmg);
                    spawnParticles(target.mesh.position.clone().add(new THREE.Vector3(0,2,0)),0xff44ff,10,3,0.5,0.1);
                    gainXp('psionics',Math.round(psiDmg*0.5));
                    if(player.skills.psionics.level>=40){
                        var aoeDmg=Math.round(psiDmg*(0.3+getSkillBonus('psionics','massKinesisDamage')));
                        GameState.enemies.forEach(function(nearby){
                            if(!nearby.alive||nearby===target)return;
                            if(nearby.mesh.position.distanceTo(target.mesh.position)>5)return;
                            applyDamageToEnemy(nearby,aoeDmg);
                            spawnParticles(nearby.mesh.position.clone().add(new THREE.Vector3(0,1,0)),0xaa22ff,5,2,0.4,0.08);
                        });
                    }
                }
            }
            // Prestige combat XP bonuses
            if(player.psionicsUnlocked&&player.skills.psionics){
                var combatXpBonus=getSkillBonus('psionics','allCombatXpBonus');
                if(combatXpBonus>0){var bonusXp=Math.round(result.damage*0.4*combatXpBonus);if(bonusXp>0)gainXp(wStyle,bonusXp);}
            }
            if(player.skills.chronomancy){
                var quickenVal=getSkillBonus('chronomancy','chronoAttackSpeed');
                if(quickenVal>0)gainXp('chronomancy',Math.round(1+result.damage*0.05));
            }
        }
        else{createHitSplat(target.mesh.position.clone().add(new THREE.Vector3(0,1.5,0)),'MISS','miss');playSound('miss');}
    }
}

function updateAttackBar(){
    var container=document.getElementById('attack-bar-container');
    if(!player.inCombat||!player.combatTarget||!player.combatTarget.alive){container.style.display='none';return;}
    container.style.display='block';
    var atkSpeed=getAttackSpeed();
    var elapsed=atkSpeed-player.autoAttackTimer;
    var pct=Math.min(100,Math.max(0,(elapsed/atkSpeed)*100));
    document.getElementById('attack-bar-fill').style.width=pct+'%';
    var wStyle=player.equipment.weapon?player.equipment.weapon.style:'nano';
    document.getElementById('attack-bar-text').textContent=wStyle.charAt(0).toUpperCase()+wStyle.slice(1)+' Attack';
    // Position above player character
    var screenPos=player.mesh.position.clone().add(new THREE.Vector3(0,3.5,0));
    screenPos.project(GameState.camera);
    var sx=(screenPos.x*0.5+0.5)*window.innerWidth;
    var sy=(-screenPos.y*0.5+0.5)*window.innerHeight;
    container.style.left=sx+'px';
    container.style.top=(sy-20)+'px';
}

function updateCombatEffects(){}
function updateCooldowns(){}
function updateAdrenaline(){}

// ========================================
// Enemy System — Data-Driven Generation
// ========================================

// Stat formula helpers
function computeEnemyStats(level, isBoss) {
    var hp, dmg, def;
    if (level <= 99) {
        hp = Math.round(20 + level * 4 + Math.pow(level, 1.75) * 0.55);
        dmg = Math.round(2 + level * 0.7 + Math.pow(level, 1.3) * 0.08);
        def = Math.round(Math.pow(level, 1.2) * 0.35);
    } else {
        var excess = level - 99;
        var hp99 = Math.round(20 + 99 * 4 + Math.pow(99, 1.75) * 0.55);
        var dmg99 = Math.round(2 + 99 * 0.7 + Math.pow(99, 1.3) * 0.08);
        var def99 = Math.round(Math.pow(99, 1.2) * 0.35);
        hp = Math.round(hp99 + excess * 40 + Math.pow(excess, 1.9) * 2);
        dmg = Math.round(dmg99 + excess * 1.5 + Math.pow(excess, 1.5) * 0.15);
        def = Math.round(def99 + excess * 0.8 + Math.pow(excess, 1.3) * 0.1);
    }
    if (isBoss) { hp = Math.round(hp * 2.5); dmg = Math.round(dmg * 1.5); def = Math.round(def * 1.3); }
    return {
        hp: hp, maxHp: hp, damage: dmg, defense: def,
        attackSpeed: Math.max(1.5, 3.5 - level * 0.01),
        aggroRange: isBoss ? 14 : Math.min(12, 5 + level * 0.05),
        leashRange: isBoss ? 25 : Math.min(25, 15 + level * 0.05),
        respawnTime: isBoss ? 120 + level : Math.round(20 + level * 0.3)
    };
}

// Loot table generation
var ENEMY_BIO_MAT = [
    [1,10,'chitin_shard'],[11,20,'jelly_membrane'],[21,30,'jelly_membrane'],[31,40,'spore_gland'],
    [41,50,'spore_gland'],[51,60,'gravity_residue'],[61,70,'gravity_residue'],[71,80,'neural_tissue'],
    [81,90,'neural_tissue'],[91,99,'corrupted_essence'],[100,140,'abyssal_ichor'],[141,200,'primordial_fragment']
];
var ENEMY_ORE = [
    [1,10,'stellarite_ore'],[11,20,'ferrite_ore'],[21,30,'cobaltium_ore'],[31,40,'duranite_ore'],
    [41,50,'titanex_ore'],[51,60,'plasmite_ore'],[61,70,'quantite_ore'],[71,80,'neutronium_ore'],
    [81,90,'darkmatter_shard'],[91,200,'voidsteel_ore']
];
var ENEMY_FOOD = [
    [1,20,'space_lichen'],[21,40,'nebula_fruit'],[41,60,'alien_steak'],[61,80,'plasma_pepper'],[81,200,'void_truffle']
];
function lookupByLevel(table, level) {
    for (var i = 0; i < table.length; i++) { if (level >= table[i][0] && level <= table[i][1]) return table[i][2]; }
    return table[table.length - 1][2];
}
function getEquipTierForLevel(level) {
    if (level < 10) return 1; if (level < 20) return 2; if (level < 30) return 3;
    if (level < 40) return 4; if (level < 50) return 5; if (level < 60) return 6;
    if (level < 70) return 7; if (level < 80) return 8; if (level < 90) return 9;
    return 10;
}
function generateLootTable(level, isBoss, combatStyle) {
    var loot = [];
    var bio = lookupByLevel(ENEMY_BIO_MAT, level);
    var ore = lookupByLevel(ENEMY_ORE, level);
    var food = lookupByLevel(ENEMY_FOOD, level);
    loot.push({itemId: bio, chance: isBoss ? 1.0 : 0.5, min: isBoss ? 2 : 1, max: isBoss ? 5 : 3});
    loot.push({itemId: ore, chance: isBoss ? 0.5 : 0.15, min: 1, max: isBoss ? 3 : 1});
    loot.push({itemId: food, chance: 0.25, min: 1, max: 2});
    // Equipment drops based on tier
    var tier = getEquipTierForLevel(level);
    var prefix = null;
    for (var ti = 0; ti < TIER_DEFS.length; ti++) { if (TIER_DEFS[ti].tier === tier) { prefix = TIER_DEFS[ti].prefix; break; } }
    if (prefix) {
        var weaponSuffix = combatStyle === 'nano' ? 'nanoblade' : combatStyle === 'tesla' ? 'coilgun' : 'voidstaff';
        loot.push({itemId: prefix + '_' + weaponSuffix, chance: isBoss ? 0.08 : 0.02, min: 1, max: 1});
        var offhandSuffix = combatStyle === 'nano' ? 'energy_shield' : combatStyle === 'tesla' ? 'capacitor' : 'dark_orb';
        loot.push({itemId: prefix + '_' + offhandSuffix, chance: isBoss ? 0.06 : 0.015, min: 1, max: 1});
        if (isBoss) {
            loot.push({itemId: prefix + '_helmet', chance: 0.04, min: 1, max: 1});
            loot.push({itemId: prefix + '_vest', chance: 0.04, min: 1, max: 1});
            loot.push({itemId: prefix + '_legs', chance: 0.04, min: 1, max: 1});
        }
    }
    return loot;
}

// ========================================
// Enemy Definitions (~168 entries)
// ========================================
var ENEMY_DEFS = [
// === 6 existing enemies (explicit stats — preserved exactly) ===
{id:'chithari',name:'Chithari',level:3,explicit:true,hp:60,maxHp:60,damage:4,defense:2,attackSpeed:3.2,aggroRange:6,leashRange:18,combatStyle:'nano',respawnTime:30,area:'alien-wastes',meshTemplate:'_legacy',desc:'Armored beetle swarm.',lootTable:[{itemId:'chitin_shard',chance:0.6,min:1,max:3},{itemId:'space_lichen',chance:0.3,min:1,max:2}]},
{id:'chithari_warrior',name:'Chithari Warrior',level:8,explicit:true,hp:120,maxHp:120,damage:8,defense:5,attackSpeed:3.0,aggroRange:7,leashRange:20,combatStyle:'nano',respawnTime:35,area:'alien-wastes',meshTemplate:'_legacy',desc:'Larger Chithari with reinforced chitin.',lootTable:[{itemId:'chitin_shard',chance:0.8,min:2,max:5},{itemId:'stellarite_ore',chance:0.2,min:1,max:1}]},
{id:'voidjelly',name:'Voidjelly',level:15,explicit:true,hp:200,maxHp:200,damage:14,defense:4,attackSpeed:3.5,aggroRange:8,leashRange:22,combatStyle:'tesla',respawnTime:40,area:'alien-wastes',meshTemplate:'_legacy',desc:'Floating jellyfish that shocks.',lootTable:[{itemId:'jelly_membrane',chance:0.5,min:1,max:2},{itemId:'nebula_fruit',chance:0.3,min:1,max:2},{itemId:'cobaltium_ore',chance:0.15,min:1,max:1},{itemId:'ferrite_coilgun',chance:0.03,min:1,max:1},{itemId:'ferrite_voidstaff',chance:0.03,min:1,max:1},{itemId:'ferrite_capacitor',chance:0.03,min:1,max:1}]},
{id:'sporeclaw',name:'Sporeclaw',level:30,explicit:true,hp:400,maxHp:400,damage:25,defense:10,attackSpeed:2.5,aggroRange:9,leashRange:25,combatStyle:'void',respawnTime:45,area:'alien-wastes',meshTemplate:'_legacy',desc:'Mantis-scorpion with toxic fungal growths.',lootTable:[{itemId:'spore_gland',chance:0.4,min:1,max:2},{itemId:'alien_steak',chance:0.35,min:1,max:2},{itemId:'duranite_ore',chance:0.1,min:1,max:1},{itemId:'duranite_bar',chance:0.05,min:1,max:1},{itemId:'cobalt_boots',chance:0.02,min:1,max:1},{itemId:'cobalt_dark_orb',chance:0.02,min:1,max:1}]},
{id:'gravlurk',name:'Gravlurk',level:50,explicit:true,hp:1200,maxHp:1200,damage:40,defense:20,attackSpeed:4.0,aggroRange:12,leashRange:18,combatStyle:'void',respawnTime:120,isBoss:true,area:'alien-wastes',meshTemplate:'_legacy',desc:'Giant slug with gravity field.',lootTable:[{itemId:'gravity_residue',chance:1.0,min:2,max:5},{itemId:'plasmite_ore',chance:0.4,min:1,max:3},{itemId:'titanex_vest',chance:0.05,min:1,max:1},{itemId:'titanex_legs',chance:0.04,min:1,max:1},{itemId:'titanex_nanoblade',chance:0.03,min:1,max:1},{itemId:'titanex_dark_orb',chance:0.03,min:1,max:1},{itemId:'voidtouched_mining_laser',chance:0.02,min:1,max:1}]},
{id:'neuroworm',name:'Neuroworm',level:60,explicit:true,hp:1500,maxHp:1500,damage:50,defense:15,attackSpeed:3.0,aggroRange:12,leashRange:20,combatStyle:'tesla',respawnTime:120,isBoss:true,area:'alien-wastes',meshTemplate:'_legacy',desc:'Psionic segmented worm.',lootTable:[{itemId:'neural_tissue',chance:1.0,min:2,max:4},{itemId:'quantite_ore',chance:0.5,min:2,max:4},{itemId:'plasmite_helmet',chance:0.05,min:1,max:1},{itemId:'plasmite_coilgun',chance:0.03,min:1,max:1},{itemId:'plasmite_capacitor',chance:0.03,min:1,max:1},{itemId:'plasmite_gloves',chance:0.04,min:1,max:1},{itemId:'voidtouched_bio_scanner',chance:0.02,min:1,max:1}]},

// === Levels 1-20: Insectoid / Vermin (alien-wastes) ===
{id:'beetle_drone',name:'Beetle Drone',level:1,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x4a3a1a,scale:0.4,variant:'drone'},desc:'Tiny scuttling automaton beetle.'},
{id:'dust_mite',name:'Dust Mite',level:1,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x8a7a5a,scale:0.3},desc:'Near-invisible parasitic mite.'},
{id:'sand_crawler',name:'Sand Crawler',level:2,combatStyle:'void',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x6a5a3a,scale:0.45,variant:'crawler'},desc:'Low-slung crawler with grinding mandibles.'},
{id:'husk_beetle',name:'Husk Beetle',level:2,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x5a4a2a,scale:0.5,variant:'drone'},desc:'Dried-out beetle feeding on carrion.'},
{id:'spitting_ant',name:'Spitting Ant',level:4,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x3a3a2a,scale:0.45,variant:'drone'},desc:'Acid-spitting colonial insect.'},
{id:'glow_fly',name:'Glow Fly',level:4,combatStyle:'void',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x44aa44,scale:0.35},desc:'Bioluminescent flying pest.'},
{id:'carapace_grub',name:'Carapace Grub',level:5,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x7a6a4a,scale:0.5,variant:'crawler'},desc:'Armored larva burrowing through soil.'},
{id:'barbed_tick',name:'Barbed Tick',level:5,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x4a3a2a,scale:0.35},desc:'Blood-sucking tick with barbed legs.'},
{id:'venom_weaver',name:'Venom Weaver',level:6,combatStyle:'void',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x2a4a2a,scale:0.45},desc:'Small spider weaving venomous webs.'},
{id:'hive_drone',name:'Hive Drone',level:6,combatStyle:'nano',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x6a5a2a,scale:0.4},desc:'Mindless worker serving the hive.'},
{id:'plague_fly',name:'Plague Fly',level:7,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x5a6a3a,scale:0.4},desc:'Disease-carrying buzzing menace.'},
{id:'tunnel_spider',name:'Tunnel Spider',level:7,combatStyle:'void',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x3a2a1a,scale:0.5},desc:'Ambush predator lurking in burrows.'},
{id:'razor_ant',name:'Razor Ant',level:9,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x2a2a1a,scale:0.55,variant:'drone'},desc:'Soldier ant with blade-like mandibles.'},
{id:'hive_queen',name:'Hive Queen',level:10,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x8a6a2a,scale:1.2,variant:'queen'},isBoss:true,desc:'Bloated queen commanding the swarm.'},
{id:'spark_beetle',name:'Spark Beetle',level:10,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x3a5a7a,scale:0.55,variant:'drone'},desc:'Beetle generating electrical discharges.'},
{id:'web_lurker',name:'Web Lurker',level:11,combatStyle:'void',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x4a3a4a,scale:0.55},desc:'Patient ambusher in sticky webs.'},
{id:'chitin_sentinel',name:'Chitin Sentinel',level:11,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x5a5a3a,scale:0.7,variant:'sentinel'},desc:'Guard insect with reinforced plates.'},
{id:'pulse_moth',name:'Pulse Moth',level:12,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x6a6aaa,scale:0.5},desc:'Moth emitting disruptive energy pulses.'},
{id:'burrowing_horror',name:'Burrowing Horror',level:12,combatStyle:'void',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x2a1a1a,scale:0.65,variant:'crawler'},desc:'Subterranean insect erupting from soil.'},
{id:'swarm_cluster',name:'Swarm Cluster',level:13,combatStyle:'nano',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x5a4a2a,scale:0.6},desc:'Tightly packed ball of tiny insects.'},
{id:'acid_spitter',name:'Acid Spitter',level:13,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x4a6a2a,scale:0.6,variant:'drone'},desc:'Insect spraying corrosive acid.'},
{id:'web_matriarch',name:'Web Matriarch',level:14,combatStyle:'void',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x5a3a5a,scale:0.7},desc:'Massive spider commanding web territory.'},
{id:'shell_roller',name:'Shell Roller',level:14,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x6a6a5a,scale:0.6,variant:'crawler'},desc:'Armadillo-like insect rolling into targets.'},
{id:'static_wasp',name:'Static Wasp',level:16,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x7a7a2a,scale:0.5},desc:'Wasp with electrically charged stinger.'},
{id:'brood_mother',name:'Brood Mother',level:16,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x6a4a3a,scale:0.8,variant:'queen'},desc:'Egg-laying matriarch defended by broodlings.'},
{id:'phase_spider',name:'Phase Spider',level:17,combatStyle:'void',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x3a3a6a,scale:0.6},desc:'Spider that blinks through dimensions.'},
{id:'hive_guardian',name:'Hive Guardian',level:17,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x7a5a2a,scale:0.8,variant:'sentinel'},desc:'Elite hive defender with crushing claws.'},
{id:'nerve_stinger',name:'Nerve Stinger',level:18,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0x5a7a5a,scale:0.55},desc:'Flying insect targeting nerve clusters.'},
{id:'pit_lurker',name:'Pit Lurker',level:18,combatStyle:'void',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x2a2a2a,scale:0.65},desc:'Ambusher hiding in sandy pits.'},
{id:'armored_centipede',name:'Armored Centipede',level:19,combatStyle:'nano',area:'alien-wastes',meshTemplate:'insectoid',meshParams:{color:0x5a4a4a,scale:0.75,variant:'crawler'},desc:'Multi-legged armored predator.'},
{id:'stingwing_matriarch',name:'Stingwing Matriarch',level:20,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'swarm_bug',meshParams:{color:0xaa8a2a,scale:1.1},isBoss:true,desc:'Giant wasp queen ruling the skies.'},
{id:'death_weaver',name:'Death Weaver',level:20,combatStyle:'void',area:'alien-wastes',meshTemplate:'arachnid',meshParams:{color:0x1a1a3a,scale:0.75},desc:'Master weaver of lethal trap webs.'},

// === Levels 21-40: Alien Wildlife (alien-wastes) ===
{id:'drift_jelly',name:'Drift Jelly',level:21,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x4488aa,scale:0.6,tentacles:6},desc:'Small jellyfish drifting on air currents.'},
{id:'blade_mantis',name:'Blade Mantis',level:21,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x3a6a3a,scale:0.7},desc:'Mantis with scythe-like forearms.'},
{id:'rock_scorpion',name:'Rock Scorpion',level:22,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x5a4a3a,scale:0.7,stingerSize:1.0},desc:'Camouflaged scorpion in rocky terrain.'},
{id:'storm_jelly',name:'Storm Jelly',level:22,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x5566cc,scale:0.7,tentacles:8},desc:'Crackling jelly generating micro-storms.'},
{id:'leaf_mantis',name:'Leaf Mantis',level:23,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x4a7a2a,scale:0.7},desc:'Camouflaged mantis mimicking foliage.'},
{id:'sand_scorpion',name:'Sand Scorpion',level:23,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x8a7a5a,scale:0.75,stingerSize:1.0},desc:'Burrowing scorpion striking from below.'},
{id:'tidal_jelly',name:'Tidal Jelly',level:24,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x3399aa,scale:0.8,tentacles:10},desc:'Large jelly pulling in prey with tidal force.'},
{id:'tidal_jelly_monarch',name:'Tidal Jelly Monarch',level:25,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x22aacc,scale:1.4,tentacles:14},isBoss:true,desc:'Enormous jelly monarch ruling the tidal pools.'},
{id:'praying_stalker',name:'Praying Stalker',level:25,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x2a5a2a,scale:0.8},desc:'Patient hunter striking with precision.'},
{id:'venom_scorpion',name:'Venom Scorpion',level:26,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x4a6a3a,scale:0.8,stingerSize:1.2},desc:'Scorpion with highly toxic venom.'},
{id:'thunder_jelly',name:'Thunder Jelly',level:26,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x6655dd,scale:0.85,tentacles:10},desc:'Jelly that discharges thunderous blasts.'},
{id:'ghost_mantis',name:'Ghost Mantis',level:27,combatStyle:'void',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x7a7a8a,scale:0.8},desc:'Near-invisible mantis striking from nowhere.'},
{id:'iron_scorpion',name:'Iron Scorpion',level:27,combatStyle:'nano',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x4a4a5a,scale:0.85,stingerSize:1.1},desc:'Scorpion with metallic carapace.'},
{id:'current_jelly',name:'Current Jelly',level:28,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x3377bb,scale:0.9,tentacles:12},desc:'Jelly channeling electrical currents.'},
{id:'ambush_mantis',name:'Ambush Mantis',level:28,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x5a3a2a,scale:0.85},desc:'Mantis master of surprise attacks.'},
{id:'emperor_scorpion',name:'Emperor Scorpion',level:29,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x2a2a3a,scale:0.95,stingerSize:1.3},desc:'Massive scorpion with crushing pincers.'},
{id:'plasma_jelly',name:'Plasma Jelly',level:29,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0xaa55cc,scale:0.95,tentacles:12},desc:'Super-heated plasma coursing through its body.'},
{id:'war_mantis',name:'War Mantis',level:31,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x6a2a2a,scale:0.95},desc:'Battle-hardened mantis covered in scars.'},
{id:'crystal_scorpion',name:'Crystal Scorpion',level:31,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x5a7a8a,scale:0.9,stingerSize:1.2},desc:'Scorpion with crystalline stinger.'},
{id:'void_jelly',name:'Void Jelly',level:32,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x4422aa,scale:1.0,tentacles:12},desc:'Dark jelly phasing through dimensions.'},
{id:'titan_mantis',name:'Titan Mantis',level:32,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x3a5a4a,scale:1.0},desc:'Towering mantis of immense strength.'},
{id:'death_scorpion',name:'Death Scorpion',level:33,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x3a1a3a,scale:0.95,stingerSize:1.4},desc:'Lethal scorpion with instant-kill venom.'},
{id:'neon_jelly',name:'Neon Jelly',level:33,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x44ff88,scale:0.9,tentacles:10},desc:'Brilliantly glowing toxic jellyfish.'},
{id:'spore_mantis',name:'Spore Mantis',level:34,combatStyle:'void',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x6a5a4a,scale:0.9},desc:'Mantis infected with toxic spores.'},
{id:'dune_scorpion',name:'Dune Scorpion',level:34,combatStyle:'nano',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x9a8a5a,scale:1.0,stingerSize:1.2},desc:'Desert-dwelling scorpion hiding in sand.'},
{id:'deep_jelly',name:'Deep Jelly',level:35,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0x223388,scale:1.05,tentacles:14},desc:'Deep-dwelling jelly adapted to crushing pressure.'},
{id:'razor_mantis',name:'Razor Mantis',level:35,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x4a4a3a,scale:1.0},desc:'Mantis with blade-edges on every limb.'},
{id:'plague_scorpion',name:'Plague Scorpion',level:36,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x5a4a2a,scale:1.0,stingerSize:1.3},desc:'Disease-carrying scorpion spreading blight.'},
{id:'coral_jelly',name:'Coral Jelly',level:36,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0xaa5566,scale:0.95,tentacles:10},desc:'Hardy jelly with coral-like outer shell.'},
{id:'assassin_mantis',name:'Assassin Mantis',level:37,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x2a2a2a,scale:1.0},desc:'Silent killer striking vital points.'},
{id:'obsidian_scorpion',name:'Obsidian Scorpion',level:37,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x1a1a2a,scale:1.05,stingerSize:1.4},desc:'Black scorpion of volcanic origin.'},
{id:'lightning_jelly',name:'Lightning Jelly',level:38,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'jellyfish',meshParams:{color:0xffdd44,scale:1.0,tentacles:12},desc:'Crackling jelly conducting pure lightning.'},
{id:'royal_mantis',name:'Royal Mantis',level:38,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x6a4a6a,scale:1.05},desc:'Regal mantis ruling insect territory.'},
{id:'titan_scorpion',name:'Titan Scorpion',level:39,combatStyle:'void',area:'alien-wastes',meshTemplate:'scorpion',meshParams:{color:0x3a3a4a,scale:1.15,stingerSize:1.5},desc:'Enormous scorpion of devastating power.'},
{id:'acid_mantis_alpha',name:'Acid Mantis Alpha',level:40,combatStyle:'nano',area:'alien-wastes',meshTemplate:'mantis',meshParams:{color:0x4aaa2a,scale:1.3},isBoss:true,desc:'Alpha mantis spraying concentrated acid.'},

// === Levels 41-60: Predators (alien-wastes) ===
{id:'shadow_stalker',name:'Shadow Stalker',level:41,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x2a2a3a,scale:0.8},desc:'Quadruped lurking in shadows.'},
{id:'dust_worm',name:'Dust Worm',level:41,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x7a6a4a,scale:0.6,segments:6},desc:'Burrowing worm erupting from dust.'},
{id:'acid_slug',name:'Acid Slug',level:42,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x4a7a2a,scale:0.7,debris:4},desc:'Slow slug leaving corrosive trail.'},
{id:'night_stalker',name:'Night Stalker',level:42,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x1a1a2a,scale:0.85},desc:'Nocturnal predator with heat vision.'},
{id:'tremor_worm',name:'Tremor Worm',level:43,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x5a4a3a,scale:0.7,segments:7},desc:'Worm causing localized earthquakes.'},
{id:'bile_slug',name:'Bile Slug',level:43,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x6a6a2a,scale:0.75,debris:5},desc:'Slug regurgitating toxic bile.'},
{id:'blood_stalker',name:'Blood Stalker',level:44,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x4a1a1a,scale:0.9},desc:'Predator drawn to the scent of blood.'},
{id:'pack_howler_alpha',name:'Pack Howler Alpha',level:45,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x5a2a2a,scale:1.3},isBoss:true,desc:'Alpha predator commanding the hunting pack.'},
{id:'bore_worm',name:'Bore Worm',level:45,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x4a3a2a,scale:0.75,segments:8},desc:'Worm boring through solid rock.'},
{id:'toxic_slug',name:'Toxic Slug',level:46,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x3a8a3a,scale:0.8,debris:6},desc:'Slug oozing potent neurotoxin.'},
{id:'dusk_stalker',name:'Dusk Stalker',level:46,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x3a2a4a,scale:0.9},desc:'Twilight predator blending with darkness.'},
{id:'shock_worm',name:'Shock Worm',level:47,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x3a5a7a,scale:0.8,segments:8},desc:'Worm discharging electrical shocks.'},
{id:'iron_slug',name:'Iron Slug',level:47,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x5a5a6a,scale:0.85,debris:5},desc:'Heavily armored slug absorbing metals.'},
{id:'fang_stalker',name:'Fang Stalker',level:48,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x3a3a2a,scale:0.95},desc:'Predator with elongated saber fangs.'},
{id:'magma_worm',name:'Magma Worm',level:48,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x8a3a1a,scale:0.85,segments:9},desc:'Superheated worm from volcanic vents.'},
{id:'crystal_slug',name:'Crystal Slug',level:49,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x5a7a8a,scale:0.9,debris:7},desc:'Slug with crystalline shell fragments.'},
{id:'alpha_stalker',name:'Alpha Stalker',level:49,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x2a1a3a,scale:1.0},desc:'Apex predator of the hunting grounds.'},
{id:'thunder_worm',name:'Thunder Worm',level:51,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x4a4a8a,scale:0.9,segments:9},desc:'Worm generating thunderous vibrations.'},
{id:'plague_slug',name:'Plague Slug',level:51,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x5a6a3a,scale:0.9,debris:6},desc:'Disease-ridden slug spreading plague.'},
{id:'void_stalker',name:'Void Stalker',level:52,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x1a1a4a,scale:1.0},desc:'Predator phasing through void tears.'},
{id:'plasma_worm',name:'Plasma Worm',level:52,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x7a3a7a,scale:0.9,segments:10},desc:'Worm supercharged with plasma energy.'},
{id:'titan_slug',name:'Titan Slug',level:53,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x3a3a5a,scale:1.0,debris:8},desc:'Enormous slug crushing everything in its path.'},
{id:'dire_stalker',name:'Dire Stalker',level:53,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x4a2a3a,scale:1.05},desc:'Fearsome predator radiating dread.'},
{id:'leech_worm',name:'Leech Worm',level:54,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x5a2a3a,scale:0.85,segments:8},desc:'Parasitic worm draining life force.'},
{id:'corrosive_slug',name:'Corrosive Slug',level:54,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x6a8a2a,scale:0.95,debris:7},desc:'Slug secreting armor-dissolving acid.'},
{id:'phantom_stalker',name:'Phantom Stalker',level:55,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x3a3a5a,scale:1.05},desc:'Semi-transparent predator fading in and out.'},
{id:'death_worm',name:'Death Worm',level:55,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x4a1a1a,scale:1.0,segments:10},desc:'Legendary worm of devastating power.'},
{id:'omega_slug',name:'Omega Slug',level:56,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x2a3a5a,scale:1.05,debris:9},desc:'Ultimate slug evolution, nearly indestructible.'},
{id:'terror_stalker',name:'Terror Stalker',level:56,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x2a1a1a,scale:1.1},desc:'Nightmare predator inducing primal fear.'},
{id:'storm_worm',name:'Storm Worm',level:57,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x3a5a6a,scale:1.0,segments:10},desc:'Worm summoning localized storms.'},
{id:'war_slug',name:'War Slug',level:57,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x5a3a3a,scale:1.0,debris:8},desc:'Battle-scarred slug hardened by conflict.'},
{id:'doom_stalker',name:'Doom Stalker',level:58,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x1a0a2a,scale:1.1},desc:'Herald of destruction prowling the wastes.'},
{id:'abyssal_worm',name:'Abyssal Worm',level:58,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'worm',meshParams:{color:0x2a1a4a,scale:1.05,segments:11},desc:'Worm from the deepest underground caverns.'},
{id:'elder_slug',name:'Elder Slug',level:59,combatStyle:'nano',area:'alien-wastes',meshTemplate:'slug',meshParams:{color:0x4a4a6a,scale:1.1,debris:10},desc:'Ancient slug of incomprehensible age.'},
{id:'apex_stalker',name:'Apex Stalker',level:59,combatStyle:'void',area:'alien-wastes',meshTemplate:'stalker',meshParams:{color:0x3a1a4a,scale:1.15},desc:'Ultimate predator at the top of the food chain.'},

// === Levels 61-80: Aberrations (alien-wastes) ===
{id:'lesser_wraith',name:'Lesser Wraith',level:61,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x4a4a7a,scale:0.7},desc:'Faint spectral entity from beyond.'},
{id:'shadow_wisp',name:'Shadow Wisp',level:61,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x2a2a4a,scale:0.6},desc:'Flickering dark energy fragment.'},
{id:'stone_golem',name:'Stone Golem',level:62,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x5a5a5a,scale:0.8},desc:'Animated stone construct.'},
{id:'void_wisp',name:'Void Wisp',level:62,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x3a3a6a,scale:0.7},desc:'Wisp of pure void energy.'},
{id:'dark_blob',name:'Dark Blob',level:63,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x1a1a3a,scale:0.7},desc:'Amorphous mass of dark energy.'},
{id:'iron_golem',name:'Iron Golem',level:63,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x4a4a5a,scale:0.85},desc:'Metallic golem of great strength.'},
{id:'wailing_wraith',name:'Wailing Wraith',level:64,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x5a4a8a,scale:0.75},desc:'Wraith whose screams paralyze prey.'},
{id:'entropy_mass',name:'Entropy Mass',level:64,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x2a1a4a,scale:0.75},desc:'Mass of entropic energy decaying all nearby.'},
{id:'obsidian_golem',name:'Obsidian Golem',level:65,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x1a1a2a,scale:0.9},desc:'Volcanic glass golem of deadly sharpness.'},
{id:'frost_wraith',name:'Frost Wraith',level:65,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x7a8aaa,scale:0.8},desc:'Freezing wraith draining heat.'},
{id:'chaos_blob',name:'Chaos Blob',level:66,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x4a1a4a,scale:0.8},desc:'Chaotic mass warping reality nearby.'},
{id:'emerald_golem',name:'Emerald Golem',level:66,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x2a6a3a,scale:0.9},desc:'Crystal golem infused with toxic energy.'},
{id:'howling_wraith',name:'Howling Wraith',level:67,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x4a3a7a,scale:0.85},desc:'Wraith emitting mind-shattering howls.'},
{id:'void_mass',name:'Void Mass',level:67,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x0a0a3a,scale:0.85},desc:'Concentrated void energy given form.'},
{id:'quartz_golem',name:'Quartz Golem',level:68,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x8a7a9a,scale:0.95},desc:'Translucent golem refracting light.'},
{id:'death_wraith',name:'Death Wraith',level:68,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x2a1a5a,scale:0.9},desc:'Harbinger of death draining life force.'},
{id:'nightmare_mass',name:'Nightmare Mass',level:69,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x3a0a3a,scale:0.9},desc:'Mass projecting horrific visions.'},
{id:'void_sentinel',name:'Void Sentinel',level:70,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x6a4aaa,scale:1.3},isBoss:true,desc:'Ancient guardian of the void boundary.'},
{id:'diamond_golem',name:'Diamond Golem',level:70,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x9a9aaa,scale:1.0},desc:'Nearly indestructible diamond construct.'},
{id:'screaming_wraith',name:'Screaming Wraith',level:71,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x5a3a8a,scale:0.9},desc:'Wraith whose screams rupture reality.'},
{id:'antimatter_blob',name:'Antimatter Blob',level:71,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x0a1a5a,scale:0.9},desc:'Antimatter mass annihilating on contact.'},
{id:'titan_golem',name:'Titan Golem',level:72,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x4a5a6a,scale:1.1},desc:'Colossal golem of staggering power.'},
{id:'soul_wraith',name:'Soul Wraith',level:72,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x3a2a7a,scale:0.95},desc:'Wraith feeding on souls of the fallen.'},
{id:'rift_mass',name:'Rift Mass',level:73,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x2a0a5a,scale:0.95},desc:'Mass tearing small rifts in spacetime.'},
{id:'neutron_golem',name:'Neutron Golem',level:73,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x3a3a4a,scale:1.1},desc:'Ultra-dense golem of neutron star matter.'},
{id:'dread_wraith',name:'Dread Wraith',level:74,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x4a2a6a,scale:1.0},desc:'Wraith radiating aura of absolute dread.'},
{id:'singularity_mass',name:'Singularity Mass',level:74,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x0a0a1a,scale:1.0},desc:'Mass warping light and space around it.'},
{id:'ancient_golem',name:'Ancient Golem',level:75,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x6a5a4a,scale:1.15},desc:'Millennia-old construct of forgotten origin.'},
{id:'oblivion_wraith',name:'Oblivion Wraith',level:75,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x1a0a5a,scale:1.0},desc:'Wraith from the edge of oblivion itself.'},
{id:'abyss_mass',name:'Abyss Mass',level:76,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x0a0a2a,scale:1.0},desc:'Mass drawn from the deepest abyss.'},
{id:'void_golem',name:'Void Golem',level:76,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x2a2a5a,scale:1.15},desc:'Golem infused with void energy.'},
{id:'eternal_wraith',name:'Eternal Wraith',level:77,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x5a4a9a,scale:1.05},desc:'Immortal wraith existing since creation.'},
{id:'null_mass',name:'Null Mass',level:77,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x050510,scale:1.05},desc:'Mass of absolute nothingness.'},
{id:'prism_golem',name:'Prism Golem',level:78,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x8a6aaa,scale:1.2},desc:'Multi-faceted golem splitting light.'},
{id:'phantom_wraith',name:'Phantom Wraith',level:78,combatStyle:'void',area:'alien-wastes',meshTemplate:'void_wraith',meshParams:{color:0x3a3a8a,scale:1.05},desc:'Nearly imperceptible wraith.'},
{id:'omega_mass',name:'Omega Mass',level:79,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'dark_entity',meshParams:{color:0x1a0a3a,scale:1.1},desc:'Final form of dark energy evolution.'},
{id:'crystal_colossus',name:'Crystal Colossus',level:80,combatStyle:'nano',area:'alien-wastes',meshTemplate:'crystal_golem',meshParams:{color:0x7a8aaa,scale:1.6},isBoss:true,desc:'Enormous crystalline titan guarding ancient secrets.'},

// === Levels 81-99: Eldritch (alien-wastes) ===
{id:'watcher_eye',name:'Watcher Eye',level:81,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x6a3a6a,scale:0.7,irisColor:0xff4444},desc:'Floating eye observing all movement.'},
{id:'minor_warper',name:'Minor Warper',level:81,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x4a4a7a,scale:0.6},desc:'Small anomaly bending local space.'},
{id:'seeker_eye',name:'Seeker Eye',level:82,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x5a2a7a,scale:0.75,irisColor:0xff6644},desc:'Tracking eye that never loses its quarry.'},
{id:'phase_warper',name:'Phase Warper',level:82,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x5a3a8a,scale:0.65},desc:'Anomaly shifting between phases of matter.'},
{id:'doom_eye',name:'Doom Eye',level:83,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x4a1a6a,scale:0.8,irisColor:0xaa2222},desc:'Eye projecting beams of destruction.'},
{id:'rift_warper',name:'Rift Warper',level:83,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x3a4a8a,scale:0.7},desc:'Anomaly opening unstable dimensional rifts.'},
{id:'terror_eye',name:'Terror Eye',level:84,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x7a2a5a,scale:0.8,irisColor:0xff3366},desc:'Eye inducing crippling terror.'},
{id:'gravity_warper',name:'Gravity Warper',level:84,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x2a3a7a,scale:0.7},desc:'Anomaly distorting gravitational fields.'},
{id:'blight_eye',name:'Blight Eye',level:85,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x3a5a3a,scale:0.85,irisColor:0x44ff44},desc:'Eye spreading corruption with its gaze.'},
{id:'time_warper',name:'Time Warper',level:85,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x6a5a3a,scale:0.75},desc:'Anomaly creating pockets of dilated time.'},
{id:'tyrant_eye',name:'Tyrant Eye',level:86,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x6a2a4a,scale:0.85,irisColor:0xff8844},desc:'Commanding eye dominating lesser minds.'},
{id:'entropy_warper',name:'Entropy Warper',level:86,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x4a2a6a,scale:0.75},desc:'Anomaly accelerating entropy in its vicinity.'},
{id:'void_eye',name:'Void Eye',level:87,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x2a1a6a,scale:0.9,irisColor:0x8844ff},desc:'Eye peering from the void itself.'},
{id:'chaos_warper',name:'Chaos Warper',level:87,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x6a3a5a,scale:0.8},desc:'Anomaly of pure chaotic energy.'},
{id:'death_eye',name:'Death Eye',level:88,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x4a0a4a,scale:0.9,irisColor:0xff0044},desc:'Eye whose gaze brings death.'},
{id:'dimensional_warper',name:'Dimensional Warper',level:88,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x5a4a6a,scale:0.8},desc:'Anomaly merging multiple dimensions.'},
{id:'reality_eater',name:'Reality Eater',level:90,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x8a3a8a,scale:1.4,irisColor:0xff44ff},isBoss:true,desc:'Enormous eye consuming reality itself.'},
{id:'elder_eye',name:'Elder Eye',level:91,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x3a2a8a,scale:0.95,irisColor:0xaa44ff},desc:'Ancient eye of unfathomable wisdom.'},
{id:'omega_warper',name:'Omega Warper',level:91,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x3a3a7a,scale:0.85},desc:'Ultimate form of spatial anomaly.'},
{id:'cosmic_eye',name:'Cosmic Eye',level:92,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x2a3a8a,scale:1.0,irisColor:0x4488ff},desc:'Eye perceiving cosmic truths.'},
{id:'null_warper',name:'Null Warper',level:92,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x1a1a5a,scale:0.85},desc:'Anomaly of absolute nothingness.'},
{id:'oblivion_eye',name:'Oblivion Eye',level:93,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x1a0a5a,scale:1.0,irisColor:0x4422ff},desc:'Eye from beyond the edge of existence.'},
{id:'singularity_warper',name:'Singularity Warper',level:93,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x0a0a4a,scale:0.9},desc:'Point of infinite spatial distortion.'},
{id:'nightmare_eye',name:'Nightmare Eye',level:94,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x5a1a7a,scale:1.0,irisColor:0xcc22ff},desc:'Eye from the realm of nightmares.'},
{id:'apex_warper',name:'Apex Warper',level:94,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x4a3a8a,scale:0.9},desc:'Peak of reality-warping evolution.'},
{id:'titan_eye',name:'Titan Eye',level:95,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x6a4a8a,scale:1.05,irisColor:0xaa66ff},desc:'Colossal eye of a slumbering titan.'},
{id:'prime_warper',name:'Prime Warper',level:95,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x5a5a8a,scale:0.9},desc:'First and most powerful of all warpers.'},
{id:'dread_eye',name:'Dread Eye',level:96,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x4a2a7a,scale:1.05,irisColor:0xee44aa},desc:'Eye radiating absolute dread.'},
{id:'genesis_warper',name:'Genesis Warper',level:96,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x6a6a8a,scale:0.95},desc:'Anomaly rewriting laws of physics.'},
{id:'ancient_eye',name:'Ancient Eye',level:97,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x3a3a9a,scale:1.1,irisColor:0x6644ff},desc:'Eye witnessing the birth of stars.'},
{id:'eternal_warper',name:'Eternal Warper',level:97,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x4a4a9a,scale:0.95},desc:'Timeless anomaly existing outside reality.'},
{id:'godseye',name:'God\'s Eye',level:98,combatStyle:'void',area:'alien-wastes',meshTemplate:'eldritch_eye',meshParams:{color:0x5a5aaa,scale:1.1,irisColor:0xffffff},desc:'Eye of a being beyond comprehension.'},
{id:'the_formless_one',name:'The Formless One',level:99,combatStyle:'tesla',area:'alien-wastes',meshTemplate:'reality_warper',meshParams:{color:0x8a6aaa,scale:1.5},isBoss:true,desc:'Entity of pure unreality, a living paradox.'},

// === Levels 100-140: Abyssal (the-abyss) ===
{id:'abyss_lurker',name:'Abyss Lurker',level:100,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x0a0a3a,scale:0.6},desc:'First creature encountered in the abyss.'},
{id:'deep_shade',name:'Deep Shade',level:102,combatStyle:'tesla',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x0a0520,scale:0.6},desc:'Shadow given form in the deep.'},
{id:'abyss_eel',name:'Abyss Eel',level:104,combatStyle:'nano',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x1a1a4a,scale:0.65},desc:'Elongated predator of dark waters.'},
{id:'void_tendril',name:'Void Tendril',level:106,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x1a0a3a,scale:0.65},desc:'Writhing tendril reaching from the dark.'},
{id:'depth_serpent',name:'Depth Serpent',level:108,combatStyle:'tesla',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x0a1a4a,scale:0.7},desc:'Serpent adapted to crushing pressures.'},
{id:'abyssal_leviathan',name:'Abyssal Leviathan',level:110,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x1a0a5a,scale:1.4},isBoss:true,desc:'Massive serpent ruling the upper abyss.'},
{id:'shadow_angler',name:'Shadow Angler',level:112,combatStyle:'nano',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x0a0a2a,scale:0.7},desc:'Lures prey with bioluminescent glow.'},
{id:'dark_leech',name:'Dark Leech',level:114,combatStyle:'tesla',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x2a0a2a,scale:0.75},desc:'Parasitic creature draining all energy.'},
{id:'abyss_maw',name:'Abyss Maw',level:116,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x1a0a2a,scale:0.75},desc:'All mouth and hunger from the deep.'},
{id:'pressure_serpent',name:'Pressure Serpent',level:118,combatStyle:'nano',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x0a2a3a,scale:0.8},desc:'Serpent using pressure waves as weapons.'},
{id:'void_kraken',name:'Void Kraken',level:120,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x0a0a4a,scale:0.85},desc:'Multi-tentacled terror of the void depths.'},
{id:'abyssal_devourer',name:'Abyssal Devourer',level:125,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x2a0a4a,scale:1.4},isBoss:true,desc:'Insatiable hunger consuming all matter.'},
{id:'brine_serpent',name:'Brine Serpent',level:122,combatStyle:'tesla',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x1a2a3a,scale:0.85},desc:'Serpent corroding with toxic brine.'},
{id:'null_horror',name:'Null Horror',level:124,combatStyle:'nano',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x050510,scale:0.8},desc:'Horror from the space between dimensions.'},
{id:'titan_eel',name:'Titan Eel',level:126,combatStyle:'tesla',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x1a1a5a,scale:0.9},desc:'Enormous electric eel of devastating power.'},
{id:'abyss_wraith',name:'Abyss Wraith',level:128,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x0a0a1a,scale:0.85},desc:'Spectral horror phasing through the abyss.'},
{id:'elder_serpent',name:'Elder Serpent',level:130,combatStyle:'nano',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x1a0a3a,scale:0.95},desc:'Ancient serpent of immense size and wisdom.'},
{id:'doom_horror',name:'Doom Horror',level:132,combatStyle:'tesla',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x1a0a1a,scale:0.9},desc:'Horror whose presence spells certain doom.'},
{id:'apex_serpent',name:'Apex Serpent',level:134,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x0a1a2a,scale:1.0},desc:'Top predator of the abyssal depths.'},
{id:'omega_horror',name:'Omega Horror',level:136,combatStyle:'nano',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x2a1a2a,scale:0.95},desc:'Final evolution of abyssal horror.'},
{id:'cosmic_serpent',name:'Cosmic Serpent',level:138,combatStyle:'tesla',area:'the-abyss',meshTemplate:'abyssal_serpent',meshParams:{color:0x1a2a5a,scale:1.0},desc:'Serpent woven from cosmic threads.'},
{id:'ancient_horror',name:'Ancient Horror',level:140,combatStyle:'void',area:'the-abyss',meshTemplate:'abyssal_horror',meshParams:{color:0x1a0a4a,scale:1.0},desc:'Horror from the dawn of the universe.'},

// === Levels 141-200: Cosmic (the-abyss) ===
{id:'cosmic_drone',name:'Cosmic Drone',level:142,combatStyle:'nano',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x2a2a5a,scale:0.7},desc:'Automaton enforcing cosmic law.'},
{id:'star_fragment',name:'Star Fragment',level:144,combatStyle:'tesla',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x5a4a2a,scale:0.5},desc:'Living shard of a dead star.'},
{id:'cosmic_guard',name:'Cosmic Guard',level:146,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x3a3a6a,scale:0.75},desc:'Sentinel guarding cosmic boundaries.'},
{id:'nova_shard',name:'Nova Shard',level:148,combatStyle:'nano',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x7a4a2a,scale:0.55},desc:'Remnant of a supernova explosion.'},
{id:'cosmic_warden',name:'Cosmic Warden',level:150,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x4a4a8a,scale:1.3},isBoss:true,desc:'Warden of the cosmic barrier between realms.'},
{id:'nebula_knight',name:'Nebula Knight',level:152,combatStyle:'nano',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x3a4a6a,scale:0.8},desc:'Knight forged in nebula fire.'},
{id:'solar_remnant',name:'Solar Remnant',level:154,combatStyle:'tesla',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x8a6a1a,scale:0.6},desc:'Echo of a long-dead sun.'},
{id:'void_knight',name:'Void Knight',level:156,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x1a1a5a,scale:0.85},desc:'Knight sworn to serve the void.'},
{id:'pulsar_shard',name:'Pulsar Shard',level:158,combatStyle:'tesla',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x4a6a8a,scale:0.65},desc:'Pulsating fragment of compressed energy.'},
{id:'cosmic_champion',name:'Cosmic Champion',level:160,combatStyle:'nano',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x5a5a8a,scale:0.9},desc:'Elite warrior of cosmic origin.'},
{id:'quasar_core',name:'Quasar Core',level:162,combatStyle:'tesla',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x6a5a3a,scale:0.7},desc:'Intensely radiating core of cosmic energy.'},
{id:'stellar_guard',name:'Stellar Guard',level:164,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x4a3a7a,scale:0.9},desc:'Guard drawn from stellar matter.'},
{id:'cosmic_juggernaut',name:'Cosmic Juggernaut',level:166,combatStyle:'nano',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x3a3a5a,scale:0.95},desc:'Unstoppable cosmic war machine.'},
{id:'magnetar_shard',name:'Magnetar Shard',level:168,combatStyle:'tesla',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x3a5a7a,scale:0.75},desc:'Highly magnetic cosmic fragment.'},
{id:'cosmic_arbiter',name:'Cosmic Arbiter',level:170,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x5a4a9a,scale:0.95},desc:'Judge of cosmic conflicts.'},
{id:'the_primordial',name:'The Primordial',level:175,combatStyle:'nano',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x4a3a6a,scale:1.4},isBoss:true,desc:'Being from before the dawn of creation.'},
{id:'genesis_sentinel',name:'Genesis Sentinel',level:178,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x6a5a9a,scale:1.0},desc:'Guardian since the genesis of time.'},
{id:'cosmic_herald',name:'Cosmic Herald',level:180,combatStyle:'tesla',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x5a5a7a,scale:0.8},desc:'Herald announcing cosmic cataclysms.'},
{id:'omega_sentinel',name:'Omega Sentinel',level:185,combatStyle:'nano',area:'the-abyss',meshTemplate:'cosmic_sentinel',meshParams:{color:0x4a4a7a,scale:1.05},desc:'Final evolution of cosmic sentinels.'},
{id:'reality_anchor',name:'Reality Anchor',level:190,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x3a3a8a,scale:0.85},desc:'Entity anchoring reality in the cosmic void.'},
{id:'cosmic_titan',name:'Cosmic Titan',level:195,combatStyle:'tesla',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x2a2a7a,scale:0.9},desc:'Towering entity of cosmic might.'},
{id:'entropy_incarnate',name:'Entropy Incarnate',level:200,combatStyle:'void',area:'the-abyss',meshTemplate:'cosmic_titan',meshParams:{color:0x0a0a3a,scale:1.6},isBoss:true,desc:'The living embodiment of entropy itself.'},
];

// ========================================
// Build ENEMY_TYPES from ENEMY_DEFS
// ========================================
var ENEMY_TYPES = {};
(function(){
    for(var i=0;i<ENEMY_DEFS.length;i++){
        var d=ENEMY_DEFS[i];
        if(d.explicit){
            // Preserve existing enemy stats exactly
            var e={name:d.name,level:d.level,hp:d.hp,maxHp:d.maxHp,damage:d.damage,defense:d.defense,
                attackSpeed:d.attackSpeed,aggroRange:d.aggroRange,leashRange:d.leashRange,
                combatStyle:d.combatStyle,respawnTime:d.respawnTime,area:d.area,desc:d.desc,
                lootTable:d.lootTable,meshTemplate:d.meshTemplate};
            if(d.isBoss) e.isBoss=true;
            if(d.meshParams) e.meshParams=d.meshParams;
            ENEMY_TYPES[d.id]=e;
        } else {
            // Generate stats from formulas
            var stats=computeEnemyStats(d.level,!!d.isBoss);
            var loot=generateLootTable(d.level,!!d.isBoss,d.combatStyle);
            var e={name:d.name,level:d.level,hp:stats.hp,maxHp:stats.maxHp,damage:stats.damage,
                defense:stats.defense,attackSpeed:stats.attackSpeed,aggroRange:stats.aggroRange,
                leashRange:stats.leashRange,combatStyle:d.combatStyle,respawnTime:stats.respawnTime,
                area:d.area,desc:d.desc,lootTable:loot,meshTemplate:d.meshTemplate};
            if(d.isBoss) e.isBoss=true;
            if(d.meshParams) e.meshParams=d.meshParams;
            ENEMY_TYPES[d.id]=e;
        }
    }
})();

function buildChithariMesh(v){
    const g=new THREE.Group(),s=v==='warrior'?1.4:1,bc=v==='warrior'?0x6a3a1a:0x5a3a1a;
    // Segmented body: thorax + abdomen
    var thorax=new THREE.Mesh(new THREE.SphereGeometry(0.6*s,8,6),new THREE.MeshLambertMaterial({color:bc}));
    thorax.scale.set(1,0.5,1);thorax.position.y=0.5*s;thorax.castShadow=true;g.add(thorax);
    var abdomen=new THREE.Mesh(new THREE.SphereGeometry(0.7*s,8,6),new THREE.MeshLambertMaterial({color:v==='warrior'?0x7a4a2a:0x6a4a2a}));
    abdomen.scale.set(1,0.4,1.3);abdomen.position.set(0,0.4*s,-0.5*s);abdomen.castShadow=true;g.add(abdomen);
    // Carapace ridges
    for(var ri=0;ri<3;ri++){var ridge=new THREE.Mesh(new THREE.BoxGeometry(0.5*s,0.04*s,0.08*s),new THREE.MeshLambertMaterial({color:v==='warrior'?0x8a5a2a:0x7a4a1a}));ridge.position.set(0,0.58*s,-0.15*s+ri*0.25*s);g.add(ridge);}
    // Jointed legs (6 total, 2 segments each)
    var legMat=new THREE.MeshLambertMaterial({color:0x3a2a10});
    for(var i=0;i<6;i++){var side=i<3?-1:1,idx=i%3;
        var upper=new THREE.Mesh(new THREE.CylinderGeometry(0.05*s,0.04*s,0.25*s,4),legMat);upper.position.set(side*0.55*s,0.3*s,(idx-1)*0.35*s);upper.rotation.z=side*0.7;g.add(upper);
        var joint=new THREE.Mesh(new THREE.SphereGeometry(0.04*s,4,4),legMat);joint.position.set(side*0.75*s,0.18*s,(idx-1)*0.35*s);g.add(joint);
        var lower=new THREE.Mesh(new THREE.CylinderGeometry(0.04*s,0.02*s,0.25*s,4),legMat);lower.position.set(side*0.85*s,0.08*s,(idx-1)*0.35*s);lower.rotation.z=side*0.3;g.add(lower);
    }
    // Mandibles
    var mandMat=new THREE.MeshLambertMaterial({color:0x8a5a2a});
    for(var side=-1;side<=1;side+=2){
        var mand=new THREE.Mesh(new THREE.CylinderGeometry(0.06*s,0.02*s,0.4*s,4),mandMat);mand.position.set(side*0.2*s,0.45*s,0.85*s);mand.rotation.x=-0.6;mand.rotation.z=side*0.3;g.add(mand);
        var tooth=new THREE.Mesh(new THREE.ConeGeometry(0.03*s,0.12*s,3),mandMat);tooth.position.set(side*0.15*s,0.42*s,1.0*s);tooth.rotation.x=-0.8;g.add(tooth);
    }
    // Antennae
    for(var side=-1;side<=1;side+=2){var ant=new THREE.Mesh(new THREE.CylinderGeometry(0.015*s,0.01*s,0.4*s,3),new THREE.MeshLambertMaterial({color:0x5a3a1a}));ant.position.set(side*0.15*s,0.7*s,0.6*s);ant.rotation.x=-0.5;ant.rotation.z=side*0.2;g.add(ant);}
    // Eyes (emissive)
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.06*s,6,6),new THREE.MeshBasicMaterial({color:0xff2222,transparent:true,opacity:0.9}));eye.position.set(side*0.2*s,0.65*s,0.7*s);g.add(eye);}
    return g;
}

function buildVoidjellyMesh(){
    const g=new THREE.Group();
    // Bell dome (higher res)
    var dome=new THREE.Mesh(new THREE.SphereGeometry(1,12,8,0,Math.PI*2,0,Math.PI/2),new THREE.MeshLambertMaterial({color:0x6688cc,transparent:true,opacity:0.5,emissive:0x2244aa,emissiveIntensity:0.3}));
    dome.position.y=2;g.add(dome);
    // Bell rim torus
    var rim=new THREE.Mesh(new THREE.TorusGeometry(0.95,0.08,6,12),new THREE.MeshLambertMaterial({color:0x5577bb,transparent:true,opacity:0.4,emissive:0x223366,emissiveIntensity:0.2}));
    rim.position.y=2.0;rim.rotation.x=Math.PI/2;g.add(rim);
    // Mid-band
    var midBand=new THREE.Mesh(new THREE.TorusGeometry(0.7,0.05,6,10),new THREE.MeshLambertMaterial({color:0x7799dd,transparent:true,opacity:0.35}));
    midBand.position.y=2.3;midBand.rotation.x=Math.PI/2;g.add(midBand);
    // Inner core
    var core=new THREE.Mesh(new THREE.SphereGeometry(0.3,8,8),new THREE.MeshBasicMaterial({color:0x88aaff}));
    core.position.y=2.2;g.add(core);
    // Inner glow
    var innerGlow=new THREE.Mesh(new THREE.SphereGeometry(0.4,8,8),new THREE.MeshBasicMaterial({color:0xaaccff,transparent:true,opacity:0.15}));
    innerGlow.position.y=2.2;g.add(innerGlow);
    // 10 tentacles at two radii with varying lengths
    var tentMat=new THREE.MeshLambertMaterial({color:0x5577bb,transparent:true,opacity:0.6});
    for(var i=0;i<10;i++){
        var a=(i/10)*Math.PI*2;
        var rad=i%2===0?0.4:0.7;
        var len=1.0+((i%3)/3)*1.0;
        var t=new THREE.Mesh(new THREE.CylinderGeometry(0.02,0.05,len,4),tentMat);
        t.position.set(Math.cos(a)*rad,2.0-len/2,Math.sin(a)*rad);g.add(t);
        // Tip sphere
        var tip=new THREE.Mesh(new THREE.SphereGeometry(0.04,4,4),new THREE.MeshBasicMaterial({color:0xaaddff}));
        tip.position.set(Math.cos(a)*rad,2.0-len,Math.sin(a)*rad);g.add(tip);
    }
    // Bioluminescent spots on dome
    for(var i=0;i<5;i++){var a=(i/5)*Math.PI*2;var spot=new THREE.Mesh(new THREE.SphereGeometry(0.06,4,4),new THREE.MeshBasicMaterial({color:0xaaddff}));spot.position.set(Math.cos(a)*0.55,2.35+Math.sin(a*2)*0.1,Math.sin(a)*0.55);g.add(spot);}
    return g;
}

function buildSporeclawMesh(){
    const g=new THREE.Group();
    // Segmented body: thorax + abdomen
    var thorax=new THREE.Mesh(new THREE.BoxGeometry(1.0,0.7,1.0),new THREE.MeshLambertMaterial({color:0x2a5a2a}));
    thorax.position.y=1;thorax.castShadow=true;g.add(thorax);
    var abdomen=new THREE.Mesh(new THREE.BoxGeometry(0.8,0.6,0.9),new THREE.MeshLambertMaterial({color:0x1a4a1a}));
    abdomen.position.set(0,0.9,-0.8);abdomen.castShadow=true;g.add(abdomen);
    // Spine ridges
    for(var ri=0;ri<5;ri++){var spine=new THREE.Mesh(new THREE.ConeGeometry(0.06,0.2,4),new THREE.MeshLambertMaterial({color:0x3a6a3a}));spine.position.set(0,1.4,-0.6+ri*0.3);g.add(spine);}
    // Articulated claws
    var clawMat=new THREE.MeshLambertMaterial({color:0x4a8a2a});
    for(var side=-1;side<=1;side+=2){
        var upper=new THREE.Mesh(new THREE.BoxGeometry(0.12,0.6,0.12),clawMat);upper.position.set(side*0.8,1.3,0.5);upper.rotation.z=side*(-0.3);g.add(upper);
        var fore=new THREE.Mesh(new THREE.BoxGeometry(0.1,0.5,0.1),clawMat);fore.position.set(side*0.95,1.6,0.7);fore.rotation.x=-0.4;g.add(fore);
        // Pincer tips
        var pin1=new THREE.Mesh(new THREE.ConeGeometry(0.06,0.35,4),clawMat);pin1.position.set(side*0.9,1.7,1.0);pin1.rotation.x=-0.6;pin1.rotation.z=side*0.2;g.add(pin1);
        var pin2=new THREE.Mesh(new THREE.ConeGeometry(0.05,0.3,4),clawMat);pin2.position.set(side*1.0,1.65,0.95);pin2.rotation.x=-0.5;pin2.rotation.z=side*(-0.2);g.add(pin2);
    }
    // Spore glands with stems (deterministic positions)
    var sporeMat=new THREE.MeshLambertMaterial({color:0xaa44aa,emissive:0x661166,emissiveIntensity:0.6});
    var sporePos=[{x:-0.4,y:1.35,z:0.2},{x:0.35,y:1.4,z:-0.1},{x:-0.2,y:1.3,z:-0.5},{x:0.3,y:1.35,z:-0.6}];
    sporePos.forEach(function(sp){
        var stem=new THREE.Mesh(new THREE.CylinderGeometry(0.03,0.03,0.15,3),new THREE.MeshLambertMaterial({color:0x3a5a3a}));stem.position.set(sp.x,sp.y-0.1,sp.z);g.add(stem);
        var gland=new THREE.Mesh(new THREE.SphereGeometry(0.18,6,6),sporeMat);gland.position.set(sp.x,sp.y,sp.z);g.add(gland);
    });
    // Legs (thigh + lower + foot)
    var legDark=new THREE.MeshLambertMaterial({color:0x1a3a1a});
    for(var i=0;i<4;i++){var side=i<2?-1:1,idx=i%2;
        var thigh=new THREE.Mesh(new THREE.CylinderGeometry(0.08,0.06,0.5,4),legDark);thigh.position.set(side*0.5,0.6,(idx-0.5)*0.8);thigh.rotation.z=side*0.3;g.add(thigh);
        var shin=new THREE.Mesh(new THREE.CylinderGeometry(0.06,0.04,0.5,4),legDark);shin.position.set(side*0.6,0.25,(idx-0.5)*0.8);g.add(shin);
        var foot=new THREE.Mesh(new THREE.SphereGeometry(0.06,4,4),legDark);foot.position.set(side*0.6,0.04,(idx-0.5)*0.8);g.add(foot);
    }
    // Segmented tail
    var tailMat=new THREE.MeshLambertMaterial({color:0x6a3a6a});
    var ts=[{x:0,y:1.2,z:-1.1,r:0.5},{x:0,y:1.35,z:-1.35,r:0.7},{x:0,y:1.55,z:-1.55,r:0.9}];
    ts.forEach(function(tp){var tc=new THREE.Mesh(new THREE.ConeGeometry(0.08,0.3,4),tailMat);tc.position.set(tp.x,tp.y,tp.z);tc.rotation.x=tp.r;g.add(tc);});
    var stinger=new THREE.Mesh(new THREE.ConeGeometry(0.04,0.2,3),new THREE.MeshBasicMaterial({color:0x9944cc}));stinger.position.set(0,1.7,-1.7);stinger.rotation.x=1.0;g.add(stinger);
    // Head eyes
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.05,4,4),new THREE.MeshBasicMaterial({color:0xff4444}));eye.position.set(side*0.3,1.15,0.55);g.add(eye);}
    return g;
}

function buildGravlurkMesh(){
    const g=new THREE.Group();
    // Main body (higher res)
    var body=new THREE.Mesh(new THREE.SphereGeometry(2,12,8),new THREE.MeshLambertMaterial({color:0x2a1a3a,emissive:0x1a0a2a,emissiveIntensity:0.3}));
    body.scale.set(1,0.6,1.8);body.position.y=1.2;body.castShadow=true;g.add(body);
    // Craggy protrusions
    var cragMat=new THREE.MeshLambertMaterial({color:0x3a2a4a});
    for(var ci=0;ci<10;ci++){var ca=(ci/10)*Math.PI*2;var crag=new THREE.Mesh(new THREE.TetrahedronGeometry(0.25+Math.sin(ci*1.7)*0.1,0),cragMat);crag.position.set(Math.cos(ca)*1.4,1.2+Math.sin(ca*3)*0.3,Math.sin(ca)*2.2);crag.rotation.set(ci*0.7,ci*1.1,ci*0.5);g.add(crag);}
    // Glowing cracks
    var crackMat=new THREE.MeshBasicMaterial({color:0xff44ff,transparent:true,opacity:0.6});
    for(var fi=0;fi<5;fi++){var fa=(fi/5)*Math.PI*2;var crack=new THREE.Mesh(new THREE.BoxGeometry(0.03,0.02,0.6+fi*0.1),crackMat);crack.position.set(Math.cos(fa)*1.0,1.1+fi*0.08,Math.sin(fa)*1.6);crack.rotation.y=fa;g.add(crack);}
    // Jointed eye stalks + larger eyes with pupils
    for(var side=-1;side<=1;side+=2){
        var stLower=new THREE.Mesh(new THREE.CylinderGeometry(0.12,0.08,0.6,5),new THREE.MeshLambertMaterial({color:0x3a2a4a}));stLower.position.set(side*0.5,1.8,2.2);g.add(stLower);
        var stJoint=new THREE.Mesh(new THREE.SphereGeometry(0.08,4,4),new THREE.MeshLambertMaterial({color:0x3a2a4a}));stJoint.position.set(side*0.5,2.15,2.2);g.add(stJoint);
        var stUpper=new THREE.Mesh(new THREE.CylinderGeometry(0.08,0.06,0.5,5),new THREE.MeshLambertMaterial({color:0x3a2a4a}));stUpper.position.set(side*0.5,2.45,2.3);g.add(stUpper);
        var eye=new THREE.Mesh(new THREE.SphereGeometry(0.22,6,6),new THREE.MeshBasicMaterial({color:0xff44ff}));eye.position.set(side*0.5,2.75,2.35);g.add(eye);
        var pupil=new THREE.Mesh(new THREE.SphereGeometry(0.08,4,4),new THREE.MeshBasicMaterial({color:0x000000}));pupil.position.set(side*0.5,2.75,2.55);g.add(pupil);
    }
    // Maw/mouth
    var maw=new THREE.Mesh(new THREE.TorusGeometry(0.3,0.08,6,8),new THREE.MeshLambertMaterial({color:0x1a0a2a,emissive:0x440044,emissiveIntensity:0.4}));
    maw.position.set(0,0.8,2.8);maw.rotation.x=Math.PI/2;g.add(maw);
    // 12 orbiting debris (preserve userData.isDebris + orbitAngle)
    for(var i=0;i<12;i++){
        var geoType=i%3===0?new THREE.BoxGeometry(0.15,0.15,0.15):new THREE.TetrahedronGeometry(0.15+((i%4)*0.03),0);
        var db=new THREE.Mesh(geoType,new THREE.MeshLambertMaterial({color:0x5a3a7a}));
        var a=(i/12)*Math.PI*2;
        db.position.set(Math.cos(a)*3,1.5+Math.sin(a*2)*0.5,Math.sin(a)*3);
        db.rotation.set(i*0.5,i*0.8,i*0.3);
        db.userData.orbitAngle=a;db.userData.isDebris=true;g.add(db);
    }
    // Gravity aura
    var aura=new THREE.Mesh(new THREE.SphereGeometry(3.5,12,12),new THREE.MeshBasicMaterial({color:0x2a0a4a,transparent:true,opacity:0.05,side:THREE.BackSide}));
    aura.position.y=1.2;g.add(aura);
    return g;
}

function buildNeurowormMesh(){
    const g=new THREE.Group(),segCt=12;
    // 12 segments (preserve userData.segmentIndex)
    for(var i=0;i<segCt;i++){var t=i/segCt,sz=0.5-t*0.25;
        var seg=new THREE.Mesh(new THREE.SphereGeometry(sz,8,8),new THREE.MeshLambertMaterial({color:new THREE.Color().setHSL(0.75-t*0.1,0.5,0.3+t*0.1),emissive:new THREE.Color().setHSL(0.75,0.6,0.1),emissiveIntensity:0.2}));
        seg.position.set(0,0.6+Math.sin(t*Math.PI)*0.3,-i*0.55);seg.userData.segmentIndex=i;seg.castShadow=true;g.add(seg);
        // Segment ridge rings on alternating segments
        if(i%2===0&&i>0){var ring=new THREE.Mesh(new THREE.TorusGeometry(sz*0.8,0.02,4,8),new THREE.MeshLambertMaterial({color:new THREE.Color().setHSL(0.75-t*0.1,0.4,0.25)}));ring.position.set(0,0.6+Math.sin(t*Math.PI)*0.3,-i*0.55);ring.rotation.x=Math.PI/2;g.add(ring);}
    }
    // Neural glow connectors between segments
    var connMat=new THREE.MeshBasicMaterial({color:0xcc66ff,transparent:true,opacity:0.4});
    for(var i=0;i<segCt-1;i++){var t1=i/segCt,t2=(i+1)/segCt;var y1=0.6+Math.sin(t1*Math.PI)*0.3,y2=0.6+Math.sin(t2*Math.PI)*0.3;
        var conn=new THREE.Mesh(new THREE.CylinderGeometry(0.04,0.04,0.3,4),connMat);conn.position.set(0,(y1+y2)/2,(-i*0.55+-(i+1)*0.55)/2);g.add(conn);}
    // Mandible mouth (4 cones around head)
    for(var mi=0;mi<4;mi++){var ma=(mi/4)*Math.PI*2;var mand=new THREE.Mesh(new THREE.ConeGeometry(0.06,0.3,3),new THREE.MeshLambertMaterial({color:0xaa22cc}));mand.position.set(Math.cos(ma)*0.25,0.8,0.2+Math.sin(ma)*0.15);mand.rotation.x=-0.6;g.add(mand);}
    // Antennae with tip spheres
    for(var side=-1;side<=1;side+=2){var ant=new THREE.Mesh(new THREE.CylinderGeometry(0.03,0.01,0.6,4),new THREE.MeshBasicMaterial({color:0xcc44ff}));ant.position.set(side*0.3,1.4,0.2);ant.rotation.z=side*0.3;ant.rotation.x=-0.3;g.add(ant);
        var tip=new THREE.Mesh(new THREE.SphereGeometry(0.04,4,4),new THREE.MeshBasicMaterial({color:0xff66ff}));tip.position.set(side*0.45,1.7,0.35);g.add(tip);}
    // Tail glow bead
    var tailT=(segCt-1)/segCt;
    var tailGlow=new THREE.Mesh(new THREE.SphereGeometry(0.15,6,6),new THREE.MeshBasicMaterial({color:0xaa44ff,transparent:true,opacity:0.5}));
    tailGlow.position.set(0,0.6+Math.sin(tailT*Math.PI)*0.3,-(segCt-1)*0.55-0.3);g.add(tailGlow);
    // Head glow aura
    var headGlow=new THREE.Mesh(new THREE.SphereGeometry(0.35,6,6),new THREE.MeshBasicMaterial({color:0xaa44ff,transparent:true,opacity:0.25}));
    headGlow.position.set(0,1.0,0.1);g.add(headGlow);
    return g;
}

// ========================================
// New Mesh Template Builders (parameterized)
// ========================================

function buildInsectoidMesh(p){
    var g=new THREE.Group(),s=p.scale||1,c=p.color||0x5a3a1a;
    var thorax=new THREE.Mesh(new THREE.SphereGeometry(0.6*s,8,6),new THREE.MeshLambertMaterial({color:c}));
    thorax.scale.set(1,0.5,1);thorax.position.y=0.5*s;thorax.castShadow=true;g.add(thorax);
    var abdomen=new THREE.Mesh(new THREE.SphereGeometry(0.7*s,8,6),new THREE.MeshLambertMaterial({color:c-0x101010>0?c-0x101010:c}));
    abdomen.scale.set(1,0.4,1.3);abdomen.position.set(0,0.4*s,-0.5*s);abdomen.castShadow=true;g.add(abdomen);
    var legMat=new THREE.MeshLambertMaterial({color:0x3a2a10});
    var legCount=p.variant==='queen'?8:6;
    for(var i=0;i<legCount;i++){var side=i<legCount/2?-1:1,idx=i%(legCount/2);
        var upper=new THREE.Mesh(new THREE.CylinderGeometry(0.05*s,0.04*s,0.25*s,4),legMat);upper.position.set(side*0.55*s,0.3*s,(idx-1)*0.35*s);upper.rotation.z=side*0.7;g.add(upper);
        var lower=new THREE.Mesh(new THREE.CylinderGeometry(0.04*s,0.02*s,0.25*s,4),legMat);lower.position.set(side*0.85*s,0.08*s,(idx-1)*0.35*s);lower.rotation.z=side*0.3;g.add(lower);
    }
    for(var side=-1;side<=1;side+=2){var mand=new THREE.Mesh(new THREE.ConeGeometry(0.05*s,0.3*s,4),new THREE.MeshLambertMaterial({color:c+0x202020}));mand.position.set(side*0.15*s,0.42*s,0.8*s);mand.rotation.x=-0.6;mand.rotation.z=side*0.3;g.add(mand);}
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.05*s,6,6),new THREE.MeshBasicMaterial({color:0xff2222}));eye.position.set(side*0.18*s,0.6*s,0.65*s);g.add(eye);}
    if(p.variant==='queen'){var crown=new THREE.Mesh(new THREE.ConeGeometry(0.2*s,0.3*s,6),new THREE.MeshLambertMaterial({color:0xaa8a2a}));crown.position.set(0,0.85*s,0.3*s);g.add(crown);}
    return g;
}

function buildSwarmBugMesh(p){
    var g=new THREE.Group(),s=p.scale||0.4,c=p.color||0x6a5a2a;
    var body=new THREE.Mesh(new THREE.SphereGeometry(0.3*s,6,6),new THREE.MeshLambertMaterial({color:c}));
    body.position.y=0.6*s;body.castShadow=true;g.add(body);
    var wingMat=new THREE.MeshLambertMaterial({color:0xaaaacc,transparent:true,opacity:0.4});
    for(var side=-1;side<=1;side+=2){var wing=new THREE.Mesh(new THREE.ConeGeometry(0.25*s,0.5*s,4),wingMat);wing.position.set(side*0.2*s,0.75*s,-0.1*s);wing.rotation.z=side*0.8;wing.rotation.x=0.3;g.add(wing);}
    var legMat=new THREE.MeshLambertMaterial({color:0x2a2a1a});
    for(var i=0;i<4;i++){var side=i<2?-1:1;var leg=new THREE.Mesh(new THREE.CylinderGeometry(0.02*s,0.01*s,0.2*s,3),legMat);leg.position.set(side*0.15*s,0.35*s,(i%2-0.5)*0.15*s);leg.rotation.z=side*0.5;g.add(leg);}
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.04*s,4,4),new THREE.MeshBasicMaterial({color:0xff4444}));eye.position.set(side*0.1*s,0.65*s,0.2*s);g.add(eye);}
    return g;
}

function buildArachnidMesh(p){
    var g=new THREE.Group(),s=p.scale||0.5,c=p.color||0x3a2a1a;
    var body=new THREE.Mesh(new THREE.BoxGeometry(0.5*s,0.3*s,0.6*s),new THREE.MeshLambertMaterial({color:c}));
    body.position.y=0.5*s;body.castShadow=true;g.add(body);
    var head=new THREE.Mesh(new THREE.SphereGeometry(0.2*s,6,6),new THREE.MeshLambertMaterial({color:c+0x0a0a0a}));
    head.position.set(0,0.5*s,0.4*s);g.add(head);
    var legMat=new THREE.MeshLambertMaterial({color:c-0x0a0a0a>0?c-0x0a0a0a:0x1a1a1a});
    for(var i=0;i<8;i++){var side=i<4?-1:1,idx=i%4;
        var leg=new THREE.Mesh(new THREE.CylinderGeometry(0.03*s,0.02*s,0.45*s,4),legMat);leg.position.set(side*0.4*s,0.3*s,(idx-1.5)*0.15*s);leg.rotation.z=side*0.7;g.add(leg);
        var lower=new THREE.Mesh(new THREE.CylinderGeometry(0.02*s,0.01*s,0.3*s,3),legMat);lower.position.set(side*0.65*s,0.08*s,(idx-1.5)*0.15*s);lower.rotation.z=side*0.2;g.add(lower);
    }
    for(var side=-1;side<=1;side+=2){var fang=new THREE.Mesh(new THREE.ConeGeometry(0.03*s,0.15*s,3),new THREE.MeshLambertMaterial({color:0x8a2a2a}));fang.position.set(side*0.08*s,0.35*s,0.55*s);fang.rotation.x=-0.5;g.add(fang);}
    for(var i=0;i<4;i++){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.025*s,4,4),new THREE.MeshBasicMaterial({color:0xff2222}));eye.position.set((i-1.5)*0.06*s,0.6*s,0.5*s);g.add(eye);}
    return g;
}

function buildJellyfishMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x6688cc,tc=p.tentacles||8;
    var dome=new THREE.Mesh(new THREE.SphereGeometry(0.8*s,10,8,0,Math.PI*2,0,Math.PI/2),new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.5,emissive:c,emissiveIntensity:0.2}));
    dome.position.y=2*s;g.add(dome);
    var core=new THREE.Mesh(new THREE.SphereGeometry(0.25*s,6,6),new THREE.MeshBasicMaterial({color:0xaaddff}));
    core.position.y=2.1*s;g.add(core);
    var tentMat=new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.5});
    for(var i=0;i<tc;i++){var a=(i/tc)*Math.PI*2,rad=i%2===0?0.3*s:0.5*s,len=(0.8+((i%3)/3)*0.8)*s;
        var t=new THREE.Mesh(new THREE.CylinderGeometry(0.02*s,0.04*s,len,4),tentMat);t.position.set(Math.cos(a)*rad,2*s-len/2,Math.sin(a)*rad);g.add(t);
    }
    return g;
}

function buildMantisMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x3a6a3a;
    var torso=new THREE.Mesh(new THREE.BoxGeometry(0.4*s,0.8*s,0.3*s),new THREE.MeshLambertMaterial({color:c}));
    torso.position.y=1.2*s;torso.castShadow=true;g.add(torso);
    var head=new THREE.Mesh(new THREE.SphereGeometry(0.2*s,6,6),new THREE.MeshLambertMaterial({color:c+0x101010}));
    head.position.set(0,1.8*s,0.15*s);g.add(head);
    var bladeMat=new THREE.MeshLambertMaterial({color:c+0x202020});
    for(var side=-1;side<=1;side+=2){
        var upper=new THREE.Mesh(new THREE.BoxGeometry(0.08*s,0.5*s,0.08*s),bladeMat);upper.position.set(side*0.35*s,1.4*s,0.15*s);upper.rotation.z=side*(-0.3);g.add(upper);
        var blade=new THREE.Mesh(new THREE.BoxGeometry(0.04*s,0.6*s,0.06*s),new THREE.MeshLambertMaterial({color:0x88aa44}));blade.position.set(side*0.5*s,1.7*s,0.3*s);blade.rotation.x=-0.4;g.add(blade);
    }
    var legMat=new THREE.MeshLambertMaterial({color:c-0x101010>0?c-0x101010:0x1a1a1a});
    for(var i=0;i<4;i++){var side=i<2?-1:1;var leg=new THREE.Mesh(new THREE.CylinderGeometry(0.04*s,0.03*s,0.6*s,4),legMat);leg.position.set(side*0.2*s,0.5*s,(i%2-0.5)*0.2*s);g.add(leg);}
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.04*s,4,4),new THREE.MeshBasicMaterial({color:0xff4444}));eye.position.set(side*0.1*s,1.85*s,0.3*s);g.add(eye);}
    return g;
}

function buildScorpionMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x5a4a3a,ss=p.stingerSize||1.0;
    var body=new THREE.Mesh(new THREE.BoxGeometry(0.6*s,0.3*s,0.9*s),new THREE.MeshLambertMaterial({color:c}));
    body.position.y=0.5*s;body.castShadow=true;g.add(body);
    var pinMat=new THREE.MeshLambertMaterial({color:c+0x101010});
    for(var side=-1;side<=1;side+=2){
        var arm=new THREE.Mesh(new THREE.BoxGeometry(0.1*s,0.1*s,0.4*s),pinMat);arm.position.set(side*0.45*s,0.5*s,0.5*s);g.add(arm);
        var claw=new THREE.Mesh(new THREE.ConeGeometry(0.06*s,0.2*s,4),pinMat);claw.position.set(side*0.45*s,0.5*s,0.75*s);claw.rotation.x=-Math.PI/2;g.add(claw);
    }
    var tailMat=new THREE.MeshLambertMaterial({color:c-0x0a0a0a>0?c-0x0a0a0a:c});
    for(var i=0;i<4;i++){var seg=new THREE.Mesh(new THREE.SphereGeometry(0.08*s*ss,5,5),tailMat);seg.position.set(0,0.6*s+i*0.2*s*ss,-0.45*s-i*0.15*s);g.add(seg);}
    var stinger=new THREE.Mesh(new THREE.ConeGeometry(0.04*s*ss,0.25*s*ss,4),new THREE.MeshBasicMaterial({color:0xaa44aa}));stinger.position.set(0,0.6*s+4*0.2*s*ss,-0.45*s-4*0.15*s);stinger.rotation.x=0.8;g.add(stinger);
    var legMat=new THREE.MeshLambertMaterial({color:c-0x151515>0?c-0x151515:0x1a1a1a});
    for(var i=0;i<8;i++){var side=i<4?-1:1;var leg=new THREE.Mesh(new THREE.CylinderGeometry(0.03*s,0.02*s,0.3*s,3),legMat);leg.position.set(side*0.35*s,0.2*s,(i%4-1.5)*0.2*s);leg.rotation.z=side*0.6;g.add(leg);}
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.03*s,4,4),new THREE.MeshBasicMaterial({color:0xff2222}));eye.position.set(side*0.12*s,0.6*s,0.45*s);g.add(eye);}
    return g;
}

function buildStalkerMesh(p){
    var g=new THREE.Group(),s=p.scale||0.9,c=p.color||0x2a2a3a;
    var body=new THREE.Mesh(new THREE.BoxGeometry(0.5*s,0.4*s,0.9*s),new THREE.MeshLambertMaterial({color:c}));
    body.position.y=0.8*s;body.castShadow=true;g.add(body);
    var head=new THREE.Mesh(new THREE.BoxGeometry(0.35*s,0.3*s,0.35*s),new THREE.MeshLambertMaterial({color:c+0x0a0a0a}));
    head.position.set(0,0.95*s,0.55*s);g.add(head);
    var snout=new THREE.Mesh(new THREE.ConeGeometry(0.1*s,0.3*s,4),new THREE.MeshLambertMaterial({color:c}));
    snout.position.set(0,0.85*s,0.8*s);snout.rotation.x=-Math.PI/2;g.add(snout);
    var legMat=new THREE.MeshLambertMaterial({color:c-0x0a0a0a>0?c-0x0a0a0a:0x1a1a1a});
    var lp=[[-0.25,0,-0.25],[0.25,0,-0.25],[-0.25,0,0.25],[0.25,0,0.25]];
    for(var i=0;i<4;i++){var leg=new THREE.Mesh(new THREE.CylinderGeometry(0.06*s,0.05*s,0.6*s,5),legMat);leg.position.set(lp[i][0]*s,0.4*s,lp[i][2]*s);g.add(leg);}
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.04*s,4,4),new THREE.MeshBasicMaterial({color:0xffaa00}));eye.position.set(side*0.1*s,1.0*s,0.7*s);g.add(eye);}
    var tail=new THREE.Mesh(new THREE.CylinderGeometry(0.04*s,0.02*s,0.5*s,4),new THREE.MeshLambertMaterial({color:c}));
    tail.position.set(0,0.75*s,-0.65*s);tail.rotation.x=0.4;g.add(tail);
    return g;
}

function buildWormMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x5a4a3a,segCt=p.segments||8;
    for(var i=0;i<segCt;i++){var t=i/segCt,sz=(0.35-t*0.15)*s;
        var seg=new THREE.Mesh(new THREE.SphereGeometry(sz,6,6),new THREE.MeshLambertMaterial({color:new THREE.Color(c).offsetHSL(0,-t*0.05,t*0.05)}));
        seg.position.set(0,0.5*s+Math.sin(t*Math.PI)*0.2*s,-i*0.4*s);seg.userData.segmentIndex=i;seg.castShadow=true;g.add(seg);
    }
    for(var mi=0;mi<4;mi++){var ma=(mi/4)*Math.PI*2;var mand=new THREE.Mesh(new THREE.ConeGeometry(0.04*s,0.2*s,3),new THREE.MeshLambertMaterial({color:c+0x202020}));mand.position.set(Math.cos(ma)*0.15*s,0.6*s,0.15*s+Math.sin(ma)*0.1*s);mand.rotation.x=-0.5;g.add(mand);}
    return g;
}

function buildSlugMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x2a1a3a,dc=p.debris||6;
    var body=new THREE.Mesh(new THREE.SphereGeometry(1.2*s,10,6),new THREE.MeshLambertMaterial({color:c,emissive:c,emissiveIntensity:0.15}));
    body.scale.set(1,0.5,1.3);body.position.y=0.8*s;body.castShadow=true;g.add(body);
    for(var side=-1;side<=1;side+=2){
        var stalk=new THREE.Mesh(new THREE.CylinderGeometry(0.06*s,0.04*s,0.4*s,4),new THREE.MeshLambertMaterial({color:c}));stalk.position.set(side*0.3*s,1.2*s,1.2*s);g.add(stalk);
        var eye=new THREE.Mesh(new THREE.SphereGeometry(0.12*s,5,5),new THREE.MeshBasicMaterial({color:0xff44ff}));eye.position.set(side*0.3*s,1.5*s,1.2*s);g.add(eye);
    }
    for(var i=0;i<dc;i++){var a=(i/dc)*Math.PI*2;
        var db=new THREE.Mesh(i%2===0?new THREE.BoxGeometry(0.12*s,0.12*s,0.12*s):new THREE.TetrahedronGeometry(0.1*s,0),new THREE.MeshLambertMaterial({color:0x5a3a7a}));
        db.position.set(Math.cos(a)*2*s,1*s+Math.sin(a*2)*0.3*s,Math.sin(a)*2*s);db.userData.orbitAngle=a;db.userData.isDebris=true;g.add(db);
    }
    return g;
}

function buildVoidWraithMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x4a4a7a;
    var body=new THREE.Mesh(new THREE.ConeGeometry(0.5*s,1.5*s,6),new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.6,emissive:c,emissiveIntensity:0.3}));
    body.position.y=1.5*s;g.add(body);
    var head=new THREE.Mesh(new THREE.SphereGeometry(0.25*s,6,6),new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.7,emissive:c,emissiveIntensity:0.4}));
    head.position.y=2.4*s;g.add(head);
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.06*s,4,4),new THREE.MeshBasicMaterial({color:0xaaddff}));eye.position.set(side*0.1*s,2.5*s,0.15*s);g.add(eye);}
    var armMat=new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.4});
    for(var side=-1;side<=1;side+=2){var arm=new THREE.Mesh(new THREE.CylinderGeometry(0.02*s,0.06*s,0.8*s,4),armMat);arm.position.set(side*0.5*s,1.8*s,0);arm.rotation.z=side*0.5;g.add(arm);}
    return g;
}

function buildDarkEntityMesh(p){
    var g=new THREE.Group(),s=p.scale||0.7,c=p.color||0x1a1a3a;
    var core=new THREE.Mesh(new THREE.IcosahedronGeometry(0.6*s,1),new THREE.MeshLambertMaterial({color:c,emissive:c,emissiveIntensity:0.4}));
    core.position.y=1.2*s;g.add(core);
    var crackMat=new THREE.MeshBasicMaterial({color:0xaa44ff,transparent:true,opacity:0.6});
    for(var i=0;i<5;i++){var a=(i/5)*Math.PI*2;var crack=new THREE.Mesh(new THREE.BoxGeometry(0.02*s,0.02*s,0.4*s),crackMat);crack.position.set(Math.cos(a)*0.4*s,1.2*s+Math.sin(a*3)*0.1*s,Math.sin(a)*0.4*s);crack.rotation.y=a;g.add(crack);}
    var aura=new THREE.Mesh(new THREE.SphereGeometry(0.9*s,8,8),new THREE.MeshBasicMaterial({color:c,transparent:true,opacity:0.08,side:THREE.BackSide}));
    aura.position.y=1.2*s;g.add(aura);
    return g;
}

function buildCrystalGolemMesh(p){
    var g=new THREE.Group(),s=p.scale||0.9,c=p.color||0x5a5a7a;
    var body=new THREE.Mesh(new THREE.OctahedronGeometry(0.6*s,0),new THREE.MeshLambertMaterial({color:c,emissive:c,emissiveIntensity:0.15}));
    body.position.y=1.3*s;body.castShadow=true;g.add(body);
    var head=new THREE.Mesh(new THREE.OctahedronGeometry(0.25*s,0),new THREE.MeshLambertMaterial({color:c+0x101010}));
    head.position.y=2.1*s;g.add(head);
    var limbMat=new THREE.MeshLambertMaterial({color:c-0x0a0a0a>0?c-0x0a0a0a:c});
    for(var side=-1;side<=1;side+=2){
        var arm=new THREE.Mesh(new THREE.BoxGeometry(0.15*s,0.7*s,0.15*s),limbMat);arm.position.set(side*0.6*s,1.3*s,0);arm.rotation.z=side*0.2;g.add(arm);
        var fist=new THREE.Mesh(new THREE.BoxGeometry(0.2*s,0.2*s,0.2*s),limbMat);fist.position.set(side*0.65*s,0.8*s,0);g.add(fist);
    }
    for(var side=-1;side<=1;side+=2){var leg=new THREE.Mesh(new THREE.BoxGeometry(0.18*s,0.6*s,0.18*s),limbMat);leg.position.set(side*0.25*s,0.35*s,0);g.add(leg);}
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.05*s,4,4),new THREE.MeshBasicMaterial({color:0x44ffaa}));eye.position.set(side*0.1*s,2.2*s,0.15*s);g.add(eye);}
    return g;
}

function buildEldritchEyeMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x6a3a6a,ic=p.irisColor||0xff4444;
    var eyeball=new THREE.Mesh(new THREE.SphereGeometry(0.6*s,10,10),new THREE.MeshLambertMaterial({color:0xeeeecc}));
    eyeball.position.y=2*s;g.add(eyeball);
    var iris=new THREE.Mesh(new THREE.SphereGeometry(0.25*s,8,8),new THREE.MeshBasicMaterial({color:ic}));
    iris.position.set(0,2*s,0.45*s);g.add(iris);
    var pupil=new THREE.Mesh(new THREE.SphereGeometry(0.1*s,6,6),new THREE.MeshBasicMaterial({color:0x000000}));
    pupil.position.set(0,2*s,0.55*s);g.add(pupil);
    var tentMat=new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.7});
    for(var i=0;i<6;i++){var a=(i/6)*Math.PI*2,len=(0.6+i*0.1)*s;
        var t=new THREE.Mesh(new THREE.CylinderGeometry(0.04*s,0.02*s,len,4),tentMat);t.position.set(Math.cos(a)*0.3*s,2*s-0.6*s-len/2,Math.sin(a)*0.3*s);g.add(t);
    }
    var brow=new THREE.Mesh(new THREE.TorusGeometry(0.55*s,0.06*s,4,8,Math.PI),new THREE.MeshLambertMaterial({color:c}));
    brow.position.set(0,2.15*s,0.1*s);brow.rotation.x=0.3;g.add(brow);
    return g;
}

function buildRealityWarperMesh(p){
    var g=new THREE.Group(),s=p.scale||0.7,c=p.color||0x4a4a7a;
    var outer=new THREE.Mesh(new THREE.IcosahedronGeometry(0.7*s,0),new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.4,emissive:c,emissiveIntensity:0.3}));
    outer.position.y=2*s;outer.userData.isWarperOuter=true;g.add(outer);
    var inner=new THREE.Mesh(new THREE.DodecahedronGeometry(0.35*s,0),new THREE.MeshBasicMaterial({color:c+0x222222,transparent:true,opacity:0.6}));
    inner.position.y=2*s;inner.userData.isWarperInner=true;g.add(inner);
    var core=new THREE.Mesh(new THREE.SphereGeometry(0.15*s,6,6),new THREE.MeshBasicMaterial({color:0xaa88ff}));
    core.position.y=2*s;g.add(core);
    for(var i=0;i<4;i++){var a=(i/4)*Math.PI*2;
        var frag=new THREE.Mesh(new THREE.TetrahedronGeometry(0.08*s,0),new THREE.MeshBasicMaterial({color:0xcc88ff,transparent:true,opacity:0.5}));
        frag.position.set(Math.cos(a)*1*s,2*s+Math.sin(a)*0.3*s,Math.sin(a)*1*s);frag.userData.orbitAngle=a;frag.userData.isDebris=true;g.add(frag);
    }
    return g;
}

function buildAbyssalSerpentMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x0a0a3a,segCt=8;
    for(var i=0;i<segCt;i++){var t=i/segCt,sz=(0.3-t*0.1)*s;
        var seg=new THREE.Mesh(new THREE.SphereGeometry(sz,6,6),new THREE.MeshLambertMaterial({color:new THREE.Color(c).offsetHSL(0,0,t*0.05),emissive:new THREE.Color(c),emissiveIntensity:0.2}));
        seg.position.set(Math.sin(t*Math.PI*2)*0.3*s,0.5*s+Math.sin(t*Math.PI)*0.2*s,-i*0.4*s);seg.userData.segmentIndex=i;seg.castShadow=true;g.add(seg);
    }
    var finMat=new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.5});
    for(var side=-1;side<=1;side+=2){var fin=new THREE.Mesh(new THREE.BoxGeometry(0.02*s,0.3*s,0.6*s),finMat);fin.position.set(side*0.35*s,0.7*s,-0.4*s);g.add(fin);}
    for(var side=-1;side<=1;side+=2){var eye=new THREE.Mesh(new THREE.SphereGeometry(0.06*s,4,4),new THREE.MeshBasicMaterial({color:0x44aaff}));eye.position.set(side*0.12*s,0.7*s,0.2*s);g.add(eye);}
    var jaw=new THREE.Mesh(new THREE.ConeGeometry(0.12*s,0.3*s,4),new THREE.MeshLambertMaterial({color:c+0x0a0a1a}));jaw.position.set(0,0.4*s,0.3*s);jaw.rotation.x=-Math.PI/2;g.add(jaw);
    return g;
}

function buildAbyssalHorrorMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x1a0a3a;
    var core=new THREE.Mesh(new THREE.IcosahedronGeometry(0.7*s,1),new THREE.MeshLambertMaterial({color:c,emissive:c,emissiveIntensity:0.3}));
    core.position.y=1.5*s;core.castShadow=true;g.add(core);
    var limbMat=new THREE.MeshLambertMaterial({color:c,transparent:true,opacity:0.7});
    for(var i=0;i<6;i++){var a=(i/6)*Math.PI*2,len=(0.8+Math.sin(i*1.3)*0.3)*s;
        var limb=new THREE.Mesh(new THREE.CylinderGeometry(0.06*s,0.03*s,len,4),limbMat);limb.position.set(Math.cos(a)*0.5*s,1.5*s-len*0.3,Math.sin(a)*0.5*s);limb.rotation.z=Math.cos(a)*0.6;limb.rotation.x=Math.sin(a)*0.6;g.add(limb);
    }
    for(var i=0;i<4;i++){var a=(i/4)*Math.PI*2;var eye=new THREE.Mesh(new THREE.SphereGeometry(0.08*s,5,5),new THREE.MeshBasicMaterial({color:0xff4488}));eye.position.set(Math.cos(a)*0.4*s,1.7*s+Math.sin(a*2)*0.15*s,Math.sin(a)*0.4*s);g.add(eye);}
    var aura=new THREE.Mesh(new THREE.SphereGeometry(1.2*s,8,8),new THREE.MeshBasicMaterial({color:c,transparent:true,opacity:0.05,side:THREE.BackSide}));
    aura.position.y=1.5*s;g.add(aura);
    return g;
}

function buildCosmicSentinelMesh(p){
    var g=new THREE.Group(),s=p.scale||0.9,c=p.color||0x3a3a6a;
    var torso=new THREE.Mesh(new THREE.BoxGeometry(0.6*s,0.9*s,0.35*s),new THREE.MeshLambertMaterial({color:c,emissive:c,emissiveIntensity:0.15}));
    torso.position.y=1.8*s;torso.castShadow=true;g.add(torso);
    var head=new THREE.Mesh(new THREE.BoxGeometry(0.3*s,0.35*s,0.3*s),new THREE.MeshLambertMaterial({color:c+0x101010}));
    head.position.y=2.5*s;g.add(head);
    var limbMat=new THREE.MeshLambertMaterial({color:c-0x0a0a0a>0?c-0x0a0a0a:c});
    for(var side=-1;side<=1;side+=2){
        var arm=new THREE.Mesh(new THREE.CylinderGeometry(0.08*s,0.06*s,0.8*s,5),limbMat);arm.position.set(side*0.5*s,1.7*s,0);arm.rotation.z=side*0.15;g.add(arm);
        var hand=new THREE.Mesh(new THREE.SphereGeometry(0.1*s,5,5),limbMat);hand.position.set(side*0.55*s,1.2*s,0);g.add(hand);
    }
    for(var side=-1;side<=1;side+=2){var leg=new THREE.Mesh(new THREE.CylinderGeometry(0.1*s,0.08*s,1.0*s,5),limbMat);leg.position.set(side*0.2*s,0.6*s,0);g.add(leg);}
    var visor=new THREE.Mesh(new THREE.BoxGeometry(0.25*s,0.06*s,0.05*s),new THREE.MeshBasicMaterial({color:0x44aaff}));
    visor.position.set(0,2.55*s,0.16*s);g.add(visor);
    for(var side=-1;side<=1;side+=2){var plate=new THREE.Mesh(new THREE.BoxGeometry(0.25*s,0.08*s,0.3*s),new THREE.MeshLambertMaterial({color:c+0x0a0a1a}));plate.position.set(side*0.45*s,2.25*s,0);g.add(plate);}
    return g;
}

function buildCosmicTitanMesh(p){
    var g=new THREE.Group(),s=p.scale||0.8,c=p.color||0x2a2a5a;
    var core=new THREE.Mesh(new THREE.IcosahedronGeometry(0.8*s,1),new THREE.MeshLambertMaterial({color:c,emissive:c,emissiveIntensity:0.3}));
    core.position.y=2*s;core.castShadow=true;g.add(core);
    for(var i=0;i<6;i++){var a=(i/6)*Math.PI*2;
        var frag=new THREE.Mesh(new THREE.OctahedronGeometry(0.12*s,0),new THREE.MeshBasicMaterial({color:0x6688ff,transparent:true,opacity:0.6}));
        frag.position.set(Math.cos(a)*1.5*s,2*s+Math.sin(a*2)*0.4*s,Math.sin(a)*1.5*s);frag.userData.orbitAngle=a;frag.userData.isDebris=true;g.add(frag);
    }
    var aura=new THREE.Mesh(new THREE.SphereGeometry(2*s,10,10),new THREE.MeshBasicMaterial({color:c,transparent:true,opacity:0.05,side:THREE.BackSide}));
    aura.position.y=2*s;g.add(aura);
    var halo=new THREE.Mesh(new THREE.TorusGeometry(0.9*s,0.04*s,4,16),new THREE.MeshBasicMaterial({color:0x8888ff,transparent:true,opacity:0.4}));
    halo.position.y=3*s;halo.rotation.x=Math.PI/2;g.add(halo);
    var glow=new THREE.Mesh(new THREE.SphereGeometry(0.4*s,6,6),new THREE.MeshBasicMaterial({color:0xaabbff,transparent:true,opacity:0.3}));
    glow.position.y=2*s;g.add(glow);
    return g;
}

// Simple player mesh for multiplayer remote players
function buildSimplePlayerMesh(bodyColor,headColor){
    var g=new THREE.Group();
    // Body
    var body=new THREE.Mesh(new THREE.BoxGeometry(0.5,0.7,0.3),new THREE.MeshLambertMaterial({color:bodyColor||0x446688}));
    body.position.y=1.15;body.castShadow=true;g.add(body);
    // Head
    var head=new THREE.Mesh(new THREE.SphereGeometry(0.2,8,6),new THREE.MeshLambertMaterial({color:headColor||0xddccbb}));
    head.position.y=1.7;head.castShadow=true;g.add(head);
    // Arms
    var armMat=new THREE.MeshLambertMaterial({color:bodyColor||0x446688});
    var lArm=new THREE.Mesh(new THREE.BoxGeometry(0.15,0.55,0.15),armMat);
    lArm.position.set(-0.35,1.1,0);g.add(lArm);g.userData.leftArm=lArm;
    var rArm=new THREE.Mesh(new THREE.BoxGeometry(0.15,0.55,0.15),armMat);
    rArm.position.set(0.35,1.1,0);g.add(rArm);g.userData.rightArm=rArm;
    // Legs
    var legMat=new THREE.MeshLambertMaterial({color:0x334455});
    var lLeg=new THREE.Mesh(new THREE.BoxGeometry(0.18,0.55,0.18),legMat);
    lLeg.position.set(-0.12,0.4,0);g.add(lLeg);g.userData.leftLeg=lLeg;
    var rLeg=new THREE.Mesh(new THREE.BoxGeometry(0.18,0.55,0.18),legMat);
    rLeg.position.set(0.12,0.4,0);g.add(rLeg);g.userData.rightLeg=rLeg;
    return g;
}

// Mesh template routing map
var MESH_TEMPLATE_BUILDERS = {
    'insectoid':buildInsectoidMesh,'swarm_bug':buildSwarmBugMesh,'arachnid':buildArachnidMesh,
    'jellyfish':buildJellyfishMesh,'mantis':buildMantisMesh,'scorpion':buildScorpionMesh,
    'stalker':buildStalkerMesh,'worm':buildWormMesh,'slug':buildSlugMesh,
    'void_wraith':buildVoidWraithMesh,'dark_entity':buildDarkEntityMesh,'crystal_golem':buildCrystalGolemMesh,
    'eldritch_eye':buildEldritchEyeMesh,'reality_warper':buildRealityWarperMesh,
    'abyssal_serpent':buildAbyssalSerpentMesh,'abyssal_horror':buildAbyssalHorrorMesh,
    'cosmic_sentinel':buildCosmicSentinelMesh,'cosmic_titan':buildCosmicTitanMesh,
};

function buildEnemyMesh(type){
    // Legacy switch for original 6 enemies
    switch(type){
        case 'chithari':return buildChithariMesh('normal');
        case 'chithari_warrior':return buildChithariMesh('warrior');
        case 'voidjelly':return buildVoidjellyMesh();
        case 'sporeclaw':return buildSporeclawMesh();
        case 'gravlurk':return buildGravlurkMesh();
        case 'neuroworm':return buildNeurowormMesh();
    }
    // Template-based routing for new enemies
    var def=ENEMY_TYPES[type];
    if(def && def.meshTemplate && MESH_TEMPLATE_BUILDERS[def.meshTemplate]){
        return MESH_TEMPLATE_BUILDERS[def.meshTemplate](def.meshParams||{});
    }
    return buildChithariMesh('normal');
}

var enemyById = {}; // enemyId → enemy object for shared combat lookup

function spawnEnemies(){
    enemyById = {};
    // Data-driven: spawn enemies in level-band clusters (groups of 1-2 levels)
    var areaConfig = {
        'alien-wastes': {cx:0, cz:-300, radius:700, levelRange:[1,99]},
        'the-abyss': {cx:0, cz:-1200, radius:400, levelRange:[100,200]}
    };
    // Group ENEMY_DEFS by area and level band (every 2 levels)
    var bandMap={};
    for(var di=0;di<ENEMY_DEFS.length;di++){
        var d=ENEMY_DEFS[di];
        if(!ENEMY_TYPES[d.id])continue;
        var ac=areaConfig[d.area];
        if(!ac)continue;
        var band=Math.floor((d.level-1)/2); // 0=lv1-2, 1=lv3-4, 2=lv5-6...
        var key=d.area+'_'+band;
        if(!bandMap[key])bandMap[key]={area:d.area,band:band,enemies:[]};
        bandMap[key].enemies.push(d);
    }
    // Safe zones enemies must never spawn in (hub, bio-lab, etc.)
    var safeZones=[
        {cx:0,cz:0,r:50},    // Station Hub (radius 35 + 15 buffer)
        {cx:-20,cz:20,r:30}   // Bio-Lab (radius 18 + 12 buffer)
    ];
    function inSafeZone(x,z){
        for(var si=0;si<safeZones.length;si++){
            var sz=safeZones[si];
            var dx=x-sz.cx,dz2=z-sz.cz;
            if(dx*dx+dz2*dz2<sz.r*sz.r) return true;
        }
        return false;
    }
    // Distribute bands evenly across full circle using sunflower spiral
    // Group by area so each area's bands fill its own circle
    var bandKeys=Object.keys(bandMap);
    var areaKeys=Object.keys(areaConfig);
    areaKeys.forEach(function(areaKey){
        var ac=areaConfig[areaKey];
        // Collect bands for this area, sorted by level
        var areaBands=[];
        for(var bi=0;bi<bandKeys.length;bi++){
            if(bandMap[bandKeys[bi]].area===areaKey) areaBands.push(bandKeys[bi]);
        }
        areaBands.sort(function(a,b){return bandMap[a].band-bandMap[b].band;});
        var n=areaBands.length;
        if(n===0) return;
        // Golden angle spiral: each point gets equal area share of circle
        var goldenAngle=Math.PI*(3-Math.sqrt(5)); // ~2.3999 radians
        areaBands.forEach(function(key,idx){
        var bg=bandMap[key];
        // Spiral radius: sqrt distribution for even area coverage, use 0.88 of radius
        var r=ac.radius*0.88*Math.sqrt((idx+0.5)/n);
        var theta=idx*goldenAngle;
        var bandX=ac.cx+r*Math.cos(theta);
        var bandZ=ac.cz+r*Math.sin(theta);
        // Add small jitter for natural look
        bandX+=Math.random()*12-6;
        bandZ+=Math.random()*12-6;
        // Clamp within area circle
        var dx=bandX-ac.cx,dz=bandZ-ac.cz;
        var dist=Math.sqrt(dx*dx+dz*dz);
        if(dist>ac.radius*0.92){var s=ac.radius*0.92/dist;bandX=ac.cx+dx*s;bandZ=ac.cz+dz*s;}
        // If band center lands in a safe zone, push it away
        if(inSafeZone(bandX,bandZ)){
            // Rotate 90 degrees and push outward
            bandX=ac.cx+r*Math.cos(theta+Math.PI*0.5);
            bandZ=ac.cz+r*Math.sin(theta+Math.PI*0.5);
            if(inSafeZone(bandX,bandZ)){bandX=ac.cx;bandZ=ac.cz-ac.radius*0.4;}
        }
        // Spawn each enemy type in this band: 1-2 per type, max 4 total per group
        var clusterSpread=8;
        var groupCount=0;
        var maxPerGroup=4;
        bg.enemies.forEach(function(d){
            if(groupCount>=maxPerGroup) return;
            var td=ENEMY_TYPES[d.id];
            var count=d.isBoss?1:Math.floor(Math.random()*2)+1; // 1-2 regular, 1 boss
            for(var i=0;i<count;i++){
                if(groupCount>=maxPerGroup) break;
                var a=Math.random()*Math.PI*2;
                var dist=d.isBoss?0:2+Math.random()*clusterSpread;
                var sx=bandX+Math.cos(a)*dist;
                var sz2=bandZ+Math.sin(a)*dist;
                // Verify within area radius
                var ddx=sx-ac.cx,ddz=sz2-ac.cz;
                if(Math.sqrt(ddx*ddx+ddz*ddz)>ac.radius*0.95){sx=bandX;sz2=bandZ;}
                // Reject if in safe zone — nudge away
                if(inSafeZone(sx,sz2)){
                    sx=bandX+(sx>ac.cx?25:-25);
                    sz2=bandZ-25;
                    if(inSafeZone(sx,sz2)){sx=ac.cx;sz2=ac.cz;}
                }
                var mesh=buildEnemyMesh(d.id);mesh.position.set(sx,0,sz2);
                var enemy={name:td.name,level:td.level,hp:td.hp,maxHp:td.maxHp,damage:td.damage,defense:td.defense,
                    attackSpeed:td.attackSpeed,aggroRange:td.aggroRange,leashRange:td.leashRange,
                    combatStyle:td.combatStyle,respawnTime:td.respawnTime,area:td.area,desc:td.desc,
                    lootTable:td.lootTable,type:d.id,mesh:mesh,alive:true,
                    spawnPos:new THREE.Vector3(sx,0,sz2),state:'idle',wanderTarget:null,
                    wanderTimer:Math.random()*5,attackTimer:td.attackSpeed,stunTimer:0,
                    respawnTimer:0,animPhase:Math.random()*Math.PI*2,deathAnim:0};
                if(td.isBoss) enemy.isBoss=true;
                if(td.meshTemplate) enemy.meshTemplate=td.meshTemplate;
                enemy.enemyId=d.area+'_'+d.id+'_'+i;
                enemyById[enemy.enemyId]=enemy;
                mesh.userData.entityType='enemy';mesh.userData.entity=enemy;
                GameState.scene.add(mesh);GameState.enemies.push(enemy);
                groupCount++;
            }
        });
    }); // end areaBands.forEach
    }); // end areaKeys.forEach
}

// ── Shared Combat: Remote damage/kill (no XP/loot for remote actions) ──
function applyRemoteDamage(enemyId, damage, style, attackerName){
    var enemy=enemyById[enemyId];
    if(!enemy||!enemy.alive) return;
    enemy.hp-=damage;
    if(enemy.hp<0) enemy.hp=0;
    if(enemy.state!=='aggro'){enemy.state='aggro';enemy.wanderTarget=null;}
    var hitPos=enemy.mesh.position.clone().add(new THREE.Vector3(0,1.5,0));
    var styleColors={nano:0x44ff88,tesla:0x44aaff,void:0xaa44ff};
    var sc=styleColors[style]||0xffffff;
    spawnParticles(hitPos,sc,5,1.5,0.4,0.05);
    spawnImpactRing(enemy.mesh.position.clone().add(new THREE.Vector3(0,0.3,0)),sc);
    enemy.hitFlash=0.1;
    var isBig=damage>enemy.maxHp*0.3;
    createHitSplat(hitPos,damage,isBig?'crit':'damage');
    if(enemy.hp<=0){enemy.hp=0;remoteKillEnemy(enemyId,attackerName);}
}

function remoteKillEnemy(enemyId, killerName){
    var enemy=enemyById[enemyId];
    if(!enemy) return;
    enemy.alive=false;enemy.respawnTimer=enemy.respawnTime;
    enemy.deathAnim=1.0;
    var deathPos=enemy.mesh.position.clone().add(new THREE.Vector3(0,1,0));
    spawnParticles(deathPos,0xff4444,20,4,0.8,0.1);
    spawnParticles(deathPos,0xffcc44,10,3,0.7,0.07);
    if(player.combatTarget===enemy){player.combatTarget=null;player.inCombat=false;}
    if(killerName) addChatMessage('multiplayer',killerName+' defeated '+enemy.name+'!');
}

function enemyMoveToward(enemy,target,speed){
    const dx=target.x-enemy.mesh.position.x,dz=target.z-enemy.mesh.position.z,dist=Math.sqrt(dx*dx+dz*dz);
    if(dist<0.1)return;
    var nx=enemy.mesh.position.x+(dx/dist)*speed;
    var nz=enemy.mesh.position.z+(dz/dist)*speed;
    // Dungeon enemies: check wall collision before moving
    if(DungeonState.active&&enemy.isDungeonEnemy){
        if(!isDungeonValidPosition(nx,nz)){
            // Try sliding along X only
            if(isDungeonValidPosition(nx,enemy.mesh.position.z)){
                enemy.mesh.position.x=nx;
            // Try sliding along Z only
            }else if(isDungeonValidPosition(enemy.mesh.position.x,nz)){
                enemy.mesh.position.z=nz;
            }
            // else: blocked both ways, don't move
        }else{
            enemy.mesh.position.x=nx;enemy.mesh.position.z=nz;
        }
    }else{
        enemy.mesh.position.x=nx;enemy.mesh.position.z=nz;
    }
    enemy.mesh.rotation.y=Math.atan2(dx,dz);
}

function enemyAttackPlayer(enemy){
    let dmg=enemy.damage*(0.8+Math.random()*0.4);
    const tri={nano:{strong:'tesla',weak:'void'},tesla:{strong:'void',weak:'nano'},void:{strong:'nano',weak:'tesla'}};
    const et=tri[enemy.combatStyle];
    if(et){if(et.strong===player.combatStyle)dmg*=1.15;else if(et.weak===player.combatStyle)dmg*=0.85;}
    const actual=playerTakeDamage(Math.round(dmg));
    EventBus.emit('floatText',{position:player.mesh.position.clone().add(new THREE.Vector3(0,3,0)),text:'-'+actual,type:'damage'});
    // Auto-retaliate: if enabled and not already fighting, target the attacker
    if(player.autoRetaliate&&!player.combatTarget&&player.hp>0){attackTarget(enemy);}
}

function updateEnemyAI(){
    const dt=GameState.deltaTime,pp=player.mesh.position;
    GameState.enemies.forEach(enemy=>{
        // Distance culling for performance — skip AI + hide far-away idle enemies
        if(!enemy.isDungeonEnemy){
            var cdx=enemy.mesh.position.x-pp.x,cdz=enemy.mesh.position.z-pp.z;
            var distFromPlayer=Math.sqrt(cdx*cdx+cdz*cdz);
            if(distFromPlayer>120&&enemy.state==='idle'&&enemy.alive){
                enemy.mesh.visible=false;return;
            } else if(enemy.alive){
                enemy.mesh.visible=true;
            }
        }
        if(!enemy.alive){
            // Death dissolve animation
            if(enemy.deathAnim>0){enemy.deathAnim-=dt;const s=Math.max(0.01,enemy.deathAnim);enemy.mesh.scale.set(s,s,s);enemy.mesh.position.y=-0.5*(1-s);
                enemy.mesh.traverse(c=>{if(c.material){if(!c.material._origOpacity)c.material._origOpacity=c.material.opacity||1;c.material.transparent=true;c.material.opacity=s*c.material._origOpacity;}});
                if(enemy.deathAnim<=0){enemy.mesh.visible=false;enemy.mesh.traverse(c=>{if(c.material&&c.material._origOpacity){c.material.opacity=c.material._origOpacity;delete c.material._origOpacity;}});}
            }
            enemy.respawnTimer-=dt;if(enemy.respawnTimer<=0&&!enemy.isDungeonEnemy){enemy.alive=true;enemy.hp=enemy.maxHp;enemy.mesh.visible=true;enemy.mesh.position.copy(enemy.spawnPos);enemy.mesh.scale.set(1,1,1);enemy.mesh.position.y=0;enemy.state='idle';enemy.deathAnim=0;}return;
        }
        if(enemy.stunTimer>0){enemy.stunTimer-=dt;return;}
        const dist=enemy.mesh.position.distanceTo(pp),dfs=enemy.mesh.position.distanceTo(enemy.spawnPos);
        enemy.animPhase+=dt*2;
        if(enemy.hitFlash>0){enemy.hitFlash-=dt;var fi=Math.max(0,enemy.hitFlash)/0.15;enemy.mesh.traverse(function(c){if(c.material&&c.material.emissive){c.material.emissive.setRGB(fi,fi,fi);}});if(enemy.hitFlash<=0)enemy.mesh.traverse(function(c){if(c.material&&c.material.emissive)c.material.emissive.setRGB(0,0,0);});}
        // Only process aggro if player is in the enemy's area
        const playerInArea=!enemy.area||player.currentArea===enemy.area;
        switch(enemy.state){
            case 'idle':
                enemy.wanderTimer-=dt;
                if(enemy.wanderTimer<=0){enemy.wanderTimer=3+Math.random()*5;const a=Math.random()*Math.PI*2,d=2+Math.random()*5;enemy.wanderTarget=new THREE.Vector3(enemy.spawnPos.x+Math.cos(a)*d,0,enemy.spawnPos.z+Math.sin(a)*d);}
                if(enemy.wanderTarget){enemyMoveToward(enemy,enemy.wanderTarget,2*dt);if(enemy.mesh.position.distanceTo(enemy.wanderTarget)<1)enemy.wanderTarget=null;}
                if(playerInArea&&dist<enemy.aggroRange){
                    // High-level players don't get aggroed by weak enemies
                    var playerCombatLvl=getHighestCombatLevel();
                    if(playerCombatLvl>enemy.level*2.5)break;
                    enemy.state='aggro';enemy.wanderTarget=null;
                }
                var ft=enemy.meshTemplate||enemy.type;
                if(ft==='voidjelly'||ft==='_legacy'&&enemy.type==='voidjelly'||ft==='jellyfish'||ft==='void_wraith'||ft==='eldritch_eye'||ft==='swarm_bug'||ft==='reality_warper'||ft==='dark_entity')enemy.mesh.position.y=Math.sin(enemy.animPhase*0.5)*0.3;
                break;
            case 'aggro':
                if(!playerInArea||dist>enemy.leashRange||dfs>enemy.leashRange*1.5){enemy.state='returning';break;}
                const ar=enemy.combatStyle==='nano'?3:6;
                if(dist>ar)enemyMoveToward(enemy,pp,4*dt);
                const dx=pp.x-enemy.mesh.position.x,dz=pp.z-enemy.mesh.position.z;
                enemy.mesh.rotation.y=Math.atan2(dx,dz);
                var chronoSlow=0;
                if(player.skills.chronomancy){chronoSlow=getSkillBonus('chronomancy','chronoSlowAura');if(hasSkillMilestone('chronomancy','timeLord'))chronoSlow*=1.25;}
                enemy.attackTimer-=dt*(1-Math.min(0.35,chronoSlow));
                if(enemy.attackTimer<=0&&dist<=ar+1){enemy.attackTimer=enemy.attackSpeed;player.deathRecap.lastDamageSource=enemy.name;enemyAttackPlayer(enemy);
                    if(player.skills.chronomancy&&chronoSlow>0)gainXp('chronomancy',Math.round(2+enemy.level*0.15));
                }
                // Enemies fight to the death (no retreat)
                var ft2=enemy.meshTemplate||enemy.type;
                if(ft2==='voidjelly'||ft2==='_legacy'&&enemy.type==='voidjelly'||ft2==='jellyfish'||ft2==='void_wraith'||ft2==='eldritch_eye'||ft2==='swarm_bug'||ft2==='reality_warper'||ft2==='dark_entity')enemy.mesh.position.y=Math.sin(enemy.animPhase*0.5)*0.3;
                break;
            case 'retreat':
                const ax=enemy.mesh.position.x+(enemy.mesh.position.x-pp.x)*0.5;
                const az=enemy.mesh.position.z+(enemy.mesh.position.z-pp.z)*0.5;
                enemyMoveToward(enemy,new THREE.Vector3(ax,0,az),5*dt);
                if(dfs>enemy.leashRange)enemy.state='returning';
                break;
            case 'returning':
                enemyMoveToward(enemy,enemy.spawnPos,4*dt);
                enemy.hp=Math.min(enemy.maxHp,enemy.hp+enemy.maxHp*0.05*dt);
                if(enemy.mesh.position.distanceTo(enemy.spawnPos)<2){enemy.state='idle';enemy.hp=enemy.maxHp;}
                break;
            case 'mind_controlled':
                if(!player.mindControlTarget||player.mindControlTarget!==enemy){enemy.state='idle';break;}
                var closestFoe=null,closestDist=8;
                GameState.enemies.forEach(function(other){
                    if(!other.alive||other===enemy||other.state==='mind_controlled')return;
                    var d2=enemy.mesh.position.distanceTo(other.mesh.position);
                    if(d2<closestDist){closestDist=d2;closestFoe=other;}
                });
                if(closestFoe){
                    var mcRange=enemy.combatStyle==='nano'?3:6;
                    if(closestDist>mcRange)enemyMoveToward(enemy,closestFoe.mesh.position,4*dt);
                    enemy.attackTimer-=dt;
                    if(enemy.attackTimer<=0&&closestDist<=mcRange+1){
                        enemy.attackTimer=enemy.attackSpeed;
                        var mcDmg=Math.round(enemy.damage*(0.6+Math.random()*0.4));
                        applyDamageToEnemy(closestFoe,mcDmg);
                        spawnParticles(closestFoe.mesh.position.clone().add(new THREE.Vector3(0,1,0)),0xff44ff,5,2,0.4,0.08);
                        gainXp('psionics',Math.round(mcDmg*0.2));
                    }
                } else {
                    if(enemy.mesh.position.distanceTo(pp)>4)enemyMoveToward(enemy,pp,3*dt);
                }
                if(Math.random()<0.05)spawnParticles(enemy.mesh.position.clone().add(new THREE.Vector3(0,1.5,0)),0xaa22ff,2,1,0.5,0.05);
                break;
        }
        if(enemy.type==='gravlurk')enemy.mesh.children.forEach(c=>{if(c.userData.isDebris){c.userData.orbitAngle+=dt*1.5;const a=c.userData.orbitAngle;c.position.set(Math.cos(a)*3,1.5+Math.sin(a*2)*0.5,Math.sin(a)*3);}});
        if(enemy.type==='neuroworm')enemy.mesh.children.forEach(c=>{if(c.userData.segmentIndex!==undefined){const i=c.userData.segmentIndex;c.position.x=Math.sin(enemy.animPhase+i*0.5)*0.2;c.position.y=0.6+Math.sin(enemy.animPhase*0.5+i*0.3)*0.2;}});
        if(enemy.type==='voidjelly')enemy.mesh.children.forEach(c=>{if(c.geometry&&c.geometry.type==='CylinderGeometry'&&c.position.y<1.8&&c.position.y>-0.5){c.rotation.x=Math.sin(enemy.animPhase+c.position.x*3)*0.15;c.rotation.z=Math.cos(enemy.animPhase*0.7+c.position.z*3)*0.1;}});
    });
}

// ========================================
// NPCs & Shops
// ========================================
const NPC_DEFS = {
    commander_vex:{name:'Commander Vex',position:{x:0,z:-3},bodyColor:0x2a4a6a,headColor:0xc4956a,desc:'Station commander. Gives quests and advice.',dialogue:{greeting:{text:"Welcome to Nova Station, recruit. This sector is crawling with hostile invertebrate species. Gear up and stay sharp.",options:[{label:"I'm ready for a mission.",next:'quest_check'},{label:"What should I do first?",next:'advice'},{label:"Tell me about combat.",next:'combat_info'},{label:"Goodbye.",next:null}]},quest_check:{text:"__QUEST_DYNAMIC__",options:[]},advice:{text:"Start by mining Stellarite in the Asteroid Mines (far east). Smelt it at the Bio-Lab (behind me, southwest corner) to craft equipment. Then head south to the Alien Wastes to train combat.",options:[{label:"Thanks!",next:null}]},combat_info:{text:"Three combat disciplines: Nanotech (close swarm), Tesla (mid electricity), Void (long dark energy). Triangle: Nano beats Tesla, Tesla beats Void, Void beats Nano.",options:[{label:"Got it.",next:null}]},alien_info:{text:"Chithari beetles for beginners. Voidjelly float and shock. Sporeclaws are fast and poisonous. Gravlurk and Neuroworm are dangerous bosses deep in the wastes.",options:[{label:"I'll be careful.",next:null}]}}},
    zik_trader:{name:'Zik the Trader',position:{x:10,z:-10},bodyColor:0x5a4a2a,headColor:0x88aa66,desc:'General goods trader.',shop:{name:"Zik's General Store",specialty:'general',items:[{itemId:'lichen_wrap',price:20,stock:50},{itemId:'nebula_smoothie',price:60,stock:30},{itemId:'alien_burger',price:150,stock:20},{itemId:'scrap_nanoblade',price:80,stock:5},{itemId:'scrap_coilgun',price:80,stock:5},{itemId:'scrap_voidstaff',price:80,stock:5},{itemId:'scrap_helmet',price:50,stock:5},{itemId:'scrap_vest',price:80,stock:5},{itemId:'scrap_legs',price:65,stock:5},{itemId:'scrap_boots',price:35,stock:5},{itemId:'scrap_gloves',price:35,stock:5},{itemId:'ferrite_nanoblade',price:350,stock:3},{itemId:'ferrite_coilgun',price:350,stock:3},{itemId:'ferrite_voidstaff',price:350,stock:3},{itemId:'ferrite_helmet',price:200,stock:3},{itemId:'ferrite_vest',price:300,stock:3},{itemId:'ferrite_legs',price:250,stock:3},{itemId:'scrap_energy_shield',price:65,stock:3},{itemId:'scrap_capacitor',price:65,stock:3},{itemId:'scrap_dark_orb',price:65,stock:3},{itemId:'ferrite_energy_shield',price:250,stock:2},{itemId:'ferrite_capacitor',price:250,stock:2},{itemId:'ferrite_dark_orb',price:250,stock:2}]},dialogue:{greeting:{text:"Welcome, friend! Want to browse my wares?",options:[{label:"Let me see your stock.",action:'openShop'},{label:"No thanks.",next:null}]}}},
    dr_luma:{name:'Dr. Luma',position:{x:-10,z:-10},bodyColor:0x2a5a4a,headColor:0xb4957a,desc:'Bioforge specialist.',shop:{name:"Dr. Luma's Bio Supplies",specialty:'bio',items:[{itemId:'space_lichen',price:8,stock:100},{itemId:'nebula_fruit',price:25,stock:50},{itemId:'alien_steak',price:60,stock:30},{itemId:'chitin_shard',price:15,stock:30},{itemId:'jelly_membrane',price:50,stock:20},{itemId:'spore_gland',price:120,stock:10},{itemId:'bio_scanner',price:40,stock:3},{itemId:'xeno_stove',price:40,stock:3}]},dialogue:{greeting:{text:"I specialize in bioforge materials and xenocooking supplies. Interested?",options:[{label:"Show me what you have.",action:'openShop'},{label:"Tell me about Bioforge.",next:'bioforge_info'},{label:"Tell me about Xenocooking.",next:'cook_info'},{label:"Not right now.",next:null}]},bioforge_info:{text:"Bioforge crafts organic items from creature parts. The Bio-Lab is just southwest of here in the hub.",options:[{label:"Thanks!",next:null}]},cook_info:{text:"Xenocooking transforms alien ingredients into healing food. Use the cooking stations in the Bio-Lab corner of the hub.",options:[{label:"I'll try it.",next:null}]}}},
    ori_miner:{name:'Ori the Miner',position:{x:-10,z:10},bodyColor:0x5a3a1a,headColor:0xd4956a,desc:'Veteran miner.',shop:{name:"Ori's Mining Supplies",specialty:'mining',items:[{itemId:'mining_laser',price:40,stock:5},{itemId:'circuit_welder',price:40,stock:5},{itemId:'ferrite_mining_laser',price:150,stock:2},{itemId:'ferrite_bio_scanner',price:150,stock:2},{itemId:'stellarite_ore',price:20,stock:50},{itemId:'ferrite_ore',price:50,stock:30},{itemId:'cobaltium_ore',price:100,stock:20},{itemId:'stellarite_bar',price:45,stock:20},{itemId:'ferrite_bar',price:100,stock:15}]},dialogue:{greeting:{text:"Another greenhorn? I sell mining tools. Asteroid Mines are far east through the corridor!",options:[{label:"Let me see your tools.",action:'openShop'},{label:"Tell me about mining.",next:'mining_info'},{label:"Maybe later.",next:null}]},mining_info:{text:"Find ore nodes, click them. Higher nodes need higher Astromining. Smelt ore into bars at the Bio-Lab in the hub with Circuitry, then craft gear!",options:[{label:"Got it!",next:null}]}}},
    kael_armorer:{name:'Kael the Armorer',position:{x:10,z:10},bodyColor:0x4a2a5a,headColor:0xc49a6a,desc:'Master armorer specializing in cobalt and duranium gear.',shop:{name:"Kael's Armory",specialty:'equipment',items:[{itemId:'cobalt_nanoblade',price:600,stock:2},{itemId:'cobalt_coilgun',price:600,stock:2},{itemId:'cobalt_voidstaff',price:600,stock:2},{itemId:'cobalt_helmet',price:350,stock:3},{itemId:'cobalt_vest',price:500,stock:2},{itemId:'cobalt_legs',price:450,stock:3},{itemId:'cobalt_boots',price:250,stock:3},{itemId:'cobalt_gloves',price:250,stock:3},{itemId:'duranium_helmet',price:600,stock:2},{itemId:'duranium_vest',price:900,stock:2},{itemId:'cobalt_energy_shield',price:480,stock:2},{itemId:'cobalt_capacitor',price:480,stock:2},{itemId:'cobalt_dark_orb',price:480,stock:2}]},dialogue:{greeting:{text:"Looking for the best gear credits can buy? I forge cobalt and duranium-grade equipment. Expensive, but worth every credit.",options:[{label:"Show me your armory.",action:'openShop'},{label:"How do you make composite gear?",next:'craft_info'},{label:"Not right now.",next:null}]},craft_info:{text:"Cobalt gear requires Cobaltium Bars. Mine Cobaltium Ore in the deep mines, smelt it with level 20 Circuitry, then forge equipment. Or just buy from me if you have the credits.",options:[{label:"Interesting!",next:null}]}}},
    slayer_grax:{name:'Slayer Master Grax',position:{x:15,z:-3},bodyColor:0x5a2a2a,headColor:0xb08060,desc:'Assigns dangerous hunting tasks with escalating rewards.',dialogue:{greeting:{text:"__SLAYER_DYNAMIC__",options:[]}}},
    dr_elara_voss:{name:'Dr. Elara Voss',position:{x:-15,z:-3},bodyColor:0x4a2a6a,headColor:0xc49a7a,desc:'Psionic researcher studying latent psychic energy from deep-space organisms.',dialogue:{greeting:{text:"__PSIONICS_DYNAMIC__",options:[]},about_psionics:{text:"Psionics is the science of mental projection. The organisms in the Alien Wastes emit latent psionic fields. With the right catalyst, humans can tap into this power.",options:[{label:"Fascinating.",next:null}]}}},
    the_archivist:{name:'The Archivist',position:{x:0,z:-12},bodyColor:0x2a1a3a,headColor:0xc4a87a,desc:'An ancient figure who can reset your skills for permanent power.',dialogue:{greeting:{text:"__PRESTIGE_DYNAMIC__",options:[]}}},
};

let activeNPC=null,currentDialogue=null,activeShop=null;

function buildNPCMesh(def,key){
    const g=new THREE.Group();
    // Base humanoid (upgraded geometry)
    const body=new THREE.Mesh(new THREE.BoxGeometry(0.8,1.1,0.5),new THREE.MeshLambertMaterial({color:def.bodyColor}));body.position.y=1.8;body.castShadow=true;g.add(body);
    const head=new THREE.Mesh(new THREE.SphereGeometry(0.35,12,10),new THREE.MeshLambertMaterial({color:def.headColor}));head.position.y=2.75;g.add(head);
    const am=new THREE.MeshLambertMaterial({color:def.bodyColor});
    const la2=new THREE.Mesh(new THREE.CapsuleGeometry(0.11,0.55,4,8),am);la2.position.set(-0.55,1.7,0);g.add(la2);
    const ra2=new THREE.Mesh(new THREE.CapsuleGeometry(0.11,0.55,4,8),am.clone());ra2.position.set(0.55,1.7,0);g.add(ra2);
    const lm=new THREE.MeshLambertMaterial({color:0x2a2a2a});
    const ll2=new THREE.Mesh(new THREE.CapsuleGeometry(0.13,0.6,4,8),lm);ll2.position.set(-0.2,0.7,0);g.add(ll2);
    const rl2=new THREE.Mesh(new THREE.CapsuleGeometry(0.13,0.6,4,8),lm.clone());rl2.position.set(0.2,0.7,0);g.add(rl2);
    // Boots
    var bm=new THREE.MeshLambertMaterial({color:0x1a1a1a});
    var lBoot2=new THREE.Mesh(new THREE.BoxGeometry(0.2,0.25,0.3),bm);lBoot2.position.set(-0.2,0.2,0.02);g.add(lBoot2);
    var rBoot2=new THREE.Mesh(new THREE.BoxGeometry(0.2,0.25,0.3),bm.clone());rBoot2.position.set(0.2,0.2,0.02);g.add(rBoot2);
    // Indicator diamond (MUST preserve userData.isIndicator)
    const ind=new THREE.Mesh(new THREE.OctahedronGeometry(0.15,0),new THREE.MeshBasicMaterial({color:0xffcc00}));
    ind.position.y=3.3;ind.userData.isIndicator=true;g.add(ind);
    // Per-NPC unique details
    if(key==='commander_vex'){
        // Gold epaulettes + rank badge
        var eMat=new THREE.MeshLambertMaterial({color:0xccaa44});
        var lEp=new THREE.Mesh(new THREE.BoxGeometry(0.35,0.06,0.3),eMat);lEp.position.set(-0.48,2.38,0);g.add(lEp);
        var rEp=new THREE.Mesh(new THREE.BoxGeometry(0.35,0.06,0.3),eMat);rEp.position.set(0.48,2.38,0);g.add(rEp);
        var badge=new THREE.Mesh(new THREE.BoxGeometry(0.1,0.1,0.05),new THREE.MeshBasicMaterial({color:0xccaa44}));badge.position.set(0.2,2.0,0.28);g.add(badge);
        body.scale.y=1.05;
    }else if(key==='zik_trader'){
        // Stocky build + apron + satchel
        body.scale.x=1.15;
        var apron=new THREE.Mesh(new THREE.BoxGeometry(0.6,0.7,0.05),new THREE.MeshLambertMaterial({color:0x8a7a5a}));apron.position.set(0,1.4,0.28);g.add(apron);
        var satchel=new THREE.Mesh(new THREE.BoxGeometry(0.25,0.2,0.15),new THREE.MeshLambertMaterial({color:0x6a5a3a}));satchel.position.set(0.5,1.5,0.1);g.add(satchel);
    }else if(key==='dr_luma'){
        // Tall/slim + lab coat tail + goggles
        body.scale.y=1.12;body.scale.x=0.9;
        var coat=new THREE.Mesh(new THREE.BoxGeometry(0.7,0.5,0.05),new THREE.MeshLambertMaterial({color:0xcccccc}));coat.position.set(0,1.2,-0.28);g.add(coat);
        var goggles=new THREE.Mesh(new THREE.TorusGeometry(0.12,0.03,4,8),new THREE.MeshBasicMaterial({color:0x44aacc}));goggles.position.set(0,2.95,0.25);goggles.rotation.y=Math.PI/2;g.add(goggles);
    }else if(key==='ori_miner'){
        // Hardhat + tool belt trinkets + broader arms
        var hardhat=new THREE.Mesh(new THREE.CylinderGeometry(0.38,0.35,0.15,8),new THREE.MeshLambertMaterial({color:0xccaa22}));hardhat.position.set(0,3.05,0);g.add(hardhat);
        la2.scale.x=1.3;ra2.scale.x=1.3;
        for(var ti=0;ti<3;ti++){var trinket=new THREE.Mesh(new THREE.BoxGeometry(0.08,0.12,0.08),new THREE.MeshLambertMaterial({color:0x666666}));trinket.position.set(-0.3+ti*0.3,1.18,0.28);g.add(trinket);}
    }else if(key==='kael_armorer'){
        // Heavy shoulder guards + hammer on back
        var sg=new THREE.MeshLambertMaterial({color:0x6a5a7a});
        var lSg=new THREE.Mesh(new THREE.BoxGeometry(0.4,0.12,0.35),sg);lSg.position.set(-0.5,2.35,0);g.add(lSg);
        var rSg=new THREE.Mesh(new THREE.BoxGeometry(0.4,0.12,0.35),sg);rSg.position.set(0.5,2.35,0);g.add(rSg);
        var hammerHead=new THREE.Mesh(new THREE.BoxGeometry(0.15,0.15,0.15),new THREE.MeshLambertMaterial({color:0x888888}));hammerHead.position.set(-0.3,2.2,-0.35);g.add(hammerHead);
        var hammerShaft=new THREE.Mesh(new THREE.CylinderGeometry(0.03,0.03,0.5,4),new THREE.MeshLambertMaterial({color:0x5a4a3a}));hammerShaft.position.set(-0.3,1.85,-0.35);g.add(hammerShaft);
    }else if(key==='slayer_grax'){
        // Scar + trophy necklace + bulky arms
        var scar=new THREE.Mesh(new THREE.BoxGeometry(0.25,0.03,0.05),new THREE.MeshBasicMaterial({color:0xaa4444}));scar.position.set(0.05,2.8,0.32);g.add(scar);
        for(var ni=0;ni<5;ni++){var trophy=new THREE.Mesh(new THREE.SphereGeometry(0.04,4,4),new THREE.MeshLambertMaterial({color:0xddcc88}));var na=(ni/5)*Math.PI-Math.PI/2;trophy.position.set(Math.sin(na)*0.35,2.45,Math.cos(na)*0.25);g.add(trophy);}
        la2.scale.set(1.2,1,1.2);ra2.scale.set(1.2,1,1.2);
    }else if(key==='dr_elara_voss'){
        // Psionic crown (ring) + subtle glow aura
        body.scale.y=1.1;body.scale.x=0.9;
        var crown=new THREE.Mesh(new THREE.RingGeometry(0.3,0.35,6),new THREE.MeshBasicMaterial({color:0x9944ff,transparent:true,opacity:0.6,side:THREE.DoubleSide}));crown.position.set(0,3.15,0);crown.rotation.x=Math.PI/2;crown.name='psionic_crown';g.add(crown);
        var aura=new THREE.Mesh(new THREE.SphereGeometry(0.5,8,8),new THREE.MeshBasicMaterial({color:0x7733cc,transparent:true,opacity:0.08}));aura.position.y=1.8;g.add(aura);
    }else if(key==='the_archivist'){
        // Hood + robe + glowing eyes
        var hood=new THREE.Mesh(new THREE.ConeGeometry(0.4,0.5,6),new THREE.MeshLambertMaterial({color:0x2a1a3a}));hood.position.set(0,3.0,0);g.add(hood);
        var robe=new THREE.Mesh(new THREE.CylinderGeometry(0.5,0.6,1.5,6),new THREE.MeshLambertMaterial({color:0x2a1a3a}));robe.position.set(0,0.9,0);g.add(robe);
        var eyeMat=new THREE.MeshBasicMaterial({color:0xffcc44});
        var lEye=new THREE.Mesh(new THREE.SphereGeometry(0.04,4,4),eyeMat);lEye.position.set(-0.12,2.8,0.28);g.add(lEye);
        var rEye=new THREE.Mesh(new THREE.SphereGeometry(0.04,4,4),eyeMat);rEye.position.set(0.12,2.8,0.28);g.add(rEye);
    }
    return g;
}

function openDialogue(npc){activeNPC=npc;currentDialogue='greeting';showDialoguePanel(npc);}
function showDialoguePanel(npc){
    const d=npc.def.dialogue[currentDialogue];if(!d){closeDialogue();return;}
    const panel=document.getElementById('dialogue-panel'),speaker=document.getElementById('dialogue-speaker'),text=document.getElementById('dialogue-text'),opts=document.getElementById('dialogue-options');
    speaker.textContent=npc.def.name;opts.innerHTML='';

    // Dynamic quest dialogue for Commander Vex
    if(d.text==='__QUEST_DYNAMIC__'){
        const qs=getVexStatus();
        if(qs){
            // Active quest - show progress
            text.textContent=qs.quest.name+': '+qs.steps.join(' | ');
            const btn=document.createElement('button');btn.className='dialogue-option';btn.textContent='I\'ll keep at it.';btn.addEventListener('click',()=>{closeDialogue();});opts.appendChild(btn);
        } else if(!questState.vexQuest&&!questState.completed.includes('first_blood')){
            // Offer first quest
            text.textContent="I need someone to thin out the Chithari in the Alien Wastes. They're getting too aggressive. Head south and defeat 5 of them. I'll make it worth your while.";
            const accept=document.createElement('button');accept.className='dialogue-option';accept.textContent='I\'ll handle it.';accept.addEventListener('click',()=>{startVexQuest('first_blood');closeDialogue();});opts.appendChild(accept);
            const decline=document.createElement('button');decline.className='dialogue-option';decline.textContent='Not right now.';decline.addEventListener('click',()=>{closeDialogue();});opts.appendChild(decline);
        } else if(questState.completed.includes('first_blood')&&!questState.vexQuest&&!questState.completed.includes('gear_up')){
            text.textContent="Good work with the Chithari! Now you need better gear. Mine 5 Stellarite Ore from the Asteroid Mines and smelt 3 bars at the Bio-Lab.";
            const accept=document.createElement('button');accept.className='dialogue-option';accept.textContent='On it, Commander.';accept.addEventListener('click',()=>{startVexQuest('gear_up');closeDialogue();});opts.appendChild(accept);
            const decline=document.createElement('button');decline.className='dialogue-option';decline.textContent='Maybe later.';decline.addEventListener('click',()=>{closeDialogue();});opts.appendChild(decline);
        } else if(questState.completed.includes('gear_up')&&!questState.vexQuest&&!questState.completed.includes('deep_cuts')){
            text.textContent="You're gearing up nicely. Now I need you to take on the Chithari Warriors deeper in the wastes. Kill 3 of them and bring back 5 Chitin Shards for our research division.";
            const accept=document.createElement('button');accept.className='dialogue-option';accept.textContent='Consider it done.';accept.addEventListener('click',()=>{startVexQuest('deep_cuts');closeDialogue();});opts.appendChild(accept);
            const decline=document.createElement('button');decline.className='dialogue-option';decline.textContent='Not yet.';decline.addEventListener('click',()=>{closeDialogue();});opts.appendChild(decline);
        } else if(questState.completed.includes('deep_cuts')&&!questState.vexQuest&&!questState.completed.includes('lab_rat')){
            text.textContent="Dr. Luma needs someone with practical skills. Cook 5 Lichen Wraps and craft 2 Scrap Vests to prove you can handle production work. Use the Bio-Lab stations.";
            const accept=document.createElement('button');accept.className='dialogue-option';accept.textContent='I\'ll get crafting.';accept.addEventListener('click',()=>{startVexQuest('lab_rat');closeDialogue();});opts.appendChild(accept);
            const decline=document.createElement('button');decline.className='dialogue-option';decline.textContent='Maybe later.';decline.addEventListener('click',()=>{closeDialogue();});opts.appendChild(decline);
        } else if(questState.completed.includes('lab_rat')&&!questState.vexQuest&&!questState.completed.includes('into_the_wastes')){
            text.textContent="The Alien Wastes are getting worse. Voidjelly swarms are expanding and a Sporeclaw has been sighted. I need you to eliminate 5 Voidjelly and take down that Sporeclaw.";
            const accept=document.createElement('button');accept.className='dialogue-option';accept.textContent='I\'ll clear them out.';accept.addEventListener('click',()=>{startVexQuest('into_the_wastes');closeDialogue();});opts.appendChild(accept);
            const decline=document.createElement('button');decline.className='dialogue-option';decline.textContent='I need to prepare first.';decline.addEventListener('click',()=>{closeDialogue();});opts.appendChild(decline);
        } else {
            text.textContent="You've proven yourself capable, recruit. Keep training and push deeper into the Alien Wastes. The real threats are still out there.";
            const btn=document.createElement('button');btn.className='dialogue-option';btn.textContent='Will do, Commander.';btn.addEventListener('click',()=>{closeDialogue();});opts.appendChild(btn);
        }
        panel.style.display='block';return;
    }

    // Dynamic slayer dialogue for Slayer Master Grax
    if(d.text==='__SLAYER_DYNAMIC__'){
        if(questState.slayerTask&&questState.slayerProgress>=questState.slayerTask.count){
            const enemyDef=ENEMY_TYPES[questState.slayerTask.target];
            const enemyName=enemyDef?enemyDef.name:questState.slayerTask.target;
            text.textContent="Excellent work! You've eliminated all "+questState.slayerTask.count+" "+enemyName+". Ready for another assignment?";
            const claim=document.createElement('button');claim.className='dialogue-option';claim.textContent='Claim reward & get new task';claim.addEventListener('click',()=>{completeSlayerTask();assignSlayerTask();closeDialogue();});opts.appendChild(claim);
            const claimOnly=document.createElement('button');claimOnly.className='dialogue-option';claimOnly.textContent='Claim reward only';claimOnly.addEventListener('click',()=>{completeSlayerTask();closeDialogue();});opts.appendChild(claimOnly);
        } else if(questState.slayerTask){
            const enemyDef=ENEMY_TYPES[questState.slayerTask.target];
            const enemyName=enemyDef?enemyDef.name:questState.slayerTask.target;
            text.textContent="Your task: Kill "+questState.slayerTask.count+" "+enemyName+". Progress: "+questState.slayerProgress+"/"+questState.slayerTask.count+". Keep hunting.";
            if(questState.slayerStreak>0)text.textContent+=" (Streak: "+questState.slayerStreak+")";
            const cancel=document.createElement('button');cancel.className='dialogue-option';cancel.textContent='Cancel task (resets streak)';cancel.addEventListener('click',()=>{cancelSlayerTask();closeDialogue();});opts.appendChild(cancel);
            const bye=document.createElement('button');bye.className='dialogue-option';bye.textContent="I'll keep at it.";bye.addEventListener('click',()=>{closeDialogue();});opts.appendChild(bye);
        } else {
            text.textContent="I'm Grax, the Slayer Master. I assign targets for hunters who want a challenge. Each kill earns credits and combat XP, with streak bonuses for consecutive completions."+(questState.slayerStreak>0?" Your current streak: "+questState.slayerStreak+".":"")+" Ready for an assignment?";
            const accept=document.createElement('button');accept.className='dialogue-option';accept.textContent='Assign me a target.';accept.addEventListener('click',()=>{assignSlayerTask();closeDialogue();});opts.appendChild(accept);
            const decline=document.createElement('button');decline.className='dialogue-option';decline.textContent='Not right now.';decline.addEventListener('click',()=>{closeDialogue();});opts.appendChild(decline);
        }
        panel.style.display='block';return;
    }

    // Dynamic psionics dialogue for Dr. Elara Voss
    if(d.text==='__PSIONICS_DYNAMIC__'){
        if(player.psionicsUnlocked){
            text.textContent="Your psionic powers grow stronger each day. Keep training your mind.";
            var pbtn=document.createElement('button');pbtn.className='dialogue-option';pbtn.textContent='I feel the power.';pbtn.addEventListener('click',function(){closeDialogue();});opts.appendChild(pbtn);
        } else if(questState.vexQuest&&questState.vexQuest.startsWith('psi_')){
            var pqs=getVexStatus();
            if(pqs){text.textContent=pqs.quest.name+': '+pqs.steps.join(' | ');var pbtn2=document.createElement('button');pbtn2.className='dialogue-option';pbtn2.textContent="I'll continue.";pbtn2.addEventListener('click',function(){closeDialogue();});opts.appendChild(pbtn2);}
        } else if(!questState.completed.includes('psi_discovery')&&questState.completed.includes('into_the_wastes')&&!questState.vexQuest){
            text.textContent="I've detected psionic energy signatures from the wastes. I need 3 Neural Tissue samples to study this phenomenon. Will you help?";
            var pa=document.createElement('button');pa.className='dialogue-option';pa.textContent="I'll get those samples.";pa.addEventListener('click',function(){startVexQuest('psi_discovery');closeDialogue();});opts.appendChild(pa);
            var pd=document.createElement('button');pd.className='dialogue-option';pd.textContent='Not right now.';pd.addEventListener('click',function(){closeDialogue();});opts.appendChild(pd);
        } else if(questState.completed.includes('psi_discovery')&&!questState.completed.includes('psi_crystal')&&!questState.vexQuest){
            text.textContent="Excellent samples! Now I need a Voidstone focusing crystal. Mine 5 Voidstone Ore and smelt 3 bars.";
            var pa2=document.createElement('button');pa2.className='dialogue-option';pa2.textContent='On it, Doctor.';pa2.addEventListener('click',function(){startVexQuest('psi_crystal');closeDialogue();});opts.appendChild(pa2);
            var pd2=document.createElement('button');pd2.className='dialogue-option';pd2.textContent='Maybe later.';pd2.addEventListener('click',function(){closeDialogue();});opts.appendChild(pd2);
        } else if(questState.completed.includes('psi_crystal')&&!questState.completed.includes('psi_entity')&&!questState.vexQuest){
            text.textContent="The crystal resonates violently. Something lurks in the deep wastes. Clear the area: defeat 2 Neuroworms and the Gravlurk.";
            var pa3=document.createElement('button');pa3.className='dialogue-option';pa3.textContent="I'll clear the path.";pa3.addEventListener('click',function(){startVexQuest('psi_entity');closeDialogue();});opts.appendChild(pa3);
            var pd3=document.createElement('button');pd3.className='dialogue-option';pd3.textContent='I need to prepare.';pd3.addEventListener('click',function(){closeDialogue();});opts.appendChild(pd3);
        } else if(questState.completed.includes('psi_entity')&&!questState.completed.includes('psi_awakening')&&!questState.vexQuest){
            text.textContent="One final component: 5 Gravity Residue to stabilize the attunement field. This will awaken your psionic potential.";
            var pa4=document.createElement('button');pa4.className='dialogue-option';pa4.textContent='For the awakening.';pa4.addEventListener('click',function(){startVexQuest('psi_awakening');closeDialogue();});opts.appendChild(pa4);
            var pd4=document.createElement('button');pd4.className='dialogue-option';pd4.textContent='Not yet.';pd4.addEventListener('click',function(){closeDialogue();});opts.appendChild(pd4);
        } else {
            text.textContent="I'm Dr. Elara Voss, psionic researcher. I study the mental energy from deep-space organisms. Prove yourself in the wastes and I may have a proposition.";
            var pb=document.createElement('button');pb.className='dialogue-option';pb.textContent='Tell me more.';pb.addEventListener('click',function(){currentDialogue='about_psionics';showDialoguePanel(npc);});opts.appendChild(pb);
            var pbye=document.createElement('button');pbye.className='dialogue-option';pbye.textContent='Goodbye.';pbye.addEventListener('click',function(){closeDialogue();});opts.appendChild(pbye);
        }
        panel.style.display='block';return;
    }
    if(d.text==='__PRESTIGE_DYNAMIC__'){
        var pTier=player.prestige.tier;
        var totalLvl=getTotalLevel();
        var hasMax99=false;
        for(var sk in player.skills){if(SKILL_DEFS[sk]&&SKILL_DEFS[sk].type!=='prestige'&&player.skills[sk].level>=99){hasMax99=true;break;}}
        var canPrestige=(hasMax99||totalLvl>=PRESTIGE_CONFIG.minTotalLevel)&&pTier<PRESTIGE_CONFIG.maxTier;
        if(pTier>=PRESTIGE_CONFIG.maxTier){
            text.textContent="You have reached the pinnacle of ascension, Tier "+pTier+". Your legend is complete. You have "+player.prestige.points+" Prestige Points to spend.";
            var sb1=document.createElement('button');sb1.className='dialogue-option';sb1.textContent='Open Prestige Shop';sb1.addEventListener('click',function(){closeDialogue();openPrestigeShop();});opts.appendChild(sb1);
            var sb2=document.createElement('button');sb2.className='dialogue-option';sb2.textContent='View Prestige Stats';sb2.addEventListener('click',function(){closeDialogue();openPrestigePanel();});opts.appendChild(sb2);
            var sb3=document.createElement('button');sb3.className='dialogue-option';sb3.textContent='Farewell.';sb3.addEventListener('click',function(){closeDialogue();});opts.appendChild(sb3);
        } else if(canPrestige){
            var pts=totalLvl*PRESTIGE_CONFIG.pointsPerTotalLevel;
            var nextTier=pTier+1;
            text.textContent="You are worthy of Prestige Tier "+nextTier+", traveler. Your total level is "+totalLvl+". You would earn "+pts+" Prestige Points. Your 7 base skills will reset to 1. Your bank, psionics, chronomancy, and bestiary are preserved. Proceed?";
            var pb=document.createElement('button');pb.className='dialogue-option';pb.textContent='Prestige to Tier '+nextTier+' (+'+pts+' points)';pb.addEventListener('click',function(){closeDialogue();confirmPrestige();});opts.appendChild(pb);
            if(pTier>0){var sb4=document.createElement('button');sb4.className='dialogue-option';sb4.textContent='Open Prestige Shop ('+player.prestige.points+' pts)';sb4.addEventListener('click',function(){closeDialogue();openPrestigeShop();});opts.appendChild(sb4);}
            if(pTier>0){var sb5=document.createElement('button');sb5.className='dialogue-option';sb5.textContent='View Prestige Stats';sb5.addEventListener('click',function(){closeDialogue();openPrestigePanel();});opts.appendChild(sb5);}
            var sb6=document.createElement('button');sb6.className='dialogue-option';sb6.textContent='Not yet.';sb6.addEventListener('click',function(){closeDialogue();});opts.appendChild(sb6);
        } else {
            text.textContent="I am The Archivist. When you have proven your mastery — reach level 99 in any base skill, or a total level of "+PRESTIGE_CONFIG.minTotalLevel+" — return to me. I can reset your knowledge in exchange for permanent power. Your current total level: "+totalLvl+".";
            if(pTier>0){var sb7=document.createElement('button');sb7.className='dialogue-option';sb7.textContent='Open Prestige Shop ('+player.prestige.points+' pts)';sb7.addEventListener('click',function(){closeDialogue();openPrestigeShop();});opts.appendChild(sb7);}
            if(pTier>0){var sb8=document.createElement('button');sb8.className='dialogue-option';sb8.textContent='View Prestige Stats';sb8.addEventListener('click',function(){closeDialogue();openPrestigePanel();});opts.appendChild(sb8);}
            var sb9=document.createElement('button');sb9.className='dialogue-option';sb9.textContent='I will return.';sb9.addEventListener('click',function(){closeDialogue();});opts.appendChild(sb9);
        }
        panel.style.display='block';return;
    }

    text.textContent=d.text;
    d.options.forEach(opt=>{const btn=document.createElement('button');btn.className='dialogue-option';btn.textContent=opt.label;btn.addEventListener('click',()=>{if(opt.action==='openShop'){closeDialogue();openShop(npc);}else if(opt.next){currentDialogue=opt.next;showDialoguePanel(npc);}else{closeDialogue();}});opts.appendChild(btn);});
    panel.style.display='block';
}
function closeDialogue(){document.getElementById('dialogue-panel').style.display='none';activeNPC=null;currentDialogue=null;}

function openShop(npc){if(!npc.def.shop)return;activeShop=npc;document.getElementById('shop-name').textContent=npc.def.shop.name;document.getElementById('shop-panel').style.display='flex';renderShop();}

function renderShop(){
    if(!activeShop)return;
    var npcId=activeShop.id;
    const si=document.getElementById('shop-items'),spi=document.getElementById('shop-player-inv');
    si.innerHTML='<div style="grid-column:1/-1;font-size:11px;color:#00c8ff;padding:4px;">Shop Stock</div>';
    activeShop.def.shop.items.forEach(item=>{
        const def=getItem(item.itemId);if(!def)return;
        var price=getShopPrice(npcId,item.itemId);
        var econ=shopEconomy[npcId]&&shopEconomy[npcId][item.itemId];
        var stock=econ?econ.stock:item.stock;
        var mult=econ?econ.currentMultiplier:1;
        var soldOut=stock<=0;
        const s=document.createElement('div');s.className='inv-slot has-item';
        if(soldOut){s.style.position='relative';}
        // Price indicator arrow
        var priceColor='#ffcc44';var arrow='';
        if(mult<0.95){priceColor='#44ff88';arrow='\u25BC ';}
        else if(mult>1.05){priceColor='#ff4444';arrow='\u25B2 ';}
        s.innerHTML='<span class="item-icon">'+def.icon+'</span><span class="item-count" style="color:'+priceColor+'">'+arrow+price+'cr</span>'+(soldOut?'<div class="shop-sold-overlay">SOLD</div>':'');
        // Stock count
        if(!soldOut){
            var stockEl=document.createElement('span');stockEl.style.cssText='position:absolute;top:1px;left:2px;font-size:8px;color:#8aa0b8;';stockEl.textContent='x'+stock;s.appendChild(stockEl);
        }
        s.addEventListener('mouseenter',e=>{showTooltip(e.clientX,e.clientY,def,'<div style="color:'+priceColor+';font-size:10px;margin-top:3px;">Click to buy ('+price+' Cr) | Stock: '+stock+'</div>');});
        s.addEventListener('mousemove',e=>{if(tooltip.style.display!=='none'){tooltip.style.left=Math.min(e.clientX+12,window.innerWidth-260)+'px';tooltip.style.top=Math.min(e.clientY+12,window.innerHeight-tooltip.offsetHeight-10)+'px';}});
        s.addEventListener('mouseleave',()=>{hideTooltip();});
        if(!soldOut){s.addEventListener('click',()=>{hideTooltip();buyItem(item);});}
        si.appendChild(s);
    });
    spi.innerHTML='<div style="grid-column:1/-1;font-size:11px;color:#ffcc44;padding:4px;">Your Items (click to sell)</div>';
    player.inventory.forEach((inv,idx)=>{const s=document.createElement('div');s.className='inv-slot'+(inv?' has-item':'');if(inv){const def=getItem(inv.itemId);const sp=getShopSellPrice(npcId,def);s.innerHTML='<span class="item-icon">'+def.icon+'</span>'+(inv.quantity>1?'<span class="item-count">'+inv.quantity+'</span>':'');s.title=def.name+' - Sell for '+sp+' Credits';s.addEventListener('click',()=>sellItem(idx));}spi.appendChild(s);});
    let cd=document.getElementById('shop-credits');if(!cd){cd=document.createElement('div');cd.id='shop-credits';cd.style.cssText='grid-column:1/-1;text-align:center;padding:6px;font-size:12px;color:#ffcc44;font-weight:700;';spi.parentNode.insertBefore(cd,spi);}cd.textContent='Credits: '+player.credits;
}

function buyItem(shopItem){
    var def=getItem(shopItem.itemId);
    var npcId=activeShop?activeShop.id:'';
    var price=getShopPrice(npcId,shopItem.itemId);
    // Check stock
    var econ=shopEconomy[npcId]&&shopEconomy[npcId][shopItem.itemId];
    if(econ&&econ.stock<=0){EventBus.emit('chat',{type:'info',text:'Out of stock!'});return;}
    if(player.credits<price){EventBus.emit('chat',{type:'info',text:'Not enough Credits!'});return;}
    if(!addItem(shopItem.itemId,1))return;
    // Init durability on gear purchases
    if(def.type===ItemType.WEAPON||def.type===ItemType.ARMOR){
        // Find the slot we just added the item to and set durability
        for(var bi=0;bi<player.inventory.length;bi++){
            if(player.inventory[bi]&&player.inventory[bi].itemId===shopItem.itemId&&player.inventory[bi].durability===undefined){
                if(def.type===ItemType.WEAPON||def.type===ItemType.ARMOR){
                    var dur=initDurability(def);
                    player.inventory[bi].durability=dur.durability;
                    player.inventory[bi].maxDurability=dur.maxDurability;
                }
                break;
            }
        }
    }
    removeCredits(price);
    if(econ){econ.stock--;econ.currentMultiplier+=SHOP_ECONOMY_CONFIG.buyPriceIncrease;}
    playSound('buy');
    EventBus.emit('chat',{type:'info',text:'Bought '+def.name+' for '+price+' Credits.'});
    renderShop();
}

function sellItem(slotIndex){
    var inv=player.inventory[slotIndex];if(!inv)return;
    var def=getItem(inv.itemId);
    // Sell confirmation for tier 3+ gear (Feature 11)
    if(def.tier&&def.tier>=3&&(def.type===ItemType.WEAPON||def.type===ItemType.ARMOR||def.slot)){
        if(!confirm('Sell '+def.name+' (Tier '+def.tier+')? This is valuable gear!'))return;
    }
    var npcId=activeShop?activeShop.id:'';
    var sp=getShopSellPrice(npcId,def);
    inv.quantity-=1;if(inv.quantity<=0)player.inventory[slotIndex]=null;
    addCredits(sp);
    // Increase shop stock, decrease price
    var econ=shopEconomy[npcId]&&shopEconomy[npcId][inv.itemId];
    if(econ){
        econ.stock=Math.min(econ.maxStock+5,econ.stock+1);
        econ.currentMultiplier=Math.max(SHOP_ECONOMY_CONFIG.priceFloor,econ.currentMultiplier-SHOP_ECONOMY_CONFIG.sellPriceDecrease);
    }
    EventBus.emit('inventoryChanged');EventBus.emit('chat',{type:'info',text:'Sold '+def.name+' for '+sp+' Credits.'});renderShop();
}

function closeShop(){document.getElementById('shop-panel').style.display='none';activeShop=null;}

// ----------------------------------------
// Shop Economy Initialization
// ----------------------------------------
function initShopEconomy() {
    shopEconomy = {};
    Object.entries(NPC_DEFS).forEach(function(entry) {
        var npcId = entry[0], def = entry[1];
        if (!def.shop) return;
        shopEconomy[npcId] = {};
        def.shop.items.forEach(function(item) {
            shopEconomy[npcId][item.itemId] = {
                basePrice: item.price,
                currentMultiplier: 1.0,
                stock: item.stock,
                maxStock: item.stock,
                lastRestockTime: 0,
            };
        });
    });
}

function updateShopEconomy(dt) {
    Object.keys(shopEconomy).forEach(function(npcId) {
        var npcEcon = shopEconomy[npcId];
        Object.keys(npcEcon).forEach(function(itemId) {
            var e = npcEcon[itemId];
            // Restock timer
            e.lastRestockTime = (e.lastRestockTime || 0) + dt;
            if (e.lastRestockTime >= SHOP_ECONOMY_CONFIG.restockInterval) {
                e.lastRestockTime = 0;
                if (e.stock < e.maxStock) e.stock = Math.min(e.maxStock, e.stock + 1);
            }
            // Mean reversion toward 1.0
            if (e.currentMultiplier > 1.0) {
                e.currentMultiplier = Math.max(1.0, e.currentMultiplier - SHOP_ECONOMY_CONFIG.meanReversionRate * dt);
            } else if (e.currentMultiplier < 1.0) {
                e.currentMultiplier = Math.min(1.0, e.currentMultiplier + SHOP_ECONOMY_CONFIG.meanReversionRate * dt);
            }
        });
    });
}

function getShopPrice(npcId, itemId) {
    if (!shopEconomy[npcId] || !shopEconomy[npcId][itemId]) {
        var def = getItem(itemId);
        return def ? def.value : 0;
    }
    var e = shopEconomy[npcId][itemId];
    var mult = Math.max(SHOP_ECONOMY_CONFIG.priceFloor, Math.min(SHOP_ECONOMY_CONFIG.priceCeiling, e.currentMultiplier));
    return Math.max(1, Math.round(e.basePrice * mult));
}

function getShopSellPrice(npcId, itemDef) {
    if (!itemDef) return 0;
    var baseSellPct = 0.6;
    var npcDef = NPC_DEFS[npcId];
    if (npcDef && npcDef.shop && npcDef.shop.specialty !== 'general') {
        var spec = npcDef.shop.specialty;
        if (spec === 'bio' && (itemDef.type === ItemType.FOOD || itemDef.type === ItemType.RESOURCE)) baseSellPct = 0.75;
        else if (spec === 'mining' && (itemDef.type === ItemType.RESOURCE || itemDef.type === ItemType.MATERIAL)) baseSellPct = 0.75;
        else if (spec === 'equipment' && (itemDef.type === ItemType.WEAPON || itemDef.type === ItemType.ARMOR)) baseSellPct = 0.75;
    }
    return Math.max(1, Math.floor(itemDef.value * baseSellPct));
}

function spawnNPCs(){
    Object.entries(NPC_DEFS).forEach(([id,def])=>{
        const mesh=buildNPCMesh(def,id);mesh.position.set(def.position.x,0,def.position.z);
        const npc={id,def,mesh,position:new THREE.Vector3(def.position.x,0,def.position.z)};
        mesh.userData.entityType='npc';mesh.userData.entity=npc;
        GameState.scene.add(mesh);GameState.npcs.push(npc);
    });
}

function updateNPCs(){
    const t=GameState.elapsedTime;
    GameState.npcs.forEach(npc=>{
        // Indicator bob
        npc.mesh.children.forEach(c=>{if(c.userData.isIndicator){c.position.y=3.3+Math.sin(t*2)*0.15;c.rotation.y+=GameState.deltaTime*2;}});
        // Subtle body sway
        npc.mesh.position.x=npc.position.x+Math.sin(t*0.8+npc.id.length)*0.02;
        // Elara crown spin
        if(npc.id==='dr_elara_voss'){var crown=npc.mesh.getObjectByName('psionic_crown');if(crown)crown.rotation.z+=GameState.deltaTime*1.5;}
    });
    if(player.pendingNPC&&!player.isMoving){const npc=player.pendingNPC;player.pendingNPC=null;if(player.mesh.position.distanceTo(npc.position)<=5)openDialogue(npc);}
    if(player.pendingStation&&!player.isMoving){
        const station=player.pendingStation;player.pendingStation=null;
        const stPos=new THREE.Vector3(station.position.x,0,station.position.z);
        if(player.mesh.position.distanceTo(stPos)<=station.interactRadius){if(station.skill==='repair')openRepairStation();else openCrafting(station.skill);}
    }
    if(player.pendingBoard&&!player.isMoving){player.pendingBoard=false;const boardPos=new THREE.Vector3(0,0,18);if(player.mesh.position.distanceTo(boardPos)<=6)openBoardPanel();}
    if(player.pendingDelivery&&!player.isMoving){player.pendingDelivery=false;const boardPos=new THREE.Vector3(0,0,18);if(player.mesh.position.distanceTo(boardPos)<=6)deliverBoardItems();}
    if(player.pendingDungeon&&!player.isMoving){player.pendingDungeon=false;enterDungeon();}
    if(player.pendingTimeLoop&&!player.isMoving){player.pendingTimeLoop=false;enterTimeLoopDungeon();}
}

// ========================================
// UI / HUD
// ========================================
var activeChatFilter='all';
function addChatMessage(type,text){
    const cm=document.getElementById('chat-messages'),msg=document.createElement('div');
    msg.className='chat-msg '+type;msg.dataset.chatType=type;msg.textContent=text;
    if(activeChatFilter!=='all'&&type!==activeChatFilter)msg.style.display='none';
    cm.appendChild(msg);cm.scrollTop=cm.scrollHeight;
    while(cm.children.length>100)cm.removeChild(cm.firstChild);
}

function createFloatText(worldPos,text,type){
    const pos=worldPos.clone();pos.project(GameState.camera);
    const x=(pos.x*0.5+0.5)*window.innerWidth,y=(-pos.y*0.5+0.5)*window.innerHeight;
    const el=document.createElement('div');el.className='float-text '+type;el.textContent=text;el.style.left=x+'px';el.style.top=y+'px';
    document.getElementById('floating-texts').appendChild(el);setTimeout(()=>el.remove(),1500);
}

// Hit Splat system (shows damage numbers on enemies)
function createHitSplat(worldPos,text,type){
    const pos=worldPos.clone();pos.project(GameState.camera);
    const x=(pos.x*0.5+0.5)*window.innerWidth,y=(-pos.y*0.5+0.5)*window.innerHeight;
    const el=document.createElement('div');el.className='hit-splat '+type;el.textContent=text;
    var scale=Math.min(2.0,1.0+(parseFloat(text)/50)*0.5);
    el.style.fontSize=Math.round(16*scale)+'px';
    el.style.left=(x+(Math.random()-0.5)*30)+'px';el.style.top=(y+(Math.random()-0.5)*20)+'px';
    document.getElementById('hit-splats').appendChild(el);setTimeout(()=>el.remove(),800);
}

// XP Drop system (RS-style drops floating up)
function createXPDrop(skill,amount){
    const el=document.createElement('div');el.className='xp-drop';
    const def=SKILL_DEFS[skill];
    el.innerHTML='<span style="color:'+def.color+'">+'+amount+'</span> '+def.icon;
    // Position right side of screen near the top
    el.style.right='220px';el.style.top=(80+Math.random()*20)+'px';
    document.getElementById('xp-drops').appendChild(el);setTimeout(()=>el.remove(),2000);
}

// Loot Toast system
function createLootToast(text,icon){
    const el=document.createElement('div');el.className='loot-toast';
    el.innerHTML=(icon||'\uD83D\uDCE6')+' '+text;
    const container=document.getElementById('loot-toasts');
    container.appendChild(el);
    setTimeout(()=>el.remove(),2500);
    while(container.children.length>5)container.removeChild(container.firstChild);
}

function triggerScreenFlash(color,duration){
    var el=document.getElementById('screen-flash');
    if(!el)return;
    el.style.background=color;
    el.style.opacity='0.3';
    setTimeout(function(){el.style.opacity='0';},duration||100);
}

function showPickupToast(itemName,icon,quantity){
    var el=document.createElement('div');
    el.className='pickup-toast';
    el.textContent=(icon||'\u{1F4E6}')+' '+itemName+(quantity>1?' x'+quantity:'');
    document.body.appendChild(el);
    setTimeout(function(){el.remove();},2100);
}

function updateBars(){
    document.getElementById('hp-fill').style.width=(player.hp/player.maxHp)*100+'%';
    document.getElementById('hp-text').textContent=Math.round(player.hp)+'/'+player.maxHp;
    document.getElementById('energy-fill').style.width=(player.energy/player.maxEnergy)*100+'%';
    document.getElementById('energy-text').textContent=Math.round(player.energy)+'/'+player.maxEnergy;
    // Low HP vignette
    var hpPct=player.hp/player.maxHp;
    var vig=document.getElementById('low-hp-vignette');
    if(vig)vig.style.opacity=hpPct<0.3?(0.3-hpPct)/0.3:0;
    // Player hit flash
    if(player.hitFlash>0){
        player.hitFlash-=GameState.deltaTime;
        var fi=Math.max(0,player.hitFlash)/0.2;
        player.mesh.traverse(function(c){if(c.material&&c.material.emissive)c.material.emissive.setRGB(fi,0,0);});
        if(player.hitFlash<=0)player.mesh.traverse(function(c){if(c.material&&c.material.emissive)c.material.emissive.setRGB(0,0,0);});
    }
    // Kill streak timer
    if(killStreak.timer>0){killStreak.timer-=GameState.deltaTime;if(killStreak.timer<=0){killStreak.count=0;var ksEl=document.getElementById('kill-streak');if(ksEl)ksEl.style.opacity='0';}}
}

function updateTargetInfo(){
    const t=player.combatTarget,p=document.getElementById('target-info');
    if(t&&t.alive){p.style.display='block';document.getElementById('target-name').textContent=t.name+' (Lv '+t.level+')';document.getElementById('target-hp-fill').style.width=(t.hp/t.maxHp)*100+'%';document.getElementById('target-hp-text').textContent=Math.round(t.hp)+'/'+t.maxHp;}
    else{p.style.display='none';}
}

function updateActionBar(){
    const slot=document.querySelector('.action-slot[data-slot="1"]');
    if(!slot)return;
    const weapon=player.equipment.weapon;
    if(weapon){
        const styleIcon={nano:'\uD83E\uDDA0',tesla:'\u26A1',void:'\uD83C\uDF11'}[weapon.style]||'?';
        slot.innerHTML='<span class="keybind">1</span><span class="ability-icon">'+styleIcon+'</span><div class="cooldown-overlay"></div>';
        slot.title=weapon.name+' ('+weapon.style+') - Press 1 to attack';
    } else {
        slot.innerHTML='<span class="keybind">1</span><span class="ability-icon">\u2694\uFE0F</span><div class="cooldown-overlay"></div>';
        slot.title='No weapon - Press 1 to attack';
    }
    slot.classList.remove('active');
}

let invSelectedSlot=-1;

function renderInventory(){
    const grid=document.getElementById('inventory-grid');grid.innerHTML='';
    for(let i=0;i<28;i++){
        const slot=document.createElement('div');slot.className='inv-slot';slot.dataset.index=i;
        if(i===invSelectedSlot)slot.style.borderColor='#00c8ff';
        const inv=player.inventory[i];
        if(inv){const def=getItem(inv.itemId);slot.classList.add('has-item');slot.innerHTML='<span class="item-icon">'+def.icon+'</span>'+(inv.quantity>1?'<span class="item-count">'+inv.quantity+'</span>':'');
            // Create tooltip-friendly def with durability info from inventory slot
            var tooltipDef=def;
            if(inv.durability!==undefined){tooltipDef=Object.assign({},def);tooltipDef.durability=inv.durability;tooltipDef.maxDurability=inv.maxDurability;}
            slot.addEventListener('mouseenter',(function(td){return function(e){showTooltip(e.clientX,e.clientY,td);};})(tooltipDef));
            slot.addEventListener('mousemove',e=>{if(tooltip.style.display!=='none'){tooltip.style.left=Math.min(e.clientX+12,window.innerWidth-260)+'px';tooltip.style.top=Math.min(e.clientY+12,window.innerHeight-tooltip.offsetHeight-10)+'px';}});
            slot.addEventListener('mouseleave',()=>{hideTooltip();});
            slot.addEventListener('contextmenu',e=>{e.preventDefault();e.stopPropagation();invSelectedSlot=-1;hideTooltip();showItemContextMenu(e.clientX,e.clientY,i,def);});
        }
        slot.addEventListener('click',function(e){
            // Shift+click to eat food (Feature 13)
            if(e.shiftKey&&player.inventory[i]){
                var sDef=getItem(player.inventory[i].itemId);
                if(sDef&&(sDef.type==='food'||sDef.heals)){useItem(i);renderInventory();return;}
            }
            if(invSelectedSlot>=0&&invSelectedSlot!==i){
                // Swap the two slots
                const tmp=player.inventory[invSelectedSlot];
                player.inventory[invSelectedSlot]=player.inventory[i];
                player.inventory[i]=tmp;
                invSelectedSlot=-1;
                renderInventory();
            } else if(invSelectedSlot===i){
                // Deselect
                invSelectedSlot=-1;renderInventory();
            } else {
                // Select this slot
                invSelectedSlot=i;renderInventory();
            }
        });
        grid.appendChild(slot);
    }
    let cd=document.getElementById('inv-credits');if(!cd){cd=document.createElement('div');cd.id='inv-credits';cd.style.cssText='text-align:center;padding:6px;font-size:12px;color:#ffcc44;font-weight:700;';grid.parentNode.appendChild(cd);}
    cd.textContent='Credits: '+player.credits;
}

function showItemContextMenu(x,y,slotIndex,def){
    const opts=[];
    if(def.slot)opts.push({label:'Equip '+def.name,action:()=>{equipItem(slotIndex);renderInventory();}});
    if(def.type==='food')opts.push({label:'Eat '+def.name,action:()=>{useItem(slotIndex);renderInventory();}});
    // Quick slot assignment (Feature 5)
    if(def.type==='food'||def.heals){
        var nextFreeSlot=-1;
        for(var qsi=0;qsi<5;qsi++){if(!player.quickSlots[qsi]){nextFreeSlot=qsi;break;}}
        if(nextFreeSlot===-1)nextFreeSlot=0;
        (function(nfs,itemDef){
            opts.push({label:'Set Quick Slot '+(nfs+1),action:function(){player.quickSlots[nfs]=itemDef.id;updateQuickBar();EventBus.emit('chat',{type:'info',text:itemDef.name+' assigned to slot '+(nfs+1)});}});
        })(nextFreeSlot,def);
    }
    opts.push({label:'Drop '+def.name,action:()=>{dropItem(slotIndex);renderInventory();}});
    opts.push({label:'Examine',action:()=>{EventBus.emit('chat',{type:'info',text:def.name+': '+def.desc});}});
    showContextMenu(x,y,opts);
}

function renderEquipment(){
    document.querySelectorAll('.equip-slot').forEach(el=>{
        const sn=el.dataset.slot,item=player.equipment[sn];
        if(item){el.classList.add('has-item');
            var durHTML='';
            if(item.durability!==undefined){
                var pct=Math.round((item.durability/item.maxDurability)*100);
                var barColor=pct>50?'#44ff88':pct>25?'#ffcc44':'#ff4444';
                durHTML='<div class="equip-dur-bar"><div class="equip-dur-fill" style="width:'+pct+'%;background:'+barColor+';"></div></div>';
                if(item.durability<=0)durHTML+='<div class="equip-broken-label">BROKEN</div>';
            }
            el.innerHTML='<span class="item-icon">'+item.icon+'</span>'+durHTML;
            el.onmouseenter=function(e){showTooltip(e.clientX,e.clientY,item);};
            el.onmousemove=function(e){if(tooltip.style.display!=='none'){tooltip.style.left=Math.min(e.clientX+12,window.innerWidth-260)+'px';tooltip.style.top=Math.min(e.clientY+12,window.innerHeight-tooltip.offsetHeight-10)+'px';}};
            el.onmouseleave=function(){hideTooltip();};
            el.onclick=()=>{hideTooltip();unequipItem(sn);renderEquipment();renderInventory();};}
        else{el.classList.remove('has-item');el.textContent=sn.charAt(0).toUpperCase()+sn.slice(1);el.onmouseenter=null;el.onmouseleave=null;el.onmousemove=null;el.onclick=null;}
    });
    var ssb=player.styleSetBonus||{pieces:0};
    var styleHTML=ssb.pieces>0?'<div style="color:#ffcc44;font-size:10px;margin-top:3px;">'+({nano:'Nano',tesla:'Tesla','void':'Void'}[ssb.style]||'')+' Set: '+ssb.pieces+'/5'+(ssb.full?' (+10% dmg, +5% acc)':' (+5% dmg, +3% acc)')+'</div>':'';
    document.getElementById('equipment-stats').innerHTML='<div>Combat Level: <span style="color:#ffd700;font-weight:bold">'+getCombatLevel()+'</span></div><div>Armor: <span style="color:#44aaff">'+player.armorBonus+'</span></div><div>Damage: <span style="color:#ff4444">'+player.damageBonus+'</span></div><div>Accuracy: <span style="color:#44ff88">'+player.attackBonus+'</span></div><div>Max HP: <span style="color:#ff6666">'+player.maxHp+'</span></div>'+styleHTML;
}

function renderSkills(){
    const list=document.getElementById('skills-list');list.innerHTML='';
    Object.entries(SKILL_DEFS).forEach(([sid,def])=>{
        if(sid==='psionics'&&!player.psionicsUnlocked){
            var lockRow=document.createElement('div');lockRow.className='skill-row skill-locked';
            lockRow.innerHTML='<div class="skill-icon" style="background:#33333322;color:#555">\uD83D\uDD12</div><div class="skill-info"><div class="skill-name" style="color:#555">???</div><div style="font-size:10px;color:#444;margin-top:2px">'+def.lockText+'</div></div><div class="skill-level" style="color:#444">?</div>';
            list.appendChild(lockRow);return;
        }
        if(sid==='chronomancy'&&def.softGate){
            var maxCombat=Math.max(player.skills.nano.level,player.skills.tesla.level,player.skills.void.level);
            if(maxCombat<10){
                var gateRow=document.createElement('div');gateRow.className='skill-row skill-gated';
                gateRow.innerHTML='<div class="skill-icon" style="background:'+def.color+'22;color:'+def.color+'">'+def.icon+'</div><div class="skill-info"><div class="skill-name" style="color:#777">'+def.name+'</div><div style="font-size:10px;color:#555;margin-top:2px">'+def.softGateText+'</div></div><div class="skill-level" style="color:#555">1</div>';
                list.appendChild(gateRow);return;
            }
        }
        if(!player.skills[sid])return;
        const sk=player.skills[sid],nxp=xpForLevel(sk.level+1),cxp=xpForLevel(sk.level);
        const prog=nxp>cxp?((sk.xp-cxp)/(nxp-cxp))*100:100;
        const row=document.createElement('div');row.className='skill-row'+(def.type==='prestige'?' prestige':'');row.dataset.skill=sid;
        var prestigeTag=def.type==='prestige'?' <span style="font-size:9px;color:'+def.color+'">[PRESTIGE]</span>':'';
        var pTierTag='';
        if(player.prestige.tier>0&&def.type!=='prestige')pTierTag=' <span style="font-size:8px;color:#ffd700;opacity:0.7;">[P'+player.prestige.tier+']</span>';
        var xpBarStyle=def.type==='prestige'?'background:linear-gradient(90deg,'+def.color+','+def.color+'88)':'';
        var levelStyle=def.type==='prestige'?' style="color:'+def.color+'"':'';
        row.innerHTML='<div class="skill-icon" style="background:'+def.color+'22;color:'+def.color+'">'+def.icon+'</div><div class="skill-info"><div class="skill-name">'+def.name+prestigeTag+pTierTag+'</div><div class="skill-xp-bar"><div class="skill-xp-fill" style="width:'+prog+'%;'+xpBarStyle+'"></div></div></div><div class="skill-level"'+levelStyle+'>'+sk.level+'</div>';
        row.title=def.name+' Lv '+sk.level+' | XP: '+sk.xp.toLocaleString()+'/'+nxp.toLocaleString();
        row.style.cursor='pointer';row.addEventListener('click',function(){openSkillGuide(sid);});
        list.appendChild(row);
    });
}
function openSkillGuide(skillId){
    if(skillId==='psionics'&&!player.psionicsUnlocked)return;
    if(!player.skills[skillId])return;
    var def=SKILL_DEFS[skillId];var sk=player.skills[skillId];if(!def||!sk)return;
    var panel=document.getElementById('skill-guide-panel');
    var header=document.getElementById('skill-guide-header');
    var list=document.getElementById('skill-guide-list');
    document.getElementById('skill-guide-title').textContent=def.name+' Guide';
    header.innerHTML='<div class="guide-skill-icon" style="background:'+def.color+'22;color:'+def.color+'">'+def.icon+'</div><div class="guide-skill-info"><div class="guide-skill-name">'+def.name+'</div><div class="guide-skill-level">Level '+sk.level+' | XP: '+sk.xp.toLocaleString()+'</div></div>';
    list.innerHTML='';
    var unlocks=SKILL_UNLOCKS[skillId];
    if(!unlocks){list.innerHTML='<div style="padding:15px;color:#5a7a9a;text-align:center;">No unlocks defined.</div>';panel.style.display='flex';return;}
    var typeIcons={item:'\uD83D\uDCE6',passive:'\u2B06',synergy:'\uD83D\uDD17',milestone:'\u2B50',mastery:'\uD83C\uDFC6'};
    for(var i=0;i<unlocks.length;i++){
        var u=unlocks[i];var isUnlocked=sk.level>=u.level;
        var row=document.createElement('div');row.className='guide-unlock-row '+(isUnlocked?'unlocked':'locked');
        row.innerHTML='<div class="guide-level">'+u.level+'</div><div class="guide-type-icon">'+(typeIcons[u.type]||'\u2022')+'</div><div class="guide-desc">'+u.desc+'</div><div class="guide-status">'+(isUnlocked?'\u2713':'\uD83D\uDD12')+'</div>';
        list.appendChild(row);
    }
    panel.style.display='flex';
}
function closeSkillGuide(){document.getElementById('skill-guide-panel').style.display='none';}

function renderSynergiesTab(){
    var list=document.getElementById('synergies-list');list.innerHTML='';
    SYNERGY_DEFS.forEach(function(syn){
        var unlocked=hasSynergy(syn.id);
        var row=document.createElement('div');
        row.className='synergy-row'+(unlocked?' unlocked':' locked');
        row.innerHTML='<div class="synergy-status">'+(unlocked?'\u2713':'\uD83D\uDD12')+'</div><div class="synergy-info"><div class="synergy-name">'+syn.name+'</div><div class="synergy-desc">'+syn.desc+'</div><div class="synergy-req">Requires: '+syn.reqText+'</div></div>';
        list.appendChild(row);
    });
}

function initSkillTabs(){
    var tabBtns=document.querySelectorAll('.skill-tab-btn');
    tabBtns.forEach(function(btn){
        btn.addEventListener('click',function(){
            tabBtns.forEach(function(b){b.classList.remove('active');});
            btn.classList.add('active');
            var tab=btn.dataset.tab;
            document.getElementById('skills-list').style.display=(tab==='skills'?'':'none');
            document.getElementById('synergies-list').style.display=(tab==='synergies'?'':'none');
            if(tab==='synergies')renderSynergiesTab();
            if(tab==='skills')renderSkills();
        });
    });
}

function updateSkillBars(){
    const panel=document.getElementById('skills-panel');
    if(!panel||panel.classList.contains('hidden'))return;
    document.querySelectorAll('.skill-row[data-skill]').forEach(row=>{
        const sid=row.dataset.skill,def=SKILL_DEFS[sid],sk=player.skills[sid];
        if(!sk||!def)return;
        const nxp=xpForLevel(sk.level+1),cxp=xpForLevel(sk.level);
        const prog=nxp>cxp?((sk.xp-cxp)/(nxp-cxp))*100:100;
        const fill=row.querySelector('.skill-xp-fill');if(fill)fill.style.width=prog+'%';
        const lvl=row.querySelector('.skill-level');if(lvl)lvl.textContent=sk.level;
        row.title=def.name+' Lv '+sk.level+' | XP: '+sk.xp.toLocaleString()+'/'+nxp.toLocaleString();
    });
}

function renderCombatStyles(){}

// ----------------------------------------
// Repair Station
// ----------------------------------------
function calculateRepairCost(itemDef, item) {
    if (!item || item.durability === undefined) return 0;
    var missing = item.maxDurability - item.durability;
    if (missing <= 0) return 0;
    var costPerPoint = Math.max(1, Math.floor(itemDef.value * 0.01));
    return missing * costPerPoint;
}

function openRepairStation() {
    var panel = document.getElementById('crafting-panel');
    var rd = document.getElementById('crafting-recipes');
    document.getElementById('crafting-title').textContent = 'Repair Station';
    rd.innerHTML = '';
    var hasItems = false;
    // List equipment needing repair
    var allSlots = ['weapon', 'head', 'body', 'legs', 'boots', 'gloves', 'offhand'];
    allSlots.forEach(function(slot) {
        var item = player.equipment[slot];
        if (!item || item.durability === undefined || item.durability >= item.maxDurability) return;
        hasItems = true;
        var def = getItem(item.id) || item;
        var cost = calculateRepairCost(def, item);
        var pct = Math.round((item.durability / item.maxDurability) * 100);
        var row = document.createElement('div');
        row.className = 'recipe-row' + (player.credits >= cost ? ' can-craft' : '');
        row.innerHTML = '<div class="recipe-icon">' + item.icon + '</div><div class="recipe-info"><div class="recipe-name">' + item.name + ' [' + slot + ']</div><div class="recipe-reqs">' + item.durability + '/' + item.maxDurability + ' (' + pct + '%) | Cost: ' + cost + ' Credits</div></div><button class="recipe-btn" ' + (player.credits >= cost ? '' : 'disabled style="opacity:0.4"') + '>Repair</button>';
        row.querySelector('.recipe-btn').addEventListener('click', function() { repairItem(slot); openRepairStation(); });
        rd.appendChild(row);
    });
    // Also list inventory items needing repair
    player.inventory.forEach(function(inv, idx) {
        if (!inv || inv.durability === undefined || inv.durability >= inv.maxDurability) return;
        var def = getItem(inv.itemId);
        if (!def) return;
        hasItems = true;
        var cost = calculateRepairCost(def, inv);
        var pct = Math.round((inv.durability / inv.maxDurability) * 100);
        var row = document.createElement('div');
        row.className = 'recipe-row' + (player.credits >= cost ? ' can-craft' : '');
        row.innerHTML = '<div class="recipe-icon">' + def.icon + '</div><div class="recipe-info"><div class="recipe-name">' + def.name + ' [inventory]</div><div class="recipe-reqs">' + inv.durability + '/' + inv.maxDurability + ' (' + pct + '%) | Cost: ' + cost + ' Credits</div></div><button class="recipe-btn" ' + (player.credits >= cost ? '' : 'disabled style="opacity:0.4"') + '>Repair</button>';
        row.querySelector('.recipe-btn').addEventListener('click', function() { repairInventoryItem(idx); openRepairStation(); });
        rd.appendChild(row);
    });
    if (!hasItems) {
        rd.innerHTML = '<div style="padding:15px;color:#5a7a9a;text-align:center;">No items need repair.</div>';
    } else {
        // Calculate total repair cost
        var totalCost = 0;
        var repairCount = 0;
        allSlots.forEach(function(slot){
            var item2=player.equipment[slot];
            if(!item2||item2.durability===undefined||item2.durability>=item2.maxDurability)return;
            totalCost+=calculateRepairCost(getItem(item2.id)||item2,item2);repairCount++;
        });
        player.inventory.forEach(function(inv2){
            if(!inv2||inv2.durability===undefined||inv2.durability>=inv2.maxDurability)return;
            var def2=getItem(inv2.itemId);if(!def2)return;
            totalCost+=calculateRepairCost(def2,inv2);repairCount++;
        });
        if(repairCount>1){
            var repairAllRow=document.createElement('div');
            repairAllRow.className='recipe-row'+(player.credits>=totalCost?' can-craft':'');
            repairAllRow.style.cssText='border-top:1px solid #2a4a6a;margin-top:8px;padding-top:8px;';
            repairAllRow.innerHTML='<div class="recipe-icon">\uD83D\uDD27</div><div class="recipe-info"><div class="recipe-name" style="color:#44ffaa;">Repair All ('+repairCount+' items)</div><div class="recipe-reqs">Total Cost: '+totalCost+' Credits</div></div><button class="recipe-btn" style="background:#1a4a3a;border-color:#44ffaa;" '+(player.credits>=totalCost?'':'disabled style="opacity:0.4"')+'>Repair All</button>';
            repairAllRow.querySelector('.recipe-btn').addEventListener('click',function(){repairAllItems();openRepairStation();});
            rd.appendChild(repairAllRow);
        }
    }
    panel.style.display = 'flex';
    craftingFromStation = true;
}

function repairItem(slot) {
    var item = player.equipment[slot];
    if (!item || item.durability === undefined) return;
    var def = getItem(item.id) || item;
    var cost = calculateRepairCost(def, item);
    if (player.credits < cost) { EventBus.emit('chat', { type: 'info', text: 'Not enough Credits to repair!' }); return; }
    removeCredits(cost);
    item.durability = item.maxDurability;
    durabilityWarned[item.id + '_' + slot + '_warn'] = false;
    durabilityWarned[item.id + '_warn'] = false;
    recalcStats();
    EventBus.emit('equipmentChanged');
    EventBus.emit('chat', { type: 'skill', text: 'You repair your ' + item.name + ' for ' + cost + ' Credits.' });
    playSound('mine_success');
}

function repairInventoryItem(idx) {
    var inv = player.inventory[idx];
    if (!inv || inv.durability === undefined) return;
    var def = getItem(inv.itemId);
    if (!def) return;
    var cost = calculateRepairCost(def, inv);
    if (player.credits < cost) { EventBus.emit('chat', { type: 'info', text: 'Not enough Credits to repair!' }); return; }
    removeCredits(cost);
    inv.durability = inv.maxDurability;
    EventBus.emit('inventoryChanged');
    EventBus.emit('chat', { type: 'skill', text: 'You repair the ' + def.name + ' for ' + cost + ' Credits.' });
    playSound('mine_success');
}

function repairAllItems(){
    var totalCost=0;var repaired=0;
    var allSlots2=['weapon','head','body','legs','boots','gloves','offhand'];
    // Calculate total cost first
    allSlots2.forEach(function(slot){
        var item=player.equipment[slot];
        if(!item||item.durability===undefined||item.durability>=item.maxDurability)return;
        totalCost+=calculateRepairCost(getItem(item.id)||item,item);
    });
    player.inventory.forEach(function(inv){
        if(!inv||inv.durability===undefined||inv.durability>=inv.maxDurability)return;
        var def=getItem(inv.itemId);if(!def)return;
        totalCost+=calculateRepairCost(def,inv);
    });
    if(player.credits<totalCost){EventBus.emit('chat',{type:'info',text:'Not enough Credits for full repair! (Need '+totalCost+')'});return;}
    // Do the repairs
    allSlots2.forEach(function(slot){
        var item=player.equipment[slot];
        if(!item||item.durability===undefined||item.durability>=item.maxDurability)return;
        var def=getItem(item.id)||item;
        var cost=calculateRepairCost(def,item);
        removeCredits(cost);
        item.durability=item.maxDurability;
        durabilityWarned[item.id+'_'+slot+'_warn']=false;
        durabilityWarned[item.id+'_warn']=false;
        repaired++;
    });
    player.inventory.forEach(function(inv){
        if(!inv||inv.durability===undefined||inv.durability>=inv.maxDurability)return;
        var def=getItem(inv.itemId);if(!def)return;
        var cost=calculateRepairCost(def,inv);
        removeCredits(cost);
        inv.durability=inv.maxDurability;
        repaired++;
    });
    recalcStats();
    EventBus.emit('equipmentChanged');
    EventBus.emit('inventoryChanged');
    EventBus.emit('chat',{type:'skill',text:'Repaired '+repaired+' items for '+totalCost+' Credits.'});
    playSound('mine_success');
}

let craftingFromStation=false;
function openCrafting(skillId){
    craftingFromStation=true;
    const panel=document.getElementById('crafting-panel'),rd=document.getElementById('crafting-recipes');
    document.getElementById('crafting-title').textContent=SKILL_DEFS[skillId].name+' Crafting';rd.innerHTML='';
    const recipes=getAvailableRecipes(skillId);
    if(!recipes.length){rd.innerHTML='<div style="padding:15px;color:#5a7a9a;text-align:center;">No recipes available.</div>';}
    recipes.forEach(r=>{
        const outDef=getItem(Object.keys(r.output)[0]);
        const inDesc=Object.entries(r.input).map(([id,qty])=>qty+'x '+getItem(id).name).join(', ');
        const row=document.createElement('div');row.className='recipe-row'+(r.canCraft?' can-craft':'');
        row.innerHTML='<div class="recipe-icon">'+(outDef?outDef.icon:'?')+'</div><div class="recipe-info"><div class="recipe-name">'+r.name+'</div><div class="recipe-reqs">Lv '+r.level+' | '+inDesc+' | '+r.xp+' XP</div></div><button class="recipe-btn" '+(r.canCraft?'':'disabled style="opacity:0.4"')+'>Craft</button>';
        row.querySelector('.recipe-btn').addEventListener('click',()=>{if(craft(r.id)){renderInventory();openCrafting(skillId);}});
        rd.appendChild(row);
    });
    panel.style.display='flex';
}

function updateMinimap(){
    const canvas=document.getElementById('minimap-canvas'),ctx=canvas.getContext('2d'),w=canvas.width,h=canvas.height;
    const px=player.mesh.position.x,pz=player.mesh.position.z;
    ctx.fillStyle='#080c14';ctx.fillRect(0,0,w,h);
    const cx=w/2,cy=h/2;
    var msc=0.25*minimapZoom;
    [{x:0,z:0,r:35,c:'#1a2838'},{x:300,z:0,r:200,c:'#2a1a10'},{x:0,z:-300,r:250,c:'#0a1a10'},{x:-20,z:20,r:18,c:'#0a2020'}].forEach(a=>{ctx.fillStyle=a.c;ctx.beginPath();ctx.arc(cx+(a.x-px)*msc,cy+(a.z-pz)*msc,a.r*msc,0,Math.PI*2);ctx.fill();});
    GameState.enemies.forEach(e=>{if(!e.alive)return;const ex=cx+(e.mesh.position.x-px)*msc,ey=cy+(e.mesh.position.z-pz)*msc;if(ex<0||ex>w||ey<0||ey>h)return;ctx.fillStyle='#ff4444';ctx.fillRect(ex-1.5,ey-1.5,3,3);});
    GameState.npcs.forEach(n=>{const nx=cx+(n.position.x-px)*msc,ny=cy+(n.position.z-pz)*msc;if(nx<0||nx>w||ny<0||ny>h)return;ctx.fillStyle='#ffcc00';ctx.fillRect(nx-2,ny-2,4,4);});
    GameState.resourceNodes.forEach(n=>{if(n.depleted)return;const rx=cx+(n.position.x-px)*msc,ry=cy+(n.position.z-pz)*msc;if(rx<0||rx>w||ry<0||ry>h)return;ctx.fillStyle='#44aaff';ctx.fillRect(rx-1,ry-1,2,2);});
    ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(cx,cy,3,0,Math.PI*2);ctx.fill();
    const dir=player.mesh.rotation.y;ctx.strokeStyle='#fff';ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(cx,cy);ctx.lineTo(cx+Math.sin(dir)*8,cy-Math.cos(dir)*8);ctx.stroke();
    // Zoom indicator
    if(minimapZoom!==1.0){ctx.fillStyle='rgba(255,255,255,0.4)';ctx.font='8px monospace';ctx.textAlign='right';ctx.fillText(minimapZoom.toFixed(1)+'x',w-4,h-4);}
    const an={'station-hub':'Station Hub','asteroid-mines':'Asteroid Mines','alien-wastes':'Alien Wastes','bio-lab':'Bio-Lab','the-abyss':'The Abyss'};
    document.getElementById('area-name').textContent=an[player.currentArea]||'Unknown';
}

function updateGatherBar(){
    const c=document.getElementById('gather-bar-container');
    if(player.isGathering){c.style.display='block';document.getElementById('gather-bar-fill').style.width=(player.gatherProgress/player.gatherDuration)*100+'%';document.getElementById('gather-bar-text').textContent='Gathering...';}
    else{c.style.display='none';}
}

function setupPanelButtons(){
    const panels={'btn-inventory':'inventory-panel','btn-equipment':'equipment-panel','btn-skills':'skills-panel','btn-quests':'quest-panel'};
    Object.entries(panels).forEach(([bid,pid])=>{
        document.getElementById(bid).addEventListener('click',()=>{
            const p=document.getElementById(pid),vis=p.style.display!=='none';if(vis&&player.panelLocks[pid]){EventBus.emit('chat',{type:'info',text:'Panel is locked.'});return;}p.style.display=vis?'none':'flex';document.getElementById(bid).classList.toggle('active',!vis);
            if(!vis){if(pid==='inventory-panel')renderInventory();if(pid==='equipment-panel')renderEquipment();if(pid==='skills-panel')renderSkills();if(pid==='quest-panel')renderQuestPanel();checkTutorialEvent('panelOpened');}
        });
    });
    EventBus.on('escape',()=>{Object.entries(panels).forEach(([bid,pid])=>{if(!player.panelLocks[pid]){document.getElementById(pid).style.display='none';document.getElementById(bid).classList.remove('active');}});if(!player.panelLocks['crafting-panel']){document.getElementById('crafting-panel').style.display='none';craftingFromStation=false;}document.getElementById('board-panel').style.display='none';document.getElementById('skill-guide-panel').style.display='none';document.getElementById('bestiary-panel').style.display='none';document.getElementById('quest-panel').style.display='none';document.getElementById('world-map-panel').style.display='none';if(bankOpen)closeBank();if(activeShop)closeShop();if(activeNPC)closeDialogue();var ac=document.getElementById('audio-controls');if(ac)ac.style.display='none';});
    // Audio button — click opens volume popup, right-click toggles mute
    var audioBtn=document.getElementById('btn-audio');
    if(audioBtn){
        audioBtn.textContent=musicState.muted?'🔇':'🔊';
        audioBtn.classList.toggle('muted',musicState.muted);
        audioBtn.addEventListener('click',function(e){
            e.stopPropagation();
            var ctrl=document.getElementById('audio-controls');
            if(ctrl)ctrl.style.display=ctrl.style.display==='none'?'flex':'none';
        });
        audioBtn.addEventListener('contextmenu',function(e){
            e.preventDefault();e.stopPropagation();
            toggleMute();
        });
    }
    // Mute toggle button inside popup
    var muteBtn=document.getElementById('btn-mute-toggle');
    if(muteBtn){
        muteBtn.textContent=musicState.muted?'Unmute All':'Mute All';
        muteBtn.addEventListener('click',function(e){
            e.stopPropagation();
            toggleMute();
            this.textContent=musicState.muted?'Unmute All':'Mute All';
        });
    }
    // Volume sliders
    var musicSlider=document.getElementById('music-volume');
    var sfxSlider=document.getElementById('sfx-volume');
    if(musicSlider){
        musicSlider.value=musicState.musicVolume*100;
        musicSlider.addEventListener('input',function(){setMusicVolume(this.value/100);});
    }
    if(sfxSlider){
        sfxSlider.value=musicState.sfxVolume*100;
        sfxSlider.addEventListener('input',function(){setSFXVolume(this.value/100);});
    }
    // Close audio popup when clicking elsewhere
    document.addEventListener('click',function(e){
        var ctrl=document.getElementById('audio-controls');
        if(ctrl&&ctrl.style.display!=='none'&&!ctrl.contains(e.target)&&e.target.id!=='btn-audio'){
            ctrl.style.display='none';
        }
    });
}

function openDefaultPanels(){
    // Skip on small screens (mobile) to avoid cluttering the viewport
    if(window.innerWidth<600)return;
    var defaults=['inventory-panel','equipment-panel'];
    defaults.forEach(function(pid){
        var panel=document.getElementById(pid);
        if(!panel)return;
        panel.style.display='flex';
        // Mark the corresponding button as active
        var bid='btn-'+pid.replace('-panel','');
        var btn=document.getElementById(bid);
        if(btn)btn.classList.add('active');
        // Render panel contents
        if(pid==='inventory-panel')renderInventory();
        if(pid==='equipment-panel')renderEquipment();
    });
}

function setupPanelDragging(){
    document.querySelectorAll('.panel-header').forEach(function(header){
        var dragging=false,sx,sy,px,py;
        header.addEventListener('mousedown',function(e){
            if(e.target.classList.contains('panel-close')||e.target.classList.contains('panel-lock-btn')||e.target.closest('.panel-resize-handle'))return;
            dragging=true;
            var r=header.parentElement.getBoundingClientRect();
            sx=e.clientX;sy=e.clientY;px=r.left;py=r.top;
            header.parentElement.style.right='auto';
            header.parentElement.style.bottom='auto';
            header.parentElement.style.transform='none';
            e.preventDefault();
        });
        window.addEventListener('mousemove',function(e){
            if(!dragging)return;
            var panel=header.parentElement;
            var newLeft=px+e.clientX-sx;
            var newTop=py+e.clientY-sy;
            var rect=panel.getBoundingClientRect();
            var provisionalRect={left:newLeft,top:newTop,right:newLeft+rect.width,bottom:newTop+rect.height,width:rect.width,height:rect.height};
            var snaps=computeSnaps(provisionalRect,panel);
            if(snaps.x!==null)newLeft=snaps.x;
            if(snaps.y!==null)newTop=snaps.y;
            panel.style.left=newLeft+'px';
            panel.style.top=newTop+'px';
            showSnapGuides(panel);
        });
        window.addEventListener('mouseup',function(){
            if(dragging){dragging=false;savePanelPosition(header.parentElement);clearSnapGuides();}
        });
    });
}

function setupPanelResizing(){
    var PANEL_MIN_W=200,PANEL_MIN_H=100;
    var activeResize=null;
    // Panels that should never hide content — only allow width resize, height auto-fits
    var NO_SCROLL_PANELS={'inventory-panel':true,'equipment-panel':true};

    // Wrap panel content (everything except header and resize handles) in a clipping container
    // Skip wrapping for no-scroll panels so they always show full content
    document.querySelectorAll('.game-panel').forEach(function(panel){
        if(NO_SCROLL_PANELS[panel.id])return;
        var header=panel.querySelector('.panel-header');
        var children=Array.from(panel.children).filter(function(c){return c!==header&&!c.classList.contains('panel-resize-handle');});
        if(children.length>0){
            var wrap=document.createElement('div');
            wrap.className='panel-content-wrap';
            children.forEach(function(c){wrap.appendChild(c);});
            if(header)header.after(wrap);else panel.prepend(wrap);
        }
    });

    document.querySelectorAll('.game-panel').forEach(function(panel){
        ['right','left','bottom','top','br','bl','tr','tl'].forEach(function(dir){
            var h=document.createElement('div');
            h.className='panel-resize-handle resize-'+dir;
            h.dataset.resizeDir=dir;
            panel.appendChild(h);
        });
    });

    document.addEventListener('mousedown',function(e){
        var handle=e.target.closest('.panel-resize-handle');
        if(!handle)return;
        var panel=handle.closest('.game-panel');
        if(!panel)return;
        e.preventDefault();e.stopPropagation();
        var rect=panel.getBoundingClientRect();
        var dir=handle.dataset.resizeDir;
        panel.style.right='auto';panel.style.bottom='auto';panel.style.transform='none';
        panel.style.left=rect.left+'px';panel.style.top=rect.top+'px';
        panel.style.width=rect.width+'px';
        if(!NO_SCROLL_PANELS[panel.id])panel.style.height=rect.height+'px';
        activeResize={panel:panel,dir:dir,startX:e.clientX,startY:e.clientY,
            startRect:{left:rect.left,top:rect.top,width:rect.width,height:rect.height}};
        var cursorClass=(dir==='left'||dir==='right')?'resizing-ew':
            (dir==='top'||dir==='bottom')?'resizing-ns':
            (dir==='br'||dir==='tl')?'resizing-nwse':'resizing-nesw';
        document.body.classList.add(cursorClass);
        activeResize.cursorClass=cursorClass;
    });

    window.addEventListener('mousemove',function(e){
        if(!activeResize)return;
        var r=activeResize;
        var dx=e.clientX-r.startX,dy=e.clientY-r.startY;
        var newLeft=r.startRect.left,newTop=r.startRect.top;
        var newW=r.startRect.width,newH=r.startRect.height;

        // Right edge or right corners
        if(r.dir==='right'||r.dir==='br'||r.dir==='tr'){
            newW=Math.max(PANEL_MIN_W,r.startRect.width+dx);
        }
        // Left edge or left corners
        if(r.dir==='left'||r.dir==='bl'||r.dir==='tl'){
            var dw=Math.min(dx,r.startRect.width-PANEL_MIN_W);
            newLeft=r.startRect.left+dw;newW=r.startRect.width-dw;
        }
        // Bottom edge or bottom corners
        if(r.dir==='bottom'||r.dir==='br'||r.dir==='bl'){
            newH=Math.max(PANEL_MIN_H,r.startRect.height+dy);
        }
        // Top edge or top corners
        if(r.dir==='top'||r.dir==='tr'||r.dir==='tl'){
            var dh=Math.min(dy,r.startRect.height-PANEL_MIN_H);
            newTop=r.startRect.top+dh;newH=r.startRect.height-dh;
        }

        // Clamp to viewport
        newLeft=Math.max(0,newLeft);newTop=Math.max(0,newTop);
        if(newLeft+newW>window.innerWidth)newW=window.innerWidth-newLeft;
        if(newTop+newH>window.innerHeight)newH=window.innerHeight-newTop;

        r.panel.style.left=newLeft+'px';r.panel.style.top=newTop+'px';
        r.panel.style.width=newW+'px';
        // No-scroll panels: only resize width, height auto-fits content
        if(NO_SCROLL_PANELS[r.panel.id]){
            r.panel.style.height='';
        }else{
            r.panel.style.height=newH+'px';
        }
        showSnapGuides(r.panel);
    });

    window.addEventListener('mouseup',function(){
        if(!activeResize)return;
        document.body.classList.remove(activeResize.cursorClass);
        // No-scroll panels: clear explicit height so they auto-fit, only save width
        if(NO_SCROLL_PANELS[activeResize.panel.id]){
            activeResize.panel.style.height='';
        }
        savePanelPosition(activeResize.panel);
        savePanelSize(activeResize.panel);
        clearSnapGuides();
        activeResize=null;
    });
}

function savePanelPosition(panel){
    if(!panel||!panel.id)return;
    var r=panel.getBoundingClientRect();
    player.panelPositions[panel.id]={left:Math.round(r.left),top:Math.round(r.top)};
}

function savePanelSize(panel){
    if(!panel||!panel.id)return;
    var r=panel.getBoundingClientRect();
    if(!player.panelSizes)player.panelSizes={};
    player.panelSizes[panel.id]={width:Math.round(r.width),height:Math.round(r.height)};
}

function restorePanelSizes(){
    if(!player.panelSizes)return;
    var noScroll={'inventory-panel':true,'equipment-panel':true};
    // Enforce minimum widths matching CSS defaults so panels never open tiny
    var defaultWidths={'inventory-panel':208,'equipment-panel':220,'skills-panel':250,'shop-panel':500,'crafting-panel':400,'bestiary-panel':280,'prestige-panel':320,'prestige-shop-panel':260,'board-panel':280,'quest-panel':380};
    Object.entries(player.panelSizes).forEach(function(entry){
        var pid=entry[0],size=entry[1];
        var panel=document.getElementById(pid);
        if(!panel||!size)return;
        var minW=defaultWidths[pid]||200;
        panel.style.width=Math.max(size.width,minW)+'px';
        // No-scroll panels keep auto height so all content is always visible
        if(!noScroll[pid]){
            var minH=Math.max(150,size.height);
            panel.style.height=minH+'px';
        }
    });
}

function restorePanelPositions(){
    if(!player.panelPositions)return;
    Object.entries(player.panelPositions).forEach(function(entry){
        var pid=entry[0],pos=entry[1];
        var panel=document.getElementById(pid);
        if(!panel||!pos)return;
        panel.style.left=pos.left+'px';
        panel.style.top=pos.top+'px';
        panel.style.right='auto';
        panel.style.bottom='auto';
        panel.style.transform='none';
    });
    restorePanelSizes();
}

var SNAP_THRESHOLD=10;

function getVisiblePanelRects(excludePanel){
    var rects=[];
    document.querySelectorAll('.game-panel').forEach(function(p){
        if(p===excludePanel||p.style.display==='none')return;
        rects.push(p.getBoundingClientRect());
    });
    var mm=document.getElementById('minimap-container');
    if(mm&&mm!==excludePanel)rects.push(mm.getBoundingClientRect());
    return rects;
}

function computeSnaps(panelRect,excludePanel){
    var snaps={x:null,y:null,guideLines:[]};
    var targets=getVisiblePanelRects(excludePanel);
    var vw=window.innerWidth,vh=window.innerHeight;
    var pL=panelRect.left,pR=panelRect.right||panelRect.left+panelRect.width;
    var pT=panelRect.top,pB=panelRect.bottom||panelRect.top+panelRect.height;
    var pW=panelRect.width,pH=panelRect.height;

    // Viewport edge snaps
    if(Math.abs(pL)<SNAP_THRESHOLD){snaps.x=0;snaps.guideLines.push({orient:'vertical',pos:0});}
    else if(Math.abs(pR-vw)<SNAP_THRESHOLD){snaps.x=vw-pW;snaps.guideLines.push({orient:'vertical',pos:vw});}
    if(Math.abs(pT)<SNAP_THRESHOLD){snaps.y=0;snaps.guideLines.push({orient:'horizontal',pos:0});}
    else if(Math.abs(pB-vh)<SNAP_THRESHOLD){snaps.y=vh-pH;snaps.guideLines.push({orient:'horizontal',pos:vh});}

    // Panel-to-panel snaps
    targets.forEach(function(t){
        // X-axis snaps
        if(snaps.x===null){
            if(Math.abs(pL-t.right)<SNAP_THRESHOLD){snaps.x=t.right;snaps.guideLines.push({orient:'vertical',pos:t.right});}
            else if(Math.abs(pR-t.left)<SNAP_THRESHOLD){snaps.x=t.left-pW;snaps.guideLines.push({orient:'vertical',pos:t.left});}
            else if(Math.abs(pL-t.left)<SNAP_THRESHOLD){snaps.x=t.left;snaps.guideLines.push({orient:'vertical',pos:t.left});}
            else if(Math.abs(pR-t.right)<SNAP_THRESHOLD){snaps.x=t.right-pW;snaps.guideLines.push({orient:'vertical',pos:t.right});}
        }
        // Y-axis snaps
        if(snaps.y===null){
            if(Math.abs(pT-t.bottom)<SNAP_THRESHOLD){snaps.y=t.bottom;snaps.guideLines.push({orient:'horizontal',pos:t.bottom});}
            else if(Math.abs(pB-t.top)<SNAP_THRESHOLD){snaps.y=t.top-pH;snaps.guideLines.push({orient:'horizontal',pos:t.top});}
            else if(Math.abs(pT-t.top)<SNAP_THRESHOLD){snaps.y=t.top;snaps.guideLines.push({orient:'horizontal',pos:t.top});}
            else if(Math.abs(pB-t.bottom)<SNAP_THRESHOLD){snaps.y=t.bottom-pH;snaps.guideLines.push({orient:'horizontal',pos:t.bottom});}
        }
    });
    return snaps;
}

function showSnapGuides(panel){
    clearSnapGuides();
    var rect=panel.getBoundingClientRect();
    var snaps=computeSnaps(rect,panel);
    var container=document.getElementById('snap-guides');
    if(!container)return;
    snaps.guideLines.forEach(function(g){
        var line=document.createElement('div');
        line.className='snap-guide-line '+(g.orient==='vertical'?'vertical':'horizontal');
        if(g.orient==='vertical')line.style.left=g.pos+'px';
        else line.style.top=g.pos+'px';
        container.appendChild(line);
    });
}

function clearSnapGuides(){
    var container=document.getElementById('snap-guides');
    if(container)container.innerHTML='';
}

function setupMinimapResize(){
    var container=document.getElementById('minimap-container');
    var canvas=document.getElementById('minimap-canvas');
    var expandBtn=document.getElementById('minimap-expand-btn');
    if(!container||!canvas)return;

    // Hide old expand button
    if(expandBtn)expandBtn.style.display='none';
    container.classList.remove('expanded');

    // Restore saved minimap size
    var savedSize=player.minimapSize||{width:180,height:180};
    container.style.width=(savedSize.width+4)+'px';
    canvas.width=savedSize.width;canvas.height=savedSize.height;
    canvas.style.width=savedSize.width+'px';canvas.style.height=savedSize.height+'px';

    // Create resize handle (bottom-left)
    var handle=document.createElement('div');
    handle.id='minimap-resize-handle';
    container.appendChild(handle);

    var resizing=false,startX,startY,startW,startH;
    var MIN_SIZE=120,MAX_SIZE=500;

    handle.addEventListener('mousedown',function(e){
        e.preventDefault();e.stopPropagation();
        resizing=true;startX=e.clientX;startY=e.clientY;
        startW=canvas.width;startH=canvas.height;
        document.body.classList.add('resizing-nesw');
    });

    window.addEventListener('mousemove',function(e){
        if(!resizing)return;
        var dx=startX-e.clientX;var dy=e.clientY-startY;
        var newSize=Math.max(MIN_SIZE,Math.min(MAX_SIZE,Math.round((startW+startH)/2+(dx+dy)/2)));
        container.style.width=(newSize+4)+'px';
        canvas.width=newSize;canvas.height=newSize;
        canvas.style.width=newSize+'px';canvas.style.height=newSize+'px';
    });

    window.addEventListener('mouseup',function(){
        if(!resizing)return;
        resizing=false;
        document.body.classList.remove('resizing-nesw');
        player.minimapSize={width:canvas.width,height:canvas.height};
    });

    // Minimap zoom (scroll wheel)
    canvas.addEventListener('wheel',function(e){
        e.preventDefault();
        var delta=e.deltaY>0?-0.15:0.15;
        minimapZoom=Math.max(0.3,Math.min(4.0,minimapZoom+delta));
    },{passive:false});

    // Preserve waypoint click (Feature 8)
    canvas.addEventListener('click',function(e){
        if(e.target!==canvas)return;
        var rect=canvas.getBoundingClientRect();
        var mx=e.clientX-rect.left,my=e.clientY-rect.top;
        var w2=canvas.width,h2=canvas.height;
        var sc2=0.25*minimapZoom;
        var worldX=player.mesh.position.x+(mx-w2/2)/sc2;
        var worldZ=player.mesh.position.z+(my-h2/2)/sc2;
        player.waypoint={x:worldX,z:worldZ};
        EventBus.emit('chat',{type:'info',text:'Waypoint set.'});
    });
    canvas.addEventListener('contextmenu',function(e){
        e.preventDefault();
        player.waypoint=null;
        EventBus.emit('chat',{type:'info',text:'Waypoint cleared.'});
    });
}

function setupChatResize(){
    var chatBox=document.getElementById('chat-box');
    if(!chatBox)return;
    // Apply saved chat size + position
    applyChatLayout();
    // Create lock button (absolute top-left corner of chat box)
    var lockBtn=document.createElement('button');
    lockBtn.id='chat-lock-btn';
    lockBtn.textContent=player.chatLocked?'\uD83D\uDD12':'\uD83D\uDD13';
    lockBtn.title=player.chatLocked?'Unlock chat':'Lock chat';
    chatBox.appendChild(lockBtn);
    lockBtn.addEventListener('click',function(e){
        e.stopPropagation();
        player.chatLocked=!player.chatLocked;
        lockBtn.textContent=player.chatLocked?'\uD83D\uDD12':'\uD83D\uDD13';
        lockBtn.title=player.chatLocked?'Unlock chat':'Lock chat';
        EventBus.emit('chat',{type:'info',text:'Chat '+(player.chatLocked?'locked.':'unlocked.')});
    });
    // Chat dragging via filter bar
    var filters=document.getElementById('chat-filters');
    var dragging=false,dragSX,dragSY,dragPX,dragPY;
    if(filters){
        filters.addEventListener('mousedown',function(e){
            if(e.target.tagName==='BUTTON')return;
            if(player.chatLocked)return;
            dragging=true;
            var r=chatBox.getBoundingClientRect();
            dragSX=e.clientX;dragSY=e.clientY;dragPX=r.left;dragPY=r.top;
            chatBox.style.bottom='auto';
            chatBox.style.right='auto';
            e.preventDefault();
        });
    }
    window.addEventListener('mousemove',function(e){
        if(!dragging)return;
        chatBox.style.left=(dragPX+e.clientX-dragSX)+'px';
        chatBox.style.top=(dragPY+e.clientY-dragSY)+'px';
    });
    window.addEventListener('mouseup',function(){
        if(dragging){
            dragging=false;
            var r=chatBox.getBoundingClientRect();
            player.chatPosition={left:Math.round(r.left),top:Math.round(r.top)};
        }
    });
    // Create resize handle (top-right corner)
    var handle=document.createElement('div');
    handle.id='chat-resize-handle';
    chatBox.appendChild(handle);
    var CHAT_MIN_W=250,CHAT_MIN_H=100,CHAT_MAX_W=700,CHAT_MAX_H=500;
    var resizing=false,startX,startY,startW,startH;
    function onStart(cx,cy){
        if(player.chatLocked)return;
        resizing=true;startX=cx;startY=cy;
        var rect=chatBox.getBoundingClientRect();
        startW=rect.width;startH=rect.height;
    }
    function onMove(cx,cy){
        if(!resizing)return;
        var dx=cx-startX;
        var dy=cy-startY; // drag down = taller
        var newW=Math.max(CHAT_MIN_W,Math.min(CHAT_MAX_W,startW+dx));
        var newH=Math.max(CHAT_MIN_H,Math.min(CHAT_MAX_H,startH+dy));
        chatBox.style.width=newW+'px';
        chatBox.style.height=newH+'px';
    }
    function onEnd(){
        if(!resizing)return;
        resizing=false;
        var rect=chatBox.getBoundingClientRect();
        player.chatSize={width:Math.round(rect.width),height:Math.round(rect.height)};
        player.chatPosition={left:Math.round(rect.left),top:Math.round(rect.top)};
    }
    handle.addEventListener('mousedown',function(e){
        e.preventDefault();e.stopPropagation();
        onStart(e.clientX,e.clientY);
        if(resizing)document.body.style.cursor='nesw-resize';
    });
    window.addEventListener('mousemove',function(e){onMove(e.clientX,e.clientY);});
    window.addEventListener('mouseup',function(){if(resizing){document.body.style.cursor='';onEnd();}});
    handle.addEventListener('touchstart',function(e){
        e.preventDefault();e.stopPropagation();
        var t=e.touches[0];onStart(t.clientX,t.clientY);
    },{passive:false});
    window.addEventListener('touchmove',function(e){
        if(!resizing)return;var t=e.touches[0];onMove(t.clientX,t.clientY);
    },{passive:false});
    window.addEventListener('touchend',function(){onEnd();});
}
function applyChatLayout(){
    var chatBox=document.getElementById('chat-box');
    if(!chatBox)return;
    var savedSize=player.chatSize||{width:340,height:160};
    chatBox.style.width=savedSize.width+'px';
    chatBox.style.height=savedSize.height+'px';
    if(player.chatPosition){
        chatBox.style.left=player.chatPosition.left+'px';
        chatBox.style.top=player.chatPosition.top+'px';
        chatBox.style.bottom='auto';
    } else {
        chatBox.style.bottom='15px';
        chatBox.style.left='15px';
        chatBox.style.top='';
    }
    var lockBtn=document.getElementById('chat-lock-btn');
    if(lockBtn){
        lockBtn.textContent=player.chatLocked?'\uD83D\uDD12':'\uD83D\uDD13';
        lockBtn.title=player.chatLocked?'Unlock chat':'Lock chat';
    }
}

var LOCKABLE_PANELS=['inventory-panel','equipment-panel','skills-panel','prestige-panel','prestige-shop-panel','bestiary-panel'];

function setupPanelLocks(){
    LOCKABLE_PANELS.forEach(function(pid){
        var panel=document.getElementById(pid);
        if(!panel)return;
        var header=panel.querySelector('.panel-header');
        if(!header)return;
        // Create lock button
        var lockBtn=document.createElement('button');
        lockBtn.className='panel-lock-btn';
        lockBtn.textContent=player.panelLocks[pid]?'\uD83D\uDD12':'\uD83D\uDD13';
        lockBtn.title=player.panelLocks[pid]?'Unlock panel':'Lock panel';
        lockBtn.addEventListener('click',function(e){
            e.stopPropagation();
            player.panelLocks[pid]=!player.panelLocks[pid];
            lockBtn.textContent=player.panelLocks[pid]?'\uD83D\uDD12':'\uD83D\uDD13';
            lockBtn.title=player.panelLocks[pid]?'Unlock panel':'Lock panel';
            if(player.panelLocks[pid]){
                EventBus.emit('chat',{type:'info',text:'Panel locked.'});
            } else {
                EventBus.emit('chat',{type:'info',text:'Panel unlocked.'});
            }
        });
        // Insert before close button
        var closeBtn=header.querySelector('.panel-close');
        if(closeBtn){header.insertBefore(lockBtn,closeBtn);}
        else{header.appendChild(lockBtn);}
    });
}

function restoreLockedPanels(){
    // Restore all saved panel positions first
    restorePanelPositions();
    // Refresh lock button icons to match loaded state
    LOCKABLE_PANELS.forEach(function(pid){
        var panel=document.getElementById(pid);
        if(!panel)return;
        var lockBtn=panel.querySelector('.panel-lock-btn');
        if(lockBtn){
            lockBtn.textContent=player.panelLocks[pid]?'\uD83D\uDD12':'\uD83D\uDD13';
            lockBtn.title=player.panelLocks[pid]?'Unlock panel':'Lock panel';
        }
        // Open locked panels
        if(player.panelLocks[pid]){
            panel.style.display='flex';
            if(pid==='inventory-panel')renderInventory();
            if(pid==='equipment-panel')renderEquipment();
            if(pid==='skills-panel')renderSkills();
            var bid='btn-'+pid.replace('-panel','');
            var btn=document.getElementById(bid);
            if(btn)btn.classList.add('active');
        }
    });
    // Restore minimap size
    if(player.minimapSize&&player.minimapSize.width>0){
        var mc=document.getElementById('minimap-container');
        var mcv=document.getElementById('minimap-canvas');
        if(mc&&mcv){
            mc.classList.remove('expanded');
            mc.style.width=(player.minimapSize.width+4)+'px';
            mcv.width=player.minimapSize.width;
            mcv.height=player.minimapSize.height;
            mcv.style.width=player.minimapSize.width+'px';
            mcv.style.height=player.minimapSize.height+'px';
        }
    }
}

function setupUIEvents(){
    EventBus.on('chat',({type,text})=>addChatMessage(type,text));
    EventBus.on('floatText',({position,text,type})=>createFloatText(position,text,type));
    EventBus.on('xpGained',({skill,amount})=>{createXPDrop(skill,amount);});
    EventBus.on('levelUp',({skill,level})=>{addChatMessage('skill','LEVEL UP! '+SKILL_DEFS[skill].name+' is now level '+level+'!');spawnLevelUpVFX();});
    EventBus.on('inventoryChanged',()=>{if(document.getElementById('inventory-panel').style.display!=='none')renderInventory();});
    EventBus.on('equipmentChanged',()=>{if(document.getElementById('equipment-panel').style.display!=='none')renderEquipment();});
    EventBus.on('styleChanged',()=>{updateActionBar();});
    EventBus.on('areaChanged',area=>{const an={'station-hub':'Station Hub','asteroid-mines':'Asteroid Mines','alien-wastes':'Alien Wastes','bio-lab':'Bio-Lab','the-abyss':'The Abyss'};addChatMessage('system','Entering: '+(an[area]||area));setAreaAtmosphere(area);});
    EventBus.on('playerDamaged',({amount})=>{createHitSplat(player.mesh.position.clone().add(new THREE.Vector3(0,3,0)),amount,'damage');});
    EventBus.on('playerHealed',({amount})=>{createHitSplat(player.mesh.position.clone().add(new THREE.Vector3(0,3,0)),'+'+amount,'heal');});
    document.querySelectorAll('.panel-close').forEach(btn=>{btn.addEventListener('click',()=>{const p=btn.closest('.game-panel, #dialogue-panel');if(player.panelLocks[p.id]){EventBus.emit('chat',{type:'info',text:'Panel is locked. Unlock first to close.'});return;}p.style.display='none';if(p.id==='crafting-panel')craftingFromStation=false;if(bankOpen)closeBank();if(activeShop)closeShop();if(activeNPC)closeDialogue();var bid2='btn-'+p.id.replace('-panel','');var bbtn=document.getElementById(bid2);if(bbtn)bbtn.classList.remove('active');});});
    // Chat filter buttons
    document.querySelectorAll('.chat-filter').forEach(function(btn){
        btn.addEventListener('click',function(){
            document.querySelectorAll('.chat-filter').forEach(function(b){b.classList.remove('active');});
            btn.classList.add('active');
            activeChatFilter=btn.dataset.filter;
            var msgs=document.getElementById('chat-messages').children;
            for(var ci=0;ci<msgs.length;ci++){
                if(activeChatFilter==='all')msgs[ci].style.display='';
                else msgs[ci].style.display=(msgs[ci].dataset.chatType===activeChatFilter)?'':'none';
            }
        });
    });
    // XP tracker listener (Feature 7)
    EventBus.on('xpGained',function(data){
        if(!player.xpTracker.active){player.xpTracker.active=true;player.xpTracker.startTime=Date.now();player.xpTracker.xpGains={};}
        if(!player.xpTracker.xpGains[data.skill])player.xpTracker.xpGains[data.skill]=0;
        player.xpTracker.xpGains[data.skill]+=data.amount;
    });
    // Quick bar update on inventory change (Feature 5)
    EventBus.on('inventoryChanged',function(){updateQuickBar();});
    // Bestiary button (Feature 6)
    var bestiaryBtn=document.getElementById('btn-bestiary');
    if(bestiaryBtn)bestiaryBtn.addEventListener('click',function(){
        var p=document.getElementById('bestiary-panel');
        if(p.style.display!=='none'){p.style.display='none';}else{openBestiary();}
    });
    // Bank search input (Feature 9)
    var bankSearchInput=document.getElementById('bank-search');
    if(bankSearchInput)bankSearchInput.addEventListener('input',filterBankItems);
    // Prestige panel button
    var pstBtn=document.createElement('button');
    pstBtn.className='panel-btn';pstBtn.id='btn-prestige';pstBtn.title='Prestige';
    pstBtn.textContent='PST';pstBtn.style.color='#ffd700';
    pstBtn.addEventListener('click',function(){openPrestigePanel();});
    document.getElementById('panel-buttons').appendChild(pstBtn);
}

// ========================================
// Particle System
// ========================================
const particles=[];
function spawnParticles(position,color,count,speed,life,size){
    for(let i=0;i<count;i++){
        const geo=new THREE.BufferGeometry();
        const sz=size||0.08;
        geo.setAttribute('position',new THREE.BufferAttribute(new Float32Array([0,0,0]),3));
        const mat=new THREE.PointsMaterial({color,size:sz,sizeAttenuation:true,transparent:true,opacity:1});
        const pt=new THREE.Points(geo,mat);
        pt.position.copy(position);
        const angle=Math.random()*Math.PI*2,elevation=(Math.random()-0.3)*Math.PI;
        const spd=speed*(0.5+Math.random()*0.5);
        const vel=new THREE.Vector3(Math.cos(angle)*Math.cos(elevation)*spd,Math.sin(elevation)*spd+2,Math.sin(angle)*Math.cos(elevation)*spd);
        GameState.scene.add(pt);
        particles.push({mesh:pt,velocity:vel,life:life||1,maxLife:life||1,gravity:-5});
    }
}
function spawnDirectedParticles(from,to,color,count,speed,life){
    const dir=new THREE.Vector3().subVectors(to,from).normalize();
    for(let i=0;i<count;i++){
        const geo=new THREE.BufferGeometry();
        geo.setAttribute('position',new THREE.BufferAttribute(new Float32Array([0,0,0]),3));
        const mat=new THREE.PointsMaterial({color,size:0.12,sizeAttenuation:true,transparent:true,opacity:1});
        const pt=new THREE.Points(geo,mat);
        pt.position.copy(from).add(new THREE.Vector3((Math.random()-0.5)*0.5,1+Math.random(),(Math.random()-0.5)*0.5));
        const spread=0.4;
        const vel=dir.clone().multiplyScalar(speed*(0.6+Math.random()*0.4)).add(new THREE.Vector3((Math.random()-0.5)*spread,Math.random()*spread,(Math.random()-0.5)*spread));
        GameState.scene.add(pt);
        particles.push({mesh:pt,velocity:vel,life:life||0.8,maxLife:life||0.8,gravity:-3});
    }
}
function updateParticles(){
    const dt=GameState.deltaTime;
    for(let i=particles.length-1;i>=0;i--){
        const p=particles[i];
        p.life-=dt;
        if(p.life<=0){GameState.scene.remove(p.mesh);p.mesh.geometry.dispose();p.mesh.material.dispose();particles.splice(i,1);continue;}
        if(p.isRing){p.mesh.scale.setScalar(1+(1-p.life/p.maxLife)*p.expandSpeed);p.mesh.material.opacity=Math.max(0,p.life/p.maxLife);continue;}
        p.velocity.y+=p.gravity*dt;
        p.mesh.position.add(p.velocity.clone().multiplyScalar(dt));
        p.mesh.material.opacity=Math.max(0,p.life/p.maxLife);
    }
}

// ========================================
// Combat VFX
// ========================================
function spawnImpactRing(position,color){
    const ringGeo=new THREE.RingGeometry(0.1,0.5,16);
    const ringMat=new THREE.MeshBasicMaterial({color,transparent:true,opacity:0.8,side:THREE.DoubleSide});
    const ring=new THREE.Mesh(ringGeo,ringMat);
    ring.position.copy(position);
    ring.rotation.x=-Math.PI/2;
    GameState.scene.add(ring);
    particles.push({mesh:ring,velocity:new THREE.Vector3(0,0,0),life:0.4,maxLife:0.4,gravity:0,isRing:true,expandSpeed:8});
}

function spawnCombatVFX(position,style,type){
    const colors={nano:0x44ff88,tesla:0x44aaff,void:0xaa44ff};
    const c=colors[style]||0xffffff;
    if(type==='aura'){
        for(let i=0;i<5;i++){
            const angle=Math.random()*Math.PI*2,r=0.8+Math.random()*0.5;
            const pos=position.clone().add(new THREE.Vector3(Math.cos(angle)*r,0.5+Math.random()*2,Math.sin(angle)*r));
            spawnParticles(pos,c,1,0.3,0.8,0.04);
        }
    } else if(type==='hit'){
        if(style==='nano'){
            // Green sparks + small leaf-like scatter
            spawnParticles(position,0x44ff88,8,2,0.5,0.07);
            spawnParticles(position,0x22aa44,5,1.2,0.4,0.04);
            spawnParticles(position,0x88ffcc,3,3,0.3,0.05);
        } else if(style==='tesla'){
            // Blue electric bolts + white sparks
            spawnParticles(position,0x44aaff,7,4,0.3,0.06);
            spawnParticles(position,0xaaddff,4,3,0.35,0.04);
            spawnParticles(position,0xffffff,3,5,0.2,0.03);
        } else if(style==='void'){
            // Purple wisps + dark core implosion
            spawnParticles(position,0xaa44ff,8,1.2,0.7,0.08);
            spawnParticles(position,0x6622aa,5,0.8,0.6,0.06);
            spawnParticles(position,0x220044,3,0.4,0.9,0.1);
        }
    }
}
// Style-specific VFX burst for special attacks
function spawnStyleBurst(position,style){
    if(style==='nano'){
        spawnImpactRing(position.clone().add(new THREE.Vector3(0,0.5,0)),0x44ff88);
        spawnParticles(position.clone().add(new THREE.Vector3(0,1,0)),0x88ffcc,12,3,0.6,0.08);
    }else if(style==='tesla'){
        // Electric burst — fast, wide spread
        for(var i=0;i<4;i++){
            var off=new THREE.Vector3((Math.random()-0.5)*2,1+Math.random(),(Math.random()-0.5)*2);
            spawnParticles(position.clone().add(off),0x88ccff,3,6,0.2,0.04);
        }
        spawnImpactRing(position.clone().add(new THREE.Vector3(0,0.5,0)),0x44aaff);
    }else if(style==='void'){
        // Implosion then burst
        spawnParticles(position.clone().add(new THREE.Vector3(0,1.5,0)),0xcc66ff,15,0.5,1.0,0.1);
        spawnImpactRing(position.clone().add(new THREE.Vector3(0,0.5,0)),0xaa44ff);
    }
}

// Level-up pillar of light + expanding ring
function spawnLevelUpVFX(){
    if(!player.mesh)return;
    var pos=player.mesh.position.clone();
    // Golden pillar particles rising upward
    for(var i=0;i<40;i++){
        var ppos=pos.clone().add(new THREE.Vector3((Math.random()-0.5)*0.6,Math.random()*4,(Math.random()-0.5)*0.6));
        var geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(new Float32Array([0,0,0]),3));
        var mat=new THREE.PointsMaterial({color:Math.random()>0.5?0xffd700:0xfffacd,size:0.1+Math.random()*0.1,sizeAttenuation:true,transparent:true,opacity:1});
        var pt=new THREE.Points(geo,mat);pt.position.copy(ppos);
        GameState.scene.add(pt);
        particles.push({mesh:pt,velocity:new THREE.Vector3((Math.random()-0.5)*0.3,3+Math.random()*4,(Math.random()-0.5)*0.3),life:1.5+Math.random()*0.5,maxLife:2.0,gravity:-0.5});
    }
    // White sparkle burst
    spawnParticles(pos.clone().add(new THREE.Vector3(0,2,0)),0xffffff,20,3,1.0,0.08);
    // Expanding golden ring at feet
    var ringGeo=new THREE.RingGeometry(0.1,0.6,24);
    var ringMat=new THREE.MeshBasicMaterial({color:0xffd700,transparent:true,opacity:0.9,side:THREE.DoubleSide});
    var ring=new THREE.Mesh(ringGeo,ringMat);
    ring.position.copy(pos).add(new THREE.Vector3(0,0.2,0));ring.rotation.x=-Math.PI/2;
    GameState.scene.add(ring);
    particles.push({mesh:ring,velocity:new THREE.Vector3(0,0,0),life:1.2,maxLife:1.2,gravity:0,isRing:true,expandSpeed:12});
    // Second ring slightly delayed (stagger effect)
    setTimeout(function(){
        var ring2Geo=new THREE.RingGeometry(0.1,0.4,24);
        var ring2Mat=new THREE.MeshBasicMaterial({color:0xfffacd,transparent:true,opacity:0.7,side:THREE.DoubleSide});
        var ring2=new THREE.Mesh(ring2Geo,ring2Mat);
        ring2.position.copy(pos).add(new THREE.Vector3(0,0.3,0));ring2.rotation.x=-Math.PI/2;
        GameState.scene.add(ring2);
        particles.push({mesh:ring2,velocity:new THREE.Vector3(0,0,0),life:1.0,maxLife:1.0,gravity:0,isRing:true,expandSpeed:15});
    },200);
    triggerScreenFlash('rgba(255,215,0,0.15)',200);
    playSound('levelUp');
}

let combatAuraTimer=0;
function updateCombatAura(){
    if(!player.inCombat||!player.combatTarget)return;
    combatAuraTimer+=GameState.deltaTime;
    if(combatAuraTimer<0.4)return;combatAuraTimer=0;
    const pos=player.mesh.position.clone();
    spawnCombatVFX(pos,player.combatStyle,'aura');
}

var prestigeAuraTimer=0;
function updatePrestigeAura(){
    if(player.prestige.tier<=0||!player.mesh)return;
    prestigeAuraTimer+=GameState.deltaTime;
    if(prestigeAuraTimer<0.5)return;
    prestigeAuraTimer=0;
    var pos=player.mesh.position.clone();
    var tierColors=[0,0x88ccff,0x44ff88,0xff8844,0xffcc44,0xff4444,0xff44aa,0x44ffaa,0xffaaaa,0xaa88ff,0xffd700];
    var color=tierColors[player.prestige.tier]||0xffd700;
    if(player.prestige.selectedAura){
        var shopItem=PRESTIGE_SHOP_ITEMS.find(function(i){return i.id===player.prestige.selectedAura;});
        if(shopItem)color=shopItem.color;
    }
    var angle=GameState.elapsedTime*2;
    for(var i=0;i<2;i++){
        var a=angle+i*Math.PI;
        var px=pos.x+Math.cos(a)*1.2;
        var pz=pos.z+Math.sin(a)*1.2;
        spawnParticles(new THREE.Vector3(px,0.5+Math.sin(GameState.elapsedTime*3)*0.3,pz),color,1,0.5,1.5,0.04);
    }
}

// ========================================
// Screen Shake
// ========================================
const screenShake={active:false,intensity:0,duration:0,timer:0,offset:new THREE.Vector3()};
function triggerScreenShake(intensity,duration){screenShake.active=true;screenShake.intensity=intensity;screenShake.duration=duration;screenShake.timer=0;}
function updateScreenShake(){
    if(!screenShake.active)return;
    screenShake.timer+=GameState.deltaTime;
    if(screenShake.timer>=screenShake.duration){screenShake.active=false;screenShake.offset.set(0,0,0);return;}
    const t=1-screenShake.timer/screenShake.duration;
    const s=screenShake.intensity*t;
    screenShake.offset.set((Math.random()-0.5)*s,(Math.random()-0.5)*s,(Math.random()-0.5)*s);
    GameState.camera.position.add(screenShake.offset);
}

// ========================================
// Sound Engine (Web Audio API)
// ========================================
let audioCtx=null;
function ensureAudio(){if(!audioCtx)audioCtx=new(window.AudioContext||window.webkitAudioContext)();}
function playSound(type,opts){
    try{
        ensureAudio();if(!audioCtx||audioCtx.state==='suspended')audioCtx.resume();
        const now=audioCtx.currentTime;
        const dest=getSFXDestination();
        opts=opts||{};
        switch(type){
            case 'hit':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sawtooth';osc.frequency.setValueAtTime(200+Math.random()*100,now);osc.frequency.exponentialRampToValueAtTime(80,now+0.15);
                gain.gain.setValueAtTime(0.15,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.15);
                osc.start(now);osc.stop(now+0.15);break;
            }
            case 'miss':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sine';osc.frequency.setValueAtTime(800,now);osc.frequency.exponentialRampToValueAtTime(200,now+0.2);
                gain.gain.setValueAtTime(0.06,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.2);
                osc.start(now);osc.stop(now+0.2);break;
            }
            case 'mine':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='square';osc.frequency.setValueAtTime(400+Math.random()*200,now);osc.frequency.exponentialRampToValueAtTime(100,now+0.1);
                gain.gain.setValueAtTime(0.08,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.1);
                osc.start(now);osc.stop(now+0.1);break;
            }
            case 'mine_success':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sine';osc.frequency.setValueAtTime(500,now);osc.frequency.setValueAtTime(700,now+0.1);osc.frequency.setValueAtTime(900,now+0.2);
                gain.gain.setValueAtTime(0.1,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.35);
                osc.start(now);osc.stop(now+0.35);break;
            }
            case 'levelup':{
                [0,0.1,0.2,0.3].forEach((t,idx)=>{const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();osc.connect(gain);gain.connect(dest);osc.type='sine';osc.frequency.setValueAtTime([523,659,784,1047][idx],now+t);gain.gain.setValueAtTime(0.12,now+t);gain.gain.exponentialRampToValueAtTime(0.001,now+t+0.2);osc.start(now+t);osc.stop(now+t+0.2);});
                break;
            }
            case 'ability':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain(),n=audioCtx.createOscillator(),ng=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);n.connect(ng);ng.connect(dest);
                osc.type='sawtooth';osc.frequency.setValueAtTime(300,now);osc.frequency.exponentialRampToValueAtTime(600,now+0.1);osc.frequency.exponentialRampToValueAtTime(150,now+0.3);
                gain.gain.setValueAtTime(0.12,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.3);
                n.type='square';n.frequency.setValueAtTime(100,now);ng.gain.setValueAtTime(0.05,now);ng.gain.exponentialRampToValueAtTime(0.001,now+0.15);
                osc.start(now);osc.stop(now+0.3);n.start(now);n.stop(now+0.15);break;
            }
            case 'ultimate':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sawtooth';osc.frequency.setValueAtTime(80,now);osc.frequency.exponentialRampToValueAtTime(400,now+0.3);osc.frequency.exponentialRampToValueAtTime(60,now+0.8);
                gain.gain.setValueAtTime(0.2,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.8);
                osc.start(now);osc.stop(now+0.8);
                const o2=audioCtx.createOscillator(),g2=audioCtx.createGain();
                o2.connect(g2);g2.connect(dest);
                o2.type='sine';o2.frequency.setValueAtTime(200,now+0.1);o2.frequency.exponentialRampToValueAtTime(800,now+0.4);
                g2.gain.setValueAtTime(0.15,now+0.1);g2.gain.exponentialRampToValueAtTime(0.001,now+0.6);
                o2.start(now+0.1);o2.stop(now+0.6);break;
            }
            case 'portal':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sine';osc.frequency.setValueAtTime(300,now);osc.frequency.exponentialRampToValueAtTime(800,now+0.3);osc.frequency.exponentialRampToValueAtTime(400,now+0.6);
                gain.gain.setValueAtTime(0.1,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.6);
                osc.start(now);osc.stop(now+0.6);break;
            }
            case 'buy':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sine';osc.frequency.setValueAtTime(600,now);osc.frequency.setValueAtTime(800,now+0.08);
                gain.gain.setValueAtTime(0.08,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.2);
                osc.start(now);osc.stop(now+0.2);break;
            }
            case 'eat':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sine';osc.frequency.setValueAtTime(400,now);osc.frequency.setValueAtTime(500,now+0.1);osc.frequency.setValueAtTime(600,now+0.2);
                gain.gain.setValueAtTime(0.08,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.3);
                osc.start(now);osc.stop(now+0.3);break;
            }
            case 'death':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='sawtooth';osc.frequency.setValueAtTime(400,now);osc.frequency.exponentialRampToValueAtTime(50,now+1);
                gain.gain.setValueAtTime(0.15,now);gain.gain.exponentialRampToValueAtTime(0.001,now+1);
                osc.start(now);osc.stop(now+1);break;
            }
            case 'equip':{
                const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
                osc.connect(gain);gain.connect(dest);
                osc.type='triangle';osc.frequency.setValueAtTime(300,now);osc.frequency.setValueAtTime(500,now+0.05);osc.frequency.setValueAtTime(400,now+0.1);
                gain.gain.setValueAtTime(0.1,now);gain.gain.exponentialRampToValueAtTime(0.001,now+0.15);
                osc.start(now);osc.stop(now+0.15);break;
            }
            case 'quest':{
                [0,0.12,0.24,0.36,0.48].forEach((t,idx)=>{const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();osc.connect(gain);gain.connect(dest);osc.type='sine';osc.frequency.setValueAtTime([523,659,784,880,1047][idx],now+t);gain.gain.setValueAtTime(0.1,now+t);gain.gain.exponentialRampToValueAtTime(0.001,now+t+0.15);osc.start(now+t);osc.stop(now+t+0.15);});
                break;
            }
        }
    }catch(e){}
}

// ========================================
// Procedural Ambient Music System
// ========================================
const AREA_MUSIC = {
    'station-hub': {
        layers: [
            {type:'sine',freq:55,gain:0.04,lfoFreq:0.08,lfoDepth:2},
            {type:'triangle',freq:110,gain:0.025,lfoFreq:0.12,lfoDepth:3},
            {type:'sine',freq:220,gain:0.015,lfoFreq:0.05,lfoDepth:1,filterFreq:400}
        ]
    },
    'asteroid-mines': {
        layers: [
            {type:'sawtooth',freq:40,gain:0.035,lfoFreq:0.06,lfoDepth:1.5,filterFreq:200},
            {type:'square',freq:80,gain:0.02,lfoFreq:0.1,lfoDepth:2,filterFreq:300},
            {type:'triangle',freq:320,gain:0.012,lfoFreq:0.15,lfoDepth:5}
        ]
    },
    'alien-wastes': {
        layers: [
            {type:'sine',freq:73,gain:0.04,lfoFreq:0.04,lfoDepth:4},
            {type:'triangle',freq:146,gain:0.02,lfoFreq:0.07,lfoDepth:3},
            {type:'sine',freq:587,gain:0.008,lfoFreq:0.2,lfoDepth:8,filterFreq:800}
        ]
    },
    'bio-lab': {
        layers: [
            {type:'sine',freq:130,gain:0.035,lfoFreq:0.09,lfoDepth:2},
            {type:'triangle',freq:260,gain:0.018,lfoFreq:0.06,lfoDepth:1.5},
            {type:'sine',freq:520,gain:0.008,lfoFreq:0.14,lfoDepth:3,filterFreq:700}
        ]
    },
    'the-abyss': {
        layers: [
            {type:'sine',freq:30,gain:0.05,lfoFreq:0.03,lfoDepth:1},
            {type:'sawtooth',freq:61,gain:0.02,lfoFreq:0.05,lfoDepth:2,filterFreq:150},
            {type:'triangle',freq:45,gain:0.03,lfoFreq:0.04,lfoDepth:1.5}
        ]
    },
    'corrupted-mines': {
        layers: [
            {type:'sawtooth',freq:40.8,gain:0.04,lfoFreq:0.07,lfoDepth:2,filterFreq:220},
            {type:'square',freq:81.6,gain:0.025,lfoFreq:0.12,lfoDepth:3,filterFreq:320},
            {type:'sawtooth',freq:163,gain:0.015,lfoFreq:0.18,lfoDepth:4,filterFreq:400}
        ]
    },
    'corrupted-wastes': {
        layers: [
            {type:'sine',freq:74.5,gain:0.045,lfoFreq:0.05,lfoDepth:5},
            {type:'sawtooth',freq:149,gain:0.02,lfoFreq:0.09,lfoDepth:4,filterFreq:350},
            {type:'triangle',freq:298,gain:0.012,lfoFreq:0.22,lfoDepth:6}
        ]
    },
    'corrupted-lab': {
        layers: [
            {type:'sine',freq:132.6,gain:0.04,lfoFreq:0.1,lfoDepth:3},
            {type:'sawtooth',freq:265,gain:0.018,lfoFreq:0.08,lfoDepth:2.5,filterFreq:500},
            {type:'sine',freq:530,gain:0.01,lfoFreq:0.16,lfoDepth:4,filterFreq:750}
        ]
    }
};

var musicState = {
    active: false,
    currentArea: null,
    layers: [],
    masterMusicGain: null,
    masterSFXGain: null,
    masterGain: null,
    musicVolume: parseFloat(localStorage.getItem('asterian_music_vol'))||0.5,
    sfxVolume: parseFloat(localStorage.getItem('asterian_sfx_vol'))||0.7,
    muted: localStorage.getItem('asterian_muted')==='true',
    initialized: false
};

function initMusicNodes(){
    ensureAudio();
    if(!audioCtx||musicState.initialized)return;
    // Create master routing: music + SFX -> master -> destination
    musicState.masterGain=audioCtx.createGain();
    musicState.masterGain.gain.value=musicState.muted?0:1;
    musicState.masterGain.connect(audioCtx.destination);
    musicState.masterMusicGain=audioCtx.createGain();
    musicState.masterMusicGain.gain.value=musicState.musicVolume;
    musicState.masterMusicGain.connect(musicState.masterGain);
    musicState.masterSFXGain=audioCtx.createGain();
    musicState.masterSFXGain.gain.value=musicState.sfxVolume;
    musicState.masterSFXGain.connect(musicState.masterGain);
    musicState.initialized=true;
    console.log('[Music] Nodes initialized, music:'+musicState.musicVolume+' sfx:'+musicState.sfxVolume+' muted:'+musicState.muted);
}

function startAreaMusic(areaId){
    if(!audioCtx||!musicState.initialized)return;
    if(audioCtx.state==='suspended')audioCtx.resume();
    var config=AREA_MUSIC[areaId]||AREA_MUSIC['station-hub'];
    // Stop any existing layers
    stopMusicLayers();
    musicState.layers=[];
    musicState.currentArea=areaId;
    musicState.active=true;
    var now=audioCtx.currentTime;
    config.layers.forEach(function(layerDef){
        var osc=audioCtx.createOscillator();
        osc.type=layerDef.type;
        osc.frequency.setValueAtTime(layerDef.freq,now);
        var gain=audioCtx.createGain();
        gain.gain.setValueAtTime(0.001,now);
        gain.gain.exponentialRampToValueAtTime(Math.max(layerDef.gain,0.001),now+2);
        // Optional lowpass filter
        var filter=null;
        if(layerDef.filterFreq){
            filter=audioCtx.createBiquadFilter();
            filter.type='lowpass';
            filter.frequency.setValueAtTime(layerDef.filterFreq,now);
            filter.Q.setValueAtTime(1,now);
            osc.connect(filter);
            filter.connect(gain);
        }else{
            osc.connect(gain);
        }
        gain.connect(musicState.masterMusicGain);
        osc.start(now);
        musicState.layers.push({
            osc:osc,gain:gain,filter:filter,
            baseFreq:layerDef.freq,targetGain:layerDef.gain,
            lfoFreq:layerDef.lfoFreq,lfoDepth:layerDef.lfoDepth,
            lfoPhase:Math.random()*Math.PI*2
        });
    });
}

function stopMusicLayers(){
    if(!audioCtx)return;
    var now=audioCtx.currentTime;
    musicState.layers.forEach(function(layer){
        try{
            layer.gain.gain.exponentialRampToValueAtTime(0.001,now+1);
            layer.osc.stop(now+1.1);
        }catch(e){}
    });
    musicState.layers=[];
    musicState.active=false;
}

function crossfadeToArea(areaId){
    if(!audioCtx||!musicState.initialized)return;
    if(musicState.currentArea===areaId)return;
    if(audioCtx.state==='suspended')audioCtx.resume();
    var config=AREA_MUSIC[areaId]||AREA_MUSIC['station-hub'];
    var now=audioCtx.currentTime;
    var fadeDur=2.5;
    // Fade out current layers
    musicState.layers.forEach(function(layer){
        try{
            layer.gain.gain.cancelScheduledValues(now);
            layer.gain.gain.setValueAtTime(Math.max(layer.gain.gain.value,0.001),now);
            layer.gain.gain.exponentialRampToValueAtTime(0.001,now+fadeDur*0.8);
            layer.osc.stop(now+fadeDur);
        }catch(e){}
    });
    // Fade in new layers after brief overlap
    var newLayers=[];
    var startTime=now+fadeDur*0.3;
    config.layers.forEach(function(layerDef){
        var osc=audioCtx.createOscillator();
        osc.type=layerDef.type;
        osc.frequency.setValueAtTime(layerDef.freq,startTime);
        var gain=audioCtx.createGain();
        gain.gain.setValueAtTime(0.001,startTime);
        gain.gain.exponentialRampToValueAtTime(Math.max(layerDef.gain,0.001),startTime+fadeDur);
        var filter=null;
        if(layerDef.filterFreq){
            filter=audioCtx.createBiquadFilter();
            filter.type='lowpass';
            filter.frequency.setValueAtTime(layerDef.filterFreq,startTime);
            filter.Q.setValueAtTime(1,startTime);
            osc.connect(filter);
            filter.connect(gain);
        }else{
            osc.connect(gain);
        }
        gain.connect(musicState.masterMusicGain);
        osc.start(startTime);
        newLayers.push({
            osc:osc,gain:gain,filter:filter,
            baseFreq:layerDef.freq,targetGain:layerDef.gain,
            lfoFreq:layerDef.lfoFreq,lfoDepth:layerDef.lfoDepth,
            lfoPhase:Math.random()*Math.PI*2
        });
    });
    musicState.layers=newLayers;
    musicState.currentArea=areaId;
    musicState.active=true;
}

function updateMusicLFO(dt){
    if(!musicState.active||!musicState.layers.length||!audioCtx)return;
    var now=audioCtx.currentTime;
    musicState.layers.forEach(function(layer){
        layer.lfoPhase+=layer.lfoFreq*dt*Math.PI*2;
        var mod=Math.sin(layer.lfoPhase)*layer.lfoDepth;
        try{
            layer.osc.frequency.setValueAtTime(layer.baseFreq+mod,now);
        }catch(e){}
    });
}

function setMusicVolume(v){
    musicState.musicVolume=Math.max(0,Math.min(1,v));
    localStorage.setItem('asterian_music_vol',String(musicState.musicVolume));
    if(musicState.masterMusicGain&&audioCtx){
        musicState.masterMusicGain.gain.setValueAtTime(musicState.musicVolume,audioCtx.currentTime);
    }
}

function setSFXVolume(v){
    musicState.sfxVolume=Math.max(0,Math.min(1,v));
    localStorage.setItem('asterian_sfx_vol',String(musicState.sfxVolume));
    if(musicState.masterSFXGain&&audioCtx){
        musicState.masterSFXGain.gain.setValueAtTime(musicState.sfxVolume,audioCtx.currentTime);
    }
}

function toggleMute(){
    musicState.muted=!musicState.muted;
    localStorage.setItem('asterian_muted',String(musicState.muted));
    if(musicState.masterGain&&audioCtx){
        var now=audioCtx.currentTime;
        musicState.masterGain.gain.cancelScheduledValues(now);
        musicState.masterGain.gain.setValueAtTime(musicState.masterGain.gain.value||0.001,now);
        musicState.masterGain.gain.exponentialRampToValueAtTime(musicState.muted?0.001:1,now+0.3);
    }
    // Update UI
    var btn=document.getElementById('btn-audio');
    if(btn){
        btn.textContent=musicState.muted?'🔇':'🔊';
        btn.classList.toggle('muted',musicState.muted);
    }
}

function getSFXDestination(){
    if(musicState.initialized&&musicState.masterSFXGain)return musicState.masterSFXGain;
    return audioCtx?audioCtx.destination:null;
}

// First-interaction music starter (browsers require gesture for audio)
var _musicStarted=false;
function tryStartMusic(){
    if(_musicStarted)return;
    _musicStarted=true;
    ensureAudio();
    if(audioCtx&&audioCtx.state==='suspended')audioCtx.resume();
    initMusicNodes();
    var area=(player&&player.currentArea)?player.currentArea:'station-hub';
    startAreaMusic(area);
    // Update mute button state
    var btn=document.getElementById('btn-audio');
    if(btn){
        btn.textContent=musicState.muted?'🔇':'🔊';
        btn.classList.toggle('muted',musicState.muted);
    }
    document.removeEventListener('click',tryStartMusic);
    document.removeEventListener('touchstart',tryStartMusic);
    document.removeEventListener('keydown',tryStartMusic);
    console.log('[Music] Started for area:',area);
}

// ========================================
// Portal Labels (3D Text Sprites)
// ========================================
function createTextSprite(text,color){
    const canvas=document.createElement('canvas');canvas.width=256;canvas.height=64;
    const ctx=canvas.getContext('2d');
    ctx.font='bold 28px Segoe UI, Consolas, monospace';ctx.textAlign='center';ctx.textBaseline='middle';
    ctx.fillStyle='rgba(0,0,0,0.5)';ctx.fillRect(0,0,256,64);
    ctx.fillStyle=color||'#00c8ff';ctx.fillText(text,128,32);
    ctx.strokeStyle='rgba(0,0,0,0.8)';ctx.lineWidth=2;ctx.strokeText(text,128,32);
    const tex=new THREE.CanvasTexture(canvas);
    const mat=new THREE.SpriteMaterial({map:tex,transparent:true,depthWrite:false});
    const sprite=new THREE.Sprite(mat);sprite.scale.set(6,1.5,1);
    return sprite;
}

// ========================================
// Item Tooltip System
// ========================================
const tooltip=document.getElementById('tooltip');
function showTooltip(x,y,itemDef,extra){
    if(!itemDef)return;
    let html='<div class="tooltip-title" style="color:'+(Tiers[itemDef.tier]?Tiers[itemDef.tier].color:'#00c8ff')+'">'+itemDef.name+'</div>';
    if(itemDef.tier)html+='<div style="font-size:10px;color:#5a7a9a;margin-bottom:3px;">'+(Tiers[itemDef.tier]?Tiers[itemDef.tier].name:'')+' (Tier '+itemDef.tier+')</div>';
    if(itemDef.desc)html+='<div class="tooltip-desc">'+itemDef.desc+'</div>';
    let stats='';
    if(itemDef.damage)stats+='Damage: '+itemDef.damage+'  ';
    if(itemDef.accuracy)stats+='Accuracy: '+itemDef.accuracy+'  ';
    if(itemDef.armor)stats+='Armor: '+itemDef.armor+'  ';
    if(itemDef.heals)stats+='Heals: '+itemDef.heals+' HP  ';
    if(itemDef.style)stats+='Style: '+itemDef.style.charAt(0).toUpperCase()+itemDef.style.slice(1)+'  ';
    if(itemDef.levelReq)stats+='Requires Lv '+itemDef.levelReq;
    if(stats)html+='<div class="tooltip-stats">'+stats.trim()+'</div>';
    if(itemDef.durability!==undefined){
        var durPct=Math.round((itemDef.durability/itemDef.maxDurability)*100);
        var durColor=durPct>50?'#44ff88':durPct>25?'#ffcc44':'#ff4444';
        html+='<div style="font-size:10px;color:'+durColor+';margin-top:3px;">Durability: '+itemDef.durability+'/'+itemDef.maxDurability+' ('+durPct+'%)'+(itemDef.durability<=0?' - BROKEN':'')+'</div>';
    }
    if(itemDef.value)html+='<div style="font-size:10px;color:#ffcc44;margin-top:3px;">Value: '+itemDef.value+' Credits</div>';
    // Equipment comparison
    if(itemDef.slot || itemDef.type==='weapon' || itemDef.type===ItemType.WEAPON || itemDef.type==='armor' || itemDef.type===ItemType.ARMOR){
        var compSlot = itemDef.slot || (itemDef.damage ? 'weapon' : null);
        if(compSlot){
            var equipped = player.equipment[compSlot];
            if(equipped && equipped.id !== itemDef.id){
                html+='<div style="border-top:1px solid #2a4a6a;margin-top:4px;padding-top:4px;font-size:10px;color:#8aa0b8;">vs Equipped: '+equipped.name+'</div>';
                var compStats = [];
                if(itemDef.damage !== undefined || (equipped && equipped.damage)){
                    var diff = (itemDef.damage||0) - (equipped.damage||0);
                    if(diff !== 0) compStats.push('<span style="color:'+(diff>0?'#44ff88':'#ff4444')+'">'+(diff>0?'+':'')+diff+' Damage</span>');
                }
                if(itemDef.accuracy !== undefined || (equipped && equipped.accuracy)){
                    var diff2 = (itemDef.accuracy||0) - (equipped.accuracy||0);
                    if(diff2 !== 0) compStats.push('<span style="color:'+(diff2>0?'#44ff88':'#ff4444')+'">'+(diff2>0?'+':'')+diff2+' Accuracy</span>');
                }
                if(itemDef.armor !== undefined || (equipped && equipped.armor)){
                    var diff3 = (itemDef.armor||0) - (equipped.armor||0);
                    if(diff3 !== 0) compStats.push('<span style="color:'+(diff3>0?'#44ff88':'#ff4444')+'">'+(diff3>0?'+':'')+diff3+' Armor</span>');
                }
                if(compStats.length > 0) html+='<div style="font-size:10px;margin-top:2px;">'+compStats.join(' | ')+'</div>';
                else html+='<div style="font-size:10px;color:#5a7a9a;margin-top:2px;">Same stats</div>';
            } else if(!equipped){
                html+='<div style="font-size:10px;color:#44ff88;margin-top:4px;border-top:1px solid #2a4a6a;padding-top:4px;">No item equipped in this slot</div>';
            }
        }
    }
    if(extra)html+=extra;
    tooltip.className=({1:'rarity-common',2:'rarity-uncommon',3:'rarity-rare',4:'rarity-duranium',5:'rarity-titanex',6:'rarity-epic',7:'rarity-quantum',8:'rarity-neutronium',9:'rarity-darkmatter',10:'rarity-legendary',11:'rarity-ascendant',12:'rarity-corrupted'})[itemDef.tier]||'';
    tooltip.innerHTML=html;tooltip.style.display='block';
    tooltip.style.left=Math.min(x+12,window.innerWidth-260)+'px';
    tooltip.style.top=Math.min(y+12,window.innerHeight-tooltip.offsetHeight-10)+'px';
}
function hideTooltip(){tooltip.style.display='none';}

// ========================================
// Ground Loot System
// ========================================
function spawnGroundItem(position,itemId,quantity){
    const def=getItem(itemId);if(!def)return;
    const mesh=new THREE.Group();
    const glow=new THREE.Mesh(new THREE.CircleGeometry(0.4,8),new THREE.MeshBasicMaterial({color:0xffcc44,transparent:true,opacity:0.3,side:THREE.DoubleSide}));
    glow.rotation.x=-Math.PI/2;glow.position.y=0.05;mesh.add(glow);
    const item=new THREE.Mesh(new THREE.BoxGeometry(0.3,0.3,0.3),new THREE.MeshLambertMaterial({color:Tiers[def.tier]?parseInt(Tiers[def.tier].color.replace('#','0x')):0xcccccc}));
    item.position.y=0.4;item.userData.isLootBob=true;mesh.add(item);
    mesh.position.set(position.x+(Math.random()-0.5)*2,0,position.z+(Math.random()-0.5)*2);
    const groundItem={mesh,itemId,quantity:quantity||1,def,timer:60,position:mesh.position.clone()};
    if(DungeonState.active)groundItem.isDungeonItem=true;
    mesh.userData.entityType='groundItem';mesh.userData.entity=groundItem;
    GameState.scene.add(mesh);GameState.groundItems.push(groundItem);
}
function updateGroundItems(){
    const dt=GameState.deltaTime,pp=player.mesh.position;
    for(let i=GameState.groundItems.length-1;i>=0;i--){
        const gi=GameState.groundItems[i];
        gi.timer-=dt;
        if(gi.timer<=0){GameState.scene.remove(gi.mesh);GameState.groundItems.splice(i,1);continue;}
        gi.mesh.children.forEach(c=>{if(c.userData.isLootBob)c.position.y=0.4+Math.sin(GameState.elapsedTime*3)*0.15;c.rotation.y+=dt*2;});
        if(pp.distanceTo(gi.mesh.position)<2){
            if(addItem(gi.itemId,gi.quantity)){
                EventBus.emit('chat',{type:'loot',text:'Picked up: '+gi.def.name+(gi.quantity>1?' x'+gi.quantity:'')});
                createLootToast(gi.def.name+(gi.quantity>1?' x'+gi.quantity:''),gi.def.icon);
                playSound('buy');
                GameState.scene.remove(gi.mesh);GameState.groundItems.splice(i,1);
            }
        }
    }
}

// ========================================
// Quest System
// ========================================
const QUESTS={
    first_blood:{
        name:'First Blood',
        desc:'Commander Vex wants you to prove yourself. Defeat 5 Chithari in the Alien Wastes.',
        giver:'commander_vex',
        steps:[
            {type:'kill',target:'chithari',count:5,desc:'Defeat Chithari (0/5)'}
        ],
        rewards:{xp:{nano:100,tesla:100,void:100},credits:200,items:['ferrite_nanoblade']},
        followUp:'gear_up'
    },
    gear_up:{
        name:'Gear Up',
        desc:'Mine 5 Stellarite Ore and smelt them into bars at the Bio-Lab.',
        giver:'commander_vex',
        steps:[
            {type:'gather',item:'stellarite_ore',count:5,desc:'Mine Stellarite Ore (0/5)'},
            {type:'craft',recipe:'smelt_scrap',count:3,desc:'Smelt Stellarite Bars (0/3)'}
        ],
        rewards:{xp:{astromining:150,circuitry:150},credits:300,items:['ferrite_helmet']},
        followUp:'deep_cuts'
    },
    deep_cuts:{
        name:'Deep Cuts',
        desc:'Commander Vex needs you to deal with the stronger Chithari and gather chitin for research.',
        giver:'commander_vex',
        steps:[
            {type:'kill',target:'chithari_warrior',count:3,desc:'Defeat Chithari Warriors (0/3)'},
            {type:'gather',item:'chitin_shard',count:5,desc:'Gather Chitin Shards (0/5)'}
        ],
        rewards:{xp:{nano:200,tesla:200},credits:400,items:['ferrite_coilgun']},
        followUp:'lab_rat'
    },
    lab_rat:{
        name:'Lab Rat',
        desc:'Dr. Luma wants you to prove your production skills. Cook lichen wraps and craft scrap vests.',
        giver:'commander_vex',
        steps:[
            {type:'craft',recipe:'cook_lichen_wrap',count:5,desc:'Cook Lichen Wraps (0/5)'},
            {type:'craft',recipe:'craft_scrap_vest',count:2,desc:'Craft Scrap Vests (0/2)'}
        ],
        rewards:{xp:{xenocook:250,bioforge:250},credits:500,items:['cobalt_helmet']},
        followUp:'into_the_wastes'
    },
    into_the_wastes:{
        name:'Into the Wastes',
        desc:'The Alien Wastes are overrun. Destroy the Voidjelly and take down a Sporeclaw.',
        giver:'commander_vex',
        steps:[
            {type:'kill',target:'voidjelly',count:5,desc:'Defeat Voidjelly (0/5)'},
            {type:'kill',target:'sporeclaw',count:1,desc:'Defeat Sporeclaw (0/1)'}
        ],
        rewards:{xp:{void:500},credits:800,items:['cobalt_nanoblade']},
        followUp:null
    },
    psi_discovery:{name:'Psionic Discovery',desc:'Dr. Elara Voss needs Neural Tissue from Neuroworms to study psionic resonance.',giver:'dr_elara_voss',steps:[{type:'gather',item:'neural_tissue',count:3,desc:'Collect Neural Tissue (0/3)'}],rewards:{xp:{void:200},credits:300,items:[]},followUp:'psi_crystal'},
    psi_crystal:{name:'The Psionic Crystal',desc:'Elara needs Darkmatter materials to forge a focusing crystal.',giver:'dr_elara_voss',steps:[{type:'gather',item:'darkmatter_shard',count:5,desc:'Mine Darkmatter Shards (0/5)'},{type:'craft',recipe:'smelt_darkmatter',count:3,desc:'Smelt Darkmatter Bars (0/3)'}],rewards:{xp:{astromining:250,circuitry:250},credits:400,items:[]},followUp:'psi_entity'},
    psi_entity:{name:'Psychic Confrontation',desc:'Clear the deep wastes so Elara can safely conduct the psionic attunement.',giver:'dr_elara_voss',steps:[{type:'kill',target:'neuroworm',count:2,desc:'Defeat Neuroworms (0/2)'},{type:'kill',target:'gravlurk',count:1,desc:'Defeat Gravlurk (0/1)'}],rewards:{xp:{nano:300,tesla:300,void:300},credits:600,items:[]},followUp:'psi_awakening'},
    psi_awakening:{name:'Psionic Awakening',desc:'The final step. Gather Gravity Residue for the attunement ritual.',giver:'dr_elara_voss',steps:[{type:'gather',item:'gravity_residue',count:5,desc:'Collect Gravity Residue (0/5)'}],rewards:{xp:{},credits:1000,items:[]},followUp:null,specialReward:'unlock_psionics'},
};

const questState={vexQuest:null,vexProgress:[],boardQuest:null,boardProgress:[],slayerTask:null,slayerProgress:0,slayerStreak:0,completed:[]};

function startVexQuest(questId){
    const quest=QUESTS[questId];if(!quest)return;
    questState.vexQuest=questId;
    questState.vexProgress=quest.steps.map(()=>0);
    EventBus.emit('chat',{type:'system',text:'Quest started: '+quest.name});
    EventBus.emit('chat',{type:'info',text:quest.desc});
    playSound('quest');
}

function updateQuestProgress(type,data){
    // Vex quest track
    if(questState.vexQuest){
        const quest=QUESTS[questState.vexQuest];
        if(quest){quest.steps.forEach((step,idx)=>{
            if(questState.vexProgress[idx]>=step.count)return;
            if(step.type==='kill'&&type==='kill'&&data.type===step.target){questState.vexProgress[idx]++;checkVexCompletion();}
            if(step.type==='gather'&&type==='gather'&&data.item===step.item){questState.vexProgress[idx]++;checkVexCompletion();}
            if(step.type==='craft'&&type==='craft'&&data.recipe===step.recipe){questState.vexProgress[idx]++;checkVexCompletion();}
        });}
    }
    // Board quest track
    if(questState.boardQuest){
        const bq=BOARD_QUESTS[questState.boardQuest];
        if(bq){bq.steps.forEach((step,idx)=>{
            if(questState.boardProgress[idx]>=step.count)return;
            if(step.type==='kill'&&type==='kill'&&data.type===step.target){questState.boardProgress[idx]++;checkBoardCompletion();}
            if(step.type==='gather'&&type==='gather'&&data.item===step.item){questState.boardProgress[idx]++;checkBoardCompletion();}
            if(step.type==='craft'&&type==='craft'&&data.recipe===step.recipe){questState.boardProgress[idx]++;checkBoardCompletion();}
        });}
    }
    // Slayer task track
    if(questState.slayerTask&&type==='kill'){
        const st=questState.slayerTask;
        if(data.type===st.target&&questState.slayerProgress<st.count){
            questState.slayerProgress++;
            if(questState.slayerProgress>=st.count){
                EventBus.emit('chat',{type:'system',text:'Slayer task complete! Return to Slayer Master Grax for your reward.'});
                playSound('quest');
            }
        }
    }
}

function checkVexCompletion(){
    const quest=QUESTS[questState.vexQuest];if(!quest)return;
    const allDone=quest.steps.every((step,idx)=>questState.vexProgress[idx]>=step.count);
    if(!allDone)return;
    questState.completed.push(questState.vexQuest);
    EventBus.emit('chat',{type:'system',text:'Quest complete: '+quest.name+'!'});
    playSound('quest');
    if(quest.rewards.xp)Object.entries(quest.rewards.xp).forEach(([skill,xp])=>gainXp(skill,xp));
    if(quest.rewards.credits){addCredits(quest.rewards.credits);EventBus.emit('chat',{type:'loot',text:'Reward: '+quest.rewards.credits+' Credits'});}
    if(quest.rewards.items)quest.rewards.items.forEach(id=>{if(addItem(id,1))EventBus.emit('chat',{type:'loot',text:'Reward: '+getItem(id).name});});
    if(quest.specialReward==='unlock_psionics'){
        player.psionicsUnlocked=true;
        player.skills.psionics={level:1,xp:0};
        SKILL_DEFS.psionics.locked=false;
        EventBus.emit('chat',{type:'system',text:'*** PSIONICS UNLOCKED ***'});
        EventBus.emit('chat',{type:'skill',text:'Your mind awakens! The Psionics skill is now available.'});
        triggerLevelUpEffect('psionics',1);
        var pp=player.mesh.position.clone().add(new THREE.Vector3(0,2,0));
        spawnParticles(pp,0xff44ff,80,8,2.5,0.2);
        spawnParticles(pp,0xaa22aa,40,5,2.0,0.15);
        renderSkills();
    }
    const followUp=quest.followUp;
    questState.vexQuest=followUp||null;
    if(followUp){questState.vexProgress=QUESTS[followUp].steps.map(()=>0);EventBus.emit('chat',{type:'system',text:'New quest available: '+QUESTS[followUp].name});}
}

function getVexStatus(){
    if(!questState.vexQuest)return null;
    const quest=QUESTS[questState.vexQuest];if(!quest)return null;
    return{quest,progress:questState.vexProgress,steps:quest.steps.map((s,i)=>{const p=Math.min(questState.vexProgress[i],s.count);return s.desc.replace(/\(.*\)/,'('+p+'/'+s.count+')');})};
}

// ----------------------------------------
// Board Quests
// ----------------------------------------
const BOARD_QUESTS={
    board_pest_control:{name:'Pest Control',desc:'Clear out Chithari pests from the Alien Wastes.',steps:[{type:'kill',target:'chithari',count:5,desc:'Defeat Chithari (0/5)'}],rewards:{xp:{nano:80},credits:150}},
    board_ore_rush:{name:'Ore Rush',desc:'Gather Stellarite Ore for the station supply.',steps:[{type:'gather',item:'stellarite_ore',count:10,desc:'Gather Stellarite Ore (0/10)'}],rewards:{xp:{astromining:120},credits:200}},
    board_warrior_hunt:{name:'Warrior Hunt',desc:'Dangerous warriors and jellyfish need culling.',steps:[{type:'kill',target:'chithari_warrior',count:3,desc:'Defeat Chithari Warriors (0/3)'},{type:'kill',target:'voidjelly',count:2,desc:'Defeat Voidjelly (0/2)'}],rewards:{xp:{tesla:150,void:150},credits:400}},
    board_deep_mining:{name:'Deep Mining',desc:'Mine and smelt Cobaltium for advanced projects.',steps:[{type:'gather',item:'cobaltium_ore',count:5,desc:'Gather Cobaltium Ore (0/5)'},{type:'craft',recipe:'smelt_cobalt',count:3,desc:'Smelt Cobaltium Bars (0/3)'}],rewards:{xp:{astromining:200,circuitry:200},credits:500}},
    board_chef_challenge:{name:"Chef's Challenge",desc:'The station chef needs specialty food prepared.',steps:[{type:'craft',recipe:'cook_nebula_smoothie',count:5,desc:'Blend Nebula Smoothies (0/5)'},{type:'craft',recipe:'cook_alien_burger',count:3,desc:'Grill Alien Burgers (0/3)'}],rewards:{xp:{xenocook:250},credits:450}},
    board_supply_run:{name:'Supply Run',desc:'Deliver processed materials to the station stores.',steps:[{type:'deliver',item:'stellarite_bar',count:10,desc:'Deliver Stellarite Bars (0/10)'},{type:'deliver',item:'lichen_wrap',count:5,desc:'Deliver Lichen Wraps (0/5)'}],rewards:{xp:{circuitry:100},credits:350}},
    board_void_menace:{name:'Void Menace',desc:'Sporeclaws threaten expedition teams. Eliminate them.',steps:[{type:'kill',target:'sporeclaw',count:3,desc:'Defeat Sporeclaw (0/3)'}],rewards:{xp:{void:300},credits:600}},
    board_master_smith:{name:'Master Smith',desc:'Prove your crafting mastery with ferrite equipment.',steps:[{type:'craft',recipe:'craft_ferrite_nanoblade',count:1,desc:'Forge Ferrite Nanoblade (0/1)'},{type:'craft',recipe:'craft_ferrite_vest',count:1,desc:'Forge Ferrite Vest (0/1)'}],rewards:{xp:{circuitry:400},credits:700,items:['ferrite_boots']}},
};

function startBoardQuest(questId){
    if(questState.boardQuest){EventBus.emit('chat',{type:'info',text:'You already have an active board quest!'});return;}
    const quest=BOARD_QUESTS[questId];if(!quest)return;
    questState.boardQuest=questId;
    questState.boardProgress=quest.steps.map(()=>0);
    EventBus.emit('chat',{type:'system',text:'Board quest accepted: '+quest.name});
    EventBus.emit('chat',{type:'info',text:quest.desc});
    playSound('quest');
    closeBoardPanel();
}

function checkBoardCompletion(){
    const bq=BOARD_QUESTS[questState.boardQuest];if(!bq)return;
    const allDone=bq.steps.every((step,idx)=>questState.boardProgress[idx]>=step.count);
    if(!allDone)return;
    questState.completed.push(questState.boardQuest);
    EventBus.emit('chat',{type:'system',text:'Board quest complete: '+bq.name+'!'});
    playSound('quest');
    if(bq.rewards.xp)Object.entries(bq.rewards.xp).forEach(([skill,xp])=>gainXp(skill,xp));
    if(bq.rewards.credits){addCredits(bq.rewards.credits);EventBus.emit('chat',{type:'loot',text:'Reward: '+bq.rewards.credits+' Credits'});}
    if(bq.rewards.items)bq.rewards.items.forEach(id=>{if(addItem(id,1))EventBus.emit('chat',{type:'loot',text:'Reward: '+getItem(id).name});});
    questState.boardQuest=null;
    questState.boardProgress=[];
}

function deliverBoardItems(){
    if(!questState.boardQuest)return;
    const bq=BOARD_QUESTS[questState.boardQuest];if(!bq)return;
    let delivered=false;
    bq.steps.forEach((step,idx)=>{
        if(step.type!=='deliver')return;
        if(questState.boardProgress[idx]>=step.count)return;
        const needed=step.count-questState.boardProgress[idx];
        const have=countItem(step.item);
        const toDeliver=Math.min(needed,have);
        if(toDeliver>0){
            removeItem(step.item,toDeliver);
            questState.boardProgress[idx]+=toDeliver;
            const def=getItem(step.item);
            EventBus.emit('chat',{type:'loot',text:'Delivered '+toDeliver+'x '+def.name});
            delivered=true;
        }
    });
    if(delivered)checkBoardCompletion();
    else EventBus.emit('chat',{type:'info',text:"You don't have the required items to deliver."});
}

function getBoardStatus(){
    if(!questState.boardQuest)return null;
    const bq=BOARD_QUESTS[questState.boardQuest];if(!bq)return null;
    return{quest:bq,progress:questState.boardProgress,steps:bq.steps.map((s,i)=>{const p=Math.min(questState.boardProgress[i],s.count);return s.desc.replace(/\(.*\)/,'('+p+'/'+s.count+')');})};
}

function openBoardPanel(){
    const panel=document.getElementById('board-panel');
    const list=document.getElementById('board-quests-list');
    list.innerHTML='';
    const hasActive=!!questState.boardQuest;
    Object.entries(BOARD_QUESTS).forEach(([id,quest])=>{
        if(questState.completed.includes(id))return;
        const row=document.createElement('div');row.className='board-quest-row';
        if(hasActive&&questState.boardQuest===id)row.classList.add('active');
        const info=document.createElement('div');info.className='board-quest-info';
        const name=document.createElement('div');name.className='board-quest-name';name.textContent=quest.name;
        const desc=document.createElement('div');desc.className='board-quest-desc';desc.textContent=quest.desc;
        const steps=document.createElement('div');steps.className='board-quest-steps';
        quest.steps.forEach((s,i)=>{
            const stepEl=document.createElement('div');stepEl.className='board-quest-step';
            if(hasActive&&questState.boardQuest===id){
                const p=Math.min(questState.boardProgress[i],s.count);
                stepEl.textContent=s.desc.replace(/\(.*\)/,'('+p+'/'+s.count+')');
                if(p>=s.count)stepEl.classList.add('done');
            }else{stepEl.textContent=s.desc;}
            steps.appendChild(stepEl);
        });
        const rewards=document.createElement('div');rewards.className='board-quest-rewards';
        let rText='Rewards: ';
        if(quest.rewards.credits)rText+=quest.rewards.credits+' Credits';
        if(quest.rewards.xp){Object.entries(quest.rewards.xp).forEach(([sk,xp])=>{rText+=', '+xp+' '+sk+' XP';});}
        if(quest.rewards.items){quest.rewards.items.forEach(id2=>{const def=getItem(id2);if(def)rText+=', '+def.name;});}
        rewards.textContent=rText;
        info.appendChild(name);info.appendChild(desc);info.appendChild(steps);info.appendChild(rewards);
        row.appendChild(info);
        if(!hasActive&&!questState.completed.includes(id)){
            const btn=document.createElement('button');btn.className='board-accept-btn';btn.textContent='Accept';
            btn.addEventListener('click',()=>{startBoardQuest(id);});
            row.appendChild(btn);
        }
        list.appendChild(row);
    });
    if(list.children.length===0){list.innerHTML='<div style="padding:15px;color:#5a7a9a;text-align:center;">No quests available.</div>';}
    panel.style.display='flex';
}

function closeBoardPanel(){document.getElementById('board-panel').style.display='none';}

// ----------------------------------------
// Slayer Tasks
// ----------------------------------------
// Dynamic slayer tasks: pick enemies near player's combat level
function getCombatLevel(){
    var n=player.skills.nano.level,t=player.skills.tesla.level,v=player.skills.void.level;
    return Math.floor(((n+t+v)/3+Math.max(n,t,v))/2);
}
function getHighestCombatLevel(){return getCombatLevel();}

function assignSlayerTask(){
    var combatLvl=getHighestCombatLevel();
    // Find non-boss enemies within [combatLvl-10, combatLvl+5]
    var minLvl=Math.max(1,combatLvl-10),maxLvl=combatLvl+5;
    var candidates=[];
    for(var id in ENEMY_TYPES){
        var et=ENEMY_TYPES[id];
        if(et.isCorrupted||et.isBoss)continue;
        if(et.level>=minLvl&&et.level<=maxLvl&&et.area!=='dungeon'){
            candidates.push({id:id,level:et.level,name:et.name});
        }
    }
    if(candidates.length===0){
        // Fallback: any enemy at or below combat level
        for(var id in ENEMY_TYPES){var et=ENEMY_TYPES[id];if(!et.isCorrupted&&!et.isBoss&&et.level<=combatLvl+2&&et.area!=='dungeon'){candidates.push({id:id,level:et.level,name:et.name});}}
    }
    if(candidates.length===0) return null;
    var pick=candidates[Math.floor(Math.random()*candidates.length)];
    // Higher level = fewer kills required
    var minCount=Math.max(1,Math.round(8-pick.level*0.05));
    var maxCount=Math.max(minCount+1,Math.round(15-pick.level*0.08));
    var count=minCount+Math.floor(Math.random()*(maxCount-minCount+1));
    questState.slayerTask={target:pick.id,count:count,level:pick.level};
    questState.slayerProgress=0;
    EventBus.emit('chat',{type:'system',text:'Slayer task: Kill '+count+' '+pick.name});
    playSound('quest');
    return questState.slayerTask;
}

function completeSlayerTask(){
    if(!questState.slayerTask||questState.slayerProgress<questState.slayerTask.count)return;
    const st=questState.slayerTask;
    questState.slayerStreak++;
    const streakMult=Math.min(2.0,1+questState.slayerStreak*0.1);
    const baseCr=st.count*st.level*2;
    const credits=Math.round(baseCr*streakMult);
    const baseXp=st.count*st.level*3;
    const xp=Math.round(baseXp*streakMult);
    addCredits(credits);
    const hStyle=player.combatStyle||'nano';
    gainXp(hStyle,xp);
    EventBus.emit('chat',{type:'loot',text:'Slayer reward: '+credits+' Credits, '+xp+' '+hStyle+' XP'});
    if(questState.slayerStreak>1)EventBus.emit('chat',{type:'info',text:'Streak: '+questState.slayerStreak+' ('+Math.round(streakMult*100)+'% multiplier)'});
    if(questState.slayerStreak%5===0){
        const bonusItems=['ferrite_nanoblade','ferrite_coilgun','ferrite_voidstaff','ferrite_helmet','ferrite_vest','ferrite_legs','cobalt_nanoblade','cobalt_helmet'];
        const bonusItem=bonusItems[Math.floor(Math.random()*bonusItems.length)];
        if(addItem(bonusItem,1)){
            const def=getItem(bonusItem);
            EventBus.emit('chat',{type:'loot',text:'Streak bonus! Received: '+def.name});
        }
    }
    questState.slayerTask=null;
    questState.slayerProgress=0;
    playSound('quest');
}

function cancelSlayerTask(){
    questState.slayerTask=null;
    questState.slayerProgress=0;
    questState.slayerStreak=0;
    EventBus.emit('chat',{type:'info',text:'Slayer task cancelled. Streak reset.'});
}

// Quest tracker removed — replaced by Quest Log panel
function updateQuestTracker(){}

// ========================================
// Quest Log Panel
// ========================================
var questPanelTab='active';
var lastQuestPanelHTML='';
function renderQuestPanel(){
    var content=document.getElementById('quest-panel-content');
    if(!content)return;
    var html='';
    if(questPanelTab==='active'){
        var hasAny=false;
        // Vex quest
        if(questState.vexQuest){
            var vq=QUESTS[questState.vexQuest];
            if(vq){
                hasAny=true;
                html+='<div class="quest-entry">';
                html+='<div class="quest-entry-header"><span class="quest-entry-name">'+vq.name+'</span><span class="quest-entry-badge quest-badge-active">Active</span></div>';
                html+='<div class="quest-entry-desc">'+vq.desc+'</div>';
                html+='<div class="quest-entry-steps">';
                vq.steps.forEach(function(step,i){
                    var prog=questState.vexProgress[i]||0;
                    var done=prog>=step.count;
                    var label=step.desc.replace(/\(.*\)/,('('+Math.min(prog,step.count)+'/'+step.count+')'));
                    html+='<div class="quest-entry-step'+(done?' done':'')+'">'+label+'</div>';
                });
                html+='</div>';
                html+=formatQuestRewards(vq.rewards);
                html+='</div>';
            }
        }
        // Board quest
        if(questState.boardQuest){
            var bq=BOARD_QUESTS[questState.boardQuest];
            if(bq){
                hasAny=true;
                html+='<div class="quest-entry board">';
                html+='<div class="quest-entry-header"><span class="quest-entry-name">'+bq.name+'</span><span class="quest-entry-badge quest-badge-active">Board</span></div>';
                html+='<div class="quest-entry-desc">'+bq.desc+'</div>';
                html+='<div class="quest-entry-steps">';
                bq.steps.forEach(function(step,i){
                    var prog=questState.boardProgress[i]||0;
                    var done=prog>=step.count;
                    var label=step.desc.replace(/\(.*\)/,('('+Math.min(prog,step.count)+'/'+step.count+')'));
                    html+='<div class="quest-entry-step'+(done?' done':'')+'">'+label+'</div>';
                });
                html+='</div>';
                html+=formatQuestRewards(bq.rewards);
                html+='</div>';
            }
        }
        // Slayer task
        if(questState.slayerTask){
            hasAny=true;
            var st=questState.slayerTask;
            var eName=ENEMY_TYPES[st.target]?ENEMY_TYPES[st.target].name:st.target;
            var sDone=questState.slayerProgress>=st.count;
            html+='<div class="quest-entry slayer">';
            html+='<div class="quest-entry-header"><span class="quest-entry-name">Slayer Task</span><span class="quest-entry-badge quest-badge-active">Slayer</span></div>';
            html+='<div class="quest-entry-desc">Eliminate '+st.count+' '+eName+' for Slayer Master Grax.</div>';
            html+='<div class="quest-entry-steps">';
            html+='<div class="quest-entry-step'+(sDone?' done':'')+'">Kill '+eName+' ('+Math.min(questState.slayerProgress,st.count)+'/'+st.count+')</div>';
            html+='</div>';
            if(questState.slayerStreak>0) html+='<div class="quest-entry-rewards"><span style="color:#ff8844;">Streak: '+questState.slayerStreak+'</span></div>';
            html+='</div>';
        }
        if(!hasAny){
            html+='<div class="quest-empty">No active quests.<br><br>Visit <span style="color:#ffcc44;">Commander Vex</span> or the <span style="color:#00c8ff;">Quest Board</span> in Station Hub to get started!</div>';
        }
    } else {
        // Completed tab
        var totalQuests=Object.keys(QUESTS).length+Object.keys(BOARD_QUESTS).length;
        var completedList=questState.completed||[];
        html+='<div class="quest-completed-header">Completed: '+completedList.length+' / '+totalQuests+' quests</div>';
        if(completedList.length===0){
            html+='<div class="quest-empty">No quests completed yet.<br><br>Your completed quests will appear here.</div>';
        } else {
            for(var ci=completedList.length-1;ci>=0;ci--){
                var cid=completedList[ci];
                var cq=QUESTS[cid]||BOARD_QUESTS[cid];
                if(!cq)continue;
                var isBoard=!!BOARD_QUESTS[cid];
                html+='<div class="quest-entry completed-entry'+(isBoard?' board':'')+'">';
                html+='<div class="quest-entry-header"><span class="quest-entry-name">'+cq.name+'</span><span class="quest-entry-badge quest-badge-done">Done</span></div>';
                html+='<div class="quest-entry-desc">'+cq.desc+'</div>';
                html+=formatQuestRewards(cq.rewards);
                html+='</div>';
            }
        }
    }
    if(html!==lastQuestPanelHTML){content.innerHTML=html;lastQuestPanelHTML=html;}
}
function formatQuestRewards(rewards){
    if(!rewards)return '';
    var parts=[];
    if(rewards.xp){
        var xpStrs=[];
        for(var sk in rewards.xp)xpStrs.push(rewards.xp[sk]+' '+sk);
        if(xpStrs.length)parts.push('<span class="quest-reward-xp">XP: '+xpStrs.join(', ')+'</span>');
    }
    if(rewards.credits)parts.push('<span class="quest-reward-credits">'+rewards.credits+' credits</span>');
    if(rewards.items&&rewards.items.length){
        var itemNames=rewards.items.map(function(iid){return ITEMS[iid]?ITEMS[iid].name:iid;});
        parts.push('<span class="quest-reward-item">'+itemNames.join(', ')+'</span>');
    }
    if(!parts.length)return '';
    return '<div class="quest-entry-rewards">Rewards: '+parts.join(' | ')+'</div>';
}
function initQuestPanelTabs(){
    var tabs=document.querySelectorAll('.quest-tab');
    tabs.forEach(function(tab){
        tab.addEventListener('click',function(){
            tabs.forEach(function(t){t.classList.remove('active');});
            tab.classList.add('active');
            questPanelTab=tab.getAttribute('data-tab');
            renderQuestPanel();
        });
    });
}

// ========================================
// QoL Feature Functions
// ========================================

// Feature 5: Quick Bar
function updateQuickBar(){
    for(var qi=0;qi<5;qi++){
        var slot=document.querySelector('.quick-slot[data-slot="'+qi+'"]');
        if(!slot)continue;
        var icon=slot.querySelector('.quick-icon');
        var qs=player.quickSlots[qi];
        if(qs){
            var found=false;
            for(var ii=0;ii<player.inventory.length;ii++){
                if(player.inventory[ii]&&player.inventory[ii].itemId===qs){
                    var qdef=getItem(qs);
                    icon.textContent=qdef?qdef.icon:'';
                    slot.classList.add('has-item');
                    slot.title=qdef?qdef.name+' ('+player.inventory[ii].quantity+')':'';
                    found=true;break;
                }
            }
            if(!found){icon.textContent='';slot.classList.remove('has-item');slot.title='Empty';}
        } else {icon.textContent='';slot.classList.remove('has-item');slot.title='Empty - Right-click food to assign';}
    }
}

function useQuickSlot(slotIdx){
    var itemId=player.quickSlots[slotIdx];
    if(!itemId)return;
    for(var ii=0;ii<player.inventory.length;ii++){
        if(player.inventory[ii]&&player.inventory[ii].itemId===itemId){
            useItem(ii);updateQuickBar();return;
        }
    }
    EventBus.emit('chat',{type:'info',text:'No '+((getItem(itemId)||{}).name||'item')+' in inventory!'});
}

// Feature 6: Bestiary
function openBestiary(){
    var panel=document.getElementById('bestiary-panel');
    var list=document.getElementById('bestiary-list');
    list.innerHTML='';
    var entries=Object.entries(player.bestiary);
    if(entries.length===0){list.innerHTML='<div style="padding:15px;color:#5a7a9a;text-align:center;">No enemies defeated yet.</div>';panel.style.display='flex';return;}
    entries.sort(function(a,b){return b[1].kills-a[1].kills;});
    var totalKills=0;
    entries.forEach(function(entry){
        var type=entry[0],data=entry[1];
        totalKills+=data.kills;
        var row=document.createElement('div');
        row.style.cssText='display:flex;justify-content:space-between;align-items:center;padding:4px 8px;border-bottom:1px solid #1a2a3a;';
        row.innerHTML='<div><span style="color:#ff8844;">'+data.name+'</span> <span style="font-size:10px;color:#5a7a9a;">Lv '+data.level+'</span></div><div style="color:#ffcc44;font-weight:700;">'+data.kills+'</div>';
        list.appendChild(row);
    });
    var header=document.createElement('div');
    header.style.cssText='padding:6px 8px;border-bottom:1px solid #2a4a6a;color:#00c8ff;font-size:11px;';
    header.textContent='Total kills: '+totalKills+' | Species discovered: '+entries.length;
    list.insertBefore(header,list.firstChild);
    panel.style.display='flex';
}

// ========================================
// Prestige UI Panels
// ========================================
function openPrestigePanel(){
    var panel=document.getElementById('prestige-panel');
    if(!panel)return;
    panel.style.display='flex';
    renderPrestigePanel();
}

function renderPrestigePanel(){
    var content=document.getElementById('prestige-content');
    if(!content)return;
    var p=player.prestige;
    var html='<div class="prestige-header">';
    html+='<div class="prestige-tier-badge" style="color:'+((PRESTIGE_PASSIVES[p.tier]||{}).color||'#888')+'">TIER '+p.tier+'</div>';
    html+='<div class="prestige-points">'+p.points+' Points Available</div>';
    html+='</div>';
    html+='<div class="prestige-section-label">Prestige Passives</div>';
    for(var i=1;i<=PRESTIGE_CONFIG.maxTier;i++){
        var pas=PRESTIGE_PASSIVES[i];
        var unlocked=p.tier>=i;
        html+='<div class="prestige-passive-row '+(unlocked?'unlocked':'locked')+'">';
        html+='<span class="prestige-passive-tier" style="color:'+(unlocked?pas.color:'#444')+'">T'+i+'</span>';
        html+='<span class="prestige-passive-name">'+(unlocked?pas.name:'???')+'</span>';
        html+='<span class="prestige-passive-desc">'+(unlocked?pas.desc:'Reach Prestige Tier '+i)+'</span>';
        html+='</div>';
    }
    html+='<div class="prestige-section-label">Corrupted Areas</div>';
    if(p.tier>=5){
        for(var cid in CORRUPTED_AREAS)html+='<div style="padding:3px 8px;color:#ff4444;font-size:11px;">'+CORRUPTED_AREAS[cid].name+' — UNLOCKED</div>';
    } else {
        html+='<div style="padding:3px 8px;color:#555;font-size:11px;">Requires Prestige Tier 5</div>';
    }
    html+='<div class="prestige-section-label">Statistics</div>';
    html+='<div class="prestige-stat">Total Prestiges: '+p.totalPrestiges+'</div>';
    html+='<div class="prestige-stat">Total Levels Gained: '+p.totalLevelsGained+'</div>';
    html+='<div class="prestige-stat">Total Points Earned: '+p.totalPointsEarned+'</div>';
    var fastest=p.fastestPrestigeTime<Infinity?Math.round(p.fastestPrestigeTime/60000)+'m':'N/A';
    html+='<div class="prestige-stat">Fastest Prestige: '+fastest+'</div>';
    html+='<div class="prestige-section-label">Active Bonuses</div>';
    if(p.tier>0){
        html+='<div class="prestige-stat">XP Rate: +'+(p.tier*5)+'%'+(p.xpBoostEnd>Date.now()?' (2x TOKEN ACTIVE)':'')+'</div>';
        html+='<div class="prestige-stat">Damage Bonus: +'+(p.tier*2)+'%</div>';
        html+='<div class="prestige-stat">Damage Reduction: +'+(p.tier*1)+'%</div>';
        if(p.selectedTitle)html+='<div class="prestige-stat">Title: '+p.selectedTitle+'</div>';
    } else {
        html+='<div class="prestige-stat" style="color:#555;">No prestige bonuses yet</div>';
    }
    content.innerHTML=html;
}

function openPrestigeShop(){
    var panel=document.getElementById('prestige-shop-panel');
    if(!panel)return;
    panel.style.display='flex';
    renderPrestigeShop();
}

function renderPrestigeShop(){
    var content=document.getElementById('prestige-shop-content');
    if(!content)return;
    var html='<div style="padding:6px;color:#ffcc44;font-size:12px;text-align:center;">Prestige Points: '+player.prestige.points+'</div>';
    PRESTIGE_SHOP_ITEMS.forEach(function(item){
        var owned=player.prestige.purchasedItems.indexOf(item.id)>=0;
        var canBuy=player.prestige.points>=item.cost&&(!owned||item.repeatable);
        html+='<div class="prestige-shop-item '+(canBuy?'available':'unavailable')+'" data-shopid="'+item.id+'">';
        html+='<div class="prestige-shop-name">'+item.name+'</div>';
        html+='<div class="prestige-shop-cost">'+(owned&&!item.repeatable?'OWNED':item.cost+' pts')+'</div>';
        html+='</div>';
    });
    content.innerHTML=html;
    content.querySelectorAll('.prestige-shop-item.available').forEach(function(el){
        el.addEventListener('click',function(){purchasePrestigeItem(el.dataset.shopid);});
    });
}

function purchasePrestigeItem(itemId){
    var item=PRESTIGE_SHOP_ITEMS.find(function(i){return i.id===itemId;});
    if(!item)return;
    var owned=player.prestige.purchasedItems.indexOf(itemId)>=0;
    if(owned&&!item.repeatable)return;
    if(player.prestige.points<item.cost)return;
    player.prestige.points-=item.cost;
    if(!item.repeatable)player.prestige.purchasedItems.push(itemId);
    switch(item.type){
        case'cosmetic':player.prestige.selectedAura=itemId;EventBus.emit('chat',{type:'system',text:'Aura equipped: '+item.name});break;
        case'bank':player.prestige.extraBankSlots+=item.value;EventBus.emit('chat',{type:'system',text:'+'+item.value+' bank slots!'});break;
        case'credits':player.prestige.extraStartCredits+=item.value;EventBus.emit('chat',{type:'system',text:'Future prestiges start with +'+item.value+' extra credits.'});break;
        case'title':player.prestige.selectedTitle=item.value;EventBus.emit('chat',{type:'system',text:'Title equipped: '+item.value});break;
        case'xp_token':player.prestige.xpBoostEnd=Date.now()+600000;EventBus.emit('chat',{type:'system',text:'2x XP boost active for 10 minutes!'});break;
    }
    playSound('buy');
    renderPrestigeShop();
    renderPrestigePanel();
}

// Feature 7: XP/hr Tracker
function updateXPTracker(){
    var el=document.getElementById('xp-tracker');
    if(!player.xpTracker.active||!el)return;
    var elapsed=(Date.now()-player.xpTracker.startTime)/1000;
    if(elapsed<5){el.style.display='none';return;}
    var html='<div style="color:#00c8ff;font-weight:700;margin-bottom:3px;">XP/hr</div>';
    var hasData=false;
    Object.entries(player.xpTracker.xpGains).forEach(function(entry){
        var skill=entry[0],xp=entry[1];
        var xpPerHr=Math.round(xp/(elapsed/3600));
        if(xpPerHr<10)return;
        var def=SKILL_DEFS[skill];
        html+='<div><span class="xp-skill">'+(def?def.icon:'')+' '+(def?def.name:skill)+'</span>: <span class="xp-rate">'+xpPerHr.toLocaleString()+'</span></div>';
        hasData=true;
    });
    if(!hasData){el.style.display='none';return;}
    var mins=Math.floor(elapsed/60),secs=Math.floor(elapsed%60);
    html+='<div style="margin-top:3px;color:#5a7a9a;font-size:9px;">Session: '+mins+'m '+secs+'s</div>';
    el.innerHTML=html;el.style.display='block';
}

// Feature 9: Bank Search
function filterBankItems(){
    var query=(document.getElementById('bank-search').value||'').toLowerCase();
    var slots=document.getElementById('bank-grid').querySelectorAll('.inv-slot');
    slots.forEach(function(slot){
        if(!query){slot.style.display='';return;}
        var name=slot.dataset.itemName||'';
        slot.style.display=name.includes(query)?'':'none';
    });
}

// Feature 10: Idle Notification
var idleNotifyTimer=0;var idleNotifyActive=false;var originalTitle='Asterian';
function checkIdleNotification(){
    if(document.hidden){
        if(!player.inCombat&&!player.isGathering&&!idleNotifyActive){
            idleNotifyActive=true;idleNotifyTimer=0;
        }
    } else {
        if(idleNotifyActive){idleNotifyActive=false;document.title=originalTitle;}
    }
    if(idleNotifyActive){
        idleNotifyTimer+=GameState.deltaTime;
        if(idleNotifyTimer%1<0.05)document.title=document.title===originalTitle?'Idle - Asterian':originalTitle;
    }
}

// Feature 12: Bank Stack All
function stackAllBank(){
    var changed=false;
    for(var i=0;i<bankStorage.length;i++){
        if(!bankStorage[i])continue;
        for(var j=i+1;j<bankStorage.length;j++){
            if(!bankStorage[j])continue;
            if(bankStorage[i].itemId===bankStorage[j].itemId){
                bankStorage[i].quantity+=bankStorage[j].quantity;
                bankStorage[j]=null;changed=true;
            }
        }
    }
    // Compact: move all nulls to end
    var compacted=bankStorage.filter(function(s){return s!==null;});
    while(compacted.length<48)compacted.push(null);
    for(var k=0;k<48;k++)bankStorage[k]=compacted[k];
    if(changed){EventBus.emit('chat',{type:'info',text:'Bank stacks consolidated.'});renderBank();}
    else{EventBus.emit('chat',{type:'info',text:'Nothing to stack.'});}
}

// Feature 14: World Map
var worldMapZoom=0.8,worldMapPanX=0,worldMapPanZ=0,worldMapDragging=false,worldMapDragStartX=0,worldMapDragStartY=0,worldMapPanStartX=0,worldMapPanStartZ=0;
var worldMapInitialized=false;

function toggleWorldMap(){
    var panel=document.getElementById('world-map-panel');
    if(panel.style.display!=='none'){panel.style.display='none';return;}
    panel.style.display='flex';
    if(!worldMapInitialized)initWorldMapControls();
    renderWorldMap();
}

function initWorldMapControls(){
    worldMapInitialized=true;
    var canvas=document.getElementById('world-map-canvas');
    if(!canvas)return;
    var panel=document.getElementById('world-map-panel');
    // Auto-resize canvas to fill panel when panel is resized
    function fitCanvasToPanel(){
        if(!panel||panel.style.display==='none')return;
        var header=panel.querySelector('.panel-header');
        var headerH=header?header.offsetHeight:30;
        var pw=panel.clientWidth-2,ph=panel.clientHeight-headerH-2;
        if(pw>100&&ph>80&&(canvas.width!==pw||canvas.height!==ph)){
            canvas.width=Math.round(pw);canvas.height=Math.round(ph);
            canvas.style.width=pw+'px';canvas.style.height=ph+'px';
        }
    }
    if(typeof ResizeObserver!=='undefined'){
        new ResizeObserver(fitCanvasToPanel).observe(panel);
    }
    fitCanvasToPanel();
    // Zoom with scroll wheel
    canvas.addEventListener('wheel',function(e){
        e.preventDefault();
        var delta=e.deltaY>0?-0.1:0.1;
        worldMapZoom=Math.max(0.15,Math.min(3.0,worldMapZoom+delta));
    },{passive:false});
    // Pan with click-drag on the map canvas
    canvas.addEventListener('mousedown',function(e){
        if(e.button===0){worldMapDragging=true;worldMapDragStartX=e.clientX;worldMapDragStartY=e.clientY;worldMapPanStartX=worldMapPanX;worldMapPanStartZ=worldMapPanZ;e.preventDefault();}
    });
    window.addEventListener('mousemove',function(e){
        if(!worldMapDragging)return;
        var dx=e.clientX-worldMapDragStartX,dy=e.clientY-worldMapDragStartY;
        worldMapPanX=worldMapPanStartX+dx;worldMapPanZ=worldMapPanStartZ+dy;
    });
    window.addEventListener('mouseup',function(e){if(e.button===0)worldMapDragging=false;});
    // Right-click to set waypoint on world map
    canvas.addEventListener('contextmenu',function(e){
        e.preventDefault();
        var rect=canvas.getBoundingClientRect();
        var mx=e.clientX-rect.left,my=e.clientY-rect.top;
        var mapCX=canvas.width/2+worldMapPanX,mapCY=canvas.height/2+worldMapPanZ;
        var worldX=(mx-mapCX)/worldMapZoom,worldZ=(my-mapCY)/worldMapZoom;
        player.waypoint={x:worldX,z:worldZ};
        EventBus.emit('chat',{type:'info',text:'Waypoint set from world map.'});
    });
    // Double-click to reset pan/zoom
    canvas.addEventListener('dblclick',function(e){
        worldMapPanX=0;worldMapPanZ=0;worldMapZoom=0.8;
    });
}

function renderWorldMap(){
    var canvas=document.getElementById('world-map-canvas');
    if(!canvas)return;
    var ctx=canvas.getContext('2d');
    var w=canvas.width,h=canvas.height;
    ctx.fillStyle='#080c14';ctx.fillRect(0,0,w,h);
    var mapCX=w/2+worldMapPanX,mapCY=h/2+worldMapPanZ,mapSc=worldMapZoom;
    // Draw corridors with animated dashes
    var animT=performance.now()*0.001;
    CORRIDORS.forEach(function(c){
        var fromArea=AREAS[c.from],toArea=AREAS[c.to];
        if(!fromArea||!toArea)return;
        var fx=mapCX+fromArea.center.x*mapSc,fz=mapCY+fromArea.center.z*mapSc;
        var tx=mapCX+toArea.center.x*mapSc,tz=mapCY+toArea.center.z*mapSc;
        // Background corridor fill (dimmer)
        ctx.fillStyle='rgba(40,60,80,0.3)';
        var rx1=mapCX+c.minX*mapSc,rz1=mapCY+c.minZ*mapSc;
        var rx2=mapCX+c.maxX*mapSc,rz2=mapCY+c.maxZ*mapSc;
        ctx.fillRect(Math.min(rx1,rx2),Math.min(rz1,rz2),Math.abs(rx2-rx1),Math.abs(rz2-rz1));
        // Animated dashed center-line
        ctx.save();
        ctx.strokeStyle='rgba(100,180,255,0.5)';
        ctx.lineWidth=Math.max(1,2*mapSc);
        ctx.setLineDash([8,6]);
        ctx.lineDashOffset=-animT*30;
        ctx.beginPath();ctx.moveTo(fx,fz);ctx.lineTo(tx,tz);ctx.stroke();
        ctx.setLineDash([]);
        ctx.restore();
    });
    // Draw areas
    var areaColors={'station-hub':'rgba(30,50,80,0.4)','asteroid-mines':'rgba(80,50,20,0.4)','alien-wastes':'rgba(20,60,30,0.4)','bio-lab':'rgba(20,60,60,0.4)','the-abyss':'rgba(10,5,40,0.4)'};
    Object.entries(AREAS).forEach(function(entry){
        var areaId=entry[0],area=entry[1];
        var ax=mapCX+area.center.x*mapSc,az=mapCY+area.center.z*mapSc;
        var ar=area.radius*mapSc;
        ctx.fillStyle=areaColors[areaId]||'rgba(40,40,40,0.4)';
        ctx.beginPath();ctx.arc(ax,az,ar,0,Math.PI*2);ctx.fill();
        ctx.strokeStyle='rgba(100,140,180,0.3)';ctx.lineWidth=1;ctx.stroke();
        var fontSize=Math.max(8,Math.min(14,Math.round(12*mapSc)));
        ctx.fillStyle='#8aa0b8';ctx.font='bold '+fontSize+'px monospace';ctx.textAlign='center';
        ctx.fillText(area.name,ax,az-ar+fontSize+2);
        // Level range label
        var lr=AREA_LEVEL_RANGES[areaId];
        if(lr){
            var pLvl=player.combatLevel||1;
            var lrColor=lr.min===0?'#66ddaa':pLvl>=lr.min?'#88ccff':'#ff6666';
            ctx.fillStyle=lrColor;
            ctx.font=Math.max(7,Math.min(10,Math.round(9*mapSc)))+'px monospace';
            ctx.fillText(lr.label,ax,az-ar+fontSize+14);
        }
    });
    // Draw corrupted areas (if built)
    if(corruptedAreaBuilt){
        Object.entries(CORRUPTED_AREAS).forEach(function(entry){
            var cid=entry[0],ca=entry[1];
            var cax=mapCX+ca.center.x*mapSc,caz=mapCY+ca.center.z*mapSc;
            var car=ca.radius*mapSc;
            ctx.fillStyle='rgba(80,10,10,0.35)';ctx.beginPath();ctx.arc(cax,caz,car,0,Math.PI*2);ctx.fill();
            ctx.strokeStyle='rgba(255,34,68,0.3)';ctx.lineWidth=1;ctx.stroke();
            ctx.fillStyle='#cc4466';ctx.font='9px monospace';ctx.textAlign='center';ctx.fillText(ca.name,cax,caz+3);
            var clr=AREA_LEVEL_RANGES[cid];
            if(clr){
                ctx.fillStyle=(player.combatLevel||1)>=clr.min?'#ff8888':'#ff4444';
                ctx.font='7px monospace';
                ctx.fillText(clr.label,cax,caz+12);
            }
        });
    }
    // Draw resource nodes
    if(GameState.resourceNodes){
        GameState.resourceNodes.forEach(function(n){
            if(n.depleted)return;
            var nx=mapCX+n.position.x*mapSc,nz=mapCY+n.position.z*mapSc;
            if(nx<-10||nx>w+10||nz<-10||nz>h+10)return;
            ctx.fillStyle='#44ffaa';ctx.beginPath();ctx.arc(nx,nz,Math.max(2,3*mapSc),0,Math.PI*2);ctx.fill();
        });
    }
    // Draw enemies (realtime positions)
    GameState.enemies.forEach(function(e){
        if(!e.alive)return;
        var ex=mapCX+e.mesh.position.x*mapSc,ez=mapCY+e.mesh.position.z*mapSc;
        if(ex<-10||ex>w+10||ez<-10||ez>h+10)return;
        ctx.fillStyle=e.isCorrupted?'#ff2244':(e.isBoss?'#ff4488':'#ff4444');
        ctx.globalAlpha=0.7;
        ctx.beginPath();ctx.moveTo(ex,ez-3);ctx.lineTo(ex-2.5,ez+2);ctx.lineTo(ex+2.5,ez+2);ctx.closePath();ctx.fill();
        ctx.globalAlpha=1.0;
    });
    // Draw NPCs
    if(GameState.npcs){
        GameState.npcs.forEach(function(n){
            var nx=mapCX+n.position.x*mapSc,nz=mapCY+n.position.z*mapSc;
            if(nx<-10||nx>w+10||nz<-10||nz>h+10)return;
            ctx.fillStyle='#ffcc00';ctx.save();ctx.translate(nx,nz);ctx.rotate(Math.PI/4);ctx.fillRect(-4,-4,8,8);ctx.restore();
            ctx.fillStyle='#ffcc00';ctx.font='9px monospace';ctx.textAlign='center';ctx.fillText(n.def?n.def.name:'NPC',nx,nz+12);
        });
    }
    // Draw processing stations
    PROCESSING_STATIONS.forEach(function(ps){
        var sx=mapCX+ps.position.x*mapSc,sz=mapCY+ps.position.z*mapSc;
        if(sx<-10||sx>w+10||sz<-10||sz>h+10)return;
        ctx.fillStyle='#ff8844';ctx.beginPath();ctx.arc(sx,sz,4,0,Math.PI*2);ctx.fill();
        ctx.fillStyle='#ff8844';ctx.font='8px monospace';ctx.textAlign='center';ctx.fillText(ps.icon,sx,sz-6);
    });
    // Draw dungeon entrance
    if(world.dungeonEntrance){
        var dx=mapCX+world.dungeonEntrance.position.x*mapSc,dz=mapCY+world.dungeonEntrance.position.z*mapSc;
        ctx.fillStyle='#aa44ff';ctx.beginPath();ctx.arc(dx,dz,5,0,Math.PI*2);ctx.fill();
        ctx.fillStyle='#aa44ff';ctx.font='9px monospace';ctx.textAlign='center';ctx.fillText('Dungeon',dx,dz+12);
    }
    // Draw player (realtime)
    var ppx=mapCX+player.mesh.position.x*mapSc,ppz=mapCY+player.mesh.position.z*mapSc;
    ctx.fillStyle='#ffffff';ctx.beginPath();ctx.arc(ppx,ppz,5,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle='#00c8ff';ctx.lineWidth=2;ctx.stroke();
    ctx.fillStyle='#ffffff';ctx.font='bold 10px monospace';ctx.textAlign='center';ctx.fillText('YOU',ppx,ppz+14);
    // Draw remote players (multiplayer)
    if(window.AsterianMP&&window.AsterianMP.getRemotePlayers){
        var rp=window.AsterianMP.getRemotePlayers();
        var rpStyleColors={nano:'#22ee66',tesla:'#44aaff','void':'#aa66ff'};
        Object.keys(rp).forEach(function(rid){
            var r=rp[rid];
            if(!r||r.currentX===undefined)return;
            var rx=mapCX+r.currentX*mapSc,rz=mapCY+r.currentZ*mapSc;
            if(rx<-10||rx>w+10||rz<-10||rz>h+10)return;
            var sty=(r.stats&&r.stats.combatStyle)||'nano';
            ctx.fillStyle=rpStyleColors[sty]||'#44aaff';
            ctx.globalAlpha=0.8;
            ctx.beginPath();ctx.arc(rx,rz,3,0,Math.PI*2);ctx.fill();
            ctx.globalAlpha=1.0;
            if(r.name&&mapSc>0.3){
                ctx.fillStyle='#aaccee';ctx.font='7px monospace';ctx.textAlign='center';
                ctx.fillText(r.name,rx,rz+10);
            }
        });
    }
    // Draw waypoint
    if(player.waypoint){
        var wpx2=mapCX+player.waypoint.x*mapSc,wpz2=mapCY+player.waypoint.z*mapSc;
        ctx.fillStyle='#ff44ff';ctx.beginPath();ctx.moveTo(wpx2,wpz2-8);ctx.lineTo(wpx2-5,wpz2);ctx.lineTo(wpx2,wpz2-3);ctx.lineTo(wpx2+5,wpz2);ctx.closePath();ctx.fill();
        ctx.fillStyle='#ff88ff';ctx.font='8px monospace';ctx.textAlign='center';
        var wpDist2=Math.round(Math.sqrt(Math.pow(player.waypoint.x-player.mesh.position.x,2)+Math.pow(player.waypoint.z-player.mesh.position.z,2)));
        ctx.fillText(wpDist2+'m',wpx2+10,wpz2-2);
    }
    // Legend
    ctx.textAlign='left';ctx.font='9px monospace';
    var ly=h-98;
    ctx.fillStyle='#44ffaa';ctx.fillRect(10,ly,8,8);ctx.fillStyle='#8aa0b8';ctx.fillText('Resources',22,ly+7);ly+=14;
    ctx.fillStyle='#ffcc00';ctx.fillRect(10,ly,8,8);ctx.fillStyle='#8aa0b8';ctx.fillText('NPCs',22,ly+7);ly+=14;
    ctx.fillStyle='#ff8844';ctx.fillRect(10,ly,8,8);ctx.fillStyle='#8aa0b8';ctx.fillText('Stations',22,ly+7);ly+=14;
    ctx.fillStyle='#ff4444';ctx.fillRect(10,ly,8,8);ctx.fillStyle='#8aa0b8';ctx.fillText('Enemies',22,ly+7);ly+=14;
    ctx.fillStyle='#aa44ff';ctx.fillRect(10,ly,8,8);ctx.fillStyle='#8aa0b8';ctx.fillText('Dungeon',22,ly+7);ly+=14;
    ctx.fillStyle='#ffffff';ctx.fillRect(10,ly,8,8);ctx.fillStyle='#8aa0b8';ctx.fillText('Player',22,ly+7);ly+=14;
    ctx.fillStyle='#44aaff';ctx.fillRect(10,ly,8,8);ctx.fillStyle='#8aa0b8';ctx.fillText('Players (MP)',22,ly+7);
    // Controls hint
    ctx.fillStyle='rgba(255,255,255,0.3)';ctx.font='8px monospace';ctx.textAlign='right';
    ctx.fillText('Scroll: Zoom | Drag: Pan | DblClick: Reset | RClick: Waypoint',w-8,h-6);
    // Zoom indicator
    ctx.fillText(worldMapZoom.toFixed(1)+'x',w-8,12);
}

// ========================================
// Game Init & Loop
// ========================================
let minimapTimer=0;
var minimapZoom=1.0; // 1.0 = default, higher = zoomed in, range 0.3-4.0

function initRenderer(){
    const canvas=document.getElementById('game-canvas');
    const renderer=new THREE.WebGLRenderer({canvas,antialias:true});
    renderer.setSize(window.innerWidth,window.innerHeight);renderer.setPixelRatio(Math.min(window.devicePixelRatio,2));
    renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
    renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;
    GameState.renderer=renderer;
    const scene=new THREE.Scene();scene.background=null;scene.fog=new THREE.FogExp2(0x020810,0.004);GameState.scene=scene;
    const camera=new THREE.PerspectiveCamera(50,window.innerWidth/window.innerHeight,0.1,1000);camera.position.set(0,25,30);camera.lookAt(0,0,0);GameState.camera=camera;
    GameState.clock=new THREE.Clock();
    GameState.ambientLight=new THREE.AmbientLight(0x1a2a4a,0.4);scene.add(GameState.ambientLight);
    // Hemisphere light for sky/ground color contrast
    var hemiLight=new THREE.HemisphereLight(0x2244aa,0x111122,0.35);scene.add(hemiLight);
    const dl=new THREE.DirectionalLight(0xaaccff,0.8);dl.position.set(30,50,20);dl.castShadow=true;dl.shadow.mapSize.width=2048;dl.shadow.mapSize.height=2048;dl.shadow.camera.near=0.5;dl.shadow.camera.far=200;dl.shadow.camera.left=-60;dl.shadow.camera.right=60;dl.shadow.camera.top=60;dl.shadow.camera.bottom=-60;scene.add(dl);GameState.dirLight=dl;
    // Rim/back light for silhouette definition
    var rimLight=new THREE.DirectionalLight(0x4488cc,0.3);rimLight.position.set(-20,30,-30);scene.add(rimLight);
    const pl2=new THREE.PointLight(0x00c8ff,0.4,80);pl2.position.set(0,10,0);scene.add(pl2);
    window.addEventListener('resize',()=>{camera.aspect=window.innerWidth/window.innerHeight;camera.updateProjectionMatrix();renderer.setSize(window.innerWidth,window.innerHeight);});
}

function initGame(){
    // World
    initWorld();
    // Shop economy
    initShopEconomy();
    // Player
    player.mesh=buildPlayerMesh();player.mesh.position.set(0,0,5);GameState.scene.add(player.mesh);GameState.player=player;
    // Starter gear: equip weapon + helmet, food in inventory
    var starterWeapon=Object.assign({},getItem('scrap_nanoblade'));
    var wDur=initDurability(starterWeapon);starterWeapon.durability=wDur.durability;starterWeapon.maxDurability=wDur.maxDurability;
    player.equipment.weapon=starterWeapon;
    var starterHelmet=Object.assign({},getItem('scrap_helmet'));
    var hDur=initDurability(starterHelmet);starterHelmet.durability=hDur.durability;starterHelmet.maxDurability=hDur.maxDurability;
    player.equipment.head=starterHelmet;
    player.inventory[0]={itemId:'lichen_wrap',quantity:20};
    player.inventory[1]={itemId:'mining_laser',quantity:1};
    var coilDur=initDurability(getItem('scrap_coilgun'));
    player.inventory[2]={itemId:'scrap_coilgun',quantity:1,durability:coilDur.durability,maxDurability:coilDur.maxDurability};
    var voidDur=initDurability(getItem('scrap_voidstaff'));
    player.inventory[3]={itemId:'scrap_voidstaff',quantity:1,durability:voidDur.durability,maxDurability:voidDur.maxDurability};
    recalcStats();updateMeshColors();
    // Input
    initInput();
    // Enemies & NPCs
    spawnEnemies();spawnNPCs();
    // UI
    setupPanelButtons();setupPanelDragging();setupPanelResizing();setupMinimapResize();setupChatResize();setupPanelLocks();setupUIEvents();updateActionBar();initStyleHUD();initSkillTabs();initQuestPanelTabs();
    setAreaAtmosphere('station-hub');
    // Event wiring
    EventBus.on('leftClick',hit=>{
        if(hit.type==='ground'){moveTo(hit.point);player.combatTarget=null;player.inCombat=false;}
        if(hit.type==='enemy'&&hit.entity&&hit.entity.alive)attackTarget(hit.entity);
        if(hit.type==='resource'&&hit.entity)startGathering(hit.entity);
        if(hit.type==='npc'&&hit.entity){const npc=hit.entity;if(player.mesh.position.distanceTo(npc.position)>5){moveTo(npc.position);player.pendingNPC=npc;}else openDialogue(npc);}
        if(hit.type==='processingStation'&&hit.entity){
            const station=hit.entity;
            const stPos=new THREE.Vector3(station.position.x,0,station.position.z);
            const pDist=player.mesh.position.distanceTo(stPos);
            if(pDist<=station.interactRadius){if(station.skill==='repair')openRepairStation();else openCrafting(station.skill);}
            else{moveTo(stPos);player.pendingStation=station;}
        }
        if(hit.type==='questBoard'){const boardPos=new THREE.Vector3(0,0,18);if(player.mesh.position.distanceTo(boardPos)>5){moveTo(boardPos);player.pendingBoard=true;}else openBoardPanel();}
        if(hit.type==='dungeonEntrance'){var gatePos=new THREE.Vector3(0,0,-18);if(player.mesh.position.distanceTo(gatePos)>5){moveTo(gatePos);player.pendingDungeon=true;}else{enterDungeon();}}
        if(hit.type==='corruptedPortal'&&hit.entity){
            if(!hasPrestigePassive(5)){EventBus.emit('chat',{type:'info',text:'You need Prestige Tier 5 to enter corrupted areas.'});return;}
            var cpca=hit.entity.targetArea;
            player.mesh.position.set(cpca.center.x,0,cpca.center.z);
            player.isMoving=false;player.moveTarget=null;
            EventBus.emit('chat',{type:'system',text:'You step through the corrupted portal into '+cpca.name+'...'});
        }
    });
    EventBus.on('rightClick',({hit,screenX,screenY})=>{
        if(hit.type==='ground'&&hit.point){showContextMenu(screenX,screenY,[{label:'Walk here',action:()=>{moveTo(hit.point);player.combatTarget=null;player.inCombat=false;}},{label:'Cancel',action:()=>{}}]);}
        if(hit.type==='enemy'&&hit.entity){const e=hit.entity;var opts=[{label:'Attack '+e.name,action:()=>attackTarget(e)},{label:'Examine',action:()=>EventBus.emit('chat',{type:'info',text:e.name+' - Lv '+e.level+' ('+e.combatStyle+'). '+e.desc})}];
    // Psionics: TK Push
    if(player.psionicsUnlocked&&player.skills.psionics&&player.skills.psionics.level>=5&&player.psionicCooldowns.tkPush<=0){
        if(player.mesh.position.distanceTo(e.mesh.position)<=12){
            opts.push({label:'\uD83E\uDDE0 TK Push',action:function(){performTKPush(e);}});
        }
    }
    // Psionics: Mind Control
    if(player.psionicsUnlocked&&player.skills.psionics&&player.skills.psionics.level>=20&&player.psionicCooldowns.mindControl<=0&&!player.mindControlTarget){
        var mcThreshold=(player.skills.psionics.level*5)*(1+getSkillBonus('psionics','mindControlThreshold'));
        if(hasSkillMilestone('psionics','psionicAscendancy'))mcThreshold*=2;
        if(e.hp<mcThreshold&&e.alive){
            opts.push({label:'\uD83E\uDDE0 Mind Control',action:function(){performMindControl(e);}});
        }
    }
    // Chronomancy: Time Dilate
    if(player.skills.chronomancy&&player.skills.chronomancy.level>=40&&player.psionicCooldowns.timeDilate<=0){
        opts.push({label:'\u23F3 Time Dilate',action:function(){performTimeDilate();}});
    }
    showContextMenu(screenX,screenY,opts);}
        if(hit.type==='resource'&&hit.entity){const n=hit.entity,def=getItem(n.resource);showContextMenu(screenX,screenY,[{label:'Mine '+def.name,action:()=>startGathering(n)},{label:'Examine',action:()=>EventBus.emit('chat',{type:'info',text:def.name+' - Level '+n.level+' node.'})}]);}
        if(hit.type==='npc'&&hit.entity){const npc=hit.entity;const npcDist=player.mesh.position.distanceTo(npc.position);const opts=[{label:'Talk to '+npc.def.name,action:()=>{if(npcDist>5){moveTo(npc.position);player.pendingNPC=npc;}else openDialogue(npc);}}];if(npc.def.shop)opts.push({label:'Trade',action:()=>{if(npcDist>5){moveTo(npc.position);player.pendingNPC=npc;EventBus.emit('chat',{type:'info',text:'You walk toward '+npc.def.name+'.'});}else openShop(npc);}});if(npc.id==='zik_trader')opts.push({label:'Use Bank',action:()=>{if(npcDist>5){moveTo(npc.position);player.pendingNPC=npc;EventBus.emit('chat',{type:'info',text:'You walk toward '+npc.def.name+'.'});}else openBank();}});opts.push({label:'Examine',action:()=>EventBus.emit('chat',{type:'info',text:npc.def.name+': '+npc.def.desc})});showContextMenu(screenX,screenY,opts);}
        if(hit.type==='processingStation'&&hit.entity){const st=hit.entity;showContextMenu(screenX,screenY,[{label:'Use '+st.name,action:()=>{const stPos=new THREE.Vector3(st.position.x,0,st.position.z);if(player.mesh.position.distanceTo(stPos)<=st.interactRadius){if(st.skill==='repair')openRepairStation();else openCrafting(st.skill);}else{moveTo(stPos);player.pendingStation=st;}}},{label:'Examine',action:()=>EventBus.emit('chat',{type:'info',text:st.name+': Used for '+(st.skill==='repair'?'repairing equipment':(SKILL_DEFS[st.skill]?SKILL_DEFS[st.skill].name:'')+ ' crafting')+'.'})}]);}
        if(hit.type==='questBoard'){
            const boardPos=new THREE.Vector3(0,0,18);
            const dist=player.mesh.position.distanceTo(boardPos);
            showContextMenu(screenX,screenY,[
                {label:'View Quests',action:()=>{if(dist>5){moveTo(boardPos);player.pendingBoard=true;}else openBoardPanel();}},
                {label:'Deliver Items',action:()=>{if(dist>5){moveTo(boardPos);player.pendingDelivery=true;}else deliverBoardItems();}},
                {label:'Examine',action:()=>EventBus.emit('chat',{type:'info',text:'A wooden board covered with quest postings. Right-click to browse available quests.'})}
            ]);
        }
        if(hit.type==='dungeonEntrance'){
            var dgPos=new THREE.Vector3(0,0,-18);
            var dgOpts=[
                {label:'Enter Dungeon',action:()=>{if(player.mesh.position.distanceTo(dgPos)>5){moveTo(dgPos);player.pendingDungeon=true;}else enterDungeon();}},
                {label:'Examine',action:()=>EventBus.emit('chat',{type:'info',text:'Abyssal Depths - A swirling void portal leading to an endless procedural dungeon. Deeper floors = better loot. Death resets progress.'})}
            ];
            if(player.skills.chronomancy&&player.skills.chronomancy.level>=99){
                dgOpts.splice(1,0,{label:'\u23F3 Temporal Rift',action:function(){
                    var dgPos2=new THREE.Vector3(0,0,-18);
                    if(player.mesh.position.distanceTo(dgPos2)>5){moveTo(dgPos2);player.pendingTimeLoop=true;}
                    else enterTimeLoopDungeon();
                }});
            }
            showContextMenu(screenX,screenY,dgOpts);
        }
        if(hit.type==='corruptedPortal'&&hit.entity){
            var cpEnt=hit.entity;
            showContextMenu(screenX,screenY,[
                {label:'Enter '+cpEnt.name,action:function(){
                    if(!hasPrestigePassive(5)){EventBus.emit('chat',{type:'info',text:'You need Prestige Tier 5 to enter corrupted areas.'});return;}
                    var ca=cpEnt.targetArea;
                    player.mesh.position.set(ca.center.x,0,ca.center.z);
                    player.isMoving=false;player.moveTarget=null;
                    EventBus.emit('chat',{type:'system',text:'You step through the corrupted portal into '+ca.name+'...'});
                }},
                {label:'Examine',action:function(){EventBus.emit('chat',{type:'info',text:'A portal radiating corrupted energy. Enemies inside are far more dangerous, but offer greater rewards.'});}},
            ]);
            return;
        }
    });
    // Action bar removed - OSRS style auto-attack only, no ability keys
    EventBus.on('tabTarget',()=>{const pos=player.mesh.position;let closest=null,cd=20;GameState.enemies.forEach(e=>{if(!e.alive||e===player.combatTarget)return;const d=pos.distanceTo(e.mesh.position);if(d<cd){cd=d;closest=e;}});if(closest)attackTarget(closest);});
    EventBus.on('eatFood',eatBestFood);
    // Save button
    const saveBtn=document.getElementById('btn-save');
    if(saveBtn)saveBtn.addEventListener('click',()=>{saveGame();EventBus.emit('chat',{type:'system',text:'Game saved!'});createLootToast('Game Saved!','💾');});
    // Dungeon exit button
    var dungExitBtn=document.getElementById('dungeon-exit-btn');
    if(dungExitBtn)dungExitBtn.addEventListener('click',function(){if(DungeonState.active){if(confirm('Exit dungeon? You will lose floor progress.')){exitDungeon();}}});
}

// ========================================
// Combat Style HUD (quick switch above action bar)
// ========================================
function initStyleHUD(){}
function updateStyleHUD(){}

// ========================================
// Area Transition Effect
// ========================================
function triggerAreaTransition(areaName){
    const overlay=document.getElementById('area-transition');
    const nameEl=overlay.querySelector('.area-name-flash');
    nameEl.textContent=areaName;
    overlay.classList.add('active');
    setTimeout(()=>overlay.classList.remove('active'),800);
}

// ========================================
// Ambient World Particles
// ========================================
function updatePortalAnimations(){
    var t=GameState.elapsedTime;
    if(world.dungeonPortalPlane){
        world.dungeonPortalPlane.material.opacity=0.3+Math.sin(t*2)*0.15+Math.sin(t*5)*0.05;
        world.dungeonPortalPlane.rotation.y+=GameState.deltaTime*0.5;
        // Pulsing glow scale
        var pulse=1.0+Math.sin(t*3)*0.08;
        world.dungeonPortalPlane.scale.setScalar(pulse);
    }
    GameState.scene.children.forEach(function(child){
        if(child.userData&&child.userData.entityType==='corruptedPortal'&&child.userData.portalPlane){
            var pp=child.userData.portalPlane;
            pp.material.opacity=0.25+Math.sin(t*2.5+child.position.x)*0.15+Math.sin(t*6+child.position.z)*0.05;
            pp.rotation.y+=GameState.deltaTime*0.4;
            var cpulse=1.0+Math.sin(t*3.5+child.position.x)*0.1;
            pp.scale.setScalar(cpulse);
        }
    });
    if(world.dungeonEntrance&&Math.random()<GameState.deltaTime*4){
        var ep=world.dungeonEntrance.position;
        spawnParticles(new THREE.Vector3(ep.x+(Math.random()-0.5)*2,0.5+Math.random()*3.5,ep.z+(Math.random()-0.5)*0.5),0x8844ff,1,0.6,1.8,0.07);
        // Occasional bright spark
        if(Math.random()<0.3){
            spawnParticles(new THREE.Vector3(ep.x+(Math.random()-0.5)*1,2+Math.random()*2,ep.z),0xcc88ff,1,1.5,0.5,0.04);
        }
    }
    // Area portals glow particles
    world.portalMeshes&&world.portalMeshes.forEach(function(pm){
        if(pm&&pm.position&&Math.random()<GameState.deltaTime*2){
            spawnParticles(new THREE.Vector3(pm.position.x+(Math.random()-0.5)*1.5,0.5+Math.random()*2,pm.position.z+(Math.random()-0.5)*1.5),0x00c8ff,1,0.3,1.5,0.05);
        }
    });
}

const ambientParticles=[];
let ambientTimer=0;
function updateAmbientParticles(){
    ambientTimer+=GameState.deltaTime;
    if(ambientTimer<0.25)return;ambientTimer=0;
    var area=player.currentArea,pp=player.mesh.position;
    if(area==='station-hub'){
        var px=pp.x+(Math.random()-0.5)*20,pz=pp.z+(Math.random()-0.5)*20;
        spawnParticles(new THREE.Vector3(px,1+Math.random()*5,pz),0x00c8ff,1,0.1,4,0.02);
    }else if(area==='asteroid-mines'){
        var px2=pp.x+(Math.random()-0.5)*30,pz2=pp.z+(Math.random()-0.5)*30;
        spawnParticles(new THREE.Vector3(px2,Math.random()*3,pz2),Math.random()>0.7?0xffaa44:0x886644,1,0.3,3,0.02+Math.random()*0.03);
    }else if(area==='alien-wastes'){
        var px3=pp.x+(Math.random()-0.5)*25,pz3=pp.z+(Math.random()-0.5)*25;
        spawnParticles(new THREE.Vector3(px3,0.2+Math.random()*2,pz3),Math.random()>0.5?0x22ff66:0x8844ff,1,0.5,2.5,0.03+Math.random()*0.04);
    }else if(area==='bio-lab'){
        var px4=pp.x+(Math.random()-0.5)*15,pz4=pp.z+(Math.random()-0.5)*15;
        spawnParticles(new THREE.Vector3(px4,Math.random()*3,pz4),0x22aa88,1,0.2,3,0.02+Math.random()*0.02);
    }else if(area&&area.indexOf('corrupted')===0){
        var px5=pp.x+(Math.random()-0.5)*25,pz5=pp.z+(Math.random()-0.5)*25;
        spawnParticles(new THREE.Vector3(px5,Math.random()*2,pz5),Math.random()>0.5?0xff2244:0x881122,1,0.4,2,0.03+Math.random()*0.03);
    }
}

// ========================================
// Improved Minimap
// ========================================
function updateMinimapEnhanced(){
    const canvas=document.getElementById('minimap-canvas'),ctx=canvas.getContext('2d'),w=canvas.width,h=canvas.height;
    const px=player.mesh.position.x,pz=player.mesh.position.z;
    ctx.fillStyle='#080c14';ctx.fillRect(0,0,w,h);
    const cx=w/2,cy=h/2;
    if (DungeonState.active) {
        // Dungeon minimap
        var dsc = 0.55*minimapZoom;
        // Draw rooms
        DungeonState.rooms.forEach(function(room) {
            var rx = cx + (room.worldX - px) * dsc, ry = cy + (room.worldZ - pz) * dsc;
            var rw = room.width * dsc, rd = room.depth * dsc;
            var roomColor = room.type === 'entrance' ? '#1a3a1a' : room.type === 'boss' ? '#3a1a1a' : room.type === 'trap' ? '#2a2a1a' : '#1a1a2a';
            ctx.fillStyle = roomColor;
            ctx.fillRect(rx - rw / 2, ry - rd / 2, rw, rd);
            ctx.strokeStyle = '#3a3a5a'; ctx.lineWidth = 0.5;
            ctx.strokeRect(rx - rw / 2, ry - rd / 2, rw, rd);
        });
        // Draw corridors
        DungeonState.corridors.forEach(function(corr) {
            var fr = corr.fromRoom, tr = corr.toRoom;
            var midX2 = cx + ((fr.worldX + tr.worldX) / 2 - px) * dsc;
            var midZ2 = cy + ((fr.worldZ + tr.worldZ) / 2 - pz) * dsc;
            var dx2 = tr.worldX - fr.worldX, dz2 = tr.worldZ - fr.worldZ;
            var isH = Math.abs(dx2) > Math.abs(dz2);
            var len = Math.abs(isH ? dx2 : dz2) * dsc;
            var cwid = DUNGEON_CONFIG.corridorWidth * dsc;
            ctx.fillStyle = '#15152a';
            if (isH) ctx.fillRect(midX2 - len / 2, midZ2 - cwid / 2, len, cwid);
            else ctx.fillRect(midX2 - cwid / 2, midZ2 - len / 2, cwid, len);
        });
        // Draw dungeon enemies
        DungeonState.enemies.forEach(function(e) {
            if (!e.alive) return;
            var ex2 = cx + (e.mesh.position.x - px) * dsc, ey2 = cy + (e.mesh.position.z - pz) * dsc;
            if (ex2 < 0 || ex2 > w || ey2 < 0 || ey2 > h) return;
            ctx.fillStyle = e.isDungeonBoss ? '#ff4488' : '#ff4444';
            ctx.beginPath(); ctx.arc(ex2, ey2, e.isDungeonBoss ? 3 : 2, 0, Math.PI * 2); ctx.fill();
        });
        // Draw traps
        DungeonState.traps.forEach(function(trap) {
            var tx2 = cx + (trap.x - px) * dsc, tz2 = cy + (trap.z - pz) * dsc;
            if (tx2 < 0 || tx2 > w || tz2 < 0 || tz2 > h) return;
            var tc = trap.type === 'fire' ? '#ff4400' : trap.type === 'slow' ? '#4488ff' : '#44ff44';
            ctx.fillStyle = tc; ctx.globalAlpha = 0.6;
            ctx.beginPath(); ctx.arc(tx2, tz2, 1.5, 0, Math.PI * 2); ctx.fill();
            ctx.globalAlpha = 1.0;
        });
        // Player
        ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(cx, cy, 3, 0, Math.PI * 2); ctx.fill();
        var dir2 = player.mesh.rotation.y; ctx.strokeStyle = '#fff'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.sin(dir2) * 8, cy - Math.cos(dir2) * 8); ctx.stroke();
        document.getElementById('area-name').textContent = 'Floor ' + DungeonState.floor;
        return;
    }
    // Area circles with distinct colors
    var msc=0.25*minimapZoom;
    [{x:0,z:0,r:35,c:'#1a2838',name:'Hub'},{x:300,z:0,r:200,c:'#2a1a10',name:'Mines'},{x:0,z:-300,r:250,c:'#0a1a10',name:'Wastes'},{x:-20,z:20,r:18,c:'#0a2020',name:'Lab'},{x:0,z:-650,r:200,c:'#0a0520',name:'Abyss'}].forEach(a=>{
        const ax=cx+(a.x-px)*msc,ay=cy+(a.z-pz)*msc;
        ctx.fillStyle=a.c;ctx.beginPath();ctx.arc(ax,ay,a.r*msc,0,Math.PI*2);ctx.fill();
        // Area label (scale font with zoom)
        var labelSize=Math.max(6,Math.min(12,Math.round(8*minimapZoom)));
        ctx.fillStyle='rgba(255,255,255,0.25)';ctx.font=labelSize+'px Segoe UI';ctx.textAlign='center';ctx.fillText(a.name,ax,ay+3);
    });
    // Resource nodes (cyan dots)
    GameState.resourceNodes.forEach(n=>{if(n.depleted)return;const rx=cx+(n.position.x-px)*msc,ry=cy+(n.position.z-pz)*msc;if(rx<0||rx>w||ry<0||ry>h)return;ctx.fillStyle='#44ffaa';ctx.beginPath();ctx.arc(rx,ry,1.5,0,Math.PI*2);ctx.fill();});
    // Enemies (red triangles)
    GameState.enemies.forEach(e=>{if(!e.alive)return;const ex=cx+(e.mesh.position.x-px)*msc,ey=cy+(e.mesh.position.z-pz)*msc;if(ex<0||ex>w||ey<0||ey>h)return;
        ctx.fillStyle=e.isBoss?'#ff4488':'#ff4444';ctx.beginPath();ctx.moveTo(ex,ey-2.5);ctx.lineTo(ex-2,ey+2);ctx.lineTo(ex+2,ey+2);ctx.closePath();ctx.fill();});
    // NPCs (yellow diamonds)
    GameState.npcs.forEach(n=>{const nx=cx+(n.position.x-px)*msc,ny=cy+(n.position.z-pz)*msc;if(nx<0||nx>w||ny<0||ny>h)return;ctx.fillStyle='#ffcc00';ctx.save();ctx.translate(nx,ny);ctx.rotate(Math.PI/4);ctx.fillRect(-2,-2,4,4);ctx.restore();});
    // Corridors (dim rectangles)
    CORRIDORS.forEach(function(c){var rx1=cx+(c.minX-px)*msc,ry1=cy+(c.minZ-pz)*msc,rx2=cx+(c.maxX-px)*msc,ry2=cy+(c.maxZ-pz)*msc;ctx.fillStyle='rgba(40,60,80,0.4)';ctx.fillRect(Math.min(rx1,rx2),Math.min(ry1,ry2),Math.abs(rx2-rx1),Math.abs(ry2-ry1));});
    // Player (white arrow)
    ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(cx,cy,3,0,Math.PI*2);ctx.fill();
    const dir=player.mesh.rotation.y;ctx.strokeStyle='#fff';ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(cx,cy);ctx.lineTo(cx+Math.sin(dir)*8,cy-Math.cos(dir)*8);ctx.stroke();
    // Zoom indicator
    if(minimapZoom!==1.0){ctx.fillStyle='rgba(255,255,255,0.4)';ctx.font='8px monospace';ctx.textAlign='right';ctx.fillText(minimapZoom.toFixed(1)+'x',w-4,h-4);}
    // Draw waypoint (Feature 8)
    if(player.waypoint){
        var wpx=cx+(player.waypoint.x-px)*msc,wpy=cy+(player.waypoint.z-pz)*msc;
        if(wpx>=0&&wpx<=w&&wpy>=0&&wpy<=h){
            ctx.fillStyle='#ff44ff';ctx.beginPath();ctx.moveTo(wpx,wpy-6);ctx.lineTo(wpx-4,wpy);ctx.lineTo(wpx,wpy-2);ctx.lineTo(wpx+4,wpy);ctx.closePath();ctx.fill();
            ctx.strokeStyle='#ff44ff';ctx.lineWidth=0.5;ctx.beginPath();ctx.moveTo(wpx,wpy);ctx.lineTo(wpx,wpy+4);ctx.stroke();
        }
        var wpDist=Math.round(Math.sqrt(Math.pow(player.waypoint.x-px,2)+Math.pow(player.waypoint.z-pz,2)));
        ctx.fillStyle='#ff88ff';ctx.font='9px monospace';ctx.textAlign='left';ctx.fillText(wpDist+'m',wpx+5,wpy-2);
    }
    const an={'station-hub':'Station Hub','asteroid-mines':'Asteroid Mines','alien-wastes':'Alien Wastes','bio-lab':'Bio-Lab','the-abyss':'The Abyss'};
    document.getElementById('area-name').textContent=an[player.currentArea]||'Unknown';
}

// ========================================
// Hover Label (RS-style mouseover text)
// ========================================
const hoverLabel=document.getElementById('hover-label');
function updateHoverLabel(hit){
    if(!hit||hit.type==='ground'){hideHoverLabel();return;}
    let html='';
    if(hit.type==='enemy'&&hit.entity){
        const e=hit.entity;
        const styleColor=e.combatStyle==='nano'?'nano':e.combatStyle==='tesla'?'tesla':'void';
        html=e.name+(e.isBoss?' <span style="color:#ff4444;font-size:10px;">[Boss]</span>':'');
        html+=' <span class="hover-level">(Level '+e.level+')</span>';
        html+=' <span class="hover-combat '+styleColor+'">'+e.combatStyle.charAt(0).toUpperCase()+e.combatStyle.slice(1)+'</span>';
        html+=' <span class="hover-action">[ Attack ]</span>';
    } else if(hit.type==='resource'&&hit.entity){
        const n=hit.entity,def=getItem(n.resource);
        if(def){
            html=def.name;
            html+=' <span class="hover-level">(Level '+n.level+')</span>';
            html+=' <span class="hover-action">[ Mine ]</span>';
        }
    } else if(hit.type==='npc'&&hit.entity){
        const npc=hit.entity;
        html=npc.def.name;
        if(npc.def.shop)html+=' <span class="hover-action">[ Talk / Trade ]</span>';
        else html+=' <span class="hover-action">[ Talk ]</span>';

    } else if(hit.type==='processingStation'&&hit.entity){
        const st=hit.entity;
        html=st.name;
        html+=' <span class="hover-action">[ Use - '+(st.skill==='repair'?'Repair':(SKILL_DEFS[st.skill]?SKILL_DEFS[st.skill].name:st.skill))+' ]</span>';
    } else if(hit.type==='questBoard'){
        html='Quest Board';
        html+=' <span class="hover-action">[ View Quests ]</span>';
    } else if(hit.type==='dungeonEntrance'){
        html='Abyssal Depths';
        html+=' <span class="hover-action">[ Enter Dungeon ]</span>';
    } else if(hit.type==='corruptedPortal'&&hit.entity){
        html=hit.entity.name;
        html+=' <span class="hover-action">[ Enter ]</span>';
    } else {hideHoverLabel();return;}
    hoverLabel.innerHTML=html;
    hoverLabel.style.display='block';
}
function hideHoverLabel(){hoverLabel.style.display='none';}

// ========================================
// Enemy HP Bars (floating above enemies)
// ========================================
const enemyHPContainer=document.getElementById('enemy-hp-bars');
const enemyHPBars=new Map();

function updateEnemyHPBars(){
    const cam=GameState.camera,w=window.innerWidth,h=window.innerHeight;
    // Track which enemies are visible this frame
    const activeIds=new Set();
    GameState.enemies.forEach(enemy=>{
        // Hide overworld enemy bars while in dungeon
        if(DungeonState.active&&!enemy.isDungeonEnemy){
            if(enemyHPBars.has(enemy))enemyHPBars.get(enemy).el.style.display='none';
            return;
        }
        if(!enemy.alive||!enemy.mesh||!enemy.mesh.visible){
            // Remove bar if enemy is dead
            if(enemyHPBars.has(enemy)){
                const bar=enemyHPBars.get(enemy);
                bar.el.remove();enemyHPBars.delete(enemy);
            }
            return;
        }
        activeIds.add(enemy);
        // Project 3D position to screen
        const pos=enemy.mesh.position.clone();
        pos.y+=(enemy.isBoss?4:2.5); // offset above the mesh
        const projected=pos.project(cam);
        const sx=(projected.x*0.5+0.5)*w;
        const sy=(-projected.y*0.5+0.5)*h;
        // Check if on screen and in front of camera
        if(projected.z>1||sx<-50||sx>w+50||sy<-50||sy>h+50){
            if(enemyHPBars.has(enemy))enemyHPBars.get(enemy).el.style.display='none';
            return;
        }
        const hpPct=(enemy.hp/enemy.maxHp)*100;
        let bar;
        if(enemyHPBars.has(enemy)){
            bar=enemyHPBars.get(enemy);
        } else {
            // Create new HP bar element
            const el=document.createElement('div');
            el.className='enemy-hp-bar'+(enemy.isBoss?' boss':'');
            el.innerHTML='<div class="hp-name"></div><div class="hp-fill"></div>';
            enemyHPContainer.appendChild(el);
            bar={el,nameEl:el.querySelector('.hp-name'),fillEl:el.querySelector('.hp-fill')};
            enemyHPBars.set(enemy,bar);
        }
        bar.el.style.display='block';
        bar.el.style.left=sx+'px';
        bar.el.style.top=sy+'px';
        bar.nameEl.textContent=enemy.name+' Lv'+enemy.level;
        bar.fillEl.style.width=hpPct+'%';
        // Color based on HP percentage
        bar.fillEl.className='hp-fill'+(hpPct>60?' hp-high':hpPct>25?' hp-mid':' hp-low');
    });
    // Clean up bars for enemies that no longer exist
    enemyHPBars.forEach((bar,enemy)=>{
        if(!activeIds.has(enemy)){bar.el.remove();enemyHPBars.delete(enemy);}
    });
}

// ========================================
// NPC Name Bars (floating above NPCs)
// ========================================
const npcNameContainer=document.getElementById('npc-name-bars');
const npcNameBars=new Map();

function updateNPCNameBars(){
    // Hide overworld NPC labels while in dungeon
    if(DungeonState.active){
        npcNameBars.forEach(function(bar){bar.el.style.display='none';});
        return;
    }
    const cam=GameState.camera,w=window.innerWidth,h=window.innerHeight;
    var playerPos=player.mesh?player.mesh.position:null;
    GameState.npcs.forEach(function(npc){
        // Distance-based culling — hide NPCs more than 60 units away
        if(playerPos){
            var dx=npc.mesh.position.x-playerPos.x,dz=npc.mesh.position.z-playerPos.z;
            if(dx*dx+dz*dz>3600){
                if(npcNameBars.has(npc))npcNameBars.get(npc).el.style.display='none';
                return;
            }
        }
        // Project 3D position to screen (above the indicator diamond)
        var pos=npc.mesh.position.clone();
        pos.y+=3.8;
        var projected=pos.project(cam);
        var sx=(projected.x*0.5+0.5)*w;
        var sy=(-projected.y*0.5+0.5)*h;
        // Off-screen or behind camera
        if(projected.z>1||sx<-100||sx>w+100||sy<-50||sy>h+50){
            if(npcNameBars.has(npc))npcNameBars.get(npc).el.style.display='none';
            return;
        }
        var bar;
        if(npcNameBars.has(npc)){
            bar=npcNameBars.get(npc);
        }else{
            var el=document.createElement('div');
            el.className='npc-name-bar';
            var nameSpan=document.createElement('div');nameSpan.className='npc-name';nameSpan.textContent=npc.def.name;
            el.appendChild(nameSpan);
            // Add subtitle for NPCs with shops or special roles
            if(npc.def.shop||npc.def.desc){
                var titleSpan=document.createElement('div');titleSpan.className='npc-title';
                if(npc.def.shop)titleSpan.textContent=npc.def.shop.specialty==='general'?'Trader':npc.def.shop.specialty==='bio'?'Bio Supplies':npc.def.shop.specialty==='mining'?'Mining Supplies':npc.def.shop.specialty==='equipment'?'Armorer':'Shop';
                else if(npc.id==='commander_vex')titleSpan.textContent='Quest Giver';
                else if(npc.id==='slayer_grax')titleSpan.textContent='Slayer Master';
                else if(npc.id==='dr_elara_voss')titleSpan.textContent='Psionic Researcher';
                else if(npc.id==='the_archivist')titleSpan.textContent='Prestige Master';
                else titleSpan.textContent='';
                if(titleSpan.textContent)el.appendChild(titleSpan);
            }
            npcNameContainer.appendChild(el);
            bar={el:el};
            npcNameBars.set(npc,bar);
        }
        bar.el.style.display='block';
        bar.el.style.left=sx+'px';
        bar.el.style.top=sy+'px';
    });
}

// ========================================
// Save / Load System
// ========================================
const SAVE_KEY='runescape_save_v1'; // kept for backwards compat with existing saves
let autoSaveTimer=0;

function saveGame(){
    try{
        const data={
            version:2,
            timestamp:Date.now(),
            player:{
                hp:player.hp,maxHp:player.maxHp,
                energy:player.energy,maxEnergy:player.maxEnergy,
                credits:player.credits,
                combatStyle:player.combatStyle,
                skills:JSON.parse(JSON.stringify(player.skills)),
                equipment:{},
                inventory:player.inventory.map(function(s){
                    if(!s)return null;
                    var obj={itemId:s.itemId,quantity:s.quantity};
                    if(s.durability!==undefined){obj.durability=s.durability;obj.maxDurability=s.maxDurability;}
                    return obj;
                }),
                position:{x:player.mesh.position.x,z:player.mesh.position.z},
                currentArea:player.currentArea,
                unlockedSynergies:player.unlockedSynergies.slice(),
                psionicsUnlocked:player.psionicsUnlocked,
                timeLoopData:JSON.parse(JSON.stringify(player.timeLoopData)),
                panelLocks:player.panelLocks||{},
                panelPositions:player.panelPositions||{},
                panelSizes:player.panelSizes||{},
                minimapSize:player.minimapSize||{width:180,height:180},
                chatSize:player.chatSize||null,
                chatPosition:player.chatPosition||null,
                chatLocked:player.chatLocked||false,
                minimapExpanded:player.minimapExpanded||false,
                autoEat:player.autoEat||false,
                autoRetaliate:player.autoRetaliate!==false,
                quickSlots:player.quickSlots||[null,null,null,null,null],
                bestiary:player.bestiary||{},
                prestige: JSON.parse(JSON.stringify(player.prestige)),
            },
            bank:bankStorage.map(s=>s?{itemId:s.itemId,quantity:s.quantity}:null),
            quests:JSON.parse(JSON.stringify(questState)),
            shopEconomy:JSON.parse(JSON.stringify(shopEconomy)),
            dungeon:{maxFloorReached:DungeonState.maxFloorReached},
        };
        // Save equipment as {id, durability, maxDurability}
        for(const[slot,item]of Object.entries(player.equipment)){
            if(item){
                var eqSave={id:item.id};
                if(item.durability!==undefined){eqSave.durability=item.durability;eqSave.maxDurability=item.maxDurability;}
                data.player.equipment[slot]=eqSave;
            }else{
                data.player.equipment[slot]=null;
            }
        }
        localStorage.setItem(SAVE_KEY,JSON.stringify(data));
        return true;
    }catch(e){console.error('Save failed:',e);return false;}
}

// Save migration: map old item IDs to new item IDs from the equipment overhaul
var ITEM_ID_MIGRATION={
    // Old tier 2 "alloy" → new "ferrite" (tier 2)
    'alloy_nanoblade':'ferrite_nanoblade','alloy_coilgun':'ferrite_coilgun','alloy_voidstaff':'ferrite_voidstaff',
    'alloy_helmet':'ferrite_helmet','alloy_vest':'ferrite_vest','alloy_greaves':'ferrite_legs','alloy_legs':'ferrite_legs',
    'alloy_boots':'ferrite_boots','alloy_gloves':'ferrite_gloves',
    // Old tier 3 "composite" → new "cobalt" (tier 3)
    'composite_nanoblade':'cobalt_nanoblade','composite_coilgun':'cobalt_coilgun','composite_voidstaff':'cobalt_voidstaff',
    'composite_helmet':'cobalt_helmet','composite_vest':'cobalt_vest','composite_greaves':'cobalt_legs','composite_legs':'cobalt_legs',
    'composite_boots':'cobalt_boots','composite_gloves':'cobalt_gloves',
    // Old tier 4 "plasma" → new "plasmite" (tier 6)
    'plasma_nanoblade':'plasmite_nanoblade','plasma_coilgun':'plasmite_coilgun','plasma_voidstaff':'plasmite_voidstaff',
    'plasma_helmet':'plasmite_helmet','plasma_vest':'plasmite_vest','plasma_greaves':'plasmite_legs','plasma_legs':'plasmite_legs',
    'plasma_boots':'plasmite_boots','plasma_gloves':'plasmite_gloves',
    // Old tier 5 "void" equipment → new "neutronium" (tier 8)
    'void_sword':'neutronium_nanoblade','void_nanoblade':'neutronium_nanoblade','void_coilgun':'neutronium_coilgun',
    'void_staff':'neutronium_voidstaff','void_voidstaff':'neutronium_voidstaff',
    'void_helmet':'neutronium_helmet','void_vest':'neutronium_vest','void_greaves':'neutronium_legs','void_legs':'neutronium_legs',
    'void_boots':'neutronium_boots','void_gloves':'neutronium_gloves','void_shield':'neutronium_helmet',
    // Old tier 6 "corrupted" → new "corrupted" (tier 12, same prefix but legs renamed)
    'corrupted_greaves':'corrupted_legs','corrupted_blade':'corrupted_nanoblade',
    'corrupted_staff':'corrupted_voidstaff',
    // Old ores/bars
    'voidstone_ore':'cobaltium_ore','voidstone_bar':'cobaltium_bar',
    'alloy_ore':'ferrite_ore','alloy_bar':'ferrite_bar',
    'composite_ore':'cobaltium_ore','composite_bar':'cobaltium_bar',
    'plasma_ore':'plasmite_ore','plasma_bar':'plasmite_bar','plasma_crystal':'plasmite_ore',
    // Old tools
    'alloy_mining_laser':'ferrite_mining_laser','alloy_bio_scanner':'ferrite_bio_scanner',
    'composite_mining_laser':'cobalt_mining_laser','composite_bio_scanner':'cobalt_bio_scanner'
};

function migrateItemId(id){return ITEM_ID_MIGRATION[id]||id;}

function migrateAllItemIds(data){
    if(!data||!data.player)return;
    var d=data.player;
    // Migrate equipment
    if(d.equipment){
        for(var slot in d.equipment){
            var eq=d.equipment[slot];
            if(!eq)continue;
            if(typeof eq==='string'){d.equipment[slot]=migrateItemId(eq);}
            else if(eq.id){eq.id=migrateItemId(eq.id);}
        }
    }
    // Migrate inventory
    if(d.inventory){
        d.inventory.forEach(function(s){if(s&&s.itemId)s.itemId=migrateItemId(s.itemId);});
    }
    // Migrate quickSlots
    if(d.quickSlots){
        d.quickSlots=d.quickSlots.map(function(qs){return qs?migrateItemId(qs):qs;});
    }
    // Migrate bank
    if(data.bank){
        data.bank.forEach(function(s){if(s&&s.itemId)s.itemId=migrateItemId(s.itemId);});
    }
}

function loadGame(){
    try{
        const raw=localStorage.getItem(SAVE_KEY);
        if(!raw)return false;
        const data=JSON.parse(raw);
        if(!data||!data.player)return false;
        // Migrate old item IDs to new ones
        migrateAllItemIds(data);
        const d=data.player;
        // Restore skills
        for(const[sk,val]of Object.entries(d.skills)){
            if(player.skills[sk]){player.skills[sk].level=val.level;player.skills[sk].xp=val.xp;}
        }
        // Restore equipment - backward compatible
        for(const[slot,eqData]of Object.entries(d.equipment)){
            if(!eqData){player.equipment[slot]=null;continue;}
            // Old format: plain string itemId; New format: {id, durability, maxDurability}
            var itemId=typeof eqData==='string'?eqData:eqData.id;
            if(!itemId){player.equipment[slot]=null;continue;}
            var itemDef=getItem(itemId);
            if(!itemDef){player.equipment[slot]=null;continue;}
            var equipped=Object.assign({},itemDef);
            if(typeof eqData==='object'&&eqData.durability!==undefined){
                equipped.durability=eqData.durability;
                equipped.maxDurability=eqData.maxDurability;
            }else if(equipped.type===ItemType.WEAPON||equipped.type===ItemType.ARMOR){
                // Old save: assign full durability
                var dur=initDurability(equipped);
                equipped.durability=dur.durability;
                equipped.maxDurability=dur.maxDurability;
            }
            player.equipment[slot]=equipped;
        }
        // Restore inventory - with durability
        d.inventory.forEach(function(s,i){
            if(!s){player.inventory[i]=null;return;}
            var invSlot={itemId:s.itemId,quantity:s.quantity};
            if(s.durability!==undefined){invSlot.durability=s.durability;invSlot.maxDurability=s.maxDurability;}
            player.inventory[i]=invSlot;
        });
        // Restore bank
        if(data.bank)data.bank.forEach((s,i)=>{bankStorage[i]=s?{itemId:s.itemId,quantity:s.quantity}:null;});
        // Restore quests
        if(data.quests){
            questState.vexQuest=data.quests.vexQuest||data.quests.active||null;
            questState.vexProgress=data.quests.vexProgress||data.quests.progress||[];
            questState.boardQuest=data.quests.boardQuest||null;
            questState.boardProgress=data.quests.boardProgress||[];
            questState.slayerTask=data.quests.slayerTask||null;
            questState.slayerProgress=data.quests.slayerProgress||0;
            questState.slayerStreak=data.quests.slayerStreak||0;
            questState.completed=data.quests.completed||[];
        }
        // Restore synergies
        player.unlockedSynergies=(d.unlockedSynergies&&Array.isArray(d.unlockedSynergies))?d.unlockedSynergies:[];
        player.psionicsUnlocked=d.psionicsUnlocked||false;
        if(player.psionicsUnlocked){
            if(!player.skills.psionics)player.skills.psionics={level:1,xp:0};
            SKILL_DEFS.psionics.locked=false;
        }
        if(d.timeLoopData)player.timeLoopData=d.timeLoopData;
        player.panelLocks=d.panelLocks||{};
        player.panelPositions=d.panelPositions||{};
        player.panelSizes=d.panelSizes||{};
        player.minimapSize=d.minimapSize||(d.minimapExpanded?{width:360,height:360}:{width:180,height:180});
        player.chatSize=d.chatSize||null;
        player.chatPosition=d.chatPosition||null;
        player.chatLocked=d.chatLocked||false;
        player.minimapExpanded=d.minimapExpanded||false;
        player.autoEat=d.autoEat||false;
        player.autoRetaliate=d.autoRetaliate!==false;
        player.quickSlots=d.quickSlots||[null,null,null,null,null];
        player.bestiary=d.bestiary||{};
        if(d.prestige){
            player.prestige=Object.assign({},player.prestige,d.prestige);
            if(!player.prestige.purchasedItems)player.prestige.purchasedItems=[];
            if(!player.prestige.questHistory)player.prestige.questHistory=[];
        }
        if(!player.skills.chronomancy)player.skills.chronomancy={level:1,xp:0};
        // Restore shop economy
        if(data.shopEconomy){shopEconomy=data.shopEconomy;}else{initShopEconomy();}
        // Restore player stats
        player.credits=d.credits||500;
        // Auto-set combat style from weapon (OSRS style)
        if(player.equipment.weapon&&player.equipment.weapon.style){player.combatStyle=player.equipment.weapon.style;}
        else{player.combatStyle=d.combatStyle||'nano';}
        player.currentArea=d.currentArea||'station-hub';
        GameState.currentArea=player.currentArea;
        recalcStats();
        player.hp=Math.min(d.hp||player.maxHp,player.maxHp);
        player.energy=Math.min(d.energy||player.maxEnergy,player.maxEnergy);
        // Restore position
        if(d.position)player.mesh.position.set(d.position.x,0,d.position.z);
        updateMeshColors();
        // Restore dungeon progress
        if(data.dungeon&&data.dungeon.maxFloorReached)DungeonState.maxFloorReached=data.dungeon.maxFloorReached;
        // If somehow saved in dungeon, place safely in Alien Wastes
        if(player.currentArea==='dungeon'){player.currentArea='alien-wastes';GameState.currentArea='alien-wastes';player.mesh.position.set(0,0,-120);}
        // Check synergies on load
        checkSynergies();
        if(player.prestige.tier>=5){
            initCorruptedEnemies();
            buildCorruptedAreas();
        }
        restoreLockedPanels();
        applyChatLayout();
        EventBus.emit('statsChanged');EventBus.emit('inventoryChanged');EventBus.emit('equipmentChanged');EventBus.emit('creditsChanged');
        return true;
    }catch(e){console.error('Load failed:',e);return false;}
}

function deleteSave(){localStorage.removeItem(SAVE_KEY);}
function hasSave(){return !!localStorage.getItem(SAVE_KEY);}

// ========================================
// Food Indicator (shows food count above action bar)
// ========================================
let foodIndicatorTimer=0;
function updateFoodIndicator(){
    foodIndicatorTimer+=GameState.deltaTime;
    if(foodIndicatorTimer<0.5)return;foodIndicatorTimer=0;
    const el=document.getElementById('food-indicator');if(!el)return;
    let foodCount=0,bestFood=null;
    player.inventory.forEach(s=>{
        if(!s)return;const def=getItem(s.itemId);
        if(def&&def.type==='food'&&def.heals){foodCount+=s.quantity;if(!bestFood||def.heals>bestFood.heals)bestFood=def;}
    });
    if(foodCount>0){
        el.innerHTML='[SPACE] <span class="food-count">'+foodCount+'</span> food'+(foodCount>1?'s':'')+' | heals <span class="food-heal">'+bestFood.heals+'</span> HP';
    }else{
        el.innerHTML='<span class="no-food">No food! Buy from Zik\'s shop</span>';
    }
}

function gameLoop(){
    requestAnimationFrame(gameLoop);
    if(GameState.paused)return;
    const dt=GameState.clock.getDelta();GameState.deltaTime=Math.min(dt,0.1);GameState.elapsedTime=GameState.clock.elapsedTime;
    // Auto-save every 60 seconds
    autoSaveTimer+=dt;if(autoSaveTimer>=60&&!DungeonState.active){autoSaveTimer=0;saveGame();}
    // Update all systems
    updateCamera();updateScreenShake();updatePlayerMovement();updatePlayerEnergy();if(!player.isMoving)resetWalkAnimation();
    updateGathering();updateAutoAttack();updateCombatEffects();updateCooldowns();updateAdrenaline();
    updateEnemyAI();updateNPCs();updateWorld();updateParticles();updateGroundItems();updateCombatAura();updateShopEconomy(GameState.deltaTime);updateDungeonTraps();updatePrestigeTimers();updatePrestigeAura();updateAreaAtmosphere();updatePortalAnimations();
    // UI
    updateBars();updateTargetInfo();updateActionBar();updateGatherBar();updateAttackBar();updateSkillBars();updateEnemyHPBars();updateNPCNameBars();updateStyleHUD();updateFoodIndicator();
    var qpEl=document.getElementById('quest-panel');if(qpEl&&qpEl.style.display!=='none')renderQuestPanel();
    // Auto-eat (Feature 3)
    if(player.autoEat&&player.hp>0&&player.hp<player.maxHp*player.autoEatThreshold)eatBestFood();
    minimapTimer++;if(minimapTimer%5===0)updateMinimapEnhanced();
    // Realtime world map update while open
    if(minimapTimer%3===0){var wmPanel=document.getElementById('world-map-panel');if(wmPanel&&wmPanel.style.display!=='none')renderWorldMap();}
    if(minimapTimer%30===0)updateXPTracker();
    checkIdleNotification();
    updateAmbientParticles();
    updateMusicLFO(GameState.deltaTime);
    // Multiplayer tick (if connected)
    if(window.AsterianMP)window.AsterianMP.tick(GameState.deltaTime);
    // Render
    GameState.renderer.render(GameState.scene,GameState.camera);
}

// ========================================
// ========================================
// Tutorial System
// ========================================
var TUTORIAL_KEY='asterian_tutorial_done';
var TUTORIAL_STEP_KEY='asterian_tutorial_step';
var tutorialActive=false;
var tutorialStep=0;

var TUTORIAL_STEPS=[
    {text:'Welcome to <strong>Asterian</strong>!<br>A sci-fi survival RPG beyond the stars.',action:'continue'},
    {text:'<strong>Tap the ground</strong> to move your character around the station.',action:'move',highlight:null},
    {text:'<strong>Drag</strong> to rotate the camera. <strong>Pinch</strong> to zoom in/out.',action:'continue'},
    {text:'<strong>Tap an enemy</strong> to start attacking!<br>Your character will auto-attack once in range.',action:'combat',highlight:null},
    {text:'You\'re earning <strong>XP</strong>! Open the <strong>Skills</strong> panel to see your progress.',action:'panel',target:'btn-skills',highlight:'#btn-skills'},
    {text:'Enemies drop <strong>loot</strong> on the ground.<br><strong>Tap items</strong> on the ground to pick them up.',action:'continue'},
    {text:'Open your <strong>Inventory</strong> to see your items and gear.',action:'panel',target:'btn-inventory',highlight:'#btn-inventory'},
    {text:'Talk to <strong>Commander Vex</strong> near the station for a mission!<br>Long-press NPCs for more options.',action:'continue'},
    {text:'You\'re ready to explore! Fight enemies, gather resources, and grow stronger.<br><strong>Good luck, recruit!</strong>',action:'continue'}
];

function startTutorial(){
    tutorialActive=true;
    // Resume from saved step if reloading mid-tutorial
    var savedStep=parseInt(localStorage.getItem(TUTORIAL_STEP_KEY))||0;
    tutorialStep=savedStep;
    showTutorialStep(savedStep);
}

function showTutorialStep(idx){
    var overlay=document.getElementById('tutorial-overlay');
    var mask=document.getElementById('tutorial-mask');
    if(!overlay) return;
    if(idx>=TUTORIAL_STEPS.length){completeTutorial();return;}
    tutorialStep=idx;
    var step=TUTORIAL_STEPS[idx];
    overlay.style.display='block';
    document.getElementById('tutorial-step-num').textContent='Step '+(idx+1)+' of '+TUTORIAL_STEPS.length;
    document.getElementById('tutorial-text').innerHTML=step.text;
    var continueBtn=document.getElementById('tutorial-continue');
    // For action steps (move, combat, panel), let clicks pass through to the game
    if(step.action!=='continue'){
        overlay.style.pointerEvents='none';
        if(mask) mask.style.display='none';
        // Keep the tutorial box clickable
        document.getElementById('tutorial-box').style.pointerEvents='auto';
        continueBtn.style.display='none';
    } else {
        overlay.style.pointerEvents='auto';
        if(mask) mask.style.display='block';
        document.getElementById('tutorial-box').style.pointerEvents='auto';
        continueBtn.style.display='';
        continueBtn.textContent=idx===TUTORIAL_STEPS.length-1?'Start Playing':'Continue';
    }
    // Highlight element
    var hl=document.getElementById('tutorial-highlight');
    if(step.highlight){
        var target=document.querySelector(step.highlight);
        if(target){
            var rect=target.getBoundingClientRect();
            hl.style.display='block';
            hl.style.left=(rect.left-4)+'px';
            hl.style.top=(rect.top-4)+'px';
            hl.style.width=(rect.width+8)+'px';
            hl.style.height=(rect.height+8)+'px';
        }else{hl.style.display='none';}
    }else{hl.style.display='none';}
}

function advanceTutorial(){
    if(!tutorialActive) return;
    tutorialStep++;
    localStorage.setItem(TUTORIAL_STEP_KEY,String(tutorialStep));
    if(tutorialStep>=TUTORIAL_STEPS.length){completeTutorial();return;}
    showTutorialStep(tutorialStep);
}

function completeTutorial(){
    tutorialActive=false;
    localStorage.setItem(TUTORIAL_KEY,'1');
    localStorage.removeItem(TUTORIAL_STEP_KEY);
    var overlay=document.getElementById('tutorial-overlay');
    if(overlay) overlay.style.display='none';
}

function skipTutorial(){
    completeTutorial();
}

// Tutorial event hooks
function checkTutorialEvent(eventType){
    if(!tutorialActive) return;
    var step=TUTORIAL_STEPS[tutorialStep];
    if(!step) return;
    if(step.action==='move'&&eventType==='playerMoved') advanceTutorial();
    else if(step.action==='combat'&&eventType==='combatStarted') advanceTutorial();
    else if(step.action==='panel'&&eventType==='panelOpened') advanceTutorial();
}

// Wire tutorial UI buttons
document.addEventListener('DOMContentLoaded',function(){
    var cb=document.getElementById('tutorial-continue');
    if(cb) cb.addEventListener('click',function(){advanceTutorial();});
    var sb=document.getElementById('tutorial-skip');
    if(sb) sb.addEventListener('click',function(){skipTutorial();});
});

// Start
// ========================================
const loadingBar=document.getElementById('loading-bar'),loadingText=document.getElementById('loading-text');
function setLoading(pct,text){loadingBar.style.width=pct+'%';loadingText.textContent=text;}

async function startGame(){
    try{
        setLoading(5,'Booting Nova Station OS...');
        await new Promise(r=>setTimeout(r,300));
        setLoading(15,'Initializing renderer...');initRenderer();
        await new Promise(r=>setTimeout(r,200));
        setLoading(30,'Generating terrain...');
        await new Promise(r=>setTimeout(r,150));
        setLoading(45,'Building station infrastructure...');
        await new Promise(r=>setTimeout(r,150));
        setLoading(55,'Populating asteroid fields...');
        await new Promise(r=>setTimeout(r,150));
        setLoading(65,'Mapping transit corridors...');
        await new Promise(r=>setTimeout(r,150));
        setLoading(75,'Spawning hostile lifeforms...');
        await new Promise(r=>setTimeout(r,150));
        setLoading(85,'Initializing combat systems...');
        initGame();
        await new Promise(r=>setTimeout(r,200));
        setLoading(95,'Establishing comms link...');
        await new Promise(r=>setTimeout(r,200));
        setLoading(100,'Systems online. Welcome, recruit.');
        await new Promise(r=>setTimeout(r,600));
        // Try to load save data
        const loaded=loadGame();
        document.getElementById('loading-screen').classList.add('fade-out');
        await new Promise(r=>setTimeout(r,800));
        document.getElementById('loading-screen').style.display='none';
        document.getElementById('ui-overlay').style.display='block';
        setTimeout(openDefaultPanels,200);
        if(loaded){
            EventBus.emit('chat',{type:'system',text:'Save data loaded! Welcome back, recruit.'});
            EventBus.emit('chat',{type:'info',text:'Your progress has been restored.'});
        }else{
            EventBus.emit('chat',{type:'system',text:'Welcome to Asterian! Click to move, right-click for options.'});
            EventBus.emit('chat',{type:'info',text:'You are at Nova Station. Explore the areas around you.'});
            EventBus.emit('chat',{type:'info',text:'Talk to Commander Vex for a mission. Middle-mouse to orbit camera.'});
            // Start tutorial for first-time players
            if(!localStorage.getItem(TUTORIAL_KEY)){
                setTimeout(startTutorial,1500);
            }
        }
        // Resume tutorial if it was in progress (reload mid-tutorial)
        if(!localStorage.getItem(TUTORIAL_KEY)&&localStorage.getItem(TUTORIAL_STEP_KEY)){
            setTimeout(startTutorial,1500);
        }
        EventBus.emit('chat',{type:'info',text:'Press SPACE to eat food. Click enemies to attack.'});
        EventBus.emit('chat',{type:'info',text:'Keys: V=Auto-eat | X=Reset XP tracker | M=World map'});
        EventBus.emit('chat',{type:'info',text:'Game auto-saves every 60s. Press F5 to quick-save.'});
        // Music starts on first user interaction (browser autoplay policy)
        document.addEventListener('click',tryStartMusic,{once:false});
        document.addEventListener('touchstart',tryStartMusic,{once:false});
        document.addEventListener('keydown',tryStartMusic,{once:false});
        gameLoop();
    }catch(err){console.error('Asterian failed:',err);setLoading(0,'Error: '+err.message);}
}

startGame();

// Debug exposure for testing
window.DEBUG={GameState,player,world,enemies:()=>world.enemies,saveGame,loadGame,openShop,openDialogue,startVexQuest,gainXp,questState,EventBus,updateQuestProgress,checkVexCompletion,addItem,addCredits,shopEconomy:function(){return shopEconomy;},checkSynergies,hasSynergy,getSynergyValue,degradeWeapon,degradeArmor,openRepairStation,initShopEconomy,renderSynergiesTab,SYNERGY_DEFS,BOARD_QUESTS,startBoardQuest,assignSlayerTask,completeSlayerTask,openBoardPanel,SKILL_UNLOCKS,getSkillBonus,hasSkillMilestone,openSkillGuide,DungeonState,enterDungeon,exitDungeon,advanceDungeonFloor,enterTimeLoopDungeon,performTKPush,performMindControl,performTimeDilate,releaseMindControl,executePrestige,confirmPrestige,getTotalLevel,getPrestigeXpMultiplier,getPrestigeDamageMultiplier,getPrestigeReduction,openPrestigePanel,openPrestigeShop,PRESTIGE_CONFIG,PRESTIGE_PASSIVES,PRESTIGE_SHOP_ITEMS,CORRUPTED_AREAS,initCorruptedEnemies,buildCorruptedAreas,hasPrestigePassive,buildSimplePlayerMesh,addChatMessage,getTierColor,getCombatLevel,getHighestCombatLevel,enemyById,applyRemoteDamage,remoteKillEnemy,musicState,setMusicVolume,setSFXVolume,toggleMute,AREA_MUSIC,THREE:THREE};

})();
