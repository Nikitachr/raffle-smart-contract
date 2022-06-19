import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { expect, use } from "chai";
import { RandomWinnerGame } from "../typechain";

const LINK_TOKEN = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB";
const VRF_COORDINATOR = "0x8C7382F9D8f56b33781fE506E897a4F1e2d17255";
const KEY_HASH =
  "0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4";
const FEE = ethers.utils.parseEther("0.0001");

const toEth = (val: string) => ethers.utils.parseEther(val);

describe("RandomWinnerGame", () => {
  let owner: SignerWithAddress;
  let user: SignerWithAddress;
  let randomWinner: RandomWinnerGame;

  beforeEach(async () => {
    [owner, user] = await ethers.getSigners();
    const RandomWinnerGame = await ethers.getContractFactory(
      "RandomWinnerGame"
    );
    randomWinner = await RandomWinnerGame.deploy(
      VRF_COORDINATOR,
      LINK_TOKEN,
      KEY_HASH,
      FEE
    );
    await randomWinner.deployed();
  });

  it("is deployed", async () => {
    expect(await randomWinner.deployed()).to.equal(randomWinner);
  });

  describe("start game", () => {
    it("only owner can start", async () => {
      await expect(randomWinner.connect(user.address).startNewGame()).to.be
        .reverted;
    });

    beforeEach(async () => {
      await randomWinner.startNewGame();
    });

    it("game is started", async () => {
      expect(await randomWinner.gameStarted()).to.equal(true);
    });

    it("total balance is 0", async () => {
      expect(await randomWinner.totalBalance()).to.equal(toEth("0"));
    });

    it("entry fee is 0.01", async () => {
      expect(await randomWinner.entryFee()).to.equal(toEth("0.01"));
    });
  });

  describe("add balance", () => {
    describe("when game is not started", () => {
      it("cant add balance", async () => {
        await expect(
          randomWinner.addBalance({ value: toEth("1") })
        ).to.be.revertedWith("Game has not been started yet");
      });
    });

    describe("when game is started", () => {
      beforeEach(async () => {
        await randomWinner.startNewGame();
      });

      it("cant join if value less then fee", async () => {
        await expect(
          randomWinner.connect(user).addBalance({ value: toEth("0.01") })
        ).to.be.revertedWith("Value sent is less then fee");
      });

      it("can join if enough value", async () => {
        await expect(
          randomWinner.addBalance({ value: toEth("1") })
        ).to.be.not.revertedWith("Value sent is less then fee");
      });

      it("balance is added", async () => {
        await randomWinner.addBalance({ value: toEth("1") });
        expect(await randomWinner.totalBalance()).to.equal(toEth("0.99"));
      });
    });
  });
});
