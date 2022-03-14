
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
    this contract will mint a game item to any players address
*/
contract GameItem is ERC721URIStorage {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds; // this line would generate a unique token id for each mint
    Counters.Counter private nMinted; // this line will track number of nfts minted
    MerkleTree merkleTree; // this line will reference to MerkleTree contract

    // Defining the Name and symbol for ERC721 token
    string public constant NAME = "GameItem";
    string public constant SYMBOL = "ITM";
    uint256 public constant MAX_SUPPLY = 8;
    uint256 public constant PRICE = 0.001 ether;
    uint256 public constant MAX_PER_MINT = 1;

   
    event GameItemMinted(uint256 tokenId, string tokenURO);
    constructor() ERC721(NAME, SYMBOL) {
        merkleTree = new MerkleTree();
    }

    /**
        this line will Mint an NFT to player address, and commit computed hash to merkle tree
       
    */
    function awardItem(address player) public payable returns (uint256) {
        require(nMinted.current() < MAX_SUPPLY, "NFTs sold out");
        require(msg.value >= PRICE, "Not enough ether to mint NFT");

        // Generate new token id
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        // Construct metadata (tokenURI) and store on-chain
        // Mint item to player
        string memory tokenUri = constructTokenURI(newItemId);
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenUri);

        // Store item to Merkle Tree
        bytes32 hash = computeHash(msg.sender, player, newItemId, tokenUri);
        merkleTree.addItem(hash);
        nMinted.increment();

        emit GameItemMinted(newItemId, tokenUri);

        return newItemId;
    }
// getting the number of nfts owned by a user
    function tokensCountByOwner(address _owner)
        external
        view
        returns (uint256)
    {
        uint256 tokenCount = balanceOf(_owner);
        return tokenCount;
    }

    /*
        Construct metadata (as base64 encoded string to store on-chain) for a token.
    */
    function constructTokenURI(uint256 tokenId)
        internal
        pure
        returns (string memory)
    {
        // encode JSON metadata into bytes
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "Boomerang #',
            tokenId.toString(),
            '", ',
            '"description": "Wooden boomerang"'
            "}"
        );
        // encode JSON metadata (in bytes) into a base64 string for on-chain storage
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }

    /*
    dev Compute hash for merkle tree
        
    */
    function computeHash(
        address sender,
        address receiver,
        uint256 tokenId,
        string memory tokenURI
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, receiver, tokenId, tokenURI));
    }
}

/*
    A fixed size Merkle Tree to store minted GameItems
    Call addItem for every mint. It will auto update the merkle tree.
*/
contract MerkleTree {
    bytes32[] public hashes;
    uint256 public nSlots = 8; // to accommodate 8 mints
    uint256 public nMinted;

    /*
        Setting the size of hashes array based on number of leaves (nSlots).
    */
    constructor() {
        hashes = new bytes32[](2 * nSlots - 1);
    }

    /*Add a GameItem to the merkle tree
    */
    function addItem(bytes32 hash) external {
        require(nMinted < nSlots, "Maximum number of mints reached");
        hashes[nMinted++] = hash;
        constructMerkleTree();
    }

    /*
        dev Update merkle tree when a new GameItem is added
        
    */
    function constructMerkleTree() internal {
        uint256 n = nSlots;
        uint256 index = nSlots;
        uint256 offset = 0;

        // Eventual array when all nSlots are filled (ie. nSlots=4)
        // Assuming 1, 2, 3, 4 represent hashes of tokens
        // [1, 2, 3, 4, hash(1,2), hash(3,4), hash(1,2) + hash(3,4)]
        while (n > 0) {
            for (uint256 i = 0; i < n - 1; i += 2) {
                // start from index after leaves to construct the parent nodes
                hashes[index++] = (
                    keccak256(
                        abi.encodePacked(
                            hashes[offset + i],
                            hashes[offset + i + 1]
                        )
                    )
                );
            }
            offset += n; // offset by number of nodes on current level
            n = n / 2; // number of nodes on next parent level
        }
    }

    /** 
        getting the merkle root
    */
    function getRoot() public view returns (bytes32) {
        return hashes[hashes.length - 1];
    }
}