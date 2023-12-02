import { deploy } from './web3-lib'

(async () => {
  try {
    const path = "./../../customContracts/artifacts/MultiSigWallet"
    const result = await deploy(path, [
        ["0xBEc04e55830224246A8fA8B245F91B2EE4A3d249","0xeD77Dbf0eb05f10DeE58974121a1B18F5d78e2A6","0x7d82FF5741f1C1D6431A5E00C14aadBbd736e932","0x9cA908a3709301454aDb2722f5680e28Baec7F3B"],
          2,
          "0x3aaa7A4180D5b7fEC6Ac086E65c4788726F14215"
        ],"0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", 3000000)
    console.log(`address: ${result.address}`)
  } catch (e) {
    console.log(e.message)
  }
})()