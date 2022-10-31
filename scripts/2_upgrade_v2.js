require("dotenv").config()
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades")
const { deployProxy } = require("@openzeppelin/truffle-upgrades")


const StakingPool = artifacts.require("StakingPool")
const StakingPoolV2 = artifacts.require("StakingPoolV2")
const StakingProxyAdmin = artifacts.require("StakingProxyAdmin")
// const StakingPool_Proxy = artifacts.require("StakingPoolProxy")

module.exports = async function (deployer) {

 const proxy = await StakingPool.deployed()
 // Upgrade
 await upgradeProxy(proxy.address, StakingPoolV2, {deployer})
}