# Requires Pester
Import-Module ..\modules\ErrorHandling.psm1 -Force

Describe 'ErrorHandling module' {
    It 'Succeeds on valid script block' {
        $result = Invoke-ScriptBlockWithErrorHandling -ScriptBlock { 2 + 2 } -Operation 'SimpleSum' -MaxRetries 1
        $result | Should -Be 4
    }

    It 'Throws on failing script block when not continuing on error' {
        { Invoke-ScriptBlockWithErrorHandling -ScriptBlock { throw 'boom' } -Operation 'Fail' -MaxRetries 1 } | Should -Throw
    }
}
