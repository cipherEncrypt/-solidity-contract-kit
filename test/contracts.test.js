const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Token", function () {
  let token, owner, alice;

  beforeEach(async () => {
    [owner, alice] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    token = await Token.deploy("My Token", "MYT", 1_000_000, 1000);
  });

  it("mints initial supply to deployer", async () => {
    expect(await token.balanceOf(owner.address)).to.equal(
      ethers.parseUnits("1000", 18)
    );
  });

  it("lets owner mint up to the cap", async () => {
    await token.mint(alice.address, ethers.parseUnits("500", 18));
    expect(await token.balanceOf(alice.address)).to.equal(
      ethers.parseUnits("500", 18)
    );
  });

  it("reverts when minting past the cap", async () => {
    await expect(
      token.mint(alice.address, ethers.parseUnits("1000000", 18))
    ).to.be.revertedWith("cap exceeded");
  });

  it("lets holders burn their tokens", async () => {
    await token.burn(ethers.parseUnits("100", 18));
    expect(await token.balanceOf(owner.address)).to.equal(
      ethers.parseUnits("900", 18)
    );
  });
});

describe("NFTCollection", function () {
  let nft, owner, alice;
  const price = ethers.parseEther("0.01");

  beforeEach(async () => {
    [owner, alice] = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("NFTCollection");
    nft = await NFT.deploy("Art", "ART", 3, price);
  });

  it("mints when paid enough", async () => {
    await nft.connect(alice).mint("ipfs://token1", { value: price });
    expect(await nft.ownerOf(0)).to.equal(alice.address);
    expect(await nft.tokenURI(0)).to.equal("ipfs://token1");
  });

  it("reverts on underpayment", async () => {
    await expect(
      nft.connect(alice).mint("ipfs://x", { value: 1 })
    ).to.be.revertedWith("insufficient payment");
  });

  it("enforces max supply", async () => {
    for (let i = 0; i < 3; i++) {
      await nft.connect(alice).mint(`ipfs://${i}`, { value: price });
    }
    await expect(
      nft.connect(alice).mint("ipfs://x", { value: price })
    ).to.be.revertedWith("sold out");
  });

  it("lets owner withdraw", async () => {
    await nft.connect(alice).mint("ipfs://x", { value: price });
    await expect(nft.withdraw()).to.changeEtherBalance(owner, price);
  });
});

describe("Staking", function () {
  let stakeToken, rewardToken, staking, owner, alice;

  beforeEach(async () => {
    [owner, alice] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    stakeToken = await Token.deploy("Stake", "STK", 1_000_000, 10_000);
    rewardToken = await Token.deploy("Reward", "RWD", 1_000_000, 10_000);

    const Staking = await ethers.getContractFactory("Staking");
    staking = await Staking.deploy(
      await stakeToken.getAddress(),
      await rewardToken.getAddress(),
      ethers.parseUnits("1", 18) // 1 reward token/sec
    );

    // fund staking contract with rewards
    await rewardToken.transfer(
      await staking.getAddress(),
      ethers.parseUnits("5000", 18)
    );
    // give alice some stake tokens
    await stakeToken.transfer(alice.address, ethers.parseUnits("1000", 18));
    await stakeToken
      .connect(alice)
      .approve(await staking.getAddress(), ethers.MaxUint256);
  });

  it("accrues rewards over time", async () => {
    await staking.connect(alice).stake(ethers.parseUnits("100", 18));
    await time.increase(100);
    const earned = await staking.earned(alice.address);
    expect(earned).to.be.gt(0);
  });

  it("lets user exit with stake and rewards", async () => {
    await staking.connect(alice).stake(ethers.parseUnits("100", 18));
    await time.increase(50);
    await staking.connect(alice).exit();
    expect(await staking.balances(alice.address)).to.equal(0);
    expect(await rewardToken.balanceOf(alice.address)).to.be.gt(0);
  });

  it("lets exit() sweep rewards even after the stake is gone", async () => {
    await staking.connect(alice).stake(ethers.parseUnits("100", 18));
    await time.increase(50);
    // Withdraw the whole stake first, leaving only unclaimed rewards behind.
    await staking.connect(alice).withdraw(ethers.parseUnits("100", 18));
    // exit() should still collect the rewards instead of reverting.
    await expect(staking.connect(alice).exit()).to.not.be.reverted;
    expect(await rewardToken.balanceOf(alice.address)).to.be.gt(0);
  });

  it("rejects zero token addresses at deploy", async () => {
    const Staking = await ethers.getContractFactory("Staking");
    await expect(
      Staking.deploy(ethers.ZeroAddress, await rewardToken.getAddress(), 1)
    ).to.be.revertedWith("staking token is zero");
  });
});

describe("Vesting", function () {
  let token, vesting, owner, beneficiary;

  beforeEach(async () => {
    [owner, beneficiary] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    token = await Token.deploy("Vest", "VST", 1_000_000, 10_000);

    const now = await time.latest();
    const Vesting = await ethers.getContractFactory("Vesting");
    vesting = await Vesting.deploy(
      await token.getAddress(),
      beneficiary.address,
      now,        // start
      100,        // cliff seconds
      1000        // duration seconds
    );
    await token.transfer(
      await vesting.getAddress(),
      ethers.parseUnits("1000", 18)
    );
  });

  it("releases nothing before the cliff", async () => {
    expect(await vesting.releasable()).to.equal(0);
  });

  it("releases linearly after the cliff", async () => {
    await time.increase(500);
    const releasable = await vesting.releasable();
    expect(releasable).to.be.gt(0);
    await vesting.release();
    expect(await token.balanceOf(beneficiary.address)).to.be.gt(0);
  });

  it("releases everything after full duration", async () => {
    await time.increase(1001);
    await vesting.release();
    expect(await token.balanceOf(beneficiary.address)).to.equal(
      ethers.parseUnits("1000", 18)
    );
  });
});

describe("MultiSigWallet", function () {
  let wallet, owner1, owner2, owner3, recipient;

  beforeEach(async () => {
    [owner1, owner2, owner3, recipient] = await ethers.getSigners();
    const MultiSig = await ethers.getContractFactory("MultiSigWallet");
    wallet = await MultiSig.deploy(
      [owner1.address, owner2.address, owner3.address],
      2
    );
    // fund it
    await owner1.sendTransaction({
      to: await wallet.getAddress(),
      value: ethers.parseEther("1"),
    });
  });

  it("requires enough confirmations to execute", async () => {
    await wallet.submit(recipient.address, ethers.parseEther("0.5"), "0x");
    await wallet.connect(owner1).confirm(0);
    await expect(wallet.connect(owner1).execute(0)).to.be.revertedWith(
      "not enough confirmations"
    );
    await wallet.connect(owner2).confirm(0);
    await expect(wallet.connect(owner1).execute(0)).to.changeEtherBalance(
      recipient,
      ethers.parseEther("0.5")
    );
  });

  it("rejects non-owners", async () => {
    await expect(
      wallet.connect(recipient).submit(recipient.address, 0, "0x")
    ).to.be.revertedWith("not owner");
  });

  it("lets an owner revoke a confirmation before execution", async () => {
    await wallet.submit(recipient.address, ethers.parseEther("0.5"), "0x");
    await wallet.connect(owner1).confirm(0);
    await wallet.connect(owner2).confirm(0);
    // Owner2 changes their mind, dropping us back below the threshold.
    await wallet.connect(owner2).revoke(0);
    await expect(wallet.connect(owner1).execute(0)).to.be.revertedWith(
      "not enough confirmations"
    );
  });
});
