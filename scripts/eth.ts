// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    async function mineBlocks(n: number) {
        for (let index = 0; index < n; index++) {
          await ethers.provider.send('evm_mine', []);
        }
      }
  
    // Get signers to use for transactions
    const signers = await ethers.getSigners();
  
    // We get the contract to deploy
    const Vault = await ethers.getContractFactory("ETHFarm");
    const vault = await Vault.deploy('ETH FARM', 'PETH');
  
    await vault.deployed();
  
    console.log("Vault deployed to:", vault.address);

    await vault.connect(signers[1]).depositETH(signers[1].address, { value: ethers.utils.parseEther('1.0') });
    await vault.connect(signers[2]).depositETH(signers[2].address, { value: ethers.utils.parseEther('1.0') });
    await vault.connect(signers[3]).depositETH(signers[3].address, { value: ethers.utils.parseEther('1.0') });

    console.log(await vault.totalAssets());
    
    const shares1 = await vault.balanceOf(signers[1].address);
    const assets1 = await vault.convertToAssets(shares1);
    await vault.connect(signers[1])["withdraw(uint256,address,address,uint256,uint8)"](assets1, signers[1].address, signers[1].address, 0, 0);

    console.log(await vault.totalAssets());

    const shares2 = await vault.balanceOf(signers[2].address);
    const assets2 = await vault.convertToAssets(shares2);
    await vault.connect(signers[2])["withdraw(uint256,address,address)"](assets2, signers[2].address, signers[2].address);

    console.log(await vault.totalAssets());

    const shares3 = await vault.balanceOf(signers[3].address);
    await vault.connect(signers[3])["redeem(uint256,address,address,uint256,uint8)"](shares3, signers[3].address, signers[3].address, 0, 0);

    console.log(await vault.totalAssets());
    console.log(await vault.totalSupply());

    // Increase time by 1 day
    // await mineBlocks(7200);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  