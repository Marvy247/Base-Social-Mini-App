// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TipChainNFT is ERC721("SOCIALNFT", "BSC"), Ownable(msg.sender) {
    uint256 public nextTokenId;
    mapping(address => mapping(uint256 => bool)) public hasMinted; // user => chainId => minted

    // Milestone thresholds for chain length
    uint256[] public milestones = [1, 3, 5, 7, 10];

    // Placeholder metadata URIs for each milestone
    mapping(uint256 => string) public milestoneURIs;

    event NFTMinted(address indexed user, uint256 indexed chainId, uint256 tokenId, uint256 milestone);

    constructor() {
        // Initialize placeholder URIs for milestones
        milestoneURIs[1] = "https://example.com/metadata/milestone1.json";
        milestoneURIs[3] = "https://example.com/metadata/milestone3.json";
        milestoneURIs[5] = "https://example.com/metadata/milestone5.json";
        milestoneURIs[7] = "https://example.com/metadata/milestone7.json";
        milestoneURIs[10] = "https://example.com/metadata/milestone10.json";
}

// Mint NFT function
    function mintNFT(address user, uint256 chainId, uint256 chainLength) public returns (uint256) {
        require(!hasMinted[user][chainId], "NFT already minted for this chain");
        uint256 milestone = getMilestone(chainLength);
        require(milestone > 0, "No milestone reached");

        uint256 tokenId = nextTokenId++;
        hasMinted[user][chainId] = true;
        _safeMint(user, tokenId);
        _setTokenURI(tokenId, milestoneURIs[milestone]);

        emit NFTMinted(user, chainId, tokenId, milestone);
        return tokenId;
    }

    // Get milestone based on the chain length
    function getMilestone(uint256 chainLength) public view returns (uint256) {
        for (uint256 i = milestones.length; i > 0; i--) {
            if (chainLength >= milestones[i - 1]) {
                return milestones[i - 1];
            }
        }
        return 0; // Return 0 if no milestone is reached
    }

    // Internal mapping to store token URIs
    mapping(uint256 => string) private _tokenURIs;
    
    // Internal function to set token URI for each NFT
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
    }

    // Return the milestone URI for a given token ID
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return _tokenURIs[tokenId]; // Return the milestone URI directly
    }
}
