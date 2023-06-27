
## Azure Virtual WAN Routing Intent with Cisco BGP VPN force tunneling Lab

In this lab you will learn how to set-up a Cisco CSR1000V VPN connected to Azure via IPSEC tunnel with BGP. The Cisco device will receive the default route from Azure (0/0) which will force tunnel all traffic from the remote site to Azure including internet traffic. Azure Virtual WAN will be setup in a standard multi-region deployment with routing intent turned on. The base lab should be deployed via the Deploy to Azure button below and can be re-used to create a multi-region Virtual WAN deployment for other needs.

##### Key learnings:
- Bicep automation of the deployment as well as walkthrough of the steps to setup the VPN configuration in PowerShell
- Repeatable deployment templates for setting up Virtual WAN or multiple VPN devices
- Setting up VRF's on the Cisco device so that force tunneling can be enabled
- How Virtual WAN routing intent changes the routing pattern
- Verify any-to-any flows enabled through secured hub
- DNAT configuration to access spoke VM's
- Static routing for for simulated on-premises in Azure

##### Use Cases


##### Future Extensions coming soon (~Fall 2023)
- DMZ egress spoke with 3rd party network virtual appliance
- Replace Azure Firewall with 3rd party firewall in the hub
- Use of Azure Route Server for dynamic routing for simulated on-premises in Azure


##### Topology

Here is the overall topology of what will be deployed as part of this lab. The first deployment script (Virtual WAN base lab deploy) deploys the blue boxes and the second deployment script (Cisco deploy) partially deploys the green box. The remainder of the green box will be deployed manually as a learning exercise.

![topology](https://raw.githubusercontent.com/bcosden/azure-cisco-bgp-lab/master/assets/azure-virtualwan-cisco-vpn-topology.png)

Let's begin

#### Step 1: Deploy the Virtual WAN

##### Virtual WAN base lab deploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbcosden%2Fazure-cisco-bgp-lab%2Fmaster%2Fvwan-arm%2Fvwan.json)

Use the button above to deploy the base Virtual deployment. This script was written in Bicep and compiled to ARM Json format so that it can be deployed above.

In the example the regions used were North Central US and West Central US but feel free to use any two different regions.

The deployment will take about 45 minutes.

#### Step 2: Verify the configuration

Now that it is deployed, let's take a deeper look at what is deployed:
- In Virtual WAN you can see both hubs have a secured hub deployed (Azure Firewall). The firewall object is managed by Virtual WAN and configuration is managed via Azure Firewall Policies
- In the Virtual WAN hub we can also see Routing Intent is turned on for both private and public traffic.

![route intent)](https://raw.githubusercontent.com/bcosden/azure-cisco-bgp-lab/master/assets/azure-virtualwan-route-intent.png)

Note: The customer can identify which prefixes should be treated as private by routing intent. (BROKEN AT THE MOMENT)

This means that all traffic both private and public is forced to the Azure Firewall in each hub via private aggregates and default route. In the Virtual WAN hub route tables you can see the default route table is advertising the Internet and Private policy ranges while propagating to None. Which means the connections to Virtual WAN will not propagate their specific routes. Only the policy routes will be visible to resources connected to Virtual WAN. 

![route tables)](https://raw.githubusercontent.com/bcosden/azure-cisco-bgp-lab/master/assets/azure-virtualwan-defaultroutetables.png)

![default route)](https://raw.githubusercontent.com/bcosden/azure-cisco-bgp-lab/master/assets/azure-virtualwan-default-routes.png)

- There are two firewalls once in each region and two firewall policies for each region. The reason why is because we have DNAT rules attached to each hub to reach the Virtual Machines. Since the Internet policy is turned on and 0/0 is pushed to the spokes, Virtual Machines in the spokes will not have direct internet access and must go through the firewall.

	Note the source will be the IP you entered at deployment time which should be your public IP address.

![dnat](https://raw.githubusercontent.com/bcosden/azure-cisco-bgp-lab/master/assets/azure-virtualwan-azfw-dnat.png)

Additionally note that the default Azure Firewall policy is allow all in the network rules. Locking down Azure Firewall rules is left as an exercise to the reader and will be a deep dive topic in a future lab.

#### Step 3: Cisco Deploy

The intent here is to go through the manual deployment instructions. However, if you would like to skip the manual deployment you can use the automation here:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbcosden%2Fazure-cisco-bgp-lab%2Fmaster%2Fcisco-arm%2Fcisco.json)

This is also a Bicep deployment script compiled into ARM Json. This script can be re-used to create multiple VPN deployments quickly by setting a few IP parameters. The script will create the VPN parameters and BGP tunnel to the remote.

For those that want to understand this process better, we will use the PowerShell script to go through it section by section.

The parameters below is all that is necessary to establish a VPN connection with Azure with BGP using this script.

The remotePubIP and remoteBGPIP represent the Azure VPN Gateway public IP address and BGP peering address.

Azure's default ASN for gateways is 65515. In hub and spoke you can change the BGP ASN but in Virtual WAN you must use 65515 (as of publication of this lab)

Local ASN should use a private ASN that is not reserved by Azure:
[Azure Route Server frequently asked questions (FAQ) | Microsoft Learn](https://learn.microsoft.com/en-us/azure/route-server/route-server-faq#what-autonomous-system-numbers-asns-can-i-use)

The address space represents your local Vnet private address space that will be used for the inside (private) Cisco interface. Note that the outside interface will also have a private address from a different subnet. However, the outside interface will be addressed via the public IP address associated with it. The reason we have two subnets is so that we can isolate 0/0 routes and keep the tunnel up, while private resources, attached to the inside subnet will be forced over the tunnel to Azure.

Feel free to change the pre-shared key but ensure the same key is used on both sides.

The tunnel BGP local will be a loopback interface on the NVA device that will receive BGP updates from the remote side. And the remote tunnel represents the far side connection but really is not visible to Azure.

```PowerShell
$rg = "vwan-cisco-west"
$loc = "westcentralus"
$vmsize = "Standard_D2as_v5"
$VnetName = "ciscoWestNVA"
$remotePubIP = "20.69.51.238"
$remoteBGPIP = "10.8.1.14"
$remoteASN = "65515"
$localASN = "65503"
$addrSpace = "10.5.0.0/16"
$inside = "10.5.0.0/24"
$outside = "10.5.1.0/24"
$PreSharedKey = "abc123"
$tunnelBGPLocal = "192.168.3.1"
$tunnelBGPRemote = "192.168.4.1"
```


Here we get the right image from the Azure Marketplace. We want the Cisco CSR100V 17.3.4.a bring your own license version.

```PowerShell
$pubName = Get-AzVMImagePublisher -Location $loc | Where-Object PublisherName -Like "Cisco" | Select-Object PublisherName
$offerName = Get-AzVMImageOffer -Location $loc -PublisherName $pubName.PublisherName | Where-Object Offer -eq 'cisco-csr-1000v'
$skuName = Get-AzVMImageSku -Location $loc -PublisherName $pubName.PublisherName -Offer $offerName.Offer | Where-Object Skus -eq '17_3_4a-byol'
$version = Get-AzVMImage -Location $loc -PublisherName $pubName.PublisherName -Offer $offerName.Offer -Sku $skuName.Skus | Select-Object Version

Set-AzMarketplaceTerms -Publisher $pubName.PublisherName -Product $offerName.Offer -Name $skuName.Skus -Accept
```

We then create some NSG rules. Allow SSH on the public interface for only your source IP address, so it is not opened to the world. This is one of the reasons that we have an outside interface. With this interface in this subnet, we always have management access to the device.

```PowerShell
$rule1 = New-AzNetworkSecurityRuleConfig -Name "Allow-SSH" `
	-Description "Allow SSH" `
	-Access Allow -Protocol Tcp `
	-Direction Inbound `
	-Priority 100 `
	-SourceAddressPrefix $myip `
	-SourcePortRange * `
	-DestinationAddressPrefix * `
	-DestinationPortRange 22

$rule2 = New-AzNetworkSecurityRuleConfig -Name "Allow-ISKAMP" `
    -Description "Allow-ISKAMP" `
    -Access Allow -Protocol * `
    -Direction Inbound `
    -Priority 110 `
    -SourceAddressPrefix $remotePubIP `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 500

$rule3 = New-AzNetworkSecurityRuleConfig -Name "Allow-IPSEC" `
    -Description "Allow-IPSEC" `
    -Access Allow -Protocol * `
    -Direction Inbound `
    -Priority 120 `
    -SourceAddressPrefix $remotePubIP `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 4500

$nsg = New-AzNetworkSecurityGroup -Name "cisco-nsg" -ResourceGroupName $rg -Location $loc -SecurityRules $rule1, $rule2, $rule3
```


Here we create the NIC's for the outside and inside subnets. The first part of this script does some string manipulation to change the CIDR network in the parameters to an actual host IP address.

```PowerShell
$outmatch = ($outside | Select-String -Pattern $matchStr)
$outsideIP = "$($outmatch.Matches.Value)4"

$inmatch = ($inside | Select-String -Pattern $matchStr)
$insideIP = "$($inmatch.Matches.Value)4"

$nic1 = New-AzNetworkInterface -Name "outside" `
	-ResourceGroupName $rg `
	-Location $loc `
	-SubnetId $Vnet.Subnets[1].Id `
	-PublicIpAddressId $PIP.Id `
	-PrivateIpAddress $outsideIP `
	-EnableIPForwarding

$nic2 = New-AzNetworkInterface -Name "inside" `
	-ResourceGroupName $rg `
	-Location $loc `
	-SubnetId $vnet.Subnets[0].Id `
	-PrivateIpAddress $insideIP `
	-EnableIPForwarding
```

And here is where the magic happens. We will take a look at the Cisco IOS config next but first, here is where we set the string replacement values and load the IOS script into a variable to being the replacement. The first part of this script does some more string manipulation to create the Gateway host IP address and create the correct netmask format. While the parameters specify CIDR format (/24), Cisco IOS configuration requires netmask format: 255.255.255.0

Then we load the file called 'bootstrap' in the same directory and being the replacement. The output is a Cisco ready script with all the values filled out correctly in a variable.

```PowerShell

$incidr = ($inside | Select-String -Pattern $matchStr)
$insideGW = "$($incidr.Matches.Value)1"

$ciscoInside = ($inside -split "/")
$netmask = Get-NetworkIPv4 $ciscoInside[0] $ciscoInside[1]

$file = ((Get-Content .\bootstrap) | ForEach-Object {
		$_.replace('OUTSIDE_IP', $outsideIP).
		replace('INSIDE_CIDR', $ciscoInside[0]). `
			replace('NETMASK', $netmask.SubnetMask.IPAddressToString). `
			replace('REMOTE_GW_IP', $remotePubIP). `
			replace('PRE_SHARED_KEY', $PreSharedKey). `
			replace('TUNNEL_BGP_LOCAL', $tunnelBGPLocal). `
			replace('TUNNEL_BGP_REMOTE', $tunnelBGPRemote). `
			replace('REMOTE_BGP_IP', $remoteBGPIP). `
			replace('LOCAL_ASN', $localASN). `
			replace('REMOTE_ASN', $remoteASN). `
			replace('INSIDE_GW', $insideGW) `
	} | Out-String)
```

Finally, we create the Virtual Machine. The New-AzVMConfig uses the parameters from the Azure Marketplace to identify the VM Image. The Operating system is set to Linux and we set a custom data field which is the output string of the above replacement script. This will inject the script into the bootstrap field of the Virtual Machine which will be configured by Cisco on boot up of the VM.

```Powershell
$config = New-AzVMConfig -VMName "ciscoNVA" -VMSize $vmsize | Set-AzVMPlan -Publisher $pubName.PublisherName -Product $offerName.Offer -Name $skuName.Skus
$config = Set-AzVMOperatingSystem -VM $config -Linux -ComputerName "cisco" -Credential $cred -CustomData $file
$config = Add-AzVMNetworkInterface -VM $config -Id $nic1.Id -Primary
$config = Add-AzVMNetworkInterface -VM $config -Id $nic2.Id
$config = Set-AzVMSourceImage -VM $config -PublisherName $pubName.PublisherName -Offer $offerName.Offer -Skus $skuName.Skus -Version $version.Version
```

And now here is the raw Cisco IOS configuration file without parameter replacement. We will be able to see the final script after deployment by logging into the Cisco device.

However, the VPN parameters are key here. Illustrated below is the matching IPSEC Phase 1 and Phase 2 parameters of the VPN that is required in order to ensure Azure and Cisco are speaking the same crypto language.

We will go through this configuration in more detail after deployment and then add VRF's to this so that we can push the 0/0 down the VPN tunnel.

```bash
Section: IOS configuration
!
crypto ikev2 proposal Azure-Ikev2-Proposal
 encryption aes-cbc-256
 integrity sha1 sha256
 group 2
!
crypto ikev2 policy Azure-Ikev2-Policy
 match address local OUTSIDE_IP 
 proposal Azure-Ikev2-Proposal
!
crypto ikev2 keyring to-onprem-keyring
 peer REMOTE_GW_IP
  address REMOTE_GW_IP
  pre-shared-key PRE_SHARED_KEY
!
crypto ikev2 profile Azure-Ikev2-Profile
 match address local OUTSIDE_IP 
 match identity remote address REMOTE_GW_IP 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local to-onprem-keyring
 lifetime 28800
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-Azure-TransformSet esp-gcm 256
 mode tunnel
!
crypto ipsec profile to-Azure-IPsecProfile
 set transform-set to-Azure-TransformSet
 set ikev2-profile Azure-Ikev2-Profile
!
interface Loopback11
 ip address TUNNEL_BGP_LOCAL 255.255.255.255
!
interface Tunnel11
 ip address TUNNEL_BGP_REMOTE 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source OUTSIDE_IP
 tunnel mode ipsec ipv4
 tunnel destination REMOTE_GW_IP
 tunnel protection ipsec profile to-Azure-IPsecProfile
!
router bgp LOCAL_ASN
 bgp router-id TUNNEL_BGP_LOCAL
 bgp log-neighbor-changes
 neighbor REMOTE_BGP_IP remote-as REMOTE_ASN
 neighbor REMOTE_BGP_IP ebgp-multihop 255
 neighbor REMOTE_BGP_IP update-source Loopback11
 !
 address-family ipv4
  network INSIDE_CIDR mask NETMASK
  neighbor REMOTE_BGP_IP activate
 exit-address-family
!
!Static route to On-Prem-VNG BGP ip pointing to Tunnel11, so that it would be reachable
ip route REMOTE_BGP_IP 255.255.255.255 Tunnel11
!Static route for Subnet-1 pointing to CSR default gateway of internal subnet, this is added in order to be able to advertise this route using BGP
ip route INSIDE_CIDR NETMASK INSIDE_GW
!
ip access-list extended icmpdump
 10 permit icmp any any
```

Please deploy the Powershell sections above in your local shell that is logged into Azure. Make sure the bootstrap file is in the same directory as the one in which you are deploying the Powershell.

The deployment will take about 20 minutes and post deployment the VM will not be ready for ssh login for about 5 minutes.



##### Results


##### Contact Microsoft for



