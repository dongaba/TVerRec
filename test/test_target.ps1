Invoke-Pester ./test/functions/initialize.Tests.ps1 -Output Detailed -Tag 'Target'
Invoke-Pester ./test/functions/common_functions.Tests.ps1 -Output Detailed -Tag 'Target'
Invoke-Pester ./test/functions/tver_functions.Tests.ps1 -Output Detailed -Tag 'Target'
