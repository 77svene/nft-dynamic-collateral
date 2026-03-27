// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CoreVault {
    struct Position {
        uint256 nftId;
        uint256 borrowedAmount;
        bool active;
    }

    IERC721 public immutable nftContract;
    IERC20 public immutable stablecoin;
    address public owner;
    uint256 public constant MAX_LTV = 7000;
    uint256 public constant LIQUIDATION_THRESHOLD = 8000;
    uint256 public constant LIQUIDATION_BONUS = 500;
    uint256 public oraclePrice;
    uint256 public volatilityMultiplier = 10000;

    mapping(address => Position[]) public userPositions;
    mapping(uint256 => address) public nftToOwner;

    event Deposit(address indexed user, uint256 nftId);
    event Withdraw(address indexed user, uint256 nftId);
    event Borrow(address indexed user, uint256 nftId, uint256 amount);
    event Repay(address indexed user, uint256 nftId, uint256 amount);
    event Liquidate(address indexed borrower, address indexed liquidator, uint256 nftId);
    event OraclePriceUpdated(uint256 oldPrice, uint256 newPrice);

    constructor(address _nftContract, address _stablecoin) {
        require(_nftContract != address(0), "Invalid NFT contract");
        require(_stablecoin != address(0), "Invalid stablecoin");
        nftContract = IERC721(_nftContract);
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
    }

    function setOraclePrice(uint256 _price) external {
        require(msg.sender == owner, "Not owner");
        uint256 oldPrice = oraclePrice;
        oraclePrice = _price;
        emit OraclePriceUpdated(oldPrice, _price);
    }

    function deposit(uint256 nftId) external {
        require(nftContract.ownerOf(nftId) == msg.sender, "Not owner");
        nftContract.safeTransferFrom(msg.sender, address(this), nftId);
        userPositions[msg.sender].push(Position({nftId: nftId, borrowedAmount: 0, active: true}));
        nftToOwner[nftId] = msg.sender;
        emit Deposit(msg.sender, nftId);
    }

    function withdraw(uint256 nftId) external {
        Position[] storage positions = userPositions[msg.sender];
        uint256 idx = _findPosition(nftId);
        require(idx < positions.length, "Position not found");
        require(positions[idx].borrowedAmount == 0, "Debt outstanding");
        nftContract.safeTransferFrom(address(this), msg.sender, nftId);
        positions[idx].active = false;
        emit Withdraw(msg.sender, nftId);
    }

    function borrow(uint256 nftId, uint256 amount) external {
        Position[] storage positions = userPositions[msg.sender];
        uint256 idx = _findPosition(nftId);
        require(idx < positions.length, "Position not found");
        require(positions[idx].active, "Inactive position");
        uint256 ltv = (amount * 10000) / oraclePrice;
        require(ltv <= MAX_LTV, "LTV exceeded");
        require(stablecoin.transfer(msg.sender, amount), "Transfer failed");
        positions[idx].borrowedAmount += amount;
        emit Borrow(msg.sender, nftId, amount);
    }

    function repay(uint256 nftId, uint256 amount) external {
        Position[] storage positions = userPositions[msg.sender];
        uint256 idx = _findPosition(nftId);
        require(idx < positions.length, "Position not found");
        require(positions[idx].borrowedAmount >= amount, "Insufficient debt");
        require(stablecoin.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        positions[idx].borrowedAmount -= amount;
        emit Repay(msg.sender, nftId, amount);
    }

    function liquidate(uint256 nftId) external {
        Position[] storage positions = userPositions[nftToOwner[nftId]];
        uint256 idx = _findPosition(nftId);
        require(idx < positions.length, "Position not found");
        uint256 debt = positions[idx].borrowedAmount;
        require(debt > 0, "No debt");
        uint256 ltv = (debt * 10000) / oraclePrice;
        require(ltv >= LIQUIDATION_THRESHOLD, "Not liquidatable");
        uint256 repayAmount = debt + (debt * LIQUIDATION_BONUS / 10000);
        require(stablecoin.transferFrom(msg.sender, address(this), repayAmount), "Transfer failed");
        positions[idx].borrowedAmount = 0;
        nftContract.safeTransferFrom(address(this), msg.sender, nftId);
        delete nftToOwner[nftId];
        emit Liquidate(nftToOwner[nftId], msg.sender, nftId);
    }

    function _findPosition(uint256 nftId) internal view returns (uint256) {
        Position[] storage positions = userPositions[msg.sender];
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].nftId == nftId && positions[i].active) return i;
        }
        return positions.length;
    }
}