const { expect } = require("chai");

describe("Staking contract", function () {
    it("Deployment should assign the admin rights to the owner", async function () {
    const [owner] = await ethers.getSigners();

    const Stake = await ethers.getContractFactory("Staking");

    const hardhatToken = await Stake.deploy("0x58C2123006b9003e899AbC8f5f30f0C96fB92179");

    const ownerBalance = await hardhatToken.balanceOf(owner.address);

    expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
    });
});
