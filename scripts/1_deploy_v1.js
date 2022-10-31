require("dotenv").config()
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades")
const { deployProxy } = require("@openzeppelin/truffle-upgrades")

// const { ethers } = require("hardhat")
const StakingPool = artifacts.require("StakingPool")
const StakingPoolV2 = artifacts.require("StakingPoolV2")

const StakingProxyAdmin = artifacts.require("StakingProxyAdmin")
const StakingPool_Proxy = artifacts.require("StakingPoolProxy")



module.exports = async function (deployer) {
 await deployProxy(StakingPool, [], {deployer, initializer: "__StakingPool_init"})
}