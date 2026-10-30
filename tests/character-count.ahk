#Requires AutoHotkey v2.0
OnError TestError
global g_started := false, g_done := false, g_textReady := false, g_locked := false, g_mode := "test"
Assert(CountCorrectChars("alpha beta", "alpha beta") = 10, "perfect text includes correct spaces")
Assert(CountCorrectChars("lpha beta", "alpha beta") = 9, "missing first character does not invalidate the rest")
Assert(CountCorrectChars("alpXa beta", "alpha beta") = 9, "substituted character is not credited")
Assert(CountCorrectChars("alpXha beta", "alpha beta") = 10, "extra character is not credited or allowed to shift the rest")
Assert(CountCorrectChars("alpha omega", "alpha beta gamma delta omega") = 11, "several missing words do not invalidate the continuation")
Assert(CountCorrectChars("one three four", "one two three four") = 14, "one omitted word does not shift following words")
Assert(CountCorrectChars("alpha beta", "alpha beta gamma") = 10, "unfinished text still credits its correct prefix")
Assert(CountCorrectChars("alpha beta XYZ", "alpha beta") = 10, "text outside the captured assignment is not credited")
Assert(CountCorrectChars("alphabeta", "alpha beta") = 9, "missing space does not merge and invalidate correct words")
Assert(CountCorrectChars("alpha  beta", "alpha beta") = 10, "extra spaces cannot inflate progress")
Assert(CountCorrectChars("alpha`r`nbeta", "alpha beta") = 10, "line ending is treated as one separator")
Assert(CountCorrectChars("alpha`tbeta", "alpha beta") = 10, "tab is treated as one separator")
Assert(CountCorrectChars("axcxef", "abcdef") = 4, "correct characters in a word with several errors still count")
Assert(CountCorrectChars("Alpha beta", "alpha beta") = 9, "wrong letter case is an error")
Assert(CountCorrectChars("kůň běží", "kůň běží") = 8, "Czech diacritics count as characters")
Assert(CountCorrectChars("kun", "kůň") = 0, "a short word with mostly wrong diacritics does not pass similarity validation")
Assert(CountCorrectChars("abab", "baba") = 3, "equal-distance alignments prefer the most exact matches")
Assert(CountCorrectChars("alpha alpha alpha", "alpha") = 5, "repetitions cannot credit the same expected characters twice")
Assert(CountCorrectChars("xxxx", "abcd") = 0, "unrelated text has no correct characters")
Assert(CountCorrectChars("", "abcd") = 0 && CountCorrectChars("abcd", "") = 0, "empty text has no correct characters")
Assert(CountCorrectChars("wdnamnmdsnm diojw pibudsácvicčewaní", "dnes budu psát dlouhé cvičení doma") = 0, "reported gibberish receives no credit for accidental letter matches")
Assert(CountCorrectChars("dnes budu doma", "dnes budu psát dlouhé cvičení doma") = 14, "several omitted words still allow correct continuation")
Assert(CountCorrectChars("xxxx yyyy zzzz", "alpha beta gamma") = 0, "spaces between rejected words do not earn points")
Assert(CountCorrectChars("alpha qzxqzx beta", "alpha delta beta") = 10, "unrelated middle word is rejected without invalidating surrounding correct words")
Assert(CountCorrectChars("alphabetagamma", "alpha beta gamma") = 14, "two missing spaces are handled by joining neighboring expected words")
Assert(CountCorrectChars("al ph a beta", "alpha beta") = 10, "extra spaces inside a word do not erase its correct characters")
Assert(CountCorrectChars("al", "alphabetagamma") = 2, "unfinished last word credits its correct beginning")
Assert(CountCorrectChars("alpha be", "alpha beta gamma") = 8, "unfinished final word remains eligible after earlier complete words")
Assert(CountCorrectChars("ab", "zzzzabzzzz") = 0, "short accidental substring inside an unrelated word does not count as a prefix")
Assert(CountCorrectChars("abcxx", "abcde") = 3, "exactly sixty percent word similarity remains eligible")
Assert(CountCorrectChars("abxxx", "abcde") = 0, "word below the similarity threshold receives no credit")
Assert(CountCorrectChars("x", "a") = 0, "wrong single-letter word receives no credit")
Assert(CountCorrectChars("alpha;", "alpha,") = 5, "wrong punctuation does not erase the correctly typed word")
Assert(CountCorrectChars("!!! ???", "alpha beta") = 0, "punctuation and spaces cannot create matches with unrelated words")
Assert(CountCorrectChars(" alXha", " alpha") = 5, "leading spaces only count with a recognized first word")

global g_filterMode := "nospaces", g_filterLetter := "", g_filterRepeat := 1
Assert(CountCorrectChars("alphXbeta", BuildExpected("alpha beta gamma")) = 8, "no-spaces mode still credits an unfinished exercise with a typo")
g_filterMode := "reverse"
Assert(CountCorrectChars("ateb ahpXa", BuildExpected("alpha beta")) = 9, "reversed assignment still uses the same similarity rules")
g_filterMode := "", g_filterRepeat := 2
Assert(CountCorrectChars("alpha alpha beta", BuildExpected("alpha beta")) = 16, "repeated assignments remain aligned after an omitted word")
g_filterRepeat := 1

samples := ["aab ba", "ababa", "b a ab", "aaaaaa", "bbb", "", "a b", "cdef"]
for typed in samples {
    for expected in samples {
        score := CountCorrectChars(typed, expected)
        Assert(score >= 0 && score <= Min(StrLen(typed), StrLen(expected)), "score is bounded by both input lengths")
    }
    Assert(CountCorrectChars(typed, typed) = StrLen(typed), "exact text always receives its complete length")
}

longExpected := ""
loop 100
    longExpected .= "alpha beta "
longTyped := SubStr(longExpected, 2)
started := A_TickCount
Assert(CountCorrectChars(longTyped, longExpected) = StrLen(longTyped), "long repeated exercise preserves the correct text after a leading omission")
FileAppend "1100-character alignment: " . (A_TickCount - started) . " ms`n", "*"

; Optional private regression: typed text, captured assignment, expected score.
if A_Args.Length = 3 {
    typed := A_Args[1], expected := A_Args[2], expectedScore := Integer(A_Args[3])
    Assert(CountCorrectChars(typed, expected) = expectedScore, "reported private exercise has the corrected character count")
    global DONE_DIR := A_ScriptDir . "\..\..\character-count-test-" . DllCall("GetCurrentProcessId")
    DirCreate DONE_DIR
    global SESSION_DAY := FormatTime(, "yyyy-MM-dd"), STATE_FILE := DONE_DIR . "\state.txt"
    global g_weekFile := DONE_DIR . "\week_state.txt", g_weekStartFile := DONE_DIR . "\week_start.txt"
    global g_sourceText := expected, g_typedText := typed, g_overlay := 0, g_log := Map()
    global g_filterMode := "", g_filterLetter := "", g_filterRepeat := 1, g_awaitLetter := ""
    global g_passedCount := 0, g_lastErrors := 0, g_lastCorrectChars := 0, g_lastResult := "", g_done := false
    global g_exerciseNum := 1, g_textReady := true, g_charsAccumulated := 0, g_dailyDone := false, g_evaluating := false
    global g_weeklyChars := 915, g_weeklyDays := 3, g_weeklyDone := false, g_weeklyLastDay := "", g_postponeCount := 0
    global MIN_TEXT_LEN := 10000, WEEKLY_GOAL := 100000, POSTPONE_MAX := 3, g_caret := StrLen(typed), g_anchor := StrLen(typed)
    EvaluateExercise()
    Assert(g_charsAccumulated = expectedScore && g_weeklyChars = 915 + expectedScore, "corrected score enters daily and weekly progress")
    Assert(g_typedText = "" && !g_evaluating, "submitted input is consumed exactly once")
    EvaluateExercise()
    Assert(g_charsAccumulated = expectedScore && g_weeklyChars = 915 + expectedScore, "delayed second submit does not duplicate corrected credit")
    LoadState()
    LoadWeeklyState()
    Assert(g_charsAccumulated = expectedScore && g_weeklyChars = 915 + expectedScore, "corrected daily and weekly progress survives a reload")
    FileAppend "Private regression correct characters: " . expectedScore . "`n", "*"
}
FileAppend "All character count tests passed.`n", "*"
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
