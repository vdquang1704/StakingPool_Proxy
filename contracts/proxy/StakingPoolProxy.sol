// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract StakingPoolProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address admin,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin, _data) {}
}
