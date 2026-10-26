#Requires AutoHotkey v2.0
global DONE_DIR := A_ScriptDir . "\..\..\device-log-test-" . DllCall("GetCurrentProcessId")
global DEFAULT_DAILY_GOAL := 250, BROTHER_DAILY_GOAL := 300, MIN_TEXT_LEN := 250, WEEKLY_GOAL := 2500
global g_device := Map(), g_log := Map(), lbl_log := 0, g_overlay := 0
global g_typedText := "", g_caret := 0, g_anchor := 0
DirCreate DONE_DIR
InitDeviceConfig()
firstId := g_device["id"]
Assert(MIN_TEXT_LEN = 250 && WEEKLY_GOAL = 2500, "new installations use the normal profile")
InitDeviceConfig()
Assert(g_device["id"] = firstId, "installation ID survives a restart")
shared := DONE_DIR . "\shared-offline"
SaveDeviceConfig("brother", shared)
InitDeviceConfig()
Assert(MIN_TEXT_LEN = 300 && WEEKLY_GOAL = 3000, "paired brother profile has 300 daily and 3000 weekly")
Assert(g_device["id"] = firstId && g_device["folder"] = shared, "updates preserve identity and selected folder")
IniWrite "different-device", g_device["path"], "Device", "Binding"
IniWrite "brother-shared-v1", g_device["path"], "Device", "AutomaticSetup"
InitDeviceConfig()
Assert(g_device["role"] = "normal" && g_device["id"] != firstId && g_device["folder"] = "", "copied settings cannot assign brother profile or sharing to another device")
Assert(g_device["autoSetup"] = "", "copied settings discard the automatic setup marker")
SaveDeviceConfig("brother", shared)
DEFAULT_DAILY_GOAL := 275
BROTHER_DAILY_GOAL := 325
ApplyProfileLimits("normal")
Assert(MIN_TEXT_LEN = 275 && WEEKLY_GOAL = 2750, "normal weekly goal follows daily times ten")
ApplyProfileLimits("brother")
Assert(MIN_TEXT_LEN = 325 && WEEKLY_GOAL = 3250, "brother weekly goal follows daily times ten")
InitPracticeLogs()
RecordPracticeText("Příliš žluťoučký")
EditPracticeBuffer(8)
RecordPracticeText("ý")
Assert(g_typedText = "Příliš žluťoučký", "Czech text and backspace are preserved")
EditPracticeBuffer(0x24)
RecordPracticeText("A ")
Assert(g_typedText = "A Příliš žluťoučký", "insertion follows caret position")
EditPracticeBuffer(0x41, true)
RecordPracticeText("Nový text`nDruhý řádek", "paste")
Assert(g_typedText = "Nový text`nDruhý řádek", "paste replaces the selected text")
FlushPracticeLogs()
base := g_log["base"]
Assert(FileExist(base . ".txt") && FileExist(base . ".jsonl"), "readable and structured logs are saved locally")
Assert(InStr(FileRead(base . ".txt", "UTF-8"), "Nový text`nDruhý řádek"), "unfinished text is included in the readable report")
Assert(InStr(FileRead(base . ".jsonl", "UTF-8"), '"event":"backspace"'), "deleted characters remain in the edit trail")
Assert(InStr(FileRead(base . ".txt", "UTF-8"), "<Backspace: ý>"), "readable report also preserves deleted characters")
SyncSharedLogs()
Assert(FileExist(base . ".pending"), "offline sharing leaves a durable pending upload")
DirCreate shared
SyncSharedLogs()
relative := SubStr(base, StrLen(g_log["root"]) + 2)
destination := shared . "\" . g_device["id"] . "\" . relative
Assert(FileExist(destination . ".txt") && FileExist(destination . ".jsonl"), "pending logs are copied once the shared folder is available: " . g_log.Get("error", ""))
Assert(!FileExist(base . ".pending"), "successful sharing clears the pending marker")
Assert(FileRead(base . ".txt", "UTF-8") = FileRead(destination . ".txt", "UTF-8"), "shared readable report matches local report")
LogSubmission("Chybný pokus", "Správný pokus", 5, 2)
Assert(InStr(FileRead(base . ".txt", "UTF-8"), "Chybný pokus"), "every submitted attempt is included")
QueuePracticeEvent("insert", 'uvozovky " a zpětné lomítko \ a nový řádek`n')
FlushPracticeLogs()
SyncSharedLogs()
Assert(InStr(FileRead(destination . ".txt", "UTF-8"), "Chybný pokus"), "later attempts update the shared report")
global g_started := false, g_done := false, g_mode := "practice", g_passwordOpen := false, g_postponedUntil := 0
previousText := g_typedText
PracticeChar(0, "outside-app-secret")
Assert(g_typedText = previousText, "inactive program does not record characters")
g_started := true
g_passwordOpen := true
PracticeChar(0, "password-secret")
Assert(g_typedText = previousText, "password dialogs do not record characters")
FileAppend "JSON_PATH=" . base . ".jsonl`n", "*"
FileAppend "All device and logging tests passed.`n", "*"
ExitApp

Assert(condition, label) {
    FileAppend (condition ? "PASS: " : "FAILED: ") . label . "`n", "*"
    if !condition
        ExitApp 1
}

#Include ..\PovinePsani.ahk
