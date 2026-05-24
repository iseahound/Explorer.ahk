# Explorer

Gets selected file names from the current explorer window

> By default checks only the current active window. To use the last active explorer window, pass `true` or `1`.

#### ExplorerDrive(i?) - Gets the drive letter of the current explorer window
#### ExplorerDir(i?) - Gets the directory open in the current explorer window
#### ExplorerFile(i?) - Gets selected filename only (no extension)
#### ExplorerExt(i?) - Gets selected extension
#### ExplorerBase(i?) - Gets selected filename and extension
#### ExplorerPath(i?) - Gets selected filepath in the current explorer window
#### ExplorerPaths(i?) - Gets all filepaths in the current explorer window

    ; Prints out the absolute filepaths of every file in the current explorer window
    for filepath in ExplorerPaths()
        MsgBox filepath

#### ExplorerWin(i?) - Gets hwnd of current explorer window
