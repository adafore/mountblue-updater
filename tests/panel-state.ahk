#Requires AutoHotkey v2.0
OnError TestError
global g_overlay := Gui("+ToolWindow -Caption -DPIScale", "Hidden panel test")
global MIN_TEXT_LEN := 300, WEEKLY_GOAL := 3000, POSTPONE_MIN := 30, POSTPONE_MAX := 3, START_HOUR := 0
global g_inputHook := 0, g_log := Map(), g_mode := "starting", g_locked := false, g_done := false
global g_btnUnlockGui := 0, g_btnUnlockBorder := 0, OVERLAY_W := 520
global lbl_status, lbl_source_len, lbl_source_count, lbl_filter, lbl_expected, lbl_result, lbl_errors
global lbl_typed, lbl_typed_label, lbl_task, lbl_weekly, lbl_postpone, btn_postpone
global lbl_confirm, btn_confirm_yes, btn_confirm_no
BuildOverlayUI(520, 1080)
Assert(btn_postpone.Text = "⏸  Odložit  ( 30 min )", "postpone label and original design are preserved")
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
