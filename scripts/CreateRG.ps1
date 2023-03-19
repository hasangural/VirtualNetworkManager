
$subscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

$location = "UK South"

$rgDef = @{
    Name = 'TailspinToys-AVNM'
    Location = $location
}

Select-Azsubscription -subscriptionId $subscriptionId

New-AzResourceGroup @rgDef