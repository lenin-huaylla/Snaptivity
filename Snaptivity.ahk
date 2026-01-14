#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook

ProcessSetPriority("High")

#SingleInstance Force
DetectHiddenWindows(true)
if WinExist("Snaptivity CONTROL PANEL") {
    WinKill()
}


; ======================================================
; GLOBAL STATE
; ======================================================

global szodActive := false
global toggleKey := ""

; Physical key states
global physicalKeys := Map("w", false, "a", false, "s", false, "d", false)

; Split lane channels
global currentSOD_H := ""   ; a / d
global currentSOD_V := ""   ; w / s

; Unified channel (ADDED)
global currentSOD_All := ""

; Picker GUI state (Snaptivity toggle)
global pickerGui := ""
global statusText := ""
global goBtn := ""
global pickedKey := ""

; Picker GUI state (Menu toggle)
global menuPickerGui := ""
global menuStatusText := ""
global menuGoBtn := ""
global menuPickedKey := ""

; Absolute priority keys
global absUnifiedKey := ""
global absSplitHKey := ""
global absSplitVKey := ""

; Menu Gui
global menuGui := ""

;special
global isResettingKey := false

;OSD helper (Universal)
global editOsdGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
editOsdGui.BackColor := "000000"
WinSetTransColor("000000", editOsdGui)
editOsdGui.SetFont("s12 Bold", "Segoe UI")

; Fixed window size (wide enough for long text)
editOsdGui.Show("Hide w700 h60")

global editOsdText := editOsdGui.AddText(
    "x10 y10 w680 h40 c00FFAA Center",
    ""
)
ShowEditOSD(msg, color := "00FFAA", duration := 4000) {
    global editOsdGui, editOsdText

    editOsdText.Text := msg
    editOsdText.Opt("c" color)

    ; Show first (keeps its original X position)
    editOsdGui.Show("NoActivate")

    ; Get current position
    editOsdGui.GetPos(&x, &y, &w, &h)

    ; Move it UP only
    y -= 120   ; adjust this value for how high you want it

    editOsdGui.Move(x, y)

    SetTimer(() => editOsdGui.Hide(), -duration)
}

;Overrides
    ; Override modes:
; 1 = Last input wins (default)
; 2 = First input wins
; 3 = Disable input on override
global overrideMode := 1
;snappy mode
global snappyMode := true  ; true = raw overlap, false = intent-based
;traytip
global trayTipsEnabled := true
;tooltip
global toolTipMap := Map()
global lastTTCtrl := ""

OnMessage(0x200, WM_MOUSEMOVE)  ; 0x200 = WM_MOUSEMOVE

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global toolTipMap, lastTTCtrl

    MouseGetPos(, , &win, &ctrlHwnd, 2)

    if toolTipMap.Has(ctrlHwnd) {
        if (lastTTCtrl != ctrlHwnd) {
            ToolTip(toolTipMap[ctrlHwnd])
            lastTTCtrl := ctrlHwnd
        }
    } else {
        ToolTip()
        lastTTCtrl := ""
    }
}

; ======================================================
; MENU TOGGLES
; ======================================================

global neutralizeMode := false
global debugOverlay := false
global menuToggleKey := ""
global splitLanes := true   ; true = WS and AD separate, false = unified

; HUD positioning / sizing adjust mode
global hudX := 40
global hudY := 220
global adjustingHud := false

; ======================================================
; REAL WASD HUD (GAMER STYLE)
; ======================================================

fontScale := 0.45

keySize := 46
gap := 8

global debugGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
debugGui.BackColor := "000000"
WinSetTransColor("000000", debugGui)
debugGui.SetFont("s" Round(keySize * fontScale) " Bold", "Segoe UI")

global hudW := debugGui.AddText("w" keySize " h" keySize " Center Border c444444", "W")
global hudA := debugGui.AddText("w" keySize " h" keySize " Center Border c444444", "A")
global hudS := debugGui.AddText("w" keySize " h" keySize " Center Border c444444", "S")
global hudD := debugGui.AddText("w" keySize " h" keySize " Center Border c444444", "D")

; Layout
hudW.Move(keySize + gap, 0)
hudA.Move(0, keySize + gap)
hudS.Move(keySize + gap, keySize + gap)
hudD.Move((keySize + gap) * 2, keySize + gap)

; Fix window cropping + add padding so borders are never cut
; Add GUI margins (inner padding)
debugGui.MarginX := 4
debugGui.MarginY := 4

; Increase window size slightly to account for borders
hudWidth  := (keySize + gap) * 3 - gap + 8
hudHeight := (keySize + gap) * 2 - gap + 8

debugGui.Show("w" hudWidth " h" hudHeight " NoActivate x" hudX " y" hudY)
debugGui.Hide()

; ======================================================
; HUD REFRESH
; ======================================================

UpdateDebugOSD() {
    global debugOverlay, debugGui, physicalKeys, szodActive, splitLanes
    global hudW, hudA, hudS, hudD
    global currentSOD_H, currentSOD_V, currentSOD_All

    if (!debugOverlay) {
        debugGui.Hide()
        return
    }

    SnaptivityColor  := "00FFFF"   ; cyan
    physColor  := "00FF00"   ; green
    idleColor  := "333333"   ; dark gray

    if (szodActive) {
        if (splitLanes) {
            ; Split-lane mode
            hudW.Opt("c" (currentSOD_V = "w" ? SnaptivityColor : idleColor))
            hudS.Opt("c" (currentSOD_V = "s" ? SnaptivityColor : idleColor))
            hudA.Opt("c" (currentSOD_H = "a" ? SnaptivityColor : idleColor))
            hudD.Opt("c" (currentSOD_H = "d" ? SnaptivityColor : idleColor))
        } else {
            ; Unified-lane mode
            hudW.Opt("c" (currentSOD_All = "w" ? SnaptivityColor : idleColor))
            hudA.Opt("c" (currentSOD_All = "a" ? SnaptivityColor : idleColor))
            hudS.Opt("c" (currentSOD_All = "s" ? SnaptivityColor : idleColor))
            hudD.Opt("c" (currentSOD_All = "d" ? SnaptivityColor : idleColor))
        }
    } else {
        ; Physical mode
        hudW.Opt("c" (physicalKeys["w"] ? physColor : idleColor))
        hudA.Opt("c" (physicalKeys["a"] ? physColor : idleColor))
        hudS.Opt("c" (physicalKeys["s"] ? physColor : idleColor))
        hudD.Opt("c" (physicalKeys["d"] ? physColor : idleColor))
    }

    debugGui.Show("NoActivate x" hudX " y" hudY)
}
configDir := A_ScriptDir "\config"
configFile := configDir "\Snaptivity.ini"

InitConfig() {
    global configDir, configFile

    if !DirExist(configDir)
        DirCreate(configDir)

    if !FileExist(configFile) {
        IniWrite("", configFile, "Keys", "Snaptivity_Toggle")
        IniWrite("", configFile, "Keys", "Menu_Toggle")
        IniWrite(0, configFile, "Settings", "NeutralizeMode")
        IniWrite(1, configFile, "Settings", "SplitLanes")
        IniWrite(0, configFile, "Settings", "DebugOverlay")
        IniWrite(40, configFile, "HUD", "X")
        IniWrite(220, configFile, "HUD", "Y")
        IniWrite(46, configFile, "HUD", "KeySize")
        IniWrite(1, configFile, "Settings", "SnappyMode")
        IniWrite(1, configFile, "Settings", "TrayTips")
        IniWrite("", configFile, "AbsolutePriority", "Unified")
        IniWrite("", configFile, "AbsolutePriority", "SplitH")
        IniWrite("", configFile, "AbsolutePriority", "SplitV")

    }
}

SaveConfig() {
    global toggleKey, menuToggleKey, neutralizeMode, splitLanes, debugOverlay, hudX, hudY, keySize, configFile

    IniWrite(toggleKey, configFile, "Keys", "Snaptivity_Toggle")
    IniWrite(menuToggleKey, configFile, "Keys", "Menu_Toggle")
    IniWrite(neutralizeMode, configFile, "Settings", "NeutralizeMode")
    IniWrite(splitLanes, configFile, "Settings", "SplitLanes")
    IniWrite(debugOverlay, configFile, "Settings", "DebugOverlay")
    IniWrite(hudX, configFile, "HUD", "X")
    IniWrite(hudY, configFile, "HUD", "Y")
    IniWrite(keySize, configFile, "HUD", "KeySize")
    IniWrite(snappyMode, configFile, "Settings", "SnappyMode")
    IniWrite(trayTipsEnabled, configFile, "Settings", "TrayTips")
    IniWrite(absUnifiedKey, configFile, "AbsolutePriority", "Unified")
    IniWrite(absSplitHKey,  configFile, "AbsolutePriority", "SplitH")
    IniWrite(absSplitVKey,  configFile, "AbsolutePriority", "SplitV")

}

LoadConfig() {
    global toggleKey, menuToggleKey, neutralizeMode, splitLanes, debugOverlay, hudX, hudY, keySize, configFile

    toggleKey := IniRead(configFile, "Keys", "Snaptivity_Toggle", "")
    menuToggleKey := IniRead(configFile, "Keys", "Menu_Toggle", "")

    neutralizeMode := IniRead(configFile, "Settings", "NeutralizeMode", 0)
    splitLanes := IniRead(configFile, "Settings", "SplitLanes", 1)
    debugOverlay := IniRead(configFile, "Settings", "DebugOverlay", 0)

    hudX := IniRead(configFile, "HUD", "X", hudX)
    hudY := IniRead(configFile, "HUD", "Y", hudY)
    keySize := IniRead(configFile, "HUD", "KeySize", keySize)

    snappyMode := IniRead(configFile, "Settings", "SnappyMode", 1)
    trayTipsEnabled := IniRead(configFile, "Settings", "TrayTips", 1)

    absUnifiedKey := IniRead(configFile, "AbsolutePriority", "Unified", "")
    absSplitHKey  := IniRead(configFile, "AbsolutePriority", "SplitH", "")
    absSplitVKey  := IniRead(configFile, "AbsolutePriority", "SplitV", "")

    return (toggleKey != "" && menuToggleKey != "")
}

; ======================================================
; Snaptivity STATUS OSD (TOP TEXT)
; ======================================================

global osdGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
osdGui.BackColor := "000000"
WinSetTransColor("000000", osdGui)
osdGui.SetFont("s13 Bold", "Segoe UI")

global osdText := osdGui.AddText("c00FF00", "Snaptivity: OFF")

UpdateOSD() {
    global szodActive, osdGui, osdText

    if (szodActive) {
        osdText.Text := "Snaptivity: ON"
        osdText.Opt("c00FFFF")
    } else {
        osdText.Text := "Snaptivity: OFF"
        osdText.Opt("cFF3333")
    }

    osdGui.Show("NoActivate")
    SetTimer(HideOSD, 0)
    SetTimer(HideOSD, -2000)
}

HideOSD() {
    global osdGui
    osdGui.Hide()
}

; ======================================================
; START
; ======================================================

InitConfig()
if LoadConfig() {
    Hotkey("$" toggleKey, (*) => ToggleSZOD())
    Hotkey("$" menuToggleKey, (*) => ShowMenu())
    ShowTrayTip("Snaptivity SCRIPT", "⚡ Config loaded from /config/Snaptivity.ini", 2000)
} else {
    ShowTogglePicker()
    UpdateDebugOSD()
}

; ======================================================
; HOTKEYS (PHYSICAL CAPTURE)
; ======================================================

; Horizontal
~*a::HandleSOD_H("a", true)
~*d::HandleSOD_H("d", true)
~*a up::HandleSOD_H("a", false)
~*d up::HandleSOD_H("d", false)

; Vertical
~*w::HandleSOD_V("w", true)
~*s::HandleSOD_V("s", true)
~*w up::HandleSOD_V("w", false)
~*s up::HandleSOD_V("s", false)


; ======================================================
; Snaptivity TOGGLE
; ======================================================

ToggleSZOD(*) {
    global szodActive, currentSOD_H, currentSOD_V, currentSOD_All

    szodActive := !szodActive
    UpdateOSD()

    if (!szodActive) {
        if (currentSOD_H != "")
            Send("{" currentSOD_H " up}")
        if (currentSOD_V != "")
            Send("{" currentSOD_V " up}")
        if (currentSOD_All != "")
            Send("{" currentSOD_All " up}")

        currentSOD_H := ""
        currentSOD_V := ""
        currentSOD_All := ""
    }

    ShowTrayTip(
        "SOD SCRIPT",
        szodActive ? "🟢 Snaptivity MODE: ACTIVE" : "🔴 Snaptivity MODE: OFF",
        1200
    )
    UpdateDebugOSD()
}

; ======================================================
; SOD RESOLVERS (ROUTER)
; ======================================================

HandleSOD_H(key, isDown) {
    global splitLanes, szodActive, physicalKeys

    physicalKeys[key] := isDown

    if (!szodActive) {
        UpdateDebugOSD()
        return
    }

    if (splitLanes)
        HandleSplitH(key, isDown)
    else
        HandleUnifiedSOD(key, isDown)
}

HandleSOD_V(key, isDown) {
    global splitLanes, szodActive, physicalKeys

    physicalKeys[key] := isDown

    if (!szodActive) {
        UpdateDebugOSD()
        return
    }

    if (splitLanes)
        HandleSplitV(key, isDown)
    else
        HandleUnifiedSOD(key, isDown)
}

; ======================================================
; SPLIT-LANE HANDLERS
; ======================================================

; =========================
; SPLIT H
; =========================
HandleSplitH(key, isDown) {
    global physicalKeys, currentSOD_H, overrideMode, neutralizeMode

    opp := (key = "a") ? "d" : "a"

    ; ===== Conflict detection =====
    if ( (snappyMode && physicalKeys[key] && physicalKeys[opp]) ;someone took my 2nd brain away and deleted this line and killed snappy mode aaaaaaaaaaaaaaaaaaaaaa
    || (!snappyMode && isDown && physicalKeys[opp]) ) {


        ; 1 = Last input wins
        if (overrideMode = 1 && isDown) {
            if (currentSOD_H != "")
                Send("{" currentSOD_H " up}")
            currentSOD_H := key
            Send("{" key " down}")
            UpdateDebugOSD()
            return
        }

        ; 2 = First input wins
        else if (overrideMode = 2) {
            if (neutralizeMode && key != currentSOD_H)
                Send("{" key " up}")
            UpdateDebugOSD()
            return
        }

        ; 3 = Disable both
        else if (overrideMode = 3) {
            if (currentSOD_H != "") {
                Send("{" currentSOD_H " up}")
                currentSOD_H := ""
            }
            UpdateDebugOSD()
            return
        }
        if (overrideMode=4 && absSplitHKey!="" && (key="a"||key="d")) {
            if (isDown) {
                if (key=absSplitHKey) {
                    if (currentSOD_H!="")
                        Send("{" currentSOD_H " up}")
                    currentSOD_H:=key
                    Send("{" key " down}")
                } else {
                    Send("{" key " up}")
                }
            }
            UpdateDebugOSD()
            return
        }
    }   

    ; ===== Winner lock ONLY if neutralizeMode ON =====
    if (neutralizeMode && currentSOD_H != "" && isDown && key != currentSOD_H) {
        UpdateDebugOSD()
        return
    }

    ; ===== Normal flow (RESTORED from old code) =====
    if (isDown) {
        if (currentSOD_H != key) {
            if (currentSOD_H != "")
                Send("{" currentSOD_H " up}")
            currentSOD_H := key
            Send("{" key " down}")
        }
    } else {
        if (currentSOD_H == key) {
            Send("{" key " up}")
            currentSOD_H := ""

            ; 🔥 THIS IS THE LOST LINE THAT CAUSED EVERYTHING AHHHHHH
            if (!neutralizeMode) {
                for k in ["a","d"] {
                    if (physicalKeys[k]) {
                        currentSOD_H := k
                        Send("{" k " down}")
                        break
                    }
                }
            }
        }
    }

    UpdateDebugOSD()
}


; =========================
; SPLIT V
; =========================
HandleSplitV(key, isDown) {
    global physicalKeys, currentSOD_V, overrideMode, neutralizeMode

    opp := (key = "w") ? "s" : "w"

    if ( (snappyMode && physicalKeys[key] && physicalKeys[opp]) 
    || (!snappyMode && isDown && physicalKeys[opp]) ) {


        if (overrideMode = 1 && isDown) {
            if (currentSOD_V != "")
                Send("{" currentSOD_V " up}")
            currentSOD_V := key
            Send("{" key " down}")
            UpdateDebugOSD()
            return
        }

        else if (overrideMode = 2) {
            if (neutralizeMode && key != currentSOD_V)
                Send("{" key " up}")
            UpdateDebugOSD()
            return
        }

        else if (overrideMode = 3) {
            if (currentSOD_V != "") {
                Send("{" currentSOD_V " up}")
                currentSOD_V := ""
            }
            UpdateDebugOSD()
            return
        }
        if (overrideMode=4 && absSplitVKey!="" && (key="w"||key="s")) {
            if (isDown) {
                if (key=absSplitVKey) {
                    if (currentSOD_V!="")
                        Send("{" currentSOD_V " up}")
                    currentSOD_V:=key
                    Send("{" key " down}")
                } else {
                    Send("{" key " up}")
                }
            }
            UpdateDebugOSD()
            return
        }

    }

    if (neutralizeMode && currentSOD_V != "" && isDown && key != currentSOD_V) {
        UpdateDebugOSD()
        return
    }

    if (isDown) {
        if (currentSOD_V != key) {
            if (currentSOD_V != "")
                Send("{" currentSOD_V " up}")
            currentSOD_V := key
            Send("{" key " down}")
        }
    } else {
        if (currentSOD_V == key) {
            Send("{" key " up}")
            currentSOD_V := ""
            if (!neutralizeMode) {
                for k in ["w","s"] {
                    if (physicalKeys[k]) {
                        currentSOD_V := k
                        Send("{" k " down}")
                        break
                    }
                }
            }
        }
    }

    UpdateDebugOSD()
}




; =========================
; UNIFIED
; =========================
HandleUnifiedSOD(key, isDown) {
    global physicalKeys, currentSOD_All, overrideMode, neutralizeMode, snappyMode

    opposites := Map("w","s","s","w","a","d","d","a")
    opp := opposites[key]

    ; ===== Conflict detection =====
    if ( (snappyMode && physicalKeys[key] && physicalKeys[opp]) 
      || (!snappyMode && isDown && physicalKeys[opp]) ) {

        if (overrideMode = 1 && isDown) {
            if (currentSOD_All != "")
                Send("{" currentSOD_All " up}")
            currentSOD_All := key
            Send("{" key " down}")
            UpdateDebugOSD()
            return
        }

        else if (overrideMode = 2) {
            if (neutralizeMode && key != currentSOD_All)
                Send("{" key " up}")
            UpdateDebugOSD()
            return
        }

        else if (overrideMode = 3) {
            if (currentSOD_All != "") {
                Send("{" currentSOD_All " up}")
                currentSOD_All := ""
            }
            UpdateDebugOSD()
            return
        }

        else if (overrideMode = 4 && absUnifiedKey != "") {
            if (isDown) {
                if (key = absUnifiedKey) {
                    if (currentSOD_All != "" && currentSOD_All != key)
                        Send("{" currentSOD_All " up}")
                    currentSOD_All := key
                    Send("{" key " down}")
                } else {
                    Send("{" key " up}")
                }
            }
            UpdateDebugOSD()
            return
        }

        UpdateDebugOSD()
        return
    }

    ; ===== Winner lock ONLY if neutralizeMode ON =====
    if (neutralizeMode && currentSOD_All != "" && isDown && key != currentSOD_All) {
        UpdateDebugOSD()
        return
    }

    ; ===== Normal flow =====
    if (isDown) {
        if (currentSOD_All != key) {
            if (currentSOD_All != "")
                Send("{" currentSOD_All " up}")
            currentSOD_All := key
            Send("{" key " down}")
        }
    } else {
        if (currentSOD_All == key) {
            Send("{" key " up}")
            currentSOD_All := ""
            if (!neutralizeMode) {
                for k in ["w","a","s","d"] {
                    if (physicalKeys[k]) {
                        currentSOD_All := k
                        Send("{" k " down}")
                        break
                    }
                }
            }
        }
    }

    UpdateDebugOSD()
}




; ======================================================
; Snaptivity TOGGLE PICKER
; ======================================================

ShowTogglePicker() {
    global pickerGui, statusText, goBtn, pickedKey

    DisableHotkeys()

    pickerGui := Gui("+AlwaysOnTop", "🎮 Snaptivity Toggle Key")
    pickerGui.BackColor := "101010"
    pickerGui.SetFont("s11 Bold", "Segoe UI")

    pickerGui.AddText("c00FFFF w300 Center", "PRESS A KEY FOR Snaptivity TOGGLE")
    statusText := pickerGui.AddText("cFFFFFF w300 Center", "No key selected")

    goBtn := pickerGui.AddButton("w120 Center Disabled", "CONFIRM")
    goBtn.OnEvent("Click", SetToggleKey)

    pickerGui.Show("AutoSize Center")
    SetTimer(ListenForKey, 10)
}

ListenForKey() {
    global pickedKey, statusText, goBtn

    ctrl  := GetKeyState("Ctrl", "P")
    alt   := GetKeyState("Alt", "P")
    shift := GetKeyState("Shift", "P")

    for key in GetAllKeys() {
        if GetKeyState(key, "P") {

            combo := ""

            if (ctrl)
                combo .= "^"
            if (alt)
                combo .= "!"
            if (shift)
                combo .= "+"

            combo .= key

            pickedKey := combo
            statusText.Text := "Selected: " combo
            goBtn.Enabled := true

            ; wait for everything to be released so it doesn't spam
            KeyWait(key)
            if (ctrl)
                KeyWait("Ctrl")
            if (alt)
                KeyWait("Alt")
            if (shift)
                KeyWait("Shift")

            break
        }
    }
}

SetToggleKey(*) {
    global pickedKey, toggleKey, pickerGui, isResettingKey

    EnableHotkeys()
    SetTimer(ListenForKey, 0)

    toggleKey := pickedKey
    Hotkey(toggleKey, (*) => ToggleSZOD())

    ShowTrayTip("SOD SCRIPT", "Snaptivity Toggle set to: " toggleKey, 1500)

    pickerGui.Destroy()

    if (!isResettingKey)
        ShowMenuTogglePicker()
    else
        isResettingKey := false

    SaveConfig()
}

; ======================================================
; MENU TOGGLE PICKER
; ======================================================

ShowMenuTogglePicker() {
    global menuPickerGui, menuStatusText, menuGoBtn, menuPickedKey

    DisableHotkeys()

    menuPickerGui := Gui("+AlwaysOnTop", "⚙️ MENU Toggle Key")
    menuPickerGui.BackColor := "101010"
    menuPickerGui.SetFont("s11 Bold", "Segoe UI")

    menuPickerGui.AddText("c00FFFF w300 Center", "PRESS A KEY TO OPEN MENU")
    menuStatusText := menuPickerGui.AddText("cFFFFFF w300 Center", "No key selected")

    menuGoBtn := menuPickerGui.AddButton("w120 Center Disabled", "CONFIRM")
    menuGoBtn.OnEvent("Click", SetMenuToggleKey)

    menuPickerGui.Show("AutoSize Center")
    SetTimer(ListenForMenuKey, 10)
}

ListenForMenuKey() {
    global menuPickedKey, menuStatusText, menuGoBtn

    ctrl  := GetKeyState("Ctrl", "P")
    alt   := GetKeyState("Alt", "P")
    shift := GetKeyState("Shift", "P")

    for key in GetAllKeys() {
        if GetKeyState(key, "P") {

            combo := ""
            if (ctrl)
                combo .= "^"
            if (alt)
                combo .= "!"
            if (shift)
                combo .= "+"

            combo .= key

            menuPickedKey := combo
            menuStatusText.Text := "Selected: " combo
            menuGoBtn.Enabled := true

            KeyWait(key)
            if (ctrl)
                KeyWait("Ctrl")
            if (alt)
                KeyWait("Alt")
            if (shift)
                KeyWait("Shift")

            break
        }
    }
}
SetMenuToggleKey(*) {
    global menuPickedKey, menuToggleKey, menuPickerGui

    EnableHotkeys()
    SetTimer(ListenForMenuKey, 0)

    menuToggleKey := menuPickedKey
    Hotkey(menuToggleKey, (*) => ShowMenu())

    SaveConfig()

    ShowTrayTip("SOD SCRIPT", "Menu Toggle set to: " menuToggleKey, 1500)
    menuPickerGui.Destroy()
}

; ======================================================
; GAMER MENU UI
; ======================================================

ShowMenu() {
    global neutralizeMode, debugOverlay, splitLanes
    global trayTipsEnabled, snappyMode, overrideMode
    global isResettingKey

    global menuGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    menu := menuGui

    menu.BackColor := "0B0F1A"
    menu.SetFont("s11 Bold", "Segoe UI")

    ; ===== CUSTOM GAMER TITLE BAR (FLOW SAFE) =====
    titleBar := menu.AddText("w300 h30 Center c00FFFF", "🎮 Snaptivity CONTROL PANEL")
    titleBar.SetFont("s11 Bold")

    ; 🔁 REBIND BUTTONS
    btnRebindSnaptivity := menu.AddText(
        "w300 h32 Center +0x200 Border Background1E90FF cFFFFFF",
        "🔁 Reselect Snaptivity Toggle Key"
    )



    btnRebindSnaptivity.OnEvent("Click", (*) => (
        menu.Destroy(),
        ShowTogglePicker()
        isResettingKey := true
    ))

    btnRebindMenu := menu.AddButton("w300 h32", "🔁 Reselect Menu Toggle Key")
    btnRebindMenu.OnEvent("Click", (*) => (
        menu.Destroy(),
        ShowMenuTogglePicker()
        isResettingKey := true
    ))

    ; HUD Edit Button
    btnHud := menu.AddButton("w300 h32", "🛠️ Edit HUD Position / Size")
    btnHud.OnEvent("Click", (*) => StartHudAdjust())

    ; Tray notifications
    cbTray := menu.AddCheckbox("cAAAAFF w300", "🔕 Disable Tray Notifications")
    cbTray.Value := !trayTipsEnabled
    cbTray.OnEvent("Click", (*) => (
        trayTipsEnabled := !cbTray.Value,
        SaveConfig()
    ))

    ; Snappy mode
    cbSnappy := menu.AddCheckbox("cFFAA00 w300", "⚡ Snappy Input Mode")
    cbSnappy.Value := snappyMode
    cbSnappy.OnEvent("Click", (*) => (
        snappyMode := cbSnappy.Value,
        ShowTrayTip(
            "SOD SCRIPT",
            snappyMode
                ? "⚡ Snappy Mode ENABLED (Arcade Feel)"
                : "🧠 Snappy Mode DISABLED (Clean / Intent)",
            1500
        ),
        SaveConfig()
    ))

    ; Neutralize / Lock winner
    global cbNeutral := menu.AddCheckbox("c00FFAA w300", "🔥 Lock Winner Opposites (W+S / A+D)")
    cbNeutral.Value := neutralizeMode
    cbNeutral.OnEvent("Click", (*) => neutralizeMode := cbNeutral.Value)

    ; Split lanes
    cbSplit := menu.AddCheckbox("c00FFFF w300", "🧭 Split Direction Lanes (WS / AD)")
    cbSplit.Value := splitLanes
    cbSplit.OnEvent("Click", (*) => (
        splitLanes := cbSplit.Value,
        OverrideModeChanged({Value:overrideMode}),
        SaveConfig()
    ))


    ; Debug HUD
    cbDebug := menu.AddCheckbox("c00FF00 w300", "🧪 Show WASD HUD Overlay")
    cbDebug.Value := debugOverlay
    cbDebug.OnEvent("Click", (*) => (
        debugOverlay := cbDebug.Value,
        UpdateDebugOSD()
        SaveConfig()
    ))

    ; Override mode
    menu.AddText("c00FFFF w300", "⚡ Override Mode")
    ddlOverride := menu.AddDropDownList("w300", [
        "Last input wins",
        "First input wins",
        "Disable input on override",
        "Absolute Priority Mode"
    ])
    ddlOverride.Value := overrideMode
    ddlOverride.OnEvent("Change", OverrideModeChanged)

    ; =========================
    ; ABSOLUTE PRIORITY UI (HIDDEN BY DEFAULT)
    ; =========================

    global absTitle := menu.AddText("cFF66FF w300 Center", "👑 Absolute Priority Settings")
    absTitle.Visible := false

    global absUnifiedDDL := menu.AddDropDownList("w300", ["None","W","A","S","D"])
    absUnifiedDDL.Visible := false

    global absSplitHDDL := menu.AddDropDownList("w300", ["None","A","D"])
    absSplitHDDL.Visible := false

    global absSplitVDDL := menu.AddDropDownList("w300", ["None","W","S"])
    absSplitVDDL.Visible := false

    ; 🔁 Load saved Absolute Priority values into UI
    absUnifiedDDL.Text := (absUnifiedKey = "" ? "None" : StrUpper(absUnifiedKey))
    absSplitHDDL.Text  := (absSplitHKey  = "" ? "None" : StrUpper(absSplitHKey))
    absSplitVDDL.Text  := (absSplitVKey  = "" ? "None" : StrUpper(absSplitVKey))



    ; SHOW MENU FIRST
    menu.Show("AutoSize Center")

    OverrideModeChanged({Value: overrideMode})
    
    ; ===== CLOSE BUTTON (ADD LAST SO IT DOESN’T BREAK FLOW) =====
    titleBar.GetPos(&tx, &ty, &tw, &th)

    btnClose := menu.AddButton(
        "x" (300 - 10 - 6) " y" 8 " w30 h28",
        "✖"
    )

    btnClose.Opt("BackgroundAA3333 cFFFFFF")
    btnClose.OnEvent("Click", (*) => (
    menu.Destroy()
    ))


    ; =========================
    ; TOOLTIPS
    ; =========================

    AttachToolTip(btnRebindSnaptivity, "Change the key used to toggle Snaptivity on and off.")
    AttachToolTip(btnRebindMenu, "Change the key used to open this control panel.")
    AttachToolTip(btnHud, "Move and resize the WASD HUD overlay.")

    AttachToolTip(cbTray, "Prevents Windows tray notifications from appearing.")

    AttachToolTip(cbSnappy,
        "Uses raw physical key overlap detection. Feels faster and more arcade-like, but less filtered."
    )

    AttachToolTip(cbNeutral,
        "When both opposite directions are pressed, keeps the winning direction instead of neutralizing."
    )

    AttachToolTip(cbSplit,
        "Separates horizontal (A/D) and vertical (W/S) input handling into independent lanes."
    )
    AttachToolTip(cbDebug,
        "Shows a real-time WASD HUD overlay for debugging input behavior."
    )

    AttachToolTip(ddlOverride,
        "Defines what happens when opposite directions are pressed together."
    )
}



; ======================================================
; KEY LIST
; ======================================================

GetAllKeys() {
    return [
        "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
        "CapsLock","ScrollLock","NumLock","Pause","Insert","Delete","Home","End","PgUp","PgDn",
        "Up","Down","Left","Right","PrintScreen",
        "Numpad0","Numpad1","Numpad2","Numpad3","Numpad4","Numpad5","Numpad6","Numpad7","Numpad8","Numpad9",
        "NumpadAdd","NumpadSub","NumpadMult","NumpadDiv","NumpadDot","NumpadEnter",
        "Volume_Up","Volume_Down","Volume_Mute","Media_Play_Pause","Media_Next","Media_Prev","Media_Stop",
        "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
        "1","2","3","4","5","6","7","8","9","0"
    ]
}



; ======================================================
; HUD ADJUST MODE HOTKEYS
; ======================================================

#HotIf adjustingHud
Up::MoveHud(0, -5)
Down::MoveHud(0, 5)
Left::MoveHud(-5, 0)
Right::MoveHud(5, 0)

NumpadAdd::ResizeHud(2)
NumpadSub::ResizeHud(-2)

Enter::FinishHudAdjust()
#HotIf

MoveHud(dx, dy) {
    global hudX, hudY
    hudX += dx
    hudY += dy
    UpdateDebugOSD()
}

ResizeHud(delta) {
    global keySize, gap, debugGui, hudW, hudA, hudS, hudD

    keySize += delta
    if (keySize < 20)
        keySize := 20

    hudW.SetFont("s" Round(keySize * fontScale) " Bold")
    hudA.SetFont("s" Round(keySize * fontScale) " Bold")
    hudS.SetFont("s" Round(keySize * fontScale) " Bold")
    hudD.SetFont("s" Round(keySize * fontScale) " Bold")


    ; resize HUD elements
    hudW.Move(, , keySize, keySize)
    hudA.Move(, , keySize, keySize)
    hudS.Move(, , keySize, keySize)
    hudD.Move(, , keySize, keySize)

    ; re-layout
    hudW.Move(keySize + gap, 0)
    hudA.Move(0, keySize + gap)
    hudS.Move(keySize + gap, keySize + gap)
    hudD.Move((keySize + gap) * 2, keySize + gap)

    ; resize window
    hudWidth  := (keySize + gap) * 3 - gap + 8
    hudHeight := (keySize + gap) * 2 - gap + 8
    debugGui.Show("w" hudWidth " h" hudHeight " NoActivate x" hudX " y" hudY)
}

FinishHudAdjust() {
    global adjustingHud
    adjustingHud := false
    SaveConfig()

    ShowEditOSD("✅ HUD position saved!", "00FF00", 2000)
}

StartHudAdjust() {
    global adjustingHud
    adjustingHud := true

    ShowEditOSD(
        "Use Arrow keys to move and numpad -/+ to resize HUD`nPress ENTER to save position",
        "00FFAA",
        6000
    )

    ShowTrayTip("HUD EDIT MODE", "Use OSD instructions to adjust HUD", 1500)
}
OverrideModeChanged(ctrl, *) {
    global overrideMode, cbNeutral, neutralizeMode
    global absTitle, absUnifiedDDL, absSplitHDDL, absSplitVDDL
    global splitLanes, menuGui

    overrideMode := ctrl.Value

    modes := Map(
        1,"Last Input Wins ⚡",
        2,"First Input Wins 🧱",
        3,"Disable On Override ❌",
        4,"Absolute Priority 👑"
    )

    ShowTrayTip("OVERRIDE MODE", "Mode set to: " modes[overrideMode], 1200)

    ; Grey-out Lock Winner on Mode 3 and 4
    if (overrideMode=3 || overrideMode=4) {
        neutralizeMode := false
        cbNeutral.Value := 0
        cbNeutral.Enabled := false
        cbNeutral.Opt("c666666")
    } else {
        cbNeutral.Enabled := true
        cbNeutral.Opt("c00FFAA")
    }

    ; 👑 SHOW/HIDE ABSOLUTE PRIORITY CONTROLS
    showAbs := (overrideMode = 4)

    absTitle.Visible := showAbs

    if (splitLanes) {
        absUnifiedDDL.Visible := false
        absSplitHDDL.Visible := showAbs
        absSplitVDDL.Visible := showAbs
    } else {
        absUnifiedDDL.Visible := showAbs
        absSplitHDDL.Visible := false
        absSplitVDDL.Visible := false
    }
    menuGui.Show("AutoSize")
}



ShowTrayTip(title, text, time := 800) {
    global trayTipsEnabled
    if (trayTipsEnabled)
        TrayTip(title, text, time)
}
AttachToolTip(ctrl, text) {
    global toolTipMap
    toolTipMap[ctrl.Hwnd] := text
}
ShowStatusOSD(msg, color := "66FF66") {
    global editOsdGui, editOsdText, debugGui, debugOverlay

    ; Only show status if WASD HUD is enabled
    if (!debugOverlay) {
        editOsdGui.Hide()
        return
    }

    ; Set text + color
    editOsdText.Text := "🟢 " msg
    editOsdText.Opt("c" color)

    ; Show so we can measure size
    editOsdGui.Show("NoActivate")

    ; Get real HUD position
    debugGui.GetPos(&hx, &hy, &hw, &hh)

    ; Get OSD size
    editOsdGui.GetPos(&x, &y, &w, &h)

    ; Place directly under WASD HUD
    newX := hx
    newY := hy + hh + 6   ; small gap

    editOsdGui.Move(newX, newY)
}
DisableHotkeys() {
    global toggleKey, menuToggleKey
    if (toggleKey != "")
        Hotkey(toggleKey, "Off")
    if (menuToggleKey != "")
        Hotkey(menuToggleKey, "Off")
}

EnableHotkeys() {
    global toggleKey, menuToggleKey
    if (toggleKey != "")
        Hotkey(toggleKey, "On")
    if (menuToggleKey != "")
        Hotkey(menuToggleKey, "On")
}
; does anyone even read this
; why does copilot keep suggesting me 2... WHATS THE MEANING OF 2!
