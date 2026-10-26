#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; ═══════════════════════════════════════════════════════════════
;  MOUNT BLUE ENFORCER v5
; ═══════════════════════════════════════════════════════════════

; ─── Inicializace proměnných PŘED vším ostatním (HotIf je vyhodnocuje okamžitě) ───
global g_started        := false
global g_done           := false
global g_textReady      := false
global g_locked         := false
global g_mode           := "starting"

; ─── AUTO-UPDATE KONFIGURACE ───────────────────────────────────
UPDATE_VERSION_URL := "https://raw.githubusercontent.com/adafore/mountblue-updater/refs/heads/main/version.txt"
UPDATE_SCRIPT_URL  := "https://raw.githubusercontent.com/adafore/mountblue-updater/refs/heads/main/PovinePsani.ahk"
LOCAL_VERSION_FILE := A_AppData . "\MountBlueEnforcer\version.txt"
THIS_SCRIPT_VERSION := 14   ; ZVYŠ toto číslo při každém uploadu nové verze na GitHub
UPDATE_TIMEOUT_MS   := 4000
; ─────────────────────────────────────────────────────────────

CheckForUpdate()

; ─── KONFIGURACE ───────────────────────────────────────────────
APP_PATH          := "C:\Program Files (x86)\HYL\MountBlue\MountBlue.exe"
DONE_DIR          := A_AppData . "\MountBlueEnforcer"
SESSION_DAY       := ""
DONE_FILE         := ""
STATE_FILE        := ""
SetDayFiles()
DEFAULT_DAILY_GOAL := 250
BROTHER_DAILY_GOAL := 300
MIN_TEXT_LEN      := DEFAULT_DAILY_GOAL
START_HOUR        := 11
OVERLAY_W         := 520
POSTPONE_MAX      := 3
POSTPONE_MIN      := 30
WEEKLY_GOAL       := MIN_TEXT_LEN * 10
; ───────────────────────────────────────────────────────────────

; ═══════════════════════════════════════════════════════════════
;  AUTO-UPDATE — zkontroluje GitHub, stáhne novější verzi, restartuje
; ═══════════════════════════════════════════════════════════════
CheckForUpdate() {
    global UPDATE_VERSION_URL, UPDATE_SCRIPT_URL, THIS_SCRIPT_VERSION

    if InStr(UPDATE_VERSION_URL, "TVOJE_JMENO")
        return

    tempVerFile := A_Temp . "\mbe_version_check.txt"

    try {
        Download(UPDATE_VERSION_URL, tempVerFile)
    } catch {
        return
    }

    if !FileExist(tempVerFile)
        return

    raw := FileRead(tempVerFile, "UTF-8")
    FileDelete tempVerFile
    raw := StrReplace(raw, "`r", "")
    raw := StrReplace(raw, "`n", "")
    raw := StrReplace(raw, Chr(0xFEFF), "")
    raw := Trim(raw)
    if !IsInteger(raw)
        return

    remoteVersion := Integer(raw)
    if (remoteVersion <= THIS_SCRIPT_VERSION)
        return  ; verze je aktuální — nic nezobrazuj

    ; ── Nová verze — zobraz hezké oznámení ──
    updateGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "Update")
    updateGui.BackColor := "0A0F2E"
    updateGui.MarginX := 0
    updateGui.MarginY := 0

    ; Modrý pruh nahoře
    updateGui.Add("Text", "x0 y0 w340 h3 Background2A6FCC", "")

    updateGui.SetFont("s11 w700 c2A6FCC", "Segoe UI")
    updateGui.Add("Text", "x20 y16 w300", "Mount Blue  —  aktualizace")

    updateGui.SetFont("s9 w400 c5BC8F5", "Segoe UI")
    updateGui.Add("Text", "x20 y42 w300", "Stahuje se nová verze…")

    updateGui.SetFont("s8 w400 c3A5080", "Segoe UI")
    updateGui.Add("Text", "x20 y62 w300", "v" . THIS_SCRIPT_VERSION . "  →  v" . remoteVersion)

    screenW := SysGet(78)
    screenH := SysGet(79)
    updateGui.Show("x" . (screenW//2 - 170) . " y" . (screenH - 130) . " w340 h92 NoActivate")

    Sleep 400

    ; ── Stáhni skript ──
    tempScriptFile := A_Temp . "\mbe_new_version.ahk"
    try {
        Download(UPDATE_SCRIPT_URL, tempScriptFile)
    } catch {
        updateGui.Destroy()
        return
    }

    if !FileExist(tempScriptFile) {
        updateGui.Destroy()
        return
    }
    if FileGetSize(tempScriptFile) < 1000 {
        updateGui.Destroy()
        return
    }
    try {
        chk := FileRead(tempScriptFile, "UTF-8")
        if !InStr(chk, "#Requires AutoHotkey") {
            updateGui.Destroy()
            return
        }
    } catch {
        updateGui.Destroy()
        return
    }

    ; ── Nahraď a restartuj ──
    currentScriptPath := A_ScriptFullPath
    try {
        FileCopy tempScriptFile, currentScriptPath, true
    } catch {
        updateGui.Destroy()
        FileDelete tempScriptFile
        return
    }
    FileDelete tempScriptFile

    ; Aktualizuj text na "hotovo"
    updateGui.Destroy()
    doneGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "UpdateDone")
    doneGui.BackColor := "0A0F2E"
    doneGui.MarginX := 0
    doneGui.MarginY := 0
    doneGui.Add("Text", "x0 y0 w340 h3 Background2A6FCC", "")
    doneGui.SetFont("s11 w700 c2A6FCC", "Segoe UI")
    doneGui.Add("Text", "x20 y16 w300", "Mount Blue  —  aktualizace")
    doneGui.SetFont("s9 w400 c3DFFA0", "Segoe UI")
    doneGui.Add("Text", "x20 y42 w300", "✔  Aktualizováno na v" . remoteVersion . "  —  restartuji…")
    doneGui.Show("x" . (screenW//2 - 170) . " y" . (screenH - 130) . " w340 h72 NoActivate")

    Sleep 1200
    doneGui.Destroy()

    Run '"' . A_AhkPath . '" "' . currentScriptPath . '"'
    ExitApp
}

; ── Stav ──
global g_done           := false
global g_started        := false
global g_overlay        := 0
global g_locked         := false
global g_textReady      := false
global g_sourceText     := ""
global g_typedText      := ""      ; co uživatel píše — sledujeme sami
global g_passedCount    := 0
global g_lastErrors     := -1
global g_lastCorrectChars := 0
global g_lastResult     := ""
global g_evaluating     := false
global g_exerciseNum       := 1       ; číslo aktuálního cvičení
global g_charsAccumulated  := 0       ; součet správně zarovnaných znaků
global g_weeklyChars      := 0     ; znaky naakumulované pro týdenní cíl
global g_weeklyDays       := 0     ; počet dokončených dnů v týdnu
global g_weeklyDone       := false ; týdenní cíl splněn
global g_weeklyLastDay    := ""    ; datum posledního dne kdy se přičetly dny
global g_weekFile         := ""    ; cesta k souboru týdenního cíle
global g_weekStartFile    := ""    ; cesta k souboru s datem startu okna
global g_btnUnlockGui     := 0     ; tlačítko odemknout
global g_btnUnlockBorder  := 0
global g_dailyDone        := false  ; denní cíl splněn, hotkeys stále aktivní pro týdenní

; Filtry
global g_filterMode     := ""
global g_filterLetter   := ""
global g_filterRepeat   := 1
global g_awaitLetter    := ""

; Heslo dialog
global g_passwordOpen   := false
global g_deleteCount    := 0
global g_deleteLocked   := false
global g_lastClipboard  := ""

; Odložení
global g_postponeCount  := 0
global g_postponedUntil := 0
global g_mode := "starting"
global g_device := Map()
global g_log := Map()
global g_inputHook := 0
global g_caret := 0
global g_anchor := 0
global g_retryGui := 0

; Overlay labely
global lbl_status, lbl_source_len, lbl_source_count, lbl_filter, lbl_expected
global lbl_confirm, btn_confirm_yes, btn_confirm_no
global lbl_weekly
global lbl_result, lbl_errors, lbl_typed, lbl_typed_label
global lbl_postpone, btn_postpone
global lbl_task
global g_btnYesGui    := 0
global g_btnNoGui     := 0
global g_btnYesBorder := 0
global g_btnNoBorder  := 0

; ═══════════════════════════════════════════════════════════════
;  START
; ═══════════════════════════════════════════════════════════════
; Tydenni obdobi obsahuje sedm dokoncenych dennich cilu.
InitDeviceConfig()
if HasArgument("--setup") {
    ShowDeviceSetup()
    return
}
g_weekFile := A_AppData . "\MountBlueEnforcer\week_state.txt"
g_weekStartFile := A_AppData . "\MountBlueEnforcer\week_start.txt"
LoadWeeklyState()
InitWeekWindow()

if FileExist(DONE_FILE) {
    if !IsWeeklyRequired()
        ExitApp
    g_dailyDone := true
}

; Načti stav z předchozího sezení
LoadState()

; Před 11:00 nedělej absolutně nic — jen čekej
SetTimer CheckDateChange, 1000
WaitUntilHour()
if CheckDateChange()
    return

; Dvojitá pojistka — po probuzení zkontroluj čas znovu
if Integer(FormatTime(, "H")) < START_HOUR
    ExitApp

g_started := true
InitPracticeLogs()
OnExit PracticeExit
StartPracticeInput()
CreateOverlay()
SetTimer WatchWindow, 1000
SetTimer PollClipboard, 800
SetTimer FlushPracticeLogs, 2000
SetTimer SyncSharedLogs, 15000
TryStartPractice()
return


; ═══════════════════════════════════════════════════════════════
;  SCHRÁNKA — automatické načtení zadaného textu
; ═══════════════════════════════════════════════════════════════
ClipboardChanged(DataType) {
    global g_sourceText, g_lastResult, g_lastErrors, g_textReady
    global g_done, g_typedText, g_exerciseNum, lbl_status, g_overlay
    global g_lastClipboard, g_mode

    if (DataType != 1 || g_done || CheckDateChange())
        return
    if g_mode != "practice" && g_mode != "daily_done"
        return
    if !IsSourceWindowActive() {
        g_lastClipboard := A_Clipboard
        return
    }

    copied := Trim(A_Clipboard)
    if StrLen(copied) < 5
        return

    ; Vyčisti OCR enters
    cleaned := StrReplace(copied, "`r`n", " ")
    cleaned := StrReplace(cleaned, "`n",  " ")
    cleaned := StrReplace(cleaned, "`r",  " ")
    loop {
        prev    := cleaned
        cleaned := StrReplace(cleaned, "  ", " ")
        if cleaned = prev
            break
    }
    cleaned := Trim(cleaned)

    FlushPracticeLogs()
    g_lastClipboard := A_Clipboard
    QueuePracticeEvent("source", cleaned)
    QueuePracticeReport("Zadání cvičení", cleaned)
    g_sourceText  := cleaned
    g_lastResult  := ""
    g_lastErrors  := -1
    g_textReady   := true
    ResetTypedInput()

    UpdateOverlay()
    UpdateTask()
    if IsObject(g_overlay)
        lbl_status.Value := "Text nastaven (" . StrLen(g_sourceText) . " znaku) - muzes psat!"
}

; ═══════════════════════════════════════════════════════════════
;  POLLING SCHRÁNKY (záloha za OnClipboardChange která nefunguje při BlockInput)
; ═══════════════════════════════════════════════════════════════
PollClipboard(*) {
    global g_done, g_lastClipboard
    if g_done
        return
    current := A_Clipboard
    if (current != g_lastClipboard && StrLen(Trim(current)) >= 5) {
        g_lastClipboard := current
        ClipboardChanged(1)
    }
}

; ═══════════════════════════════════════════════════════════════
;  TIMERY
; ═══════════════════════════════════════════════════════════════
WatchWindow(*) {
    global g_done, g_mode, g_overlay
    if g_done || g_mode != "practice"
        return
    if IsObject(g_overlay) && WinActive("ahk_id " . g_overlay.Hwnd)
        return
    try activeExe := ProcessGetName(WinGetPID("A"))
    catch
        activeExe := ""
    if InStr(activeExe, "PowerToys") || InStr(activeExe, "Spotify")
        || InStr(activeExe, "SnippingTool") || InStr(activeExe, "ScreenSketch")
        return
    if activeExe != "MountBlue.exe" && !ActivateMountBlue(1)
        ShowStartupFailure()
}

; ═══════════════════════════════════════════════════════════════
;  HOTKEYS
; ═══════════════════════════════════════════════════════════════

; Ctrl+Enter = vyhodnoť
#HotIf IsPracticeInputActive()
~^Enter:: {
    EvaluateExercise()
}

; F1 = reset filtrů
~F1:: {
    global g_filterMode, g_filterLetter, g_filterRepeat, g_awaitLetter
    g_filterMode := "" , g_filterLetter := "" , g_filterRepeat := 1 , g_awaitLetter := ""
    UpdateOverlay()
}
~F2:: {
    global g_filterMode, g_awaitLetter, g_filterLetter
    g_filterMode := "reverse" , g_filterLetter := "" , g_awaitLetter := ""
    UpdateOverlay()
}
~F3:: {
    global g_awaitLetter
    g_awaitLetter := "startswith"
    UpdateOverlay()
}
~F4:: {
    global g_awaitLetter
    g_awaitLetter := "contains"
    UpdateOverlay()
}
~F5:: {
    global g_filterMode, g_awaitLetter, g_filterLetter
    g_filterMode := "nospaces" , g_filterLetter := "" , g_awaitLetter := ""
    UpdateOverlay()
}
~Numpad2:: {
    global g_filterRepeat
    g_filterRepeat := 2
    UpdateOverlay()
}
~Numpad3:: {
    global g_filterRepeat
    g_filterRepeat := 3
    UpdateOverlay()
}

~^v:: RecordPracticePaste()
~+Insert:: RecordPracticePaste()
#HotIf

; Blokování systémových zkratek
#HotIf g_locked && !g_done && g_mode = "practice"
    !F4::     return
    ^Escape:: return
    #d::      return
    #Tab::    return
    LWin::    return
    RWin::    return
    ^w::      return
    ^F4::     return
    !Tab::    return
#HotIf

; Nouzove ukonceni - Ctrl+Delete (heslo 953, max 10 pokusu, timeout 10s)
#SuspendExempt
#HotIf g_started && !g_done
^Delete:: {
    global g_deleteCount, g_deleteLocked, g_overlay, lbl_status
    global g_mode, g_passwordOpen

    ; Uz zamceno — tiše ignoruj
    if g_deleteLocked
        return

    g_deleteCount++

    ; Po 10 zmacknutich trvale zamkni
    if g_deleteCount > 10 {
        g_deleteLocked := true
        if IsObject(g_overlay)
            lbl_status.Value := "ZAMCENO: Nouzove ukonceni trvale zablokovano!"
        return
    }

    zbyvaPokusu := 10 - g_deleteCount
    previousMode := g_mode
    g_passwordOpen := true
    SetPracticeMode("password")
    ; Zastav timery aby nepřepisovaly focus
    SetTimer WatchWindow,  0
    BlockInput "Off"
    Suspend true
    Sleep 80

    result := InputBox("Heslo pro ukonceni (mas 10 sekund).`nZbyvajici pokusy: " . zbyvaPokusu, "Ukonceni", "w280 h150 Password T10")

    if (result.Result = "OK" && result.Value = "953") {
        Suspend false
        LockInput(false)
        try {
            if IsObject(g_overlay)
                g_overlay.Destroy()
        }
        ExitApp
    }

    ; Timeout nebo spatne heslo — obnov vse a restartuj timery
    Suspend false
    g_passwordOpen := false
    SetPracticeMode(previousMode)
    LockInput(previousMode = "practice")
    SetTimer WatchWindow,  1000

    if g_deleteCount >= 10 {
        g_deleteLocked := true
        if IsObject(g_overlay)
            lbl_status.Value := "ZAMCENO: Nouzove ukonceni trvale zablokovano!"
    } else {
        if IsObject(g_overlay)
            lbl_status.Value := "Spatne heslo nebo timeout — zbyvajici pokusy: " . (10 - g_deleteCount)
    }
}

; Klik myší = vyhodnoť a resetuj napsaný text (jen pokud je text připraven)
Home:: {
    ForceResumeNow()
}

#HotIf g_started && !g_done && g_postponedUntil = 0
$Pause:: {
    if CheckDateChange()
        return
    SaveState()
    SaveWeeklyState()
    BlockInput "Off"
    Reload()
}

#HotIf
#SuspendExempt False

#HotIf
#HotIf (IsPracticeInputActive() && g_textReady)
~LButton:: {
    global g_typedText, g_lastResult, g_lastErrors
    ; Krátká pauza aby aplikace zpracovala klik
    Sleep 80
    MouseGetPos , , &clickedWindow
    if clickedWindow != GetMainMountBlueWindow()
        return
    ; Kontroluj jen pokud uzivatel neco napsal
    if StrLen(g_typedText) = 0
        return
    EvaluateExercise()
}
#HotIf

; ═══════════════════════════════════════════════════════════════
;  HANDLEKEY — sleduje co píšeš + blokování
; ═══════════════════════════════════════════════════════════════
HandleKey(letter) {
    global g_awaitLetter, g_filterMode, g_filterLetter
    if g_awaitLetter != "" {
        g_filterMode := g_awaitLetter
        g_filterLetter := letter
        g_awaitLetter := ""
        UpdateOverlay()
        return
    }
    RecordPracticeText(letter)
}

HandleKeyBS() {
    RecordPracticeEdit(0, 8, 0)
}

UpdateTypedPreview() {
    global g_typedText, lbl_typed, g_overlay
    if !IsObject(g_overlay)
        return
    preview := StrLen(g_typedText) > 120 ? "…" . SubStr(g_typedText, StrLen(g_typedText) - 119) : g_typedText
    lbl_typed.Value := preview
}

; ═══════════════════════════════════════════════════════════════
;  FILTRY
; ═══════════════════════════════════════════════════════════════
BuildExpected(sourceText) {
    global g_filterMode, g_filterLetter, g_filterRepeat
    if sourceText = ""
        return ""
    result := sourceText

    if g_filterMode = "reverse" {
        rev := ""
        loop StrLen(result)
            rev := SubStr(result, A_Index, 1) . rev
        result := rev
    } else if g_filterMode = "startswith" && g_filterLetter != "" {
        words := StrSplit(result, " ")
        out   := []
        for w in words
            if StrLen(w) > 0 && SubStr(w, 1, 1) = g_filterLetter
                out.Push(w)
        result := out.Length > 0 ? ArrayJoin(out, " ") : "(zadna slova)"
    } else if g_filterMode = "contains" && g_filterLetter != "" {
        words := StrSplit(result, " ")
        out   := []
        for w in words
            if InStr(w, g_filterLetter)
                out.Push(w)
        result := out.Length > 0 ? ArrayJoin(out, " ") : "(zadna slova)"
    } else if g_filterMode = "nospaces" {
        result := StrReplace(result, " ", "")
        result := StrReplace(result, "`n", "")
    }

    if g_filterRepeat > 1 {
        base := result
        loop (g_filterRepeat - 1)
            result .= " " . base
    }
    return result
}

ArrayJoin(arr, sep) {
    out := ""
    for i, v in arr
        out .= (i > 1 ? sep : "") . v
    return out
}

; ═══════════════════════════════════════════════════════════════
;  KONTROLA TEXTU — po slovech
; ═══════════════════════════════════════════════════════════════
CountWordErrors(typed, expected) {
    typedWords := SplitWords(typed)
    expectedWords := SplitWords(expected)

    previous := []
    loop expectedWords.Length + 1
        previous.Push(A_Index - 1)

    loop typedWords.Length {
        i := A_Index
        current := [i]
        loop expectedWords.Length {
            j := A_Index
            replaceCost := typedWords[i] = expectedWords[j] ? 0 : 1
            current.Push(Min(
                previous[j + 1] + 1,
                current[j] + 1,
                previous[j] + replaceCost
            ))
        }
        previous := current
    }

    return previous[expectedWords.Length + 1]
}

SplitWords(text) {
    words := []
    for word in StrSplit(Trim(text), " ", "`n`r`t")
        if StrLen(Trim(word)) > 0
            words.Push(Trim(word))
    return words
}

; Spočítá správně napsané znaky po slovech.
; Limit chyb na slovo: 1 chyba (≤9 znaků), 2 chyby (10-19 znaků), 4 chyby (20+ znaků).
; Při chybě se odečte počet chyb od délky slova.
CountCorrectChars(typed, expected) {
    typedWords    := SplitWords(typed)
    expectedWords := SplitWords(expected)

    correctChars := 0
    expIdx       := 1

    loop typedWords.Length {
        tw := typedWords[A_Index]

        skipped := 0
        while (expIdx <= expectedWords.Length && skipped <= 2) {
            ew      := expectedWords[expIdx]
            ewLen   := StrLen(ew)
            dist    := LevenshteinWord(tw, ew)

            ; Dynamický limit chyb podle délky slova
            if (ewLen >= 20)
                maxDist := 4
            else if (ewLen >= 10)
                maxDist := 2
            else
                maxDist := 1

            if (dist <= maxDist) {
                ; Přičti znaky slova minus počet chyb
                correctChars += Max(ewLen - dist, 0)
                expIdx++
                break
            }
            ; Zkus jestli typed slovo nesedí na další expected slovo
            if (expIdx + 1 <= expectedWords.Length) {
                ewNext   := expectedWords[expIdx + 1]
                ewNLen   := StrLen(ewNext)
                distNext := LevenshteinWord(tw, ewNext)
                if (ewNLen >= 20)
                    maxDistNext := 4
                else if (ewNLen >= 10)
                    maxDistNext := 2
                else
                    maxDistNext := 1
                if (distNext <= maxDistNext) {
                    expIdx++
                    skipped++
                    continue
                }
            }
            break
        }
        if (expIdx > expectedWords.Length)
            break
    }

    return correctChars
}

; Levenshtein distance pro dvě slova (znakový)
LevenshteinWord(a, b) {
    la := StrLen(a)
    lb := StrLen(b)
    if la = 0
        return lb
    if lb = 0
        return la

    prev := []
    loop lb + 1
        prev.Push(A_Index - 1)

    loop la {
        i   := A_Index
        ca  := SubStr(a, i, 1)
        curr := [i]
        loop lb {
            j  := A_Index
            cb := SubStr(b, j, 1)
            cost := ca = cb ? 0 : 1
            curr.Push(Min(prev[j+1] + 1, curr[j] + 1, prev[j] + cost))
        }
        prev := curr
    }
    return prev[lb + 1]
}

; ═══════════════════════════════════════════════════════════════
;  VYHODNOCENÍ
; ═══════════════════════════════════════════════════════════════
EvaluateExercise() {
    global g_evaluating
    if g_evaluating || CheckDateChange()
        return
    g_evaluating := true
    try {
        EvaluateExerciseInput()
    } finally {
        g_evaluating := false
    }
}

EvaluateExerciseInput() {
    global g_sourceText, g_typedText, g_passedCount, g_lastErrors
    global g_lastResult, g_lastCorrectChars, g_done, MIN_TEXT_LEN
    global g_exerciseNum, lbl_status, g_overlay, g_textReady, g_charsAccumulated
    global g_filterMode, g_filterLetter, g_filterRepeat, g_awaitLetter, g_dailyDone
    global g_weeklyChars, g_weeklyDays, g_weeklyDone, WEEKLY_GOAL

    if g_sourceText = "" {
        if IsObject(g_overlay)
            lbl_status.Value := "⚠  Nejdriv Shift+Win+T!"
        return
    }

    typedText := g_typedText
    if Trim(typedText) = "" {
        if IsObject(g_overlay)
            lbl_status.Value := "Nejdriv napis alespon cast cviceni."
        return
    }

    expected := BuildExpected(g_sourceText)
    ; Spotrebuj odevzdany text pred vyhodnocenim, aby opozdeny klik neudelil body znovu.
    ResetTypedInput()
    g_lastErrors := CountWordErrors(typedText, expected)
    g_lastCorrectChars := CountCorrectChars(typedText, expected)
    LogSubmission(typedText, expected, g_lastCorrectChars, g_lastErrors)
    g_charsAccumulated += g_lastCorrectChars

    ; Týdenní cíl se přičítá při KAŽDÉM přičtení znaků, bez ohledu na denní cíl
    g_weeklyChars += g_lastCorrectChars
    if !g_weeklyDone && g_weeklyChars >= WEEKLY_GOAL
        g_weeklyDone := true
    SaveWeeklyState()

    ; Filtr se neresetuje tady — resetuje se až v ConfirmYes (ANO) nebo při resetu textu

    ; Zjisti jestli právě teď byl splněn denní cíl
    justFinishedDaily := (g_charsAccumulated >= MIN_TEXT_LEN && !g_dailyDone)
    if justFinishedDaily {
        g_lastResult := "pass"
        g_passedCount++
        g_dailyDone  := true
    } else {
        g_lastResult := "counted"
        g_exerciseNum++
    }

    ; Po dennim cili pokracuj bez potvrzovani az do povinneho tydenniho cile.
    if g_dailyDone {
        UpdateOverlay()
        UpdateTask()
        Finish(typedText)
        return
    }

    ; Confirm se zobrazí pokud napsal 300+ znaků NEBO max 5 chyb
    confirmNeeded := (g_lastCorrectChars >= 300 || g_lastErrors <= 5)

    if confirmNeeded {
        SaveState()
        UpdateOverlay()
        UpdateTask()

        if confirmNeeded
            ShowConfirm("Dokončil jsi cvičení?   znaky: " . g_lastCorrectChars . "  ·  chyby: " . g_lastErrors)

        return   ; zbytek vyřeší ConfirmYes/ConfirmNo
    }

    SaveState()
    UpdateOverlay()
    UpdateTask()
}

; ═══════════════════════════════════════════════════════════════
;  ODLOŽENÍ
; ═══════════════════════════════════════════════════════════════
DoPostpone() {
    global g_postponeCount, g_postponedUntil, POSTPONE_MAX, POSTPONE_MIN, g_overlay
    if CheckDateChange() || g_postponedUntil > 0 || g_postponeCount >= POSTPONE_MAX
        return
    g_postponeCount++
    msDelay := POSTPONE_MIN * 60 * 1000
    g_postponedUntil := A_TickCount + msDelay
    QueuePracticeEvent("postpone", "", String(g_postponeCount))
    FlushPracticeLogs()
    SetPracticeMode("postponed")
    ; Zastav hlidani okna po dobu odlozeni.
    SetTimer WatchWindow,  0
    ; Odblokuj vstup
    BlockInput "Off"
    Suspend true
    ; Skryj overlay
    if IsObject(g_overlay)
        g_overlay.Hide()
    ; Za 30 min znovu zobraz
    SetTimer ShowOverlayAgain, -msDelay
    SaveState()
}

ShowOverlayAgain() {
    global g_overlay, g_done, g_postponedUntil
    if g_done || CheckDateChange()
        return
    g_postponedUntil := 0
    ; Obnov timery
    SetTimer WatchWindow,  1000
    ; Znovu zamkni
    Suspend false
    if IsObject(g_overlay) {
        g_overlay.Show("NoActivate")
        UpdateOverlay()
    }
    TryStartPractice()
    SaveState()
}

ForceResumeNow() {
    global g_postponedUntil, g_done, g_overlay
    if g_done || CheckDateChange()
        return
    if (g_postponedUntil > 0 && A_TickCount < g_postponedUntil) {
        SetTimer ShowOverlayAgain, 0
        ShowOverlayAgain()
        return
    }
    if IsObject(g_overlay) {
        g_overlay.Show("NoActivate")
        UpdateOverlay()
    }
    ActivateMountBlue(4)
}


; ═══════════════════════════════════════════════════════════════
;  OVERLAY
; ═══════════════════════════════════════════════════════════════
CreateOverlay() {
    global g_overlay, OVERLAY_W

    screenW  := SysGet(78)
    screenH  := SysGet(79)

    g_overlay           := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "MBEnforcer")
    g_overlay.BackColor := "0A0B1A"
    g_overlay.MarginX   := 0
    g_overlay.MarginY   := 0
    BuildOverlayUI(OVERLAY_W, screenH)
    UpdateOverlay()
    UpdateTask()
    OnMessage(0x201, UnlockMouseDown)
    g_overlay.Show("x" . (screenW - OVERLAY_W) . " y0 w" . OVERLAY_W . " h" . screenH . " NoActivate")
}

BuildOverlayUI(w, h) {
    global g_overlay, MIN_TEXT_LEN
    global lbl_status, lbl_source_len, lbl_source_count, lbl_filter, lbl_expected
    global lbl_confirm, btn_confirm_yes, btn_confirm_no
    global lbl_weekly
    global lbl_result, lbl_errors, lbl_typed, lbl_typed_label
    global lbl_postpone, btn_postpone
    global lbl_task

    ; ── Paleta ──────────────────────────────────────────
    cAccent  := "E8425A"
    cBlue    := "5BC8F5"
    cGreen   := "3DFFA0"
    cYellow  := "FFD166"
    cText    := "EEF0F7"
    cSub     := "6B6F96"
    cBorder  := "232540"
    cProg    := "1E2038"

    pad  := 20          ; vnější odsazení
    lw   := w - pad*2   ; šířka obsahu
    ipad := pad + 8     ; odsazení hodnot pod štítkem
    ilw  := lw - 8

    ; Konstanty pro spacing
    gapLabel  := 6      ; štítek → hodnota
    gapAfter  := 14     ; hodnota → separator
    gapSep    := 14     ; separator → štítek další sekce
    gapKeys   := 16     ; mezi řádky kláves

    y := 0

    ; ════════════════════════════════════════════════════
    ; HLAVIČKA
    ; ════════════════════════════════════════════════════
    g_overlay.Add("Text", "x0 y0 w" . w . " h3 Background" . cAccent, "")
    y += 16

    g_overlay.SetFont("s15 w700 c" . cAccent, "Segoe UI")
    g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "Mount Blue")
    y += 26
    g_overlay.SetFont("s8 w400 c" . cSub, "Segoe UI")
    g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "Hlídač psacích cvičení")
    y += 22

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; POSTUP
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s7 w600 c" . cSub, "Segoe UI")
    g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "POSTUP")
    y += gapLabel + 8

    g_overlay.SetFont("s10 w700 c" . cYellow, "Segoe UI")
    lbl_task := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw, "Cvičení 1  ·  0 / " . MIN_TEXT_LEN . " znaků")
    y += 22

    g_overlay.Add("Progress", "x" . ipad . " y" . y . " w" . ilw . " h6 Background" . cProg . " c" . cGreen . " Range0-" . MIN_TEXT_LEN . " -Smooth vPROG_BAR", 0)
    y += gapAfter + 8

    ; ─── TÝDENNÍ CÍL (stejný styl, modrý) ───────────────
    g_overlay.SetFont("s10 w700 c4499FF", "Segoe UI")
    global lbl_weekly
    lbl_weekly := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw, "Týden  ·  0 / " . WEEKLY_GOAL . " znaků")
    y += 22
    g_overlay.Add("Progress", "x" . ipad . " y" . y . " w" . ilw . " h6 Background" . cProg . " c4499FF Range0-" . WEEKLY_GOAL . " -Smooth vPROG_WEEK", 0)
    y += gapAfter + 2

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; ZADANÝ TEXT
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s7 w600 c" . cSub, "Segoe UI")
    g_overlay.Add("Text", "x" . pad . " y" . y . " w" . (lw-82), "ZADANÝ TEXT")
    g_overlay.SetFont("s7 w400 c" . cBorder, "Segoe UI")
    g_overlay.Add("Text", "x" . (pad+lw-80) . " y" . y . " w80", "Shift+Win+T")
    y += gapLabel + 8

    g_overlay.SetFont("s11 w700 c00D9A0", "Segoe UI")
    lbl_source_count := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw . " h20", "")
    y += 22

    g_overlay.SetFont("s8 w400 c" . cSub, "Segoe UI")
    lbl_source_len := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw . " h34", "zatím nebyl zkopírován")
    y += 38 + gapAfter - 6

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; FILTR
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s7 w600 c" . cSub, "Segoe UI")
    g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "FILTR")
    y += gapLabel + 8

    g_overlay.SetFont("s9 w600 c" . cYellow, "Segoe UI")
    lbl_filter := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw, "— žádný —")
    y += 20

    g_overlay.SetFont("s7 w400 c" . cSub, "Segoe UI")
    g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw, "výstup filtru:")
    y += gapLabel + 6

    g_overlay.SetFont("s8 w400 c" . cBlue, "Consolas")
    lbl_expected := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw . " h30", "—")
    y += 34 + gapAfter - 6

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; CO PÍŠEŠ
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s7 w600 c" . cSub, "Segoe UI")
    lbl_typed_label := g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "CO PÍŠEŠ")
    y += gapLabel + 8

    g_overlay.SetFont("s8 w400 c" . cGreen, "Consolas")
    lbl_typed := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw . " h30", "")
    y += 34 + gapAfter - 6

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; VÝSLEDEK
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s7 w600 c" . cSub, "Segoe UI")
    g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "POSLEDNÍ VÝSLEDEK")
    y += gapLabel + 8

    g_overlay.SetFont("s11 w700 c" . cSub, "Segoe UI")
    lbl_result := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw, "čeká na první cvičení")
    y += 22

    g_overlay.SetFont("s8 w400 c" . cSub, "Segoe UI")
    lbl_errors := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw, "")
    y += gapAfter + 4

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; KLÁVESY
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s7 w600 c" . cSub, "Segoe UI")
    g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "KLÁVESOVÉ ZKRATKY")
    y += gapLabel + 8

    keys := [
        ["F1",       "reset filtru"],
        ["F2",       "text pozadu"],
        ["F3 + X",   "slova začínající na X"],
        ["F4 + X",   "slova obsahující X"],
        ["F5",       "bez mezer"],
        ["Num 2/3",  "opakuj 2× / 3×"],
    ]
    col2x := ipad + 68
    for item in keys {
        g_overlay.SetFont("s8 w700 c" . cYellow, "Consolas")
        g_overlay.Add("Text", "x" . ipad . " y" . y . " w66", item[1])
        g_overlay.SetFont("s8 w400 c" . cSub, "Segoe UI")
        g_overlay.Add("Text", "x" . col2x . " y" . y . " w" . (ilw - 68), item[2])
        y += gapKeys
    }
    y += 4

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; ODLOŽENÍ
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s7 w400 c" . cSub, "Segoe UI")
    lbl_postpone := g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw, "odložení:  0 / 3")
    y += gapLabel + 10

    g_overlay.SetFont("s9 w600 c" . cText, "Segoe UI")
    btn_postpone := g_overlay.Add("Button", "x" . pad . " y" . y . " w" . lw . " h28", "⏸  Odložit  ( 30 min )")
    btn_postpone.OnEvent("Click", (*) => DoPostpone())
    y += 38

    Sep(pad, y, w) , y += gapSep - 4

    ; ════════════════════════════════════════════════════
    ; STATUS
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s8 w400 c" . cSub, "Segoe UI")
    lbl_status := g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw . " h36", "Shift+Win+T  →  označ text")
    y += 44

    Sep(pad, y, w) , y += gapSep

    ; ════════════════════════════════════════════════════
    ; POTVRZENÍ CVIČENÍ (skryté dokud není potřeba)
    ; ════════════════════════════════════════════════════
    g_overlay.SetFont("s11 w700 c" . cYellow, "Segoe UI")
    lbl_confirm := g_overlay.Add("Text", "x" . pad . " y" . y . " w" . lw . " h0", "")
    y += 2
    ; Normální tlačítka — barva přes Gui okna se nastaví v ShowConfirm
    g_overlay.SetFont("s10 w700 cEEEEEE", "Segoe UI")
    btn_confirm_yes := g_overlay.Add("Button", "x" . pad . " y" . y . " w" . (lw//2 - 6) . " h0", "✔  ANO, dokoncil")
    btn_confirm_no  := g_overlay.Add("Button", "x" . (pad + lw//2 + 6) . " y" . y . " w" . (lw//2 - 6) . " h0", "✘  NE, zkus znovu")
    btn_confirm_yes.OnEvent("Click", (*) => ConfirmYes())
    btn_confirm_no.OnEvent("Click",  (*) => ConfirmNo())
}


; ─── Potvrzovací UI v overlay ──────────────────────────────────
; Globální Gui okna pro barevná tlačítka (inicializovány nahoře)

ShowConfirm(msg) {
    SetPracticeMode("confirm")
    LockInput(false)
    global lbl_confirm, btn_confirm_yes, btn_confirm_no
    global lbl_weekly
    global g_overlay, g_btnYesGui, g_btnNoGui, g_btnYesBorder, g_btnNoBorder, OVERLAY_W

    lbl_confirm.Value := msg
    lbl_confirm.Move(,,, 44)
    btn_confirm_yes.Move(,,, 0)   ; skryj AHK button
    btn_confirm_no.Move(,,, 0)

    ; Zjisti pozici overlay
    screenW := SysGet(78)
    overlayX := screenW - OVERLAY_W
    pad := 20
    lw  := OVERLAY_W - pad*2

    ; Absolutní pozice overlay okna na obrazovce
    g_overlay.GetPos(&ovX, &ovY, &ovW, &ovH)

    ; Zjisti Y pozici lbl_confirm (relativní k oknu) a přepočítej na absolutní
    lbl_confirm.GetPos(&cx, &cy, &cw, &ch)
    btnH   := 58
    btnW   := lw
    radius := 10
    gap    := 10
    yYes   := ovY + cy + ch + 10

    ; Pokud už existuje modré tlačítko ODEMKNOUT, posuň confirm tlačítka pod něj
    global g_btnUnlockGui
    if IsObject(g_btnUnlockGui) {
        try {
            g_btnUnlockGui.GetPos(&ux, &uy, &uw, &uh)
            if uh > 0
                yYes := uy + uh + 10
        }
    }

    yNo := yYes + btnH + gap

    ; ── Pomocná funkce: zakulatí okno přes SetWindowRgn ──
    RoundWindow(hwnd, w, h, r) {
        hRgn := DllCall("CreateRoundRectRgn", "int",0,"int",0,"int",w+1,"int",h+1,"int",r*2,"int",r*2,"ptr")
        DllCall("SetWindowRgn", "ptr", hwnd, "ptr", hRgn, "int", true)
    }

    brd := 3   ; tloušťka okraje v px
    ownerOpt := " +Owner" . g_overlay.Hwnd

    ; ── Zelený rámeček (pod tlačítkem ANO) ──
    if IsObject(g_btnYesBorder)
        g_btnYesBorder.Destroy()
    g_btnYesBorder := Gui("+AlwaysOnTop -Caption" . ownerOpt, "")
    g_btnYesBorder.BackColor := "2ecc71"
    g_btnYesBorder.Show("x" . (overlayX + pad - brd) . " y" . (yYes - brd) . " w" . (btnW + brd*2) . " h" . (btnH + brd*2) . " NoActivate")
    RoundWindow(g_btnYesBorder.Hwnd, btnW + brd*2, btnH + brd*2, radius + brd)
    g_btnYesBorder.OnEvent("Close", (*) => 0)

    ; ── Zelené tlačítko ANO ──
    if IsObject(g_btnYesGui)
        g_btnYesGui.Destroy()
    g_btnYesGui := Gui("+AlwaysOnTop -Caption" . ownerOpt, "")
    g_btnYesGui.BackColor := "1a7a3a"
    g_btnYesGui.MarginX := 0
    g_btnYesGui.MarginY := 0
    g_btnYesGui.SetFont("s13 w700 cFFFFFF", "Segoe UI")
    yesLbl := g_btnYesGui.Add("Text", "x0 y0 w" . btnW . " h" . btnH . " Center +0x200", "✔   ANO — udělal jsem to")
    g_btnYesGui.Show("x" . (overlayX + pad) . " y" . yYes . " w" . btnW . " h" . btnH . " NoActivate")
    yesLbl.OnEvent("Click", (*) => ConfirmYes())
    RoundWindow(g_btnYesGui.Hwnd, btnW, btnH, radius)
    g_btnYesGui.OnEvent("Close", (*) => 0)

    ; ── Červený rámeček (pod tlačítkem NE) ──
    if IsObject(g_btnNoBorder)
        g_btnNoBorder.Destroy()
    g_btnNoBorder := Gui("+AlwaysOnTop -Caption" . ownerOpt, "")
    g_btnNoBorder.BackColor := "e74c3c"
    g_btnNoBorder.Show("x" . (overlayX + pad - brd) . " y" . (yNo - brd) . " w" . (btnW + brd*2) . " h" . (btnH + brd*2) . " NoActivate")
    RoundWindow(g_btnNoBorder.Hwnd, btnW + brd*2, btnH + brd*2, radius + brd)
    g_btnNoBorder.OnEvent("Close", (*) => 0)

    ; ── Červené tlačítko NE ──
    if IsObject(g_btnNoGui)
        g_btnNoGui.Destroy()
    g_btnNoGui := Gui("+AlwaysOnTop -Caption" . ownerOpt, "")
    g_btnNoGui.BackColor := "7a1a1a"
    g_btnNoGui.MarginX := 0
    g_btnNoGui.MarginY := 0
    g_btnNoGui.SetFont("s13 w700 cFFFFFF", "Segoe UI")
    noLbl := g_btnNoGui.Add("Text", "x0 y0 w" . btnW . " h" . btnH . " Center +0x200", "✘   NE — ještě ne")
    g_btnNoGui.Show("x" . (overlayX + pad) . " y" . yNo . " w" . btnW . " h" . btnH . " NoActivate")
    noLbl.OnEvent("Click", (*) => ConfirmNo())
    RoundWindow(g_btnNoGui.Hwnd, btnW, btnH, radius)
    g_btnNoGui.OnEvent("Close", (*) => 0)
}


; ─── Tlačítko ODEMKNOUT — stejný design jako confirm, ale modré a větší ─
ShowUnlockButton() {
    SetPracticeMode("daily_done")
    LockInput(false)
    HideConfirm()
    global g_overlay, g_btnUnlockGui, g_btnUnlockBorder, OVERLAY_W
    global g_weeklyChars, g_weeklyDays, g_weeklyDone, WEEKLY_GOAL, lbl_status

    ; ── Pomocná funkce: zakulatí okno ──
    RoundWindow(hwnd, w, h, r) {
        hRgn := DllCall("CreateRoundRectRgn", "int",0,"int",0,"int",w+1,"int",h+1,"int",r*2,"int",r*2,"ptr")
        DllCall("SetWindowRgn", "ptr", hwnd, "ptr", hRgn, "int", true)
    }

    screenW  := SysGet(78)
    overlayX := screenW - OVERLAY_W

    ; Zjisti absolutní pozici overlay okna na obrazovce
    g_overlay.GetPos(&ovX, &ovY, &ovW, &ovH)

    pad := 20
    lw  := OVERLAY_W - pad*2

    btnW   := lw
    btnH   := 92
    radius := 10
    brd    := 3
    btnX   := overlayX + pad

    ; Pokud jsou viditelná potvrzovací tlačítka, umísti modré tlačítko pod ně
    ; (g_btnNoGui má vlastní absolutní pozici na obrazovce).
    ; Jinak pod lbl_status (jehož pozice je relativní k overlay oknu — přepočítej na absolutní).
    global g_btnNoGui
    btnY := 0
    if IsObject(g_btnNoGui) {
        try {
            g_btnNoGui.GetPos(&nx, &ny, &nw, &nh)
            if nh > 0
                btnY := ny + nh + 10
        }
    }
    if (btnY = 0) {
        lbl_status.GetPos(&cx, &cy, &cw, &ch)
        btnY := ovY + cy + ch + 10
    }

    ownerOpt := " +Owner" . g_overlay.Hwnd

    ; ── Modrý rámeček ──
    if IsObject(g_btnUnlockBorder)
        g_btnUnlockBorder.Destroy()
    g_btnUnlockBorder := Gui("+AlwaysOnTop -Caption" . ownerOpt, "")
    g_btnUnlockBorder.BackColor := "3498db"
    g_btnUnlockBorder.Show("x" . (btnX - brd) . " y" . (btnY - brd) . " w" . (btnW + brd*2) . " h" . (btnH + brd*2) . " NoActivate")
    RoundWindow(g_btnUnlockBorder.Hwnd, btnW + brd*2, btnH + brd*2, radius + brd)
    g_btnUnlockBorder.OnEvent("Close", (*) => 0)

    ; ── Modré tlačítko ──
    if IsObject(g_btnUnlockGui)
        g_btnUnlockGui.Destroy()
    g_btnUnlockGui := Gui("+AlwaysOnTop -Caption" . ownerOpt, "")
    g_btnUnlockGui.BackColor := "1a4d7a"
    g_btnUnlockGui.MarginX := 0
    g_btnUnlockGui.MarginY := 0

    g_btnUnlockGui.SetFont("s13 w700 cFFFFFF", "Segoe UI")
    title := g_btnUnlockGui.Add("Text", "x0 y14 w" . btnW . " h26 Center +0x200", "🔓  ODEMKNOUT PC")

    g_btnUnlockGui.SetFont("s9 w400 cBBDDFF", "Segoe UI")
    weekDay := GetWeeklyDay()
    weekTxt := g_weeklyDone ? "🏆 Týdenní cíl splněn!  ·  den " . weekDay . "/7" : "Týden: " . g_weeklyChars . " / " . WEEKLY_GOAL . " znaků  ·  den " . weekDay . "/7"
    g_btnUnlockGui.Add("Text", "x0 y44 w" . btnW . " h20 Center +0x200", weekTxt)

    g_btnUnlockGui.SetFont("s8 w400 c88AACC", "Segoe UI")
    g_btnUnlockGui.Add("Text", "x0 y68 w" . btnW . " h18 Center +0x200", "Nebo pokračuj v psaní pro týdenní cíl")

    g_btnUnlockGui.Show("x" . btnX . " y" . btnY . " w" . btnW . " h" . btnH . " NoActivate")
    title.OnEvent("Click", (*) => DoUnlock())
    RoundWindow(g_btnUnlockGui.Hwnd, btnW, btnH, radius)
    g_btnUnlockGui.OnEvent("Close", (*) => 0)
}

DoUnlock() {
    global g_done, g_mode, g_overlay, g_btnUnlockGui, g_btnUnlockBorder
    if g_mode = "closing" || CheckDateChange() || IsWeeklyRequired()
        return
    SetPracticeMode("closing")
    g_done := true
    SetTimer WatchWindow, 0
    LockInput(false)
    if IsObject(g_btnUnlockGui) {
        g_btnUnlockGui.Destroy()
        g_btnUnlockGui := 0
    }
    if IsObject(g_btnUnlockBorder) {
        g_btnUnlockBorder.Destroy()
        g_btnUnlockBorder := 0
    }
    if IsObject(g_overlay)
        g_overlay.Destroy()
    ExitApp
}

HideConfirm() {
    global lbl_confirm, btn_confirm_yes, btn_confirm_no, g_btnYesGui, g_btnNoGui, g_btnYesBorder, g_btnNoBorder
    lbl_confirm.Value := ""
    lbl_confirm.Move(,,, 0)
    if IsObject(g_btnYesBorder) {
        g_btnYesBorder.Destroy()
        g_btnYesBorder := 0
    }
    if IsObject(g_btnNoBorder) {
        g_btnNoBorder.Destroy()
        g_btnNoBorder := 0
    }
    if IsObject(g_btnYesGui) {
        g_btnYesGui.Destroy()
        g_btnYesGui := 0
    }
    if IsObject(g_btnNoGui) {
        g_btnNoGui.Destroy()
        g_btnNoGui := 0
    }
}

ConfirmYes() {
    global g_sourceText, g_textReady, g_filterMode, g_filterLetter, g_filterRepeat, g_awaitLetter, g_dailyDone
    QueuePracticeEvent("confirm", "", "yes")
    HideConfirm()
    ResetTypedInput()
    g_sourceText := ""
    g_textReady := false
    g_filterMode := ""
    g_filterLetter := ""
    g_filterRepeat := 1
    g_awaitLetter := ""
    SetPracticeMode(g_dailyDone ? "daily_done" : "practice")
    SaveState()
    UpdateOverlay()
    UpdateTask()
    if g_dailyDone
        ShowUnlockButton()
    else {
        ActivateMountBlue(2)
        LockInput(true)
    }
}

ConfirmNo() {
    global g_dailyDone
    QueuePracticeEvent("confirm", "", "no")
    HideConfirm()
    ResetTypedInput()
    SetPracticeMode(g_dailyDone ? "daily_done" : "practice")
    SaveState()
    UpdateOverlay()
    UpdateTask()
    if g_dailyDone
        ShowUnlockButton()
    else {
        ActivateMountBlue(2)
        LockInput(true)
    }
}

Sep(x, y, w) {
    global g_overlay
    g_overlay.Add("Text", "x" . x . " y" . y . " w" . (w - x*2) . " h1 Background232540", "")
}

; ── Aktualizuje "co musíš udělat" ──
UpdateTask() {
    global lbl_task, g_exerciseNum, g_sourceText, MIN_TEXT_LEN, g_overlay, g_charsAccumulated
    global g_weeklyChars, g_weeklyDays, g_weeklyDone, WEEKLY_GOAL, lbl_weekly
    if !IsObject(g_overlay)
        return
    remaining := Max(MIN_TEXT_LEN - g_charsAccumulated, 0)
    pct := Min(g_charsAccumulated, MIN_TEXT_LEN)
    lbl_task.Value := "Cvičení " . g_exerciseNum . "   ·   " . g_charsAccumulated . " / " . MIN_TEXT_LEN . " znaků   ·   chybí " . remaining
    lbl_task.SetFont("cFFD166")
    try g_overlay["PROG_BAR"].Value := pct

    ; Týdenní progress
    weekDay := GetWeeklyDay()
    if IsObject(lbl_weekly) {
        if g_weeklyDone {
            lbl_weekly.Value := "Týden  ·  🏆 Splněn!  den " . weekDay . "/7"
            lbl_weekly.SetFont("c00EE88")
        } else {
            lbl_weekly.Value := "Týden  ·  " . g_weeklyChars . " / " . WEEKLY_GOAL . " znaků  ·  den " . weekDay . "/7"
            lbl_weekly.SetFont("c4499FF")
        }
    }
    try g_overlay["PROG_WEEK"].Value := Min(g_weeklyChars, WEEKLY_GOAL)
}

UpdateOverlay(statusOverride := "") {
    global g_sourceText, g_filterMode, g_filterLetter, g_filterRepeat, g_awaitLetter
    global g_lastErrors, g_lastCorrectChars, g_lastResult, g_postponeCount, g_charsAccumulated
    global lbl_status, lbl_source_len, lbl_source_count, lbl_filter, lbl_expected
    global lbl_confirm, btn_confirm_yes, btn_confirm_no
    global lbl_weekly
    global lbl_result, lbl_errors, btn_postpone
    global MIN_TEXT_LEN, POSTPONE_MAX, POSTPONE_MIN, g_done

    if !IsObject(g_overlay)
        return
    LogFilterState()

    ; ── Zadaný text ──
    if g_sourceText = "" {
        lbl_source_count.Value := ""
        lbl_source_len.Value := "zatím nebyl zkopírován"
        lbl_source_len.SetFont("c484C6E")
    } else {
        slen := StrLen(g_sourceText)
        effectiveLen := StrLen(BuildExpected(g_sourceText))
        lenText := effectiveLen = slen ? slen . " znaků" : slen . " → " . effectiveLen . " znaků"
        lbl_source_count.Value := lenText
        lbl_source_len.Value := SubStr(g_sourceText, 1, 44) . (slen > 44 ? "…" : "")
        lbl_source_len.SetFont("c3DFFA0")
    }

    ; ── Filtr ──
    if g_awaitLetter != "" {
        lbl_filter.Value := (g_awaitLetter = "startswith" ? "F3 — stiskni písmeno…" : "F4 — stiskni písmeno…")
        lbl_filter.SetFont("cFFD166")
    } else if g_filterMode = "" {
        lbl_filter.Value := "— žádný —" . (g_filterRepeat > 1 ? "   ×" . g_filterRepeat : "")
        lbl_filter.SetFont("c484C6E")
    } else if g_filterMode = "reverse" {
        lbl_filter.Value := "↩  pozadu" . (g_filterRepeat > 1 ? "   ×" . g_filterRepeat : "")
        lbl_filter.SetFont("cE8425A")
    } else if g_filterMode = "startswith" {
        lbl_filter.Value := "▶  začíná na  [ " . g_filterLetter . " ]" . (g_filterRepeat > 1 ? "   ×" . g_filterRepeat : "")
        lbl_filter.SetFont("c5BC8F5")
    } else if g_filterMode = "contains" {
        lbl_filter.Value := "◈  obsahuje  [ " . g_filterLetter . " ]" . (g_filterRepeat > 1 ? "   ×" . g_filterRepeat : "")
        lbl_filter.SetFont("c5BC8F5")
    } else if g_filterMode = "nospaces" {
        lbl_filter.Value := "⬜  bez mezer" . (g_filterRepeat > 1 ? "   ×" . g_filterRepeat : "")
        lbl_filter.SetFont("cFF6B35")
    }

    ; ── Očekávaný výstup ──
    if g_sourceText != "" {
        exp     := BuildExpected(g_sourceText)
        preview := StrLen(exp) > 80 ? SubStr(exp, 1, 80) . "…" : exp
        lbl_expected.Value := preview
        lbl_expected.SetFont("c5BC8F5")
    } else {
        lbl_expected.Value := "—"
        lbl_expected.SetFont("c2D2F50")
    }

    ; ── Výsledek ──
    if g_lastResult = "pass" {
        lbl_result.Value := "Hotovo!"
        lbl_result.SetFont("c3DFFA0")
        lbl_errors.Value := "+" . g_lastCorrectChars . " znaků    chybná slova: " . g_lastErrors
        lbl_errors.SetFont("c3DFFA0")
    } else if g_lastResult = "counted" {
        lbl_result.Value := "+" . g_lastCorrectChars . " znaků započítáno"
        lbl_result.SetFont("c5BC8F5")
        lbl_errors.Value := "chyby: " . g_lastErrors . "    celkem: " . g_charsAccumulated . " / " . MIN_TEXT_LEN
        lbl_errors.SetFont("c7A7FA8")
    } else {
        lbl_result.Value := "čeká na první cvičení"
        lbl_result.SetFont("c484C6E")
        lbl_errors.Value := ""
    }

    ; ── Odložit tlačítko ──
    if g_postponeCount >= POSTPONE_MAX {
        btn_postpone.Enabled := false
        btn_postpone.Text    := "odložení vyčerpána"
        lbl_postpone.Value := "odložení:  " . POSTPONE_MAX . " / " . POSTPONE_MAX . "  (vyčerpáno)"
        lbl_postpone.SetFont("c484C6E")
    } else {
        btn_postpone.Enabled := true
        btn_postpone.Text := "⏸  Odložit  ( " . POSTPONE_MIN . " min )"
        lbl_postpone.Value := "odložení:  " . g_postponeCount . " / " . POSTPONE_MAX
        lbl_postpone.SetFont("c7A7FA8")
    }

    ; ── Status ──
    if statusOverride != "" {
        lbl_status.Value := statusOverride
        lbl_status.SetFont("cFF6B35 w600")
        return
    }
    if g_done {
        lbl_status.Value := "dokončeno — odemykám"
        lbl_status.SetFont("c3DFFA0 w700")
    } else if g_sourceText = "" {
        lbl_status.Value := "Shift+Win+T  →  označ zadaný text"
        lbl_status.SetFont("c7A7FA8 w400")
    } else {
        lbl_status.Value := "piš a po dokončení  Ctrl+Enter  nebo klik"
        lbl_status.SetFont("c5BC8F5 w400")
    }
}

; ═══════════════════════════════════════════════════════════════
;  POMOCNÉ FUNKCE
; ═══════════════════════════════════════════════════════════════
LockInput(state) {
    global g_locked, START_HOUR
    ; Text a tlacitka zustavaji ovladatelne i pri spusteni jako spravce.
    BlockInput "Off"
    g_locked := state && Integer(FormatTime(, "H")) >= START_HOUR
}

SetDayFiles(now := "") {
    global SESSION_DAY, DONE_DIR, DONE_FILE, STATE_FILE
    if now = ""
        now := A_Now
    SESSION_DAY := FormatTime(now, "yyyy-MM-dd")
    DONE_FILE := DONE_DIR . "\done_" . SESSION_DAY . ".txt"
    STATE_FILE := DONE_DIR . "\state_" . SESSION_DAY . ".txt"
}

IsNewDay(now := "") {
    global SESSION_DAY
    if now = ""
        now := A_Now
    return FormatTime(now, "yyyy-MM-dd") != SESSION_DAY
}

CheckDateChange(now := "") {
    if !IsNewDay(now)
        return false

    ; Uloz jeste do puvodniho dne; Reload nacte novy den a obnovi cele UI.
    SaveState()
    SaveWeeklyState()
    BlockInput "Off"
    Reload()
    return true
}

WaitUntilHour() {
    global START_HOUR
    ; Čekej dokud není START_HOUR:00 — každých 30s zkontroluj
    loop {
        nowHour := Integer(FormatTime(, "H"))
        if nowHour >= START_HOUR
            break
        nowMin := Integer(FormatTime(, "m"))
        nowSec := Integer(FormatTime(, "s"))
        msLeft := (((START_HOUR - nowHour) * 60 - nowMin) * 60 - nowSec) * 1000
        Sleep Max(1000, Min(msLeft, 30000))
    }
}


; ─── Najde hlavní okno MountBlue (největší ze všech oken procesu) ─
GetMainMountBlueWindow() {
    bestHwnd := 0
    bestArea := 0
    for hwnd in WinGetList("ahk_exe MountBlue.exe") {
        try {
            WinGetPos &wx, &wy, &ww, &wh, "ahk_id " hwnd
            area := ww * wh
            if area > bestArea {
                bestArea := area
                bestHwnd := hwnd
            }
        }
    }
    return bestHwnd
}

; ─── Aktivuje hlavní okno MountBlue, NIKDY nemaximalizuje popupy ─
ActivateMountBlue(maxTries := 5) {
    global APP_PATH
    if !ProcessExist("MountBlue.exe") {
        try Run APP_PATH
        catch
            return false
    }
    loop maxTries {
        hwnd := GetMainMountBlueWindow()
        if !hwnd {
            Sleep 400
            continue
        }
        try {
            if WinGetMinMax("ahk_id " . hwnd) = -1
                WinRestore "ahk_id " . hwnd
            WinActivate "ahk_id " . hwnd
            if WinWaitActive("ahk_id " . hwnd,, 0.5) {
                if WinGetMinMax("ahk_id " . hwnd) != 1
                    WinMaximize "ahk_id " . hwnd
                return true
            }
        }
        Sleep 200
    }
    return false
}

; Sedm treninkovych dnu; nedokoncene dny zachovaji znaky i poradi dne.
InitWeekWindow(now := "") {
    global g_weekStartFile, g_weekFile, DONE_DIR
    global g_weeklyChars, g_weeklyDays, g_weeklyDone, g_weeklyLastDay

    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR

    if now = ""
        now := A_Now
    todayStr := FormatTime(now, "yyyyMMdd")

    ; Pokud soubor s datem startu neexistuje → toto je úplně první spuštění
    if !FileExist(g_weekStartFile) {
        FileAppend todayStr, g_weekStartFile
    }

    ; Načti datum startu okna
    try {
        startStr := ReadWeekStart()
        ; Stare verze prepisovaly posledni den pri kazdem ulozeni znaku.
        ; Skutecne dokoncene dny obnov z existujicich dennich zaznamu.
        g_weeklyDays := 0
        g_weeklyLastDay := ""
        loop Files DONE_DIR . "\done_*.txt" {
            if !RegExMatch(A_LoopFileName, "^done_(\d{4})-(\d{2})-(\d{2})\.txt$", &dateParts)
                continue
            dayStr := dateParts[1] . dateParts[2] . dateParts[3]
            if dayStr < startStr || dayStr > todayStr
                continue
            g_weeklyDays := Min(7, g_weeklyDays + 1)
            if g_weeklyLastDay = "" || dayStr > g_weeklyLastDay
                g_weeklyLastDay := dayStr
        }

        ; Zacni dalsi obdobi az po sedmi splnenych dnech a splneni celeho cile.
        ; Restart ve stejnem dni nesmi uzavrene obdobi znovu otevrit.
        if g_weeklyDays >= 7 && g_weeklyDone && g_weeklyLastDay < todayStr {
            WriteStateFile(g_weekStartFile, todayStr)
            g_weeklyChars := 0
            g_weeklyDays := 0
            g_weeklyDone := false
            g_weeklyLastDay := ""
        }
        SaveWeeklyState()
    }
}

ReadWeekStart() {
    global g_weekStartFile
    return Trim(FileRead(g_weekStartFile, "UTF-8"), " `t`r`n" . Chr(0xFEFF))
}

IsWeeklyRequired(now := "") {
    global g_weeklyDone
    return !g_weeklyDone && IsWeeklyDeadline(now)
}

IsWeeklyDeadline(now := "") {
    return GetWeeklyDay(now) = 7
}

GetWeeklyDay(now := "") {
    global g_weeklyDays, g_weeklyLastDay
    if now = ""
        now := A_Now
    todayStr := FormatTime(now, "yyyyMMdd")
    return Min(7, Max(1, g_weeklyDays + (g_weeklyLastDay = todayStr ? 0 : 1)))
}

LoadWeeklyState() {
    global g_weekFile, g_weeklyChars, g_weeklyDays, g_weeklyDone, WEEKLY_GOAL
    if !FileExist(g_weekFile)
        return
    try {
        lines := StrSplit(FileRead(g_weekFile), "`n")
        if lines.Length >= 3 {
            g_weeklyChars := Integer(lines[1])
            g_weeklyDays  := Integer(lines[2])
            g_weeklyDone  := g_weeklyChars >= WEEKLY_GOAL
        }
        if lines.Length >= 4 {
            global g_weeklyLastDay
            g_weeklyLastDay := Trim(lines[4], " `t`r`n")
        }
    }
}

SaveWeeklyState() {
    global g_weekFile, g_weeklyChars, g_weeklyDays, g_weeklyDone, g_weeklyLastDay, DONE_DIR
    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR
    WriteStateFile(g_weekFile, g_weeklyChars . "`n" . g_weeklyDays . "`n" . (g_weeklyDone ? 1 : 0) . "`n" . g_weeklyLastDay)
}

SaveState() {
    global STATE_FILE, DONE_DIR, g_postponeCount, g_charsAccumulated, g_exerciseNum
    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR
    WriteStateFile(STATE_FILE, g_postponeCount . "`n" . g_charsAccumulated . "`n" . g_exerciseNum)
}

WriteStateFile(path, contents) {
    previousCritical := A_IsCritical
    Critical "On"
    file := 0
    try {
        file := FileOpen(path . ".tmp", "w", "UTF-8")
        file.Write(contents)
        file.Close()
        file := 0
        FileMove path . ".tmp", path, true
    } finally {
        if IsObject(file)
            file.Close()
        Critical previousCritical
    }
}

LoadState() {
    global STATE_FILE, g_postponeCount, g_charsAccumulated, g_exerciseNum, POSTPONE_MAX
    g_postponeCount := 0
    g_charsAccumulated := 0
    g_exerciseNum := 1
    if !FileExist(STATE_FILE)
        return
    try {
        lines := StrSplit(FileRead(STATE_FILE), "`n")
        if lines.Length >= 3 {
            g_postponeCount    := Min(POSTPONE_MAX, Max(Integer(lines[1]), 0))
            g_charsAccumulated := Max(Integer(lines[2]), 0)
            g_exerciseNum      := Max(Integer(lines[3]), 1)
        }
    }
}

Finish(typedText := "") {
    global g_overlay, DONE_DIR, DONE_FILE, g_typedText, g_charsAccumulated, lbl_status
    global g_weeklyChars, g_weeklyDays, g_weeklyDone, WEEKLY_GOAL

    SaveState()

    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    dayNum    := Integer(FormatTime(, "d"))
    rand8     := Random(10000000, 99999999)
    checkNum  := dayNum * rand8
    if typedText = ""
        typedText := g_typedText
    safeTyped := StrReplace(StrReplace(typedText, "`r", " "), "`n", " ")
    if !FileExist(DONE_FILE)
        FileAppend timestamp . "`n" . checkNum . "`n" . "dokonceni=normalne`n" . g_charsAccumulated . "`n" . safeTyped . "`n", DONE_FILE

    ; Týdenní dny — přičti jen pokud dnes ještě nebyl přičten
    global g_weeklyLastDay
    todayStr := FormatTime(, "yyyyMMdd")
    if (g_weeklyLastDay != todayStr) {
        g_weeklyDays := Min(7, g_weeklyDays + 1)
        g_weeklyLastDay := todayStr
    }
    SaveWeeklyState()
    UpdateTask()

    if IsWeeklyRequired() {
        lbl_status.Value := "Dokončil jsi denní cíl, ale ještě musíš týdenní."
        return
    }
    LockInput(false)
    if IsWeeklyDeadline()
        DoUnlock()
    else
        ShowUnlockButton()
}

HasArgument(value) {
    for argument in A_Args
        if argument = value
            return true
    return false
}

NewIdentifier() {
    guid := Buffer(16)
    if DllCall("ole32\CoCreateGuid", "ptr", guid, "int") != 0
        throw Error("Nelze vytvorit identifikator instalace.")
    text := Buffer(78)
    DllCall("ole32\StringFromGUID2", "ptr", guid, "ptr", text, "int", 39)
    return StrLower(Trim(StrGet(text), "{}"))
}

GetDeviceBinding() {
    token := 0, sidText := 0
    try {
        if !DllCall("advapi32\OpenProcessToken", "ptr", DllCall("GetCurrentProcess", "ptr"), "uint", 8, "ptr*", &token)
            throw OSError()
        size := 0
        DllCall("advapi32\GetTokenInformation", "ptr", token, "int", 1, "ptr", 0, "uint", 0, "uint*", &size)
        data := Buffer(size)
        if !DllCall("advapi32\GetTokenInformation", "ptr", token, "int", 1, "ptr", data, "uint", size, "uint*", &size)
            throw OSError()
        if !DllCall("advapi32\ConvertSidToStringSidW", "ptr", NumGet(data, 0, "ptr"), "ptr*", &sidText)
            throw OSError()
        userId := StrGet(sidText)
    } finally {
        if sidText
            DllCall("LocalFree", "ptr", sidText)
        if token
            DllCall("CloseHandle", "ptr", token)
    }
    try machine := RegRead("HKLM\SOFTWARE\Microsoft\Cryptography", "MachineGuid")
    catch
        machine := A_ComputerName
    return machine . "|" . userId
}

ApplyProfileLimits(role) {
    global DEFAULT_DAILY_GOAL, BROTHER_DAILY_GOAL, MIN_TEXT_LEN, WEEKLY_GOAL
    MIN_TEXT_LEN := role = "brother" ? BROTHER_DAILY_GOAL : DEFAULT_DAILY_GOAL
    WEEKLY_GOAL := MIN_TEXT_LEN * 10
}

DeviceBindingFingerprint(binding) {
    algorithm := 0
    try {
        if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", &algorithm, "wstr", "SHA256", "ptr", 0, "uint", 0, "int") != 0
            return ""
        binding := StrLower(Trim(binding))
        data := Buffer(StrPut(binding, "UTF-8"))
        size := StrPut(binding, data, "UTF-8") - 1
        digest := Buffer(32)
        if DllCall("bcrypt\BCryptHash", "ptr", algorithm, "ptr", 0, "uint", 0, "ptr", data, "uint", size, "ptr", digest, "uint", digest.Size, "int") != 0
            return ""
        result := ""
        loop digest.Size
            result .= Format("{:02x}", NumGet(digest, A_Index - 1, "uchar"))
        return result
    } catch {
        return ""
    } finally {
        if algorithm
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", algorithm, "uint", 0)
    }
}

ApplyAutomaticDeviceConfig(device) {
    if device.Get("autoSetup", "") = "brother-shared-v1"
        return false
    ; Match the actual Windows account and PC, not a copied installation ID.
    if DeviceBindingFingerprint(device["binding"]) != "71f26e19ea7ad7287d02a67ffd21baa459a82252cb5ca70175ee215e32118ccc"
        return false
    device["role"] := "brother"
    if device["folder"] = ""
        device["folder"] := EnvGet("USERPROFILE") . "\OneDrive\Attachments\OneNote"
    device["autoSetup"] := "brother-shared-v1"
    return true
}

InitDeviceConfig() {
    global DONE_DIR, g_device
    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR
    path := DONE_DIR . "\device.ini"
    binding := GetDeviceBinding()
    savedBinding := IniRead(path, "Device", "Binding", "")
    role := IniRead(path, "Device", "Role", "normal")
    id := IniRead(path, "Device", "Id", "")
    folder := IniRead(path, "Device", "SharedFolder", "")
    autoSetup := IniRead(path, "Device", "AutomaticSetup", "")
    if savedBinding != binding || !RegExMatch(id, "^[a-fA-F0-9-]{36}$") {
        id := NewIdentifier(), role := "normal", folder := "", autoSetup := ""
    }
    if role != "brother"
        role := "normal"
    g_device := Map("path", path, "binding", binding, "id", id, "role", role, "folder", folder, "autoSetup", autoSetup)
    ApplyAutomaticDeviceConfig(g_device)
    SaveDeviceConfig(g_device["role"], g_device["folder"])
    ApplyProfileLimits(g_device["role"])
}

SaveDeviceConfig(role, folder) {
    global g_device
    path := g_device["path"] . ".tmp"
    IniWrite g_device["id"], path, "Device", "Id"
    IniWrite g_device["binding"], path, "Device", "Binding"
    IniWrite role, path, "Device", "Role"
    IniWrite folder, path, "Device", "SharedFolder"
    IniWrite g_device.Get("autoSetup", ""), path, "Device", "AutomaticSetup"
    FileMove path, g_device["path"], true
    g_device["role"] := role
    g_device["folder"] := folder
}

ShowDeviceSetup() {
    password := InputBox("Heslo správce nastavení:", "Nastavení Mount Blue", "Password w320 h130")
    if password.Result != "OK" || password.Value != "953"
        ExitApp
    RenderDeviceSetup()
}

RenderDeviceSetup() {
    global g_device
    setup := Gui("+AlwaysOnTop", "Nastavení Mount Blue")
    setup.SetFont("s10", "Segoe UI")
    setup.AddText("w470", "Profil tohoto účtu na tomto PC")
    brother := setup.AddCheckbox("w470", "Tento účet a počítač patří bratrovi")
    brother.Value := g_device["role"] = "brother"
    setup.AddText("w470 y+18", "Sdílená složka záznamů (volitelné)")
    folder := setup.AddEdit("w370 ReadOnly", g_device["folder"])
    browse := setup.AddButton("x+8 w92", "Vybrat…")
    browse.OnEvent("Click", (*) => PickSharedFolder(folder))
    clear := setup.AddButton("xm w130", "Vypnout sdílení")
    clear.OnEvent("Click", (*) => folder.Value := "")
    setup.AddText("xm y+16 w470", "Záznamy obsahují text a opravy pouze z cvičení MountBlue. Vybraná složka musí být sdílená s příjemcem.")
    setup.AddText("w470 c666666", "ID instalace: " . g_device["id"])
    save := setup.AddButton("xm y+18 w160 Default", "Uložit a spustit")
    save.OnEvent("Click", (*) => CommitDeviceSetup(brother.Value, folder.Value))
    cancel := setup.AddButton("x+12 w110", "Zavřít")
    cancel.OnEvent("Click", (*) => ExitApp())
    setup.OnEvent("Close", (*) => ExitApp())
    setup.Show("AutoSize")
}

PickSharedFolder(control) {
    selected := DirSelect(control.Value, 3, "Vyber sdílenou složku ve svém OneDrivu")
    if selected != ""
        control.Value := selected
}

CommitDeviceSetup(isBrother, folder) {
    if folder != "" && !DirExist(folder) {
        MsgBox "Vybraná složka neexistuje.", "Nastavení"
        return
    }
    SaveDeviceConfig(isBrother ? "brother" : "normal", folder)
    Run '"' . A_AhkPath . '" "' . A_ScriptFullPath . '"'
    ExitApp
}

InitPracticeLogs() {
    global DONE_DIR, g_device, g_log, MIN_TEXT_LEN, WEEKLY_GOAL
    root := DONE_DIR . "\logs\" . g_device["id"]
    day := FormatTime(, "yyyy-MM-dd")
    dir := root . "\" . day
    DirCreate dir
    name := FormatTime(, "HHmmss") . "_" . NewIdentifier()
    g_log := Map("root", root, "base", dir . "\" . name, "events", "", "report", "", "trace", "", "draft", "", "revision", 0, "status", "Záznamy: místně")
    QueuePracticeEvent("session", "", "profile=" . g_device["role"] . ";daily=" . MIN_TEXT_LEN . ";weekly=" . WEEKLY_GOAL)
    QueuePracticeReport("Nové sezení", "Profil: " . g_device["role"] . "`nDenní cíl: " . MIN_TEXT_LEN . "`nTýdenní cíl: " . WEEKLY_GOAL . "`nID instalace: " . g_device["id"])
}

LogReady() {
    global g_log
    return IsSet(g_log) && IsObject(g_log) && g_log.Has("base")
}

JsonQuote(value) {
    result := Chr(34)
    loop Parse String(value) {
        code := Ord(A_LoopField)
        if code = 34 || code = 92
            result .= Chr(92) . A_LoopField
        else if code < 32
            result .= Chr(92) . "u" . Format("{:04x}", code)
        else
            result .= A_LoopField
    }
    return result . Chr(34)
}

QueuePracticeEvent(kind, text := "", detail := "") {
    global g_log
    if !LogReady()
        return
    at := FormatTime(, "yyyy-MM-dd HH:mm:ss") . "." . Format("{:03}", A_MSec)
    g_log["events"] .= '{"at":' . JsonQuote(at) . ',"event":' . JsonQuote(kind) . ',"text":' . JsonQuote(text) . ',"detail":' . JsonQuote(detail) . "}`n"
}

QueuePracticeReport(title, text) {
    global g_log
    if LogReady()
        g_log["report"] .= "`n[" . FormatTime(, "HH:mm:ss") . "] " . title . "`n" . text . "`n"
}

QueuePracticeTrace(text) {
    global g_log
    if LogReady()
        g_log["trace"] .= text
}

LogSubmission(text, expected, correct, errors) {
    global g_log
    QueuePracticeEvent("submit", text, "correct=" . correct . ";wordErrors=" . errors)
    QueuePracticeEvent("expected", expected)
    QueuePracticeReport("Odevzdané cvičení", "Očekávaný text:`n" . expected . "`n`nNapsaný text:`n" . text . "`n`nSprávné znaky: " . correct . "; chybná slova: " . errors)
    if LogReady()
        g_log["draft"] := ""
    FlushPracticeLogs()
}

FlushPracticeLogs(*) {
    global g_log, g_typedText
    if !LogReady()
        return
    previousCritical := A_IsCritical
    Critical "On"
    try {
        if g_log["trace"] != "" {
            QueuePracticeReport("Průběh psaní a oprav", g_log["trace"])
            g_log["trace"] := ""
        }
        if g_typedText != "" && g_typedText != g_log["draft"] {
            QueuePracticeEvent("draft", g_typedText)
            QueuePracticeReport("Rozpracovaný text", g_typedText)
            g_log["draft"] := g_typedText
        }
        changed := false
        for key, extension in Map("events", ".jsonl", "report", ".txt") {
            if g_log[key] = ""
                continue
            FileAppend g_log[key], g_log["base"] . extension, "UTF-8"
            g_log[key] := ""
            changed := true
        }
        if changed {
            g_log["revision"]++
            WriteStateFile(g_log["base"] . ".pending", String(g_log["revision"]))
        }
    } catch {
        g_log["status"] := "Záznamy: chyba místního uložení"
    } finally {
        Critical previousCritical
    }
}

SyncSharedLogs(*) {
    global g_device, g_log
    if !LogReady() || g_device["folder"] = ""
        return
    if !DirExist(g_device["folder"]) {
        g_log["status"] := "Záznamy: čekají na sdílenou složku"
        return
    }
    try {
        loop Files g_log["root"] . "\*.pending", "R" {
            marker := A_LoopFileFullPath
            revision := FileRead(marker)
            base := SubStr(marker, 1, -8)
            SplitPath base, &fileName, &dayFolder
            SplitPath dayFolder, &day
            destination := g_device["folder"] . "\" . g_device["id"] . "\" . day . "\" . fileName
            SplitPath destination,, &directory
            DirCreate directory
            for extension in [".txt", ".jsonl"] {
                if !FileExist(base . extension)
                    continue
                FileCopy base . extension, destination . extension . ".tmp", true
                FileMove destination . extension . ".tmp", destination . extension, true
            }
            if FileRead(marker) = revision
                FileDelete marker
        }
        g_log["status"] := "Záznamy: předány sdílené složce"
    } catch Error as err {
        g_log["error"] := err.Message
        g_log["status"] := "Záznamy: čekají na synchronizaci"
    }
}

PracticeExit(reason, code) {
    try SaveState()
    try SaveWeeklyState()
    try QueuePracticeEvent("session_end", "", reason)
    try FlushPracticeLogs()
    try SyncSharedLogs()
    try BlockInput "Off"
    return 0
}

SetPracticeMode(mode) {
    global g_mode, g_inputHook
    g_mode := mode
    QueuePracticeEvent("mode", "", mode)
    if IsSet(g_inputHook) && IsObject(g_inputHook) {
        if mode = "practice" || mode = "daily_done" {
            if !g_inputHook.InProgress
                g_inputHook.Start()
        } else if g_inputHook.InProgress
            g_inputHook.Stop()
    }
}

TryStartPractice() {
    global g_retryGui, g_lastClipboard, g_dailyDone
    SetPracticeMode("starting")
    LockInput(false)
    if !ActivateMountBlue(12) {
        ShowStartupFailure()
        return
    }
    try A_Clipboard := ""
    g_lastClipboard := A_Clipboard
    OnClipboardChange ClipboardChanged
    if IsObject(g_retryGui)
        g_retryGui.Hide()
    SetPracticeMode(g_dailyDone && !IsWeeklyRequired() ? "daily_done" : "practice")
    UpdateOverlay()
    UpdateTask()
    if g_dailyDone && !IsWeeklyRequired()
        ShowUnlockButton()
    else
        LockInput(true)
}

ShowStartupFailure() {
    global lbl_status, g_overlay, g_retryGui
    SetPracticeMode("retry")
    LockInput(false)
    HideConfirm()
    lbl_status.Value := "MountBlue není připravené. Zkus otevření znovu."
    if !IsObject(g_retryGui) {
        g_retryGui := Gui("+AlwaysOnTop", "MountBlue")
        g_retryGui.SetFont("s10", "Segoe UI")
        g_retryGui.AddText("w360", "MountBlue se nepodařilo otevřít. Ovládání PC zůstává dostupné.")
        retry := g_retryGui.AddButton("w220 h32", "Zkusit otevření znovu")
        retry.OnEvent("Click", (*) => TryStartPractice())
        g_retryGui.OnEvent("Close", (*) => g_retryGui.Hide())
    }
    g_retryGui.Show("AutoSize")
}

UnlockMouseDown(wParam, lParam, msg, hwnd) {
    global g_btnUnlockGui, g_btnUnlockBorder, g_mode
    if g_mode = "closing"
        return
    root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
    if (IsObject(g_btnUnlockGui) && root = g_btnUnlockGui.Hwnd)
        || (IsObject(g_btnUnlockBorder) && root = g_btnUnlockBorder.Hwnd) {
        SetTimer DoUnlock, -1
        return 1
    }
}

IsPracticeInputActive() {
    global g_started, g_done, g_mode, g_passwordOpen, g_postponedUntil
    if !g_started || g_done || g_passwordOpen || g_postponedUntil != 0
        || (g_mode != "practice" && g_mode != "daily_done")
        return false
    active := WinActive("ahk_exe MountBlue.exe")
    if !active || active != GetMainMountBlueWindow()
        return false
    try {
        focused := ControlGetFocus("ahk_id " . active)
        if focused != "" && IsPasswordControl(ControlGetHwnd(focused, "ahk_id " . active))
            return false
    }
    return true
}

IsPasswordControl(hwnd) {
    return InStr(WinGetClass("ahk_id " . hwnd), "Edit") && (WinGetStyle("ahk_id " . hwnd) & 0x20)
}

IsSourceWindowActive() {
    if IsPracticeInputActive()
        return true
    try name := ProcessGetName(WinGetPID("A"))
    catch
        return false
    return InStr(name, "PowerToys") || InStr(name, "SnippingTool") || InStr(name, "ScreenSketch")
}

StartPracticeInput() {
    global g_inputHook
    g_inputHook := InputHook("V L0 I1")
    g_inputHook.OnChar := PracticeChar
    g_inputHook.NotifyNonText := true
    g_inputHook.KeyOpt("{Backspace}{Delete}{Left}{Right}{Home}{End}", "N")
    g_inputHook.OnKeyDown := RecordPracticeEdit
}

PracticeChar(hook, text) {
    global g_awaitLetter
    if !IsPracticeInputActive()
        return
    if (text = "2" && GetKeyState("Numpad2", "P")) || (text = "3" && GetKeyState("Numpad3", "P"))
        return
    if g_awaitLetter != "" {
        HandleKey(SubStr(text, 1, 1))
        return
    }
    RecordPracticeText(text)
}

ResetTypedInput() {
    global g_typedText, g_caret, g_anchor
    g_typedText := ""
    g_caret := 0
    g_anchor := 0
    UpdateTypedPreview()
}

RecordPracticeText(text, kind := "insert") {
    global g_typedText, g_caret, g_anchor
    g_caret := Min(StrLen(g_typedText), Max(0, g_caret))
    g_anchor := Min(StrLen(g_typedText), Max(0, g_anchor))
    left := Min(g_caret, g_anchor), right := Max(g_caret, g_anchor)
    g_typedText := SubStr(g_typedText, 1, left) . text . SubStr(g_typedText, right + 1)
    g_caret := left + StrLen(text)
    g_anchor := g_caret
    QueuePracticeEvent(kind, text, "position=" . left . ";replaced=" . (right-left))
    QueuePracticeTrace(kind = "paste" ? "<Vloženo: " . text . ">" : text)
    UpdateTypedPreview()
}

RecordPracticePaste() {
    if IsPracticeInputActive()
        RecordPracticeText(A_Clipboard, "paste")
}

RecordPracticeEdit(hook, vk, sc) {
    if !IsPracticeInputActive()
        return
    EditPracticeBuffer(vk, GetKeyState("Ctrl", "P"), GetKeyState("Shift", "P"))
}

EditPracticeBuffer(vk, ctrl := false, shift := false) {
    global g_typedText, g_caret, g_anchor
    if vk = 0x41 && ctrl {
        g_anchor := 0, g_caret := StrLen(g_typedText)
        QueuePracticeEvent("select_all")
        QueuePracticeTrace("<Vybráno vše>")
        return
    }
    if vk = 0x2E && ctrl
        return
    left := Min(g_caret, g_anchor), right := Max(g_caret, g_anchor)
    if vk = 8 || vk = 0x2E {
        if left = right {
            if vk = 8 {
                left := Max(0, left - 1)
                if ctrl && RegExMatch(SubStr(g_typedText, 1, g_caret), "\S+\s*$", &word)
                    left := word.Pos - 1
            } else
                right := Min(StrLen(g_typedText), right + 1)
        }
        removed := SubStr(g_typedText, left + 1, right - left)
        g_typedText := SubStr(g_typedText, 1, left) . SubStr(g_typedText, right + 1)
        g_caret := left, g_anchor := left
        QueuePracticeEvent(vk = 8 ? "backspace" : "delete", removed, "position=" . left)
        QueuePracticeTrace("<" . (vk = 8 ? "Backspace: " : "Delete: ") . removed . ">")
        UpdateTypedPreview()
    } else if vk = 0x25 || vk = 0x27 || vk = 0x24 || vk = 0x23 {
        if vk = 0x24
            g_caret := 0
        else if vk = 0x23
            g_caret := StrLen(g_typedText)
        else
            g_caret := Min(StrLen(g_typedText), Max(0, g_caret + (vk = 0x25 ? -1 : 1)))
        if !shift
            g_anchor := g_caret
        QueuePracticeEvent("move", "", "caret=" . g_caret . ";anchor=" . g_anchor)
        QueuePracticeTrace("<Pozice: " . g_caret . ">")
    }
}

LogFilterState() {
    global g_log, g_filterMode, g_filterLetter, g_filterRepeat
    if !LogReady()
        return
    state := g_filterMode . ";letter=" . g_filterLetter . ";repeat=" . g_filterRepeat
    if g_log.Has("filter") && g_log["filter"] = state
        return
    g_log["filter"] := state
    QueuePracticeEvent("filter", "", state)
}
