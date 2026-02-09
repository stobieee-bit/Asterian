// ========================================
// Asterian Multiplayer Client — Tier 1.5
// Presence, chat, name labels, walk sync
// Auto-connect, reconnect, HUD indicator
// Loaded AFTER game.js — uses window.DEBUG
// ========================================
(function(){
'use strict';

// ── Config ──────────────────────────────────────────────────────
var MP_NAME_KEY = 'asterian_mp_name';
var DEFAULT_SERVER = 'wss://asterian-server.onrender.com';
var RECONNECT_MIN = 1000;
var RECONNECT_MAX = 30000;

// ── State ──────────────────────────────────────────────────────
var ws = null;
var myId = null;
var connected = false;
var remotePlayers = {};   // id → { mesh, label, targetX, targetZ, targetRy, currentX, currentZ, currentRy, moving, name, stats, animPhase, attackAnim }
var sendTimer = 0;
var SEND_INTERVAL = 0.1;  // 10 updates/sec
var LERP_SPEED = 10;

// Auto-reconnect state
var intentionalDisconnect = false;
var reconnectDelay = RECONNECT_MIN;
var reconnectTimeout = null;
var autoConnectDone = false;

// Style colors for remote player meshes
var STYLE_COLORS = {
    'nano':  0x22aa55,
    'tesla': 0x3388ee,
    'void':  0x8844cc
};

// ── Helpers ────────────────────────────────────────────────────
function D(){ return window.DEBUG || {}; }
function scene(){ var d=D(); return d.GameState ? d.GameState.scene : null; }
function player(){ return D().player; }
function camera(){ var d=D(); return d.GameState ? d.GameState.camera : null; }

function getSavedName(){ return localStorage.getItem(MP_NAME_KEY) || ''; }
function saveName(name){ localStorage.setItem(MP_NAME_KEY, name); }

function getAreaName(){
    var p=player();
    if(!p||!p.mesh)return 'station-hub';
    var pz=p.mesh.position.z;
    if(pz < -450) return 'the-abyss';
    if(pz < -50) return 'alien-wastes';
    if(p.mesh.position.x > 100) return 'asteroid-mines';
    return 'station-hub';
}

function getCombatStyleName(){
    var p=player();
    if(!p)return 'nano';
    return p.combatStyle || 'nano';
}

// ── Remote Player Management ───────────────────────────────────
function addRemotePlayer(id, name, x, z, ry, moving, equipment, stats){
    if(remotePlayers[id]) return;

    var color = STYLE_COLORS[(stats && stats.combatStyle) || 'nano'] || 0x446688;
    var mesh;
    var buildFn = D().buildSimplePlayerMesh;
    if(buildFn){
        mesh = buildFn(color, 0xddccbb);
    } else {
        var THREE = D().THREE || window.THREE;
        mesh = new THREE.Mesh(
            new THREE.BoxGeometry(0.5, 1.5, 0.3),
            new THREE.MeshLambertMaterial({color: color})
        );
    }
    mesh.position.set(x || 0, 0, z || 0);
    mesh.rotation.y = ry || 0;

    var s = scene();
    if(s){ s.add(mesh); console.log('[MP] Added mesh to scene for', name, 'at', x, z); }
    else { console.warn('[MP] No scene available! Cannot add mesh for', name); }

    var label = document.createElement('div');
    label.className = 'mp-player-name';
    label.innerHTML = name + '<span class="mp-level"> Lv' + ((stats && stats.level) || 1) + '</span>';
    document.getElementById('mp-name-labels').appendChild(label);

    remotePlayers[id] = {
        mesh: mesh,
        label: label,
        name: name,
        targetX: x || 0, targetZ: z || 0, targetRy: ry || 0,
        currentX: x || 0, currentZ: z || 0, currentRy: ry || 0,
        moving: moving || false,
        equipment: equipment || {},
        stats: stats || {},
        animPhase: 0,
        attackAnim: 0
    };
}

function removeRemotePlayer(id){
    var rp = remotePlayers[id];
    if(!rp) return;
    var s = scene();
    if(s && rp.mesh) s.remove(rp.mesh);
    if(rp.label && rp.label.parentNode) rp.label.parentNode.removeChild(rp.label);
    delete remotePlayers[id];
}

function removeAllRemotePlayers(){
    for(var id in remotePlayers){
        removeRemotePlayer(id);
    }
}

// ── Interpolation + Animation ──────────────────────────────────
function updateRemotePlayers(dt){
    var cam = camera();
    var renderer = D().GameState ? D().GameState.renderer : null;
    if(!cam || !renderer) return;

    var width = renderer.domElement.width;
    var height = renderer.domElement.height;

    for(var id in remotePlayers){
        var rp = remotePlayers[id];
        if(!rp.mesh) continue;

        // Lerp position
        rp.currentX += (rp.targetX - rp.currentX) * Math.min(1, LERP_SPEED * dt);
        rp.currentZ += (rp.targetZ - rp.currentZ) * Math.min(1, LERP_SPEED * dt);
        var dRy = rp.targetRy - rp.currentRy;
        while(dRy > Math.PI) dRy -= Math.PI * 2;
        while(dRy < -Math.PI) dRy += Math.PI * 2;
        rp.currentRy += dRy * Math.min(1, LERP_SPEED * dt);

        rp.mesh.position.x = rp.currentX;
        rp.mesh.position.z = rp.currentZ;
        rp.mesh.rotation.y = rp.currentRy;

        // Attack animation override
        if(rp.attackAnim > 0){
            rp.attackAnim -= dt;
            var at = Math.max(0, rp.attackAnim) / 0.25;
            if(rp.mesh.userData.rightArm) rp.mesh.userData.rightArm.rotation.x = -1.2 * at;
            if(rp.mesh.userData.leftArm) rp.mesh.userData.leftArm.rotation.x = 0.3 * at;
        } else if(rp.moving){
            // Walk animation
            rp.animPhase += dt * 8;
            var swing = Math.sin(rp.animPhase) * 0.4;
            if(rp.mesh.userData.leftArm) rp.mesh.userData.leftArm.rotation.x = swing;
            if(rp.mesh.userData.rightArm) rp.mesh.userData.rightArm.rotation.x = -swing;
            if(rp.mesh.userData.leftLeg) rp.mesh.userData.leftLeg.rotation.x = -swing;
            if(rp.mesh.userData.rightLeg) rp.mesh.userData.rightLeg.rotation.x = swing;
        } else {
            if(rp.mesh.userData.leftArm) rp.mesh.userData.leftArm.rotation.x = 0;
            if(rp.mesh.userData.rightArm) rp.mesh.userData.rightArm.rotation.x = 0;
            if(rp.mesh.userData.leftLeg) rp.mesh.userData.leftLeg.rotation.x = 0;
            if(rp.mesh.userData.rightLeg) rp.mesh.userData.rightLeg.rotation.x = 0;
        }

        // Update name label position (project 3D → 2D)
        var THREE = D().THREE || window.THREE;
        if(THREE && rp.label){
            var pos = new THREE.Vector3(rp.currentX, 2.2, rp.currentZ);
            pos.project(cam);
            var sx = (pos.x * 0.5 + 0.5) * width;
            var sy = (-pos.y * 0.5 + 0.5) * height;
            if(pos.z > 1 || pos.z < -1){
                rp.label.style.display = 'none';
            } else {
                rp.label.style.display = '';
                rp.label.style.left = sx + 'px';
                rp.label.style.top = sy + 'px';
            }
        }
    }
}

// ── Send own position (throttled) ──────────────────────────────
function sendPosition(dt){
    if(!connected || !ws) return;
    sendTimer += dt;
    if(sendTimer < SEND_INTERVAL) return;
    sendTimer = 0;

    var p = player();
    if(!p || !p.mesh) return;

    ws.send(JSON.stringify({
        type: 'move',
        x: Math.round(p.mesh.position.x * 100) / 100,
        z: Math.round(p.mesh.position.z * 100) / 100,
        ry: Math.round(p.mesh.rotation.y * 100) / 100,
        moving: !!p.isMoving
    }));
}

// ── Send stats/equipment updates ───────────────────────────────
var lastSentStats = '';
var lastSentEquip = '';

function sendStatsIfChanged(){
    if(!connected || !ws) return;
    var p = player();
    if(!p) return;
    var getCL = D().getCombatLevel;
    var level = getCL ? getCL() : 1;
    var style = getCombatStyleName();
    var area = getAreaName();
    var key = level + '|' + style + '|' + p.hp + '|' + p.maxHp + '|' + area;
    if(key === lastSentStats) return;
    lastSentStats = key;
    ws.send(JSON.stringify({
        type: 'stats',
        level: level,
        combatStyle: style,
        hp: p.hp,
        maxHp: p.maxHp,
        area: area
    }));
}

function sendEquipIfChanged(){
    if(!connected || !ws) return;
    var p = player();
    if(!p || !p.equipment) return;
    var simplified = {};
    for(var slot in p.equipment){
        var item = p.equipment[slot];
        if(item){
            simplified[slot] = { id: item.id || '', tier: item.tier || 1 };
        }
    }
    var key = JSON.stringify(simplified);
    if(key === lastSentEquip) return;
    lastSentEquip = key;
    ws.send(JSON.stringify({ type: 'equip', equipment: simplified }));
}

// ── HUD Status Indicator ──────────────────────────────────────
function updateHUD(){
    var hud = document.getElementById('mp-status-hud');
    if(!hud) return;
    if(connected){
        var count = Object.keys(remotePlayers).length + 1;
        hud.innerHTML = '<span class="mp-hud-dot online"></span> Online (' + count + ')';
        hud.className = 'mp-hud-online';
    } else {
        hud.innerHTML = '<span class="mp-hud-dot offline"></span> Offline';
        hud.className = 'mp-hud-offline';
    }
}

// ── WebSocket Connection ───────────────────────────────────────
function connect(url, name){
    console.log('[MP] connect() called - url:', url, 'name:', name);
    if(ws) disconnect();
    intentionalDisconnect = false;

    // Save name for future sessions
    if(name) saveName(name);

    setStatus('Connecting...', 'connecting');

    try {
        ws = new WebSocket(url);
        console.log('[MP] WebSocket created');
    } catch(e){
        console.error('[MP] WebSocket creation failed:', e);
        setStatus('Invalid URL', 'error');
        scheduleReconnect(url, name);
        return;
    }

    ws.onopen = function(){
        console.log('[MP] WebSocket opened, sending join');
        ws.send(JSON.stringify({ type: 'join', name: name }));
        // Reset reconnect delay on success
        reconnectDelay = RECONNECT_MIN;
    };

    ws.onmessage = function(evt){
        var msg;
        try { msg = JSON.parse(evt.data); } catch { return; }

        switch(msg.type){
            case 'welcome':
                myId = msg.id;
                connected = true;
                console.log('[MP] Welcome! My ID:', myId, 'Existing players:', msg.players.length);
                setStatus('Connected (' + (msg.players.length + 1) + ' online)', 'connected');
                updateUIConnected(true);
                updateHUD();
                for(var i = 0; i < msg.players.length; i++){
                    var p = msg.players[i];
                    console.log('[MP] Adding existing player:', p.name, 'at', p.x, p.z);
                    addRemotePlayer(p.id, p.name, p.x, p.z, p.ry, p.moving, p.equipment, p.stats);
                }
                addChat('system', 'Multiplayer connected! You are: ' + name);
                lastSentStats = '';
                lastSentEquip = '';
                sendStatsIfChanged();
                sendEquipIfChanged();
                break;

            case 'join':
                console.log('[MP] Player joined:', msg.name, 'id:', msg.id);
                addRemotePlayer(msg.id, msg.name, 0, 0, 0, false, {}, {});
                addChat('multiplayer', msg.name + ' joined the world.');
                updatePlayerCount();
                updateHUD();
                break;

            case 'leave':
                var lp = remotePlayers[msg.id];
                if(lp) addChat('multiplayer', lp.name + ' left the world.');
                removeRemotePlayer(msg.id);
                updatePlayerCount();
                updateHUD();
                break;

            case 'move':
                var rp = remotePlayers[msg.id];
                if(rp){
                    rp.targetX = msg.x;
                    rp.targetZ = msg.z;
                    rp.targetRy = msg.ry;
                    rp.moving = msg.moving;
                }
                break;

            case 'chat':
                if(msg.id === myId) break;
                console.log('[MP] Chat from', msg.name, ':', msg.text);
                addChat('multiplayer', msg.name + ': ' + msg.text);
                break;

            case 'equip':
                var ep = remotePlayers[msg.id];
                if(ep) ep.equipment = msg.equipment || {};
                break;

            case 'stats':
                var sp = remotePlayers[msg.id];
                if(sp){
                    sp.stats = msg.stats || {};
                    var color = STYLE_COLORS[(sp.stats.combatStyle) || 'nano'] || 0x446688;
                    if(sp.mesh && sp.mesh.children && sp.mesh.children[0]){
                        sp.mesh.children[0].material.color.setHex(color);
                    }
                    if(sp.label){
                        sp.label.innerHTML = sp.name + '<span class="mp-level"> Lv' + (sp.stats.level || 1) + '</span>';
                    }
                }
                break;

            case 'attack':
                handleRemoteAttack(msg);
                break;

            case 'enemyKill':
                handleRemoteKill(msg);
                break;

            case 'ping':
                if(ws && ws.readyState === 1){
                    ws.send(JSON.stringify({ type: 'pong' }));
                }
                break;

            case 'error':
                setStatus(msg.msg || 'Server error', 'error');
                break;
        }
    };

    ws.onclose = function(ev){
        console.log('[MP] WebSocket closed, code:', ev.code, 'reason:', ev.reason, 'intentional:', intentionalDisconnect);
        connected = false;
        myId = null;
        removeAllRemotePlayers();
        setStatus('Disconnected', 'error');
        updateUIConnected(false);
        updateHUD();
        addChat('system', 'Multiplayer disconnected.');
        ws = null;
        // Auto-reconnect if not intentional
        if(!intentionalDisconnect){
            scheduleReconnect(url, name);
        }
    };

    ws.onerror = function(ev){
        console.error('[MP] WebSocket error:', ev);
        setStatus('Connection failed', 'error');
    };
}

function disconnect(){
    intentionalDisconnect = true;
    clearReconnectTimeout();
    if(ws){
        ws.close();
        ws = null;
    }
    connected = false;
    myId = null;
    removeAllRemotePlayers();
    setStatus('Disconnected', '');
    updateUIConnected(false);
    updateHUD();
}

// ── Auto-Reconnect ────────────────────────────────────────────
function scheduleReconnect(url, name){
    if(intentionalDisconnect) return;
    clearReconnectTimeout();
    var delay = reconnectDelay;
    reconnectDelay = Math.min(reconnectDelay * 2, RECONNECT_MAX);
    addChat('system', 'Reconnecting in ' + Math.round(delay / 1000) + 's...');
    setStatus('Reconnecting in ' + Math.round(delay / 1000) + 's...', 'connecting');
    reconnectTimeout = setTimeout(function(){
        if(!connected && !intentionalDisconnect){
            connect(url, name);
        }
    }, delay);
}

function clearReconnectTimeout(){
    if(reconnectTimeout){
        clearTimeout(reconnectTimeout);
        reconnectTimeout = null;
    }
}

// ── Shared Combat: send attack/kill ────────────────────────────
function sendAttack(enemyId, damage, style){
    if(!connected || !ws) return;
    var p = player();
    if(!p || !p.mesh) return;
    ws.send(JSON.stringify({
        type: 'attack',
        enemyId: enemyId,
        damage: damage,
        style: style || 'nano',
        x: Math.round(p.mesh.position.x * 100) / 100,
        z: Math.round(p.mesh.position.z * 100) / 100
    }));
}

function sendKill(enemyId){
    if(!connected || !ws) return;
    ws.send(JSON.stringify({ type: 'enemyKill', enemyId: enemyId }));
}

function handleRemoteAttack(msg){
    // Trigger attack animation on remote player
    var rp = remotePlayers[msg.id];
    if(rp) rp.attackAnim = 0.25;

    // Apply damage to local enemy representation
    var applyRemote = D().applyRemoteDamage;
    if(applyRemote && msg.enemyId){
        applyRemote(msg.enemyId, msg.damage, msg.style, msg.name);
    }
}

function handleRemoteKill(msg){
    var remoteKill = D().remoteKillEnemy;
    if(remoteKill && msg.enemyId){
        remoteKill(msg.enemyId, msg.name);
    }
}

// ── Chat ───────────────────────────────────────────────────────
function addChat(type, text){
    var fn = D().addChatMessage;
    if(fn) fn(type, text);
}

function sendChat(text){
    if(!connected || !ws) return;
    text = text.trim().slice(0, 200);
    if(!text) return;
    ws.send(JSON.stringify({ type: 'chat', text: text }));
    var name = getSavedName() || 'You';
    addChat('multiplayer', name + ': ' + text);
}

// ── UI Helpers ─────────────────────────────────────────────────
function setStatus(text, cls){
    var el = document.getElementById('mp-status');
    if(!el) return;
    el.textContent = text;
    el.className = cls || '';
}

function updateUIConnected(isConnected){
    var connectBtn = document.getElementById('mp-connect-btn');
    var disconnectBtn = document.getElementById('mp-disconnect-btn');
    var chatRow = document.getElementById('mp-chat-row');
    var mpBtn = document.getElementById('btn-mp');

    if(connectBtn) connectBtn.style.display = isConnected ? 'none' : '';
    if(disconnectBtn) disconnectBtn.style.display = isConnected ? '' : 'none';
    if(chatRow) chatRow.style.display = isConnected ? 'flex' : 'none';
    if(mpBtn){
        if(isConnected) mpBtn.classList.add('connected');
        else mpBtn.classList.remove('connected');
    }
}

function updatePlayerCount(){
    if(!connected) return;
    var count = Object.keys(remotePlayers).length + 1;
    setStatus('Connected (' + count + ' online)', 'connected');
}

// ── UI Event Bindings ──────────────────────────────────────────
function initUI(){
    // Pre-fill modal with saved name/server
    var mpNameInput = document.getElementById('mp-name');
    var mpServerInput = document.getElementById('mp-server');
    if(mpNameInput){
        var saved = getSavedName();
        if(saved) mpNameInput.value = saved;
    }
    if(mpServerInput && !mpServerInput.value){
        mpServerInput.value = DEFAULT_SERVER;
    }

    // MP button opens connect modal
    var mpBtn = document.getElementById('btn-mp');
    if(mpBtn){
        mpBtn.addEventListener('click', function(){
            var modal = document.getElementById('mp-connect-modal');
            if(!modal) return;
            if(modal.style.display === 'none'){
                modal.style.display = 'flex';
            } else {
                modal.style.display = 'none';
            }
        });
    }

    // Stop game keybinds when typing in MP modal inputs
    [mpNameInput, mpServerInput].forEach(function(inp){
        if(!inp) return;
        inp.addEventListener('keydown', function(e){ e.stopPropagation(); });
        inp.addEventListener('keyup', function(e){ e.stopPropagation(); });
        inp.addEventListener('keypress', function(e){ e.stopPropagation(); });
    });

    // Connect button
    var connectBtn = document.getElementById('mp-connect-btn');
    if(connectBtn){
        connectBtn.addEventListener('click', function(){
            var nameInput = document.getElementById('mp-name');
            var serverInput = document.getElementById('mp-server');
            var name = (nameInput ? nameInput.value.trim() : '') || 'Player';
            var url = (serverInput ? serverInput.value.trim() : '') || DEFAULT_SERVER;
            saveName(name);
            connect(url, name);
        });
    }

    // Disconnect button
    var disconnectBtn = document.getElementById('mp-disconnect-btn');
    if(disconnectBtn){
        disconnectBtn.addEventListener('click', function(){
            disconnect();
        });
    }

    // Chat input
    var chatInput = document.getElementById('mp-chat-input');
    if(chatInput){
        chatInput.addEventListener('keydown', function(e){
            e.stopPropagation();
            if(e.key === 'Enter'){
                sendChat(chatInput.value);
                chatInput.value = '';
            }
        });
        chatInput.addEventListener('keyup', function(e){ e.stopPropagation(); });
        chatInput.addEventListener('keypress', function(e){ e.stopPropagation(); });
    }

    // Initialize HUD
    updateHUD();
}

// ── Auto-Connect on Game Load ──────────────────────────────────
function tryAutoConnect(){
    console.log('[MP] tryAutoConnect called, done:', autoConnectDone);
    if(autoConnectDone) return;
    autoConnectDone = true;

    var savedName = getSavedName();
    console.log('[MP] Saved name:', savedName || '(none)');
    if(!savedName){
        // First time — prompt for name
        savedName = window.prompt('Enter your multiplayer name:', 'Player');
        if(!savedName || !savedName.trim()) savedName = 'Player';
        savedName = savedName.trim().slice(0, 16);
        saveName(savedName);
        // Also pre-fill the modal
        var ni = document.getElementById('mp-name');
        if(ni) ni.value = savedName;
    }

    connect(DEFAULT_SERVER, savedName);
}

// ── Game Loop Hook ─────────────────────────────────────────────
window.AsterianMP = {
    tick: function(dt){
        if(!connected) return;
        sendPosition(dt);
        updateRemotePlayers(dt);
        if(Math.random() < dt * 0.5){
            sendStatsIfChanged();
            sendEquipIfChanged();
        }
    },
    sendAttack: sendAttack,
    sendKill: sendKill,
    getRemotePlayers: function(){ return remotePlayers; }
};

// ── Init ───────────────────────────────────────────────────────
var waitForGameAttempts = 0;
function waitForGame(cb){
    // Wait until GameState.scene exists (game fully initialized)
    var d = D();
    waitForGameAttempts++;
    if(waitForGameAttempts % 10 === 1){
        console.log('[MP] waitForGame attempt', waitForGameAttempts, '- DEBUG:', !!d.GameState, 'scene:', !!(d.GameState && d.GameState.scene), 'camera:', !!(d.GameState && d.GameState.camera));
    }
    if(d.GameState && d.GameState.scene && d.GameState.camera){
        console.log('[MP] Game ready after', waitForGameAttempts, 'attempts');
        cb();
    } else {
        setTimeout(function(){ waitForGame(cb); }, 500);
    }
}

function tryInit(){
    console.log('[MP] tryInit called, btn-mp:', !!document.getElementById('btn-mp'));
    if(document.getElementById('btn-mp')){
        initUI();
        console.log('[MP] initUI done, waiting for game...');
        // Auto-connect once game is fully loaded
        waitForGame(function(){
            console.log('[MP] Game loaded, auto-connecting in 500ms...');
            setTimeout(tryAutoConnect, 500);
        });
    } else {
        setTimeout(tryInit, 200);
    }
}

if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', tryInit);
} else {
    tryInit();
}

})();
