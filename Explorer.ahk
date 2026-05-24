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

WinContext(WinTitle := "A") {
   hwnd := WinExist(WinTitle)
   switch WinGetClass(hwnd) {
      case "ExploreWClass", "CabinetWClass":
         ctrl := ControlGetFocus(hwnd)
         if ctrl = 0 || ControlGetClassNN(ctrl) ~= "^DirectUIHWND"
            if ExplorerActiveTab(hwnd).Document.SelectedItems.Count > 0
               return "explorer"
         return "default"

      case "Progman", "WorkerW":
         hwnd := ControlGetHwnd("SysListView321", hwnd)
         ctrl := ControlGetFocus(hwnd)
         if ctrl = 0 || ControlGetClassNN(ctrl) ~= "^WorkerW1"
            if ListViewGetContent("Selected Col1", hwnd)
               return "explorer"
         return "default"

      case "ConsoleWindowClass":             return "console"
      case "CASCADIA_HOSTING_WINDOW_CLASS":  return "terminal"

      default: return "default"
   }
}

ExplorerState(t) {

   static GetIShellBrowser(hwnd) {
      ; Get IWebBrowser2. Each tab is its own window, but will share top level hwnds.
      for window in ComObject("Shell.Application").Windows
         wb := window
      until (window.hwnd = hwnd)

      ; Get IShellBrowser. This gets the correct tab from any matching window.
      IID_IShellBrowser    := "{000214E2-0000-0000-C000-000000000046}"
      SID_STopLevelBrowser := "{4C96BE40-915C-11CF-99D3-00AA004AE837}"
      sb := ComObjQuery(wb, SID_STopLevelBrowser, IID_IShellBrowser)

      return sb
   }

   static GetIShellView(sb) {
      ComCall(QueryActiveShellView := 15, sb, "ptr*", sv := ComValue(13,0))
      return sv
   }

   static GetIFolderView(sv) { ; Does not update when files are added or deleted.
      IID_IFolderView := "{CDE725B0-CCC9-4519-917E-325D72FAB4CE}"
      fv := ComObjQuery(sv, IID_IFolderView)
      return fv
   }

   static GetCurrentItem(fv) {
      ComCall(GetFocusedItem := 10, fv, "int*", &i:=0)
      ComCall(Item := 6, fv, "int", i, "ptr*", &pidl := 0)
      return pidl
   }

   static GetIShellFolder(fv) { ; Do not cache this pointer as it is unstable.
      DllCall("ole32\IIDFromString", "wstr", "{000214E6-0000-0000-C000-000000000046}", "ptr", IID_IShellFolder := Buffer(16), "hresult")
      ComCall(5, fv, "ptr", IID_IShellFolder, "ptr*", sf := ComValue(13,0))
      return sf
   }

   static hwnd := -1, sb, sv, fv, n, pidls := []

   reset(e) {
      ; textrender("reset " e, "y:83% c:random t:300")
      loop pidls.length
         DllCall("ole32\CoTaskMemFree", "ptr", pidls.pop())

      hwnd := WinExist("A")

      ; Get IShellBrowser from the current active window.
      sb := GetIShellBrowser(hwnd)

      ; Get IShellView. This pointer is unstable and will invalidate when the user navigates away.
      sv := GetIShellView(sb)

      ; Get IFolderView. This pointer and the data it points to do not update even when files have been changed.
      fv := GetIFolderView(sv)

      ; Creates an array of all the items by converting relative indexes to absolute references.
      ComCall(GetFocusedItem := 10, fv, "int*", &i:=0)
      ComCall(ItemCount := 7, fv, "uint", 2, "int*", &n:=0) ; SVGIO_ALLVIEW
      loop n {
         ComCall(Item := 6, fv, "int", mod(++i, n), "ptr*", &pidl := 0)
         pidls.push pidl
      }

      ; No need for pidl := GetCurrentItem(fv) as its set by the above loop!
   }


   if (t = 1) {

      if hwnd != WinExist("A")
         reset(1)

      if sb.ptr != GetIShellBrowser(hwnd).ptr
         reset(2)

      if sv.ptr != GetIShellView(sb).ptr
         reset(3)

      if fv.ptr != GetIFolderView(sv).ptr
         reset(4)

      if ComCall(CompareIDs := 7, sf := GetIShellFolder(fv), "ptr", 0, "ptr", pidls[-1], "ptr", GetCurrentItem(fv), "ushort")
         reset(5)
   }

   if (t = 2) {

      try while ControlGetClassNN(ControlGetFocus(hwnd)) ~= "^Edit"
         Sleep 10
      Sleep 150

      flags := 0x1 | 0x4 | 0x8 | 0x10 ; SVSI_SELECT | SVSI_DESELECTOTHERS | SVSI_ENSUREVISIBLE | SVSI_FOCUSED
      pidl := pidls.RemoveAt(1)
      ComCall(SelectItem := 14, sv, "ptr", pidl, "uint", flags)
      pidls.push pidl
   }
}

ExplorerFileRename(s := "") {
   if (s == "")
      return ""
   ExplorerState(1)
   Send '{F2}'
   Sleep 50
   switch Type(s) {
      case "Func", "BoundFunc": Paste(s(Copy()))
      case "String":            SendText s
   }
   Send '{Enter}'
   ExplorerState(2)
   return s
}

ExplorerFilePrepend(s := "") {
   if (s == "")
      return ""
   ExplorerState(1)
   Send '{F2}'
   Sleep 50
   Send '{Left}'
   SendText s
   Send '{Enter}'
   ExplorerState(2)
}

ExplorerFileAppend(s := "") {
   if (s == "")
      return ""
   ExplorerState(1)
   Send '{F2}'
   Sleep 50
   Send '{Right}'
   SendText s
   Send '{Enter}'
   ExplorerState(2)
}

ExplorerExtLower() {
   ExplorerState(1)
   Send '{F2}'
   Sleep 50
   Send '{Right}+{End}'
   EditText.StrLower()
   Send '{Enter}'
   ExplorerState(2)
}
