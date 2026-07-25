#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Screenshot')]
param(
    [Parameter(Mandatory)][int]$ProcessId,

    [Parameter(Mandatory, ParameterSetName = 'Screenshot')]
    [string]$Screenshot,

    [Parameter(Mandatory, ParameterSetName = 'Click')]
    [switch]$Click,

    [Parameter(Mandatory, ParameterSetName = 'Keys')]
    [string]$Keys,

    [Parameter(Mandatory, ParameterSetName = 'State')]
    [ValidateSet('Restore', 'Minimize', 'Maximize')]
    [string]$State
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'WindowAutomation.psm1') -Force

$window = Get-EdWindow -ProcessId $ProcessId
switch ($PSCmdlet.ParameterSetName) {
    Screenshot { Save-EdWindowScreenshot -Process $window -Path $Screenshot }
    Click { Invoke-EdWindowClick -Process $window }
    Keys { Send-EdWindowKeys -Process $window -Keys $Keys }
    State { Set-EdWindowState -Process $window -State $State }
}
