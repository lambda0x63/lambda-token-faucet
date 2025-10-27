import { ethers } from "hardhat";

async function main() {
  console.log("🚀 Starting LambdaFaucet deployment...\n");

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying with account: ${deployer.address}\n`);

  // Parameters for FaucetAdmin
  const baseAmount = ethers.utils.parseUnits("100", 18); // 100 LMDA
  const baseCooldown = 3600; // 1 hour

  // 1. Deploy Token
  console.log("1️⃣  Deploying LambdaToken...");
  const Token = await ethers.getContractFactory("LambdaToken");
  const token = await Token.deploy();
  await token.deployed();
  console.log(`   ✅ Token deployed at: ${token.address}\n`);

  // 2. Deploy FaucetAdmin
  console.log("2️⃣  Deploying FaucetAdmin...");
  const FaucetAdmin = await ethers.getContractFactory("FaucetAdmin");
  const faucetAdmin = await FaucetAdmin.deploy(
    deployer.address,
    baseAmount,
    baseCooldown
  );
  await faucetAdmin.deployed();
  console.log(`   ✅ FaucetAdmin deployed at: ${faucetAdmin.address}\n`);

  // 3. Deploy FaucetStats with deployer as initial faucet
  console.log("3️⃣  Deploying FaucetStats...");
  const FaucetStats = await ethers.getContractFactory("FaucetStats");
  const faucetStats = await FaucetStats.deploy(deployer.address);
  await faucetStats.deployed();
  console.log(`   ✅ FaucetStats deployed at: ${faucetStats.address}\n`);

  // 4. Deploy ReferralSystem with deployer as initial faucet
  console.log("4️⃣  Deploying ReferralSystem...");
  const ReferralSystem = await ethers.getContractFactory("ReferralSystem");
  const referralSystem = await ReferralSystem.deploy(deployer.address);
  await referralSystem.deployed();
  console.log(`   ✅ ReferralSystem deployed at: ${referralSystem.address}\n`);

  // 5. Deploy LambdaFaucet
  console.log("5️⃣  Deploying LambdaFaucet...");
  const LambdaFaucet = await ethers.getContractFactory("LambdaFaucet");
  const lambdaFaucet = await LambdaFaucet.deploy(
    token.address,
    faucetAdmin.address,
    faucetStats.address,
    referralSystem.address
  );
  await lambdaFaucet.deployed();
  const faucetAddress = lambdaFaucet.address;
  console.log(`   ✅ LambdaFaucet deployed at: ${faucetAddress}\n`);

  // 6. Update FaucetStats with correct LambdaFaucet address (called from deployer who is current faucet)
  console.log("6️⃣  Updating FaucetStats with LambdaFaucet address...");
  let tx = await faucetStats.updateFaucet(faucetAddress);
  await tx.wait();
  console.log("   ✅ FaucetStats updated\n");

  // 7. Update ReferralSystem with correct LambdaFaucet address (called from deployer who is current faucet)
  console.log("7️⃣  Updating ReferralSystem with LambdaFaucet address...");
  tx = await referralSystem.updateFaucet(faucetAddress);
  await tx.wait();
  console.log("   ✅ ReferralSystem updated\n");

  // 8. Update FaucetAdmin with LambdaFaucet address
  console.log("8️⃣  Updating FaucetAdmin with LambdaFaucet address...");
  tx = await faucetAdmin.setFaucet(faucetAddress);
  await tx.wait();
  console.log("   ✅ FaucetAdmin updated\n");

  // 9. Fund the faucet with tokens
  console.log("9️⃣  Funding LambdaFaucet with tokens...");
  const fundAmount = ethers.utils.parseUnits("50000", 18); // 50,000 LMDA
  tx = await token.transfer(faucetAddress, fundAmount);
  await tx.wait();
  console.log(`   ✅ Faucet funded with 50,000 LMDA\n`);

  // Print summary
  console.log("=".repeat(70));
  console.log("✅ DEPLOYMENT SUCCESSFUL!\n");
  console.log("📋 Contract Addresses:");
  console.log(`   Token:          ${token.address}`);
  console.log(`   FaucetAdmin:    ${faucetAdmin.address}`);
  console.log(`   FaucetStats:    ${faucetStats.address}`);
  console.log(`   ReferralSystem: ${referralSystem.address}`);
  console.log(`   LambdaFaucet:   ${faucetAddress}`);
  console.log("=".repeat(70));
  console.log("\n📝 Network: Sepolia Testnet");
  console.log("📝 Block Explorer: https://sepolia.etherscan.io\n");
  console.log("💾 Save these addresses for verification and interactions!\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
