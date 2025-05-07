// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TipChain.sol";
import "../src/TipChainNFT.sol";

contract DeployScript is Script {
    function run() external {
        // Load private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TipChainNFT contract
        TipChainNFT tipChainNFT = new TipChainNFT();

        // Deploy TipChain contract with payable constructor
        TipChain tipChain = (new TipChain){value: 0.001 ether}();

        // Set the TipChainNFT contract address in TipChain
        tipChain.setTipChainNFT(address(tipChainNFT));

        vm.stopBroadcast();

        console.log("TipChainNFT deployed at:", address(tipChainNFT));
        console.log("TipChain deployed at:", address(tipChain));
    }
}
