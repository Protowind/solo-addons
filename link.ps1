param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Flavour = '_forever_'
)

$source = Join-Path $PSScriptRoot $Name
$target = "H:\World of Warcraft\$Flavour\Interface\AddOns\$Name"

if (-not (Test-Path $source)) { throw "No addon folder: $source" }
if (Test-Path $target) { throw "Already exists: $target" }

New-Item -ItemType Junction -Path $target -Target $source | Out-Null
"Linked $target -> $source"
