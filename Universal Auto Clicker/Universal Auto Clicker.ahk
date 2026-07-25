#Requires AutoHotkey v2.0
#SingleInstance Force

; ========================================
; =        Author : muhamdazkaa          =
; =    github : <github/muhamdazkaa>     =
; =            MIT License               =
; ========================================


SetControlDelay -1
SetKeyDelay 50, 50

; ── Global Variables ────────────────────────────────────────────────────────
global TargetHWND          := 0
global ActionQueue         := []
global IsRunning           := false
global IsLooping           := false
global CurrentlyHiddenHWND := 0
global SelectedHK          := ""
global HWNDList            := []
global PickedX             := 0
global PickedY             := 0

; Capture the foreground window BEFORE anything else runs
global PrevActiveHWND := 0
try PrevActiveHWND := WinGetID("A")

; ==========================================
; SYSTEM THEME DETECTION
; ==========================================
IsDarkMode() {
    try {
        val := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
        return (val == 0)
    } catch {
        return true
    }
}

darkMode := IsDarkMode()

if (darkMode) {
    clrBG      := "202020"
    clrControl := "323130"
    clrListBG  := "252423"
    clrFont    := "E9E8E8"
    clrSub     := "B3B0AD"
    clrBorder  := "3D3D3D"
} else {
    clrBG      := "F3F2F1"
    clrControl := "EDEBE9"
    clrListBG  := "FAF9F8"
    clrFont    := "323130"
    clrSub     := "605E5C"
    clrBorder  := "E1DFDD"
}

; ==========================================
; BUILD WINDOW LIST — mirrors the Windows Alt+Tab algorithm
; Reference: https://devblogs.microsoft.com/oldnewthing/20071008-00/?p=24863
; ==========================================
BuildWindowList() {
    global HWNDList
    HWNDList := []
    winList  := []
    Sleep(300)
    DetectHiddenWindows False
    WinIDs := WinGetList()
    for id in WinIDs {
        title := WinGetTitle(id)
        if (title == "" || title == "Program Manager")
            continue
        exStyle := WinGetExStyle("ahk_id " id)
        if ((exStyle & 0x80) && !(exStyle & 0x40000))
            continue
        winList.Push(title " [" id "]")
        HWNDList.Push(id)
    }
    DetectHiddenWindows True
    return winList
}

WinList := BuildWindowList()


MyGui := Gui("-Resize -MaximizeBox -MinimizeBox", "Auto Click Universal")
MyGui.BackColor := clrBG
MyGui.SetFont("s9 c" clrFont, "Segoe UI")

; ── 1. TARGET WINDOW ────────────────────────────────────────────────────────
MyGui.SetFont("s9 c" clrSub, "Segoe UI")
MyGui.Add("Text", "xm y12 w416", "1. TARGET WINDOW")
MyGui.SetFont("s9 c" clrFont, "Segoe UI")

ddlWin := MyGui.Add("DropDownList", "xm y30 w384 r8 vSelectedWindow Background" clrControl " Choose1", WinList)
ddlWin.OnEvent("Change", OnWindowSelect)
btnRefresh := MyGui.Add("Button", "x398 y30 w30 h24", "↺")
btnRefresh.OnEvent("Click", RefreshWindowList)


defaultIdx := 1
for idx, id in HWNDList {
    if (id == PrevActiveHWND) {
        defaultIdx := idx
        break
    }
}
ddlWin.Choose(defaultIdx)
TargetHWND := HWNDList.Length ? HWNDList[defaultIdx] : 0

chkHide := MyGui.Add("CheckBox", "xm y62 vHideWindow c" clrFont, "Hide window from screen while running")
chkHide.OnEvent("Click", ToggleHide)

; ── Divider ──────────────────────────────────────────────────────────────────
MyGui.Add("Text", "xm y90 w416 h1 Background" clrBorder, "")

; ── 2. ADD ACTION ───────────────────────────────────────────────────────────
MyGui.SetFont("s9 c" clrSub, "Segoe UI")
MyGui.Add("Text", "xm y98 w416", "2. ADD ACTION")
MyGui.SetFont("s9 c" clrFont, "Segoe UI")

MyGui.Add("Text", "xm y116 w106 h24 +0x200", "Step A — Coord:")
btnPick  := MyGui.Add("Button", "x118 y116 w140 h24", "Pick Coordinate  [Click]")
btnPick.OnEvent("Click", PickCoord)
txtCoord := MyGui.Add("Text", "x268 y120 w160 vCoordDisplay c" clrSub, "X: —   Y: —")

MyGui.Add("Text", "xm y148 w416 c" clrSub, "Step B — Action type:")

radClick := MyGui.Add("Radio", "xm y166 w110 h22 vActionType Checked c" clrFont, "Mouse Click")
radKey   := MyGui.Add("Radio", "xm y192 w110 h22 c" clrFont, "Keyboard / Send")

ddlMouseBtn := MyGui.Add("DropDownList", "x120 y163 w90 h22 vMouseButton Background" clrControl " Choose1", ["Left", "Right", "Middle"])
txtInput    := MyGui.Add("Edit",         "x120 y189 w296 h22 vKeyInput Background" clrControl, "")

MyGui.Add("Text", "xm y220 w128 h22 +0x200 c" clrSub, "Sleep after action (ms):")
numSleep := MyGui.Add("Edit", "x138 y220 w70 h22 vSleepMs Background" clrControl, "300")
MyGui.Add("UpDown", "Range1-99999", 300)

btnAdd := MyGui.Add("Button", "xm y250 w416 h28", "+ Add Action to Queue")
btnAdd.OnEvent("Click", AddAction)

; ── Divider ──────────────────────────────────────────────────────────────────
MyGui.Add("Text", "xm y286 w416 h1 Background" clrBorder, "")

; ── 3. ACTION QUEUE ─────────────────────────────────────────────────────────
MyGui.SetFont("s9 c" clrSub, "Segoe UI")
MyGui.Add("Text", "xm y294 w416", "3. ACTION QUEUE")
MyGui.SetFont("s9 c" clrFont, "Segoe UI")

lvActions := MyGui.Add("ListView", "xm y310 w416 h130 Background" clrListBG " c" clrFont " NoSortHdr", ["#", "Type", "Detail", "Sleep (ms)"])
lvActions.ModifyCol(1, 26)
lvActions.ModifyCol(2, 88)
lvActions.ModifyCol(3, 214)
lvActions.ModifyCol(4, 80)
lvActions.OnEvent("Click", OnQueueClick)

MyGui.SetFont("s9 c" clrSub, "Segoe UI")
MyGui.Add("Text", "xm y448 w136 h24 +0x200", "Edit sleep for selected:")
MyGui.SetFont("s9 c" clrFont, "Segoe UI")
edtEditSleep   := MyGui.Add("Edit",   "x146 y448 w70 h24 vEditSleep Background" clrControl, "")
MyGui.Add("UpDown", "Range1-99999", 300)
btnUpdateSleep := MyGui.Add("Button", "x226 y448 w90 h24", "Update Sleep")
btnUpdateSleep.OnEvent("Click", UpdateSleep)

btnDel   := MyGui.Add("Button", "xm y480 w203 h24", "Remove Selected")
btnClear := MyGui.Add("Button", "x223 y480 w203 h24", "Clear All")
btnDel.OnEvent("Click", DeleteAction)
btnClear.OnEvent("Click", ClearActions)

; ── Divider ──────────────────────────────────────────────────────────────────
MyGui.Add("Text", "xm y512 w416 h1 Background" clrBorder, "")

; ── 4. TRIGGER HOTKEY ───────────────────────────────────────────────────────
MyGui.SetFont("s9 c" clrSub, "Segoe UI")
MyGui.Add("Text", "xm y520 w416", "4. TRIGGER HOTKEY")
MyGui.SetFont("s9 c" clrFont, "Segoe UI")

MyGui.Add("Text", "xm y538 w146 h24 +0x200", "Press a key combination:")
hkCtrl := MyGui.Add("Hotkey", "x156 y538 w160 h24 vTriggerKey", "")

; ── LOOP OPTION ──────────────────────────────────────────────────────────────
chkLoop := MyGui.Add("CheckBox", "xm y566 vLoopEnabled c" clrFont, "Loop")
chkLoop.Value := 1
MyGui.Add("Text", "x64 y566 w110 h22 +0x200 c" clrSub, "Interval between loops:")
edtInterval := MyGui.Add("Edit", "x184 y564 w70 h22 vLoopInterval Background" clrControl, "500")
MyGui.Add("UpDown", "Range0-99999", 500)
MyGui.Add("Text", "x260 y566 w30 h22 +0x200 c" clrSub, "ms")

; ── START / STOP ─────────────────────────────────────────────────────────────
btnToggle := MyGui.Add("Button", "xm y594 w416 h36", "START  —  Activate Hotkey")
btnToggle.OnEvent("Click", ToggleStart)

MyGui.OnEvent("Close", OnGuiClose)
MyGui.Show("w440 h644")

; ==========================================
; FUNCTIONS
; ==========================================

RefreshWindowList(*) {
    global TargetHWND, HWNDList, CurrentlyHiddenHWND, PrevActiveHWND
    prevHWND := TargetHWND
    newList  := BuildWindowList()
    ddlWin.Delete()
    ddlWin.Add(newList)

    foundIdx := 0
    for idx, id in HWNDList {
        if (id == prevHWND) {
            foundIdx := idx
            break
        }
    }

    if (!foundIdx) {
        for idx, id in HWNDList {
            if (id == PrevActiveHWND) {
                foundIdx := idx
                break
            }
        }
    }

    if (!foundIdx)
        foundIdx := 1

    ddlWin.Choose(foundIdx)
    TargetHWND := HWNDList.Length ? HWNDList[foundIdx] : 0


    if (CurrentlyHiddenHWND && !WinExist("ahk_id " CurrentlyHiddenHWND)) {
        CurrentlyHiddenHWND := 0
        chkHide.Value := 0
    }
}

OnWindowSelect(ctrl, *) {
    global TargetHWND, HWNDList, CurrentlyHiddenHWND
    if (CurrentlyHiddenHWND && CurrentlyHiddenHWND != HWNDList[ctrl.Value]) {
        if WinExist("ahk_id " CurrentlyHiddenHWND)
            WinShow("ahk_id " CurrentlyHiddenHWND)
        CurrentlyHiddenHWND := 0
        chkHide.Value := 0
    }
    TargetHWND := HWNDList[ctrl.Value]
}

ToggleHide(ctrl, *) {
    global TargetHWND, CurrentlyHiddenHWND
    if !TargetHWND
        return
    if (ctrl.Value) {
        WinHide("ahk_id " TargetHWND)
        CurrentlyHiddenHWND := TargetHWND
    } else {
        WinShow("ahk_id " TargetHWND)
        CurrentlyHiddenHWND := 0
    }
}

PickCoord(*) {
    global TargetHWND, PickedX, PickedY
    if !TargetHWND {
        MsgBox("Please select a target window first.", "Error", "Icon!")
        return
    }
    wasHidden := chkHide.Value
    if (wasHidden) {
        WinShow("ahk_id " TargetHWND)
        Sleep(200)
    }
    WinActivate("ahk_id " TargetHWND)
    ToolTip("Click on the target position...")
    KeyWait("LButton", "D")
    CoordMode("Mouse", "Client")
    MouseGetPos(&mX, &mY, &winUnder)
    ToolTip()
    if (winUnder != TargetHWND) {
        MsgBox("Click was outside the target window. Try again.", "Warning", "Icon!")
        if (wasHidden)
            WinHide("ahk_id " TargetHWND)
        return
    }
    PickedX := mX
    PickedY := mY
    txtCoord.Value := "X: " mX "   Y: " mY
    if (wasHidden)
        WinHide("ahk_id " TargetHWND)
}

AddAction(*) {
    saved    := MyGui.Submit(0)
    sleepVal := Trim(saved.SleepMs)
    if (!IsInteger(sleepVal) || Integer(sleepVal) < 1)
        sleepVal := "300"

    rowNum := ActionQueue.Length + 1

    if (saved.ActionType == 1) {
        if (PickedX == 0 && PickedY == 0) {
            MsgBox("Pick a coordinate first using 'Pick Coordinate [F3]'.", "Warning", "Icon!")
            return
        }
        btnLabels := ["Left", "Right", "Middle"]
        mouseBtn  := btnLabels[ddlMouseBtn.Value]
        ActionQueue.Push({Type: "Click", X: PickedX, Y: PickedY, Button: mouseBtn, Sleep: Integer(sleepVal)})
        lvActions.Add("", rowNum, mouseBtn " Click", "X: " PickedX "   Y: " PickedY, sleepVal)
    } else {
        if (Trim(saved.KeyInput) == "") {
            MsgBox("Enter a valid keyboard input.", "Warning", "Icon!")
            return
        }
        ActionQueue.Push({Type: "Key", Key: saved.KeyInput, Sleep: Integer(sleepVal)})
        lvActions.Add("", rowNum, "Keyboard", saved.KeyInput, sleepVal)
    }
}

OnQueueClick(ctrl, rowNum, *) {
    if (rowNum < 1)
        return
    edtEditSleep.Value := ActionQueue[rowNum].Sleep
}

UpdateSleep(*) {
    row := lvActions.GetNext(0, "Focused")
    if (!row) {
        MsgBox("Select a row in the queue first.", "Info", "Icon!")
        return
    }
    saved    := MyGui.Submit(0)
    newSleep := Trim(saved.EditSleep)
    if (!IsInteger(newSleep) || Integer(newSleep) < 1) {
        MsgBox("Enter a valid sleep value (ms).", "Warning", "Icon!")
        return
    }
    ActionQueue[row].Sleep := Integer(newSleep)
    lvActions.Modify(row, , , , , newSleep)
}

DeleteAction(*) {
    row := lvActions.GetNext(0, "Focused")
    if (!row) {
        MsgBox("Select an action from the queue first.", "Info", "Icon!")
        return
    }
    lvActions.Delete(row)
    ActionQueue.RemoveAt(row)
    loop lvActions.GetCount()
        lvActions.Modify(A_Index, , A_Index)
}

ClearActions(*) {
    lvActions.Delete()
    ActionQueue := []
}

ToggleStart(*) {
    global IsRunning, IsLooping, SelectedHK
    saved := MyGui.Submit(0)
    if (!IsRunning) {
        if (saved.TriggerKey == "") {
            MsgBox("Please set a trigger hotkey first.", "Warning", "Icon!")
            return
        }
        if (ActionQueue.Length == 0) {
            MsgBox("The action queue is empty. Add at least one action.", "Warning", "Icon!")
            return
        }
        SelectedHK := saved.TriggerKey
        try {
            Hotkey(SelectedHK, RunActions, "On")
            IsRunning := true
            IsLooping := false
            btnToggle.Text := "STOP  —  Deactivate Hotkey"
        } catch {
            MsgBox("Invalid hotkey or conflict with another hotkey.", "Error", "IconX")
        }
    } else {
        IsLooping := false
        try Hotkey(SelectedHK, "Off")
        IsRunning := false
        btnToggle.Text := "START  —  Activate Hotkey"
    }
}

RunActions(*) {
    global TargetHWND, ActionQueue, IsLooping
    if !TargetHWND || !WinExist("ahk_id " TargetHWND)
        return


    if (IsLooping) {
        IsLooping := false
        return
    }

    saved       := MyGui.Submit(0)
    doLoop      := saved.LoopEnabled
    intervalMs  := IsInteger(saved.LoopInterval) ? Integer(saved.LoopInterval) : 500

    if (!doLoop) {
        ExecuteQueue()
        return
    }

    IsLooping := true
    btnToggle.Text := "STOP LOOP  —  or press hotkey again"
    while (IsLooping) {
        if !WinExist("ahk_id " TargetHWND)
            break
        ExecuteQueue()
        if (intervalMs > 0)
            Sleep(intervalMs)
    }
    btnToggle.Text := "START  —  Activate Hotkey"
}

ExecuteQueue() {
    global TargetHWND, ActionQueue
    for act in ActionQueue {
        if (act.Type == "Click")
            ControlClick("x" act.X " y" act.Y, "ahk_id " TargetHWND, , act.Button, 1, "NA")
        else if (act.Type == "Key")
            ControlSend(act.Key, , "ahk_id " TargetHWND)
        Sleep(act.Sleep)
    }
}

OnGuiClose(*) {
    global CurrentlyHiddenHWND
    if (CurrentlyHiddenHWND) {
        if WinExist("ahk_id " CurrentlyHiddenHWND)
            WinShow("ahk_id " CurrentlyHiddenHWND)
    }
    ExitApp()
}
