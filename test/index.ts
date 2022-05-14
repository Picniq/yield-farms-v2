import { expect } from "chai";
import { ethers } from "hardhat";
import { tokenList, TOKEN_ABI, UNISWAP_ABI, UNI_ADDRESS, WETH } from "../scripts/utils";

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
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

  let amounts = [
    0, 0, 0, await lusd.balanceOf(signers[1].address)
  ]

  await lusd.connect(signers[1]).approve(vault.address, ethers.constants.MaxInt256);

  await vault.connect(signers[1]).depositStable(amounts, 0, signers[1].address);

  // Increase time by 30 days
  await ethers.provider.send('evm_increaseTime', [86400 * 30]);
  await ethers.provider.send('evm_mine', []);

  await vault.connect(signers[0]).harvest([0,0,0,0]);

  await uniswap.connect(signers[2]).swapExactETHForTokens(0, route, signers[2].address, "9999999999", {value: ethers.utils.parseEther('1.35')});

  amounts = [
    0, 0, 0, await lusd.balanceOf(signers[2].address)
  ]

  await lusd.connect(signers[2]).approve(vault.address, ethers.constants.MaxInt256);

  await vault.connect(signers[2]).depositStable(amounts, 0, signers[2].address);

  // Increase time by 30 days
  await ethers.provider.send('evm_increaseTime', [86400 * 30]);
  await ethers.provider.send('evm_mine', []);

  await vault.connect(signers[0]).harvest([0,0,0,0]);

  const assets1 = await vault.convertToAssets(await vault.balanceOf(signers[1].address));
  const assets2 = await vault.convertToAssets(await vault.balanceOf(signers[2].address));
  console.log(assets1, assets2, await vault.totalAssets());

  await vault.connect(signers[1]).withdraw(assets1, signers[1].address, signers[1].address);
  await vault.balanceOf(signers[1].address);
  await vault.connect(signers[2]).withdraw(assets2, signers[2].address, signers[2].address);
  // const kekId = await vault.getBestWithdrawal(assets2);
  // await vault.connect(signers[2]).withdraw
  });
});
