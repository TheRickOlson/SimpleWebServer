// New-AzResourceGroupDeployment -Name "deploy" -ResourceGroup "RSG" -TemplateFile ./environment.bicep
param location string = 'westus2'
param serverName string = 'server1'

// This should be your IP - this is used to restrict external TCP/22 to just your machine
// Easiest way to get this if you don't know it is to search "what's my IP" on Bing
param allowedIP string = '1.2.3.4'   

// This username/password will be used to log into the test VMs
// It is never recommended that you store passwords in code like this
// Don't be like me :)
param user string = 'testuser'
param pass string = 'TheStr0nge5tPWD!'

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'VNET-TEST'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'SUBNET-VMs'
        properties: {
          addressPrefix: '10.10.10.0/24'
        }
      }
    ]
  }
  
  resource vmsubnet 'subnets' existing = {
    name: 'SUBNET-VMs'
  }
}

resource PIP_server 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'pip-${serverName}'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  sku: {
    name: 'Basic'
  }
}

resource NSG_AllowSSH 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-allowssh'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          protocol: 'Tcp'
          sourceAddressPrefix: allowedIP
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource NIC_server 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${serverName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: vnet::vmsubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: PIP_server.id
          }
        }
      }
    ]

    networkSecurityGroup: {
      id: NSG_AllowSSH.id
    }
  }
}

resource servervm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: serverName
  location: location
  dependsOn: [
    NIC_server
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }

    osProfile: {
      computerName: serverName
      adminUsername: user
      adminPassword: pass
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }

    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: NIC_server.id
        }
      ]
    }
  }
}
