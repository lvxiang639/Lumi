const String kCharacterHtml = r'''
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<style>
  :root{--mouth:0}
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:transparent;display:flex;justify-content:center;align-items:center;height:100vh;overflow:hidden;-webkit-user-select:none;user-select:none}
  svg{max-height:100vh;max-width:100vw}

  .pet{animation:breathe 2.8s ease-in-out infinite;transform-origin:250px 300px}
  @keyframes breathe{0%,100%{transform:translateY(0) scaleY(1)}50%{transform:translateY(-8px) scaleY(1.03)}}

  .tail{animation:wag 2.2s ease-in-out infinite;transform-origin:370px 350px}
  @keyframes wag{0%,100%{transform:rotate(-5deg)}50%{transform:rotate(8deg)}}

  .ear-l{animation:earL 3s ease-in-out infinite;transform-origin:180px 100px}
  .ear-r{animation:earR 2.8s ease-in-out infinite;transform-origin:320px 100px}
  @keyframes earL{0%,100%{transform:rotate(0)}50%{transform:rotate(-6deg)}}
  @keyframes earR{0%,100%{transform:rotate(0)}50%{transform:rotate(6deg)}}

  .eye-l,.eye-r{transform-origin:center}
  .blink .eye-l,.blink .eye-r{animation:blink 0.12s ease-in-out}
  @keyframes blink{0%,100%{transform:scaleY(1)}50%{transform:scaleY(0.05)}}

  .mouth-g{transition:transform .05s ease-out}

  .em-joy .eye-l,.em-joy .eye-r{transform:scaleY(0.75)}
  .em-joy .blush-l,.em-joy .blush-r{opacity:1}
  .em-sad .eye-l,.em-sad .eye-r{transform:translateY(4px)}
  .em-angry .brow-l,.em-angry .brow-r{transform:translateY(-4px)}
  .em-surprised .eye-l,.em-surprised .eye-r{transform:scale(1.3)}
  .em-worried .brow-l,.em-worried .brow-r{transform:translateY(2px)}

  .dance .pet{animation:danceB .4s ease-in-out infinite}
  .dance .tail{animation:danceT .3s ease-in-out infinite}
  @keyframes danceB{0%,100%{transform:translateY(0) rotate(-3deg)}50%{transform:translateY(-15px) rotate(3deg)}}
  @keyframes danceT{0%,100%{transform:rotate(-12deg)}50%{transform:rotate(12deg)}}
</style>
</head>
<body id="body">

<svg viewBox="0 0 500 550" class="pet">
  <defs>
    <radialGradient id="bodyG" cx="50%" cy="40%"><stop offset="0%" stop-color="#FFF8F0"/><stop offset="60%" stop-color="#FDE8D8"/><stop offset="100%" stop-color="#F5D0B0"/></radialGradient>
    <radialGradient id="eyeG" cx="50%" cy="35%"><stop offset="0%" stop-color="#6B4FB0"/><stop offset="50%" stop-color="#4A2F80"/><stop offset="100%" stop-color="#2A1050"/></radialGradient>
    <radialGradient id="blushG" cx="50%" cy="50%"><stop offset="0%" stop-color="#FFB0B0" stop-opacity="0.5"/><stop offset="100%" stop-color="#FFB0B0" stop-opacity="0"/></radialGradient>
    <radialGradient id="pawG" cx="50%" cy="40%"><stop offset="0%" stop-color="#FFF0E8"/><stop offset="100%" stop-color="#F5D0B0"/></radialGradient>
    <linearGradient id="tailG" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#E8C090"/><stop offset="100%" stop-color="#F5DCC0"/></linearGradient>
    <radialGradient id="noseG" cx="50%" cy="50%"><stop offset="0%" stop-color="#F8A0A0"/><stop offset="100%" stop-color="#E06060"/></radialGradient>
  </defs>

  <!-- ══ TAIL (fluffy, wagging) ══ -->
  <g class="tail">
    <path d="M340 330 Q380 310 400 280 Q420 250 430 230 Q440 210 420 200 Q410 195 400 210 Q380 240 350 280 Q330 310 340 330 Z" fill="url(#tailG)"/>
    <path d="M430 230 Q435 210 420 200" stroke="#E8C8A0" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.5"/>
    <!-- Tail fluff -->
    <ellipse cx="415" cy="215" rx="12" ry="8" fill="#FDE8D0" opacity="0.6"/>
    <ellipse cx="420" cy="228" rx="14" ry="9" fill="white" opacity="0.4"/>
  </g>

  <!-- ══ BACK LEGS ══ -->
  <ellipse cx="218" cy="400" rx="35" ry="22" fill="url(#pawG)"/>
  <ellipse cx="282" cy="400" rx="35" ry="22" fill="url(#pawG)"/>
  <!-- Paw pads -->
  <ellipse cx="208" cy="402" rx="10" ry="6" fill="#F0C8A8" opacity="0.5"/>
  <ellipse cx="226" cy="402" rx="10" ry="6" fill="#F0C8A8" opacity="0.5"/>
  <ellipse cx="274" cy="402" rx="10" ry="6" fill="#F0C8A8" opacity="0.5"/>
  <ellipse cx="292" cy="402" rx="10" ry="6" fill="#F0C8A8" opacity="0.5"/>

  <!-- ══ BODY (round fluffy ball) ══ -->
  <ellipse cx="250" cy="300" rx="115" ry="110" fill="url(#bodyG)"/>
  <!-- Belly highlight -->
  <ellipse cx="250" cy="315" rx="80" ry="70" fill="white" opacity="0.35"/>

  <!-- ══ FRONT PAWS ══ -->
  <ellipse cx="185" cy="360" rx="28" ry="20" fill="url(#pawG)"/>
  <ellipse cx="315" cy="360" rx="28" ry="20" fill="url(#pawG)"/>
  <!-- Tiny paw lines -->
  <line x1="178" y1="362" x2="178" y2="374" stroke="#E8C8A8" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>
  <line x1="185" y1="360" x2="185" y2="376" stroke="#E8C8A8" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>
  <line x1="192" y1="362" x2="192" y2="374" stroke="#E8C8A8" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>
  <line x1="310" y1="362" x2="310" y2="374" stroke="#E8C8A8" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>
  <line x1="317" y1="360" x2="317" y2="376" stroke="#E8C8A8" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>
  <line x1="324" y1="362" x2="324" y2="374" stroke="#E8C8A8" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>

  <!-- ══ EARS ══ -->
  <g class="ear-l">
    <path d="M175 160 Q155 80 165 55 Q175 35 195 75 Q200 95 205 140 Z" fill="url(#bodyG)"/>
    <path d="M178 150 Q163 85 170 62 Q178 45 192 78 Q196 95 200 135 Z" fill="#F8D0D0" opacity="0.6"/>
  </g>
  <g class="ear-r">
    <path d="M325 160 Q345 80 335 55 Q325 35 305 75 Q300 95 295 140 Z" fill="url(#bodyG)"/>
    <path d="M322 150 Q337 85 330 62 Q322 45 308 78 Q304 95 300 135 Z" fill="#F8D0D0" opacity="0.6"/>
  </g>

  <!-- ══ HEAD ══ -->
  <ellipse cx="250" cy="200" rx="85" ry="80" fill="url(#bodyG)"/>
  <!-- Head fluff (cheeks) -->
  <ellipse cx="185" cy="220" rx="30" ry="20" fill="url(#bodyG)"/>
  <ellipse cx="315" cy="220" rx="30" ry="20" fill="url(#bodyG)"/>

  <!-- ══ EYES (big sparkly) ══ -->
  <g>
    <!-- Left -->
    <g class="eye-l" style="transform-origin:222px 190px">
      <ellipse cx="222" cy="190" rx="16" ry="20" fill="white"/>
      <ellipse cx="223" cy="191" rx="14" ry="18" fill="url(#eyeG)"/>
      <ellipse cx="224" cy="192" rx="10" ry="13" fill="#1A0530"/>
      <circle cx="219" cy="184" r="6" fill="white" opacity="0.95"/>
      <circle cx="227" cy="194" r="3" fill="white" opacity="0.7"/>
      <circle cx="216" cy="195" r="1.5" fill="white" opacity="0.5"/>
    </g>
    <!-- Right -->
    <g class="eye-r" style="transform-origin:278px 190px">
      <ellipse cx="278" cy="190" rx="16" ry="20" fill="white"/>
      <ellipse cx="277" cy="191" rx="14" ry="18" fill="url(#eyeG)"/>
      <ellipse cx="276" cy="192" rx="10" ry="13" fill="#1A0530"/>
      <circle cx="273" cy="184" r="6" fill="white" opacity="0.95"/>
      <circle cx="273" cy="194" r="3" fill="white" opacity="0.7"/>
      <circle cx="284" cy="195" r="1.5" fill="white" opacity="0.5"/>
    </g>
    <!-- Brows -->
    <path class="brow-l" d="M208 172 Q222 164 236 171" stroke="#D0B090" stroke-width="2" fill="none" stroke-linecap="round" opacity="0.5"/>
    <path class="brow-r" d="M264 171 Q278 164 292 172" stroke="#D0B090" stroke-width="2" fill="none" stroke-linecap="round" opacity="0.5"/>
  </g>

  <!-- ══ BLUSH ══ -->
  <ellipse class="blush-l" cx="198" cy="208" rx="16" ry="8" fill="url(#blushG)" opacity="0.55"/>
  <ellipse class="blush-r" cx="302" cy="208" rx="16" ry="8" fill="url(#blushG)" opacity="0.55"/>

  <!-- ══ NOSE ══ -->
  <ellipse cx="250" cy="206" rx="8" ry="6" fill="url(#noseG)"/>
  <ellipse cx="247" cy="204" rx="3" ry="2" fill="white" opacity="0.5"/>

  <!-- ══ MOUTH (W shape) ══ -->
  <g class="mouth-g" id="mouth">
    <path d="M242 214 Q246 210 250 214 Q254 210 258 214" stroke="#C08080" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <ellipse cx="250" cy="218" rx="6" ry="3" fill="#C04050" opacity="0" id="mouthOpen"/>
  </g>

  <!-- ══ WHISKERS ══ -->
  <line x1="195" y1="205" x2="140" y2="198" stroke="#E0C8B0" stroke-width="1.2" stroke-linecap="round" opacity="0.5"/>
  <line x1="195" y1="210" x2="138" y2="212" stroke="#E0C8B0" stroke-width="1.2" stroke-linecap="round" opacity="0.5"/>
  <line x1="195" y1="215" x2="140" y2="225" stroke="#E0C8B0" stroke-width="1.2" stroke-linecap="round" opacity="0.5"/>
  <line x1="305" y1="205" x2="360" y2="198" stroke="#E0C8B0" stroke-width="1.2" stroke-linecap="round" opacity="0.5"/>
  <line x1="305" y1="210" x2="362" y2="212" stroke="#E0C8B0" stroke-width="1.2" stroke-linecap="round" opacity="0.5"/>
  <line x1="305" y1="215" x2="360" y2="225" stroke="#E0C8B0" stroke-width="1.2" stroke-linecap="round" opacity="0.5"/>

  <!-- ══ BOW (pink, on ear) ══ -->
  <g transform="translate(310,115)">
    <path d="M-12,-8 Q-18,-18 0,-16 Q18,-18 12,-8 Q8,-2 0,-4 Q-8,-2 -12,-8 Z" fill="#F8A0B8"/>
    <path d="M-12,8 Q-18,18 0,16 Q18,18 12,8 Q8,2 0,4 Q-8,2 -12,8 Z" fill="#F8A0B8"/>
    <circle cx="0" cy="0" r="4" fill="#E87090"/>
  </g>
</svg>

<script>
  const body=document.getElementById('body'),mouth=document.getElementById('mouth'),mo=document.getElementById('mouthOpen');
  let bt;
  function sb(){clearTimeout(bt);bt=setTimeout(()=>{body.classList.add('blink');setTimeout(()=>body.classList.remove('blink'),130);sb()},2500+Math.random()*4000)}
  sb();
  window.updateMouth=function(v){v=Math.min(1,Math.max(0,+v||0));mouth.style.transform='scaleY('+(0.1+v*1.8)+')';mo.setAttribute('opacity',v*.8);mo.setAttribute('ry',2+v*6)}
  window.setEmotion=function(e){body.className=body.className.replace(/em-\\w+/g,'').replace(/dance/g,'');if(e&&e!=='calm')body.classList.add('em-'+e)}
  window.setAnimState=function(s){body.classList.remove('dance');if(s==='dancing')body.classList.add('dance')}
</script>
</body>
</html>

''';
