// Icons.qml — Centralized MDI icon constants
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property string font: Config.mdiFont

    // Music
    readonly property string musicNote:       "󰎈"
    readonly property string musicPrev:       "󰒮"
    readonly property string musicPlay:       "󰐊"
    readonly property string musicPause:      "󰏤"
    readonly property string musicNext:       "󰒭"
    readonly property string musicPlayer:     "󰜟"
    readonly property string disc:            ""
    readonly property string musicNoteOff:    "󰎊"

    // Volume
    readonly property string volume:          "󰕾"
    readonly property string volumeLow:       "󰕿"
    readonly property string volumeMedium:    "󰖀"
    readonly property string volumeMuted:     "󰝟"
    readonly property string audioOutput:     "󰈐"
    readonly property string audioUsb:        "󰕓"
    readonly property string audioHeadphone:  "󰋋"

    // WiFi / Network
    readonly property string wifi:            "󰤨"
    readonly property string wifiOff:         "󰤭"
    readonly property string wifiNoNet:       "󰤮"
    readonly property string wifiStrength1:   "󰤟"
    readonly property string wifiStrength2:   "󰤢"
    readonly property string wifiStrength3:   "󰤥"
    readonly property string wifiNoSignal:    "󰤯"
    readonly property string ethernet:        "󰈀"

    // Bluetooth
    readonly property string bluetooth:       "󰂯"
    readonly property string bluetoothOn:     "󰂱"

    // Display
    readonly property string display:         "󰌢"
    readonly property string displayDual:     "󰆼"
    readonly property string displayMonitor:  "󰍹"
    readonly property string brightness:      "󰃠"
    readonly property string brightnessLow:   "󰌵"


    // System
    readonly property string power:           "󰐥"
    readonly property string reboot:          "󰜉"
    readonly property string logout:          "󰍃"
    readonly property string settings:        "󰒓"
    readonly property string darkMode:        "󰽥"
    readonly property string lightMode:       "󰖨"
    readonly property string nightLightOff:   "󰖠"
    readonly property string screenshot:      "󰄀"
    // Toggle Captura (SettingsState): U+F06D1, en escape porque el
    // literal no viaja bien por todos los editores.
    readonly property string screenshotAlt:   "\uDB81\uDCD1"
    readonly property string theme:           "󰆌"
    readonly property string palette:         "󰏘"
    readonly property string code:            "󰣆"
    readonly property string shell:           "󰒋"

    // Clipboard
    readonly property string clipboard:       "󰅍"
    readonly property string clipboardItem:   "󰈟"

    // Notifications
    readonly property string notification:    "󰂚"
    readonly property string notificationOff: "󰂛"

    // Calendar
    readonly property string calendar:        "󰃭"
    readonly property string calendarPrev:    "󰅁"
    readonly property string timer:           "󰔟"

    // Taskbar / Windows
    readonly property string window:          "󰋐"
    readonly property string windowMinimize:  "󰖭"
    readonly property string windowMaximize:  "󰊓"
    readonly property string pin:             "󰐃"
    readonly property string unpin:           "󰐄"
    readonly property string taskGroup:       "󰘓"
    readonly property string drag:            "󰄭"
    readonly property string windowActive:    "󰄮"
    readonly property string windowInactive:  "󰄯"

    // Start menu
    readonly property string startMenu:       "󰀻"

    // Command Palette (modos): launcher + calculadora + theme.
    readonly property string launcher:        "󰣆"
    readonly property string calculator:      "󰃬"
    readonly property string themeSwitch:     "󰌶"


    // Arrows / Navigation
    readonly property string chevronUp:       "󰅃"
    readonly property string chevronDown:     "󰅀"
    readonly property string chevronRight:    "󰅂"
    readonly property string chevronLeft:     "󰁍"

    // Misc
    readonly property string firefox:         "󰈹"
    readonly property string youtube:         ""
    readonly property string add:             ""
    readonly property string minus:           "󰍴"
    readonly property string trash:           ""
    readonly property string edit:            "󰏫"
    readonly property string remove:          "󰍸"
    readonly property string check:           "󰄬"
    readonly property string close:           "󰅖"
    readonly property string search:          "󰍉"
    readonly property string lock:            "󰌾"
    readonly property string unlock:          "󰌽"
    readonly property string eyeOff:          "󰆴"
    readonly property string info:            "󰋽"
    readonly property string warning:         "󰀪"
    readonly property string error:           "󰀨"
    readonly property string star:            "󰓎"
    readonly property string checkBold:       "󰐕"
    readonly property string mirror:          "󰆏"
    readonly property string image:           "󰋩"
    readonly property string imageBroken:     "󰀦"
    readonly property string eyeVisible:      "󰈈"
    readonly property string eyeHidden:       "󰈉"
    readonly property string passwordBullet:  "●"
    readonly property string folderOutline:   "󰝰"
    readonly property string account:         "󰀄"
    readonly property string key:             "󰌆"
    readonly property string keyVariant:      "󰑄"
    readonly property string refresh:         "󰑐"
    readonly property string refreshAlt:      "󰑓"
    readonly property string download:        "󰇚"
    readonly property string upload:          "󰕜"
    readonly property string folder:          "󰉋"
    readonly property string file:            "󰈙"
    readonly property string fileSort:        "󰒺"
    readonly property string hash:            "󰃗"
    readonly property string monitor:         "󰘚"
    readonly property string question:        "󰋖"
    readonly property string eyeOpen:         "󰈈"
    readonly property string eyeClose:        "󰈉"
    readonly property string dice:            "󰇎"
    readonly property string chart:           "󰄨"


    // File types (clipboard)
    readonly property string filePdf:         "󰈦"
    readonly property string fileArchive:     "󰗄"
    readonly property string fileVideo:       "󰈫"
    readonly property string fileAudio:       "󰈣"
    readonly property string fileSlides:      "󰈨"
    readonly property string fileSheet:       "󰈜"
    readonly property string fileDoc:         "󰈭"
    readonly property string fileText:        "󰧭"
    readonly property string fileScript:      "󱆃"
    readonly property string fileCode:        "󰈮"
    readonly property string fileWeb:         "󰲋"
    readonly property string fileData:        "󰘦"
    readonly property string fileFont:        "󰛖"
    readonly property string fileIso:         "󰗮"
    readonly property string fileSubtitle:    "󰨖"
    readonly property string filePkg:         "󰏗"
    readonly property string fileOutline:     "󰈤"
    readonly property string email:           "󰇮"

    // Empty states
    readonly property string emptyState:      "󰋜"

    // Wallpaper modes
    readonly property string wpFill:          "󰁁"
    readonly property string wpFit:           "󰑟"
    readonly property string wpCenter:        "󰻃"
    readonly property string wpTile:          "󰕰"
    // Wallpaper transitions
    readonly property string wpFade:          "󰝥"
    readonly property string wpWave:          "󰞍"
    readonly property string wpOuter:         "󰉁"
}
