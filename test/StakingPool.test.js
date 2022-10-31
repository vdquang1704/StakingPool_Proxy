const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers")
const StakingPoolProxy = artifacts.require("StakingPool.sol")

contract("StakingPool", function (accounts) {
 it("Show right version", async function () {
  const stakingPoolInstance = await StakingPoolProxy.deployed();
  let value = await stakingPoolInstance.version();
  assert.equal(value, 1, "It's not version of Staking Pool");
 })

 it("Should retrieve correctly stored value", async function () {
  const stakingPoolInstance = await StakingPoolProxy.deployed();
  await stakingPoolInstance.store(2);
  let value = await stakingPoolInstance.retrieve();
  assert.equal(value, 2, "Staking Pool did not store correct value")
 })
})