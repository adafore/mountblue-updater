#Requires AutoHotkey v2.0
OnError TestError
global START_HOUR := 0
global g_mode := "practice", g_locked := true, g_done := false, g_passwordOpen := false
global g_inputHook := 0, g_log := Map(), g_focusRetryCount := 0
global g_taskbarShields := Map()

Assert(IsPictureInPictureTitle("Picture in picture"), "English Chrome picture-in-picture title is recognised")
Assert(IsPictureInPictureTitle("Obraz v obraze"), "Czech Chrome picture-in-picture title is recognised")
Assert(IsPictureInPictureTitle("Picture-in-Picture"), "Firefox picture-in-picture title is recognised")
Assert(!IsPictureInPictureTitle("YouTube - Obraz v obraze tutorial"), "ordinary browser tabs are not closed")
Assert(!IsPictureInPictureTitle("Mount Blue"), "ordinary windows are not closed")

Assert(ShouldShieldTaskbar(), "locked practice shields the taskbar")
for mode in ["starting", "confirm", "postponed", "password", "daily_done", "closing", "retry"] {
    g_mode := mode
    Assert(!ShouldShieldTaskbar(), mode . " mode leaves the taskbar usable")
}
g_mode := "practice"
g_locked := false
Assert(!ShouldShieldTaskbar(), "unlocked practice (focus denied) leaves the taskbar usable")
g_locked := true
g_passwordOpen := true
Assert(!ShouldShieldTaskbar(), "password dialog leaves the taskbar usable")
g_passwordOpen := false
g_done := true
Assert(!ShouldShieldTaskbar(), "finished day leaves the taskbar usable")
g_done := false

taskbars := TaskbarWindows()
if taskbars.Length {
    rect := TaskbarShieldRect(taskbars[1])
    Assert(rect && rect.w > 0 && rect.h >= 48, "shield rectangle covers at least a taskbar-sized strip")
    SyncTaskbarShield()
    Assert(g_taskbarShields.Count >= 1, "shield window is created while locked")
    for hwnd, shield in g_taskbarShields
        Assert(DllCall("IsWindowVisible", "ptr", shield.Hwnd), "shield window is visible while locked")
    SetPracticeMode("postponed")
    for hwnd, shield in g_taskbarShields
        Assert(!DllCall("IsWindowVisible", "ptr", shield.Hwnd), "shield disappears when practice mode ends")
    for hwnd, shield in g_taskbarShields
        shield.Destroy()
}

; Nikdy nespouštěj skutečný Spotify z testu.
FindSpotifyWindow()
TopApplicationExe()
Assert(true, "Spotify lookup helpers are harmless")
Assert(IsRestrictedWindowProcess("chrome.exe"), "chrome is restricted during locked practice")
Assert(IsRestrictedWindowProcess("msedge.exe"), "edge is restricted during locked practice")
Assert(IsRestrictedWindowProcess("firefox.exe"), "firefox is restricted during locked practice")
Assert(IsRestrictedWindowProcess("vlc.exe"), "vlc is restricted during locked practice")
Assert(!IsRestrictedWindowProcess("MountBlue.exe"), "MountBlue is never restricted")
Assert(!IsRestrictedWindowProcess("Spotify.exe"), "Spotify is never restricted")
Assert(!IsRestrictedWindowProcess("PowerToys.exe"), "PowerToys is never restricted")
Assert(IsRestrictedWindowProcess("Discord.exe"), "Discord is restricted during locked practice")
Assert(IsRestrictedWindowProcess("RobloxPlayerBeta.exe"), "Roblox is restricted during locked practice")
Assert(IsRestrictedWindowProcess("steam.exe"), "Steam is restricted during locked practice")
Assert(!IsRestrictedWindowProcess("explorer.exe"), "File explorer is allowed during locked practice")
Assert(!IsRestrictedWindowProcess("SystemSettings.exe"), "Settings is allowed during locked practice")

FileAppend "All taskbar shield tests passed.`n", "*"
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
