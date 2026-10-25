Invoke-Pester ./test/functions/initialize.Test.ps1 -Output Detailed
Invoke-Pester ./test/functions/common_functions.Test.ps1 -Output Detailed
Invoke-Pester ./test/functions/tver_functions.Test.ps1 -Output Detailed
Invoke-Pester ./test/functions/tverrec_functions.Test.ps1 -Output Detailed
Invoke-Pester ./test/functions/update_tverrec.Test.ps1 -Output Detailed
