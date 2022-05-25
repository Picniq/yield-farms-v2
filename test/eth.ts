import { expect } from "chai";
import { ethers } from "hardhat";

describe("ETHFarm", function () {
    it("Should allow deposits, harvests, and withdrawals", async function () {
        // Get signers to use for transactions
        const signers = await ethers.getSigners();

        // We get the contract to deploy
        const Vault = await ethers.getContractFactory("ETHFarm");
        const vault = await Vault.deploy("ETH FARM", "PETH");

        await vault.deployed();

        console.log("Vault deployed to:", vault.address);

        await vault
            .connect(signers[1])
            .depositETH(signers[1].address, {
                value: ethers.utils.parseEther("1.0"),
            });
        await vault
            .connect(signers[2])
            .depositETH(signers[2].address, {
                value: ethers.utils.parseEther("1.0"),
            });
        await vault
            .connect(signers[3])
            .depositETH(signers[3].address, {
                value: ethers.utils.parseEther("1.0"),
            });

        console.log(await vault.totalAssets());

        const shares1 = await vault.balanceOf(signers[1].address);
        const assets1 = await vault.convertToAssets(shares1);
        await vault
            .connect(signers[1])
            ["withdraw(uint256,address,address,uint256,uint8)"](
                assets1,
                signers[1].address,
                signers[1].address,
                0,
                0
            );

        const shares2 = await vault.balanceOf(signers[2].address);
        const assets2 = await vault.convertToAssets(shares2);
        await vault
            .connect(signers[2])
            ["withdraw(uint256,address,address)"](
                assets2,
                signers[2].address,
                signers[2].address
            );

        const shares3 = await vault.balanceOf(signers[3].address);
        await vault
            .connect(signers[3])
            ["redeem(uint256,address,address,uint256,uint8)"](
                shares3,
                signers[3].address,
                signers[3].address,
                0,
                0
            );

        console.log(shares1, shares2, shares3);
        console.log(await vault.totalAssets());
        console.log(await vault.totalSupply());
    });
});
