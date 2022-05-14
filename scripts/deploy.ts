// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import { tokenList, TOKEN_ABI, UNISWAP_ABI, UNI_ADDRESS, WETH } from "./utils";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // Get signers to use for transactions
  const signers = await ethers.getSigners();

  // We get the contract to deploy
  const Vault = await ethers.getContractFactory("StableFarm");
  const vault = await Vault.deploy();

  await vault.deployed();

  console.log("Vault deployed to:", vault.address);

  const uniswap = new ethers.Contract(UNI_ADDRESS, UNISWAP_ABI, ethers.provider);
  const route = [
    WETH, tokenList[3].address
  ];

  await uniswap.connect(signers[1]).swapExactETHForTokens(0, route, signers[1].address, "9999999999", {value: ethers.utils.parseEther('1')});

  const lusd = new ethers.Contract(tokenList[3].address, TOKEN_ABI, ethers.provider);

  console.log(await lusd.balanceOf(signers[1].address));

  let amounts = [
    0, 0, 0, await lusd.balanceOf(signers[1].address)
  ]

  await lusd.connect(signers[1]).approve(vault.address, ethers.constants.MaxInt256);

  await vault.connect(signers[1]).depositStable(amounts, 0, signers[1].address);

  console.log(await vault.balanceOf(signers[1].address));

  // Increase time by 30 days
  await ethers.provider.send('evm_increaseTime', [86400 * 30]);
  await ethers.provider.send('evm_mine', []);

  await vault.connect(signers[0]).harvest([0,0,0,0]);

  console.log(await vault.convertToAssets(await vault.balanceOf(signers[1].address)));

  await uniswap.connect(signers[2]).swapExactETHForTokens(0, route, signers[2].address, "9999999999", {value: ethers.utils.parseEther('1.35')});

  console.log(await lusd.balanceOf(signers[2].address));

  amounts = [
    0, 0, 0, await lusd.balanceOf(signers[2].address)
  ]

  await lusd.connect(signers[2]).approve(vault.address, ethers.constants.MaxInt256);

  await vault.connect(signers[2]).depositStable(amounts, 0, signers[2].address);

  console.log(await vault.balanceOf(signers[2].address));

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
