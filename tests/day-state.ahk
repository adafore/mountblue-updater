#Requires AutoHotkey v2.0
global DONE_DIR := A_ScriptDir . "\..\..\daily-state-test-" . DllCall("GetCurrentProcessId")
global SESSION_DAY := "", STATE_FILE := "", DONE_FILE := ""
global g_weekFile := DONE_DIR . "\week_state.txt", g_weekStartFile := DONE_DIR . "\week_start.txt"
global POSTPONE_MAX := 3, POSTPONE_MIN := 30, WEEKLY_GOAL := 2500
global g_postponeCount := 0, g_postponedUntil := 0, g_charsAccumulated := 0, g_exerciseNum := 1
global g_weeklyChars := 366, g_weeklyDays := 1, g_weeklyDone := false, g_weeklyLastDay := "20261015"
global g_overlay := 0, g_done := false
global reloadCalls := 0, lastInputMode := "", timerChecked := false
DirCreate DONE_DIR
WriteTestFile(g_weekStartFile, "20261015")
WriteTestFile(DONE_DIR . "\done_2026-10-15.txt", "completed")
SetDayFiles("20261016120000")
LoadState()
Assert(g_postponeCount = 0 && g_charsAccumulated = 0, "new day without a state file starts with zero postponements and characters")
g_postponeCount := 3, g_charsAccumulated := 123, g_exerciseNum := 4
SaveState()
SaveWeeklyState()
oldStateFile := STATE_FILE
Assert(!CheckDateChange("20261016235959") && reloadCalls = 0, "same date does not reload")
Assert(IsNewDay("20261017000000"), "midnight is detected")
Assert(IsNewDay("20261105120000"), "wake after several days is detected")
Assert(CheckDateChange("20261017000000") && reloadCalls = 1 && lastInputMode = "Off", "date change saves state and requests an unlocked reload")
Assert(STATE_FILE = oldStateFile && FileExist(oldStateFile), "rollover saves yesterday before selecting new paths")

SetDayFiles("20261017120000")
LoadState()
LoadWeeklyState()
InitWeekWindow("20261017120000")
Assert(g_postponeCount = 0 && g_charsAccumulated = 0 && g_exerciseNum = 1, "yesterday's three postponements do not carry over")
Assert(g_weeklyChars = 366 && GetWeeklyDay("20261017120000") = 2, "weekly characters and unfinished training day survive rollover")
oldLines := StrSplit(FileRead(oldStateFile), "`n")
Assert(Integer(oldLines[1]) = 3 && Integer(oldLines[2]) = 123, "yesterday's usage and progress remain in yesterday's file")
g_postponeCount := 1
SaveState()
g_postponeCount := 0
LoadState()
Assert(g_postponeCount = 1, "same-day restart retains actual postponement usage")
g_postponeCount := 3
SaveState()
LoadState()
Assert(g_postponeCount = 3, "same-day restart does not grant extra postponements")

Suspend true
SetTimer SuspendedDateCheck, -10
Sleep 100
Suspend false
Assert(timerChecked && reloadCalls = 2, "date check runs even while hotkeys are suspended during postponement")
SetDayFiles(A_Now)
g_postponeCount := 0
g_postponedUntil := 0
DoPostpone()
Assert(g_postponeCount = 1 && g_postponedUntil > 0, "one postponement consumes one use")
DoPostpone()
Assert(g_postponeCount = 1, "repeat callback during postponement does not consume another use")
SetTimer ShowOverlayAgain, 0
Suspend false
Assert(!FileExist(STATE_FILE . ".tmp") && !FileExist(g_weekFile . ".tmp"), "completed saves leave no temporary state files")
POSTPONE_MAX := 2
g_postponedUntil := 0
g_postponeCount := 1
DoPostpone()
Assert(g_postponeCount = 2 && g_postponedUntil > 0, "brother's second postponement is allowed")
SetTimer ShowOverlayAgain, 0
Suspend false
g_postponedUntil := 0
DoPostpone()
Assert(g_postponeCount = 2 && g_postponedUntil = 0, "brother cannot take a third postponement")
g_postponeCount := 3
SaveState()
LoadState()
Assert(g_postponeCount = 2, "older three-use state remains exhausted under brother's new limit")
FileAppend "All daily state tests passed.`n", "*"
ExitApp

SuspendedDateCheck() {
    global timerChecked
    timerChecked := CheckDateChange("20261018000000")
}

Reload() {
    global reloadCalls
    reloadCalls++
}

BlockInput(mode) {
    global lastInputMode
    lastInputMode := mode
}

Assert(condition, label) {
    FileAppend (condition ? "PASS: " : "FAILED: ") . label . "`n", "*"
    if !condition
        ExitApp 1
}

WriteTestFile(path, value) {
    file := FileOpen(path, "w", "UTF-8")
    file.Write(value)
    file.Close()
}

#Include ..\PovinePsani.ahk
