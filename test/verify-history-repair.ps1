$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot '../src/functions/tverrec_functions.ps1'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw $errors[0] }
$definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Repair-HistoryFile' }, $true)
Invoke-Expression $definition.Extent.Text
$root = Join-Path ([IO.Path]::GetTempPath()) ('TVerRec-history-repair-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$script:histFilePath = Join-Path $root 'history.csv'
$script:histLockFilePath = Join-Path $root 'history.lock'
$script:msg = @{ WaitingLock = 'waiting'; DistinctHistFailed = 'repair failed' }
$script:locked = $false; $script:lockCount = 0; $script:unlockCount = 0
function Lock-File($path) {
    if ($script:locked) { throw 'Nested history lock.' }
    $script:locked = $true; $script:lockCount++
    return @{ result = $true }
}
function Unlock-File($path) { $script:locked = $false; $script:unlockCount++ }
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Save-Fixture($rows) { $rows | Microsoft.PowerShell.Utility\Export-Csv -LiteralPath $script:histFilePath -Encoding utf8 }
function Row($page, $date, $validated) { [pscustomobject]@{videoPage=$page;downloadDate=$date;videoValidated=$validated;title='日本語, "番組"'} }

Save-Fixture @((Row 'a' '2026-10-10 00:00:00' '0'), (Row 'a' '2026-10-11 00:00:00' '1'), (Row 'b' '2026-10-11 00:00:00' '3'))
$before = [IO.File]::ReadAllBytes($script:histFilePath)
Repair-HistoryFile
$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding utf8)
Assert ($rows.Count -eq 1 -and $rows[0].videoPage -eq 'a' -and $rows[0].videoValidated -eq '1') 'Latest/failed row semantics changed.'
Assert ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($script:histFilePath + '.bak'))) 'Backup differs from original.'

Save-Fixture @((Row 'b' '2026-10-11 00:00:00' '3'))
Repair-HistoryFile
Assert ((Get-Content -LiteralPath $script:histFilePath -Encoding utf8 -TotalCount 1) -match 'videoPage') 'Empty history lost its header.'
(Row 'c' '2026-10-11 00:00:00' '0') | Export-Csv -LiteralPath $script:histFilePath -Encoding utf8 -Append
Assert (@(Import-Csv -LiteralPath $script:histFilePath -Encoding utf8).Count -eq 1) 'Append after empty repair failed.'

$before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($script:histFilePath))
function Export-Csv {
    [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, [string]$LiteralPath, [string]$Encoding)
    process { Assert $script:locked 'Save must hold the history lock.'; [IO.File]::WriteAllText($LiteralPath, 'partial'); throw 'Injected write failure' }
}
$warnings = @(Repair-HistoryFile 3>&1)
Assert ($warnings.Count -eq 1) 'Expected failure warning.'
Assert ($before -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($script:histFilePath))) 'Write failure damaged original history.'
Remove-Item Function:/Export-Csv
Assert (-not $script:locked -and $script:lockCount -eq $script:unlockCount) 'Lock was not released.'
Assert (@([IO.Directory]::EnumerateFiles($root, '*.tmp')).Count -eq 0) 'Temporary files leaked.'
function Export-Csv {
    [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, [string]$LiteralPath, [string]$Encoding)
    process { [IO.File]::WriteAllText($LiteralPath, 'partial'); [IO.File]::SetAttributes($LiteralPath, [IO.FileAttributes]::ReadOnly); throw 'Injected cleanup failure' }
}
try { Repair-HistoryFile 3>$null } catch { }
Assert (-not $script:locked -and $script:lockCount -eq $script:unlockCount) 'Cleanup failure leaked lock.'
Assert ($before -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($script:histFilePath))) 'Cleanup failure damaged original history.'
foreach ($temp in [IO.Directory]::EnumerateFiles($root, '*.tmp')) { [IO.File]::SetAttributes($temp, [IO.FileAttributes]::Normal); [IO.File]::Delete($temp) }
Remove-Item Function:/Export-Csv
Write-Output ('PASS history repair: latest/failed rows, backup, empty header/append, failed save, lock lifetime; fixture=' + $root)
