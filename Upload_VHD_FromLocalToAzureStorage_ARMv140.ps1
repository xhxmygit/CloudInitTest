<#
    New portal: https://ms.portal.azure.com/
    This script is tested on Azure Powershell 1.4.0 version.
	
    .SYNOPSIS
       This script will upload specified VHD file to Windows Azure.
       And this script depends on Windows Azure Powershell.
    .DESCRIPTION
       This script will upload specified VHD file to Windows Azure.
       And this script depends on Windows Azure Powershell.
    .PARAMETER  VHDFile
		Specifies the name of VHD file with full path.
    .PARAMETER  StorageAccountName
		Specifies the Storage Account to access Azure.
    .PARAMETER  ContainerName
		Specifies the Container to store the VHD in Azure.
    .PARAMETER  BlobFileName
        Specifies the file name for VHD to be uploaded to Storage Container.
    .EXAMPLE
        These examples show how to upload a VHD file with specified subscription, resource group, storage and container name.
    
        C:\PS> UploadVHDFromLocalToAzureStorage.ps1 -VHDFile "FullPathOfVHD" -ResourceGroupName "YourGroupName" -StorageAccountName "YourStorageAccountName"  \
		                                            -StorageAccountType "Standard_LRS" -ContainerName "YourContainerName" -BlobFileName "TestCentOSBlobFile.vhd"  \
													-Location "West US"
#>



Param
(
    [String]$VHDFile = "D:\xhxTest\Cloudinit\CloudinitBase.vhd",   # The full path of vhd which is ready to be uploaded to azure.
	
    [String]$ResourceGroupName = "xhxcloudtest",    # Resource group name can only include alphanumeric characters, periods, 
											        # underscores, hyphens and parenthesis and cannot end in a period.
	
    [String]$StorageAccountName = "xhxcloudtest",        # Storage account name must be between 3 and 24 characters in length 
														   # and use numbers and lower-case letters only.
	[Parameter(Mandatory=$false)]
    [String]$StorageAccountType = "Standard_LRS",   # Available options include Standard_LRS, Standard_ZRS, Standard_GRS, 
													# Standard_RAGRS and Premium_LRS. To learn more about the differences 
													# of each storage account type, please consult the below link.
													# https://blogs.msdn.microsoft.com/windowsazurestorage/2013/12/11/windows-azure-storage-redundancy-options-and-read-access-geo-redundant-storage/
	
    [String]$ContainerName = "vhds",     # Valid Container names start and end with a lower case letter or 
											 # a number and has in between a lower case letter, number or dash with 
											 # no consecutive dashes and is 3 through63 characters long.

    [String]$Location = "West US",  		# For a list of all Azure locations, please consult the below link.
											# https://azure.microsoft.com/en-us/regions/
	
    [String]$SubscriptionId = "4be8920b-2978-43d7-ab14-04d8549c1d05",  # Your subscription ID.
	
    [String]$BlobFileName = "xhxcloudtest.vhd"       # The name of vhd file in azure. Any valid name is supported.
)



$InteractiveLogin = $False 	# If you have a service principal certificate authentication, set it "$False". Otherwise, set it "$True"
if( $InteractiveLogin )
{
	Login-AzureRmAccount 	
}
else
{
	# Login azure account via service principal. 
	# NOTE: You must change these parameters with your service principal.
	
	$ServicePrincipalClientID = $env:ServicePrincipalClientID
	$ServicePrincipalTenantID = $env:ServicePrincipalTenantID
	$ServicePrincipalkey = $env:ServicePrincipalkey
	$securePasswd = ConvertTo-SecureString -String $ServicePrincipalkey -AsPlainText -Force
	$cred = New-Object System.Management.Automation.PSCredential($ServicePrincipalClientID,$securePasswd)
	Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId $ServicePrincipalTenantID 
}


# Print some important parameters
" "
"The important parameters list:"
"------------------------------------------------------------"
"Full path of VHD on local: $VHDFile"
"Resource group name: $ResourceGroupName"
"Storage account name: $StorageAccountName"
"Storage account type: $StorageAccountType"
"Container name: $ContainerName"
"Location on Azure: $Location"
"VHD name on Azure: $BlobFileName"
"------------------------------------------------------------"
" "


# Blob has 1G on size limitation, related byte number is used below
$GByteSize = 1073741824

# Build DateTime string for blob name generation and operation purpose
$startDateString = Get-Date -Format yyyy-MM-dd-HH-mm-ss

$isFileExisted = Test-Path $VHDFile
if( $isFileExisted -ne "True" )
{
	Write-Host "The $VHDFile doesn't exist, please check it and try again." -ForegroundColor Red
	return 1
} 

# build Azure Storage File Name: LocalFileName-yyyy-MM-dd-HH-mm-ss.vhd
$FileName = [IO.Path]::GetFileNameWithoutExtension($VHDFile)
if ($BlobFileName.Length -eq 0)
{
	$BlobFileName = "{0}-{1}.vhd" -f $FileName, $startDateString
}

# Check/Prepare subscription, resource group, storage account, container and so on.
Try
{
	# If you have many subscriptions, you can use Select-AzureRmSubscription to select one of them.
	# Otherwise, use the default subscription.
	if( -not $SubscriptionId )
	{
		Select-AzureRmSubscription   -SubscriptionId  $SubscriptionId
	}
	
	$isGroupExsited = Get-AzureRmResourceGroup  Get-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName  2>$null
	if( $isGroupExsited  -eq $null )
	{
	    "The group named $ResourceGroupName doesn't exist, so create it now."
		New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
	}
	
	$isStorageAccoutExsited = Get-AzureRmResource -ResourceName $StorageAccountName -ResourceGroupName $ResourceGroupName  2>$null
	if( $isStorageAccoutExsited  -eq $null )
	{
	    "The storage account named $StorageAccountName doesn't exist, so create it now."
		New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -Type $StorageAccountType -Location $Location
	}
	
    Set-AzureRmCurrentStorageAccount -ResourceGroupName  $ResourceGroupName  -Name $StorageAccountName 

    $StorageKey = (Get-AzurermStorageAccountKey  -Name $StorageAccountName -ResourceGroupName $ResourceGroupName).Value[0]
    $sourceContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKey
    $blobContainer = Get-AzureStorageContainer -Name $ContainerName -Context $sourceContext 2>$null
	if( $blobContainer -eq $null )
	{
		"The container named $ContainerName doesn't exist, so create it now."
		New-AzureStorageContainer -Name $ContainerName -Context $sourceContext
		sleep 3
		$blobContainer = Get-AzureStorageContainer -Name $ContainerName -Context $sourceContext
	}
	
    # Build path for VHD BlobPage file uploading
    $mediaLocation = $blobContainer.CloudBlobContainer.Uri.ToString() + "/" + $BlobFileName
}
Catch
{
    Write-Host "Check/Prepare subscription, resource group, storage account and container failed." -ForegroundColor Red
    Write-Host "Please check the validity of subscription, resource group, storage account and container, and try again." -ForegroundColor Red
	Write-Host $ERROR[0].Exception
    return 1
}


Try
{
	# Upload VHD 
	"Upload the specified VHD to $mediaLocation."
	Add-AzureRmVhd -ResourceGroupName $ResourceGroupName -LocalFilePath $VHDFile -Destination $mediaLocation -NumberOfUploaderThreads 64 -OverWrite
	Write-Host "'$BlobFileName' uploaded successfully." -ForegroundColor Green
}
Catch
{
	Write-Host "Upload VHD Failed." -ForegroundColor Red
	Write-Host $ERROR[0].Exception
}


