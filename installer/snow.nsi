Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "WinVer.nsh"
Name "Снег"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\Snow"
InstallDirRegKey HKCU "Software\SnowDesktop" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "Snow 0.2.19-win.1"
!define MUI_ICON "${APPDIR}/assets/snow.ico"
!define MUI_UNICON "${APPDIR}/assets/snow.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Снег для Windows"
!define MUI_WELCOMEPAGE_TEXT "Снег, снежинки, снежки, гирлянды, пять ёлочек и два трактора на рабочем столе.$\r$\n$\r$\nУстановка для текущего пользователя. Права администратора и подключение к интернету не требуются.$\r$\n$\r$\nПеред обновлением завершите Снег через значок в области уведомлений."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\Snow.exe"
!define MUI_FINISHPAGE_RUN_PARAMETERS "--settings"
!define MUI_FINISHPAGE_RUN_TEXT "Запустить Снег"
!insertmacro MUI_PAGE_FINISH
!define MUI_UNCONFIRMPAGE_TEXT_TOP "Приложение и ярлыки будут удалены. Личные настройки останутся в локальных данных пользователя."
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "Russian"
VIProductVersion "0.2.19.1"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "ProductName" "Снег для Windows"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileDescription" "Установщик Снега"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileVersion" "0.2.19.1"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "LegalCopyright" "Snow Desktop"

Function .onInit
 ${IfNot} ${RunningX64}
  MessageBox MB_ICONSTOP "Нужна 64-разрядная Windows 10 или Windows 11."
  Abort
 ${EndIf}
 ${IfNot} ${AtLeastWin10}
  MessageBox MB_ICONSTOP "Нужна Windows 10 или Windows 11."
  Abort
 ${EndIf}
 SetRegView 64
 FindWindow $0 "SnowDesktop.Tray"
 ${If} $0 != 0
  MessageBox MB_ICONSTOP "Сначала завершите Снег через значок в области уведомлений, затем снова запустите установщик."
  Abort
 ${EndIf}
FunctionEnd

Section "Снег" SEC_SNOW
 SetShellVarContext current
 SetOutPath "$INSTDIR"
 File "${APPDIR}/Snow.exe"
 File "${APPDIR}/INSTALL.txt"
 File "${APPDIR}/THIRD_PARTY.md"
 SetOutPath "$INSTDIR\assets"
 File "${APPDIR}/assets/snow.ico"
 File "${APPDIR}/assets/cabin.png"
 File "${APPDIR}/assets/porch.png"
 File "${APPDIR}/assets/tree-vector.svg"
 SetOutPath "$INSTDIR\licenses"
 File /nonfatal "${APPDIR}/licenses/*"
 SetOutPath "$INSTDIR"
 WriteUninstaller "$INSTDIR\Uninstall.exe"
 CreateDirectory "$SMPROGRAMS\Снег"
 CreateShortcut "$SMPROGRAMS\Снег\Снег.lnk" "$INSTDIR\Snow.exe" "--settings" "$INSTDIR\Snow.exe" 0
 CreateShortcut "$SMPROGRAMS\Снег\Удалить Снег.lnk" "$INSTDIR\Uninstall.exe"
 WriteRegStr HKCU "Software\SnowDesktop" "InstallDir" "$INSTDIR"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "DisplayName" "Снег"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "DisplayVersion" "0.2.19.1"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "DisplayIcon" "$INSTDIR\Snow.exe"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "InstallLocation" "$INSTDIR"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "NoModify" 1
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "NoRepair" 1
SectionEnd

Function un.onInit
 SetRegView 64
 FindWindow $0 "SnowDesktop.Tray"
 ${If} $0 != 0
  MessageBox MB_ICONSTOP "Сначала завершите Снег через значок в области уведомлений."
  Abort
 ${EndIf}
FunctionEnd
Section "Uninstall"
 SetShellVarContext current
 ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "SnowDesktop"
 StrCmp $0 '$\"$INSTDIR\Snow.exe$\"' 0 +2
 DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "SnowDesktop"
 Delete "$SMPROGRAMS\Снег\Снег.lnk"
 Delete "$SMPROGRAMS\Снег\Удалить Снег.lnk"
 RMDir "$SMPROGRAMS\Снег"
 Delete "$INSTDIR\Snow.exe"
 Delete "$INSTDIR\INSTALL.txt"
 Delete "$INSTDIR\THIRD_PARTY.md"
 Delete "$INSTDIR\assets\snow.ico"
 Delete "$INSTDIR\assets\cabin.png"
 Delete "$INSTDIR\assets\porch.png"
 Delete "$INSTDIR\assets\tree-vector.svg"
 RMDir "$INSTDIR\assets"
 Delete "$INSTDIR\licenses\LLVM.txt"
 Delete "$INSTDIR\licenses\Zig.txt"
 Delete "$INSTDIR\licenses\NSIS.txt"
 RMDir "$INSTDIR\licenses"
 Delete "$INSTDIR\Uninstall.exe"
 RMDir "$INSTDIR"
 DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop"
 DeleteRegKey HKCU "Software\SnowDesktop"
SectionEnd
