# PSScriptAnalyzerSettings.psd1
@{
	Severity     = @('Error', 'Warning')
}
@{
	IncludeRules = @('PSAvoidUsingPlainTextForPassword',
		'PSAvoidUsingConvertToSecureStringWithPlainText')
}