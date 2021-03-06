﻿function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $Configuration = @{
        Name = $Name
    }

    try
    {
        if ($vsCodeInstall = Get-VSCodeInstall)
        {
            if ([version] $vsCodeInstall.DisplayVersion -ge [version]'1.2.0')
            {
                Write-Verbose -Message "Getting a list of installed extensions."
                $installedExtensions = Get-InstalledExtension
                if ($installedExtensions.Name -contains $Name)
                {
                    Write-Verbose -Message "${Name} extension is installed."
                    $Configuration.Add('Ensure','Present')
                    $Configuration
                }
                else
                {
                    Write-Verbose -Message "${Name} extension is not installed."
                    $Configuration.Add('Ensure','Absent')
                    $Configuration
                }
            }
            else
            {
                throw 'VS Code version must be at least 1.2.0'
            }
        }
    }

    catch
    {
        Write-Error $_
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    try
    {
        $vsCodeInstall = Get-VSCodeInstall
        if ($Ensure -eq 'Present')
        {
            $commandLine = "/c `"$($vsCodeInstall.InstallLocation)\bin\code.cmd`" --install-extension ${Name}"
            try
            {
                Write-Verbose -Message "Installing ${Name} extension ..."
                Start-Process -FilePath "cmd" -ArgumentList $commandLine -Wait -WindowStyle Hidden
                if ((Get-InstalledExtension).Name -contains $Name)
                {
                    Write-Verbose 'Extension install complete. Restart VS code if open.'
                }
                else
                {
                    throw 'Extension install failed'
                }
            }
            catch
            {
                Write-Error $_
            }
        }
        else
        {
            $commandLine = "/c `"$($vsCodeInstall.InstallLocation)\bin\code.cmd`" --uninstall-extension ${Name}"
            try
            {
                Write-Verbose -Message "Uninstalling ${Name} extension ..."
                Start-Process -FilePath "cmd" -ArgumentList $commandLine -Wait -WindowStyle Hidden
                if ((Get-InstalledExtension).Name -contains $Name)
                {
                    
                    throw 'Extension uninstall failed'
                }
                else
                {
                    Write-Verbose 'Extension uninstall complete. Restart VS code if open.'
                }
            }
            catch
            {
                Write-Error $_
            }
        }
    }
    
    catch
    {
        Write-Error $_
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    try
    {
        if ($vsCodeInstall = Get-VSCodeInstall)
        {
            if ([version] $vsCodeInstall.DisplayVersion -ge [version]'1.2.0')
            {
                Write-Verbose -Message "Getting a list of installed extensions."
                $installedExtensions = Get-InstalledExtension
                if ($installedExtensions.Name -contains $Name)
                {
                    if ($Ensure -eq 'Present')
                    {
                        Write-Verbose -Message 'Extension is already installed. No action needed.'
                        return $true
                    }
                    else
                    {
                        Write-Verbose -Message 'Extension is installed. It will be removed.'
                        return $false
                    }
                }
                else
                {
                    if ($Ensure -eq 'Present')
                    {
                        Write-Verbose -Message 'Extension is not installed. It will be installed.'
                        return $false
                    }
                    else
                    {
                        Write-Verbose -Message 'Extension is not installed. No action not needed.'
                        return $true
                    }
                }
            }
            else
            {
                Write-Verbose 'VS Code install 1.2.0 not found. Set will be skipped.'
                return $true
            }
        }
        else
        {
            Write-Verbose 'VS Code install not found. Set will be skipped.'
            return $true
        }
    }
    
    catch
    {
        Write-Error $_
    }
}

Function Get-InstalledExtension
{
    [CmdletBinding()]
    param (
    )

    $extensionList = @()
    $extensionPath = "$env:HOMEPATH\.vscode\extensions"
    if (Test-Path $extensionPath)
    {
        $items = (Get-ChildItem $extensionPath)
        if($null -ne $items)
        {
          foreach ($item in $items)
          { 
            $packageObject = Get-Content -Path "$($item.FullName)\package.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($packageObject)
            {
                $extension = @{}
                $extension.Add('Name',"$($packageObject.Publisher).$($packageObject.Name)")
                $extension.Add('Version',$packageObject.version)

                $extensionList += $extension
            }
           }
        }
        else
        {
            Write-Verbose -Message 'No extensions installed.'
        }
    }
    else
    {
        Write-Verbose -Message "${extensionPath} does not exist. Creating it."
        $null = New-Item -Path $extensionPath -ItemType Directory -Force
    }

    if ($extensionList)
    {
        return $extensionList
    }
}

#Function Wait-ForExtensionInstall
#{
#    [CmdletBinding()]
#    param (
#        [String]
#        $Name,
#
#        [UInt64]
#        $RetryIntervalSec = 10,
#
#        [UInt32]
#        $RetryCount = 10
#    )
#    
#    $extensionInstalled = $false
#
#    for ($count = 0; $count -lt $RetryCount; $count++)
#    {
#        Write-Verbose "Retry count: $($count+1); waiting for $RetryIntervalSec seconds"
#        $installedExtensions = Get-InstalledExtension
#        if ($installedExtensions.Name -contains $Name)
#        {
#            $extensionInstalled = $true
#            break
#        }
#        else
#        {
#            Start-Sleep -Seconds $RetryIntervalSec
#        }
#    }
#
#    if (!$extensionInstalled)
#    {
#        throw "$Name extension installed failed"
#    }
#    else
#    {
#        return $extensionInstalled
#    }
#}

Function Get-VSCodeInstall
{
    switch ($env:PROCESSOR_ARCHITECTURE)
    {
        'AMD64' { $UninstallKey = 'HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*' }
        'x86' { $UninstallKey = 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*' }
    }

    $products = Get-ItemProperty -Path $UninstallKey | Select DisplayName, DisplayVersion, InstallLocation
    if ($products.DisplayName -contains 'Microsoft Visual Studio Code')
    {
        return $products.Where({$_.DisplayName -eq 'Microsoft Visual Studio Code'})
    }
}

Export-ModuleMember -Function *-TargetResource

