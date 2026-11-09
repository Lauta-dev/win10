pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int workDuration: 25 * 60
    property int shortBreakDuration: 5 * 60
    property int longBreakDuration: 15 * 60

    property string timerState: "idle"
    property bool isRunning: false
    property int timeRemaining: root.workDuration
    property int sessionsCompleted: 0
    property int totalSessions: 0
    property string sessionsDate: ""

    readonly property real progress: root._currentDuration > 0
        ? 1.0 - (root.timeRemaining / root._currentDuration) : 0.0
    property int _currentDuration: root.workDuration

    function _today() {
        return new Date().toISOString().slice(0, 10)
    }

    function _resetDaily() {
        var today = root._today()
        if (root.sessionsDate !== today) {
            root.sessionsCompleted = 0
            root.sessionsDate = today
            root._save()
        }
    }

    function startWork() {
        root._resetDaily()
        root.timerState = "work"
        root._currentDuration = root.workDuration
        root.timeRemaining = root.workDuration
        root.isRunning = true
    }

    function startShortBreak() {
        root.timerState = "shortBreak"
        root._currentDuration = root.shortBreakDuration
        root.timeRemaining = root.shortBreakDuration
        root.isRunning = true
    }

    function startLongBreak() {
        root.timerState = "longBreak"
        root._currentDuration = root.longBreakDuration
        root.timeRemaining = root.longBreakDuration
        root.isRunning = true
    }

    function start() {
        if (root.timerState === "idle") {
            root.startWork()
        } else {
            root.isRunning = true
        }
    }

    function pause() {
        root.isRunning = false
    }

    function reset() {
        root.isRunning = false
        if (root.timerState === "idle") {
            root._currentDuration = root.workDuration
            root.timeRemaining = root.workDuration
        } else {
            root.timeRemaining = root._currentDuration
        }
    }

    function skipPhase() {
        root.isRunning = false
        root._advanceToNext()
    }

    function _advanceToNext() {
        if (root.timerState === "work") {
            root.sessionsCompleted++
            root.totalSessions++
            root._save()
            var isLong = root.sessionsCompleted % 4 === 0
            if (isLong) {
                root.startLongBreak()
            } else {
                root.startShortBreak()
            }

        } else {
            root.startWork()
        }
    }

    Timer {
        interval: 1000
        running: root.isRunning
        repeat: true
        onTriggered: {
            if (root.timeRemaining > 0) {
                root.timeRemaining--
            }
            if (root.timeRemaining <= 0) {
                root.isRunning = false
                root._advanceToNext()
            }
        }
    }

    function setWorkDuration(min) {
        var sec = Math.max(1, Math.min(90, min)) * 60
        root.workDuration = sec
        if (!root.isRunning) {
            if (root.timerState === "work" || root.timerState === "idle") {
                root._currentDuration = sec
                root.timeRemaining = sec
            }
        }
        root._save()
    }
    function setShortBreakDuration(min) {
        var sec = Math.max(1, Math.min(30, min)) * 60
        root.shortBreakDuration = sec
        if (!root.isRunning && root.timerState === "shortBreak") {
            root._currentDuration = sec
            root.timeRemaining = sec
        }
        root._save()
    }
    function setLongBreakDuration(min) {
        var sec = Math.max(1, Math.min(60, min)) * 60
        root.longBreakDuration = sec
        if (!root.isRunning && root.timerState === "longBreak") {
            root._currentDuration = sec
            root.timeRemaining = sec
        }
        root._save()
    }

    function _save() {
        var data = JSON.stringify({
            totalSessions: root.totalSessions,
            sessionsDate: root.sessionsDate,
            workDuration: root.workDuration,
            shortBreakDuration: root.shortBreakDuration,
            longBreakDuration: root.longBreakDuration
        })
        pomodoroFile.setText(data)
    }

    function _load() {
        var raw = pomodoroFile.text()
        if (!raw || raw.trim() === "") return
        try {
            var obj = JSON.parse(raw)
            if (obj.totalSessions !== undefined) root.totalSessions = obj.totalSessions
            if (obj.sessionsDate) root.sessionsDate = obj.sessionsDate
            if (obj.workDuration) { root.workDuration = obj.workDuration; if (!root.isRunning && (root.timerState === "idle" || root.timerState === "work")) { root._currentDuration = obj.workDuration; root.timeRemaining = obj.workDuration } }
            if (obj.shortBreakDuration) root.shortBreakDuration = obj.shortBreakDuration
            if (obj.longBreakDuration) root.longBreakDuration = obj.longBreakDuration
        } catch(e) {}
        root._resetDaily()
    }

    FileView {
        id: pomodoroFile
        path: Quickshell.env("HOME") + "/.config/qs-pomodoro.json"
        atomicWrites: true
        onLoaded: root._load()
        onLoadFailed: root._resetDaily()
    }
}
