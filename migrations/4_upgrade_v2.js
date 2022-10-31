const StakingPoolV2 = artifacts.require("StakingPoolV2.sol")
const StakingPool = artifacts.require("StakingPool.sol")
const StakingProxyAdmin = artifacts.require("StakingProxyAdmin.sol")
const StakingPoolProxy = artifacts.require("StakingPoolProxy")


module.exports = async function(deployer) {
 const stakingPoolV1 = await StakingPool.deployed()
 const admin = await StakingProxyAdmin.deployed()
 const proxyStaking = await StakingPoolProxy.deployed()
 await deployer.deploy(StakingPoolV2)
 const stakingPoolV2 = await StakingPoolV2.deployed()

 //Upgrade
 await admin.upgrade(StakingPoolProxy.address, stakingPoolV2.address)
 const proxy = await StakingPoolV2.at(proxyStaking.address)
 console.log("Version: ", (await proxy.version()).toNumber())
}