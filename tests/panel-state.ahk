#Requires AutoHotkey v2.0
OnError TestError
global g_overlay := Gui("+ToolWindow -Caption -DPIScale", "Hidden panel test")
global MIN_TEXT_LEN := 300, WEEKLY_GOAL := 3000, POSTPONE_MIN := 30, POSTPONE_MAX := 3, START_HOUR := 0
global g_inputHook := 0, g_log := Map(), g_mode := "starting", g_locked := false, g_done := false
global g_btnUnlockGui := 0, g_btnUnlockBorder := 0, OVERLAY_W := 520, g_quickPauseAvailable := true, g_postponedUntil := 0, g_postponeCount := 0
global lbl_status, lbl_source_len, lbl_source_count, lbl_filter, lbl_expected, lbl_result, lbl_errors
global lbl_typed, lbl_typed_label, lbl_task, lbl_weekly, lbl_postpone, btn_postpone, btn_spotify, btn_quick_pause
global lbl_confirm, btn_confirm_yes, btn_confirm_no
BuildOverlayUI(520, 1080)
Assert(btn_postpone.Text = "⏸  Odložit  ( 30 min )", "postpone label and original design are preserved")
btn_postpone.GetPos(&px, &py, &pw, &ph)
btn_spotify.GetPos(&sx, &sy, &sw, &sh)
Assert(sy > py + ph && sw = pw, "green Spotify bar sits below postpone")
Assert(InStr(btn_spotify.Text, "Spotify"), "Spotify button is labelled")
btn_quick_pause.GetPos(&qx, &qy, &qw, &qh)
Assert(qy > sy + sh && qw = sw, "quick pause button sits below Spotify bar")
Assert(InStr(btn_quick_pause.Text, "Zastavit") && InStr(btn_quick_pause.Text, "10 s"), "quick pause button is labelled with 10s duration")
foundMediaShortcut := false
for control in g_overlay {
    if InStr(control.Text, "Ctrl+Alt+Mezerník") || InStr(control.Text, "Pauza videa")
        foundMediaShortcut := true
}
Assert(!foundMediaShortcut, "video pause shortcut has been removed from keyboard list")
Assert(g_quickPauseAvailable = true, "quick pause is available on initial startup")
DoQuickPause()
Assert(g_quickPauseAvailable = false, "quick pause is unavailable once used")
Assert(g_postponedUntil > 0, "quick pause sets postponed timer")
SetTimer ShowOverlayAgain, 0
g_postponedUntil := 0
DoPostpone()
Assert(g_quickPauseAvailable = true, "normal postpone resets quick pause availability")
SetTimer ShowOverlayAgain, 0
g_postponedUntil := 0
Assert(DllCall("SendMessageW", "ptr", g_overlay["PROG_BAR"].Hwnd, "uint", 0x407, "ptr", 0, "ptr", 0, "ptr") = 300, "daily progress range follows brother's limit")
Assert(DllCall("SendMessageW", "ptr", g_overlay["PROG_WEEK"].Hwnd, "uint", 0x407, "ptr", 0, "ptr", 0, "ptr") = 3000, "weekly progress range follows brother's limit")
for control in g_overlay
    Assert(!InStr(control.Text, "Záznamy:"), "normal panel contains no new logging status")
passwordControl := g_overlay.AddEdit("Hidden Password", "")
plainControl := g_overlay.AddEdit("Hidden", "")
Assert(IsPasswordControl(passwordControl.Hwnd), "native password fields are excluded from practice recording")
Assert(!IsPasswordControl(plainControl.Hwnd), "plain edit fields are not mistaken for password fields")
SetPracticeMode("confirm")
WatchWindow()
Assert(g_mode = "confirm" && !g_locked, "confirmation state cannot steal focus or lock input")
SetPracticeMode("daily_done")
WatchWindow()
Assert(g_mode = "daily_done", "unlock state cannot steal focus")
g_btnUnlockGui := Gui("+ToolWindow -Caption")
title := g_btnUnlockGui.AddText("w300 h26", "ODEMKNOUT PC")
body := g_btnUnlockGui.AddText("w300 h18", "Týden: 350 / 3000")
g_btnUnlockBorder := Gui("+ToolWindow -Caption")
Critical "On"
Assert(UnlockMouseDown(0, 0, 0x201, title.Hwnd) = 1, "unlock title routes the first mouse press")
SetTimer DoUnlock, 0
Assert(UnlockMouseDown(0, 0, 0x201, body.Hwnd) = 1, "unlock secondary text routes the first mouse press")
SetTimer DoUnlock, 0
Assert(UnlockMouseDown(0, 0, 0x201, g_btnUnlockGui.Hwnd) = 1, "unlock empty background routes the first mouse press")
SetTimer DoUnlock, 0
Assert(UnlockMouseDown(0, 0, 0x201, g_btnUnlockBorder.Hwnd) = 1, "unlock border routes the first mouse press")
SetTimer DoUnlock, 0
Assert(UnlockMouseDown(0, 0, 0x201, btn_postpone.Hwnd) = "", "unrelated panel controls retain their normal mouse handling")
Critical "Off"
global APP_PATH := A_ScriptDir . "\nonexistent-mountblue.exe"
if !ProcessExist("MountBlue.exe")
    Assert(!ActivateMountBlue(1), "failed startup does not report a usable MountBlue window")

global DONE_DIR := A_ScriptDir . "\..\..\panel-eval-test-" . DllCall("GetCurrentProcessId")
DirCreate DONE_DIR
global SESSION_DAY := FormatTime(, "yyyy-MM-dd"), STATE_FILE := DONE_DIR . "\state.txt"
global g_weekFile := DONE_DIR . "\week_state.txt", g_weekStartFile := DONE_DIR . "\week_start.txt"
global g_evaluating := false, g_dailyDone := false, g_weeklyChars := 0, g_weeklyDays := 0, g_weeklyDone := false, g_weeklyLastDay := ""
global g_charsAccumulated := 0, g_passedCount := 0, g_exerciseNum := 1, g_lastResult := "", g_lastErrors := 0, g_lastCorrectChars := 0
global g_filterMode := "reverse", g_filterLetter := "a", g_filterRepeat := 2, g_awaitLetter := ""
global g_caret := 0, g_anchor := 0, g_btnYesGui := 0, g_btnNoGui := 0, g_btnYesBorder := 0, g_btnNoBorder := 0
global MIN_TEXT_LEN := 10000, WEEKLY_GOAL := 90000

g_mode := "practice", g_textReady := true, g_sourceText := "one two three four five"
g_typedText := "e x1 x2 x3 owt eno", g_caret := StrLen(g_typedText), g_anchor := StrLen(g_typedText)
g_filterMode := "", g_filterRepeat := 1
g_typedText := "one x1 x2 x3 five", g_caret := StrLen(g_typedText), g_anchor := StrLen(g_typedText)
EvaluateExercise()
Assert(g_lastErrors = 3 && g_mode = "practice" && g_sourceText = "" && !g_textReady && !IsObject(g_btnYesGui), "3 or fewer errors auto-confirm without showing confirm buttons")

g_mode := "practice", g_textReady := true, g_sourceText := "one two three four five"
g_typedText := "x1 x2 x3 x4 five", g_caret := StrLen(g_typedText), g_anchor := StrLen(g_typedText)
EvaluateExercise()
Assert(g_lastErrors = 4 && g_mode = "confirm" && IsObject(g_btnYesGui), "4 errors still show confirmation buttons")
HideConfirm()

try DirDelete(DONE_DIR, true)
g_btnUnlockGui.Destroy()
g_btnUnlockBorder.Destroy()
g_overlay.Destroy()
FileAppend "All hidden panel tests passed.`n", "*"
ExitApp

Assert(condition, label) {
    FileAppend (condition ? "PASS: " : "FAILED: ") . label . "`n", "*"
    if !condition
        ExitApp 1
}

TestError(err, mode) {
    FileAppend "ERROR: " . err.Message . " at " . err.Line . "`n", "*"
    ExitApp 1
}

#Include ..\PovinePsani.ahk
