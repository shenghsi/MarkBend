; Offer MarkBend in Open With. Never set an extension's default application.
; SHCTX follows the installer's current-user/all-users scope.
!define MARKBEND_PROGID "dev.markbend.editor.Markdown"
!define MARKBEND_COMMAND '$\"$INSTDIR\${MAINBINARYNAME}.exe$\" $\"%1$\"'

!macro NSIS_HOOK_POSTINSTALL
  WriteRegStr SHCTX "Software\Classes\${MARKBEND_PROGID}" "" "MarkBend document"
  WriteRegStr SHCTX "Software\Classes\${MARKBEND_PROGID}\DefaultIcon" "" '$\"$INSTDIR\${MAINBINARYNAME}.exe$\",0'
  WriteRegStr SHCTX "Software\Classes\${MARKBEND_PROGID}\shell\open\command" "" '${MARKBEND_COMMAND}'
  WriteRegStr SHCTX "Software\Classes\.md\OpenWithProgids" "${MARKBEND_PROGID}" ""
  WriteRegStr SHCTX "Software\Classes\.markdown\OpenWithProgids" "${MARKBEND_PROGID}" ""
  WriteRegStr SHCTX "Software\Classes\.txt\OpenWithProgids" "${MARKBEND_PROGID}" ""
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  ; A newer installation can own this ProgID. Keep its registration intact.
  ReadRegStr $R7 SHCTX "Software\Classes\${MARKBEND_PROGID}\shell\open\command" ""
  ${If} $R7 == '${MARKBEND_COMMAND}'
    DeleteRegValue SHCTX "Software\Classes\.md\OpenWithProgids" "${MARKBEND_PROGID}"
    DeleteRegValue SHCTX "Software\Classes\.markdown\OpenWithProgids" "${MARKBEND_PROGID}"
    DeleteRegValue SHCTX "Software\Classes\.txt\OpenWithProgids" "${MARKBEND_PROGID}"
    DeleteRegValue SHCTX "Software\Classes\${MARKBEND_PROGID}\shell\open\command" ""
    DeleteRegValue SHCTX "Software\Classes\${MARKBEND_PROGID}\DefaultIcon" ""
    DeleteRegValue SHCTX "Software\Classes\${MARKBEND_PROGID}" ""
    DeleteRegKey /ifempty SHCTX "Software\Classes\${MARKBEND_PROGID}\shell\open\command"
    DeleteRegKey /ifempty SHCTX "Software\Classes\${MARKBEND_PROGID}\shell\open"
    DeleteRegKey /ifempty SHCTX "Software\Classes\${MARKBEND_PROGID}\shell"
    DeleteRegKey /ifempty SHCTX "Software\Classes\${MARKBEND_PROGID}\DefaultIcon"
    DeleteRegKey /ifempty SHCTX "Software\Classes\${MARKBEND_PROGID}"
  ${EndIf}
!macroend
