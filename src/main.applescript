-- APK拖放安装：把 APK 拖到图标上（或双击后选文件），装进插在电脑上的安卓手机。
-- 界面在这里，装包逻辑在同目录打包进 App 的 install.sh。

property appTitle : "APK拖放安装"

on run
	try
		set picked to choose file with prompt "选择要安装的 APK（可多选）" with multiple selections allowed
	on error number -128
		return
	end try
	installFiles(picked)
end run

on open droppedItems
	installFiles(droppedItems)
end open

on installFiles(theItems)
	set apkPaths to {}
	repeat with f in theItems
		set p to POSIX path of f
		if p ends with ".apk" then set end of apkPaths to p
	end repeat
	if apkPaths is {} then
		display dialog "请拖入 .apk 文件。" buttons {"好"} default button 1 with title appTitle with icon caution
		return
	end if

	set targets to pickDevices()
	if targets is {} then return

	set report to {}
	set allOk to true
	set progress total steps to (count apkPaths) * (count targets)
	set progress completed steps to 0
	set progress description to "正在安装…"
	repeat with apk in apkPaths
		set apkName to lastPart(apk as text, "/")
		repeat with t in targets
			set {serial, devName} to t
			set progress additional description to apkName & " → " & devName
			display notification ("正在把 " & apkName & " 装到 " & devName) with title appTitle
			set r to runTool("install", serial, apk)
			if item 1 of r is "FAIL" and item 2 of r is "NEED_UNINSTALL" then
				try
					display dialog devName & "：" & item 3 of r & return & return & "卸载旧版再装？会清空这个 App 的数据。" buttons {"取消", "卸载并安装"} default button "取消" cancel button "取消" with title appTitle with icon caution
					set r to runTool("reinstall", serial, apk)
				on error number -128
					set r to {"SKIP"}
				end try
			end if
			if item 1 of r is "OK" then
				set end of report to "✅ " & devName & "：" & apkName & " 已装好（用时 " & item 2 of r & " 秒）"
			else if item 1 of r is "SKIP" then
				set allOk to false
				set end of report to "⏭ " & devName & "：" & apkName & " 没装（没有卸载旧版）"
			else
				set allOk to false
				set end of report to "❌ " & devName & "：" & apkName & return & "    " & item 3 of r
			end if
			set progress completed steps to (progress completed steps) + 1
		end repeat
	end repeat

	set progress description to "安装结束"
	set progress additional description to ""
	set msg to joinList(report, return)
	if allOk then
		display dialog msg buttons {"好"} default button 1 with title appTitle with icon note
	else
		display dialog msg buttons {"好"} default button 1 with title appTitle with icon caution
	end if
end installFiles

-- 返回 {{序列号, 显示名}, …}；用户取消返回 {}
on pickDevices()
	repeat
		set ready to {}
		set notAllowed to false
		set badState to false
		repeat with ln in paragraphs of runShell("devices")
			if (ln as text) is not "" then
				set {serial, state, devName} to splitText(ln as text, tab)
				if state is "device" then
					set end of ready to {serial, devName}
				else if state is "unauthorized" then
					set notAllowed to true
				else
					set badState to true
				end if
			end if
		end repeat

		if (count ready) is 1 then return ready
		if (count ready) > 1 then
			set labels to {}
			repeat with d in ready
				set end of labels to (item 2 of d) & "  ·  " & (item 1 of d)
			end repeat
			set chosen to choose from list labels with prompt "选择要安装到的手机（可多选）：" with title appTitle OK button name "安装" cancel button name "取消" with multiple selections allowed
			if chosen is false then return {}
			set picked to {}
			repeat with i from 1 to count labels
				if chosen contains item i of labels then set end of picked to item i of ready
			end repeat
			return picked
		end if

		if notAllowed then
			set msg to "手机上会弹出「允许 USB 调试吗？」，请点「允许」（建议勾选「始终允许」），然后点「重试」。"
		else if badState then
			set msg to "手机连接状态异常，请拔掉数据线重新插上，然后点「重试」。"
		else
			set msg to "没检测到手机。请确认：" & return & "1. 数据线插好，手机已解锁" & return & "2. 手机「开发者选项」里打开了「USB 调试」" & return & "3. 插线后手机上的连接方式选「传输文件」"
		end if
		try
			display dialog msg buttons {"取消", "重试"} default button "重试" cancel button "取消" with title appTitle with icon caution
		on error number -128
			return {}
		end try
	end repeat
end pickDevices

-- 跑 install.sh 的 install / reinstall，返回按 tab 拆开的结果
on runTool(cmd, serial, apk)
	return splitText(runShell(cmd & " " & quoted form of serial & " " & quoted form of (apk as text)), tab)
end runTool

on runShell(args)
	set script_ to (POSIX path of (path to me)) & "Contents/Resources/install.sh"
	return do shell script "/bin/bash " & quoted form of script_ & " " & args without altering line endings
end runShell

on splitText(s, delim)
	set old to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delim
	set parts to text items of s
	set AppleScript's text item delimiters to old
	-- 去掉末尾换行
	set lastItem to item -1 of parts
	if lastItem is linefeed then
		set item -1 of parts to ""
	else if lastItem ends with linefeed then
		set item -1 of parts to text 1 thru -2 of lastItem
	end if
	return parts
end splitText

on lastPart(s, delim)
	return item -1 of splitText(s, delim)
end lastPart

on joinList(xs, delim)
	set old to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delim
	set s to xs as text
	set AppleScript's text item delimiters to old
	return s
end joinList
