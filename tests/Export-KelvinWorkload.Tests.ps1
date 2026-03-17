#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Export-KelvinWorkload' {

    Context '-AsStream parameter set' {

        BeforeAll {
            $mockStream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes('PKZIPdata'))
            Mock Invoke-KelvinApi { $mockStream } -ModuleName PoshKelvin
        }

        It 'Calls the download endpoint with GET and application/zip Accept header' {
            Export-KelvinWorkload -Name 'my-workload' -AsStream

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/download' -and
                $Method -eq 'Get' -and
                $Accept -eq 'application/zip'
            }
        }

        It 'Returns the raw stream when -AsStream is specified' {
            $result = Export-KelvinWorkload -Name 'my-workload' -AsStream
            $result | Should -BeOfType [System.IO.Stream]
        }

        It 'Passes the -AsStream flag to Invoke-KelvinApi' {
            Export-KelvinWorkload -Name 'my-workload' -AsStream

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $AsStream -eq $true
            }
        }
    }

    Context 'File parameter set (default)' {

        BeforeEach {
            $zipContent   = [byte[]]@(0x50, 0x4B, 0x03, 0x04)  # ZIP magic bytes
            $script:mockStream = [System.IO.MemoryStream]::new($zipContent)
            Mock Invoke-KelvinApi { $script:mockStream } -ModuleName PoshKelvin
        }

        It 'Calls the download endpoint with the correct path and parameters' {
            Export-KelvinWorkload -Name 'my-workload' -DestinationPath $TestDrive

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/download'
            }
        }

        It 'Writes the downloaded content to a zip file under the destination path' {
            Export-KelvinWorkload -Name 'my-workload' -DestinationPath $TestDrive

            "$TestDrive/my-workload.zip" | Should -Exist
        }
    }
}
