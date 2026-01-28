# windows-touchpad-sensitivity
Gets/sets windows touchpad capacitive sensitivity, for palm rejection and gaming.

This toggles the exact same setting that can be found in the Windows Settings app. The intention is that this script can automate the process, if you change this setting often.

To set touchpad sensitivity to "Medium sensitivity" so that your fingers/palm are ignored when typing, run `.\touchpad.ps1 -Action Set -Level medium`
To set touchpad sensitivity to "Most sensitive" so that your finger is never ignored, even when using WASD, run `.\touchpad.ps1 -Action Set -Level most`

All possible values are listed here https://learn.microsoft.com/en-us/windows/win32/api/winuser/ne-winuser-touchpad_sensitivity_level  
but level 4 seems to break tapping to click. it is also hidden from the settings app, so I've ommitted it. Personally, I only find medium and most to be the useful ones.
