#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe '_GetParams' {

    Context 'When a $Map hashtable is provided' {

        It 'Returns only entries whose value is not null' {
            $result = InModuleScope PoshKelvin {
                _GetParams -Map @{ search = 'foo'; name = $null; type = 'bar' }
            }
            $result.Keys | Should -Contain 'search'
            $result.Keys | Should -Contain 'type'
            $result.Keys | Should -Not -Contain 'name'
        }

        It 'Returns an empty hashtable when all map values are null' {
            $result = InModuleScope PoshKelvin {
                _GetParams -Map @{ search = $null; name = $null }
            }
            $result.Count | Should -Be 0
        }

        It 'Returns all non-null entries from the map' {
            $result = InModuleScope PoshKelvin {
                _GetParams -Map @{ a = '1'; b = '2' }
            }
            $result.Count | Should -Be 2
            $result['a'] | Should -Be '1'
            $result['b'] | Should -Be '2'
        }
    }
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
