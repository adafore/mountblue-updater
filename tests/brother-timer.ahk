#Requires AutoHotkey v2.0
OnError TestError

global DONE_DIR := A_ScriptDir . "\..\..\brother-timer-test-" . DllCall("GetCurrentProcessId")
DirCreate DONE_DIR
global SESSION_DAY := FormatTime(, "yyyy-MM-dd")
global STATE_FILE := DONE_DIR . "\state.txt"
global DONE_FILE := DONE_DIR . "\done.txt"
global BROTHER_TIMER_MODE := true
global BROTHER_TIMER_GOAL_SEC := 600
global BROTHER_PENALTY_SEC := 120
global BROTHER_FUEL_PER_CHAR_SEC := 0.70
global BROTHER_FUEL_MAX_SEC := 2.50
global BROTHER_PENALTY_COOLDOWN_MS := 12000
global DEFAULT_DAILY_GOAL := 300, BROTHER_DAILY_GOAL := 500
global DEFAULT_POSTPONE_COUNT := 3, BROTHER_POSTPONE_COUNT := 3
global MIN_TEXT_LEN := 300, WEEKLY_GOAL := 2400, POSTPONE_MAX := 3, POSTPONE_MIN := 30
global OVERLAY_W := 520, START_HOUR := 11

global g_device := Map("role", "normal", "id", "test-id", "folder", "")
global g_log := Map(), g_overlay := 0, g_done := false, g_dailyDone := false, g_weeklyDone := false
global g_weeklyDays := 6, g_weeklyLastDay := "", g_mode := "practice", g_locked := false
global g_postponeCount := 0, g_postponedUntil := 0, g_quickPauseAvailable := true
global g_charsAccumulated := 0, g_exerciseNum := 1, g_typedText := "", g_caret := 0, g_anchor := 0
global g_inputHook := 0, g_btnUnlockGui := 0, g_btnUnlockBorder := 0

global g_timerRemainingSec := BROTHER_TIMER_GOAL_SEC
global g_timerFuelSec := 0.0, g_timerActive := false, g_timerLastTick := 0, g_timerLastSaveTick := 0
global g_timerFocusGainTick := 0, g_timerWasPracticeActive := false
global g_timerPenaltyCount := 0, g_timerHasPenalty := false, g_timerLastPenaltyTick := 0
global g_timerPenaltyBannerUntil := 0, g_timerLastCheatReason := ""
global g_timerBuf := "", g_timerConsecChar := "", g_timerConsecCount := 0, g_timerConsecSpace := 0
global g_timerBigramSet := 0, g_timerKbRowSet := 0
global lbl_timer_clock := 0, lbl_timer_state := 0, lbl_timer_penalty := 0
global lbl_postpone := 0, btn_postpone := 0, lbl_status := 0, btn_spotify := 0, btn_quick_pause := 0
global g_timerUiClockCache := "", g_timerUiStateCache := "", g_timerUiPenaltyCache := ""

; 1. Mode separation & 8x weekly goal
ApplyProfileLimits("normal")
Assert(!IsBrotherTimerMode(), "normal role does not use brother timer mode")
Assert(MIN_TEXT_LEN = 300 && WEEKLY_GOAL = 2400, "normal profile uses 8x weekly goal")
Assert(IsWeeklyRequired(), "normal profile still enforces weekly deadline on day 7")

g_device["role"] := "brother"
Assert(IsBrotherTimerMode(), "brother role enables brother timer mode")
Assert(!IsWeeklyRequired(), "brother timer mode disables weekly requirement")

; 2. Timer pauses when idle and counts smoothly at brother's real typing speed (~0.55s/char)
BrotherTimerResetRuntime()
g_timerRemainingSec := 600.0
g_timerFocusGainTick := 1000
BrotherTimerStep(5.0, true)
Assert(g_timerRemainingSec = 600.0 && !g_timerActive, "timer does not decrement when not typing")

realText := "solil veku i vzniklo to v nouzi letos i loni jekot rozjel role tento rok vedl kroniku televizor i telefon foukl tvrdost osel "
    . "svoje zdroje krotitel neuvedlo loutku do role tlustou i velkou kolos no tvoje role letos outsider konverzuje neloudej se kostru"
t := 5000
elapsed := 0.0
loop Parse realText {
    BrotherTimerOnChar(A_LoopField, t)
    BrotherTimerStep(0.55, true)
    t += 550
    elapsed += 0.55
}
spentReal := 600.0 - g_timerRemainingSec
Assert(g_timerPenaltyCount = 0, "real Czech MountBlue typing triggers zero penalties")
Assert(spentReal >= elapsed * 0.95 && spentReal <= elapsed * 1.01, "real typing at average speed drains timer 1:1 with elapsed time")

; Stopping typing drains at most maxFuel (2.5s) then pauses
beforeIdle := g_timerRemainingSec
BrotherTimerStep(10.0, true)
Assert((beforeIdle - g_timerRemainingSec) <= 2.51 && !g_timerActive, "timer pauses after short buffer when typing stops")

; Slow-tapping 1 key every 2.0s only drains ~0.70s per tap, not 2.0s
BrotherTimerResetRuntime()
g_timerRemainingSec := 600.0
g_timerFocusGainTick := 1000
t := 5000
for ch in StrSplit("kilo kolo osel", "") {
    BrotherTimerOnChar(ch, t)
    BrotherTimerStep(2.0, true)
    t += 2000
}
slowSpent := 600.0 - g_timerRemainingSec
Assert(slowSpent < 11.0 && slowSpent > 8.5, "slow tapping 1 key per 2s only credits ~0.70s per key")

; 3. Anti-cheat tests (+120s penalty each)
TestCheat(sample, label) {
    global g_timerRemainingSec, g_timerPenaltyCount, g_timerFocusGainTick, g_timerFuelSec
    BrotherTimerResetRuntime()
    g_timerRemainingSec := 600.0
    g_timerPenaltyCount := 0
    g_timerFocusGainTick := 1000
    t := 5000
    fuelZeroWhenPenalized := false
    loop Parse sample {
        prevPen := g_timerPenaltyCount
        BrotherTimerOnChar(A_LoopField, t)
        if g_timerPenaltyCount > prevPen && g_timerFuelSec = 0.0
            fuelZeroWhenPenalized := true
        t += 300
    }
    Assert(g_timerPenaltyCount >= 1 && g_timerRemainingSec >= 720.0 && fuelZeroWhenPenalized, label)
}

TestCheat("aaaaaaaaaa", "holding single key adds +2 min penalty")
TestCheat("          ", "spamming spaces adds +2 min penalty")
TestCheat("qwertzuiop", "top keyboard row adds +2 min penalty")
TestCheat("asdfghjkl", "home keyboard row adds +2 min penalty")
TestCheat("yxcvbnm", "bottom keyboard row adds +2 min penalty")
TestCheat("ěščřžýáíé", "Czech number row adds +2 min penalty")
TestCheat("1234567890", "digit row adds +2 min penalty")
TestCheat("ababababab", "2-key alternation adds +2 min penalty")
TestCheat("asdasdasdas", "3-key cycle adds +2 min penalty")
TestCheat("fjdkfjdkfjdk", "4-key cycle adds +2 min penalty")
TestCheat("ahoj ahoj ahoj ahoj", "repeating one word 4x adds +2 min penalty")
TestCheat("ahoj cau ahoj cau ahoj cau", "repeating 2-word pair 3x adds +2 min penalty")
TestCheat("a s d f g h", "single-letter spam adds +2 min penalty")
TestCheat("qsefthuko plijzgrdwa qsefthuko plijzgrdwa", "brother's zigzag cheat adds +2 min penalty")
TestCheat("kjhdfgskjdfh weoriuqwe mnbzxcv lkjhdfg", "random keyboard mash adds +2 min penalty")
TestCheat("pqlamz xnskow djfhei rutgby vncmxz", "random spaced mash adds +2 min penalty")
TestCheat("aeiuo oieua aoeiu uioea aeiuo oieua", "vowel-only mash adds +2 min penalty")
TestCheat("skdfjghlaksdjfhglaksdjfhglaksdjfhg", "long spaceless mash adds +2 min penalty")

; Focus grace (first 1.0s after focus gain): held WASD tail does not unfairly penalize, but gives 0 fuel
BrotherTimerResetRuntime()
g_timerRemainingSec := 600.0
g_timerPenaltyCount := 0
g_timerFocusGainTick := 10000
loop 10
    BrotherTimerOnChar("d", 10000 + A_Index * 30)
Assert(g_timerPenaltyCount = 0 && g_timerRemainingSec = 600.0 && g_timerFuelSec = 0.0, "brief held key right on focus gain gives 0 fuel without unfair penalty")

; Cooldown: second cheat within 12s doesn't stack another +2 min; after 12s it does
BrotherTimerResetRuntime()
g_timerRemainingSec := 600.0
g_timerPenaltyCount := 0
g_timerFocusGainTick := 1000
loop Parse "qwert"
    BrotherTimerOnChar(A_LoopField, 5000 + A_Index * 100)
Assert(g_timerPenaltyCount = 1 && g_timerRemainingSec = 720.0, "first cheat adds +2 min")
loop Parse "asdf"
    BrotherTimerOnChar(A_LoopField, 9000 + A_Index * 100)
Assert(g_timerPenaltyCount = 1 && g_timerRemainingSec = 720.0, "cheat within 12s cooldown does not double-penalize")
loop Parse "yxcv"
    BrotherTimerOnChar(A_LoopField, 20000 + A_Index * 100)
Assert(g_timerPenaltyCount = 2 && g_timerRemainingSec = 840.0, "cheat after 12s cooldown adds another +2 min")

; 4. State persistence survives restart (including penalties)
g_postponeCount := 1
g_timerRemainingSec := 482.3
g_timerPenaltyCount := 2
SaveState()
g_postponeCount := 0
g_timerRemainingSec := 600.0
g_timerPenaltyCount := 0
LoadState()
Assert(g_postponeCount = 1 && g_timerRemainingSec = 483 && g_timerPenaltyCount = 2, "brother timer remaining seconds and penalties survive restart")

; 5. Brother overlay UI omits all old limits, OCR, and shortcuts while preserving postpone, Spotify, and quick-pause
g_overlay := Gui("+ToolWindow -Caption -DPIScale", "Brother timer UI test")
BuildOverlayUI(520, 1080)
UpdateOverlay()
Assert(lbl_timer_clock.Value = "08:03", "brother UI shows formatted remaining time")
Assert(InStr(btn_postpone.Text, "Odložit"), "brother UI keeps postpone button")
Assert(InStr(btn_spotify.Text, "Spotify"), "brother UI keeps Spotify button")
Assert(InStr(btn_quick_pause.Text, "Zastavit") && InStr(btn_quick_pause.Text, "10 s"), "brother UI keeps 10s quick-pause button")
for control in g_overlay {
    txt := ""
    try txt := control.Text
    Assert(!InStr(txt, "Shift+Win+T"), "brother UI omits Shift+Win+T scan hint")
    Assert(!InStr(txt, "KLÁVESOVÉ ZKRATKY"), "brother UI omits shortcuts section")
    Assert(!InStr(txt, "ZADANÝ TEXT"), "brother UI omits source text section")
    Assert(!InStr(txt, "Týden"), "brother UI omits weekly limit")
    Assert(!InStr(txt, "znaků"), "brother UI omits character limit")
    Assert(!InStr(txt, "reset filtru"), "brother UI omits filter shortcuts")
}
g_postponeCount := 0
g_postponedUntil := 0
g_quickPauseAvailable := true
DoQuickPause()
Assert(!g_quickPauseAvailable && g_postponedUntil > 0, "quick pause works in brother timer mode")
SetTimer ShowOverlayAgain, 0
g_postponedUntil := 0
DoPostpone()
Assert(g_quickPauseAvailable && g_postponeCount = 1, "postpone works and resets quick pause in brother timer mode")
SetTimer ShowOverlayAgain, 0
g_postponedUntil := 0

g_overlay.Destroy()
try DirDelete(DONE_DIR, true)
FileAppend "All brother timer tests passed.`n", "*"
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
