// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import "./TipChainNFT.sol";

contract TipChain is ReentrancyGuard {
    struct ChainStats {
        uint256 length;
        address topTipper;
        uint256 topTipAmount;
    }

    TipChainNFT public tipChainNFT;

    // Set the NFT contract address
    function setTipChainNFT(address nftAddress) external {
        tipChainNFT = TipChainNFT(nftAddress);
    }

    // Payable constructor to accept initial ETH funding
    constructor() payable {}

    // Function to fund ERC20 tokens to the contract
    function fundERC20(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    // Mapping from tipId to chain of addresses
    mapping(uint256 => address[]) public tipChains;

    // Mapping from tipId to mapping of address to bool to limit 1 tip per address per chain
    mapping(uint256 => mapping(address => bool)) public hasTipped;

    // Mapping from tipId to chain stats
    mapping(uint256 => ChainStats) public chainStats;

    // Tracks how much a user has *tipped* per token (user can withdraw if needed)
    mapping(address => mapping(address => uint256)) public userTips;

    // Tracks how much a *recipient* has received in tips per token
    mapping(address => mapping(address => uint256)) public recipientTips;

    // Event emitted when a tip is sent
    event TipSent(uint256 indexed tipId, address indexed from, address indexed to, uint256 amount, address token);

    // Event emitted when chain stats are updated
    event ChainStatsUpdated(uint256 indexed tipId, uint256 length, address topTipper, uint256 topTipAmount);

    // Event emitted when a user withdraws tips
    event TipWithdrawn(address indexed user, address indexed token, uint256 amount);

    // Tip in ETH
    function tipETH(uint256 tipId, address to) external payable nonReentrant {
        require(msg.value > 0, "Tip must be > 0");
        require(!hasTipped[tipId][msg.sender], "Already tipped this chain");

        tipChains[tipId].push(msg.sender);
        hasTipped[tipId][msg.sender] = true;

        ChainStats storage stats = chainStats[tipId];
        stats.length += 1;

        if (msg.value > stats.topTipAmount) {
            stats.topTipAmount = msg.value;
            stats.topTipper = msg.sender;
        }

        // ETH is address(0)
        userTips[msg.sender][address(0)] += msg.value;
        recipientTips[to][address(0)] += msg.value;

        emit TipSent(tipId, msg.sender, to, msg.value, address(0));
        emit ChainStatsUpdated(tipId, stats.length, stats.topTipper, stats.topTipAmount);

        _checkAndMintNFT(tipId);
    }

    // Tip in ERC20
    function tipERC20(uint256 tipId, address to, address token, uint256 amount) external {
        require(amount > 0, "Tip amount must be greater than zero");
        require(!hasTipped[tipId][msg.sender], "Already tipped in this chain");

        // Add sender to chain
        tipChains[tipId].push(msg.sender);
        hasTipped[tipId][msg.sender] = true;

        // Update chain stats
        ChainStats storage stats = chainStats[tipId];
        stats.length += 1;

        if (amount > stats.topTipAmount) {
            stats.topTipAmount = amount;
            stats.topTipper = msg.sender;
        }

        // Track user tips for withdrawal
        userTips[msg.sender][token] += amount;

        // Transfer ERC20 tokens from sender to contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Track recipient tips for withdrawal
        recipientTips[to][token] += amount;

        emit TipSent(tipId, msg.sender, to, amount, token);
        emit ChainStatsUpdated(tipId, stats.length, stats.topTipper, stats.topTipAmount);

        _checkAndMintNFT(tipId);
    }

    // Sender can withdraw their own tipping history (if needed)
    function withdrawTips(address token) external {
        uint256 amount = userTips[msg.sender][token];
        require(amount > 0, "No tips to withdraw");

        userTips[msg.sender][token] = 0;

        if (token == address(0)) {
            // Withdraw ETH
            (bool sent,) = payable(msg.sender).call{value: amount}("");
            require(sent, "Failed to withdraw ETH");
        } else {
            // Withdraw ERC20 tokens
            IERC20(token).transfer(msg.sender, amount); // Ensure this line works properly
        }

        emit TipWithdrawn(msg.sender, token, amount);
    }

    // Recipients can withdraw tips they’ve received
    function withdrawRecipientTips(address token) external nonReentrant {
        uint256 amount = recipientTips[msg.sender][token];
        require(amount > 0, "No tips to withdraw");

        recipientTips[msg.sender][token] = 0;

        if (token == address(0)) {
            (bool sent,) = payable(msg.sender).call{value: amount}("");
            require(sent, "ETH withdraw failed");
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }

        emit TipWithdrawn(msg.sender, token, amount);
    }

    // View chain participants
    function getChain(uint256 tipId) external view returns (address[] memory) {
        return tipChains[tipId];
    }

    // View chain stats
    function getChainStats(uint256 tipId)
        external
        view
        returns (uint256 length, address topTipper, uint256 topTipAmount)
    {
        ChainStats storage stats = chainStats[tipId];
        return (stats.length, stats.topTipper, stats.topTipAmount);
    }

    // Internal function to check and mint NFT on milestone
function _checkAndMintNFT(uint256 tipId) internal {
    ChainStats storage stats = chainStats[tipId];
    uint256 length = stats.length;

    // Define milestones
    uint256[5] memory milestones = [uint256(1), uint256(3), uint256(5), uint256(7), uint256(10)];

    for (uint256 i = 0; i < milestones.length; i++) {
        if (length == milestones[i]) {
            // Mint NFT to the last tipper in the chain
            address user = tipChains[tipId][tipChains[tipId].length - 1];
            if (address(tipChainNFT) != address(0) && !tipChainNFT.hasMinted(user, tipId)) {
                tipChainNFT.mintNFT(user, tipId, length);
            }
            break;
        }
    }
}
}
