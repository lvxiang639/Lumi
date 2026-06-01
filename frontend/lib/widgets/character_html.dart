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

  .girl{animation:breathe 3.2s ease-in-out infinite;transform-origin:250px 380px}
  @keyframes breathe{0%,100%{transform:translateY(0)}50%{transform:translateY(-5px)}}

  .hair-flow-l{animation:hairL 3.8s ease-in-out infinite;transform-origin:250px 130px}
  .hair-flow-r{animation:hairR 4.1s ease-in-out infinite;transform-origin:250px 130px}
  @keyframes hairL{0%,100%{transform:rotate(0)}25%{transform:rotate(1deg)}75%{transform:rotate(-0.7deg)}}
  @keyframes hairR{0%,100%{transform:rotate(0)}30%{transform:rotate(-0.8deg)}70%{transform:rotate(0.6deg)}}

  .skirt-g{animation:skirt 2.5s ease-in-out infinite;transform-origin:250px 310px}
  @keyframes skirt{0%,100%{transform:rotate(0)}50%{transform:rotate(1.5deg)}}

  .eye-l,.eye-r{transform-origin:center}
  .blink .eye-l,.blink .eye-r{animation:blink 0.12s ease-in-out}
  @keyframes blink{0%,100%{transform:scaleY(1)}50%{transform:scaleY(0.04)}}

  .mouth-g{transform-origin:250px 170px;transition:transform .05s ease-out}

  /* emotions */
  .em-joy .eye-l,.em-joy .eye-r{transform:scaleY(0.78)}
  .em-joy .blush-l,.em-joy .blush-r{opacity:1}
  .em-sad .brow-l{transform:translateY(4px) rotate(-8deg)}.em-sad .brow-r{transform:translateY(4px) rotate(8deg)}
  .em-angry .brow-l{transform:translateY(-5px) rotate(7deg)}.em-angry .brow-r{transform:translateY(-5px) rotate(-7deg)}
  .em-surprised .eye-l,.em-surprised .eye-r{transform:scale(1.2)}
  .em-worried .brow-l{transform:translateY(3px) rotate(-3deg)}.em-worried .brow-r{transform:translateY(3px) rotate(3deg)}

  .dance .girl{animation:danceB .5s ease-in-out infinite}
  .dance .skirt-g{animation:danceSk .4s ease-in-out infinite}
  @keyframes danceB{0%,100%{transform:translateY(0) rotate(-2deg)}25%{transform:translateY(-12px) rotate(0)}50%{transform:translateY(0) rotate(2deg)}75%{transform:translateY(-7px) rotate(0)}}
  @keyframes danceSk{0%,100%{transform:rotate(-6deg)}50%{transform:rotate(6deg)}}
</style>
</head>
<body id="body">

<svg viewBox="0 0 500 800" class="girl">
  <defs>
    <radialGradient id="skin" cx="50%" cy="30%"><stop offset="0%" stop-color="#FFFBF7"/><stop offset="60%" stop-color="#FEE9D2"/><stop offset="100%" stop-color="#F2C9A0"/></radialGradient>
    <linearGradient id="hairG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#5C3A2E"/><stop offset="30%" stop-color="#4A2A1E"/><stop offset="70%" stop-color="#3A1E14"/><stop offset="100%" stop-color="#2A120A"/></linearGradient>
    <linearGradient id="hairHL" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#8C6A5E"/><stop offset="40%" stop-color="#6A4A3E"/><stop offset="100%" stop-color="#4A2A1E"/></linearGradient>
    <linearGradient id="hairTip" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#4A2A1E"/><stop offset="100%" stop-color="#6A4A3E"/></linearGradient>
    <radialGradient id="eyeG" cx="50%" cy="35%"><stop offset="0%" stop-color="#8B6FC0"/><stop offset="30%" stop-color="#5B3FA0"/><stop offset="70%" stop-color="#3A1F70"/><stop offset="100%" stop-color="#200840"/></radialGradient>
    <radialGradient id="eyeShine" cx="35%" cy="25%"><stop offset="0%" stop-color="white" stop-opacity="1"/><stop offset="60%" stop-color="white" stop-opacity="0.6"/><stop offset="100%" stop-color="white" stop-opacity="0"/></radialGradient>
    <linearGradient id="topG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#F0E0D0"/><stop offset="100%" stop-color="#E8D0B8"/></linearGradient>
    <linearGradient id="skirtG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#3A2850"/><stop offset="50%" stop-color="#2D1E40"/><stop offset="100%" stop-color="#1E1430"/></linearGradient>
    <radialGradient id="blushG" cx="50%" cy="50%"><stop offset="0%" stop-color="#FFA0A0" stop-opacity="0.4"/><stop offset="100%" stop-color="#FFA0A0" stop-opacity="0"/></radialGradient>
    <linearGradient id="legG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FEE9D2"/><stop offset="100%" stop-color="#F5CFA8"/></linearGradient>
  </defs>

  <!-- ═══════ LONG FLOWING BACK HAIR ═══════ -->
  <g class="hair-back">
    <path d="M190 105 Q170 95 150 135 Q130 190 120 260 Q110 350 108 430 Q106 480 115 520 Q130 530 150 520 Q140 480 135 430 Q128 350 132 260 Q138 190 155 140 Z" fill="url(#hairG)"/>
    <path d="M310 105 Q330 95 350 135 Q370 190 380 260 Q390 350 392 430 Q394 480 385 520 Q370 530 350 520 Q360 480 365 430 Q372 350 368 260 Q362 190 345 140 Z" fill="url(#hairG)"/>
    <!-- Middle back hair -->
    <path d="M200 160 Q180 280 175 380 Q172 460 180 510 L320 510 Q328 460 325 380 Q320 280 300 160 Z" fill="#2E1A10"/>
    <!-- Side back strands -->
    <path d="M160 200 Q140 300 135 400 Q132 480 142 530 Q155 540 158 520 Q152 450 155 380 Q160 280 168 200 Z" fill="#3A1E14" opacity="0.7"/>
    <path d="M340 200 Q360 300 365 400 Q368 480 358 530 Q345 540 342 520 Q348 450 345 380 Q340 280 332 200 Z" fill="#3A1E14" opacity="0.7"/>
  </g>

  <!-- ═══════ LEGS (LONG) ═══════ -->
  <g class="legs-g">
    <!-- Left leg -->
    <path d="M210 390 L208 620 Q207 630 214 630 L234 630 Q241 630 240 620 L242 390 Z" fill="url(#legG)"/>
    <!-- Right leg -->
    <path d="M258 390 L260 620 Q261 630 268 630 L288 630 Q295 630 294 620 L292 390 Z" fill="url(#legG)"/>
    <!-- Knee highlights -->
    <ellipse cx="223" cy="480" rx="7" ry="3" fill="white" opacity="0.12"/>
    <ellipse cx="277" cy="480" rx="7" ry="3" fill="white" opacity="0.12"/>
    <!-- Left sock (knee-high) -->
    <path d="M208 540 L210 635 L238 635 L240 540 Z" fill="#F8F8F8"/>
    <line x1="210" y1="558" x2="238" y2="558" stroke="#E0E0E0" stroke-width="0.7"/>
    <line x1="210" y1="578" x2="238" y2="578" stroke="#E0E0E0" stroke-width="0.7"/>
    <line x1="210" y1="598" x2="238" y2="598" stroke="#E0E0E0" stroke-width="0.7"/>
    <line x1="210" y1="618" x2="238" y2="618" stroke="#E0E0E0" stroke-width="0.7"/>
    <!-- Right sock -->
    <path d="M260 540 L262 635 L290 635 L292 540 Z" fill="#F8F8F8"/>
    <line x1="262" y1="558" x2="290" y2="558" stroke="#E0E0E0" stroke-width="0.7"/>
    <line x1="262" y1="578" x2="290" y2="578" stroke="#E0E0E0" stroke-width="0.7"/>
    <line x1="262" y1="598" x2="290" y2="598" stroke="#E0E0E0" stroke-width="0.7"/>
    <line x1="262" y1="618" x2="290" y2="618" stroke="#E0E0E0" stroke-width="0.7"/>
  </g>

  <!-- ═══════ SHOES ═══════ -->
  <path d="M198 628 Q193 638 204 643 L236 643 Q247 638 244 628 Z" fill="#3A2020"/>
  <path d="M256 628 Q253 638 264 643 L296 643 Q307 638 302 628 Z" fill="#3A2020"/>
  <ellipse cx="221" cy="630" rx="5" ry="2" fill="#5A4040" opacity="0.4"/>
  <ellipse cx="279" cy="630" rx="5" ry="2" fill="#5A4040" opacity="0.4"/>

  <!-- ═══════ ARMS ═══════ -->
  <g style="transform-origin:175px 280px">
    <path d="M178 285 Q155 315 148 365 Q145 380 150 388" stroke="url(#skin)" stroke-width="15" stroke-linecap="round" fill="none"/>
    <ellipse cx="150" cy="394" rx="11" ry="9" fill="url(#skin)"/>
    <path d="M178 285 Q158 308 152 335" stroke="#E8D0B8" stroke-width="17" stroke-linecap="round" fill="none" opacity="0.3"/>
  </g>
  <g style="transform-origin:325px 280px">
    <path d="M322 285 Q345 315 352 365 Q355 380 350 388" stroke="url(#skin)" stroke-width="15" stroke-linecap="round" fill="none"/>
    <ellipse cx="350" cy="394" rx="11" ry="9" fill="url(#skin)"/>
    <path d="M322 285 Q342 308 348 335" stroke="#E8D0B8" stroke-width="17" stroke-linecap="round" fill="none" opacity="0.3"/>
  </g>

  <!-- ═══════ BODY ═══════ -->
  <g>
    <!-- Neck -->
    <rect x="235" y="250" width="30" height="18" rx="7" fill="url(#skin)"/>
    <ellipse cx="250" cy="264" rx="13" ry="3" fill="#E8C0A0" opacity="0.3"/>
    <!-- Torso -->
    <path d="M168 272 Q160 330 165 380 L335 380 Q340 330 332 272 Z" fill="url(#topG)"/>
    <!-- Collar -->
    <path d="M188 272 L250 305 L312 272" stroke="white" stroke-width="2.5" fill="none" opacity="0.3"/>
    <!-- Neck ribbon -->
    <path d="M235 288 L250 310 L265 288" stroke="#D44060" stroke-width="2.5" fill="none" stroke-linecap="round"/>
    <circle cx="250" cy="300" r="5" fill="#D44060"/>
    <!-- Belt -->
    <rect x="167" y="374" width="166" height="10" rx="3" fill="#1A1225"/>
    <rect x="242" y="372" width="16" height="14" rx="3" fill="#D4B060"/>
  </g>

  <!-- ═══════ SKIRT ═══════ -->
  <g class="skirt-g">
    <path d="M165 378 Q155 440 140 510 L360 510 Q345 440 335 378 Z" fill="url(#skirtG)"/>
    <!-- Pleats -->
    <line x1="188" y1="384" x2="178" y2="508" stroke="#4A3870" stroke-width="0.8" opacity="0.5"/>
    <line x1="218" y1="380" x2="218" y2="510" stroke="#4A3870" stroke-width="0.8" opacity="0.5"/>
    <line x1="250" y1="378" x2="250" y2="510" stroke="#4A3870" stroke-width="0.8" opacity="0.5"/>
    <line x1="282" y1="380" x2="282" y2="510" stroke="#4A3870" stroke-width="0.8" opacity="0.5"/>
    <line x1="312" y1="384" x2="322" y2="508" stroke="#4A3870" stroke-width="0.8" opacity="0.5"/>
    <path d="M138 506 Q250 524 362 506" stroke="#5A4090" stroke-width="1.5" fill="none" opacity="0.35"/>
  </g>

  <!-- ═══════ HEAD ═══════ -->
  <g>
    <ellipse cx="250" cy="145" rx="66" ry="74" fill="url(#skin)"/>
    <ellipse cx="250" cy="208" rx="18" ry="5" fill="#E8C0A0" opacity="0.22"/>
  </g>

  <!-- ═══════ BIG ANIME EYES ═══════ -->
  <g>
    <!-- Left eye -->
    <g class="eye-l" style="transform-origin:218px 140px">
      <!-- White -->
      <ellipse cx="218" cy="140" rx="19" ry="25" fill="white"/>
      <!-- Iris gradient -->
      <ellipse cx="219" cy="141" rx="17" ry="23" fill="url(#eyeG)"/>
      <!-- Pupil -->
      <ellipse cx="220" cy="142" rx="12" ry="17" fill="#1A0530"/>
      <!-- Main shine -->
      <circle cx="213" cy="133" r="7" fill="white" opacity="0.95"/>
      <!-- Secondary shine -->
      <circle cx="225" cy="146" r="4" fill="white" opacity="0.7"/>
      <!-- Tiny sparkle -->
      <circle cx="210" cy="147" r="1.5" fill="white" opacity="0.5"/>
      <!-- Upper lash -->
      <path d="M199 130 Q218 112 238 130" stroke="#1A1028" stroke-width="4" fill="none" stroke-linecap="round"/>
      <!-- Lower lash -->
      <path d="M202 150 Q218 165 234 150" stroke="#3A2A4A" stroke-width="1.5" fill="none" opacity="0.45"/>
      <!-- Eyelid fold -->
      <path d="M200 125 Q218 115 236 125" stroke="#E0C0A0" stroke-width="1" fill="none" opacity="0.3"/>
    </g>
    <!-- Right eye -->
    <g class="eye-r" style="transform-origin:282px 140px">
      <ellipse cx="282" cy="140" rx="19" ry="25" fill="white"/>
      <ellipse cx="281" cy="141" rx="17" ry="23" fill="url(#eyeG)"/>
      <ellipse cx="280" cy="142" rx="12" ry="17" fill="#1A0530"/>
      <circle cx="275" cy="133" r="7" fill="white" opacity="0.95"/>
      <circle cx="275" cy="146" r="4" fill="white" opacity="0.7"/>
      <circle cx="290" cy="147" r="1.5" fill="white" opacity="0.5"/>
      <path d="M262 130 Q282 112 301 130" stroke="#1A1028" stroke-width="4" fill="none" stroke-linecap="round"/>
      <path d="M266 150 Q282 165 298 150" stroke="#3A2A4A" stroke-width="1.5" fill="none" opacity="0.45"/>
      <path d="M264 125 Q282 115 300 125" stroke="#E0C0A0" stroke-width="1" fill="none" opacity="0.3"/>
    </g>
    <!-- Eyebrows -->
    <path class="brow-l" d="M204 113 Q220 103 238 114" stroke="#4A3020" stroke-width="2.5" fill="none" stroke-linecap="round" opacity="0.7"/>
    <path class="brow-r" d="M262 114 Q280 103 296 113" stroke="#4A3020" stroke-width="2.5" fill="none" stroke-linecap="round" opacity="0.7"/>
  </g>

  <!-- ═══════ BLUSH ═══════ -->
  <ellipse class="blush-l" cx="196" cy="160" rx="18" ry="9" fill="url(#blushG)" opacity="0.55"/>
  <ellipse class="blush-r" cx="304" cy="160" rx="18" ry="9" fill="url(#blushG)" opacity="0.55"/>

  <!-- ═══════ NOSE ═══════ -->
  <path d="M247 152 L245 160 Q250 163 255 160 L253 152" stroke="#E0B890" stroke-width="0.8" fill="none" opacity="0.4"/>

  <!-- ═══════ MOUTH ═══════ -->
  <g class="mouth-g" id="mouth">
    <path d="M237 168 Q250 175 263 168" stroke="#D08090" stroke-width="2" fill="none" stroke-linecap="round"/>
    <ellipse cx="250" cy="175" rx="12" ry="3.5" fill="#B04050" opacity="0" id="mouthOpen"/>
  </g>

  <!-- ═══════ FRONT HAIR (BROWN, FLOWING) ═══════ -->
  <g>
    <!-- Main bangs -->
    <path d="M184 118 Q180 58 198 36 Q218 14 250 16 Q282 14 302 36 Q320 58 316 118
             Q312 88 296 76 Q278 62 250 64 Q222 62 204 76 Q188 88 184 118 Z" fill="url(#hairHL)"/>
    <path d="M186 115 Q182 60 200 40 Q218 18 250 20 Q282 18 300 40 Q318 60 314 115
             Q310 85 294 73 Q276 60 250 62 Q224 60 206 73 Q190 85 186 115 Z" fill="url(#hairG)"/>
    <!-- Side strands -->
    <g class="hair-flow-l">
      <path d="M186 113 Q164 100 150 82 Q138 110 132 175 Q128 250 135 350 Q138 400 145 450" fill="none" stroke="url(#hairG)" stroke-width="20" stroke-linecap="round"/>
      <path d="M186 113 Q164 100 150 82 Q138 110 132 175 Q128 250 135 350 Q138 400 145 450" fill="none" stroke="url(#hairHL)" stroke-width="3" stroke-linecap="round" opacity="0.3"/>
    </g>
    <g class="hair-flow-r">
      <path d="M314 113 Q336 100 350 82 Q362 110 368 175 Q372 250 365 350 Q362 400 355 450" fill="none" stroke="url(#hairG)" stroke-width="20" stroke-linecap="round"/>
      <path d="M314 113 Q336 100 350 82 Q362 110 368 175 Q372 250 365 350 Q362 400 355 450" fill="none" stroke="url(#hairHL)" stroke-width="3" stroke-linecap="round" opacity="0.3"/>
    </g>
    <!-- Ahoge -->
    <path d="M254 22 Q265 -2 282 -6" stroke="url(#hairG)" stroke-width="3.5" fill="none" stroke-linecap="round"/>
    <path d="M254 22 Q265 -2 282 -6" stroke="#8C6A5E" stroke-width="1" fill="none" stroke-linecap="round" opacity="0.4"/>
  </g>
</svg>

<script>
  const body=document.getElementById('body'),mouth=document.getElementById('mouth'),mo=document.getElementById('mouthOpen');
  let bt;
  function sb(){clearTimeout(bt);bt=setTimeout(()=>{body.classList.add('blink');setTimeout(()=>body.classList.remove('blink'),130);sb()},2600+Math.random()*3400)}
  sb();
  window.updateMouth=function(v){v=Math.min(1,Math.max(0,+v||0));mouth.style.transform='scaleY('+(0.15+v*1.6)+')';mo.setAttribute('opacity',v*.8);mo.setAttribute('ry',2+v*8)}
  window.setEmotion=function(e){body.className=body.className.replace(/em-\\w+/g,'').replace(/dance/g,'');if(e&&e!=='calm')body.classList.add('em-'+e)}
  window.setAnimState=function(s){body.classList.remove('dance');if(s==='dancing')body.classList.add('dance')}
</script>
</body>
</html>

''';
