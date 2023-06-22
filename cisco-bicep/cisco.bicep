
/******************************************************/
/* User Parameters to set the VPN device connectivity */
/******************************************************/

@description('The Azure Region in which to create the resources')
param location string = resourceGroup().location

@description('Admin username for the servers')
param adminUsername string

@description('Password for the admin account on the servers')
@secure()
param adminPassword string

@description('Your public IP address, for SSH to the vm')
param myIP string

@description('VM size to be deployed (be careful of quota available in specified region)')
param vmsize string = 'Standard_D2as_v5'

@description('Name of the Virtual Network object')
param VnetName string = 'ciscoNVA'

@description('Public IP address of the VPN Gateway')
param remotePubIP string

@description('BGP peering address of the VPN Gateway')
param remoteBGPIP string

@description('ASN of the VPN Gateway')
param remoteASN string = '65515'

@description('ASN of this device, do not use reserved ASNs')
param localASN string = '65503'

@description('Address space of the local Virtual Network this VM will be deployed to')
param addrSpace string = '10.5.0.0/16'

@description('Private subnet CIDR address range, must be within address space')
param inside string = '10.5.0.0/24'

@description('Public subnet CIDR address range, must be within address space')
param outside string = '10.5.1.0/24'

@description('Pre-shared key for the VPN Gateway, must match on both sides')
param PreSharedKey string

@description('Unique local IP address, not used in other address space, for the local BGP tunnel on this device')
param tunnelBGPLocal string = '192.168.3.1'


/******************************************************/
/* Variables used internally to set IP parameters     */
/******************************************************/

var tunnelBGPRemote = cidrHost(tunnelBGPLocal, 1)
var insideIP = parseCidr(inside)
var insideHost = cidrHost(inside, 3)
var insideGW = cidrHost(inside, 0)
var outsideHost = cidrHost(outside, 3)

/***********************************************************/
/* IOS config, this is pushed to the device at vm creation */
/***********************************************************/

var IOSconfig = '''Section: IOS configuration
!
ip vrf AzureVpn
 rd 65000:65000
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
 ip vrf forwarding AzureVpn
 ip address TUNNEL_BGP_LOCAL 255.255.255.255
!
interface Tunnel11
 ip vrf forwarding AzureVpn
 ip address TUNNEL_BGP_REMOTE 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source OUTSIDE_IP
 tunnel mode ipsec ipv4
 tunnel destination REMOTE_GW_IP
 tunnel protection ipsec profile to-Azure-IPsecProfile
!
interface GigabitEthernet2
 ip vrf forwarding AzureVpn
 ip address dhcp
 negotiation auto
 no mop enabled
 no mop sysid
!
router bgp LOCAL_ASN
 bgp router-id TUNNEL_BGP_LOCAL
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf AzureVpn
  network INSIDE_CIDR mask NETMASK
  neighbor REMOTE_BGP_IP remote-as REMOTE_ASN
  neighbor REMOTE_BGP_IP ebgp-multihop 255
  neighbor REMOTE_BGP_IP update-source Loopback11
  neighbor REMOTE_BGP_IP activate
 exit-address-family
!
!Static route to On-Prem-VNG BGP ip pointing to Tunnel11, so that it would be reachable
ip route vrf AzureVpn REMOTE_BGP_IP 255.255.255.255 Tunnel11
!Static route for Subnet-1 pointing to CSR default gateway of internal subnet, this is added in order to be able to advertise this route using BGP
ip route vrf AzureVpn INSIDE_CIDR NETMASK INSIDE_GW
!
ip access-list extended icmpdump
 10 permit icmp any any'''

/***********************************************************/
/* Replace variables in config above with parameters       */
/***********************************************************/

var firstOutput = replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(IOSconfig, 'OUTSIDE_IP', outsideHost), 'INSIDE_CIDR', insideIP.network), 'REMOTE_GW_IP', remotePubIP), 'REMOTE_ASN', remoteASN), 'LOCAL_ASN', localASN), 'PRE_SHARED_KEY', PreSharedKey), 'TUNNEL_BGP_LOCAL', tunnelBGPLocal), 'TUNNEL_BGP_REMOTE', tunnelBGPRemote), 'REMOTE_BGP_IP', remoteBGPIP), 'INSIDE_GW', insideGW), 'NETMASK', insideIP.netmask)

/***********************************************************/
/* Create Azure resource objects                           */
/***********************************************************/

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: VnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addrSpace
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource subnet_inside 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: virtualNetwork
  name: 'inside'
  properties: {
    addressPrefix: inside
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: nsg_nva.id
    }
  }
}

resource subnet_outside 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: virtualNetwork
  name: 'outside'
  properties: {
    addressPrefix: outside
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: nsg_nva.id
    }
  }
}

resource nsg_nva 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'ciscoNVA-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: myIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      {
        name: 'ISAKMP'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '500'
          sourceAddressPrefix: remotePubIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 310
          direction: 'Inbound'
        }
      }
      {
        name: 'IPSEC'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '4500'
          sourceAddressPrefix: remotePubIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 320
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'ciscoNVA-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource netInterface_outside 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: 'outside_nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: outsideHost
          subnet: {
            id: subnet_outside.id
          }
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: true
  }
}

resource netInterface_inside 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: 'inside_nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: insideHost
          subnet: {
            id: subnet_inside.id
          }
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: true
  }
  dependsOn: [
    netInterface_outside
  ]
}

/**************************************************************************************************************************
 If you have not run this script before you must accept marketplace terms by running Powershell below before
 running this script.

 $pubName = Get-AzVMImagePublisher -Location $loc | Where-Object PublisherName -Like "Cisco" | Select-Object PublisherName
 $offerName = Get-AzVMImageOffer -Location $loc -PublisherName $pubName.PublisherName | Where-Object Offer -eq 'cisco-csr-1000v'
 $skuName = Get-AzVMImageSku -Location $loc -PublisherName $pubName.PublisherName -Offer $offerName.Offer | Where-Object Skus -eq '17_3_4a-byol'
 $version = Get-AzVMImage -Location $loc -PublisherName $pubName.PublisherName -Offer $offerName.Offer -Sku $skuName.Skus | Select-Object Version
 Set-AzMarketplaceTerms -Publisher $pubName.PublisherName -Product $offerName.Offer -Name $skuName.Skus -Accept

 **************************************************************************************************************************/

resource vm_cisconva 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'ciscoNVA'
  location: location
  plan: {
    name: '17_3_4a-byol'
    product: 'cisco-csr-1000v'
    publisher: 'cisco'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmsize
    }
    storageProfile: {
      imageReference: {      
        publisher: 'cisco'
        offer: 'cisco-csr-1000v'
        sku: '17_3_4a-byol'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: 'ciscoNVA'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(firstOutput)
      linuxConfiguration: {
        provisionVMAgent: true
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          properties: {
            primary: true
          }
          id: netInterface_outside.id
        }
        {
          properties: {
            primary: false
          }
          id: netInterface_inside.id
        }
      ]
    }
  }
}

output hostname string = 'ssh ${adminUsername}@${publicIp.properties.ipAddress}'
