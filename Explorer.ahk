ExplorerWin(i?)   => ExplorerActive(i?)[2]
ExplorerPath(i?)  => (filepaths := ExplorerPaths(i?), filepaths.has(1) ? filepaths[1] : "")
ExplorerBase(i?)  => ExplorerSplitPath(ExplorerPath(i?)).basename
ExplorerDrive(i?) => ExplorerSplitPath(ExplorerDir(i?)).drive
ExplorerDir(i?)   => ExplorerActive(i?)[1]
ExplorerFile(i?)  => ExplorerSplitPath(ExplorerPath(i?)).filename
ExplorerExt(i?)   => ExplorerSplitPath(ExplorerPath(i?)).extension

ExplorerSplitPath(filepath) {

   SplitPath filepath, &basename, &directory, &extension, &filename, &drive
   DirExist(filepath) && (filename := basename, extension := "")

   return {
      filepath: filepath,
      basename: basename,
      directory: directory,
      extension: extension,
      filename: filename,
      drive: drive
   }
}

ExplorerActive(inactive := False) {
   if (hwnd := WinActive("ahk_class WorkerW"))
   or (hwnd := WinActive("ahk_class Progman"))
      return [A_Desktop, hwnd]

   WinExistOrActive := (inactive) ? WinExist : WinActive
   if (hwnd := WinExistOrActive("ahk_class ExploreWClass"))
   or (hwnd := WinExistOrActive("ahk_class CabinetWClass")) {
      window := ExplorerActiveTab(hwnd)
      filepath := Type(window.Document) == "ShellFolderView"
         ? window.Document.Folder.Self.Path
         : window.LocationURL            ; "HTMLDocument"
      return [filepath, window.hwnd]
   }

   return ["", 0] ; No matching explorer windows found.
}

ExplorerActiveTab(hwnd) {
   ; Thanks Lexikos, @TheCrether - https://www.autohotkey.com/boards/viewtopic.php?f=83&t=109907
   try activeTab := ControlGetHwnd("ShellTabWindowClass1", hwnd) ; File Explorer (Windows 11)
   catch
   try activeTab := ControlGetHwnd("TabWindowClass1", hwnd) ; IE
   for window in ComObject("Shell.Application").Windows {
      if (window.hwnd != hwnd)
         continue
      if IsSet(activeTab) { ; The window has tabs, so make sure this is the right one.
         static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
         IShellBrowser := ComObjQuery(window, IID_IShellBrowser, IID_IShellBrowser)
         ComCall(GetWindow := 3, IShellBrowser, "uint*", &thisTab := 0)
         if (thisTab != activeTab)
            continue
      }
      return window ; Returns a ComObject with a .hwnd property
   }
   throw Error("Could not locate active tab in Explorer window.")
}

ExplorerPaths(inactive := False) {
   ; Thanks mikeyww - https://www.autohotkey.com/boards/viewtopic.php?p=509165#p509165
   filepaths := []
   WinExistOrActive := (inactive) ? WinExist : WinActive
   if (hwnd := WinExistOrActive("ahk_class ExploreWClass"))
   or (hwnd := WinExistOrActive("ahk_class CabinetWClass")) {
      window := ExplorerActiveTab(hwnd)
      for item in window.Document.SelectedItems
         filepaths.push(item.Path)
   }
   if WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman") {
      try hwnd := ControlGetHwnd("SysListView321", "ahk_class Progman")
      hwnd := hwnd || ControlGetHwnd("SysListView321", "A")
      Loop Parse ListViewGetContent("Selected Col1", hwnd), "`n", "`r"
         filepaths.push(A_Desktop "\" A_LoopField)
   }
   return filepaths ; Returned array could be empty with zero length
}
