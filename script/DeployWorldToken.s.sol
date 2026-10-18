// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {WorldToken} from "../src/WorldToken.sol";

/// @notice Reviewable reference deployment. The production launch is performed by IMD's factory,
/// which deploys WorldToken from its creation code; this script is for local/test networks only.
contract DeployWorldToken is Script {
    function deploy() public returns (WorldToken token) {
        token = new WorldToken();
    }

    function run() external returns (WorldToken token) {
        vm.startBroadcast();
        token = deploy();
        vm.stopBroadcast();
    }
}
