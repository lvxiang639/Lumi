const String kCharacterHtml = r'''
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<style>
  :root{--mouth:0}
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:transparent;display:flex;justify-content:center;align-items:flex-end;height:100vh;overflow:hidden;-webkit-user-select:none;user-select:none}
  svg{max-height:100vh;max-width:100vw}

  .pet{transform-origin:250px 420px;transition:transform .3s ease-out}
  .pet.talking{transform:translateY(-40px) scaleY(1.25)}

  .tail{animation:wag 2s ease-in-out infinite;transform-origin:380px 360px}
  @keyframes wag{0%,100%{transform:rotate(-6deg)}50%{transform:rotate(8deg)}}

  .ear-l{animation:earL 3s ease-in-out infinite;transform-origin:200px 100px}
  .ear-r{animation:earR 2.8s ease-in-out infinite;transform-origin:300px 100px}
  @keyframes earL{0%,100%{transform:rotate(0)}50%{transform:rotate(-5deg)}}
  @keyframes earR{0%,100%{transform:rotate(0)}50%{transform:rotate(5deg)}}

  .eye-l,.eye-r{transform-origin:center}
  .blink .eye-l,.blink .eye-r{animation:blink .12s ease-in-out}
  @keyframes blink{0%,100%{transform:scaleY(1)}50%{transform:scaleY(.05)}}

  .mouth-g{transform-origin:250px 215px;transition:transform .06s ease-out}
  .talking .mouth-g{transform:scaleY(1.6)}

  .em-joy .eye-l,.em-joy .eye-r{transform:scaleY(.75)}
  .em-joy .blush-l,.em-joy .blush-r{opacity:1}
  .em-sad .eye-l,.em-sad .eye-r{transform:translateY(4px)}
  .em-angry .brow-l,.em-angry .brow-r{transform:translateY(-4px)}
  .em-surprised .eye-l,.em-surprised .eye-r{transform:scale(1.3)}
  .em-worried .brow-l,.em-worried .brow-r{transform:translateY(2px)}

  .dance .pet{animation:bounce .4s ease-in-out infinite}
  @keyframes bounce{0%,100%{transform:translateY(-20px)}50%{transform:translateY(-60px) rotate(-3deg)}}
</style>
</head>
<body id="body">

<svg viewBox="0 0 500 500">
  <defs>
    <radialGradient id="bodyG" cx="50%" cy="40%"><stop offset="0%" stop-color="#FEFAF4"/><stop offset="60%" stop-color="#F8E4D0"/><stop offset="100%" stop-color="#E8C8A8"/></radialGradient>
    <radialGradient id="bellyG" cx="50%" cy="45%"><stop offset="0%" stop-color="white"/><stop offset="100%" stop-color="#FEF5EC"/></radialGradient>
    <radialGradient id="eyeG" cx="50%" cy="35%"><stop offset="0%" stop-color="#7B5FB8"/><stop offset="50%" stop-color="#4A2F7A"/><stop offset="100%" stop-color="#2A1048"/></radialGradient>
    <radialGradient id="blushG" cx="50%" cy="50%"><stop offset="0%" stop-color="#FFB0B0" stop-opacity=".5"/><stop offset="100%" stop-color="#FFB0B0" stop-opacity="0"/></radialGradient>
    <radialGradient id="noseG" cx="50%" cy="50%"><stop offset="0%" stop-color="#F89898"/><stop offset="100%" stop-color="#D86060"/></radialGradient>
    <radialGradient id="earIn" cx="50%" cy="50%"><stop offset="0%" stop-color="#FCD8D8"/><stop offset="100%" stop-color="#F0B8B8"/></radialGradient>
    <linearGradient id="tailG" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#E0B888"/><stop offset="100%" stop-color="#F0D8C0"/></linearGradient>
  </defs>

  <g class="pet" id="pet">
    <!-- ══ TAIL ══ -->
    <g class="tail">
      <path d="M340 350 Q370 330 395 300 Q410 278 415 258 Q420 240 408 235 Q398 232 392 248 Q380 275 358 310 Q340 335 330 345 Z" fill="url(#tailG)"/>
      <ellipse cx="400" cy="245" rx="8" ry="12" fill="#F8E8D8" opacity="0.7"/>
      <ellipse cx="408" cy="255" rx="10" ry="8" fill="white" opacity="0.4"/>
    </g>

    <!-- ══ BACK LEGS (sitting pose) ══ -->
    <ellipse cx="210" cy="400" rx="42" ry="28" fill="url(#bodyG)"/>
    <ellipse cx="290" cy="400" rx="42" ry="28" fill="url(#bodyG)"/>
    <!-- Paw pads -->
    <ellipse cx="196" cy="402" rx="10" ry="6" fill="#E8C8A8" opacity="0.4"/>
    <ellipse cx="216" cy="405" rx="10" ry="6" fill="#E8C8A8" opacity="0.4"/>
    <ellipse cx="284" cy="405" rx="10" ry="6" fill="#E8C8A8" opacity="0.4"/>
    <ellipse cx="304" cy="402" rx="10" ry="6" fill="#E8C8A8" opacity="0.4"/>

    <!-- ══ BODY (slim, elegant sitting pose) ══ -->
    <ellipse cx="250" cy="310" rx="100" ry="115" fill="url(#bodyG)"/>
    <!-- Belly -->
    <ellipse cx="250" cy="320" rx="65" ry="75" fill="url(#bellyG)"/>

    <!-- ══ FRONT PAWS (tucked in sitting) ══ -->
    <ellipse cx="190" cy="370" rx="22" ry="18" fill="url(#bodyG)"/>
    <ellipse cx="310" cy="370" rx="22" ry="18" fill="url(#bodyG)"/>
    <!-- Paw lines -->
    <line x1="182" y1="374" x2="182" y2="384" stroke="#E0C0A0" stroke-width="1.5" stroke-linecap="round" opacity="0.35"/>
    <line x1="190" y1="372" x2="190" y2="386" stroke="#E0C0A0" stroke-width="1.5" stroke-linecap="round" opacity="0.35"/>
    <line x1="198" y1="374" x2="198" y2="384" stroke="#E0C0A0" stroke-width="1.5" stroke-linecap="round" opacity="0.35"/>
    <line x1="302" y1="374" x2="302" y2="384" stroke="#E0C0A0" stroke-width="1.5" stroke-linecap="round" opacity="0.35"/>
    <line x1="310" y1="372" x2="310" y2="386" stroke="#E0C0A0" stroke-width="1.5" stroke-linecap="round" opacity="0.35"/>
    <line x1="318" y1="374" x2="318" y2="384" stroke="#E0C0A0" stroke-width="1.5" stroke-linecap="round" opacity="0.35"/>

    <!-- ══ EARS ══ -->
    <g class="ear-l">
      <path d="M185 140 Q155 40 168 15 Q178 0 200 55 Q210 90 215 130 Z" fill="url(#bodyG)"/>
      <path d="M188 135 Q165 50 175 28 Q182 14 196 58 Q203 85 210 125 Z" fill="url(#earIn)"/>
    </g>
    <g class="ear-r">
      <path d="M315 140 Q345 40 332 15 Q322 0 300 55 Q290 90 285 130 Z" fill="url(#bodyG)"/>
      <path d="M312 135 Q335 50 325 28 Q318 14 304 58 Q297 85 290 125 Z" fill="url(#earIn)"/>
    </g>

    <!-- ══ HEAD ══ -->
    <ellipse cx="250" cy="200" rx="80" ry="75" fill="url(#bodyG)"/>
    <!-- Cheek fluff -->
    <ellipse cx="185" cy="220" rx="28" ry="18" fill="url(#bodyG)"/>
    <ellipse cx="315" cy="220" rx="28" ry="18" fill="url(#bodyG)"/>

    <!-- ══ EYES ══ -->
    <g>
      <g class="eye-l" style="transform-origin:222px 192px">
        <ellipse cx="222" cy="192" rx="15" ry="19" fill="white"/>
        <ellipse cx="223" cy="193" rx="13" ry="17" fill="url(#eyeG)"/>
        <ellipse cx="224" cy="194" rx="9" ry="12" fill="#1A0530"/>
        <circle cx="219" cy="186" r="5.5" fill="white" opacity=".95"/>
        <circle cx="227" cy="196" r="2.8" fill="white" opacity=".7"/>
        <circle cx="216" cy="197" r="1.3" fill="white" opacity=".5"/>
      </g>
      <g class="eye-r" style="transform-origin:278px 192px">
        <ellipse cx="278" cy="192" rx="15" ry="19" fill="white"/>
        <ellipse cx="277" cy="193" rx="13" ry="17" fill="url(#eyeG)"/>
        <ellipse cx="276" cy="194" rx="9" ry="12" fill="#1A0530"/>
        <circle cx="273" cy="186" r="5.5" fill="white" opacity=".95"/>
        <circle cx="273" cy="196" r="2.8" fill="white" opacity=".7"/>
        <circle cx="284" cy="197" r="1.3" fill="white" opacity=".5"/>
      </g>
      <path class="brow-l" d="M210 174 Q222 166 236 173" stroke="#D0B090" stroke-width="2" fill="none" stroke-linecap="round" opacity=".5"/>
      <path class="brow-r" d="M264 173 Q278 166 290 174" stroke="#D0B090" stroke-width="2" fill="none" stroke-linecap="round" opacity=".5"/>
    </g>

    <!-- ══ BLUSH ══ -->
    <ellipse class="blush-l" cx="200" cy="210" rx="15" ry="7" fill="url(#blushG)" opacity=".5"/>
    <ellipse class="blush-r" cx="300" cy="210" rx="15" ry="7" fill="url(#blushG)" opacity=".5"/>

    <!-- ══ NOSE ══ -->
    <ellipse cx="250" cy="208" rx="7" ry="5.5" fill="url(#noseG)"/>
    <ellipse cx="247" cy="206" rx="2.5" ry="1.8" fill="white" opacity=".5"/>

    <!-- ══ MOUTH (visible open/close) ══ -->
    <g class="mouth-g" id="mouth">
      <path d="M242 216 Q246 212 250 216 Q254 212 258 216" stroke="#C08080" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
      <ellipse cx="250" cy="220" rx="8" ry="3.5" fill="#C84858" opacity="0" id="mouthOpen"/>
    </g>

    <!-- ══ WHISKERS ══ -->
    <g opacity="0.4">
      <line x1="195" y1="208" x2="130" y2="200" stroke="#D0B898" stroke-width="1.2" stroke-linecap="round"/>
      <line x1="195" y1="213" x2="128" y2="215" stroke="#D0B898" stroke-width="1.2" stroke-linecap="round"/>
      <line x1="195" y1="218" x2="130" y2="230" stroke="#D0B898" stroke-width="1.2" stroke-linecap="round"/>
      <line x1="305" y1="208" x2="370" y2="200" stroke="#D0B898" stroke-width="1.2" stroke-linecap="round"/>
      <line x1="305" y1="213" x2="372" y2="215" stroke="#D0B898" stroke-width="1.2" stroke-linecap="round"/>
      <line x1="305" y1="218" x2="370" y2="230" stroke="#D0B898" stroke-width="1.2" stroke-linecap="round"/>
    </g>

    <!-- ══ PINK RIBBON/BOW ══ -->
    <g transform="translate(310,118) scale(0.85)">
      <path d="M-14,-8 Q-20,-22 0,-18 Q20,-22 14,-8 Q8,-2 0,-4 Q-8,-2 -14,-8 Z" fill="#F898B0"/>
      <path d="M-14,8 Q-20,22 0,18 Q20,22 14,8 Q8,2 0,4 Q-8,2 -14,8 Z" fill="#F898B0"/>
      <circle cx="0" cy="0" r="4.5" fill="#E86880"/>
    </g>
  </g>
</svg>

<script>
  const body=document.getElementById('body');
  const pet=document.getElementById('pet');
  const mouth=document.getElementById('mouth');
  const mo=document.getElementById('mouthOpen');

  let bt;
  function sb(){clearTimeout(bt);bt=setTimeout(()=>{body.classList.add('blink');setTimeout(()=>body.classList.remove('blink'),130);sb()},2500+Math.random()*4000)}
  sb();

  window.updateMouth=function(v){
    v=Math.min(1,Math.max(0,+v||0));
    // Stand up when talking (v > 0.05)
    if(v>0.05){pet.classList.add('talking')}else{pet.classList.remove('talking')}
    // Mouth open
    mouth.style.transform='scaleY('+(0.08+v*2.2)+')';
    mo.setAttribute('opacity',v*.85);
    mo.setAttribute('ry',2+v*8);
  };

  window.setEmotion=function(e){
    body.className=body.className.replace(/em-\\w+/g,'').replace(/dance/g,'');
    if(e&&e!=='calm')body.classList.add('em-'+e);
  };

  window.setAnimState=function(s){
    body.classList.remove('dance');
    if(s==='dancing')body.classList.add('dance');
  };
</script>
</body>
</html>

''';
