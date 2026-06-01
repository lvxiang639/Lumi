const String kCharacterHtml = r'''
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<style>
  :root { --mouth:0; --emotion:calm; }
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:transparent;display:flex;justify-content:center;align-items:center;height:100vh;overflow:hidden;-webkit-user-select:none;user-select:none}
  svg{max-height:100vh;max-width:100vw}

  /* Breathing */
  .char-body{animation:breathe 3.4s ease-in-out infinite;transform-origin:250px 320px}
  @keyframes breathe{0%,100%{transform:translateY(0)}50%{transform:translateY(-7px)}}

  /* Hair sway */
  .hair-l{animation:hairL 3.6s ease-in-out infinite;transform-origin:250px 140px}
  .hair-r{animation:hairR 3.9s ease-in-out infinite;transform-origin:250px 140px}
  @keyframes hairL{0%,100%{transform:rotate(0)}30%{transform:rotate(1.2deg)}70%{transform:rotate(-0.8deg)}}
  @keyframes hairR{0%,100%{transform:rotate(0)}35%{transform:rotate(-1deg)}65%{transform:rotate(0.9deg)}}

  /* Skirt */
  .skirt{animation:skirtS 2.6s ease-in-out infinite;transform-origin:250px 280px}
  @keyframes skirtS{0%,100%{transform:rotate(0)}50%{transform:rotate(1.8deg)}}

  /* Blink */
  .eye-l,.eye-r{transform-origin:center}
  .blink .eye-l,.blink .eye-r{animation:blink 0.12s ease-in-out}
  @keyframes blink{0%,100%{transform:scaleY(1)}50%{transform:scaleY(0.05)}}

  /* Mouth */
  .mouth-g{transform-origin:250px 170px;transition:transform .06s ease-out}

  /* Emotions */
  .em-joy .blush-l,.em-joy .blush-r{opacity:1}
  .em-joy .eye-l,.em-joy .eye-r{transform:scaleY(0.8)}
  .em-sad .eyebrow-l{transform:translateY(3px) rotate(-8deg)}
  .em-sad .eyebrow-r{transform:translateY(3px) rotate(8deg)}
  .em-angry .eyebrow-l{transform:translateY(-5px) rotate(8deg)}
  .em-angry .eyebrow-r{transform:translateY(-5px) rotate(-8deg)}
  .em-surprised .eye-l,.em-surprised .eye-r{transform:scale(1.18)}
  .em-surprised .mouth-g{transform:scaleY(1.6)}
  .em-worried .eyebrow-l{transform:translateY(2px) rotate(-4deg)}
  .em-worried .eyebrow-r{transform:translateY(2px) rotate(4deg)}

  /* Dancing */
  .dance .char-body{animation:danceB .5s ease-in-out infinite}
  .dance .skirt{animation:danceSk .4s ease-in-out infinite}
  .dance .hair-l,.dance .hair-r{animation:danceH .45s ease-in-out infinite}
  @keyframes danceB{0%,100%{transform:translateY(0) rotate(-3deg)}25%{transform:translateY(-14px) rotate(0)}50%{transform:translateY(0) rotate(3deg)}75%{transform:translateY(-8px) rotate(0)}}
  @keyframes danceSk{0%,100%{transform:rotate(-8deg)}50%{transform:rotate(8deg)}}
  @keyframes danceH{0%,100%{transform:rotate(-6deg)}50%{transform:rotate(6deg)}}
</style>
</head>
<body id="body">

<svg viewBox="0 0 500 700" class="char-body">
  <defs>
    <radialGradient id="skin" cx="50%" cy="35%"><stop offset="0%" stop-color="#FFF8F0"/><stop offset="70%" stop-color="#FDE4CF"/><stop offset="100%" stop-color="#F5C8A0"/></radialGradient>
    <linearGradient id="hair" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#3C2A40"/><stop offset="50%" stop-color="#2D1A30"/><stop offset="100%" stop-color="#1A0E1E"/></linearGradient>
    <linearGradient id="hairShine" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#6A5070"/><stop offset="50%" stop-color="#5A4060"/><stop offset="100%" stop-color="#3C2A40"/></linearGradient>
    <radialGradient id="eye" cx="50%" cy="40%"><stop offset="0%" stop-color="#7B5EA7"/><stop offset="40%" stop-color="#4A2F7A"/><stop offset="100%" stop-color="#2A1050"/></radialGradient>
    <linearGradient id="top" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#3A2848"/><stop offset="100%" stop-color="#241830"/></linearGradient>
    <linearGradient id="skirtG" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#3A2848"/><stop offset="50%" stop-color="#2D1E38"/><stop offset="100%" stop-color="#1E1428"/></linearGradient>
    <radialGradient id="blush" cx="50%" cy="50%"><stop offset="0%" stop-color="#FFB3B3" stop-opacity="0.5"/><stop offset="100%" stop-color="#FFB3B3" stop-opacity="0"/></radialGradient>
    <radialGradient id="mouthIn" cx="50%" cy="40%"><stop offset="0%" stop-color="#D46070"/><stop offset="100%" stop-color="#8B2040"/></radialGradient>
    <filter id="glow"><feGaussianBlur stdDeviation="3" result="blur"/><feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  </defs>

  <!-- ══ BACK HAIR ══ -->
  <g class="hair-back">
    <path d="M210 110 Q180 100 155 150 Q135 220 130 320 Q128 360 140 400 L360 400 Q372 360 370 320 Q365 220 345 150 Q320 100 290 110 Z" fill="url(#hair)"/>
    <path d="M175 200 Q150 280 142 360 Q140 390 150 405 Q165 390 162 360 Q160 280 172 200 Z" fill="#221422" opacity="0.7"/>
    <path d="M325 200 Q350 280 358 360 Q360 390 350 405 Q335 390 338 360 Q340 280 328 200 Z" fill="#221422" opacity="0.7"/>
  </g>

  <!-- ══ LEGS + SOCKS ══ -->
  <g class="legs">
    <path d="M210 370 L208 510 Q207 520 212 520 L232 520 Q238 520 238 510 L240 370 Z" fill="url(#skin)"/>
    <path d="M260 370 L262 510 Q263 520 268 520 L288 520 Q293 520 292 510 L290 370 Z" fill="url(#skin)"/>
    <ellipse cx="224" cy="400" rx="6" ry="3" fill="white" opacity="0.15"/>
    <ellipse cx="276" cy="400" rx="6" ry="3" fill="white" opacity="0.15"/>
    <!-- socks -->
    <path d="M208 450 L210 525 L238 525 L240 450 Z" fill="white"/>
    <line x1="210" y1="468" x2="238" y2="468" stroke="#E8E8E8" stroke-width="0.8"/>
    <line x1="210" y1="485" x2="238" y2="485" stroke="#E8E8E8" stroke-width="0.8"/>
    <line x1="210" y1="502" x2="238" y2="502" stroke="#E8E8E8" stroke-width="0.8"/>
    <path d="M260 450 L262 525 L290 525 L292 450 Z" fill="white"/>
    <line x1="262" y1="468" x2="290" y2="468" stroke="#E8E8E8" stroke-width="0.8"/>
    <line x1="262" y1="485" x2="290" y2="485" stroke="#E8E8E8" stroke-width="0.8"/>
    <line x1="262" y1="502" x2="290" y2="502" stroke="#E8E8E8" stroke-width="0.8"/>
  </g>

  <!-- ══ SHOES ══ -->
  <path d="M200 520 Q195 530 205 535 L235 535 Q245 530 242 520 Z" fill="#4A3030"/>
  <path d="M258 520 Q255 530 265 535 L295 535 Q305 530 300 520 Z" fill="#4A3030"/>
  <ellipse cx="222" cy="522" rx="4" ry="2" fill="#6A5050" opacity="0.5"/>
  <ellipse cx="280" cy="522" rx="4" ry="2" fill="#6A5050" opacity="0.5"/>

  <!-- ══ ARMS ══ -->
  <g class="arm-l" style="transform-origin:180px 260px">
    <path d="M185 265 Q160 290 155 340 Q153 355 158 362" stroke="url(#skin)" stroke-width="16" stroke-linecap="round" fill="none"/>
    <ellipse cx="158" cy="368" rx="12" ry="10" fill="url(#skin)"/>
    <path d="M185 265 Q168 285 162 310" stroke="#2D1E38" stroke-width="18" stroke-linecap="round" fill="none" opacity="0.4"/>
  </g>
  <g class="arm-r" style="transform-origin:320px 260px">
    <path d="M315 265 Q340 290 345 340 Q347 355 342 362" stroke="url(#skin)" stroke-width="16" stroke-linecap="round" fill="none"/>
    <ellipse cx="342" cy="368" rx="12" ry="10" fill="url(#skin)"/>
    <path d="M315 265 Q332 285 338 310" stroke="#2D1E38" stroke-width="18" stroke-linecap="round" fill="none" opacity="0.4"/>
  </g>

  <!-- ══ BODY ══ -->
  <g class="body-g">
    <rect x="236" y="235" width="28" height="16" rx="6" fill="url(#skin)"/>
    <ellipse cx="250" cy="248" rx="12" ry="3" fill="#E8C0A0" opacity="0.35"/>
    <path d="M175 255 Q170 300 175 345 L325 345 Q330 300 325 255 Z" fill="url(#top)"/>
    <!-- Collar -->
    <path d="M195 255 L250 285 L305 255" stroke="white" stroke-width="2" fill="none" opacity="0.25"/>
    <!-- Ribbon -->
    <path d="M240 275 L250 300 L260 275" stroke="#E87090" stroke-width="3" fill="none" stroke-linecap="round"/>
    <circle cx="250" cy="288" r="5" fill="#E87090"/>
    <!-- Belt -->
    <rect x="176" y="340" width="148" height="8" rx="3" fill="#1A1025"/>
    <rect x="244" y="338" width="12" height="12" rx="3" fill="#C0A060"/>
  </g>

  <!-- ══ SKIRT ══ -->
  <g class="skirt">
    <path d="M175 342 Q168 400 150 460 L350 460 Q332 400 325 342 Z" fill="url(#skirtG)"/>
    <line x1="195" y1="348" x2="185" y2="458" stroke="#4A3870" stroke-width="0.8" opacity="0.6"/>
    <line x1="222" y1="344" x2="222" y2="460" stroke="#4A3870" stroke-width="0.8" opacity="0.6"/>
    <line x1="250" y1="342" x2="250" y2="460" stroke="#4A3870" stroke-width="0.8" opacity="0.6"/>
    <line x1="278" y1="344" x2="278" y2="460" stroke="#4A3870" stroke-width="0.8" opacity="0.6"/>
    <line x1="305" y1="348" x2="315" y2="458" stroke="#4A3870" stroke-width="0.8" opacity="0.6"/>
    <path d="M148 456 Q250 472 352 456" stroke="#6A5090" stroke-width="1.5" fill="none" opacity="0.4"/>
  </g>

  <!-- ══ HEAD ══ -->
  <g class="head-g">
    <ellipse cx="250" cy="145" rx="62" ry="70" fill="url(#skin)"/>
    <ellipse cx="250" cy="200" rx="16" ry="5" fill="#E8C0A0" opacity="0.25"/>
  </g>

  <!-- ══ EYES ══ -->
  <g class="eyes-g">
    <!-- Left eye -->
    <g class="eye-l" style="transform-origin:220px 140px">
      <ellipse cx="220" cy="140" rx="16" ry="22" fill="white"/>
      <ellipse cx="221" cy="141" rx="15" ry="20" fill="url(#eye)"/>
      <ellipse cx="222" cy="142" rx="10" ry="15" fill="#1A0530"/>
      <circle cx="216" cy="133" r="6" fill="white" opacity="0.95"/>
      <circle cx="226" cy="144" r="3.5" fill="white" opacity="0.75"/>
      <path d="M205 130 Q220 114 236 130" stroke="#1A1028" stroke-width="3.5" fill="none" stroke-linecap="round"/>
      <path d="M207 148 Q220 160 233 148" stroke="#3A2A4A" stroke-width="1.5" fill="none" opacity="0.5"/>
    </g>
    <!-- Right eye -->
    <g class="eye-r" style="transform-origin:280px 140px">
      <ellipse cx="280" cy="140" rx="16" ry="22" fill="white"/>
      <ellipse cx="279" cy="141" rx="15" ry="20" fill="url(#eye)"/>
      <ellipse cx="278" cy="142" rx="10" ry="15" fill="#1A0530"/>
      <circle cx="274" cy="133" r="6" fill="white" opacity="0.95"/>
      <circle cx="274" cy="144" r="3.5" fill="white" opacity="0.75"/>
      <path d="M264 130 Q280 114 295 130" stroke="#1A1028" stroke-width="3.5" fill="none" stroke-linecap="round"/>
      <path d="M267 148 Q280 160 293 148" stroke="#3A2A4A" stroke-width="1.5" fill="none" opacity="0.5"/>
    </g>
    <!-- Eyebrows -->
    <path class="eyebrow-l" d="M206 116 Q220 108 236 115" stroke="#3A2848" stroke-width="2.5" fill="none" opacity="0.8"/>
    <path class="eyebrow-r" d="M264 115 Q280 108 294 116" stroke="#3A2848" stroke-width="2.5" fill="none" opacity="0.8"/>
  </g>

  <!-- ══ BLUSH ══ -->
  <ellipse class="blush-l" cx="200" cy="158" rx="16" ry="8" fill="url(#blush)" opacity="0.6"/>
  <ellipse class="blush-r" cx="300" cy="158" rx="16" ry="8" fill="url(#blush)" opacity="0.6"/>

  <!-- ══ NOSE ══ -->
  <path d="M248 150 L246 158 Q250 160 254 158 L252 150" stroke="#E8C0A0" stroke-width="0.8" fill="none" opacity="0.45"/>

  <!-- ══ MOUTH ══ -->
  <g class="mouth-g" id="mouth">
    <path d="M238 166 Q250 173 262 166" stroke="#D88090" stroke-width="2" fill="none" stroke-linecap="round"/>
    <ellipse cx="250" cy="172" rx="10" ry="3" fill="url(#mouthIn)" opacity="0" id="mouthOpen"/>
  </g>

  <!-- ══ FRONT HAIR ══ -->
  <g class="hair-front">
    <!-- Bangs -->
    <path d="M188 120 Q185 70 200 50 Q220 30 250 32 Q280 30 300 50 Q315 70 312 120
             Q308 95 295 85 Q278 72 250 74 Q222 72 205 85 Q192 95 188 120 Z" fill="url(#hairShine)"/>
    <path d="M190 115 Q186 72 200 55 Q215 38 240 36 L250 28 L260 36 Q285 38 300 55 Q314 72 310 115
             Q306 92 290 82 Q272 70 250 72 Q228 70 210 82 Q194 92 190 115 Z" fill="url(#hair)"/>
    <!-- Side strands -->
    <g class="hair-l">
      <path d="M190 115 Q170 105 158 90 Q148 115 145 170 Q143 230 150 290" fill="none" stroke="url(#hair)" stroke-width="18" stroke-linecap="round"/>
      <path d="M190 115 Q170 105 158 90 Q148 115 145 170 Q143 230 150 290" fill="none" stroke="#5A4060" stroke-width="2" stroke-linecap="round" opacity="0.3"/>
    </g>
    <g class="hair-r">
      <path d="M310 115 Q330 105 342 90 Q352 115 355 170 Q357 230 350 290" fill="none" stroke="url(#hair)" stroke-width="18" stroke-linecap="round"/>
      <path d="M310 115 Q330 105 342 90 Q352 115 355 170 Q357 230 350 290" fill="none" stroke="#5A4060" stroke-width="2" stroke-linecap="round" opacity="0.3"/>
    </g>
    <!-- Ahoge -->
    <path d="M252 32 Q260 8 275 2" stroke="url(#hair)" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M252 32 Q260 8 275 2" stroke="#7A6080" stroke-width="1.5" fill="none" stroke-linecap="round" opacity="0.4"/>
    <!-- Hair clips -->
    <circle cx="168" cy="140" r="6" fill="#E87090" opacity="0.85"/>
    <circle cx="332" cy="140" r="6" fill="#E87090" opacity="0.85"/>
  </g>
</svg>

<script>
  const body = document.getElementById('body');
  const mouthG = document.getElementById('mouth');
  const mouthOpen = document.getElementById('mouthOpen');

  // Blink
  let blinkT;
  function scheduleBlink() {
    clearTimeout(blinkT);
    blinkT = setTimeout(() => {
      body.classList.add('blink');
      setTimeout(() => body.classList.remove('blink'), 150);
      scheduleBlink();
    }, 2500 + Math.random() * 3500);
  }
  scheduleBlink();

  window.updateMouth = function(v) {
    const val = Math.min(1, Math.max(0, Number(v) || 0));
    mouthG.style.transform = 'scaleY(' + (0.2 + val * 1.5) + ')';
    mouthOpen.setAttribute('opacity', val * 0.75);
    mouthOpen.setAttribute('ry', 1 + val * 7);
  };

  window.setEmotion = function(emotion) {
    body.className = body.className.replace(/em-\\w+/g, '').replace(/dance/g, '');
    if (emotion && emotion !== 'calm') body.classList.add('em-' + emotion);
  };

  window.setAnimState = function(state) {
    body.classList.remove('dance');
    if (state === 'dancing') body.classList.add('dance');
  };
</script>
</body>
</html>

''';
