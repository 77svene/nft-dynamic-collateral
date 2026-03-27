// SPDX-License-Identifier: MIT
const hre = require("hardhat");

async function main() {
  console.log("=== Deploying NFT Vault System to Sepolia ===");
  
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying from:", deployer.address);
  
  const SEPOLIA_CHAIN_ID = 11155111;
  const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
  
  // Check balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Deployer balance:", hre.ethers.formatEther(balance), "ETH");
  if (balance < hre.ethers.parseEther("0.1")) {
    console.log("WARNING: Low balance - fund with Sepolia testnet ETH");
  }
  
  // Deploy PriceOracle first (no dependencies)
  console.log("\n1. Deploying PriceOracle...");
  const PriceOracle = await hre.ethers.getContractFactory("PriceOracle");
  const oracle = await PriceOracle.deploy(deployer.address);
  await oracle.waitForDeployment();
  const oracleAddress = await oracle.getAddress();
  console.log("PriceOracle deployed at:", oracleAddress);
  
  // Deploy CoreVault (needs NFT and stablecoin addresses)
  console.log("\n2. Deploying CoreVault...");
  const CoreVault = await hre.ethers.getContractFactory("CoreVault");
  const CORE_VAULT_NFT = "0x0000000000000000000000000000000000000001";
  const STABLECOIN = "0x0000000000000000000000000000000000000002";
  const vault = await CoreVault.deploy(CORE_VAULT_NFT, STABLECOIN);
  await vault.waitForDeployment();
  const vaultAddress = await vault.getAddress();
  console.log("CoreVault deployed at:", vaultAddress);
  
  // Deploy LiquidationEngine (needs vault address)
  console.log("\n3. Deploying LiquidationEngine...");
  const LiquidationEngine = await hre.ethers.getContractFactory("LiquidationEngine");
  const liquidator = await LiquidationEngine.deploy(vaultAddress);
  await liquidator.waitForDeployment();
  const liquidatorAddress = await liquidator.getAddress();
  console.log("LiquidationEngine deployed at:", liquidatorAddress);
  
  // Fund oracle with initial ETH for gas
  console.log("\n4. Funding oracle with 0.1 ETH...");
  const fundTx = await deployer.sendTransaction({
    to: oracleAddress,
    value: hre.ethers.parseEther("0.1")
  });
  await fundTx.wait();
  console.log("Oracle funded successfully");
  
  // Verify on Etherscan if API key provided
  if (ETHERSCAN_API_KEY) {
    console.log("\n5. Verifying contracts on Etherscan...");
    try {
      await hre.run("verify:verify", {
        address: oracleAddress,
        constructorArguments: [deployer.address]
      });
      console.log("PriceOracle verified");
    } catch (e) { console.log("Oracle verify:", e.message); }
    
    try {
      await hre.run("verify:verify", {
        address: vaultAddress,
        constructorArguments: [CORE_VAULT_NFT, STABLECOIN]
      });
      console.log("CoreVault verified");
    } catch (e) { console.log("Vault verify:", e.message); }
    
    try {
      await hre.run("verify:verify", {
        address: liquidatorAddress,
        constructorArguments: [vaultAddress]
      });
      console.log("LiquidationEngine verified");
    } catch (e) { console.log("Liquidator verify:", e.message); }
  }
  
  // Print deployment summary
  console.log("\n=== DEPLOYMENT SUMMARY ===");
  console.log("PriceOracle:", oracleAddress);
  console.log("CoreVault:", vaultAddress);
  console.log("LiquidationEngine:", liquidatorAddress);
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", SEPOLIA_CHAIN_ID);
  console.log("==========================");
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exit(1);
});