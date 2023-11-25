const { expect } = require("chai");
const { ethers } = require("hardhat");
const path = "./../../customContracts/artifacts/MultiSigWallet"

describe(path, function () {
  it("测试 部署合约", async function () {
    const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
    const multiSigWallet = await MultiSigWallet.deploy(["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"],2);
    await multiSigWallet.deployed();
    console.log("MultiSigWallet deployed at:" + multiSigWallet.address);
    expect((await multiSigWallet.getTransactionCount()).toNumber()).to.equal(0);
  });
});
