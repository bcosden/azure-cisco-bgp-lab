
@description('Admin username for the servers')
param adminUsername string

@description('Password for the admin account on the servers')
@secure()
param adminPassword string

@description('Location for all resources.')
param location string = resourceGroup().location
param secLocation string

param myIP string

var vmSize = 'Standard_D2as_v5'

resource virtualWan 'Microsoft.Network/virtualWans@2022-11-01' = {
  name: 'VWan'
  location: location
  properties: {
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
}

resource policy1 'Microsoft.Network/firewallPolicies@2022-11-01' = {
  name: 'AzfwPolicy1'
  location: location
  properties: {
    threatIntelMode: 'Alert'
  }
}

resource ruleCollectionGroup1 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: policy1
  name: 'DefaultNetworkRuleCollectionGroup1'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRuleCollection'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-All'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
          }
        ]
      }
    ]
  }
}

resource ruleCollectionGroup11 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: policy1
  name: 'DefaultDnatRuleCollectionGroup1'
  properties: {
    priority: 310
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'DnatRuleCollection'
        priority: 110
        action: {
          type: 'Dnat'
        }
        rules: [
          {
            ruleType: 'NatRule'
            name: 'Dnat-Hub1Spoke1VM'
            sourceAddresses: [
              myIP
            ]
            destinationAddresses: [
              firewall1.properties.hubIPAddresses.publicIPs.addresses[0].address
            ]
            destinationPorts: [
              '3389'
            ]
            translatedAddress: Hub1Spoke1VM_netInterface.properties.ipConfigurations[0].properties.privateIPAddress
            translatedPort: '3389'
            ipProtocols: [
              'TCP'
            ]
          }
          {
            ruleType: 'NatRule'
            name: 'Dnat-Hub1Spoke2VM'
            sourceAddresses: [
              myIP
            ]
            destinationAddresses: [
              firewall1.properties.hubIPAddresses.publicIPs.addresses[0].address
            ]
            destinationPorts: [
              '3390'
            ]
            translatedAddress: Hub1Spoke2VM_netInterface.properties.ipConfigurations[0].properties.privateIPAddress
            translatedPort: '3389'
            ipProtocols: [
              'TCP'
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [
    Hub1Spoke1VM
    Hub1Spoke2VM
    ruleCollectionGroup1
  ]
}

resource firewall1 'Microsoft.Network/azureFirewalls@2022-11-01' = {
  name: 'Az${location}HubFirewall'
  location: location
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: 'Standard'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    virtualHub: {
      id: virtualHub1.id
    }
    firewallPolicy: {
      id: policy1.id
    }
  }
}

resource policy2 'Microsoft.Network/firewallPolicies@2022-11-01' = {
  name: 'AzfwPolicy2'
  location: secLocation
  properties: {
    threatIntelMode: 'Alert'
  }
}

resource ruleCollectionGroup2 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: policy2
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRuleCollection'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-All'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
          }
        ]
      }
    ]
  }
}

resource ruleCollectionGroup21 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: policy2
  name: 'DefaultDnatRuleCollectionGroup1'
  properties: {
    priority: 310
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'DnatRuleCollection'
        priority: 110
        action: {
          type: 'Dnat'
        }
        rules: [
          {
            ruleType: 'NatRule'
            name: 'Dnat-Hub2Spoke1VM'
            sourceAddresses: [
              myIP
            ]
            destinationAddresses: [
              firewall2.properties.hubIPAddresses.publicIPs.addresses[0].address
            ]
            destinationPorts: [
              '3389'
            ]
            translatedAddress: Hub2Spoke1VM_netInterface.properties.ipConfigurations[0].properties.privateIPAddress
            translatedPort: '3389'
            ipProtocols: [
              'TCP'
            ]
          }
          {
            ruleType: 'NatRule'
            name: 'Dnat-Hub2Spoke2VM'
            sourceAddresses: [
              myIP
            ]
            destinationAddresses: [
              firewall2.properties.hubIPAddresses.publicIPs.addresses[0].address
            ]
            destinationPorts: [
              '3390'
            ]
            translatedAddress: Hub2Spoke2VM_netInterface.properties.ipConfigurations[0].properties.privateIPAddress
            translatedPort: '3389'
            ipProtocols: [
              'TCP'
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [
    Hub2Spoke1VM
    Hub2Spoke2VM
    ruleCollectionGroup2
  ]
}

resource firewall2 'Microsoft.Network/azureFirewalls@2022-11-01' = {
  name: 'Az${secLocation}HubFirewall'
  location: secLocation
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: 'Standard'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    virtualHub: {
      id: virtualHub2.id
    }
    firewallPolicy: {
      id: policy2.id
    }
  }
}

resource vpnGateway 'Microsoft.Network/vpnGateways@2022-11-01' = {
  name: '${secLocation}VpnGateway'
  location: secLocation
  properties: {
    vpnGatewayScaleUnit: 1
    virtualHub: {
      id: virtualHub2.id
    }
    bgpSettings: {
      asn: 65515
    }
  }
  dependsOn: [
    virtualWan
  ]
}

resource virtualHub1 'Microsoft.Network/virtualHubs@2022-11-01' = {
  name: '${location}Hub'
  location: location
  properties: {
    addressPrefix: '10.8.0.0/24'
    virtualWan: {
      id: virtualWan.id
    }
  }
}

resource virtualHub2 'Microsoft.Network/virtualHubs@2022-11-01' = {
  name: '${secLocation}Hub'
  location: secLocation
  properties: {
    addressPrefix: '10.8.1.0/24'
    virtualWan: {
      id: virtualWan.id
    }
  }
}

resource routeIntent1 'Microsoft.Network/virtualHubs/routingIntent@2022-11-01' = {
  name: 'routeIntent1'
  parent: virtualHub1
  properties: {
    routingPolicies: [
      {
        destinations: [
          'Internet'
        ]
        name: 'RoutePolicyInternet'
        nextHop: firewall1.id
      }
      {
        destinations: [
          'PrivateTraffic'
        ]
        name: 'RoutePolicyPrivate'
        nextHop: firewall1.id
      }
    ]
  }
}

resource routeIntent2 'Microsoft.Network/virtualHubs/routingIntent@2022-11-01' = {
  name: 'routeIntent2'
  parent: virtualHub2
  properties: {
    routingPolicies: [
      {
        destinations: [
          'Internet'
        ]
        name: 'RoutePolicyInternet'
        nextHop: firewall2.id
      }
      {
        destinations: [
          'PrivateTraffic'
        ]
        name: 'RoutePolicyPrivate'
        nextHop: firewall2.id
      }
    ]
  }
}

/* Location Spoke 1 connected to VWan hub LocationHub */
resource virtualNetwork1 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: '${location}Spoke1'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/24'
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource subnet_app1 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: virtualNetwork1
  name: 'app'
  properties: {
    addressPrefix: '10.10.0.0/28'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

/* Location Spoke 2 connected to VWan hub LocationHub */
resource virtualNetwork2 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: '${location}Spoke2'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.1.0/24'
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource subnet_app2 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: virtualNetwork2
  name: 'app'
  properties: {
    addressPrefix: '10.10.1.0/28'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource hubVNetconnection1 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-11-01' = {
  parent: virtualHub1
  name: '${location}spoke1'
  dependsOn: [
    firewall1
  ]
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork1.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: false
    enableInternetSecurity: true
  }
}

resource hubVNetconnection2 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-11-01' = {
  parent: virtualHub1
  name: '${location}spoke2'
  dependsOn: [
    firewall1
  ]
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork2.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: false
    enableInternetSecurity: true
  }
}

/* Location Spoke1 VM */
resource Hub1Spoke1VM_nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: '${location}Spoke1VM_nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: myIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource Hub1Spoke1VM_netInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${location}Spoke1VM_nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_app1.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: Hub1Spoke1VM_nsg.id
    }
  }
}

resource Hub1Spoke1VM 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${location}Spoke1VM'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: '${location}Spoke1VM'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: Hub1Spoke1VM_netInterface.id
        }
      ]
    }
  }
}

/* Location Spoke2 VM */
resource Hub1Spoke2VM_nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: '${location}Spoke2VM_nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: myIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource Hub1Spoke2VM_netInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${location}Spoke2VM_nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_app2.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: Hub1Spoke2VM_nsg.id
    }
  }
}

resource Hub1Spoke2VM 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${location}Spoke2VM'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: '${location}Spoke2VM'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: Hub1Spoke2VM_netInterface.id
        }
      ]
    }
  }
}

/**********************************************************************/

/* Location Spoke 1 connected to VWan hub LocationHub */
resource virtualNetwork3 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: '${secLocation}Spoke1'
  location: secLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.11.0.0/24'
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource subnet_app3 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: virtualNetwork3
  name: 'app'
  properties: {
    addressPrefix: '10.11.0.0/28'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

/* Location Spoke 2 connected to VWan hub LocationHub */
resource virtualNetwork4 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: '${secLocation}Spoke2'
  location: secLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.11.1.0/24'
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource subnet_app4 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: virtualNetwork4
  name: 'app'
  properties: {
    addressPrefix: '10.11.1.0/28'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource hubVNetconnection3 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-11-01' = {
  parent: virtualHub2
  name: '${secLocation}spoke1'
  dependsOn: [
    firewall2
  ]
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork3.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: false
    enableInternetSecurity: true
  }
}

resource hubVNetconnection4 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-11-01' = {
  parent: virtualHub2
  name: '${secLocation}spoke2'
  dependsOn: [
    firewall2
  ]
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork4.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: false
    enableInternetSecurity: true
  }
}

/* Location Spoke1 VM */
resource Hub2Spoke1VM_nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: '${secLocation}Spoke1VM_nsg'
  location: secLocation
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: myIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource Hub2Spoke1VM_netInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${secLocation}Spoke1VM_nic'
  location: secLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_app3.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: Hub2Spoke1VM_nsg.id
    }
  }
}

resource Hub2Spoke1VM 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${secLocation}Spoke1VM'
  location: secLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: '${secLocation}Spoke1VM'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: Hub2Spoke1VM_netInterface.id
        }
      ]
    }
  }
}

/* Location Spoke2 VM */
resource Hub2Spoke2VM_nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: '${secLocation}Spoke2VM_nsg'
  location: secLocation
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: myIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource Hub2Spoke2VM_netInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${secLocation}Spoke2VM_nic'
  location: secLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_app4.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: Hub2Spoke2VM_nsg.id
    }
  }
}

resource Hub2Spoke2VM 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${secLocation}Spoke2VM'
  location: secLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: '${secLocation}Spoke2VM'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: Hub2Spoke2VM_netInterface.id
        }
      ]
    }
  }
}
