// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItemsNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    // Item types
    enum ItemType { WEAPON, ARMOR, POTION, MATERIAL }
    enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

    // Item structure
    struct GameItem {
        ItemType itemType;
        Rarity rarity;
        uint256 power; // Attack power for weapons, defense for armor, effect for potions
        string name;
        bool isForSale;
        uint256 price;
    }

    // Mappings
    mapping(uint256 => GameItem) public gameItems;
    mapping(address => uint256[]) public playerItems;
    
    // Events
    event ItemMinted(address indexed player, uint256 indexed tokenId, ItemType itemType, Rarity rarity);
    event ItemCrafted(address indexed player, uint256 indexed newTokenId, uint256[] materials);
    event ItemListed(uint256 indexed tokenId, uint256 price);
    event ItemSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    constructor(address initialOwner) ERC721("GameItemsNFT", "GINFT") Ownable(initialOwner) {
        _tokenIdCounter = 0;
    }

    // 1. Mint new gaming items (only owner can mint initial items)
    function mintItem(
        address to,
        ItemType _itemType,
        Rarity _rarity,
        uint256 _power,
        string memory _name
    ) external onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(to, tokenId);
        
        gameItems[tokenId] = GameItem({
            itemType: _itemType,
            rarity: _rarity,
            power: _power,
            name: _name,
            isForSale: false,
            price: 0
        });
        
        playerItems[to].push(tokenId);
        emit ItemMinted(to, tokenId, _itemType, _rarity);
    }

    // 2. Craft new items by combining materials
    function craftItem(
        uint256[] memory materialIds,
        ItemType _newItemType,
        string memory _newItemName
    ) external {
        require(materialIds.length >= 2, "Need at least 2 materials to craft");
        
        uint256 totalPower = 0;
        Rarity highestRarity = Rarity.COMMON;
        
        // Verify ownership and calculate new item stats
        for (uint i = 0; i < materialIds.length; i++) {
            require(ownerOf(materialIds[i]) == msg.sender, "You don't own this material");
            require(gameItems[materialIds[i]].itemType == ItemType.MATERIAL, "Can only craft with materials");
            
            totalPower += gameItems[materialIds[i]].power;
            if (gameItems[materialIds[i]].rarity > highestRarity) {
                highestRarity = gameItems[materialIds[i]].rarity;
            }
            
            // Burn the material
            _burn(materialIds[i]);
            _removeFromPlayerItems(msg.sender, materialIds[i]);
        }
        
        // Create new crafted item
        uint256 newTokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(msg.sender, newTokenId);
        
        gameItems[newTokenId] = GameItem({
            itemType: _newItemType,
            rarity: highestRarity,
            power: totalPower + 10, // Bonus power for crafting
            name: _newItemName,
            isForSale: false,
            price: 0
        });
        
        playerItems[msg.sender].push(newTokenId);
        emit ItemCrafted(msg.sender, newTokenId, materialIds);
    }

    // 3. List item for sale in marketplace
    function listItemForSale(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "You don't own this item");
        require(price > 0, "Price must be greater than 0");
        require(!gameItems[tokenId].isForSale, "Item is already for sale");
        
        gameItems[tokenId].isForSale = true;
        gameItems[tokenId].price = price;
        
        emit ItemListed(tokenId, price);
    }

    // 4. Buy item from marketplace
    function buyItem(uint256 tokenId) external payable {
        require(gameItems[tokenId].isForSale, "Item is not for sale");
        require(msg.value >= gameItems[tokenId].price, "Insufficient payment");
        require(ownerOf(tokenId) != msg.sender, "Cannot buy your own item");
        
        address seller = ownerOf(tokenId);
        uint256 price = gameItems[tokenId].price;
        
        // Remove from seller's items and add to buyer's items
        _removeFromPlayerItems(seller, tokenId);
        playerItems[msg.sender].push(tokenId);
        
        // Update item status
        gameItems[tokenId].isForSale = false;
        gameItems[tokenId].price = 0;
        
        // Transfer NFT
        _transfer(seller, msg.sender, tokenId);
        
        // Transfer payment to seller
        payable(seller).transfer(price);
        
        // Refund excess payment
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit ItemSold(tokenId, seller, msg.sender, price);
    }

    // 5. Get player's items
    function getPlayerItems(address player) external view returns (uint256[] memory) {
        return playerItems[player];
    }

    // Helper function to remove item from player's inventory
    function _removeFromPlayerItems(address player, uint256 tokenId) internal {
        uint256[] storage items = playerItems[player];
        for (uint i = 0; i < items.length; i++) {
            if (items[i] == tokenId) {
                items[i] = items[items.length - 1];
                items.pop();
                break;
            }
        }
    }

    // Get item details
    function getItemDetails(uint256 tokenId) external view returns (GameItem memory) {
        require(_ownerOf(tokenId) != address(0), "Item does not exist");
        return gameItems[tokenId];
    }

    // Get current token counter (helpful for frontend)
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
