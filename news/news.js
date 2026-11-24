(function(){
  const root=document.documentElement;
  function setLanguage(language){
    const lang=language==='bn'?'bn':'en';
    root.classList.add('language-switching');
    root.dataset.lang=lang;
    try{localStorage.setItem('nghsians-news-language',lang)}catch(e){}
    document.querySelectorAll('[data-set-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.setLanguage===lang)));
    window.setTimeout(()=>root.classList.remove('language-switching'),260);
  }
  let initial='en';
  try{initial=localStorage.getItem('nghsians-news-language')||'en'}catch(e){}
  setLanguage(initial);
  document.querySelectorAll('[data-set-language]').forEach(button=>button.addEventListener('click',()=>setLanguage(button.dataset.setLanguage)));

  // The shared site's mobile drawer is populated from the desktop navigation.
  const mobileList=document.getElementById('mobileNavList');
  const menu=document.getElementById('mobileMenu');
  const menuButton=document.getElementById('menuToggle');
  if(mobileList){
    document.querySelectorAll('#navLeft .nav-link,#navRight .nav-link').forEach(link=>mobileList.appendChild(link.cloneNode(true)));
  }
  function closeMenu(){
    if(!menu||!menuButton)return;
    menu.classList.remove('open');menu.setAttribute('aria-hidden','true');menu.setAttribute('inert','');
    menuButton.setAttribute('aria-expanded','false');menuButton.setAttribute('aria-label','Open navigation menu');
    document.body.style.overflow='';
  }
  if(menu&&menuButton){
    menuButton.addEventListener('click',()=>{
      const open=!menu.classList.contains('open');
      menu.classList.toggle('open',open);menu.setAttribute('aria-hidden',String(!open));
      if(open)menu.removeAttribute('inert');else menu.setAttribute('inert','');
      menuButton.setAttribute('aria-expanded',String(open));menuButton.setAttribute('aria-label',open?'Close navigation menu':'Open navigation menu');
      document.body.style.overflow=open?'hidden':'';
    });
    menu.addEventListener('click',event=>{if(event.target.closest('a'))closeMenu()});
    document.addEventListener('keydown',event=>{if(event.key==='Escape'&&menu.classList.contains('open')){closeMenu();menuButton.focus()}});
  }

  const search=document.getElementById('newsSearch');
  const topic=document.getElementById('newsTopic');
  const year=document.getElementById('newsYear');
  const cards=[...document.querySelectorAll('[data-news-card]')];
  function filter(){
    if(!cards.length)return;
    const term=(search?.value||'').trim().toLocaleLowerCase();
    const selectedTopic=topic?.value||'all';
    const selectedYear=year?.value||'all';
    let count=0;
    cards.forEach(card=>{
      const matchesText=!term||(card.dataset.search||'').toLocaleLowerCase().includes(term);
      const matchesTopic=selectedTopic==='all'||card.dataset.topic===selectedTopic;
      const matchesYear=selectedYear==='all'||card.dataset.year===selectedYear;
      const show=matchesText&&matchesTopic&&matchesYear;
      if(show){
        if(card._hideTimer){window.clearTimeout(card._hideTimer);card._hideTimer=null}
        card.hidden=false;
        requestAnimationFrame(()=>card.classList.remove('is-filtering-out'));
        count++;
      }else{
        card.classList.add('is-filtering-out');
        if(!card._hideTimer)card._hideTimer=window.setTimeout(()=>{card.hidden=true;card._hideTimer=null},220);
      }
    });
    const result=document.getElementById('newsCount');
    if(result)result.textContent=count===1?'1 story':`${count} stories`;
    const empty=document.getElementById('newsEmpty');
    if(empty)empty.hidden=count!==0;
  }
  [search,topic,year].filter(Boolean).forEach(el=>el.addEventListener(el===search?'input':'change',filter));
  filter();
})();
