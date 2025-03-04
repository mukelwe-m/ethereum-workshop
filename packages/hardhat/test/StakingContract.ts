import { expect } from "chai";
import { ethers } from "hardhat";
import { StakingContract } from "../typechain-types/contracts/StakingContract.sol";
import { AttackerContract } from "../typechain-types/contracts/AttackerContract.sol";
import { type HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("StakingContract", function () {
  // We define a fixture to reuse the same setup in every test.
  let stakingContract: StakingContract, stakingContractAddress: string;
  let attackerContract: AttackerContract;
  let owner: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner;
  before(async () => {
    // Get the Signers object from ethers
    [owner, user1, user2, user3] = await ethers.getSigners();

    const stakingContractFactory = await ethers.getContractFactory("StakingContract");
    stakingContract = (await stakingContractFactory.deploy(owner.address, 2)) as StakingContract;

    await stakingContract.waitForDeployment();
    stakingContractAddress = await stakingContract.getAddress();

    // attacker contract
    const attackerContractFactory = await ethers.getContractFactory("AttackerContract");
    attackerContract = (await attackerContractFactory.deploy()) as AttackerContract;
  });

  describe("Deployment", function () {
    it("Should have the right owner on deploy", async function () {
      expect(await stakingContract.owner()).to.equal(owner.address);
    });
  });

  describe("Add users", function () {
    it("Should not allow adding a user without staking", async function () {
      // User should not be added without a staking amount
      await expect(stakingContract.connect(user1).addUser("user1", 20, 0)).to.be.revertedWith("The staking value is 0");
    });

    it("Should allow adding users", async function () {
      // Execute a contract's method from another account using connect
      await stakingContract.connect(user1).addUser("user1", 20, 0, { value: ethers.parseUnits("20", "ether") });

      // Dynamic array can be returned in chunks or specific indexes
      expect(await stakingContract.userAddresses(0)).to.equal(user1.address);

      // Add user 2
      await stakingContract.connect(user2).addUser("user2", 20, 0, { value: ethers.parseUnits("20", "ether") });
      expect(await stakingContract.userAddresses(1)).to.equal(user2.address);
    });

    it("Should not allow adding an existing user", async function () {
      // An existing user cannot rejoin staking pool
      await expect(
        stakingContract.connect(user1).addUser("user1", 20, 0, { value: ethers.parseUnits("20", "ether") }),
      ).to.be.revertedWith("User already exists");
    });

    it("Should not allow adding users over the max limit", async function () {
      // Users should not exceed the maximum allowed
      await expect(
        stakingContract.connect(user3).addUser("user3", 20, 0, { value: ethers.parseUnits("20", "ether") }),
      ).to.be.revertedWith("Users are over the limit of 2");
    });
  });

  describe("Withdrawal", function () {
    it("Should not allow a user without a balance to withdraw", async function () {
      await expect(stakingContract.connect(user3).withdraw()).to.be.revertedWith("No balance to withdraw");
    });

    it("Should allow a staked user to withdraw", async function () {
      const user1BalETH = await ethers.provider.getBalance(user1.address);

      // Withdraw and keep gas used receipt
      const transactionResponse = await stakingContract.connect(user1).withdraw();

      const receipt = await transactionResponse.wait();
      const gasCostForTxn = receipt!.gasUsed * receipt!.gasPrice;

      // addr1 should have been popped from the user addresses
      expect(await ethers.provider.getBalance(stakingContractAddress)).to.equal(ethers.parseUnits("20", "ether"));
      expect(await ethers.provider.getBalance(user1.address)).to.equal(
        user1BalETH + ethers.parseUnits("20", "ether") - gasCostForTxn,
      );
    });

    it("Should delete a user after withdrawal", async function () {
      expect(await stakingContract.getUserCount()).to.equal(1);
    });

    // TODO: Comment out this section to test out a re-entrance attack
    // it("Should allow a re-entry attack", async function () {
    //   const transactionResponse = await attackerContract
    //     .connect(user3)
    //     .attack(stakingContractAddress, { value: ethers.parseUnits("2", "ether") });
    //   expect(await ethers.provider.getBalance(stakingContractAddress)).to.equal(ethers.parseUnits("0", "ether"));
    // });

    it("Should not allow a re-entry attack", async function () {
      await expect(
        attackerContract.connect(user3).attack(stakingContractAddress, { value: ethers.parseUnits("2", "ether") }),
      ).to.be.reverted;
      expect(await ethers.provider.getBalance(stakingContractAddress)).to.equal(ethers.parseUnits("20", "ether"));
    });
  });
});
