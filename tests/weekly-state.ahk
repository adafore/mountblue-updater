#Requires AutoHotkey v2.0
global DONE_DIR := A_ScriptDir . "\..\..\weekly-state-test-" . DllCall("GetCurrentProcessId")
global g_weekFile := DONE_DIR . "\week_state.txt"
global g_weekStartFile := DONE_DIR . "\week_start.txt"
global WEEKLY_GOAL := 3000
global g_weeklyChars := 0, g_weeklyDays := 0, g_weeklyDone := false, g_weeklyLastDay := ""
DirCreate DONE_DIR
WriteTestFile(g_weekStartFile, Chr(0xFEFF) . "20261001`r`n")
InitWeekWindow("20261001120000")
Assert(ReadWeekStart() = "20261001", "start date accepts BOM and newline")
Assert(GetWeeklyDay("20261001120000") = 1, "new period starts on training day 1")

WriteTestFile(DONE_DIR . "\done_2026-10-01.txt", "completed")
g_weeklyChars := 350
InitWeekWindow("20261001120000")
Assert(g_weeklyDays = 1 && GetWeeklyDay("20261001120000") = 1, "first completed daily goal still displays day 1 (count=" . g_weeklyDays . ", last=" . g_weeklyLastDay . ")")
g_weeklyChars += 16
SaveWeeklyState()
InitWeekWindow("20261002120000")
Assert(g_weeklyChars = 366 && g_weeklyDays = 1, "16 characters count without completing the second day")
Assert(GetWeeklyDay("20261002120000") = 2, "unfinished second day displays day 2")

g_weeklyChars := 0, g_weeklyDays := 0, g_weeklyLastDay := ""
LoadWeeklyState()
InitWeekWindow("20261003120000")
Assert(g_weeklyChars = 366 && GetWeeklyDay("20261003120000") = 2, "350 plus 16 survives restart and shows 366 on day 2")
Assert(!IsWeeklyRequired("20261003120000"), "missed day does not trigger weekly deadline")
InitWeekWindow("20261020120000")
Assert(g_weeklyChars = 366 && GetWeeklyDay("20261020120000") = 2, "calendar gaps preserve training day and characters")

g_weeklyChars := 3000
g_weeklyDone := true
InitWeekWindow("20261020120000")
Assert(g_weeklyChars = 3000 && g_weeklyDays = 1, "early weekly completion does not skip remaining daily goals")
Assert(ReadWeekStart() = "20261001", "seven calendar days do not reset an unfinished training period")
g_weeklyChars := 366
g_weeklyDone := false
for day in ["2026-10-03", "2026-10-05", "2026-10-08", "2026-10-11", "2026-10-14"]
    WriteTestFile(DONE_DIR . "\done_" . day . ".txt", "completed")
InitWeekWindow("20261014120000")
Assert(g_weeklyDays = 6 && GetWeeklyDay("20261014120000") = 6, "six completed goals display day 6 on completion day")
Assert(!IsWeeklyRequired("20261014120000"), "sixth completed day still allows daily unlock")
Assert(GetWeeklyDay("20261015120000") = 7 && IsWeeklyRequired("20261015120000"), "next training day requires weekly completion")
InitWeekWindow("20261014120000")
Assert(g_weeklyDays = 6, "restart does not duplicate completed days")

WriteTestFile(DONE_DIR . "\done_2026-10-15.txt", "completed")
InitWeekWindow("20261015120000")
Assert(g_weeklyDays = 7 && g_weeklyChars = 366 && IsWeeklyRequired("20261015120000"), "seventh daily goal retains incomplete weekly progress")
g_weeklyChars := 3000
g_weeklyDone := true
InitWeekWindow("20261015120000")
Assert(g_weeklyChars = 3000 && ReadWeekStart() = "20261001", "same-day restart preserves completed seventh day")
Assert(!IsWeeklyRequired("20261015120000") && IsWeeklyDeadline("20261015120000"), "completed seventh day allows automatic unlock")
InitWeekWindow("20261016120000")
Assert(g_weeklyChars = 0 && g_weeklyDays = 0 && !g_weeklyDone, "next period starts only after seven completed days and weekly goal")
Assert(ReadWeekStart() = "20261016" && GetWeeklyDay("20261016120000") = 1, "next period starts at day 1 on its actual start date")
WriteTestFile(DONE_DIR . "\done_2026-10-16.txt", "completed")
g_weeklyChars := 350
InitWeekWindow("20261016120000")
Assert(g_weeklyDays = 1 && g_weeklyChars = 350, "previous period daily records do not enter new period")
FileAppend "All weekly state tests passed.`n", "*"
ExitApp

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
