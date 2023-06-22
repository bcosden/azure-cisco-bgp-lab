targetScope='subscription'

param rgName string
param rgLocation string
param rgsecLocation string

param myIP string

param adminUsername string
@secure()
param adminPassword string

resource newRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: rgName
  location: rgLocation
}

module vwan 'vwan.bicep' = {
  name: 'vwan'
  scope: newRG
  params: {
    location: rgLocation
    secLocation: rgsecLocation
    adminUsername: adminUsername
    adminPassword: adminPassword
    myIP: myIP
  }
}
