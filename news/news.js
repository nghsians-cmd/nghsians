(function(){
  const body=document.body;
  function setLanguage(language,animate){
    const lang=language==='bn'?'bn':'en';
    body.dataset.language=lang;
    if(animate!==false)body.classList.add('language-switching');
    else body.classList.remove('language-switching');
    try{localStorage.setItem('nghsians-news-language',lang)}catch(e){}
    document.querySelectorAll('[data-set-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.setLanguage===lang)));
    const search=document.getElementById('newsSearch');
    if(search){
      search.placeholder=lang==='bn'?'শিরোনাম ও খবর খুঁজুন…':'Search headlines and stories…';
      search.setAttribute('aria-label',lang==='bn'?'শিরোনাম ও খবর খুঁজুন':'Search headlines and stories');
    }
    window.setTimeout(()=>body.classList.remove('language-switching'),260);
  }
  let initial='en';
  try{initial=localStorage.getItem('nghsians-news-language')||'en'}catch(e){}
  document.querySelectorAll('[data-set-language]').forEach(button=>button.addEventListener('click',()=>setLanguage(button.dataset.setLanguage)));
  setLanguage(initial,false);

  // Match the shared pages' mobile menu behavior and reuse their exact nav links.
  const menuToggle=document.getElementById('menuToggle');
  const mobileMenu=document.getElementById('mobileMenu');
  const mobileNavList=document.getElementById('mobileNavList');
  const leftNav=document.getElementById('navLeft');
  const rightNav=document.getElementById('navRight');
  const desktopLinks=[...Array.from(leftNav.children),...Array.from(rightNav.children)];
  function toggleMobileMenu(){
    const isOpen=mobileMenu.classList.toggle('open');
    menuToggle.setAttribute('aria-expanded',isOpen);
    document.body.style.overflow=isOpen?'hidden':'';
  }
  function buildMobileMenu(){
    mobileNavList.innerHTML='';
    desktopLinks.forEach(link=>{
      const clone=link.cloneNode(true);
      clone.addEventListener('click',toggleMobileMenu);
      mobileNavList.appendChild(clone);
    });
  }
  buildMobileMenu();
  menuToggle.addEventListener('click',toggleMobileMenu);
  document.addEventListener('keydown',event=>{
    if(event.key==='Escape'&&mobileMenu.classList.contains('open'))toggleMobileMenu();
  });

  const search=document.getElementById('newsSearch');
  const cards=[...document.querySelectorAll('[data-news-card]')];
  const selected={topic:'all',year:'all'};
  const filterMenus=[...document.querySelectorAll('.filter-menu[data-filter]')];
  function closeFilterMenus(except){
    filterMenus.forEach(menu=>{
      if(menu===except)return;
      menu.classList.remove('is-open');
      menu.querySelector('.filter-trigger')?.setAttribute('aria-expanded','false');
      menu.querySelector('.filter-options')?.setAttribute('hidden','');
    });
  }
  function filter(){
    if(!cards.length)return;
    const lang=body.dataset.language||'en';
    const term=(search?.value||'').trim().toLocaleLowerCase();
    let count=0;
    cards.forEach(card=>{
      const matchesText=!term||(card.dataset.search||'').toLocaleLowerCase().includes(term);
      const matchesTopic=selected.topic==='all'||card.dataset.topic===selected.topic;
      const matchesYear=selected.year==='all'||card.dataset.year===selected.year;
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
    if(result)result.textContent=lang==='bn'?`${count}টি খবর`:`${count} ${count===1?'story':'stories'}`;
    const empty=document.getElementById('newsEmpty');
    if(empty)empty.hidden=count!==0;
  }
  filterMenus.forEach(menu=>{
    const trigger=menu.querySelector('.filter-trigger');
    const options=menu.querySelector('.filter-options');
    trigger.addEventListener('click',()=>{
      const open=!menu.classList.contains('is-open');
      closeFilterMenus(menu);
      menu.classList.toggle('is-open',open);
      trigger.setAttribute('aria-expanded',String(open));
      options.hidden=!open;
      if(open)options.querySelector('[aria-selected="true"]')?.focus();
    });
    options.querySelectorAll('[role="option"]').forEach(option=>option.addEventListener('click',()=>{
      selected[menu.dataset.filter]=option.dataset.value;
      options.querySelectorAll('[role="option"]').forEach(item=>item.setAttribute('aria-selected',String(item===option)));
      const label=menu.querySelector('.filter-current');
      label.innerHTML=option.innerHTML;
      closeFilterMenus();
      filter();trigger.focus();
    }));
    menu.addEventListener('keydown',event=>{
      const items=[...options.querySelectorAll('[role="option"]')];
      const index=items.indexOf(document.activeElement);
      if(event.key==='Escape'){event.preventDefault();closeFilterMenus();trigger.focus()}
      else if(event.key==='ArrowDown'||event.key==='ArrowUp'){
        event.preventDefault();
        if(!menu.classList.contains('is-open')){trigger.click();return}
        const direction=event.key==='ArrowDown'?1:-1;
        items[(index+direction+items.length)%items.length].focus();
      }
    });
  });
  document.addEventListener('click',event=>{if(!event.target.closest('.filter-menu'))closeFilterMenus()});
  search?.addEventListener('input',filter);
  filter();
})();
