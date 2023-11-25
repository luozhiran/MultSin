import { deploy } from './web3-lib'

(async () => {
  try {
    const path = "./../../customContracts/artifacts/MultiSigWallet"
    const result = await deploy(path, [
        ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
        ,2
        ],"0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", 3000000)
    console.log(`address: ${result.address}`)
  } catch (e) {
    console.log(e.message)
  }
})()