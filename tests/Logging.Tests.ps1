# Requires Pester
Import-Module ..\modules\Logging.psm1 -Force
Import-Module ..\modules\Configuration.psm1 -Force

Describe 'Logging module' {
    $testLog = Join-Path $env:TEMP 'PowerShellScripts_Test_Logging.log'
    if (Test-Path $testLog) { Remove-Item $testLog -Force -ErrorAction SilentlyContinue }

    BeforeAll {
        Initialize-Logging -LogPath $testLog -Component 'LoggingTests'
    }

    It 'Writes a log entry without errors' {
        $entry = Write-ScriptLog -Level Info -Message 'Test log entry' -NoConsole
        $entry | Should -BeOfType PSCustomObject
        $entry.Level | Should -Be 'Info'
        $entry.Message | Should -Be 'Test log entry'
    }
}
