Unicode true
Name "MarkBend Open With compile check"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\MarkBend check"
RequestExecutionLevel user
!include "LogicLib.nsh"
!define MAINBINARYNAME "markbend-desktop"
!include "${HOOK}"
Section
  SetShellVarContext current
  !insertmacro NSIS_HOOK_POSTINSTALL
  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd
Section "Uninstall"
  SetShellVarContext current
  !insertmacro NSIS_HOOK_POSTUNINSTALL
SectionEnd
