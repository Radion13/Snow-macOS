 // Included by App. Quick and full settings use the same actions and model.
 static void preferRoundedWindow(HWND window){
  const DWM_WINDOW_CORNER_PREFERENCE corner=DWMWCP_ROUND;
  DwmSetWindowAttribute(window,DWMWA_WINDOW_CORNER_PREFERENCE,&corner,sizeof(corner));
 }
 void darkFrame(HWND window){
  preferRoundedWindow(window);
  BOOL enabled=TRUE;
  if(FAILED(DwmSetWindowAttribute(window,20,&enabled,sizeof(enabled))))
   DwmSetWindowAttribute(window,19,&enabled,sizeof(enabled));
 }
 static LRESULT CALLBACK paintNativeControl(HWND window,UINT message,WPARAM w,LPARAM l,UINT_PTR,DWORD_PTR data){
  auto& self=*reinterpret_cast<App*>(data);
  if(message==WM_ERASEBKGND)return TRUE;
  if((message==WM_LBUTTONDOWN||message==WM_LBUTTONUP||message==WM_MOUSEMOVE)&&
     className(window)==TRACKBAR_CLASSW&&self.trackbarPointer(window,message,GET_X_LPARAM(l)))return 0;
  if(message==WM_PAINT){
   PAINTSTRUCT paint;
   HDC dc=BeginPaint(window,&paint);
   self.drawNativeControl(window,dc);
   EndPaint(window,&paint);
   return 0;
  }
  if(message==WM_PRINTCLIENT){self.drawNativeControl(window,(HDC)w);return 0;}
   // TBM_SETPOS can draw the system thumb directly when asked to repaint.
   // Let the native control update its state, then redraw through the skin.
   LRESULT result=DefSubclassProc(window,message,message==TBM_SETPOS?FALSE:w,l);
   switch(message){
    case TBM_SETPOS:case BM_SETCHECK:case CB_SETCURSEL:case CB_SHOWDROPDOWN:
    case WM_ENABLE:case WM_SETFOCUS:case WM_KILLFOCUS:case WM_UPDATEUISTATE:
    case WM_KEYDOWN:case WM_LBUTTONDOWN:case WM_LBUTTONUP:
     InvalidateRect(window,nullptr,FALSE);
     break;
    case WM_MOUSEMOVE:
     if(w&MK_LBUTTON)InvalidateRect(window,nullptr,FALSE);
     break;
   }
   return result;
 }
 static bool keyboardFocus(HWND window){
  return GetFocus()==window&&!(SendMessageW(window,WM_QUERYUISTATE,0,0)&UISF_HIDEFOCUS);
 }
 int sliderThumbSize(HWND control)const{
  return GetParent(control)==quickPane?qp(settingsTheme::sliderHandle):px(settingsTheme::sliderHandle);
 }
 bool trackbarPointer(HWND window,UINT message,int x){
  if(message==WM_LBUTTONDOWN){
   if(!IsWindowEnabled(window))return false;
   SetFocus(window);
   SetCapture(window);
  }else if(GetCapture()!=window)return false;
  RECT area{};GetClientRect(window,&area);
  const int size=sliderThumbSize(window);
  const int width=std::max<int>(1,area.right-size);
  const int minimum=int(SendMessageW(window,TBM_GETRANGEMIN,0,0));
  const int maximum=int(SendMessageW(window,TBM_GETRANGEMAX,0,0));
  const int value=minimum+MulDiv(std::clamp(x-size/2,0,width),maximum-minimum,width);
  if(SendMessageW(window,TBM_GETPOS,0,0)!=value){
   SendMessageW(window,TBM_SETPOS,FALSE,value);
   SendMessageW(GetParent(window),WM_HSCROLL,TB_THUMBTRACK,(LPARAM)window);
  }
  if(message==WM_LBUTTONUP)ReleaseCapture();
  return true;
 }
 void drawNativeControl(HWND window,HDC target){
  bool quick=GetParent(window)==quickPane||GetParent(window)==quickWindow;
  auto scale=[&](int n){return quick?qp(n):px(n);};
  const float radius=float(scale(settingsTheme::controlRadius));
  std::wstring cls=className(window);
  RECT area{};GetClientRect(window,&area);
  settingsTheme::ControlBuffer frame(target,area);
  HDC dc=frame.dc();
  FillRect(dc,&area,graphite);
  const bool disabled=!IsWindowEnabled(window),focus=keyboardFocus(window);
  auto previous=SelectObject(dc,quick?quickFont:font);
  SetBkMode(dc,TRANSPARENT);
  SetTextColor(dc,disabled?settingsTheme::muted:settingsTheme::foreground);
  if(cls==L"ScrollBar"||cls==L"SCROLLBAR"){
   SCROLLBARINFO bar{sizeof(bar)};
   if(GetScrollBarInfo(window,OBJID_CLIENT,&bar)&&bar.xyThumbBottom>bar.xyThumbTop){
    Gdiplus::Graphics g(dc);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    settingsTheme::solidSurface(g,settingsTheme::frame({area.left,bar.xyThumbTop,area.right,bar.xyThumbBottom}),
                                radius,0x5A5B64);
   }
  }else if(cls==TRACKBAR_CLASSW){
   const int low=int(SendMessageW(window,TBM_GETRANGEMIN,0,0));
   const int high=int(SendMessageW(window,TBM_GETRANGEMAX,0,0));
   const int position=int(SendMessageW(window,TBM_GETPOS,0,0));
   const int size=sliderThumbSize(window);
   const int available=std::max<int>(0,area.right-size);
   const int center=size/2+MulDiv(available,position-low,std::max(1,high-low));
   const float mid=area.bottom*.5f, thickness=float(std::max(2,scale(settingsTheme::sliderTrack)));
   const Gdiplus::RectF groove{0,mid-thickness*.5f,float(area.right),thickness};
   Gdiplus::Graphics g(dc);
   g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
   settingsTheme::solidSurface(g,groove,radius,disabled?0x37383F:0x575862);
   if(center>size/2)
    settingsTheme::solidSurface(g,{0,groove.Y,float(center),thickness},radius,disabled?0x737482:0xBEC5D6);
   settingsTheme::sliderThumb(g,float(center-size/2),mid-size*.5f,float(size),disabled,focus);
  }else if(cls==WC_COMBOBOXW){
   settingsTheme::surface(dc,area,radius,false,disabled,focus);
   int index=int(SendMessageW(window,CB_GETCURSEL,0,0));
   if(index>=0){
    LRESULT length=SendMessageW(window,CB_GETLBTEXTLEN,index,0);
    if(length>=0){
     std::wstring label(size_t(length)+1,L'\0');
     SendMessageW(window,CB_GETLBTEXT,index,(LPARAM)label.data());
     RECT text=area;text.left+=scale(13);text.right-=scale(32);
     DrawTextW(dc,label.c_str(),-1,&text,DT_SINGLELINE|DT_VCENTER|DT_END_ELLIPSIS|DT_NOPREFIX);
    }
   }
   settingsTheme::icon(dc,settingsTheme::Icon::down,
    {area.right-scale(26),area.bottom/2-scale(8),area.right-scale(10),area.bottom/2+scale(8)},
    disabled?settingsTheme::muted:settingsTheme::foreground);
  }else{
   const bool on=SendMessageW(window,BM_GETCHECK,0,0)==BST_CHECKED;
   const int height=scale(settingsTheme::switchHeight),width=scale(settingsTheme::switchWidth);
   const LONG left=std::max<LONG>(0,area.right-width);
   const float middle=area.bottom*.5f;
   {
    Gdiplus::Graphics g(dc);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    const Gdiplus::RectF track{left+.5f,middle-height*.5f+.5f,area.right-left-1.f,height-1.f};
    settingsTheme::toggle(g,track,float(scale(settingsTheme::switchThumb)),on,disabled,focus);
   }
   wchar_t text[256]{};GetWindowTextW(window,text,256);
   RECT caption=area;caption.right=left-scale(11);
   if(GetDlgCtrlID(window)>=1801&&GetDlgCtrlID(window)<1817){
    settingsTheme::icon(dc,settingsTheme::Icon::monitor,{0,scale(4),scale(18),scale(23)},
                        disabled?settingsTheme::muted:settingsTheme::foreground);
    caption.left=scale(27);
   }
   DrawTextW(dc,text,-1,&caption,DT_SINGLELINE|DT_VCENTER|DT_END_ELLIPSIS|DT_NOPREFIX);
  }
  SelectObject(dc,previous);
 }
 void skinControl(HWND window,const wchar_t* type,DWORD style){
  if(!window)return;
  if((lstrcmpiW(type,L"BUTTON")==0&&(style&BS_TYPEMASK)==BS_AUTOCHECKBOX)||
     lstrcmpiW(type,WC_COMBOBOXW)==0||lstrcmpiW(type,TRACKBAR_CLASSW)==0||lstrcmpiW(type,L"SCROLLBAR")==0)
   SetWindowSubclass(window,paintNativeControl,1,(DWORD_PTR)this);
 }
 HWND findControl(const std::map<int,HWND>& group,int id) const {
  auto found=group.find(id);
  return found==group.end()?nullptr:found->second;
 }
 static void setControlEnabled(HWND control,bool enabled){
  if(control&&(IsWindowEnabled(control)!=FALSE)!=enabled)EnableWindow(control,enabled);
 }
 static void setControlChecked(HWND control,bool checked){
  WPARAM state=checked?BST_CHECKED:BST_UNCHECKED;
  if(control&&SendMessageW(control,BM_GETCHECK,0,0)!=LRESULT(state))
   SendMessageW(control,BM_SETCHECK,state,0);
 }
 static void setControlText(HWND control,const wchar_t* text){
  if(!control)return;
  wchar_t before[128]{};
  GetWindowTextW(control,before,128);
  if(lstrcmpW(before,text)!=0)SetWindowTextW(control,text);
 }
 void syncSlider(const std::map<int,HWND>& group,int id,int value){
  if(HWND slider=findControl(group,id)){
   if(SendMessageW(slider,TBM_GETPOS,0,0)!=value)SendMessageW(slider,TBM_SETPOS,FALSE,value);
   setControlText(findControl(group,id+4000),sliderValue(id,value).c_str());
  }
 }
 void updateSidebar(){
  if(!sidebar)return;
  SendMessageW(sidebar,LB_RESETCONTENT,0,0);
  int row=0;
  for(int index:visiblePanes){
   SendMessageW(sidebar,LB_ADDSTRING,0,(LPARAM)tr(paneNames[index]));
   if(index==selectedPane)SendMessageW(sidebar,LB_SETCURSEL,row,0);
   row++;
  }
 }
 void selectLanguage(Language language){
  if(language!=Language::english&&language!=Language::russian)return;
  appLanguage=language;
  save();
  lstrcpynW(nid.szTip,tr(L"Снег"),128);
  Shell_NotifyIconW(NIM_MODIFY,&nid);
  if(settingsWindow){
   SCROLLINFO scrollInfo{sizeof(scrollInfo),SIF_POS};
   GetScrollInfo(settingsScroll,SB_CTL,&scrollInfo);
   SetWindowTextW(settingsWindow,tr(L"Настройки Снега"));
   updateSidebar();
   buildPane();
   scrollPane(pane,scrollInfo.nPos);
   InvalidateRect(sidebar,nullptr,TRUE);
  }
  if(quickWindow){
   SCROLLINFO scrollInfo{sizeof(scrollInfo),SIF_POS};
   GetScrollInfo(quickScroll,SB_CTL,&scrollInfo);
   buildQuick();
   scrollPane(quickPane,scrollInfo.nPos);
  }
  renderAll();
 }
 void menu(bool more=false,HWND button=nullptr){
  enum MenuCommand { pause=1, hide, melt, clean, trees, full, quit, english, russian, quick, mitten, snowball, shovel, remove };
  if(!more&&quickWindow)ShowWindow(quickWindow,SW_HIDE);
  HWND owner=more?quickWindow:tray;
  HMENU popup=CreatePopupMenu(), languages=CreatePopupMenu();
  auto item=[&](UINT id,const wchar_t* text,bool enabled=true,bool selected=false){
   AppendMenuW(popup,MF_STRING|(enabled?0:MF_GRAYED)|(selected?MF_CHECKED:0),id,text);
  };
  if(!more){
   item(0,lastStatus.c_str(),false);
   AppendMenuW(popup,MF_SEPARATOR,0,nullptr);
   item(pause,tr(paused?L"Продолжить":L"Пауза"));
  }
  item(hide,tr(hidden?L"Показать эффекты":L"Скрыть эффекты"));
  if(!more){
   AppendMenuW(popup,MF_SEPARATOR,0,nullptr);
   item(mitten,tr(L"Варежка"),gameAvailable(),interactive&&settings.tool==1);
   item(snowball,tr(L"Снежок"),gameAvailable(),interactive&&settings.tool==0);
   if(showShovel)item(shovel,tr(L"Лопата"),gameAvailable(),interactive&&settings.tool==2);
   if(showDeleteTool)item(remove,tr(L"Удалить объект"),gameAvailable(),interactive&&settings.tool==3);
   item(trees,tr(L"Ёлочки"),gameAvailable()||anyTree(),anyTree());
   item(clean,tr(L"Запустить уборщика"),gameAvailable());
   item(melt,tr(L"Растопить весь снег"));
   AppendMenuW(popup,MF_SEPARATOR,0,nullptr);
   item(quick,tr(L"Быстрые настройки"));
   item(full,tr(L"Все настройки"));
  }
  AppendMenuW(languages,MF_STRING|(appLanguage==Language::english?MF_CHECKED:0),english,L"English");
  AppendMenuW(languages,MF_STRING|(appLanguage==Language::russian?MF_CHECKED:0),russian,L"Русский");
  AppendMenuW(popup,MF_POPUP,(UINT_PTR)languages,tr(L"Язык"));
  AppendMenuW(popup,MF_SEPARATOR,0,nullptr);
  item(quit,tr(L"Завершить Снег"));
  POINT p{};GetCursorPos(&p);
  if(button){RECT r{};GetWindowRect(button,&r);p={r.left,r.bottom};}
  SetForegroundWindow(owner);
  int result=TrackPopupMenu(popup,TPM_RETURNCMD|TPM_RIGHTBUTTON,p.x,p.y,0,owner,nullptr);
  DestroyMenu(popup);
  PostMessageW(owner,WM_NULL,0,0);
  switch(result){
   case pause:togglePause();break;
   case hide:toggleHidden();break;
   case melt:clearSnow();break;
   case clean:runCleaner();break;
   case trees:growTree(!anyTree());break;
   case full:showSettings();break;
   case quit:DestroyWindow(tray);break;
   case english:selectLanguage(Language::english);break;
   case russian:selectLanguage(Language::russian);break;
   case quick:showQuick(false);break;
   case mitten:play(1);break;
   case snowball:play(0);break;
   case shovel:play(2);break;
   case remove:play(3);break;
  }
 }
 int qp(double length) const {return int(std::round(quickScale*length));}
 HWND quickControl(const wchar_t* type,const wchar_t* title,DWORD style,int id,int x,int y,int w,int h){
  HWND child=CreateWindowExW(0,type,title,WS_CHILD|WS_VISIBLE|style,
   qp(x),qp(y),qp(x+w)-qp(x),qp(y+h)-qp(y),quickPane,(HMENU)(INT_PTR)id,instance,nullptr);
  SendMessageW(child,WM_SETFONT,(WPARAM)quickFont,TRUE);
  skinControl(child,type,style);
  if(id)quickControls[id]=child;
  return child;
 }
 void quickButton(int id,const wchar_t* title,int x,int y,int width,int height=31){
  quickControl(L"BUTTON",title,BS_OWNERDRAW|WS_TABSTOP,id,x,y,width,height);
 }
 void addTools(HWND parent,int y){
  const std::pair<int,const wchar_t*> tools[]={{MITTEN,tr(L"Варежка")},{SNOWBALL,tr(L"Снежок")},
    {SHOVEL,tr(L"Лопата")},{DELETE_TOOL,tr(L"Удалить объект")}};
  const int visible=2+int(showShovel)+int(showDeleteTool);
  const bool quick=parent==quickPane;
  const int span=quick?280:fieldWidth,gap=quick?6:8;
  int index=0;
  for(auto& tool:tools){
   if((tool.first==SHOVEL&&!showShovel)||(tool.first==DELETE_TOOL&&!showDeleteTool))continue;
   int left=(span+gap)*index/visible,right=(span+gap)*(index+1)/visible-gap;
   if(quick)quickButton(tool.first,tool.second,16+left,y,right-left,38);
   else control(L"BUTTON",tool.second,BS_OWNERDRAW|WS_TABSTOP,tool.first,left,y,right-left,95);
   index++;
  }
 }
 void quickSlider(int id,const wchar_t* title,int y,int minimum,int maximum){
  quickControl(L"STATIC",title,SS_LEFT,0,16,y,180,22);
  quickControl(L"STATIC",L"",SS_RIGHT,id+4000,201,y,94,22);
  HWND slider=quickControl(TRACKBAR_CLASSW,L"",TBS_HORZ|TBS_NOTICKS|WS_TABSTOP,id,16,y+20,279,27);
  // Window name is exposed by native accessibility and is not painted on the track.
  SetWindowTextW(slider,title);
  SendMessageW(slider,TBM_SETRANGE,TRUE,MAKELPARAM(minimum,maximum));
  if(id==FLAKESIZE){
   SendMessageW(slider,TBM_SETLINESIZE,0,10);
   SendMessageW(slider,TBM_SETPAGESIZE,0,10);
  }
 }
 void buildQuick(){
  if(!quickPane)return;
  while(HWND child=GetWindow(quickPane,GW_CHILD))DestroyWindow(child);
  quickControls.clear();
  quickValues.fill(-1);
  SetWindowTextW(quickWindow,tr(L"Быстрые настройки"));
  quickControl(L"STATIC",L"",SS_OWNERDRAW,SETTINGS_BRAND_ICON,16,19,26,28);
  HWND title=quickControl(L"STATIC",tr(L"Снег"),SS_LEFT,0,50,13,140,26);
  SendMessageW(title,WM_SETFONT,(WPARAM)quickTitleFont,TRUE);
  quickStatus=quickControl(L"STATIC",lastStatus.c_str(),SS_LEFT,STATUS_LABEL,50,38,171,21);
  quickButton(QUICK_PAUSE,tr(paused?L"Продолжить":L"Пауза"),230,16,38,34);
  quickButton(QUICK_MORE,tr(L"Другие команды"),271,16,24,34);
  quickButton(QUICK_LIGHT,tr(L"Лёгкий"),16,71,93,32);
  quickButton(QUICK_LIGHT+1,tr(L"Сильный"),109,71,93,32);
  quickButton(QUICK_LIGHT+2,tr(L"Метель"),202,71,93,32);
  quickControl(L"STATIC",tr(L"Предпросмотр"),SS_OWNERDRAW,QUICK_PREVIEW,16,109,279,80);
  quickControl(L"STATIC",tr(L"Снежинки"),SS_LEFT,0,16,204,139,23);
  HWND flake=quickControl(WC_COMBOBOXW,L"",CBS_DROPDOWNLIST|CBS_OWNERDRAWFIXED|CBS_HASSTRINGS|WS_TABSTOP|WS_VSCROLL,FLAKESTYLE,157,195,138,180);
  for(auto label:{tr(L"Простые"),tr(L"Узорные")})SendMessageW(flake,CB_ADDSTRING,0,(LPARAM)label);
  SendMessageW(flake,CB_SETITEMHEIGHT,WPARAM(-1),qp(26));
  quickSlider(FLAKESIZE,tr(L"Размер"),233,50,300);
  quickSlider(WIND,tr(L"Ветер"),279,-100,100);
  auto separator=[&](int y){quickControl(L"STATIC",L"",SS_OWNERDRAW,SETTINGS_RULE,16,y,279,1);};
  separator(331);
  quickControl(L"BUTTON",tr(L"Ёлочки"),BS_AUTOCHECKBOX|WS_TABSTOP,TREE,16,344,279,27);
  separator(383);
  quickControl(L"STATIC",tr(L"Уборка снега"),SS_LEFT,HELP_TEXT,16,397,279,22);
  quickButton(RUNCLEANER,tr(L"Запустить уборщика"),16,419,279,33);
  quickButton(CLEAR,tr(L"Растопить весь снег"),16,460,279,33);
  separator(507);
  quickControl(L"STATIC",tr(L"Поиграть со снегом"),SS_LEFT,HELP_TEXT,16,522,279,22);
  addTools(quickPane,542);
  separator(594);
  quickButton(QUICK_OPEN,tr(L"Все настройки"),16,609,279,36);
  RECT r{},panel{};GetClientRect(quickPane,&r);GetClientRect(quickWindow,&panel);
  SCROLLINFO limits{sizeof(limits),SIF_RANGE|SIF_PAGE|SIF_POS,0,qp(673)-1,UINT(r.bottom),0,0};
  SetScrollInfo(quickScroll,SB_CTL,&limits,TRUE);
  const int gutter=std::max(1,qp(6));
  MoveWindow(quickScroll,std::max<int>(0,panel.right-gutter-qp(2)),0,gutter,r.bottom,TRUE);
  ShowWindow(quickScroll,int(limits.nMax+1)>r.bottom?SW_SHOWNOACTIVATE:SW_HIDE);
  syncQuick();
 }
 void showQuick(bool toggle=true){
  if(quickWindow&&IsWindowVisible(quickWindow)&&toggle){ShowWindow(quickWindow,SW_HIDE);return;}
  POINT cursor{};GetCursorPos(&cursor);
  NOTIFYICONIDENTIFIER identifier{sizeof(identifier)};
  identifier.hWnd=tray;identifier.uID=nid.uID;
  if(FAILED(Shell_NotifyIconGetRect(&identifier,&quickAnchor)))quickAnchor={cursor.x,cursor.y,cursor.x+1,cursor.y+1};
  MONITORINFO monitor{sizeof(monitor)};
  if(!GetMonitorInfoW(MonitorFromRect(&quickAnchor,MONITOR_DEFAULTTONEAREST),&monitor))return;
  RECT work=monitor.rcWork;
  if(!quickWindow){
   const DWORD mode=reviewWindow?WS_EX_APPWINDOW:WS_EX_TOOLWINDOW;
   quickWindow=CreateWindowExW(WS_EX_TOPMOST|mode|WS_EX_CONTROLPARENT,QUICKCLASS,tr(L"Быстрые настройки"),
     WS_POPUP|WS_BORDER|WS_CLIPCHILDREN,work.left,work.top,1,1,reviewWindow?nullptr:tray,nullptr,instance,nullptr);
   if(!quickWindow)return;
   darkFrame(quickWindow);
   const COLORREF border=RGB(74,75,84);
   DwmSetWindowAttribute(quickWindow,DWMWA_BORDER_COLOR,&border,sizeof(border));
   quickPane=CreateWindowExW(WS_EX_CONTROLPARENT,PANECLASS,L"",WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN,
    0,0,1,1,quickWindow,nullptr,instance,nullptr);
   quickScroll=CreateWindowExW(0,L"SCROLLBAR",L"",WS_CHILD|SBS_VERT,0,0,1,1,quickWindow,nullptr,instance,nullptr);
   skinControl(quickScroll,L"SCROLLBAR",SBS_VERT);
  }
  // Move first so PerMonitorV2 supplies the DPI of the tray icon's monitor.
  SetWindowPos(quickWindow,nullptr,work.left,work.top,0,0,SWP_NOACTIVATE|SWP_NOSIZE|SWP_NOZORDER);
  quickScale=std::min(GetDpiForWindow(quickWindow)/96.,(work.right-work.left-24)/311.);
  quickScale=std::max(.4,quickScale);
  if(quickFont)DeleteObject(quickFont);
  if(quickTitleFont)DeleteObject(quickTitleFont);
  quickFont=CreateFontW(-qp(13),0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");
  quickTitleFont=CreateFontW(-qp(19),0,0,0,FW_SEMIBOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");
  int height=std::min<int>(qp(675),work.bottom-work.top);
  const bool scrollable=height<qp(675);
  int width=std::min<int>(qp(313)+(scrollable?qp(10):0),work.right-work.left);
  int left=std::clamp<int>((quickAnchor.left+quickAnchor.right-width)/2,work.left,work.right-width);
  bool below=quickAnchor.top<work.top;
  int top=std::clamp<int>(below?quickAnchor.bottom:quickAnchor.top-height,work.top,work.bottom-height);
  SetWindowPos(quickWindow,HWND_TOPMOST,left,top,width,height,SWP_NOACTIVATE);
  RECT r;GetClientRect(quickWindow,&r);
  MoveWindow(quickPane,0,0,r.right-(scrollable?qp(10):0),r.bottom,TRUE);
  buildQuick();
  ShowWindow(quickWindow,SW_SHOW);
  SetForegroundWindow(quickWindow);
 }
 void syncQuick(){
  if(quickControls.empty())return;
  std::array<int,8> values{settings.weather,settings.snowflakeStyle,int(std::round(settings.snowflakeSize*100)),
   int(settings.wind),int(anyTree()),int(gameAvailable()),interactive?settings.tool+1:0,int(paused)};
  if(values==quickValues)return;
  auto before=quickValues;
  quickValues=values;
  auto hwnd=[&](int id){return findControl(quickControls,id);};
  if(before[1]!=values[1]&&SendMessageW(hwnd(FLAKESTYLE),CB_GETCURSEL,0,0)!=values[1])
   SendMessageW(hwnd(FLAKESTYLE),CB_SETCURSEL,values[1],0);
  if(before[2]!=values[2])syncSlider(quickControls,FLAKESIZE,values[2]);
  if(before[3]!=values[3])syncSlider(quickControls,WIND,values[3]);
  setControlChecked(hwnd(TREE),values[4]!=0);
  setControlText(hwnd(QUICK_PAUSE),tr(paused?L"Продолжить":L"Пауза"));
  setControlEnabled(hwnd(TREE),values[5]||values[4]);
  for(int id:{RUNCLEANER,MITTEN,SNOWBALL,SHOVEL,DELETE_TOOL})
   setControlEnabled(hwnd(id),values[5]!=0);
  if(before[0]!=values[0])for(int id:{QUICK_LIGHT,QUICK_LIGHT+1,QUICK_LIGHT+2})
   InvalidateRect(hwnd(id),nullptr,FALSE);
  if(!std::equal(values.begin(),values.begin()+5,before.begin()))InvalidateRect(hwnd(QUICK_PREVIEW),nullptr,FALSE);
  if(before[6]!=values[6])for(int id:{MITTEN,SNOWBALL})InvalidateRect(hwnd(id),nullptr,FALSE);
 }
 void quickCommand(int id,int notification,HWND source){
  if(id==FLAKESTYLE&&notification==CBN_SELCHANGE){
   int selection=int(SendMessageW(source,CB_GETCURSEL,0,0));
   if(selection>=0){settings.snowflakeStyle=selection;changed();syncFull();}
   return;
  }
  if(notification!=BN_CLICKED)return;
  switch(id){
   case QUICK_PAUSE:togglePause();break;
   case QUICK_MORE:menu(true,source);break;
   case QUICK_OPEN:showSettings();break;
   case QUICK_LIGHT:case QUICK_LIGHT+1:case QUICK_LIGHT+2:settings.weather=id-QUICK_LIGHT;changed();syncFull();break;
   case TREE:growTree(SendMessageW(source,BM_GETCHECK,0,0)==BST_CHECKED);break;
   case CLEAR:clearSnow();break;
   case RUNCLEANER:runCleaner();break;
   case MITTEN:play(1);break;
   case SNOWBALL:play(0);break;
   case SHOVEL:if(showShovel)play(2);break;
   case DELETE_TOOL:if(showDeleteTool)play(3);break;
  }
 }
 void syncFull(){
  syncSlider(controls,WIND,int(settings.wind));
  syncSlider(controls,FLAKESIZE,int(std::round(settings.snowflakeSize*100)));
 }
 void scrollPane(HWND view,int next){
  HWND bar=view==pane?settingsScroll:quickScroll;
  SCROLLINFO info{sizeof(info),SIF_POS};
  GetScrollInfo(bar,SB_CTL,&info);
  int before=info.nPos;
  info.nPos=next;
  SetScrollInfo(bar,SB_CTL,&info,TRUE);
  GetScrollInfo(bar,SB_CTL,&info);
  if(before==info.nPos)return;
  for(HWND child=GetWindow(view,GW_CHILD);child;child=GetWindow(child,GW_HWNDNEXT)){
   RECT frame;GetWindowRect(child,&frame);MapWindowPoints(HWND_DESKTOP,view,(POINT*)&frame,2);
   SetWindowPos(child,nullptr,frame.left,frame.top+before-info.nPos,0,0,SWP_NOZORDER|SWP_NOSIZE|SWP_NOACTIVATE);
  }
  InvalidateRect(view,nullptr,TRUE);
  InvalidateRect(bar,nullptr,FALSE);
 }
 void requestScroll(HWND view,int action){
  SCROLLINFO info{sizeof(info),SIF_ALL};GetScrollInfo(view==pane?settingsScroll:quickScroll,SB_CTL,&info);
  int next=info.nPos, step=view==quickPane?qp(38):px(38);
  switch(action){
   case SB_LINEUP:next-=step;break;
   case SB_LINEDOWN:next+=step;break;
   case SB_PAGEUP:next-=int(info.nPage);break;
   case SB_PAGEDOWN:next+=int(info.nPage);break;
   case SB_THUMBTRACK:case SB_THUMBPOSITION:next=info.nTrackPos;break;
  }
  scrollPane(view,next);
 }
 bool handleUiMessage(MSG& message){
  HWND root=GetAncestor(message.hwnd,GA_ROOT);
  if(!root||(root!=settingsWindow&&root!=quickWindow)||!IsWindowVisible(root))return false;
  HWND view=root==quickWindow?quickPane:pane;
  if(message.message==WM_MOUSEWHEEL&&view&&GetParent(message.hwnd)==view
     &&className(message.hwnd)!=WC_COMBOBOXW){
   requestScroll(view,GET_WHEEL_DELTA_WPARAM(message.wParam)>0?SB_LINEUP:SB_LINEDOWN);
   return true;
  }
  if(message.message==WM_KEYDOWN&&message.wParam==VK_ESCAPE&&root==quickWindow){
   HWND focus=GetFocus();
   if(!focus||!SendMessageW(focus,CB_GETDROPPEDSTATE,0,0)){ShowWindow(quickWindow,SW_HIDE);return true;}
  }
  if(!IsDialogMessageW(root,&message))return false;
  HWND focus=GetFocus();
  if(view&&focus&&GetParent(focus)==view){
   RECT r, client;
   GetWindowRect(focus,&r);MapWindowPoints(HWND_DESKTOP,view,(POINT*)&r,2);GetClientRect(view,&client);
   SCROLLINFO info{sizeof(info),SIF_POS};GetScrollInfo(view==pane?settingsScroll:quickScroll,SB_CTL,&info);
   if(r.top<0)scrollPane(view,info.nPos+r.top-4);
   else if(r.bottom>client.bottom)scrollPane(view,info.nPos+r.bottom-client.bottom+4);
  }
  return true;
 }
 struct ChoiceGroup {int first,count;int* value;};
 std::array<int,6> paintedChoices{{-1,-1,-1,-1,-1,-1}};
 int paintedPalette=-1;
 std::array<ChoiceGroup,6> choices(){
  return {{{SEG_WEATHER,3,&settings.weather},{SEG_MATERIAL,2,&settings.appearance},
    {SEG_FLAKES,2,&settings.snowflakeStyle},{SEG_CLEANER,2,&settings.cleaner},
    {STYLE_CARDS,3,&settings.style},{QUALITY_CARDS,3,&settings.quality}}};
 }
 bool selectSettingsCard(int id){
  for(auto group:choices())if(id>=group.first&&id<group.first+group.count){
   *group.value=id-group.first;
   if(group.first==STYLE_CARDS&&settings.garland==0){
    settings.garland=1;
    SendMessageW(findControl(controls,MODE),CB_SETCURSEL,1,0);
    InvalidateRect(findControl(controls,MODE),nullptr,FALSE);
   }
   changed();return true;
  }
  return false;
 }
 void refreshSettingsControls(){
  if(HWND preview=findControl(controls,FULL_PREVIEW))InvalidateRect(preview,nullptr,FALSE);
  if(quickWindow&&IsWindowVisible(quickWindow))
   if(HWND preview=findControl(quickControls,QUICK_PREVIEW))InvalidateRect(preview,nullptr,FALSE);
  const bool paletteChanged=paintedPalette!=settings.palette;
  paintedPalette=settings.palette;
  size_t position=0;
  for(auto group:choices()){
   int& previous=paintedChoices[position++];
   if(previous==*group.value&&!(group.first==STYLE_CARDS&&paletteChanged))continue;
   previous=*group.value;
   for(int index=0;index<group.count;index++)
    if(HWND item=findControl(controls,group.first+index))InvalidateRect(item,nullptr,FALSE);
  }
 }
 LRESULT controlColors(UINT message,HDC dc,HWND child){
  static HBRUSH menuBrush=CreateSolidBrush(RGB(37,37,41));
  int id=GetDlgCtrlID(child);
  bool muted=id==HELP_TEXT||id==STATUS_LABEL;
  const bool sidebarChild=child==sidebar||child==status||child==brandTitle;
  bool dropDown=message==WM_CTLCOLORLISTBOX&&child!=sidebar;
  SetTextColor(dc,IsWindowEnabled(child)?muted?settingsTheme::secondary:settingsTheme::foreground:settingsTheme::muted);
  SetBkMode(dc,TRANSPARENT);
  SetBkColor(dc,sidebarChild?settingsTheme::sidebar:settingsTheme::background);
  return (LRESULT)(dropDown?menuBrush:sidebarChild?navBrush:graphite);
 }
 struct SegmentStrip {
  std::array<int,9> geometry{};
  std::unique_ptr<Gdiplus::Bitmap> pixels;
 };
 std::map<int,SegmentStrip> segmentStrips;
 void drawSegmentStrip(const DRAWITEMSTRUCT& item,const ChoiceGroup& group,int value,bool quick,bool active){
  const bool vertical=group.first==QUALITY_CARDS;
  const auto& children=quick?quickControls:controls;
  std::array<int,4> edges{};
  RECT bounds{},child{};
  if(!GetWindowRect(findControl(children,group.first),&bounds))return;
  for(int index=0;index<group.count;index++){
   if(!GetWindowRect(findControl(children,group.first+index),&child))return;
   edges[index+1]=vertical?child.bottom-bounds.top:child.right-bounds.left;
  }
  const int width=vertical?bounds.right-bounds.left:edges[group.count];
  const int height=vertical?edges[group.count]:bounds.bottom-bounds.top;
  if(width<1||height<1)return;
  const int index=int(item.CtlID)-group.first;
  const bool disabled=(item.itemState&ODS_DISABLED)!=0;
  const int activeIndex=active?index:-1;
  const int inset=std::max(1,quick?qp(1):px(1));
  const int radius=quick?qp(settingsTheme::controlRadius):px(settingsTheme::controlRadius);
  const std::array<int,9> geometry{width,height,edges[1],edges[2],value,activeIndex,disabled,inset,radius};
  auto& cache=segmentStrips[group.first];
  if(!cache.pixels||cache.geometry!=geometry){
   cache.geometry=geometry;
   cache.pixels=std::make_unique<Gdiplus::Bitmap>(width,height,PixelFormat32bppPARGB);
   Gdiplus::Graphics g(cache.pixels.get());
   g.Clear(settingsTheme::color(settingsTheme::background));
   g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
   const auto outer=settingsTheme::frame({0,0,width,height});
   if(vertical)settingsTheme::solidSurface(g,outer,float(radius),0x19191C,0x494A51);
   else settingsTheme::surface(g,outer,float(radius),false,disabled);
   auto drawInner=[&](int part,bool selected,bool emphasized){
    using namespace settingsTheme;
    const bool first=part==0,last=part==group.count-1;
    const int begin=edges[part]+(first?inset:0);
    const int end=edges[part+1]-(last?inset:0);
    const float innerRadius=std::max(0.f,float(radius-inset)+.5f);
    if(vertical){
     const unsigned corners=(first?(topLeft|topRight):0)|(last?(bottomLeft|bottomRight):0);
     solidSurface(g,{float(inset),float(begin),float(width-2*inset),float(end-begin)},
                  innerRadius,selected?emphasized?0x383943:0x30313A:0x25262B,0,corners);
    }else{
     const unsigned corners=(first?(topLeft|bottomLeft):0)|(last?(topRight|bottomRight):0);
     surface(g,{float(begin),float(inset),float(end-begin),float(height-2*inset)},
             innerRadius,selected,disabled,emphasized,false,corners);
    }
   };
   if(value>=0&&value<group.count)drawInner(value,true,value==activeIndex);
   if(activeIndex>=0&&activeIndex!=value)drawInner(activeIndex,false,true);
   if(vertical){
    Gdiplus::SolidBrush separator(Painter::color(0x494A51));
    for(int edge=1;edge<group.count;edge++)
     g.FillRectangle(&separator,inset,edges[edge],width-2*inset,1);
   }
  }
  // Use the actual device edges so adjacent items share the same outer border.
  Gdiplus::Graphics graphics(item.hDC);
  graphics.DrawImage(cache.pixels.get(),int(item.rcItem.left)-(vertical?0:edges[index]),
                     int(item.rcItem.top)-(vertical?edges[index]:0),width,height);
 }
 void drawSettingsControl(const DRAWITEMSTRUCT& item,bool quick){
  settingsTheme::ControlBuffer buffer(item.hDC,item.rcItem);
  auto local=item;
  local.hDC=buffer.dc();
  if(local.hDC!=item.hDC)OffsetRect(&local.rcItem,-local.rcItem.left,-local.rcItem.top);
  paintSettingsControl(local,quick);
 }
 void paintSettingsControl(const DRAWITEMSTRUCT& item,bool quick){
  int id=int(item.CtlID);
  if(id==QUICK_PREVIEW||id==FULL_PREVIEW){drawPreview(item,quick?0:selectedPane);return;}
  RECT area=item.rcItem;
  auto scale=[&](int n){return quick?qp(n):px(n);};
  const float radius=float(scale(settingsTheme::controlRadius));
  const bool disabled=(item.itemState&ODS_DISABLED)!=0,pressed=(item.itemState&ODS_SELECTED)!=0;
  const bool engaged=pressed||keyboardFocus(item.hwndItem);
  using Icon=settingsTheme::Icon;
  auto icon=[&](Icon icon,RECT frame,COLORREF tint){settingsTheme::icon(item.hDC,icon,frame,tint);};
  auto drawCenteredIcon=[&](Icon iconKind,int size,COLORREF tint){
   int d=scale(size);
   int x=(area.left+area.right-d)/2,y=(area.top+area.bottom-d)/2;
   icon(iconKind,{x,y,x+d,y+d},tint);
  };
  if(item.CtlType==ODT_COMBOBOX){
   SetDCBrushColor(item.hDC,RGB(38,38,42));
   FillRect(item.hDC,&area,(HBRUSH)GetStockObject(DC_BRUSH));
   if(pressed){
    Gdiplus::Graphics g(item.hDC);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    RECT selection=area;InflateRect(&selection,-scale(2),-1);
    settingsTheme::solidSurface(g,settingsTheme::frame(selection,0),radius,0xA4AABB);
   }
   if(item.itemID!=UINT(-1)){
    LRESULT length=SendMessageW(item.hwndItem,CB_GETLBTEXTLEN,item.itemID,0);
    if(length>=0){
     std::wstring caption(size_t(length)+1,L'\0');
     SendMessageW(item.hwndItem,CB_GETLBTEXT,item.itemID,(LPARAM)caption.data());
     auto prev=SelectObject(item.hDC,quick?quickFont:font);
     SetBkMode(item.hDC,TRANSPARENT);
     SetTextColor(item.hDC,pressed?settingsTheme::ink:settingsTheme::foreground);
     area.left+=scale(12);
     DrawTextW(item.hDC,caption.c_str(),-1,&area,DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS|DT_NOPREFIX);
     SelectObject(item.hDC,prev);
    }
   }
   return;
  }
  bool sidebarControl=id==SIDEBAR_LANGUAGE||(id==SETTINGS_BRAND_ICON&&!quick);
  FillRect(item.hDC,&area,sidebarControl?navBrush:graphite);
  if(id==SETTINGS_RULE){
   SetDCBrushColor(item.hDC,settingsTheme::line);
   FillRect(item.hDC,&area,(HBRUSH)GetStockObject(DC_BRUSH));return;
  }
  if(id==SETTINGS_BRAND_ICON||id==PRIVACY_ICON){
   drawCenteredIcon(Icon::flake,id==PRIVACY_ICON?48:quick?27:32,settingsTheme::foreground);return;
  }
  int tool=id==MITTEN?1:id==SNOWBALL?0:id==SHOVEL?2:id==DELETE_TOOL?3:-1;
  int first=0,count=0,value=0;
  if(id>=QUICK_LIGHT&&id<QUICK_LIGHT+3){first=QUICK_LIGHT;count=3;value=settings.weather;}
  for(auto group:choices())if(id>=group.first&&id<group.first+group.count){
   first=group.first;count=group.count;value=*group.value;break;
  }
  bool segment=first&&first!=QUALITY_CARDS&&first!=STYLE_CARDS;
  bool selected=first?id-first==value:tool>=0&&interactive&&settings.tool==tool;
  if(id==FULL_PAUSE||id==QUICK_PAUSE)selected=true;
  if(id==RUNCLEANER&&!quick)selected=true;
  const COLORREF tint=disabled?settingsTheme::muted:selected&&first!=QUALITY_CARDS?settingsTheme::ink:settingsTheme::foreground;
  SetBkMode(item.hDC,TRANSPARENT);
  SetTextColor(item.hDC,tint);
  wchar_t caption[256]{};GetWindowTextW(item.hwndItem,caption,256);
  auto old=SelectObject(item.hDC,quick?quickFont:selected?strongFont:font);
  auto print=[&](const wchar_t* text,RECT frame,UINT alignment){
   DrawTextW(item.hDC,text,-1,&frame,DT_SINGLELINE|DT_VCENTER|DT_END_ELLIPSIS|DT_NOPREFIX|alignment);
  };
  if(segment){
   drawSegmentStrip(item,{first,count,nullptr},value,quick,engaged);
   print(caption,area,DT_CENTER);
  }else if(first==QUALITY_CARDS){
   drawSegmentStrip(item,{first,count,nullptr},value,quick,engaged);
   int x=area.left+scale(16),y=(area.top+area.bottom)/2-scale(9);
   {
    Gdiplus::Graphics graphics(item.hDC);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    Gdiplus::Pen border(Painter::color(0xB5B8C7),1.5f);
    graphics.DrawEllipse(&border,x,y,scale(18),scale(18));
    if(selected){
     Gdiplus::SolidBrush dot(Painter::color(0xB7BBC9));
     graphics.FillEllipse(&dot,x+scale(4),y+scale(4),scale(10),scale(10));
    }
   }
   SelectObject(item.hDC,strongFont);
   RECT title{area.left+scale(53),area.top+scale(10),area.right-scale(10),area.top+scale(35)};
   print(caption,title,DT_LEFT);
   const wchar_t* notes[]={tr(L"Умеренная нагрузка · до 30 кадров/с"),tr(L"До 30 кадров/с"),tr(L"До 60 кадров/с")};
   SelectObject(item.hDC,smallFont);SetTextColor(item.hDC,settingsTheme::secondary);
   title.top=area.top+scale(35);title.bottom=area.bottom-scale(8);
   print(notes[id-first],title,DT_LEFT);
  }else if(first==STYLE_CARDS){
   settingsTheme::surface(item.hDC,area,radius,selected,disabled,engaged);
   drawGarlandSwatch(item,id-first);
   RECT text=area;text.top=area.bottom-scale(30);
   print(caption,text,DT_CENTER);
  }else if(id==SIDEBAR_LANGUAGE||id==AUTHOR){
   if(id==SIDEBAR_LANGUAGE){
    icon(Icon::globe,{area.left+scale(4),area.top+scale(8),area.left+scale(17),area.bottom-scale(8)},settingsTheme::foreground);
    icon(Icon::down,{area.right-scale(17),area.top+scale(7),area.right-scale(5),area.bottom-scale(7)},settingsTheme::foreground);
    area.left+=scale(23);area.right-=scale(21);
   }else SetTextColor(item.hDC,settingsTheme::secondary);
   print(caption,area,DT_LEFT);
  }else if(id==QUICK_MORE){
   drawCenteredIcon(Icon::more,14,tint);
  }else if(id==FULL_PAUSE||id==QUICK_PAUSE){
   settingsTheme::surface(item.hDC,area,radius,true,false,engaged);
   drawCenteredIcon(paused?Icon::play:Icon::pause,quick?13:15,tint);
  }else if(tool==0||tool==1){
   settingsTheme::surface(item.hDC,area,radius,selected,disabled,engaged);
   auto symbol=tool==1?Icon::mitten:Icon::snowball;
   if(quick)drawCenteredIcon(symbol,22,tint);
   else{
    int x=(area.left+area.right-scale(24))/2;
    icon(symbol,{x,area.top+scale(20),x+scale(24),area.top+scale(46)},tint);
    RECT text=area;text.top=area.top+scale(47);text.bottom=area.bottom-scale(11);
    print(caption,text,DT_CENTER);
   }
  }else{
   if(id==ESC_KEY){
    Gdiplus::Graphics g(item.hDC);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    settingsTheme::solidSurface(g,settingsTheme::frame(area,0),radius,0x242426);
   }else settingsTheme::surface(item.hDC,area,radius,selected,disabled,engaged);
   bool left=id==CLEAR||id==RUNCLEANER||id==QUICK_OPEN||id==DISPLAY_MENU||id==STARTUP_SETTINGS;
   if(left){
    Icon symbol=id==CLEAR?Icon::sun:id==RUNCLEANER?Icon::broom:id==DISPLAY_MENU?Icon::monitor:id==STARTUP_SETTINGS?Icon::external:Icon::gear;
    int y=(area.top+area.bottom-scale(20))/2;
    icon(symbol,{area.left+scale(13),y,area.left+scale(33),y+scale(20)},tint);
    RECT text=area;text.left+=scale(42);text.right-=scale(12);
    if(id==QUICK_OPEN||id==DISPLAY_MENU){
     icon(id==QUICK_OPEN?Icon::next:Icon::down,{area.right-scale(23),y,area.right-scale(8),y+scale(20)},tint);
     text.right-=scale(16);
    }
    print(caption,text,DT_LEFT);
   }else print(caption,area,DT_CENTER);
  }
  SelectObject(item.hDC,old);
 }
 void drawGarlandSwatch(const DRAWITEMSTRUCT& item,int style){
  RECT area=item.rcItem;
  const int w=std::min<int>(px(90),area.right-area.left-px(16)),h=px(44);
  if(w<=0)return;
  auto& cached=garlandCards[style];
  if(!cached.image||cached.key[0]!=w||cached.key[1]!=h||cached.key[2]!=settings.palette){
   cached.key[0]=w;cached.key[1]=h;cached.key[2]=settings.palette;
   cached.image=makeGarlandSwatch(w,h,style,settings.palette);
  }
  const LONG left=(area.left+area.right-w)/2,top=area.top+px(9);
  settingsTheme::roundedImage(item.hDC,*cached.image,{left,top,left+w,top+h},float(px(settingsTheme::controlRadius)));
 }
 struct CachedPreview {
  std::array<int,19> key{};
  std::unique_ptr<Gdiplus::Bitmap> image;
 };
 CachedPreview fullPreview,quickPreview,garlandCards[3];
 void drawPreview(const DRAWITEMSTRUCT& item,int section){
  RECT rect=item.rcItem;
  int width=rect.right-rect.left, height=rect.bottom-rect.top;
  if(width<=0||height<=0)return;
  std::array<int,19> key{width,height,section,settings.appearance,settings.weather,settings.snowflakeStyle,
    int(settings.snowflakeSize*100),int(settings.wind),settings.cleaner,settings.garland,settings.style,
    settings.palette,int(settings.brightness*100)*101+int(settings.intensity*100),
    settings.windows,settings.bottom,int(settings.windowHeight),int(settings.bottomHeight),
    int(settings.taskbar)+2*int(anyTree()),int(monitors.size())};
  auto& cache=item.CtlID==QUICK_PREVIEW?quickPreview:fullPreview;
  if(!cache.image||cache.key!=key){
   cache.key=key;
   cache.image=makeGraphitePreview(width,height,section,settings,item.CtlID==QUICK_PREVIEW,anyTree(),monitors.size());
  }
  FillRect(item.hDC,&rect,graphite);
  bool compact=item.CtlID==QUICK_PREVIEW;
  const float radius=float(compact?qp(settingsTheme::overlayRadius):px(settingsTheme::overlayRadius));
  settingsTheme::roundedImage(item.hDC,*cache.image,rect,radius,0x63646C);
 }
