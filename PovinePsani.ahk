#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; ═══════════════════════════════════════════════════════════════
;  MOUNT BLUE ENFORCER v5
; ═══════════════════════════════════════════════════════════════

; ─── AUTO-UPDATE KONFIGURACE ───────────────────────────────────
; Nastav na svou GitHub raw URL po nahrání souborů (viz návod)
UPDATE_VERSION_URL := "https://raw.githubusercontent.com/TVOJE_JMENO/TVOJE_REPO/main/version.txt"
UPDATE_SCRIPT_URL  := "https://raw.githubusercontent.com/TVOJE_JMENO/TVOJE_REPO/main/PovinePsani.ahk"
LOCAL_VERSION_FILE := A_AppData . "\MountBlueEnforcer\version.txt"
THIS_SCRIPT_VERSION := 1   ; ZVYŠ toto číslo při každém uploadu nové verze na GitHub
UPDATE_TIMEOUT_MS   := 4000  ; max čekání na odpověď serveru (ms)
; ─────────────────────────────────────────────────────────────

CheckForUpdate()

; ─── KONFIGURACE ───────────────────────────────────────────────
APP_PATH          := "C:\Program Files (x86)\HYL\MountBlue\MountBlue.exe"
DONE_FILE         := A_AppData . "\MountBlueEnforcer\done_" . FormatTime(, "yyyy-MM-dd") . ".txt"
STATE_FILE        := A_AppData . "\MountBlueEnforcer\state_" . FormatTime(, "yyyy-MM-dd") . ".txt"
DONE_DIR          := A_AppData . "\MountBlueEnforcer"
MIN_TEXT_LEN      := 250
START_HOUR        := 11
OVERLAY_W         := 520
POSTPONE_MAX      := 3
POSTPONE_MIN      := 30
WEEKLY_GOAL       := 2500     ; znaky pro týdenní cíl (7 dní)
; ───────────────────────────────────────────────────────────────

; ═══════════════════════════════════════════════════════════════
;  AUTO-UPDATE — zkontroluje GitHub, stáhne novější verzi, restartuje
; ═══════════════════════════════════════════════════════════════
CheckForUpdate() {
    global UPDATE_VERSION_URL, UPDATE_SCRIPT_URL, LOCAL_VERSION_FILE, THIS_SCRIPT_VERSION

    ; Pokud URL nejsou nastavené (placeholder), přeskoč
    if InStr(UPDATE_VERSION_URL, "TVOJE_JMENO")
        return

    remoteVersion := 0
    tempVerFile := A_Temp . "\mbe_version_check.txt"

    try {
        Download(UPDATE_VERSION_URL, tempVerFile)
        if FileExist(tempVerFile) {
            remoteVersion := Integer(Trim(FileRead(tempVerFile)))
            FileDelete tempVerFile
        }
    } catch {
        ; Žádné internetové připojení nebo server nedostupný — pokračuj normálně
        return
    }

    if (remoteVersion <= THIS_SCRIPT_VERSION)
        return   ; lokální verze je aktuální nebo novější

    ; ── Nová verze dostupná — stáhni ji ──
    tempScriptFile := A_Temp . "\mbe_new_version.ahk"
    try {
        Download(UPDATE_SCRIPT_URL, tempScriptFile)
    } catch {
        return   ; stažení selhalo, pokračuj se starou verzí
    }

    ; Ověř že stažený soubor není prázdný/poškozený
    if !FileExist(tempScriptFile)
        return
    fileSize := FileGetSize(tempScriptFile)
    if (fileSize < 1000)   ; podezřele malý soubor = pravděpodobně chyba
        return

    ; Over že obsahuje základní AHK hlavičku (sanity check)
    try {
        content := FileRead(tempScriptFile, "UTF-8")
        if !InStr(content, "#Requires AutoHotkey")
            return
    } catch {
        return
    }

    ; ── Vše OK — nahraď aktuální skript a restartuj ──
    try {
        currentScriptPath := A_ScriptFullPath
        FileCopy tempScriptFile, currentScriptPath, true   ; true = přepsat
        FileDelete tempScriptFile

        ; Spusť novou verzi a ukonči tuto
        Run '"' . A_AhkPath . '" "' . currentScriptPath . '"'
        ExitApp
    } catch {
        ; Pokud se nahrazení nepovede (např. soubor uzamčen), pokračuj se starou verzí
        return
    }
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
global g_exerciseNum       := 1       ; číslo aktuálního cvičení
global g_charsAccumulated  := 0       ; součet správně zarovnaných znaků
global g_weeklyChars      := 0     ; znaky naakumulované pro týdenní cíl
global g_weeklyDays       := 0     ; počet dokončených dnů v týdnu
global g_weeklyDone       := false ; týdenní cíl splněn
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
if FileExist(DONE_FILE)
    ExitApp

; Týdenní cíl = rolling 7denní okno od PRVNÍHO spuštění programu (ne kalendářní týden)
g_weekFile := A_AppData . "\MountBlueEnforcer\week_state.txt"
g_weekStartFile := A_AppData . "\MountBlueEnforcer\week_start.txt"
InitWeekWindow()

; Načti stav z předchozího sezení
LoadState()

LoadWeeklyState()
; Před 11:00 nedělej absolutně nic — jen čekej
WaitUntilHour()

; Dvojitá pojistka — po probuzení zkontroluj čas znovu
if Integer(FormatTime(, "H")) < START_HOUR
    ExitApp

g_started := true

if !ProcessExist("MountBlue.exe")
    Run APP_PATH

loop 60 {
    hwnd := WinExist("ahk_exe MountBlue.exe")
    if hwnd
        break
    Sleep 500
}
if !hwnd {
    MsgBox "MountBlue se nepodarilo spustit!"
    ExitApp
}

Sleep 1500
ActivateMountBlue(8)
Sleep 500

; Vymaz starou schranku jeste pred zapnutim sledovani, aby se nenacetl text z minula.
try A_Clipboard := ""
g_lastClipboard := A_Clipboard

; Sledování schránky — automaticky načte zadaný text
OnClipboardChange ClipboardChanged

LockInput(true)
CreateOverlay()

SetTimer WatchWindow,    1000
SetTimer PollClipboard,  800
return

; ═══════════════════════════════════════════════════════════════
;  SCHRÁNKA — automatické načtení zadaného textu
; ═══════════════════════════════════════════════════════════════
ClipboardChanged(DataType) {
    global g_sourceText, g_lastResult, g_lastErrors, g_textReady
    global g_done, g_typedText, g_exerciseNum, lbl_status, g_overlay

    if (DataType != 1 || g_done)
        return

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

    g_sourceText  := cleaned
    g_lastResult  := ""
    g_lastErrors  := -1
    g_textReady   := true
    g_typedText   := ""    ; reset napsaného textu pro nové cvičení

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
    global g_done, g_postponedUntil, g_passwordOpen
    if g_done
        return
    if g_passwordOpen
        return
    if (g_postponedUntil > 0 && A_TickCount < g_postponedUntil)
        return
    if !ProcessExist("MountBlue.exe") {
        Run APP_PATH
        Sleep 2000
    }
    hwnd := GetMainMountBlueWindow()
    if hwnd {
        try activeExe := ProcessGetName(WinGetPID("A"))
        catch
            activeExe := ""
        if InStr(activeExe, "PowerToys") || InStr(activeExe, "Spotify")
            || InStr(activeExe, "SnippingTool") || InStr(activeExe, "ScreenSketch")
            return
        ; Pokud je aktivní okno JINÉ okno MountBlue (popup) → nech ho být
        activeHwnd := WinExist("A")
        try activeExeName := ProcessGetName(WinGetPID("ahk_id " activeHwnd))
        catch
            activeExeName := ""
        if (activeHwnd != hwnd) && (activeExeName != "MountBlue.exe")
            ActivateMountBlue(3)
    }
}

; ═══════════════════════════════════════════════════════════════
;  HOTKEYS
; ═══════════════════════════════════════════════════════════════

; Ctrl+Enter = vyhodnoť
#HotIf g_started && !g_done
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

; Klávesy — přes HandleKey (malá i velká)
a:: HandleKey("a")
b:: HandleKey("b")
c:: HandleKey("c")
d:: HandleKey("d")
e:: HandleKey("e")
f:: HandleKey("f")
g:: HandleKey("g")
h:: HandleKey("h")
i:: HandleKey("i")
j:: HandleKey("j")
k:: HandleKey("k")
l:: HandleKey("l")
m:: HandleKey("m")
n:: HandleKey("n")
o:: HandleKey("o")
p:: HandleKey("p")
q:: HandleKey("q")
r:: HandleKey("r")
s:: HandleKey("s")
t:: HandleKey("t")
u:: HandleKey("u")
v:: HandleKey("v")
w:: HandleKey("w")
x:: HandleKey("x")
y:: HandleKey("y")
z:: HandleKey("z")
+a:: HandleKey("A")
+b:: HandleKey("B")
+c:: HandleKey("C")
+d:: HandleKey("D")
+e:: HandleKey("E")
+f:: HandleKey("F")
+g:: HandleKey("G")
+h:: HandleKey("H")
+i:: HandleKey("I")
+j:: HandleKey("J")
+k:: HandleKey("K")
+l:: HandleKey("L")
+m:: HandleKey("M")
+n:: HandleKey("N")
+o:: HandleKey("O")
+p:: HandleKey("P")
+q:: HandleKey("Q")
+r:: HandleKey("R")
+s:: HandleKey("S")
+t:: HandleKey("T")
+u:: HandleKey("U")
+v:: HandleKey("V")
+w:: HandleKey("W")
+x:: HandleKey("X")
+y:: HandleKey("Y")
+z:: HandleKey("Z")
0:: HandleKey("0")
1:: HandleKey("1")
2:: HandleKey("2")
3:: HandleKey("3")
4:: HandleKey("4")
5:: HandleKey("5")
6:: HandleKey("6")
7:: HandleKey("7")
8:: HandleKey("8")
9:: HandleKey("9")
Space::     HandleKey(" ")
,::         HandleKey(",")
.::         HandleKey(".")
-::         HandleKey("-")
`;::        HandleKey(";")
BackSpace:: HandleKeyBS()
#HotIf

; Blokování systémových zkratek
#HotIf g_started && !g_done
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
    BlockInput "On"
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

#HotIf
#SuspendExempt False

#HotIf
#HotIf (g_started && !g_done && g_textReady)
~LButton:: {
    global g_typedText, g_lastResult, g_lastErrors
    ; Krátká pauza aby aplikace zpracovala klik
    Sleep 80
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
    global g_textReady, g_awaitLetter, g_filterMode, g_filterLetter
    global g_typedText, lbl_typed, lbl_status, g_overlay

    ; F3/F4 čeká na písmeno
    if g_awaitLetter != "" {
        g_filterMode   := g_awaitLetter
        g_filterLetter := letter
        g_awaitLetter  := ""
        UpdateOverlay()
        return
    }

    ; Blokuj dokud není text
    if !g_textReady {
        if IsObject(g_overlay)
            lbl_status.Value := "⚠  Nejdriv Shift+Win+T → oznac zadany text!"
        return
    }

    ; Přidej do sledovaného textu
    g_typedText .= letter
    UpdateTypedPreview()

    ; Propusť do aplikace (SendEvent obchází AHK hotkey loop)
    SendEvent "{Blind}" . letter
}

HandleKeyBS() {
    global g_textReady, g_typedText
    if !g_textReady
        return
    if StrLen(g_typedText) > 0
        g_typedText := SubStr(g_typedText, 1, StrLen(g_typedText) - 1)
    UpdateTypedPreview()
    SendEvent "{BackSpace}"
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
    g_lastErrors := CountWordErrors(typedText, expected)
    g_lastCorrectChars := CountCorrectChars(typedText, expected)
    g_charsAccumulated += g_lastCorrectChars

    ; Týdenní cíl se přičítá při KAŽDÉM přičtení znaků, bez ohledu na denní cíl
    g_weeklyChars += g_lastCorrectChars
    if !g_weeklyDone && g_weeklyChars >= WEEKLY_GOAL
        g_weeklyDone := true
    SaveWeeklyState()

    g_filterMode   := ""
    g_filterLetter := ""
    g_filterRepeat := 1
    g_awaitLetter  := ""

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

    ; Pokud napsal 150+ znaků NEBO max 5 chyb → zeptej se, jestli text dokončil
    confirmNeeded := (g_lastCorrectChars >= 150 || g_lastErrors <= 5)

    if justFinishedDaily || confirmNeeded {
        BlockInput "Off"
        Suspend true
        UpdateOverlay()
        UpdateTask()

        ; Pokud byl splněn denní cíl → zapiš DONE soubor a zobraz modré tlačítko
        if justFinishedDaily
            Finish()

        ; Zobraz potvrzovací tlačítka (pokud splnil podmínky pro confirm)
        if confirmNeeded
            ShowConfirm("Dokončil jsi cvičení?   znaky: " . g_lastCorrectChars . "  ·  chyby: " . g_lastErrors)

        ; Pokud byl splněn denní cíl, ale NEbyl splněn confirm → ulož stav rovnou
        if justFinishedDaily && !confirmNeeded {
            SaveState()
        }

        return   ; zbytek (pokud je confirm) vyřeší ConfirmYes/ConfirmNo
    } else {
        ; Nesplnil ani jednu podmínku → nechej text, jen vymaz napsaný
        g_typedText := ""
        UpdateTypedPreview()
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
    if g_postponeCount >= POSTPONE_MAX
        return
    g_postponeCount++
    msDelay := POSTPONE_MIN * 60 * 1000
    g_postponedUntil := A_TickCount + msDelay
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
    if g_done
        return
    g_postponedUntil := 0
    ; Obnov timery
    SetTimer WatchWindow,  1000
    ; Znovu zamkni
    Suspend false
    BlockInput "On"
    if IsObject(g_overlay) {
        g_overlay.Show("NoActivate")
        UpdateOverlay()
    }
    hwnd := WinExist("ahk_exe MountBlue.exe")
    if hwnd
        ActivateMountBlue(4)
    SaveState()
}

ForceResumeNow() {
    global g_postponedUntil, g_done, g_overlay
    if g_done
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

    g_overlay           := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale", "MBEnforcer")
    g_overlay.BackColor := "0A0B1A"
    g_overlay.MarginX   := 0
    g_overlay.MarginY   := 0
    g_overlay.Show("x" . (screenW - OVERLAY_W) . " y0 w" . OVERLAY_W . " h" . screenH . " NoActivate")

    BuildOverlayUI(OVERLAY_W, screenH)
    UpdateOverlay()
    UpdateTask()
}

BuildOverlayUI(w, h) {
    global g_overlay
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
    lbl_task := g_overlay.Add("Text", "x" . ipad . " y" . y . " w" . ilw, "Cvičení 1  ·  0 / 250 znaků")
    y += 22

    g_overlay.Add("Progress", "x" . ipad . " y" . y . " w" . ilw . " h6 Background" . cProg . " c" . cGreen . " Range0-250 -Smooth vPROG_BAR", 0)
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
    weekTxt := g_weeklyDone ? "🏆 Tydenni cil splnen!  ·  " . g_weeklyDays . "/7 dni" : "Tyden: " . g_weeklyChars . " / " . WEEKLY_GOAL . " znaku  ·  " . g_weeklyDays . "/7 dni"
    g_btnUnlockGui.Add("Text", "x0 y44 w" . btnW . " h20 Center +0x200", weekTxt)

    g_btnUnlockGui.SetFont("s8 w400 c88AACC", "Segoe UI")
    g_btnUnlockGui.Add("Text", "x0 y68 w" . btnW . " h18 Center +0x200", "Nebo pokracuj v psani pro tydenni cil")

    g_btnUnlockGui.Show("x" . btnX . " y" . btnY . " w" . btnW . " h" . btnH . " NoActivate")
    title.OnEvent("Click", (*) => DoUnlock())
    RoundWindow(g_btnUnlockGui.Hwnd, btnW, btnH, radius)
    g_btnUnlockGui.OnEvent("Close", (*) => 0)
}

DoUnlock() {
    global g_overlay, g_btnUnlockGui, g_btnUnlockBorder
    ; Odblokuj vstup PŘED ukončením — jinak Windows zůstane zamčený
    try BlockInput "Off"
    try Suspend false
    if IsObject(g_btnUnlockBorder) {
        g_btnUnlockBorder.Destroy()
        g_btnUnlockBorder := 0
    }
    if IsObject(g_btnUnlockGui) {
        g_btnUnlockGui.Destroy()
        g_btnUnlockGui := 0
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
    global g_sourceText, g_typedText, g_textReady, g_filterMode, g_filterLetter, g_filterRepeat, g_awaitLetter
    HideConfirm()
    BlockInput "On"
    Suspend false
    g_sourceText   := ""
    g_typedText    := ""
    g_textReady    := false
    g_filterMode   := ""
    g_filterLetter := ""
    g_filterRepeat := 1
    g_awaitLetter  := ""
    UpdateTypedPreview()
    SaveState()
    UpdateOverlay()
    UpdateTask()
}

ConfirmNo() {
    global g_typedText
    HideConfirm()
    BlockInput "On"
    Suspend false
    g_typedText := ""
    UpdateTypedPreview()
    SaveState()
    UpdateOverlay()
    UpdateTask()
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
    if IsObject(lbl_weekly) {
        if g_weeklyDone {
            lbl_weekly.Value := "Týden  ·  🏆 Splněn!  " . g_weeklyDays . "/7 dní"
            lbl_weekly.SetFont("c00EE88")
        } else {
            lbl_weekly.Value := "Týden  ·  " . g_weeklyChars . " / " . WEEKLY_GOAL . " znaků  ·  " . g_weeklyDays . "/7 dní"
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
    global MIN_TEXT_LEN, POSTPONE_MAX, g_done

    if !IsObject(g_overlay)
        return

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
        lbl_postpone.Value := "odložení:  " . POSTPONE_MAX . " / " . POSTPONE_MAX . "  (vycerpano)"
        lbl_postpone.SetFont("c484C6E")
    } else {
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
    if state {
        ; Nikdy nezamykej před START_HOUR
        if Integer(FormatTime(, "H")) < START_HOUR
            return
        g_locked := true
        BlockInput "On"
    } else {
        g_locked := false
        BlockInput "Off"
    }
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
        Sleep 1000
    }
    hwnd := 0
    loop maxTries {
        hwnd := GetMainMountBlueWindow()
        if !hwnd {
            Sleep 500
            continue
        }
        try WinRestore "ahk_id " hwnd
        try WinActivate "ahk_id " hwnd
        try DllCall("SetForegroundWindow", "ptr", hwnd)
        Sleep 250
        ; Maximalizuj POUZE pokud okno není už maximalizované
        ; a pouze hlavní okno (popupy jsou menší, GetMainMountBlueWindow je nevrátí)
        try {
            if WinGetMinMax("ahk_id " hwnd) != 1
                WinMaximize "ahk_id " hwnd
        }
        if WinActive("ahk_id " hwnd)
            return true
        Sleep 350
    }
    return hwnd != 0
}

; ─── Inicializace 7denního rolling okna pro týdenní cíl ───────
InitWeekWindow() {
    global g_weekStartFile, DONE_DIR

    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR

    ; Pokud soubor s datem startu neexistuje → toto je úplně první spuštění
    if !FileExist(g_weekStartFile) {
        FileAppend FormatTime(, "yyyyMMdd"), g_weekStartFile
        return
    }

    ; Načti datum startu okna
    try {
        startStr := Trim(FileRead(g_weekStartFile))
        startDate := startStr . "000000"   ; AHK potřebuje plný timestamp
        daysPassed := DateDiff(A_Now, startDate, "Days")

        ; Pokud uplynulo 7 nebo více dní → posuň okno o tolik celých týdnů,
        ; kolik jich uplynulo (aby se okno nezasekávalo, pokud PC nebylo dlouho zapnuté)
        if (daysPassed >= 7) {
            weeksToAdd := daysPassed // 7
            newStart := DateAdd(startDate, weeksToAdd * 7, "Days")
            newStartStr := FormatTime(newStart, "yyyyMMdd")
            try FileDelete g_weekStartFile
            FileAppend newStartStr, g_weekStartFile

            ; Nové okno = vynuluj týdenní progres (poslední okno nebylo splněno)
            global g_weeklyChars, g_weeklyDays, g_weeklyDone
            g_weeklyChars := 0
            g_weeklyDays  := 0
            g_weeklyDone  := false
            try FileDelete g_weekFile
        }
    }
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
            g_weeklyDone  := Integer(lines[3]) = 1
        }
    }
}

SaveWeeklyState() {
    global g_weekFile, g_weeklyChars, g_weeklyDays, g_weeklyDone, DONE_DIR
    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR
    try FileDelete g_weekFile
    FileAppend g_weeklyChars . "`n" . g_weeklyDays . "`n" . (g_weeklyDone ? 1 : 0), g_weekFile
}

SaveState() {
    global STATE_FILE, DONE_DIR, g_postponeCount, g_charsAccumulated, g_exerciseNum
    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR
    try FileDelete STATE_FILE
    FileAppend g_postponeCount . "`n" . g_charsAccumulated . "`n" . g_exerciseNum, STATE_FILE
}

LoadState() {
    global STATE_FILE, g_postponeCount, g_charsAccumulated, g_exerciseNum
    if !FileExist(STATE_FILE)
        return
    try {
        lines := StrSplit(FileRead(STATE_FILE), "`n")
        if lines.Length >= 3 {
            g_postponeCount    := Integer(lines[1])
            g_charsAccumulated := Integer(lines[2])
            g_exerciseNum      := Max(Integer(lines[3]), 1)
        }
    }
}

Finish() {
    global g_overlay, DONE_DIR, DONE_FILE, g_typedText, g_charsAccumulated
    global g_weeklyChars, g_weeklyDays, g_weeklyDone, WEEKLY_GOAL

    SaveState()

    if !DirExist(DONE_DIR)
        DirCreate DONE_DIR
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    dayNum    := Integer(FormatTime(, "d"))
    rand8     := Random(10000000, 99999999)
    checkNum  := dayNum * rand8
    safeTyped := StrReplace(StrReplace(g_typedText, "`r", " "), "`n", " ")
    FileAppend timestamp . "`n" . checkNum . "`n" . "dokonceni=normalne`n" . g_charsAccumulated . "`n" . safeTyped . "`n", DONE_FILE

    ; Týdenní znaky se přičítají inkrementálně v EvaluateExercise — tady jen den
    g_weeklyDays += 1
    SaveWeeklyState()

    LockInput(false)

    ShowUnlockButton()
}
