// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract PriceOracle {
    using ECDSA for bytes32;

    address public admin;
    uint256 public price;
    uint256 public lastUpdate;
    uint256 public nonce;
    
    mapping(bytes32 => bool) public usedNonces;
    
    event PriceUpdated(uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event AdminUpdated(address oldAdmin, address newAdmin);
    event NonceUpdated(uint256 oldNonce, uint256 newNonce);

    constructor(address _admin) {
        require(_admin != address(0), "Invalid admin");
        admin = _admin;
        price = 1000000;
        lastUpdate = block.timestamp;
        nonce = 0;
    }

    function updatePrice(uint256 _price, bytes calldata signature) external {
        require(_price > 0, "Invalid price");
        require(msg.sender == admin, "Not admin");
        
        bytes32 messageHash = keccak256(abi.encodePacked(_price, nonce));
        address signer = messageHash.recover(signature);
        require(signer == admin, "Invalid signature");
        require(!usedNonces[messageHash], "Nonce already used");
        
        usedNonces[messageHash] = true;
        uint256 oldPrice = price;
        price = _price;
        lastUpdate = block.timestamp;
        nonce++;
        
        emit PriceUpdated(oldPrice, _price, lastUpdate);
        emit NonceUpdated(nonce - 1, nonce);
    }

    function setAdmin(address _newAdmin) external {
        require(msg.sender == admin, "Not admin");
        require(_newAdmin != address(0), "Invalid admin");
        address oldAdmin = admin;
        admin = _newAdmin;
        emit AdminUpdated(oldAdmin, _newAdmin);
    }

    function getPrice() external view returns (uint256) {
        require(block.timestamp - lastUpdate < 3600, "Price stale");
        return price;
    }

    function getNonce() external view returns (uint256) {
        return nonce;
    }
}