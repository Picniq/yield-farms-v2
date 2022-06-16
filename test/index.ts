import { expect } from "chai";
import { ethers } from "hardhat";
import { tokenList, TOKEN_ABI, UNISWAP_ABI, UNI_ADDRESS, WETH } from "../scripts/utils";

describe("StableFarm", function () {
  it("Should allow deposits, harvests, and withdrawals", async function () {
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
  const saddlePoolToken = new ethers.Contract("0xd48cF4D7FB0824CC8bAe055dF3092584d0a1726A", TOKEN_ABI, ethers.provider);
  const alusd = new ethers.Contract(tokenList[0].address, TOKEN_ABI, ethers.provider);

  let amounts = [
    0, 0, 0, await lusd.balanceOf(signers[1].address)
  ]

  await lusd.connect(signers[1]).approve(vault.address, ethers.constants.MaxInt256);

  await vault.connect(signers[1]).depositStable(amounts, 0, signers[1].address);

  // Increase time by 30 days
  await ethers.provider.send('evm_increaseTime', [86400 * 30]);
  await ethers.provider.send('evm_mine', []);

  // await vault.connect(signers[0]).harvest([0,0,0,0]);

  console.log(await vault.totalAssets());

  await uniswap.connect(signers[2]).swapExactETHForTokens(0, route, signers[2].address, "9999999999", {value: ethers.utils.parseEther('1.35')});
  await uniswap.connect(signers[3]).swapExactETHForTokens(0, route, signers[3].address, "9999999999", {value: ethers.utils.parseEther('1.35')});
  await uniswap.connect(signers[4]).swapExactETHForTokens(0, route, signers[4].address, "9999999999", {value: ethers.utils.parseEther('1.35')});

  amounts = [
    0, 0, 0, await lusd.balanceOf(signers[2].address)
  ]
  await lusd.connect(signers[2]).approve(vault.address, ethers.constants.MaxInt256);

  amounts = [
    0, 0, 0, await lusd.balanceOf(signers[3].address)
  ]
  await lusd.connect(signers[3]).approve(vault.address, ethers.constants.MaxInt256);

  amounts = [
    0, 0, 0, await lusd.balanceOf(signers[4].address)
  ]
  await lusd.connect(signers[4]).approve(vault.address, ethers.constants.MaxInt256);

  await vault.connect(signers[2]).depositStable(amounts, 0, signers[2].address);
  await vault.connect(signers[3]).depositStable(amounts, 0, signers[3].address);
  await vault.connect(signers[4]).depositStable(amounts, 0, signers[4].address);

  // Increase time by 30 days
  await ethers.provider.send('evm_increaseTime', [86400 * 30]);
  await ethers.provider.send('evm_mine', []);

  // await vault.connect(signers[0]).harvest([0,0,0,0]);

  const shares1 = await vault.balanceOf(signers[1].address)
  const assets1 = await vault.convertToAssets(shares1);
  await vault.connect(signers[1])["withdraw(uint256,address,address)"](assets1, signers[1].address, signers[1].address);
  expect(await vault.balanceOf(signers[1].address)).to.equal(0);
  expect(await saddlePoolToken.balanceOf(signers[1].address)).to.equal(assets1);

  await ethers.provider.send('evm_increaseTime', [86400]);
  await ethers.provider.send('evm_mine', []);

  const shares2 = await vault.balanceOf(signers[2].address);
  const assets2 = await vault.convertToAssets(shares2);
  await vault.connect(signers[2]).redeem(shares2, signers[2].address, signers[2].address);
  expect(await vault.balanceOf(signers[2].address)).to.equal(0);
  expect(await saddlePoolToken.balanceOf(signers[2].address)).to.equal(assets2);

  await ethers.provider.send('evm_increaseTime', [86400]);
  await ethers.provider.send('evm_mine', []);

  const assets3 = await vault.convertToAssets(await vault.balanceOf(signers[3].address));
  await vault.connect(signers[3])["withdraw(uint256,address,address)"](assets3, signers[3].address, signers[3].address);
  expect(await vault.balanceOf(signers[3].address)).to.equal(0);
  expect(await saddlePoolToken.balanceOf(signers[3].address)).to.equal(assets3);

  await ethers.provider.send('evm_increaseTime', [86400]);
  await ethers.provider.send('evm_mine', []);

  const assets4 = await vault.convertToAssets(await vault.balanceOf(signers[4].address));
  await vault.connect(signers[4])["withdraw(uint256,address,address,uint256,uint8)"](assets4, signers[4].address, signers[4].address, 0, 0);
  expect(await vault.balanceOf(signers[4].address)).to.equal(0);
  expect(await saddlePoolToken.balanceOf(signers[4].address)).to.equal(0);
  expect(Number(ethers.utils.formatEther((await alusd.balanceOf(signers[4].address)).toString()))).to.greaterThan(0);

  expect(await vault.totalAssets()).to.equal(0);

  });
});
