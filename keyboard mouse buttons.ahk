#Requires AutoHotkey v2.0
#SingleInstance

RAlt::LButton
RControl::RButton
<+#F23::RButton ; capture copilot key (left windows + left shift + F23)
; note that shift+right click is impossible when using copilot key for right click

Ins:: 
{
	static toggled := false
	if toggled := !toggled 
	{
		Run "powershell -NoProfile -Command `"C:\Users\Vykori\OneDrive\touchpad.ps1 -action set -Level medium`""
	}
	else
	{
		Run "powershell -NoProfile -Command `"C:\Users\Vykori\OneDrive\touchpad.ps1 -action set -Level most`""
	}
}