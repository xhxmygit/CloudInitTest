
.\PrepareImageForCloudinit.ps1

$vhdPath = "$pwd" +"\CloudinitBase.vhd"
.\Upload_VHD_FromLocalToAzureStorage_ARMv140.ps1   -VHDFile $vhdPath
