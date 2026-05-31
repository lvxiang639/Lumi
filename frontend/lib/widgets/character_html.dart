// Auto-generated from assets/character/character_3d.html
const String kCharacterHtml = r'''
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { background:transparent; overflow:hidden; height:100vh; width:100vw; }
  canvas { display:block; }
  #loading { position:fixed; top:50%; left:50%; transform:translate(-50%,-50%);
    color:#A78BFA; font-family:sans-serif; font-size:14px; z-index:10; }
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
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const scene = new THREE.Scene();
const renderer = new THREE.WebGLRenderer({ alpha:true, antialias:true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio,2));
renderer.setSize(window.innerWidth,window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2;
document.body.appendChild(renderer.domElement);

const camera = new THREE.PerspectiveCamera(30,
  window.innerWidth/window.innerHeight, 0.1, 20);
camera.position.set(0,1.3,4);
camera.lookAt(0,0.9,0);

scene.add(new THREE.AmbientLight('#f0e8ff',2.5));
const key = new THREE.DirectionalLight('#ffffff',4);
key.position.set(2,3,3); key.castShadow=true; scene.add(key);
scene.add(new THREE.DirectionalLight('#c8b8ff',3).position.set(-1,2,-2)&&null||(()=>{const l=new THREE.DirectionalLight('#c8b8ff',3);l.position.set(-1,2,-2);return l})());
const rim = new THREE.DirectionalLight('#c8b8ff',3); rim.position.set(-1,2,-2); scene.add(rim);
const fill = new THREE.DirectionalLight('#ffe8d0',1.5); fill.position.set(0,0.5,1); scene.add(fill);

const ground = new THREE.Mesh(new THREE.PlaneGeometry(10,10),
  new THREE.MeshStandardMaterial({color:'#0B0E1E',roughness:0.4,metalness:0.1,transparent:true,opacity:0.5}));
ground.rotation.x=-Math.PI/2; ground.position.y=-1.5; ground.receiveShadow=true; scene.add(ground);

let model=null, mixer=null, blinkTimer=null;
let baseRotation=0, targetRotation=0, autoRotate=true;
let targetMouth=0, currentMouth=0, isJumping=false, jumpStart=0;
let eyeCloseI=-1, mouthOpenI=-1, browAngryI=-1, browSadI=-1, browSurprisedI=-1;

const loader = new GLTFLoader();

// ── Load from Flutter-injected base64 ──
window.loadModelBase64 = function(b64) {
  const bytes = Uint8Array.from(atob(b64), c=>c.charCodeAt(0));
  loader.parse(bytes.buffer, '', gltf => {
    document.getElementById('loading').style.display='none';
    model = gltf.scene;
    model.scale.set(1,1,1);
    model.position.set(0,-0.3,0);
    model.traverse(c=>{ if(c.isMesh){c.castShadow=true;c.receiveShadow=true;} });
    scene.add(model);
    if(gltf.animations?.length){
      mixer = new THREE.AnimationMixer(model);
      const idle = gltf.animations.find(a=>a.name.toLowerCase().includes('idle'))||gltf.animations[0];
      mixer.clipAction(idle).play();
    }
    findMorphs(model); setupBlink();
  }, e => { console.error(e); fallback(); });
};

setTimeout(()=>{ if(!model) fallback(); }, 3000);

// ── Fallback female character ──
function fallback(){
  const g=new THREE.Group();
  const s=new THREE.MeshStandardMaterial({color:'#FFF0E6',roughness:0.25});
  const h=new THREE.MeshStandardMaterial({color:'#3D2B3F',roughness:0.2});
  const o=new THREE.MeshStandardMaterial({color:'#2D2040',roughness:0.4});
  const sk=new THREE.MeshStandardMaterial({color:'#3A2850',roughness:0.4});
  const w=new THREE.MeshStandardMaterial({color:'#FFFFFF',roughness:0.1});
  const e=new THREE.MeshStandardMaterial({color:'#6B3FA0',roughness:0.1});
  // Head
  const hd=new THREE.Mesh(new THREE.SphereGeometry(0.18,32,24),s);hd.scale.set(0.95,1.08,0.9);hd.position.y=1.35;g.add(hd);
  // Eyes
  [-1,1].forEach(side=>{
    const wh=new THREE.Mesh(new THREE.SphereGeometry(0.055,16,12),w);wh.scale.set(0.9,1.3,0.3);wh.position.set(side*0.065,1.38,-0.14);g.add(wh);
    const ir=new THREE.Mesh(new THREE.SphereGeometry(0.04,16,12),e);ir.scale.set(0.9,1.3,0.3);ir.position.set(side*0.065,1.38,-0.125);g.add(ir);
    const sh=new THREE.Mesh(new THREE.SphereGeometry(0.015,8,8),w);sh.position.set(side*0.05,1.41,-0.115);g.add(sh);
  });
  // Hair
  const hb=new THREE.Mesh(new THREE.SphereGeometry(0.22,32,16,0,Math.PI*2,0,0.7),h);hb.scale.set(1.05,1.2,1.15);hb.position.y=1.38;g.add(hb);
  [-1,1].forEach(side=>{
    const st=new THREE.Mesh(new THREE.CylinderGeometry(0.03,0.02,0.6,8),h);st.position.set(side*0.18,1.05,-0.05);st.rotation.z=side*0.3;g.add(st);
    const cl=new THREE.Mesh(new THREE.SphereGeometry(0.02),new THREE.MeshStandardMaterial({color:'#E87080'}));cl.position.set(side*0.16,1.38,-0.1);g.add(cl);
  });
  // Body
  g.add(new THREE.Mesh(new THREE.CylinderGeometry(0.1,0.06,0.45,16),o)).position.y=0.92;
  g.add(new THREE.Mesh(new THREE.CylinderGeometry(0.035,0.04,0.08,12),s)).position.y=1.15;
  g.add(new THREE.Mesh(new THREE.CylinderGeometry(0.04,0.18,0.35,16),sk)).position.y=0.52;
  [-1,1].forEach(side=>{
    g.add(new THREE.Mesh(new THREE.CylinderGeometry(0.04,0.04,0.35,12),s)).position.set(side*0.04,0.18,0);
    const a=new THREE.Mesh(new THREE.CylinderGeometry(0.025,0.025,0.45,8),s);a.position.set(side*0.14,0.95,0);a.rotation.z=side*0.25;g.add(a);
  });
  model=g;model.position.set(0,0.1,0);scene.add(model);
  document.getElementById('loading').style.display='none';
  setupBlink();
}

function findMorphs(obj){
  obj.traverse(c=>{
    if(c.isMesh&&c.morphTargetDictionary){
      const d=c.morphTargetDictionary;
      if('Fcl_EYE_Close' in d) eyeCloseI=d['Fcl_EYE_Close'];
      if('Fcl_MTH_A' in d) mouthOpenI=d['Fcl_MTH_A'];
      if('Fcl_BRW_Angry' in d) browAngryI=d['Fcl_BRW_Angry'];
      if('Fcl_BRW_Sad' in d) browSadI=d['Fcl_BRW_Sad'];
      if('Fcl_BRW_Surprised' in d) browSurprisedI=d['Fcl_BRW_Surprised'];
    }
  });
}

function setupBlink(){blinkTimer&&clearTimeout(blinkTimer);blinkTimer=setTimeout(()=>{doBlink();setupBlink();},2500+Math.random()*3500);}
function doBlink(){
  if(!model||eyeCloseI<0) return;
  const ms=[];model.traverse(c=>{if(c.isMesh&&c.morphTargetInfluences)ms.push(c);});if(!ms.length)return;
  ms[0].morphTargetInfluences[eyeCloseI]=1;
  setTimeout(()=>{ms[0].morphTargetInfluences[eyeCloseI]=0;resetExpr();},120);
}

function resetExpr(){
  if(!model)return;
  const ms=[];model.traverse(c=>{if(c.isMesh&&c.morphTargetInfluences)ms.push(c);});if(!ms.length)return;
  [browAngryI,browSadI,browSurprisedI].forEach(i=>{if(i>=0)ms[0].morphTargetInfluences[i]=0;});
}

// ── Flutter bridge ──
window.updateMouth=v=>{ targetMouth=Number(v)||0; };
window.setEmotion=emo=>{
  if(!model)return;
  const ms=[];model.traverse(c=>{if(c.isMesh&&c.morphTargetInfluences)ms.push(c);});if(!ms.length)return;
  resetExpr();
  const m={joy:()=>{},sad:()=>{if(browSadI>=0)ms[0].morphTargetInfluences[browSadI]=0.8;},
    angry:()=>{if(browAngryI>=0)ms[0].morphTargetInfluences[browAngryI]=0.9;},
    surprised:()=>{if(browSurprisedI>=0)ms[0].morphTargetInfluences[browSurprisedI]=0.9;},
    worried:()=>{if(browSadI>=0)ms[0].morphTargetInfluences[browSadI]=0.4;}}[emo||'calm'];
  if(m)m();
};
window.setAnimState=s=>{ if(s==='dancing'&&!isJumping){isJumping=true;jumpStart=performance.now();autoRotate=true;} };

// ── Render ──
const clock=new THREE.Clock();
(function anim(){requestAnimationFrame(anim);
  const dt=clock.getDelta(),now=performance.now();
  if(mixer)mixer.update(dt);
  if(model){
    if(autoRotate) baseRotation+=dt*0.3; else baseRotation+=(targetRotation-baseRotation)*0.05;
    model.rotation.y=baseRotation;
    currentMouth+=(targetMouth-currentMouth)*0.3;
    const ms=[];model.traverse(c=>{if(c.isMesh&&c.morphTargetInfluences)ms.push(c);});
    if(ms.length&&mouthOpenI>=0)ms[0].morphTargetInfluences[mouthOpenI]=currentMouth;
    if(isJumping){
      const el=now-jumpStart;const D=600;
      if(el>D){isJumping=false;model.position.y=-0.3;model.scale.set(1,1,1);}
      else{const t=el/D;model.position.y=-0.3+Math.sin(t*Math.PI)*0.5;const ss=1+Math.sin(t*Math.PI)*0.1;model.scale.set(1/(ss*0.3+0.7),ss,1/(ss*0.3+0.7));}
    }
  }
  renderer.render(scene,camera);
})();

window.addEventListener('resize',()=>{
  camera.aspect=window.innerWidth/window.innerHeight;camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth,window.innerHeight);
});

let dragX=0,isDrag=false;
window.addEventListener('pointerdown',e=>{dragX=e.clientX;isDrag=true;});
window.addEventListener('pointermove',e=>{if(!isDrag)return;setTimeout(()=>{autoRotate=false;targetRotation=baseRotation+(e.clientX-dragX)*0.01;},0);});
window.addEventListener('pointerup',()=>{isDrag=false;setTimeout(()=>{autoRotate=true;},5000);});

console.log('✅ 3D Character ready');
</script>
</body>
</html>

''';
