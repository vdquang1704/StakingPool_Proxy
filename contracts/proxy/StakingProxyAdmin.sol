// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract StakingProxyAdmin is ProxyAdmin {
    constructor(address) ProxyAdmin() {}
}
