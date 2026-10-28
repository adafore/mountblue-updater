#Requires AutoHotkey v2.0
OnError TestError
global APP_PATH := A_ScriptFullPath, START_HOUR := 0
global g_mode := "practice", g_done := false, g_overlay := 0, g_inputHook := 0, g_log := Map()
global g_activationFailure := "", g_focusRetryCount := 0, g_watchWindowBusy := false, g_startAttemptBusy := false
global g_locked := true, g_retryGui := 0
global scenario := Map()

ResetScenario()
Assert(ActivateMountBlue(1), "main MountBlue window activates successfully")
Assert(g_activationFailure = "" && scenario["maximized"] = 1, "only the main window is maximized")
ResetScenario()
scenario["activateTo"] := 77
Assert(ActivateMountBlue(1), "MountBlue modal dialog counts as a successful activation")
Assert(scenario["maximized"] = 0, "modal dialog is never maximized")
ResetScenario()
scenario["maximizeThrows"] := true
Assert(ActivateMountBlue(1), "unsupported maximize does not turn successful focus into startup failure")

ResetScenario()
scenario["activateTo"] := 0
Assert(!ActivateMountBlue(1) && g_activationFailure = "focus_denied", "foreground restriction is distinguished from a launch failure")
loop 8
    WatchWindow()
Assert(g_mode = "practice" && !IsObject(g_retryGui), "repeated focus restrictions do not show a false startup error")
Assert(!g_locked && g_focusRetryCount = 8, "PC stays usable while focus retries continue")
Assert(!g_watchWindowBusy, "watchdog reentry guard is released after failures")
scenario["activateTo"] := 42
WatchWindow()
Assert(g_locked && g_focusRetryCount = 0 && g_mode = "practice", "watchdog automatically recovers focus without a retry button")

ResetScenario()
scenario["activateTo"] := 0
scenario["active"] := 77
WatchWindow()
Assert(scenario["activations"] = 0 && g_locked, "already active MountBlue popup is left alone")
ResetScenario()
scenario["activeExe"] := "PowerToys.PowerOCR.exe"
WatchWindow()
Assert(scenario["activations"] = 0, "OCR remains an allowed temporary foreground application")
SetPracticeMode("confirm")
WatchWindow()
Assert(scenario["activations"] = 0, "confirmation dialog is not interrupted by focus retries")
SetPracticeMode("daily_done")
WatchWindow()
Assert(scenario["activations"] = 0, "unlock state is not interrupted by focus retries")

ResetScenario()
scenario["reenter"] := true
WatchWindow()
Assert(scenario["activations"] = 1, "watchdog cannot reenter while an activation is waiting")
ResetScenario()
scenario["changeMode"] := "postponed"
WatchWindow()
Assert(g_mode = "postponed" && !g_locked && !IsObject(g_retryGui), "postponement during activation is not undone or reported as a startup error")
ResetScenario()
scenario["changeMode"] := "postponed"
TryStartPractice()
Assert(g_mode = "postponed" && !g_startAttemptBusy && !g_locked, "startup respects postponement requested while waiting")
ResetScenario()
g_startAttemptBusy := true
TryStartPractice()
Assert(scenario["activations"] = 0, "double-clicked retry cannot start overlapping attempts")
g_startAttemptBusy := false

ResetScenario()
scenario["running"] := false
APP_PATH := A_ScriptDir . "\nonexistent-mountblue.exe"
Assert(!ActivateMountBlue(1) && g_activationFailure = "missing_executable", "missing executable has its own diagnostic reason")
APP_PATH := A_ScriptFullPath
scenario["launchThrows"] := true
Assert(!ActivateMountBlue(1) && g_activationFailure = "launch_failed", "Windows launch error has its own diagnostic reason")
ResetScenario()
scenario["windows"] := []
Assert(!ActivateMountBlue(2) && g_activationFailure = "window_missing", "running process without a window is reported separately")
Assert(StartupFailureMessage("focus_denied") != StartupFailureMessage("window_missing"), "visible retry message explains the actual failure type")
FileAppend "All startup and focus tests passed.`n", "*"
ExitApp

ResetScenario() {
    global scenario, g_mode, g_locked, g_done, g_focusRetryCount, g_activationFailure, g_watchWindowBusy
    scenario := Map("running", true, "windows", [42], "active", 0, "activeExe", "notepad.exe", "activateTo", 42,
        "activations", 0, "maximized", 0, "maximizeThrows", false, "launchThrows", false, "reenter", false, "changeMode", "")
    g_mode := "practice", g_locked := false, g_done := false, g_focusRetryCount := 0, g_activationFailure := "", g_watchWindowBusy := false
}

ProcessExist(*) {
    global scenario
    return scenario["running"] ? 123 : 0
}

WinGetList(*) {
    global scenario
    return scenario["windows"]
}

WinGetPos(&x, &y, &width, &height, *) {
    x := 0, y := 0, width := 1200, height := 800
}

WinGetMinMax(*) {
    return 0
}

WinActivate(*) {
    global scenario
    scenario["activations"]++
    scenario["active"] := scenario["activateTo"]
}

WinWaitActive(*) {
    global scenario, g_mode
    if scenario["reenter"]
        WatchWindow()
    if scenario["changeMode"] != "" {
        g_mode := scenario["changeMode"]
        LockInput(false)
    }
    return scenario["active"] = 42 ? 42 : 0
}

WinActive(*) {
    global scenario
    return scenario["active"]
}

WinMaximize(*) {
    global scenario
    if scenario["maximizeThrows"]
        throw Error("Window does not support maximizing")
    scenario["maximized"]++
}

WinGetPID(*) {
    return 123
}

ProcessGetName(*) {
    global scenario
    return scenario["active"] ? "MountBlue.exe" : scenario["activeExe"]
}

Run(*) {
    global scenario
    if scenario["launchThrows"]
        throw Error("Launch denied")
}

Sleep(*) {
}

BlockInput(*) {
}

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
