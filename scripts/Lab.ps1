

$networkMap = @{
    "vnet-a" = @{
        AddressPrefix = "10.0.0.0/24"
        Subnets = @{
            "subnet-a" = @{ AddressPrefix = "10.0.0.0/24" }
        } 
    }
    "vnet-b" = @{
        AddressPrefix = "10.0.1.0/24"
        Subnets = @{
            "subnet-b" = @{ AddressPrefix = "10.0.1.0/24" }
        }
    }
    "vnet-c" = @{
        AddressPrefix = "10.0.2.0/24" 
        Subnets = @{
            "subnet-c" = @{ AddressPrefix = "10.0.2.0/24"}
        } 
    }
}

ForEach($nw in $networkMap.Keys) {

    $properties = @{

        Name = $nw                                    # Name of the virtual network from the network map                                      
        AddressPrefix = $networkMap.$nw.AddressPrefix # Address prefix for the virtual network.
        ResourceGroupName = $rgDef.Name                    # Resource group name
        Location = "uksouth"                               # Location of the virtual network

        Subnet = foreach($subnet in $networkMap.$nw.Subnets.Keys){

            Write-Information "Creating subnet configuration for subnet '$subnet', in network '$nw'" -InformationAction Continue
            New-AzVirtualNetworkSubnetConfig -Name $subnet -AddressPrefix $networkMap.$nw.Subnets.$subnet.AddressPrefix
        }
    }

    New-AzVirtualNetwork @properties -force | Out-Null
}


$networkGroupMap = @{
    "networkGroup-01" = @{
        NetworkManagerName = $networkManager.Name # It is the name of the Azure Virtual Network Manager Resource. Variable name is $networkManager.
        ResourceGroupName  = $rgDef.Name  # Resource group name. We have created it in the previous post. Variable name is $rgDef.
    }
    "networkGroup-02" = @{
        NetworkManagerName = $networkManager.Name
        ResourceGroupName  = $rgDef.Name
    }
}

ForEach ($ng in $networkGroupMap.Keys) {

    $properties = @{
        Name = $ng
        NetworkManagerName  = $networkGroupMap.$ng.NetworkManagerName
        ResourceGroupName   = $networkGroupMap.$ng.ResourceGroupName
    }

    New-AzNetworkManagerGroup @properties -force | Out-Null
}


$memberNetworkGroupMap = @{ # This is a map of network groups and their members.

    "networkGroup-01" = @{
        NetworkManagerName = $networkManager.Name
        ResourceGroupName  = $rgDef.Name
        VirtualNetworks = @("vnet-a", "vnet-b") # we will iterate through this list and add the virtual networks to the network group.
    }

    "networkGroup-02" = @{
        NetworkManagerName = $networkManager.Name
        ResourceGroupName  = $rgDef.Name
        VirtualNetworks = @("vnet-c")
    }
}

ForEach ($member in $memberNetworkGroupMap.Keys) {

    ForEach($vnet in $memberNetworkGroupMap.$member.VirtualNetworks) {

        $vNetId = (Get-AzVirtualNetwork -Name $vnet -ResourceGroupName $rgDef.Name).Id

        $properties = @{

            Name               = $vnet
            NetworkGroupName   = $member
            NetworkManagerName = $memberNetworkGroupMap.$member.NetworkManagerName
            ResourceGroupName  = $memberNetworkGroupMap.$member.ResourceGroupName
            ResourceId         = $vNetId
        }

        New-AzNetworkManagerStaticMember @properties -force | Out-Null
    }
}



# Retrieve the network group Id from the network group name - networkGroup-01

$NetWorkGroupId = Get-AzNetworkManagerGroup -Name "networkGroup-01" -NetworkManagerName avnm -ResourceGroupName TailspinToys-AVNM

# Create a network group item
$NetworkGroupItem = @{

    NetworkGroupId = $NetWorkGroupId.Id
}

$getGroupItem = New-AzNetworkManagerConnectivityGroupItem @networkGroupItem

# Create a connectivity configuration
$groupConfig = @()

# Add the network group item to the connectivity configuration
$groupConfig += $getGroupItem

# Create the connectivity configuration
$config = @{

    Name                  = 'Mesh-ConnectivityConfig-01'
    ResourceGroupName     = $rgDef.Name
    NetworkManagerName    = $networkManager.Name
    ConnectivityTopology  = 'Mesh'
    AppliesToGroup        = $groupConfig

}

$MeshConnectivityConfig = New-AzNetworkManagerConnectivityConfiguration @config


# Gather the confguration Ids
$meshConfigIds = @()
$meshConfigIds += $MeshConnectivityConfig.Id

# Gather the effected regions
$meshEffectedRegions = @()
$meshEffectedRegions += "uksouth"

# Build the deployment object
$avnmDeployment = @{

    Name              = $networkManager.Name
    ResourceGroupName = $rgDef.Name
    ConfigurationId   = $meshConfigIds
    TargetLocation    = $meshEffectedRegions
    CommitType        = 'Connectivity'

}

# Deploy the configuration
Deploy-AzNetworkManagerCommit @avnmDeployment


$virtualMachinesMap = @{

    "ubuntu-a" = @{

        "ResourceGroupName" = $rgDef.Name
        "Location"          = "uksouth"
        "Size"              = "Standard_B1s"
        "Image"             = "Canonical:UbuntuServer:18.04-LTS:latest"
        "vNetName"          = "vnet-a"
        "SubnetName"        = "subnet-a"
        "UserName"          = "admin-a"
        "Password"          = "AVNMLab123!"

    }
    "ubuntu-b" = @{

        "resourceGroupName" = $rgDef.Name
        "Location"          = "uksouth"
        "Size"              = "Standard_B1s"
        "Image"             = "Canonical:UbuntuServer:18.04-LTS:latest"
        "vNetName"          = "vnet-b"
        "SubnetName"        = "subnet-b"
        "UserName"          = "admin-b"
        "Password"          = "AVNMLab123!"
    }

}

ForEach ($vm in $virtualMachinesMap.Keys) {

    $properties = @{

        Name               = $vm
        ResourceGroupName  = $virtualMachinesMap.$vm.ResourceGroupName
        Location           = $virtualMachinesMap.$vm.Location
        VirtualNetworkName = $virtualMachinesMap.$vm.vNetName
        SubnetName         = $virtualMachinesMap.$vm.SubnetName
        Size               = $virtualMachinesMap.$vm.Size
        Image              = $virtualMachinesMap.$vm.Image
        SecurityGroupName  = $vm
        OpenPorts          = @("22")
        Credential         = New-Object System.Management.Automation.PSCredential($virtualMachinesMap.$vm.UserName, (ConvertTo-SecureString -String $virtualMachinesMap.$vm.Password -AsPlainText -Force))
        
    }

    New-AzVm @properties -AsJob 
}


# This will help us to get effective routes for ubuntu-a
Get-AzEffectiveRouteTable -ResourceGroupName TailspinToys-AVNM -NetworkInterfaceName ubuntu-a | Format-Table -AutoSize

# Vice versa
Get-AzEffectiveRouteTable -ResourceGroupName TailspinToys-AVNM -NetworkInterfaceName ubuntu-b | Format-Table -AutoSize