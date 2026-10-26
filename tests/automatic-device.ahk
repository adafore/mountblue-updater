#Requires AutoHotkey v2.0
OnError TestError
global DONE_DIR := A_ScriptDir . "\..\..\automatic-device-test-" . DllCall("GetCurrentProcessId")
global DEFAULT_DAILY_GOAL := 250, BROTHER_DAILY_GOAL := 300, MIN_TEXT_LEN := 250, WEEKLY_GOAL := 2500
global g_device := Map(), g_log := Map(), g_typedText := ""
DirCreate DONE_DIR
Assert(DeviceBindingFingerprint("ABC") = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "fingerprint is normalized UTF-8 SHA-256 without a trailing null")
unknown := NewDevice("different-pc|different-user")
Assert(!ApplyAutomaticDeviceConfig(unknown), "an unrelated Windows account is not configured automatically")
Assert(unknown["role"] = "normal" && unknown["folder"] = "" && unknown["autoSetup"] = "", "unrelated account settings remain unchanged")

; Supply the private binding at test time; never publish it in a fixture.
if A_Args.Length {
    binding := A_Args[1]
    g_device := NewDevice(binding)
    SaveDeviceConfig("normal", "")
    originalId := g_device["id"]
    InitPracticeLogs()
    QueuePracticeEvent("insert", "existing unsynced practice")
    FlushPracticeLogs()
    base := g_log["base"]
    originalProfile := EnvGet("USERPROFILE")
    EnvSet "USERPROFILE", DONE_DIR . "\profile"
    try {
        Assert(ApplyAutomaticDeviceConfig(g_device), "the supplied known Windows account is configured automatically")
        expectedFolder := DONE_DIR . "\profile\OneDrive\Attachments\OneNote"
        Assert(g_device["folder"] = expectedFolder, "shared folder resolves within the matched user's Windows profile")
        Assert(!DirExist(expectedFolder), "unavailable shared folder is not created as a replacement")
    } finally {
        EnvSet "USERPROFILE", originalProfile
    }
    SaveDeviceConfig(g_device["role"], g_device["folder"])
    ApplyProfileLimits(g_device["role"])
    Assert(MIN_TEXT_LEN = 300 && WEEKLY_GOAL = 3000, "automatic profile applies 300 daily and 3000 weekly")
    Assert(g_device["id"] = originalId, "automatic configuration preserves installation ID and log root")
    Assert(IniRead(g_device["path"], "Device", "AutomaticSetup") = "brother-shared-v1", "one-time migration marker is persisted")
    Assert(!ApplyAutomaticDeviceConfig(g_device), "repeated startup does not repeat the migration")
    SyncSharedLogs()
    Assert(FileExist(base . ".pending"), "previous practice logs remain pending while the shared folder is unavailable")
    DirCreate expectedFolder
    SyncSharedLogs()
    relative := SubStr(base, StrLen(g_log["root"]) + 2)
    destination := expectedFolder . "\" . originalId . "\" . relative . ".txt"
    Assert(FileExist(destination) && !FileExist(base . ".pending"), "previously pending logs reach the automatically selected folder")
    Assert(FileRead(destination, "UTF-8") = FileRead(base . ".txt", "UTF-8"), "automatic sharing keeps the complete existing report")
    SaveDeviceConfig("normal", "")
    g_device["autoSetup"] := IniRead(g_device["path"], "Device", "AutomaticSetup")
    Assert(!ApplyAutomaticDeviceConfig(g_device) && g_device["role"] = "normal" && g_device["folder"] = "", "later manual profile changes and disabled sharing are respected")
    custom := NewDevice(binding)
    custom["folder"] := DONE_DIR . "\custom-share"
    Assert(ApplyAutomaticDeviceConfig(custom) && custom["folder"] = DONE_DIR . "\custom-share", "an existing selected shared folder is preserved")
    anotherUser := NewDevice(RegExReplace(binding, "-\d+$", "-9999"))
    anotherUser["id"] := originalId
    Assert(!ApplyAutomaticDeviceConfig(anotherUser), "copied installation ID does not match another Windows account")
    anotherPC := NewDevice(NewIdentifier() . SubStr(binding, InStr(binding, "|")))
    anotherPC["id"] := originalId
    Assert(!ApplyAutomaticDeviceConfig(anotherPC), "same user SID on a different computer does not match")
    reinstalled := NewDevice(StrUpper(binding))
    Assert(ApplyAutomaticDeviceConfig(reinstalled), "known computer still matches after reinstall or case changes")
} else {
    FileAppend "SKIP: targeted account tests require the private binding as an argument.`n", "*"
}
FileAppend "All automatic device configuration tests passed.`n", "*"
ExitApp

NewDevice(binding) {
    global DONE_DIR
    return Map("path", DONE_DIR . "\device.ini", "binding", binding, "id", NewIdentifier(), "role", "normal", "folder", "", "autoSetup", "")
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
