# windows-touchpad-sensitivity
Gets/sets the Windows touchpad capacitive sensitivity, for palm rejection and gaming.

This toggles the exact same setting that can be found in the Windows Settings app. The intention is that this script can automate the process, if you change this setting often.
<img width="1604" height="986" alt="image_2026-01-28_17-43-31" src="https://github.com/user-attachments/assets/51285249-d0a5-4cfe-9d49-afe3a658b960" />


To set touchpad sensitivity to "Medium sensitivity" so that your fingers/palm are ignored when typing, run `.\touchpad.ps1 -Action Set -Level medium`  
To set touchpad sensitivity to "Most sensitive" so that your finger is never ignored, even when using WASD, run `.\touchpad.ps1 -Action Set -Level most`

The included AutoHotKey v2 script can toggle between medium and most upon pressing the "insert" button on your keyboard. Currently, it forgets its state upon relaunch and looks kinda fugly with the terminal popping up for a second. I hope to make it prettier at some point.

All possible sensitivity values are listed here https://learn.microsoft.com/en-us/windows/win32/api/winuser/ne-winuser-touchpad_sensitivity_level  
but level 4 seems to break tapping to click. it is also hidden from the settings app, so I've ommitted it. Personally, I find `medium` and `most` to be the only useful modes.

Further information of the API used can be found at https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-touchpad_parameters
