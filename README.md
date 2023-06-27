
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

Here is the overall topology of what will be deployed as part of this lab.

![[azure-virtualwan-cisco-vpn-topology.png]]

Let's begin

### Step 1: Deploy the Virtual WAN

#### Virtual WAN base lab deploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbcosden%2Fazure-cisco-bgp-lab%2Fmaster%2Fvwan-arm%2Fvwan.json)



#### Cisco Deploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbcosden%2Fazure-cisco-bgp-lab%2Fmaster%2Fcisco-arm%2Fcisco.json)



##### Results


##### Contact Microsoft for



