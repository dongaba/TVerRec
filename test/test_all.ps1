Invoke-Pester ./test/functions/initialize.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/common_functions.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/tver_functions.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/tverrec_functions.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/update_tverrec.Tests.ps1 -Output Detailed
