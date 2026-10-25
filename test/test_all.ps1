Invoke-Pester ./test/functions/initialize.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/initialize_child.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/common_functions.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/tver_functions.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/tverrec_functions.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/update_tverrec.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/update_ffmpeg.Tests.ps1 -Output Detailed
Invoke-Pester ./test/functions/update_youtube-dl.Tests.ps1 -Output Detailed
