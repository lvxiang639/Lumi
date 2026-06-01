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

  .girl{animation:breathe 3.2s ease-in-out infinite;transform-origin:250px 350px}
  @keyframes breathe{0%,100%{transform:translateY(0)}50%{transform:translateY(-5px)}}

  .hairL{animation:hL 3.6s ease-in-out infinite;transform-origin:250px 130px}
  .hairR{animation:hR 4s ease-in-out infinite;transform-origin:250px 130px}
  @keyframes hL{0%,100%{transform:rotate(0)}30%{transform:rotate(1.2deg)}70%{transform:rotate(-0.8deg)}}
  @keyframes hR{0%,100%{transform:rotate(0)}35%{transform:rotate(-1deg)}65%{transform:rotate(0.7deg)}}

  .dress{animation:dressS 2.6s ease-in-out infinite;transform-origin:250px 380px}
  @keyframes dressS{0%,100%{transform:rotate(0)}50%{transform:rotate(1.2deg)}}

  .eye-l,.eye-r{transform-origin:center}
  .blink .eye-l,.blink .eye-r{animation:blink 0.12s ease-in-out}
  @keyframes blink{0%,100%{transform:scaleY(1)}50%{transform:scaleY(0.04)}}

  .mouth-g{transform-origin:250px 175px;transition:transform .05s ease-out}

  .em-joy .eye-l,.em-joy .eye-r{transform:scaleY(0.78)}
  .em-joy .blush-l,.em-joy .blush-r{opacity:1}
  .em-sad .brow-l{transform:translateY(4px) rotate(-8deg)}.em-sad .brow-r{transform:translateY(4px) rotate(8deg)}
  .em-angry .brow-l{transform:translateY(-5px) rotate(7deg)}.em-angry .brow-r{transform:translateY(-5px) rotate(-7deg)}
  .em-surprised .eye-l,.em-surprised .eye-r{transform:scale(1.2)}
  .em-worried .brow-l{transform:translateY(3px) rotate(-3deg)}.em-worried .brow-r{transform:translateY(3px) rotate(3deg)}

  .dance .girl{animation:danceB .5s ease-in-out infinite}
  .dance .dress{animation:danceSk .4s ease-in-out infinite}
  @keyframes danceB{0%,100%{transform:translateY(0) rotate(-2deg)}25%{transform:translateY(-12px) rotate(0)}50%{transform:translateY(0) rotate(2deg)}75%{transform:translateY(-7px) rotate(0)}}
  @keyframes danceSk{0%,100%{transform:rotate(-5deg)}50%{transform:rotate(5deg)}}
</style>
</head>
<body id="body">

<svg viewBox="0 0 500 750" class="girl">
  <defs>
    <radialGradient id="skin" cx="50%" cy="35%"><stop offset="0%" stop-color="#FFFBF8"/><stop offset="55%" stop-color="#FEEAD8"/><stop offset="100%" stop-color="#F0C498"/></radialGradient>
    <linearGradient id="hairG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#5A3828"/><stop offset="25%" stop-color="#482618"/><stop offset="60%" stop-color="#361810"/><stop offset="100%" stop-color="#240C06"/></linearGradient>
    <linearGradient id="hairHL" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#8A6858"/><stop offset="35%" stop-color="#684838"/><stop offset="100%" stop-color="#482618"/></linearGradient>
    <radialGradient id="eyeG" cx="50%" cy="32%"><stop offset="0%" stop-color="#9578D0"/><stop offset="25%" stop-color="#6B48B0"/><stop offset="60%" stop-color="#4A2890"/><stop offset="100%" stop-color="#2A1050"/></radialGradient>
    <radialGradient id="eyeSh" cx="35%" cy="22%"><stop offset="0%" stop-color="white" stop-opacity="1"/><stop offset="50%" stop-color="white" stop-opacity="0.6"/><stop offset="100%" stop-color="white" stop-opacity="0"/></radialGradient>
    <linearGradient id="dressG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#F8A0B8"/><stop offset="20%" stop-color="#F0809C"/><stop offset="60%" stop-color="#E87090"/><stop offset="100%" stop-color="#D46080"/></linearGradient>
    <linearGradient id="dressBodice" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#F8B0C8"/><stop offset="100%" stop-color="#F090A8"/></linearGradient>
    <radialGradient id="blushG" cx="50%" cy="50%"><stop offset="0%" stop-color="#FF9090" stop-opacity="0.35"/><stop offset="100%" stop-color="#FF9090" stop-opacity="0"/></radialGradient>
    <linearGradient id="legG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FEEAD8"/><stop offset="100%" stop-color="#F3C898"/></linearGradient>
    <linearGradient id="heelG" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#E88090"/><stop offset="100%" stop-color="#C05060"/></linearGradient>
  </defs>

  <!-- ══ BACK HAIR ══ -->
  <g>
    <path d="M190 105 Q170 95 148 135 Q128 190 118 260 Q108 350 106 440 Q105 510 115 560 Q130 575 155 560 Q145 510 140 430 Q134 340 138 250 Q144 180 160 135 Z" fill="url(#hairG)"/>
    <path d="M310 105 Q330 95 352 135 Q372 190 382 260 Q392 350 394 440 Q395 510 385 560 Q370 575 345 560 Q355 510 360 430 Q366 340 362 250 Q356 180 340 135 Z" fill="url(#hairG)"/>
    <path d="M200 150 Q178 260 172 370 Q168 450 178 540 Q195 555 210 540 Q200 460 198 370 Q195 260 205 150 Z" fill="#2E160E"/>
    <path d="M300 150 Q322 260 328 370 Q332 450 322 540 Q305 555 290 540 Q300 460 302 370 Q305 260 295 150 Z" fill="#2E160E"/>
  </g>

  <!-- ══ LEGS ══ -->
  <g>
    <path d="M210 480 L208 650 Q207 660 215 660 L235 660 Q243 660 242 650 L244 480 Z" fill="url(#legG)"/>
    <path d="M256 480 L258 650 Q259 660 267 660 L287 660 Q295 660 294 650 L292 480 Z" fill="url(#legG)"/>
    <ellipse cx="224" cy="540" rx="7" ry="3" fill="white" opacity="0.1"/>
    <ellipse cx="276" cy="540" rx="7" ry="3" fill="white" opacity="0.1"/>
  </g>

  <!-- ══ HIGH HEELS ══ -->
  <g>
    <!-- Left heel -->
    <path d="M200 655 L198 668 Q197 674 206 676 L236 676 Q245 674 244 668 L242 655 Z" fill="url(#heelG)"/>
    <path d="M208 676 L206 690 Q208 694 216 692 L228 692 Q236 694 234 690 L232 676 Z" fill="#A04050"/>
    <!-- Right heel -->
    <path d="M256 655 L258 668 Q259 674 268 676 L298 676 Q307 674 306 668 L304 655 Z" fill="url(#heelG)"/>
    <path d="M270 676 L272 690 Q274 694 282 692 L294 692 Q302 694 300 690 L298 676 Z" fill="#A04050"/>
  </g>

  <!-- ══ ARMS ══ -->
  <g style="transform-origin:172px 320px">
    <path d="M174 325 Q150 360 142 410 Q138 428 144 434" stroke="url(#skin)" stroke-width="14" stroke-linecap="round" fill="none"/>
    <ellipse cx="144" cy="440" rx="10" ry="8" fill="url(#skin)"/>
    <path d="M174 325 Q154 350 148 380" stroke="#F090A8" stroke-width="16" stroke-linecap="round" fill="none" opacity="0.25"/>
  </g>
  <g style="transform-origin:328px 320px">
    <path d="M326 325 Q350 360 358 410 Q362 428 356 434" stroke="url(#skin)" stroke-width="14" stroke-linecap="round" fill="none"/>
    <ellipse cx="356" cy="440" rx="10" ry="8" fill="url(#skin)"/>
    <path d="M326 325 Q346 350 352 380" stroke="#F090A8" stroke-width="16" stroke-linecap="round" fill="none" opacity="0.25"/>
  </g>

  <!-- ══ PINK DRESS BODICE ══ -->
  <g>
    <rect x="234" y="290" width="32" height="18" rx="8" fill="url(#skin)"/>
    <ellipse cx="250" cy="305" rx="14" ry="3" fill="#E8C0A0" opacity="0.25"/>
    <!-- Bodice -->
    <path d="M162 312 Q152 370 155 420 L345 420 Q348 370 338 312 Z" fill="url(#dressBodice)"/>
    <!-- White collar -->
    <path d="M185 312 L250 350 L315 312" stroke="white" stroke-width="4" fill="none" opacity="0.6"/>
    <!-- Bow -->
    <path d="M240 332 L250 350 L260 332" stroke="#E86080" stroke-width="3" fill="none" stroke-linecap="round"/>
    <circle cx="250" cy="342" r="6" fill="#E86080"/>
    <!-- Waist ribbon -->
    <rect x="156" y="416" width="188" height="10" rx="4" fill="#E86080"/>
    <rect x="242" y="414" width="16" height="14" rx="3" fill="#FFD0D8"/>
  </g>

  <!-- ══ PINK DRESS SKIRT (KNEE LENGTH) ══ -->
  <g class="dress">
    <path d="M155 422 Q142 490 135 560 L365 560 Q358 490 345 422 Z" fill="url(#dressG)"/>
    <!-- Dress folds -->
    <line x1="180" y1="428" x2="170" y2="558" stroke="#D47088" stroke-width="0.8" opacity="0.4"/>
    <line x1="215" y1="424" x2="215" y2="560" stroke="#D47088" stroke-width="0.8" opacity="0.4"/>
    <line x1="250" y1="422" x2="250" y2="560" stroke="#D47088" stroke-width="0.8" opacity="0.4"/>
    <line x1="285" y1="424" x2="285" y2="560" stroke="#D47088" stroke-width="0.8" opacity="0.4"/>
    <line x1="320" y1="428" x2="330" y2="558" stroke="#D47088" stroke-width="0.8" opacity="0.4"/>
    <!-- Hem ruffle -->
    <path d="M133 556 Q250 578 367 556" stroke="#F8C0D0" stroke-width="3" fill="none" opacity="0.5"/>
    <path d="M134 560 Q250 575 366 560" stroke="white" stroke-width="1" fill="none" opacity="0.15"/>
  </g>

  <!-- ══ HEAD ══ -->
  <g>
    <ellipse cx="250" cy="145" rx="68" ry="76" fill="url(#skin)"/>
    <ellipse cx="250" cy="212" rx="19" ry="5" fill="#E8C0A0" opacity="0.2"/>
  </g>

  <!-- ══ EYES ══ -->
  <g>
    <!-- Left -->
    <g class="eye-l" style="transform-origin:217px 140px">
      <ellipse cx="217" cy="140" rx="20" ry="26" fill="white"/>
      <ellipse cx="218" cy="141" rx="18" ry="24" fill="url(#eyeG)"/>
      <ellipse cx="219" cy="142" rx="13" ry="18" fill="#1A0530"/>
      <circle cx="212" cy="132" r="7.5" fill="url(#eyeSh)"/>
      <circle cx="224" cy="147" r="4.5" fill="white" opacity="0.65"/>
      <circle cx="209" cy="148" r="1.8" fill="white" opacity="0.45"/>
      <path d="M197 129 Q218 110 239 129" stroke="#1A1028" stroke-width="4.5" fill="none" stroke-linecap="round"/>
      <path d="M200 150 Q218 166 236 150" stroke="#3A2A4A" stroke-width="1.5" fill="none" opacity="0.4"/>
      <path d="M199 124 Q218 113 237 124" stroke="#D8B898" stroke-width="1" fill="none" opacity="0.25"/>
    </g>
    <!-- Right -->
    <g class="eye-r" style="transform-origin:283px 140px">
      <ellipse cx="283" cy="140" rx="20" ry="26" fill="white"/>
      <ellipse cx="282" cy="141" rx="18" ry="24" fill="url(#eyeG)"/>
      <ellipse cx="281" cy="142" rx="13" ry="18" fill="#1A0530"/>
      <circle cx="278" cy="132" r="7.5" fill="url(#eyeSh)"/>
      <circle cx="276" cy="147" r="4.5" fill="white" opacity="0.65"/>
      <circle cx="291" cy="148" r="1.8" fill="white" opacity="0.45"/>
      <path d="M261 129 Q283 110 303 129" stroke="#1A1028" stroke-width="4.5" fill="none" stroke-linecap="round"/>
      <path d="M264 150 Q283 166 300 150" stroke="#3A2A4A" stroke-width="1.5" fill="none" opacity="0.4"/>
      <path d="M263 124 Q283 113 301 124" stroke="#D8B898" stroke-width="1" fill="none" opacity="0.25"/>
    </g>
    <!-- Brows -->
    <path class="brow-l" d="M202 112 Q220 101 240 113" stroke="#4A3020" stroke-width="2.8" fill="none" stroke-linecap="round" opacity="0.65"/>
    <path class="brow-r" d="M260 113 Q280 101 298 112" stroke="#4A3020" stroke-width="2.8" fill="none" stroke-linecap="round" opacity="0.65"/>
  </g>

  <!-- ══ BLUSH ══ -->
  <ellipse class="blush-l" cx="194" cy="162" rx="19" ry="10" fill="url(#blushG)" opacity="0.5"/>
  <ellipse class="blush-r" cx="306" cy="162" rx="19" ry="10" fill="url(#blushG)" opacity="0.5"/>

  <!-- ══ NOSE ══ -->
  <path d="M247 153 L244 162 Q250 165 256 162 L253 153" stroke="#D8B090" stroke-width="0.8" fill="none" opacity="0.35"/>

  <!-- ══ MOUTH ══ -->
  <g class="mouth-g" id="mouth">
    <path d="M236 170 Q250 178 264 170" stroke="#D08090" stroke-width="2.2" fill="none" stroke-linecap="round"/>
    <ellipse cx="250" cy="178" rx="13" ry="4" fill="#B04050" opacity="0" id="mouthOpen"/>
  </g>

  <!-- ══ FRONT HAIR ══ -->
  <g>
    <!-- Bangs -->
    <path d="M182 118 Q178 52 198 28 Q220 4 250 6 Q280 4 302 28 Q322 52 318 118
             Q314 82 296 70 Q276 54 250 56 Q224 54 204 70 Q186 82 182 118 Z" fill="url(#hairHL)"/>
    <path d="M184 115 Q180 54 200 32 Q222 8 250 10 Q278 8 300 32 Q320 54 316 115
             Q312 80 294 68 Q274 52 250 54 Q226 52 206 68 Q188 80 184 115 Z" fill="url(#hairG)"/>
    <!-- Side strands -->
    <g class="hairL">
      <path d="M184 112 Q160 98 144 78 Q132 110 126 180 Q122 260 130 370 Q134 430 142 500" fill="none" stroke="url(#hairG)" stroke-width="22" stroke-linecap="round"/>
      <path d="M184 112 Q160 98 144 78 Q132 110 126 180 Q122 260 130 370 Q134 430 142 500" fill="none" stroke="url(#hairHL)" stroke-width="3" stroke-linecap="round" opacity="0.25"/>
    </g>
    <g class="hairR">
      <path d="M316 112 Q340 98 356 78 Q368 110 374 180 Q378 260 370 370 Q366 430 358 500" fill="none" stroke="url(#hairG)" stroke-width="22" stroke-linecap="round"/>
      <path d="M316 112 Q340 98 356 78 Q368 110 374 180 Q378 260 370 370 Q366 430 358 500" fill="none" stroke="url(#hairHL)" stroke-width="3" stroke-linecap="round" opacity="0.25"/>
    </g>
    <!-- Ahoge -->
    <path d="M254 12 Q268 -18 286 -24" stroke="url(#hairG)" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M254 12 Q268 -18 286 -24" stroke="#8A6858" stroke-width="1.2" fill="none" stroke-linecap="round" opacity="0.35"/>
    <!-- Pink hair clip -->
    <circle cx="158" cy="148" r="6" fill="#F8A0B8" opacity="0.85"/>
    <circle cx="342" cy="148" r="6" fill="#F8A0B8" opacity="0.85"/>
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
