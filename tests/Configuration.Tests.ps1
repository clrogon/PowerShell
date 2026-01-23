# Requires Pester
Import-Module ..\modules\Configuration.psm1 -Force

Describe 'Configuration module' {
    $tempConfig = Join-Path $env:TEMP 'PowerShellScripts_Test_Config.xml'

    It 'Initializes configuration with defaults' {
        if (Test-Path $tempConfig) { Remove-Item -Path $tempConfig -Force -ErrorAction SilentlyContinue }
        $config = Initialize-ScriptConfiguration -ConfigPath $tempConfig -DefaultConfig (Get-DefaultConfiguration)
        $config | Should -Not -BeNullOrEmpty
        (Test-Path $tempConfig) | Should -BeTrue
    }

    It 'Sets and gets a simple configuration value' {
        Set-ScriptConfiguration -Key 'TestKey' -Value 'TestValue' -ConfigPath $tempConfig
        $val = Get-ScriptConfiguration -Key 'TestKey' -DefaultValue $null
        $val | Should -Be 'TestValue'
    }
}
