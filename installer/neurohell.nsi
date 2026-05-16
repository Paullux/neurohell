; ============================================================
;  NeuroHell — Installeur NSIS
;  Généré par le CI GitHub Actions
;  makensis -DAPP_VERSION=vX.Y.Z installer/neurohell.nsi
; ============================================================

!ifndef APP_VERSION
  !define APP_VERSION "dev"
!endif

!define APP_NAME     "NeuroHell"
!define APP_EXE      "NeuroHell.exe"
!define PUBLISHER    "NeuroHell"
!define INSTALL_DIR  "$PROGRAMFILES64\NeuroHell"
!define REG_KEY      "Software\Microsoft\Windows\CurrentVersion\Uninstall\NeuroHell"

; ── Métadonnées installeur ────────────────────────────────
Name            "${APP_NAME} ${APP_VERSION}"
OutFile         "NeuroHell-Setup.exe"
InstallDir      "${INSTALL_DIR}"
InstallDirRegKey HKLM "Software\${APP_NAME}" "Install_Dir"
RequestExecutionLevel admin
SetCompressor   /SOLID lzma

; ── Icône ─────────────────────────────────────────────────
; Chemin relatif au répertoire du script (installer/)
Icon            "icon.ico"
UninstallIcon   "icon.ico"

; ── Interface MUI2 ────────────────────────────────────────
!include "MUI2.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON    "icon.ico"
!define MUI_UNICON  "icon.ico"

; Pages installation
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN          "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT     "Lancer NeuroHell"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

; Pages désinstallation
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Langue française en priorité, anglais en fallback
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "English"

; ── Section principale ────────────────────────────────────
Section "NeuroHell (requis)" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; Copier tous les fichiers du build Windows
  ; BUILD_DIR est passé en argument par le CI : -DBUILD_DIR=<chemin absolu>
  !ifndef BUILD_DIR
    !define BUILD_DIR "build/NeuroHell-Windows"
  !endif
  File /r "${BUILD_DIR}/"

  ; Raccourci Menu Démarrer
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" \
                  "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0

  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\Désinstaller ${APP_NAME}.lnk" \
                  "$INSTDIR\Uninstall.exe"

  ; Raccourci Bureau
  CreateShortcut  "$DESKTOP\${APP_NAME}.lnk" \
                  "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0

  ; Désinstalleur
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Registre Ajout/Suppression de programmes
  WriteRegStr HKLM "${REG_KEY}" "DisplayName"     "${APP_NAME}"
  WriteRegStr HKLM "${REG_KEY}" "DisplayVersion"  "${APP_VERSION}"
  WriteRegStr HKLM "${REG_KEY}" "Publisher"       "${PUBLISHER}"
  WriteRegStr HKLM "${REG_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "${REG_KEY}" "DisplayIcon"     "$INSTDIR\${APP_EXE}"
  WriteRegStr HKLM "${REG_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKLM "${REG_KEY}" "NoModify"      1
  WriteRegDWORD HKLM "${REG_KEY}" "NoRepair"      1
SectionEnd

; ── Section désinstallation ───────────────────────────────
Section "Uninstall"
  ; Supprimer fichiers
  RMDir /r "$INSTDIR"

  ; Supprimer raccourcis
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Désinstaller ${APP_NAME}.lnk"
  RMDir  "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"

  ; Nettoyer registre
  DeleteRegKey HKLM "${REG_KEY}"
  DeleteRegKey HKLM "Software\${APP_NAME}"
SectionEnd
