#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe '_GetParamName' {

    It 'Returns the lowercase parameter name when no aliases exist' {
        $result = InModuleScope PoshKelvin {
            $parm = [PSCustomObject]@{
                Name    = 'MyParam'
                Aliases = @()
            }
            _GetParamName $parm
        }
        $result | Should -Be 'myparam'
    }

    It 'Returns the first alias in lowercase when aliases exist' {
        $result = InModuleScope PoshKelvin {
            $parm = [PSCustomObject]@{
                Name    = 'MyParam'
                Aliases = @('my_alias', 'other_alias')
            }
            _GetParamName $parm
        }
        $result | Should -Be 'my_alias'
    }
}
