// SPDX-License-Identifier: MIT
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFT Vault System", function () {
  let vault, oracle, liquidator, deployer, user1, user2;
  let nftContract, stablecoin;

  beforeEach(async function () {
    [deployer, user1, user2, liquidator] = await ethers.getSigners();
    
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    oracle = await PriceOracle.deploy(deployer.address);
    await oracle.waitForDeployment();
    
    const CoreVault = await ethers.getContractFactory("CoreVault");
    vault = await CoreVault.deploy(
      "0x0000000000000000000000000000000000000001",
      "0x0000000000000000000000000000000000000002"
    );
    await vault.waitForDeployment();
    
    const LiquidationEngine = await ethers.getContractFactory("LiquidationEngine");
    const liqEngine = await LiquidationEngine.deploy(await vault.getAddress());
    await liqEngine.waitForDeployment();
    
    const MockERC721 = await ethers.getContractFactory("MockERC721");
    nftContract = await MockERC721.deploy();
    await nftContract.waitForDeployment();
    
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    stablecoin = await MockERC20.deploy();
    await stablecoin.waitForDeployment();
    
    await vault.updateNFTContract(await nftContract.getAddress());
    await vault.updateStablecoin(await stablecoin.getAddress());
  });

  it("should deposit NFT and borrow stablecoins", async function () {
    await nftContract.mint(user1.address, 1);
    await nftContract.connect(user1).approve(await vault.getAddress(), 1);
    await vault.connect(user1).deposit(1);
    
    await stablecoin.mint(await vault.getAddress(), ethers.parseEther("1000"));
    await vault.connect(user1).borrow(1, ethers.parseEther("500"));
    
    const position = await vault.userPositions(user1.address, 0);
    expect(position.borrowedAmount).to.equal(ethers.parseEther("500"));
    expect(position.active).to.be.true;
  });

  it("should liquidate undercollateralized position", async function () {
    await nftContract.mint(user1.address, 1);
    await nftContract.connect(user1).approve(await vault.getAddress(), 1);
    await vault.connect(user1).deposit(1);
    
    await stablecoin.mint(await vault.getAddress(), ethers.parseEther("1000"));
    await vault.connect(user1).borrow(1, ethers.parseEther("500"));
    
    await oracle.updatePrice(100, "0x");
    await vault.updateOraclePrice(100);
    
    const liqEngine = await ethers.getContractFactory("LiquidationEngine");
    const liq = await liqEngine.deploy(await vault.getAddress());
    await liq.waitForDeployment();
    
    await liq.connect(liquidator).liquidate(user1.address, 1);
    
    const position = await vault.userPositions(user1.address, 0);
    expect(position.active).to.be.false;
  });

  it("should fail deposit without approval", async function () {
    await nftContract.mint(user1.address, 1);
    await expect(
      vault.connect(user1).deposit(1)
    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
  });

  it("should fail borrow when over-collateralized", async function () {
    await nftContract.mint(user1.address, 1);
    await nftContract.connect(user1).approve(await vault.getAddress(), 1);
    await vault.connect(user1).deposit(1);
    
    await stablecoin.mint(await vault.getAddress(), ethers.parseEther("1000"));
    await expect(
      vault.connect(user1).borrow(1, ethers.parseEther("10000"))
    ).to.be.revertedWith("Insufficient collateral");
  });

  it("should repay loan and withdraw NFT", async function () {
    await nftContract.mint(user1.address, 1);
    await nftContract.connect(user1).approve(await vault.getAddress(), 1);
    await vault.connect(user1).deposit(1);
    
    await stablecoin.mint(await vault.getAddress(), ethers.parseEther("1000"));
    await vault.connect(user1).borrow(1, ethers.parseEther("500"));
    await stablecoin.connect(user1).approve(await vault.getAddress(), ethers.parseEther("500"));
    await vault.connect(user1).repay(1, ethers.parseEther("500"));
    
    await vault.connect(user1).withdraw(1);
    const owner = await nftContract.ownerOf(1);
    expect(owner).to.equal(user1.address);
  });
});