# List of subscriptions to add to the scope
$subLists = @(

    "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
)

<# You can also add management groups to the scope.I will skip this for now

$mgmtGroups = @(

    "/providers/Microsoft.Management/managementGroups/2596de33-c183-49cc-966f-069cfce79321"
)

#>

# define the access types for the scope
$accessTypes = @(

        "Connectivity",
        "SecurityAdmin"
)




$scope = New-AzNetworkManagerScope -Subscription $subLists

# Provide the scope and access types to the New-AzNetworkManagerScope cmdlet

$resourceDef = @{

    Name                      = 'avnm'       # Name of the network manager
    ResourceGroupName         = $rgDef.Name  # Resource group name
    NetworkManagerScope       = $scope       # Scope of the network manager
    NetworkManagerScopeAccess = $accessTypes # Access types for the scope
    Location                  = $location    # Location of the network manager

}

$networkmanager = New-AzNetworkManager @resourceDef # Create the network manager