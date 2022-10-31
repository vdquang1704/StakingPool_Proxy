const { admin } = require("@openzeppelin/truffle-upgrades")
require("dotenv").config()

const StakingPool = artifacts.require("StakingPool.sol")
const StakingProxyAdmin = artifacts.require("StakingProxyAdmin.sol")
const StakingPoolProxy = artifacts.require("StakingPoolProxy")

// Deploy implementation
module.exports = async function(deployer) {
 await deployer.deploy(StakingPool)
 const stakingPoolV1 = await StakingPool.deployed()

 // Deploy ProxyAdmin 
 await deployer.deploy(StakingProxyAdmin, "0x306366DE0bF312786C0af82089Fc914eF578fe0c")
 const admin = await StakingProxyAdmin.deployed()

  // Deploy Proxy 
const data = stakingPoolV1.contract.methods.__StakingPool_init().encodeABI()

await deployer.deploy(StakingPoolProxy, stakingPoolV1.address, admin.address, data)
const proxyAdmin = await StakingPoolProxy.deployed()
const proxy = await StakingPool.at(proxyAdmin.address)
console.log("Version: ", (await proxy.version()).toNumber())
}
