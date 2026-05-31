// Auto-generated from assets/character/character_3d.html
const String kCharacterHtml = r'''
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: transparent;
    overflow: hidden;
    height: 100vh;
    width: 100vw;
  }
  canvas { display: block; }
  #loading {
    position: fixed; top: 50%; left: 50%;
    transform: translate(-50%,-50%);
    color: #A78BFA; font-family: sans-serif;
    font-size: 14px; z-index: 10;
  }
</style>
</head>
<body>
<div id="loading">⏳ 加载角色中...</div>

<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/"
  }
}
</script>

<script type="module">
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

// ── Scene setup ──
const scene = new THREE.Scene();

const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2;
document.body.appendChild(renderer.domElement);

const camera = new THREE.PerspectiveCamera(30, window.innerWidth / window.innerHeight, 0.1, 20);
camera.position.set(0, 1.3, 4.5);
camera.lookAt(0, 0.9, 0);

// ── Lighting ──
scene.add(new THREE.AmbientLight('#f0e8ff', 2.5));
const keyLight = new THREE.DirectionalLight('#ffffff', 4);
keyLight.position.set(2, 3, 3);
keyLight.castShadow = true;
scene.add(keyLight);
const rimLight = new THREE.DirectionalLight('#c8b8ff', 3);
rimLight.position.set(-1, 2, -2);
scene.add(rimLight);
const fillLight = new THREE.DirectionalLight('#ffe8d0', 1.5);
fillLight.position.set(0, 0.5, 1);
scene.add(fillLight);

// ── Ground reflection ──
const groundGeo = new THREE.PlaneGeometry(10, 10);
const groundMat = new THREE.MeshStandardMaterial({
  color: '#0B0E1E', roughness: 0.4, metalness: 0.1, transparent: true, opacity: 0.5
});
const ground = new THREE.Mesh(groundGeo, groundMat);
ground.rotation.x = -Math.PI / 2;
ground.position.y = -1.5;
ground.receiveShadow = true;
scene.add(ground);

// ── VRM / GLTF loader ──
let model = null;
let mixer = null;
let animations = [];
let blinkTimer = null;
let autoRotate = true;
let currentEmotion = 'calm';
let targetMouthOpen = 0;
let currentMouthOpen = 0;

const loader = new GLTFLoader();

// Use a well-known free VRM/VRoid model
// This is a sample VRM model from the Pixiv three-vrm repository
// Free female anime VRM model (three-vrm-girl from Pixiv)
const MODEL_URL = 'https://raw.githubusercontent.com/pixiv/three-vrm/dev/packages/three-vrm/examples/models/three-vrm-girl.vrm';

loader.load(
  MODEL_URL,
  (gltf) => {
    document.getElementById('loading').style.display = 'none';
    model = gltf.scene;
    model.scale.set(1, 1, 1);
    model.position.set(0, -0.3, 0);
    model.traverse((child) => {
      if (child.isMesh) {
        child.castShadow = true;
        child.receiveShadow = true;
      }
    });
    scene.add(model);

    // Animation clips
    if (gltf.animations && gltf.animations.length > 0) {
      mixer = new THREE.AnimationMixer(model);
      animations = gltf.animations;
      // Try to play first animation as idle
      const idleClip = gltf.animations.find(a => a.name.toLowerCase().includes('idle')) || gltf.animations[0];
      const action = mixer.clipAction(idleClip);
      action.play();
    }

    // Morph targets for blink detection
    findMorphTargets(model);
    setupBlink();
  },
  (progress) => {
    if (progress.total > 0) {
      const pct = Math.round((progress.loaded / progress.total) * 100);
      document.getElementById('loading').textContent = `⏳ 加载中 \${pct}%`;
    }
  },
  (error) => {
    document.getElementById('loading').textContent = '❌ 模型加载失败，请检查网络连接';
    console.error('VRM load error:', error);
    // Fallback: create simple character with basic geometries
    createFallbackCharacter();
  }
);

// ── Fallback character (if VRM fails to load) ──
function createFallbackCharacter() {
  const group = new THREE.Group();
  const skinMat = new THREE.MeshStandardMaterial({ color: '#FFF0E6', roughness: 0.25 });
  const hairMat = new THREE.MeshStandardMaterial({ color: '#3D2B3F', roughness: 0.2 });
  const outfitMat = new THREE.MeshStandardMaterial({ color: '#2D2040', roughness: 0.4 });
  const skirtMat = new THREE.MeshStandardMaterial({ color: '#3A2850', roughness: 0.4 });
  const sockMat = new THREE.MeshStandardMaterial({ color: '#FFFFFF', roughness: 0.3 });
  const shoeMat = new THREE.MeshStandardMaterial({ color: '#4A3030', roughness: 0.5 });
  const eyeMat = new THREE.MeshStandardMaterial({ color: '#6B3FA0', roughness: 0.1 });
  const whiteMat = new THREE.MeshStandardMaterial({ color: '#FFFFFF', roughness: 0.1 });

  // Head (slightly tall for anime style)
  const headGeo = new THREE.SphereGeometry(0.18, 32, 24);
  const head = new THREE.Mesh(headGeo, skinMat);
  head.scale.set(0.95, 1.08, 0.9);
  head.position.y = 1.35;
  group.add(head);

  // Eyes (big anime eyes)
  for (const side of [-1, 1]) {
    const eyeWhite = new THREE.Mesh(
      new THREE.SphereGeometry(0.055, 16, 12), whiteMat);
    eyeWhite.scale.set(0.9, 1.3, 0.3);
    eyeWhite.position.set(side * 0.065, 1.38, -0.14);
    group.add(eyeWhite);
    const iris = new THREE.Mesh(
      new THREE.SphereGeometry(0.04, 16, 12), eyeMat);
    iris.scale.set(0.9, 1.3, 0.3);
    iris.position.set(side * 0.065, 1.38, -0.125);
    group.add(iris);
    // Eye shine
    const shine = new THREE.Mesh(
      new THREE.SphereGeometry(0.015, 8, 8), whiteMat);
    shine.position.set(side * 0.05, 1.41, -0.115);
    group.add(shine);
  }

  // Hair (layered)
  const hairBack = new THREE.Mesh(
    new THREE.SphereGeometry(0.22, 32, 16, 0, Math.PI * 2, 0, 0.7), hairMat);
  hairBack.scale.set(1.05, 1.2, 1.15);
  hairBack.position.y = 1.38;
  group.add(hairBack);
  // Side strands
  for (const side of [-1, 1]) {
    const strand = new THREE.Mesh(
      new THREE.CylinderGeometry(0.03, 0.02, 0.6, 8), hairMat);
    strand.position.set(side * 0.18, 1.05, -0.05);
    strand.rotation.z = side * 0.3;
    group.add(strand);
  }
  // Hair clips
  for (const side of [-1, 1]) {
    const clip = new THREE.Mesh(new THREE.SphereGeometry(0.02),
      new THREE.MeshStandardMaterial({ color: '#E87080' }));
    clip.position.set(side * 0.16, 1.38, -0.1);
    group.add(clip);
  }

  // Body
  const bodyGeo = new THREE.CylinderGeometry(0.1, 0.06, 0.45, 16);
  const body = new THREE.Mesh(bodyGeo, outfitMat);
  body.position.y = 0.92;
  group.add(body);

  // Neck
  const neckGeo = new THREE.CylinderGeometry(0.035, 0.04, 0.08, 12);
  const neck = new THREE.Mesh(neckGeo, skinMat);
  neck.position.y = 1.15;
  group.add(neck);

  // Skirt (flared)
  const skirtGeo = new THREE.CylinderGeometry(0.04, 0.18, 0.35, 16);
  const skirt = new THREE.Mesh(skirtGeo, skirtMat);
  skirt.position.y = 0.52;
  group.add(skirt);

  // Legs
  for (const side of [-1, 1]) {
    // Upper leg
    const legGeo = new THREE.CylinderGeometry(0.04, 0.04, 0.35, 12);
    const leg = new THREE.Mesh(legGeo, skinMat);
    leg.position.set(side * 0.04, 0.18, 0);
    group.add(leg);
  }

  // Arms
  for (const side of [-1, 1]) {
    const armGeo = new THREE.CylinderGeometry(0.025, 0.025, 0.45, 8);
    const arm = new THREE.Mesh(armGeo, skinMat);
    arm.position.set(side * 0.14, 0.95, 0);
    arm.rotation.z = side * 0.25;
    group.add(arm);
  }

  model = group;
  model.position.set(0, 0.1, 0);
  scene.add(model);
  document.getElementById('loading').style.display = 'none';
  setupBlink();
}

// ── Morph target detection ──
let eyeCloseIndex = -1;
let mouthOpenIndex = -1;
let browAngryIndex = -1;
let browSadIndex = -1;
let browSurprisedIndex = -1;

function findMorphTargets(obj) {
  obj.traverse((child) => {
    if (child.isMesh && child.morphTargetDictionary) {
      const d = child.morphTargetDictionary;
      if ('Fcl_EYE_Close' in d) eyeCloseIndex = d['Fcl_EYE_Close'];
      if ('Fcl_MTH_A' in d) mouthOpenIndex = d['Fcl_MTH_A'];
      if ('Fcl_BRW_Angry' in d) browAngryIndex = d['Fcl_BRW_Angry'];
      if ('Fcl_BRW_Sad' in d) browSadIndex = d['Fcl_BRW_Sad'];
      if ('Fcl_BRW_Surprised' in d) browSurprisedIndex = d['Fcl_BRW_Surprised'];
    }
  });
}

// ── Blink ──
function setupBlink() {
  if (blinkTimer) clearTimeout(blinkTimer);
  const delay = 2500 + Math.random() * 3500;
  blinkTimer = setTimeout(() => {
    doBlink();
    setupBlink();
  }, delay);
}

function doBlink() {
  if (!model || eyeCloseIndex < 0) return;
  // Find meshes with morph targets
  const meshes = [];
  model.traverse(c => { if (c.isMesh && c.morphTargetInfluences) meshes.push(c); });
  if (meshes.length === 0) return;
  const mesh = meshes[0];

  const close = () => {
    if (eyeCloseIndex >= 0 && mesh.morphTargetInfluences) {
      mesh.morphTargetInfluences[eyeCloseIndex] = 1;
    }
  };
  const open = () => {
    if (eyeCloseIndex >= 0 && mesh.morphTargetInfluences) {
      mesh.morphTargetInfluences[eyeCloseIndex] = 0;
    }
    resetExpression();
  };

  close();
  setTimeout(open, 120);
}

// ── Expression control ──
function setEmotion(emotion) {
  currentEmotion = emotion;
  if (!model) return;
  const meshes = [];
  model.traverse(c => { if (c.isMesh && c.morphTargetInfluences) meshes.push(c); });
  if (meshes.length === 0) return;
  const m = meshes[0];

  resetExpression();

  switch (emotion) {
    case 'joy':
      if (browAngryIndex >= 0) m.morphTargetInfluences[browAngryIndex] = 0;
      break;
    case 'sad':
      if (browSadIndex >= 0) m.morphTargetInfluences[browSadIndex] = 0.8;
      break;
    case 'angry':
      if (browAngryIndex >= 0) m.morphTargetInfluences[browAngryIndex] = 0.9;
      break;
    case 'surprised':
      if (browSurprisedIndex >= 0) m.morphTargetInfluences[browSurprisedIndex] = 0.9;
      break;
    case 'worried':
      if (browSadIndex >= 0) m.morphTargetInfluences[browSadIndex] = 0.4;
      break;
  }
}

function resetExpression() {
  if (!model) return;
  const meshes = [];
  model.traverse(c => { if (c.isMesh && c.morphTargetInfluences) meshes.push(c); });
  if (meshes.length === 0) return;
  const m = meshes[0];
  [browAngryIndex, browSadIndex, browSurprisedIndex].forEach(i => {
    if (i >= 0) m.morphTargetInfluences[i] = 0;
  });
}

// ── Mouth sync ──
function updateMouth(value) {
  targetMouthOpen = value;
}

// ── Jump ──
let isJumping = false;
let jumpStartTime = 0;
const JUMP_DURATION = 600;

function doJump() {
  if (isJumping || !model) return;
  isJumping = true;
  jumpStartTime = performance.now();
}

// ── Auto-rotate ──
let baseRotation = 0;
let targetRotation = 0;
function setRotation(angle) {
  targetRotation = angle;
  autoRotate = false;
  setTimeout(() => { autoRotate = true; }, 5000);
}

// ── Render loop ──
const clock = new THREE.Clock();
function animate() {
  requestAnimationFrame(animate);

  const delta = clock.getDelta();
  const now = performance.now();

  if (mixer) mixer.update(delta);

  if (model) {
    // Auto-rotate
    if (autoRotate) {
      baseRotation += delta * 0.3;
    } else {
      baseRotation += (targetRotation - baseRotation) * 0.05;
    }
    model.rotation.y = baseRotation;

    // Smooth mouth open
    currentMouthOpen += (targetMouthOpen - currentMouthOpen) * 0.3;
    const meshes = [];
    model.traverse(c => { if (c.isMesh && c.morphTargetInfluences) meshes.push(c); });
    if (meshes.length > 0 && mouthOpenIndex >= 0 && meshes[0].morphTargetInfluences) {
      meshes[0].morphTargetInfluences[mouthOpenIndex] = currentMouthOpen;
    }

    // Jump animation
    if (isJumping) {
      const elapsed = now - jumpStartTime;
      if (elapsed > JUMP_DURATION) {
        isJumping = false;
        model.position.y = -0.3;
      } else {
        const t = elapsed / JUMP_DURATION;
        // Parabolic jump
        model.position.y = -0.3 + Math.sin(t * Math.PI) * 0.6;
        // Squash and stretch
        const stretch = 1 + Math.sin(t * Math.PI) * 0.1;
        model.scale.set(1 / (stretch * 0.3 + 0.7), stretch, 1 / (stretch * 0.3 + 0.7));
      }
    }
  }

  renderer.render(scene, camera);
}
animate();

// ── Handle resize ──
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

// ── Flutter bridge ──
window.updateMouth = function(v) {
  updateMouth(Number(v) || 0);
};

window.setEmotion = function(emotion) {
  setEmotion(emotion || 'calm');
};

window.setAnimState = function(state) {
  if (state === 'dancing') {
    autoRotate = true;
    doJump();
  }
};

window.doJump = function() {
  doJump();
};

// Expose rotation for Flutter
let dragStartX = 0;
let isDragging = false;
window.addEventListener('pointerdown', (e) => { dragStartX = e.clientX; isDragging = true; });
window.addEventListener('pointermove', (e) => {
  if (!isDragging) return;
  const dx = e.clientX - dragStartX;
  setRotation(baseRotation + dx * 0.01);
});
window.addEventListener('pointerup', () => { isDragging = false; });

console.log('✅ 3D Character ready');
</script>
</body>
</html>

''';
