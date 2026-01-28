<#
.SYNOPSIS
	Get or set touchpad sensitivity.
.DESCRIPTION
	Reads and optionally sets touchpad parameters using SystemParametersInfo.
.EXAMPLE
	.\touchpad.ps1 -Action Get
.EXAMPLE
	.\touchpad.ps1 -Action Set -Level HIGH_SENSITIVITY -Broadcast
#>

param(
	[Parameter(Mandatory = $true)]
	[ValidateSet("Get", "Set", IgnoreCase = $true)]
	[string] $Action,

	[string] $Level,  # we'll validate manually

	[switch] $Broadcast = $true,
	[switch] $Persist   = $true
)

# PowerShell can’t natively call SystemParametersInfo with arbitrary structs
# The below is C# code that will be compiled later with Add-Type

$code = @"
using System;
using System.Runtime.InteropServices;

// struct defined here https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-touchpad_parameters

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct TOUCHPAD_PARAMETERS
{
	public UInt32 versionNumber;
	public UInt32 maxSupportedContacts;
	public UInt32 legacyTouchpadFeatures;
	private UInt32 _flags1; // Packed status/capability bits (read-only?)
	private UInt32 _flags2; // Packed user-configurable behavior bits (no idea which bit is which)
	public UInt32 sensitivityLevel;  	// TOUCHPAD_SENSITIVITY_LEVEL
    public UInt32 cursorSpeed;			// 1-20 inclusive
    public UInt32 feedbackIntensity;	// 0-100 inclusive
    public UInt32 clickForceSensitivity;// 0-100 inclusive
    public UInt32 rightClickZoneWidth;	// 0-100 inclusive
    public UInt32 rightClickZoneHeight;	// 0-100 inclusive
	
	public UInt32 flags1
    {
        get { return _flags1; }
    }

    public UInt32 flags2
    {
        get { return _flags2; }
    }
}

// Values from https://learn.microsoft.com/en-us/windows/win32/api/winuser/ne-winuser-touchpad_sensitivity_level
// level 4 seems to break tapping to click. it is also hidden from the settings app. ommitting it.
public enum TOUCHPAD_SENSITIVITY_LEVEL : uint
{
	MOST_SENSITIVE		= 0,
	HIGH_SENSITIVITY	= 1,
	MEDIUM_SENSITIVITY	= 2,
	LOW_SENSITIVITY		= 3
}

public static class TouchpadNative
{
	public const uint SPI_GETTOUCHPADPARAMETERS = 0x00AE;
	public const uint SPI_SETTOUCHPADPARAMETERS = 0x00AF;

	public const uint TOUCHPAD_PARAMETERS_VERSION_1 = 0x00000001;

	// fWinIni flags:
	// 0 = don't broadcast change
	public const uint SPIF_UPDATEINIFILE = 0x0001;   // persist change
	public const uint SPIF_SENDCHANGE   = 0x0002;   // broadcast WM_SETTINGCHANGE

	[DllImport("user32.dll", SetLastError = true)]
	[return: MarshalAs(UnmanagedType.Bool)]
	public static extern bool SystemParametersInfo(
		uint uiAction,
		uint uiParam,
		ref TOUCHPAD_PARAMETERS pvParam,
		uint fWinIni
	);
}
"@

# Compiled code is preserved for the session. If the script was already ran and TOUCHPAD_PARAMETERS still exists, don't try to recompile to avoid an error.
if (-not ([System.Management.Automation.PSTypeName]'TOUCHPAD_PARAMETERS').Type) {
	Add-Type -TypeDefinition $code -ErrorAction Stop
}

function Get-TouchpadParams {
	# create and init struct
	$p = New-Object TOUCHPAD_PARAMETERS
	$p.versionNumber = [TouchpadNative]::TOUCHPAD_PARAMETERS_VERSION_1

	# size of THIS instance (mirrors sizeof(struct) in C)
	$size = [System.Runtime.InteropServices.Marshal]::SizeOf($p)

	# call SPI_GETTOUCHPADPARAMETERS
	$ok = [TouchpadNative]::SystemParametersInfo(
		[TouchpadNative]::SPI_GETTOUCHPADPARAMETERS,
		[uint32]$size,
		[ref]$p,
		0
	)

	if (-not $ok) {
		$err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
		throw "SPI_GETTOUCHPADPARAMETERS failed. Win32 error: $err"
	}

	return $p
}

function Set-TouchpadSensitivity {
	param(
		[Parameter(Mandatory = $true)]
		[TOUCHPAD_SENSITIVITY_LEVEL] $NewLevel,

		[switch] $Broadcast,
		[switch] $Persist
	)

	# Read current params (so we keep everything else the same)
	$cur = Get-TouchpadParams

	# Update just the sensitivityLevel
	$cur.sensitivityLevel = [uint32]$NewLevel

	# Prepare size and flags
	$size = [System.Runtime.InteropServices.Marshal]::SizeOf($cur)

	# Build fWinIni flags
	# Start at 0, then include:
	#   - SPIF_SENDCHANGE (broadcast WM_SETTINGCHANGE)
	#   - SPIF_UPDATEINIFILE (ask Windows to persist)
	$fWinIni = 0
	if ($Broadcast) {
		$fWinIni = $fWinIni -bor [TouchpadNative]::SPIF_SENDCHANGE
	}
	if ($Persist) {
		$fWinIni = $fWinIni -bor [TouchpadNative]::SPIF_UPDATEINIFILE
	}

	# Call SPI_SETTOUCHPADPARAMETERS
	$ok = [TouchpadNative]::SystemParametersInfo(
		[TouchpadNative]::SPI_SETTOUCHPADPARAMETERS,
		[uint32]$size,
		[ref]$cur,
		[uint32]$fWinIni
	)

	if (-not $ok) {
		$err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
		throw "SPI_SETTOUCHPADPARAMETERS failed. Win32 error: $err"
	}

	return $true
}

# --- input handling and flow

if ($Action -eq "Get") {
	Write-Host "Reading current touchpad parameters..." -ForegroundColor Yellow
	$p = Get-TouchpadParams
	$p | Format-List *
	exit
}

if ($Action -eq "Set") {
	if (-not $Level) {
		Write-Host "Error: -Level must be specified when using -Action Set." -ForegroundColor Red
		exit 1
	}

	# normalize to uppercase
	$levelKey = $Level.ToUpperInvariant()

	# lookup table: short aliases → official enum names
	$levelMap = @{
		"MOST"   = "MOST_SENSITIVE"
		"HIGH"   = "HIGH_SENSITIVITY"
		"MEDIUM" = "MEDIUM_SENSITIVITY"
		"LOW"	= "LOW_SENSITIVITY"
	}

	if ($levelMap.ContainsKey($levelKey)) {
		$resolvedLevel = $levelMap[$levelKey]
	}
	else {
		# also allow full enum names (case-insensitive)
		$resolvedLevel = $levelMap.Values |
			Where-Object { $_ -ieq $Level } |
			Select-Object -First 1

		if (-not $resolvedLevel) {
			Write-Host "Invalid -Level '$Level'. Valid values are: $($levelMap.Keys -join ', '), or full enum names." -ForegroundColor Red
			exit 1
		}
	}

	$enumValue = [TOUCHPAD_SENSITIVITY_LEVEL]::$resolvedLevel
	Write-Host "Setting touchpad sensitivity to $resolvedLevel..." -ForegroundColor Yellow

	try {
		if (Set-TouchpadSensitivity -NewLevel $enumValue -Broadcast:$Broadcast -Persist:$Persist) {
			Write-Host "Successfully applied sensitivity." -ForegroundColor Green
		}
		else {Write-Host "Failed to apply sensitivity."}
	}
	catch {
		Write-Host "Failed to apply sensitivity:`n$($_.Exception.Message)" -ForegroundColor Red
		exit 1
	}

	exit
}
