// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CoreVault.sol";

contract LiquidationEngine {
    CoreVault public vault;
    address public admin;
    uint256 public constant LIQUIDATION_BONUS = 500; // 5%
    uint256 public constant HEALTH_FACTOR_PRECISION = 10000;
    uint256 public constant LIQUIDATION_THRESHOLD = 8000;

    event Liquidated(address indexed borrower, address indexed liquidator, uint256 nftId, uint256 debtPaid, uint256 bonusReceived);

    constructor(address _vault) {
        require(_vault != address(0), "Invalid vault");
        vault = CoreVault(_vault);
        admin = msg.sender;
    }

    function getHealthFactor(address user, uint256 nftId) public view returns (uint256) {
        uint256 borrowed = vault.getBorrowedAmount(user, nftId);
        if (borrowed == 0) return HEALTH_FACTOR_PRECISION;
        
        uint256 nftValue = vault.oraclePrice() * vault.volatilityMultiplier();
        uint256 maxBorrow = (nftValue * vault.MAX_LTV()) / HEALTH_FACTOR_PRECISION;
        
        if (maxBorrow == 0) return 0;
        return (maxBorrow * HEALTH_FACTOR_PRECISION) / borrowed;
    }

    function isLiquidatable(address user, uint256 nftId) public view returns (bool) {
        uint256 healthFactor = getHealthFactor(user, nftId);
        return healthFactor < HEALTH_FACTOR_PRECISION;
    }

    function liquidate(address borrower, uint256 nftId) external {
        require(isLiquidatable(borrower, nftId), "Not liquidatable");
        require(vault.nftToOwner(nftId) == borrower, "Not owner");
        
        uint256 debtPaid = vault.getBorrowedAmount(borrower, nftId);
        require(debtPaid > 0, "No debt");
        
        uint256 bonus = (debtPaid * LIQUIDATION_BONUS) / HEALTH_FACTOR_PRECISION;
        uint256 totalRepay = debtPaid + bonus;
        
        require(vault.stablecoin().balanceOf(address(this)) >= totalRepay, "Insufficient funds");
        
        vault.stablecoin().transferFrom(address(this), msg.sender, totalRepay);
        vault.stablecoin().transferFrom(msg.sender, address(this), debtPaid);
        
        vault.liquidateNFT(borrower, nftId, msg.sender);
        
        emit Liquidated(borrower, msg.sender, nftId, debtPaid, bonus);
    }

    function setOraclePrice(uint256 _price) external {
        require(msg.sender == admin, "Not admin");
        vault.setOraclePrice(_price);
    }

    function setVolatility(uint256 _multiplier) external {
        require(msg.sender == admin, "Not admin");
        vault.setVolatility(_multiplier);
    }

    function withdrawFunds() external {
        require(msg.sender == admin, "Not admin");
        uint256 balance = vault.stablecoin().balanceOf(address(this));
        vault.stablecoin().transfer(admin, balance);
    }
}