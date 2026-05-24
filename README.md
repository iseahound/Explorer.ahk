# Explorer

Gets selected file names from the current explorer window

> By default checks only the current active window. To use the last active explorer window, pass `true` or `1`.

    MsgBox ExplorerDrive()  ; Gets the drive letter of the current explorer window
    MsgBox ExplorerDir()    ; Gets the directory open in the current explorer window
    MsgBox ExplorerFile()   ; Gets selected filename only (no extension)
    MsgBox ExplorerExt()    ; Gets selected extension
    MsgBox ExplorerBase()   ; Gets selected filename and extension
    MsgBox ExplorerPath()   ; Gets selected filepath in the current explorer window
    MsgBox ExplorerPaths()  ; Gets all filepaths in the current explorer window

    ; Prints out the absolute filepaths of every file in the current explorer window
    for filepath in ExplorerPaths()
        MsgBox filepath

    MsgBox ExplorerWin(i?) - Gets hwnd of current explorer window
