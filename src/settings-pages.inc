 void createSettingsShell(){
  auto child=[&](const wchar_t* type,const wchar_t* text,DWORD style,int id){
   return CreateWindowExW(0,type,text,WS_CHILD|WS_VISIBLE|style,0,0,1,1,settingsWindow,
                          (HMENU)(INT_PTR)id,instance,nullptr);
  };
  brandIcon=child(L"STATIC",L"",SS_OWNERDRAW,SETTINGS_BRAND_ICON);
  brandTitle=child(L"STATIC",tr(L"Снег"),SS_LEFT,0);
  status=child(L"STATIC",lastStatus.c_str(),SS_LEFT,STATUS_LABEL);
  sidebar=child(WC_LISTBOXW,L"",LBS_NOTIFY|WS_TABSTOP|LBS_OWNERDRAWFIXED|LBS_HASSTRINGS|LBS_NOINTEGRALHEIGHT|WS_VSCROLL,SIDEBAR);
  languageButton=child(L"BUTTON",L"English",BS_OWNERDRAW|WS_TABSTOP,SIDEBAR_LANGUAGE);
  pageTitle=child(L"STATIC",L"",SS_LEFT,0);
  pageSubtitle=child(L"STATIC",L"",SS_LEFT,STATUS_LABEL);
  pagePause=child(L"BUTTON",tr(L"Пауза"),BS_OWNERDRAW|WS_TABSTOP,FULL_PAUSE);
  pageFooter=child(L"STATIC",tr(L"Изменения сохраняются автоматически"),SS_LEFT,STATUS_LABEL);
  pane=CreateWindowExW(WS_EX_CONTROLPARENT,PANECLASS,L"",WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN,
                       0,0,1,1,settingsWindow,nullptr,instance,nullptr);
  settingsScroll=child(L"SCROLLBAR",L"",SBS_VERT,0);
  skinControl(settingsScroll,L"SCROLLBAR",SBS_VERT);
  updateSidebar();
  applySettingsFonts();
 }
 void applySettingsFonts(){
  for(HWND child:{sidebar,languageButton,pagePause})if(child)SendMessageW(child,WM_SETFONT,(WPARAM)font,TRUE);
  for(HWND child:{status,pageSubtitle,pageFooter})if(child)SendMessageW(child,WM_SETFONT,(WPARAM)smallFont,TRUE);
  if(brandTitle)SendMessageW(brandTitle,WM_SETFONT,(WPARAM)brandFont,TRUE);
  if(pageTitle)SendMessageW(pageTitle,WM_SETFONT,(WPARAM)titleFont,TRUE);
 }
 void updateSettingsChrome(){
  if(!pageTitle)return;
  static const wchar_t* subtitles[]={
   L"Настройте снегопад и вид снежинок",L"Направление и сила ветра",
   L"Где снег остаётся и какой высоты вырастает",L"Выберите инструмент — игра начнётся сразу",
   L"Уборщик расчистит сугроб внизу экрана",L"Огни вдоль верхнего края экрана",
   L"Зимние украшения для каждого экрана",L"Выберите, где будет идти снег",
   L"Баланс плавности и нагрузки на Windows",L"Запуск приложения и основные параметры"};
  SetWindowTextW(pageTitle,tr(paneNames[selectedPane]));
  SetWindowTextW(pageSubtitle,tr(subtitles[selectedPane]));
  SetWindowTextW(brandTitle,tr(L"Снег"));
  SetWindowTextW(pageFooter,tr(L"Изменения сохраняются автоматически"));
  SetWindowTextW(languageButton,appLanguage==Language::russian?L"Русский":L"English");
  SetWindowTextW(pagePause,tr(paused?L"Продолжить":L"Пауза"));
 }
 void layoutSettings(){
  if(!pane)return;
  RECT client{};GetClientRect(settingsWindow,&client);
  const int width=int(client.right/uiScale),height=int(client.bottom/uiScale);
  sidebarWidth=std::clamp(width/4,158,230);
  const int inset=width>=850?26:18;
  const int start=sidebarWidth+inset;
  auto place=[&](HWND child,int x,int y,int w,int h){
   MoveWindow(child,px(x),px(y),std::max(1,px(w)),std::max(1,px(h)),TRUE);
  };
  place(brandIcon,20,49,32,37);
  place(brandTitle,64,46,sidebarWidth-72,25);
  place(status,64,73,sidebarWidth-70,19);
  place(sidebar,10,110,sidebarWidth-20,height-161);
  place(languageButton,19,height-42,119,29);
  place(pageTitle,start,24,width-start-88,35);
  place(pageSubtitle,start,58,width-start-68,32);
  place(pagePause,width-inset-45,25,45,40);
  place(pane,start,120,width-start-inset,height-166);
  place(settingsScroll,width-inset+7,120,7,height-166);
  place(pageFooter,start,height-35,width-start-inset,22);
  buildPane();
  InvalidateRect(settingsWindow,nullptr,TRUE);
 }
 void paintSettingsShell(HDC dc){
  RECT r{};GetClientRect(settingsWindow,&r);
  FillRect(dc,&r,graphite);
  RECT nav=r;nav.right=px(sidebarWidth);
  FillRect(dc,&nav,navBrush);
  auto mark=[&](RECT frame){
   SetDCBrushColor(dc,settingsTheme::line);
   FillRect(dc,&frame,(HBRUSH)GetStockObject(DC_BRUSH));
  };
  mark({nav.right,0,nav.right+1,r.bottom});
  int inset=px(r.right/uiScale>=850?26:18), left=nav.right+inset;
  mark({left,px(93),r.right-inset,px(93)+1});
  mark({left,r.bottom-px(44),r.right-inset,r.bottom-px(44)+1});
 }
 void detail(const wchar_t* text,int x,int y,int w,int h=34){
  HWND item=control(L"STATIC",text,SS_LEFT,HELP_TEXT,x,y,w,h);
  SendMessageW(item,WM_SETFONT,(WPARAM)smallFont,TRUE);
 }
 void heading(const wchar_t* text,int x,int y,int w){
  HWND item=control(L"STATIC",text,SS_LEFT,0,x,y,w,22);
  SendMessageW(item,WM_SETFONT,(WPARAM)strongFont,TRUE);
 }
 void rule(int y,int x=0,int width=-1){
  control(L"STATIC",L"",SS_OWNERDRAW,SETTINGS_RULE,x,y,width<0?fieldWidth:width,1);
 }
 void segment(int first,const wchar_t* title,int y,std::initializer_list<const wchar_t*> names){
  heading(title,0,y,fieldWidth);
  int count=int(names.size()),index=0;
  for(auto name:names){
   int left=fieldWidth*index/count;
   int end=fieldWidth*(index+1)/count;
   control(L"BUTTON",name,BS_OWNERDRAW|WS_TABSTOP,first+index,left,y+29,end-left,35);
   index++;
  }
 }
 void dropdown(int id,const wchar_t* title,int y,std::initializer_list<const wchar_t*> options,int selected){
  heading(title,0,y,fieldWidth);
  HWND child=control(WC_COMBOBOXW,L"",CBS_DROPDOWNLIST|CBS_OWNERDRAWFIXED|CBS_HASSTRINGS|WS_TABSTOP|WS_VSCROLL,
                    id,0,y+26,fieldWidth,240);
  for(auto option:options)SendMessageW(child,CB_ADDSTRING,0,(LPARAM)option);
  SendMessageW(child,CB_SETCURSEL,selected,0);
  SendMessageW(child,CB_SETITEMHEIGHT,WPARAM(-1),px(30));
 }
 std::wstring displayTitle() const{
  if(settings.allDisplays)return tr(L"Все экраны");
  std::wstring name;
  int count=0;
  for(const auto& monitor:monitors)if(settings.displays.count(monitor.device)){name=monitor.device;count++;}
  if(count==0)return tr(L"Выберите экран");
  if(count==1)return name;
  return std::to_wstring(count)+L" "+tr(L"экрана");
 }
 void displayMenu(HWND button){
  HMENU menu=CreatePopupMenu();
  AppendMenuW(menu,MF_STRING|(settings.allDisplays?MF_CHECKED:0),1,tr(L"На всех экранах"));
  AppendMenuW(menu,MF_SEPARATOR,0,nullptr);
  size_t i=0;
  for(const auto& monitor:monitors){
   bool selected=settings.allDisplays||settings.displays.count(monitor.device)!=0;
   AppendMenuW(menu,MF_STRING|(selected?MF_CHECKED:0),i++ + 2,monitor.device.c_str());
  }
  RECT r{};GetWindowRect(button,&r);
  int result=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_LEFTALIGN,r.left,r.bottom,0,settingsWindow,nullptr);
  DestroyMenu(menu);
  if(result==1)settings.allDisplays=!settings.allDisplays;
  else if(result>=2&&size_t(result-2)<monitors.size()){
   if(settings.allDisplays){
    settings.displays.clear();
    for(const auto& monitor:monitors)settings.displays.insert(monitor.device);
    settings.allDisplays=false;
   }
   const auto& device=monitors[result-2].device;
   if(!settings.displays.erase(device))settings.displays.insert(device);
  }else return;
  save();rebuild();
 }
 void languageMenu(){
  HMENU menu=CreatePopupMenu();
  AppendMenuW(menu,MF_STRING|(appLanguage==Language::english?MF_CHECKED:0),1,L"English");
  AppendMenuW(menu,MF_STRING|(appLanguage==Language::russian?MF_CHECKED:0),2,L"Русский");
  RECT r{};GetWindowRect(languageButton,&r);
  int selection=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_BOTTOMALIGN,r.left,r.top,0,settingsWindow,nullptr);
  DestroyMenu(menu);
  if(selection)selectLanguage(selection==1?Language::english:Language::russian);
 }
 void buildSettingsPage(){
  if(!pane)return;
  if(selectedPane==6&&!showWinterScenes)selectedPane=0;
  updateSettingsChrome();
  for(HWND child=GetWindow(pane,GW_CHILD);child;){
   HWND next=GetWindow(child,GW_HWNDNEXT);DestroyWindow(child);child=next;
  }
  controls.clear();
  paintedChoices.fill(-1);
  RECT r{};GetClientRect(pane,&r);
  int width=std::max(1,int(r.right/uiScale));
  int previewWidth=std::clamp(width-315,160,260);
  bool twoColumns=width>=500;
  int columnGap=width>=680?28:20;
  fieldWidth=twoColumns?width-previewWidth-columnGap:width;
  const int w=fieldWidth;
  contentHeight=0;
  switch(selectedPane){
   case 0:
    segment(SEG_WEATHER,tr(L"Снегопад"),0,{tr(L"Лёгкий"),tr(L"Сильный"),tr(L"Метель")});
    segment(SEG_MATERIAL,tr(L"Вид снега"),83,{tr(L"Простой"),tr(L"Фактурный")});
    detail(tr(L"Мягкая фактура и объёмные тени"),0,156,w,21);
    rule(190);
    segment(SEG_FLAKES,tr(L"Вид снежинок"),210,{tr(L"Простые"),tr(L"Узорные")});
    slider(FLAKESIZE,tr(L"Размер снежинок"),294,50,300,int(std::round(settings.snowflakeSize*100)),true);
    SendMessageW(controls[FLAKESIZE],TBM_SETLINESIZE,0,10);
    SendMessageW(controls[FLAKESIZE],TBM_SETPAGESIZE,0,10);
    rule(360);
    check(SWEEP,tr(L"Расталкивать снег указателем"),378,settings.sweep);
    detail(tr(L"Снег сдвигается от движения курсора"),0,414,w,20);
    check(TREE,tr(L"Показать Ёлочки"),446,anyTree());
    detail(tr(L"Пять ёлочек вдоль нижнего края экрана"),0,482,w,28);
    contentHeight=511;
    break;
   case 1:
    detail(tr(L"Ветер меняется плавно и не очищает накопленный снег."),0,0,w,31);
    slider(WIND,tr(L"Сила ветра"),34,-100,100,int(settings.wind));
    detail(tr(L"Влево"),0,103,w/3,20);
    autoText(tr(L"Штиль"),SS_CENTER,w/3,103,w/3);
    autoText(tr(L"Вправо"),SS_RIGHT,2*w/3,103,w/3);
    button(WINDRESET,tr(L"Убрать ветер"),135,138);
    contentHeight=179;
    break;
   case 2:
    check(ACCWINDOWS,tr(L"На окнах"),0,settings.windows);
    slider(WINDOWHEIGHT,tr(L"Высота на окнах"),46,4,36,int(settings.windowHeight));
    rule(114);
    check(ACCBOTTOM,tr(L"Внизу экрана"),132,settings.bottom);
    slider(BOTTOMHEIGHT,tr(L"Высота внизу"),179,8,96,int(settings.bottomHeight));
    rule(247);
    check(TASKBAR,tr(L"Снег на панели задач"),265,settings.taskbar);
    check(VERTICAL,tr(L"На вертикальной панели задач"),310,settings.verticalTaskbar);
    detail(tr(L"Высота снега на панели задач следует настройке окон"),0,357,w,35);
    contentHeight=403;
    break;
   case 3:
    addTools(pane,0);
    heading(tr(L"Катайте снежки"),0,114,w);
    detail(tr(L"Катайте шар по сугробу, чтобы он рос. Поднимите и бросьте, чтобы разбить."),0,141,w,38);
    heading(tr(L"Соберите снеговика"),0,176,w);
    detail(tr(L"Положите три шара друг на друга. Четыре образа снеговика будут чередоваться."),0,202,w,45);
    control(L"STATIC",L"Esc",SS_OWNERDRAW,ESC_KEY,0,252,41,29);
    detail(tr(L"Выйти из игры"),51,260,w-51,23);
    contentHeight=296;
    break;
   case 4:
    segment(SEG_CLEANER,tr(L"Модель"),0,{tr(L"Трактор"),tr(L"Ретро-трактор")});
    button(RUNCLEANER,tr(L"Запустить уборщика"),83,w);
    detail(tr(L"Снег на окнах останется"),0,132,w,24);
    button(CLEAR,tr(L"Растопить весь снег"),156,w);
    rule(212);
    check(AUTOCLEANER,tr(L"Автоматическая уборка снега"),231,settings.automaticCleaner);
    detail(tr(L"Когда сугроб заполнится, уборщик выйдет сам. Автоматические проходы — не чаще раза в минуту."),0,277,w,52);
    contentHeight=338;
    break;
   case 5:{
    heading(tr(L"Вид гирлянды"),0,0,w);
    const wchar_t* names[]={tr(L"Лампочки"),tr(L"Звёзды"),tr(L"Со свечением")};
    for(int i=0;i<3;i++){
     int x=w*i/3+3*i,end=w*(i+1)/3-3*(2-i);
     control(L"BUTTON",names[i],BS_OWNERDRAW|WS_TABSTOP,STYLE_CARDS+i,x,28,end-x,83);
    }
    dropdown(MODE,tr(L"Свет"),129,{tr(L"Выключено"),tr(L"Постоянный"),tr(L"Мягкое мигание"),tr(L"Волна")},settings.garland);
    dropdown(PALETTE,tr(L"Палитра"),212,{tr(L"Тёплый свет"),tr(L"Разноцветная"),tr(L"Ледяной свет")},settings.palette);
    rule(293);
    slider(BRIGHTNESS,tr(L"Яркость"),314,0,100,int(std::round(settings.brightness*100)),true);
    slider(INTENSITY,tr(L"Интенсивность мигания"),382,0,100,int(std::round(settings.intensity*100)),true);
    detail(tr(L"При 0% свет становится постоянным"),0,452,w,29);
    contentHeight=490;
    break;
   }
   case 6:{
    HWND monitor=control(WC_COMBOBOXW,L"",CBS_DROPDOWNLIST|WS_TABSTOP|WS_VSCROLL,SCENEMONITOR,0,30,w,240);
    for(auto& display:monitors)SendMessageW(monitor,CB_ADDSTRING,0,(LPARAM)display.device.c_str());
    sceneMonitor=std::clamp(sceneMonitor,0,std::max(0,int(monitors.size())-1));
    SendMessageW(monitor,CB_SETCURSEL,sceneMonitor,0);
    int value=monitors.empty()?0:settings.scenes[monitors[sceneMonitor].device];
    dropdown(SCENEKIND,tr(L"Сцена"),88,{tr(L"Обычный рабочий стол"),tr(L"Дом в зимнем лесу"),tr(L"Заснеженное крыльцо")},value);
    contentHeight=160;
    break;
   }
   case 7:{
    check(ALLMONITORS,tr(L"На всех экранах"),0,settings.allDisplays);
    detail(tr(L"Включите для всех экранов или выберите отдельные"),0,47,w,24);
    int y=78;
    rule(y);
    for(size_t i=0;i<monitors.size()&&i<16;i++){
     int id=1801+int(i);
     check(id,monitors[i].device.c_str(),y+17,settings.allDisplays||settings.displays.count(monitors[i].device));
     enable(id,!settings.allDisplays);
     y+=64;rule(y);
    }
    detail(tr(L"Можно отключить все экраны — приложение останется в области уведомлений"),0,y+20,w,44);
    detail(tr(L"В полноэкранном режиме эффект скрывается"),0,y+77,w,33);
    contentHeight=y+128;
    break;
   }
   case 8:{
    heading(tr(L"Режим"),0,0,w);
    const wchar_t* quality[]={tr(L"Авто"),tr(L"Экономный"),tr(L"Плавный")};
    for(int i=0;i<3;i++)control(L"BUTTON",quality[i],BS_OWNERDRAW|WS_TABSTOP,QUALITY_CARDS+i,0,37+i*68,w,68);
    detail(tr(L"В режиме энергосбережения частота ограничена 30 кадрами/с"),0,263,w,28);
    rule(294);
    check(REDUCEMOTION,tr(L"Учитывать уменьшение движения Windows"),313,settings.reduceMotion);
    detail(tr(L"При уменьшении движения снег реже, а снежинки не вращаются"),0,360,w,43);
    contentHeight=419;
    break;
   }
   case 9:
    heading(tr(L"Автозапуск"),0,0,w);
    check(LOGIN,tr(L"Запускать Снег при входе в Windows"),37,loginEnabled());
    detail(tr(L"Автозапуск можно изменить в любой момент"),0,83,w,36);
    button(STARTUP_SETTINGS,tr(L"Параметры автозагрузки Windows…"),130,w<270?w:270);
    rule(191);
    heading(tr(L"Начальные настройки"),0,218,w);
    detail(tr(L"Верните режим снегопада, ветер, накопление и качество к начальным значениям."),0,253,w,44);
    button(RESET,tr(L"Сбросить настройки…"),305,193);
    detail(tr(L"Язык и автозапуск не изменятся"),0,359,w,30);
    contentHeight=400;
    break;
  }
  const int x=twoColumns?w+columnGap:0;
  const int y=twoColumns?0:contentHeight+18;
  previewWidth=twoColumns?previewWidth:std::min(width,260);
  if(selectedPane==9){
   heading(tr(L"Работает локально"),x,y,previewWidth);
   control(L"STATIC",L"",SS_OWNERDRAW,PRIVACY_ICON,x,y+40,48,48);
   detail(tr(L"Снег работает локально. Не записывает экран, не читает заголовки окон и не отправляет данные в сеть. Разрешения на запись экрана и управление компьютером не запрашиваются."),
    x,y+112,previewWidth,103);
   detail(L"Snow 0.3.9-win.6 · Windows 10/11 x64",x,y+220,previewWidth,24);
   control(L"BUTTON",tr(L"от D1on"),BS_OWNERDRAW|WS_TABSTOP,AUTHOR,x,y+251,130,30);
   contentHeight=std::max(contentHeight,y+285);
  }else if(selectedPane!=6){
   int previewHeight=int(previewWidth*1.25);
   heading(tr(L"Предпросмотр"),x,y,previewWidth);
   control(L"STATIC",tr(L"Предпросмотр"),SS_OWNERDRAW,FULL_PREVIEW,x,y+31,previewWidth,previewHeight);
   if(selectedPane==7)detail(tr(L"Снег на выбранных экранах"),x,y+48+previewHeight,previewWidth,32);
   else control(L"BUTTON",displayTitle().c_str(),BS_OWNERDRAW|WS_TABSTOP,DISPLAY_MENU,x,y+43+previewHeight,previewWidth,36);
   contentHeight=std::max(contentHeight,y+90+previewHeight);
  }
  dependencies();
  SCROLLINFO info{sizeof(info),SIF_RANGE|SIF_PAGE|SIF_POS,0,px(contentHeight)-1,UINT(r.bottom),0,0};
  SetScrollInfo(settingsScroll,SB_CTL,&info,TRUE);
  ShowWindow(settingsScroll,px(contentHeight)>r.bottom?SW_SHOWNOACTIVATE:SW_HIDE);
  InvalidateRect(pane,nullptr,TRUE);
 }
 void autoText(const wchar_t* text,DWORD align,int x,int y,int width){
  HWND label=control(L"STATIC",text,align,HELP_TEXT,x,y,width,22);
  SendMessageW(label,WM_SETFONT,(WPARAM)smallFont,TRUE);
 }
