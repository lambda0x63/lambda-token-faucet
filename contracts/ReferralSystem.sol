// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./libraries/FaucetMath.sol";

/**
 * @title ReferralSystem
 * @notice Manages referral codes and bonuses for the Lambda Faucet
 * @dev Handles referral code generation, registration, and bonus calculations
 */
contract ReferralSystem {
    using FaucetMath for uint256;

    // Faucet contract address (only faucet can call certain functions)
    address public faucet;

    // Referral data structure
    struct ReferralData {
        address referrer;              // Address of the referrer
        uint256 referralCount;         // Number of people referred
        uint256 totalReferralRewards;  // Total rewards earned from referrals
        bool hasClaimedBonus;          // Whether user has claimed their signup bonus
        bytes32 myReferralCode;        // User's unique referral code
    }

    // Mappings
    mapping(address => ReferralData) public referrals;
    mapping(bytes32 => address) public codeToAddress;

    // Events
    event ReferralCodeGenerated(address indexed user, bytes32 code);
    event ReferralRegistered(address indexed newUser, address indexed referrer, bytes32 code);
    event ReferralBonusPaid(address indexed referrer, address indexed referee, uint256 amount);
    event FaucetUpdated(address indexed oldFaucet, address indexed newFaucet);

    // Modifiers
    modifier onlyFaucet() {
        require(msg.sender == faucet, "Only faucet can call");
        _;
    }

    /**
     * @notice Constructor
     * @param _faucet Address of the main faucet contract
     */
    constructor(address _faucet) {
        require(_faucet != address(0), "Invalid faucet address");
        faucet = _faucet;
    }

    /**
     * @notice Generate a unique referral code for a user
     * @param user Address of the user
     * @return code Generated referral code
     * @dev Can only be called by the faucet contract
     */
    function generateReferralCode(address user) external onlyFaucet returns (bytes32 code) {
        require(user != address(0), "Invalid user address");
        require(referrals[user].myReferralCode == bytes32(0), "Code already exists");

        // Generate unique code using user address and block data
        code = keccak256(
            abi.encodePacked(
                user,
                block.timestamp,
                block.prevrandao,
                blockhash(block.number - 1)
            )
        );

        // Ensure code is unique (highly unlikely to collide, but check anyway)
        uint256 nonce = 0;
        while (codeToAddress[code] != address(0)) {
            code = keccak256(abi.encodePacked(code, nonce));
            nonce++;
        }

        // Store the code
        referrals[user].myReferralCode = code;
        codeToAddress[code] = user;

        emit ReferralCodeGenerated(user, code);
        return code;
    }

    /**
     * @notice Register a new user with a referral code
     * @param newUser Address of the new user
     * @param referralCode Referral code used for signup
     * @dev Can only be called by the faucet contract
     */
    function registerReferral(address newUser, bytes32 referralCode) external onlyFaucet {
        require(newUser != address(0), "Invalid user address");
        require(referralCode != bytes32(0), "Invalid referral code");
        require(referrals[newUser].referrer == address(0), "Already registered");
        require(!referrals[newUser].hasClaimedBonus, "Bonus already claimed");

        // Get referrer from code
        address referrer = codeToAddress[referralCode];
        require(referrer != address(0), "Invalid referral code");
        require(referrer != newUser, "Cannot refer yourself");

        // Check that referrer has a valid code (has used faucet before)
        require(referrals[referrer].myReferralCode != bytes32(0), "Referrer not eligible");

        // Register the referral
        referrals[newUser].referrer = referrer;
        referrals[newUser].hasClaimedBonus = true;

        // Update referrer's stats
        referrals[referrer].referralCount++;

        emit ReferralRegistered(newUser, referrer, referralCode);
    }

    /**
     * @notice Calculate referral bonuses for a user
     * @param user Address of the user
     * @param baseAmount Base faucet amount
     * @return userBonus Bonus for the new user
     * @return referrerBonus Bonus for the referrer
     */
    function calculateReferralBonus(
        address user,
        uint256 baseAmount
    ) external view returns (uint256 userBonus, uint256 referrerBonus) {
        ReferralData storage data = referrals[user];

        // New user bonus (20%)
        if (data.referrer != address(0) && data.hasClaimedBonus) {
            userBonus = FaucetMath.calculateNewUserBonus(baseAmount);
        }

        // Referrer bonus (10%) - calculated but paid separately
        if (data.referrer != address(0)) {
            referrerBonus = FaucetMath.calculateReferrerReward(baseAmount);
        }

        return (userBonus, referrerBonus);
    }

    /**
     * @notice Get referrer and their bonus amount
     * @param user Address of the user
     * @param baseAmount Base faucet amount
     * @return referrer Address of the referrer (address(0) if none)
     * @return bonus Bonus amount for the referrer
     */
    function getReferrerAndBonus(
        address user,
        uint256 baseAmount
    ) external view returns (address referrer, uint256 bonus) {
        referrer = referrals[user].referrer;

        if (referrer != address(0) && referrals[user].hasClaimedBonus) {
            bonus = FaucetMath.calculateReferrerReward(baseAmount);
        }

        return (referrer, bonus);
    }

    /**
     * @notice Record referral reward payment
     * @param referrer Address of the referrer
     * @param amount Amount of reward paid
     * @dev Can only be called by the faucet contract
     */
    function recordReferralReward(
        address referrer,
        uint256 amount
    ) external onlyFaucet {
        require(referrer != address(0), "Invalid referrer");
        referrals[referrer].totalReferralRewards += amount;
    }

    /**
     * @notice Get complete referral information for a user
     * @param user Address of the user
     * @return data Complete ReferralData struct
     */
    function getReferralInfo(address user) external view returns (ReferralData memory data) {
        return referrals[user];
    }

    /**
     * @notice Get user's referral code
     * @param user Address of the user
     * @return code User's referral code
     */
    function getMyReferralCode(address user) external view returns (bytes32 code) {
        return referrals[user].myReferralCode;
    }

    /**
     * @notice Check if a referral code is valid
     * @param code Referral code to check
     * @return isValid True if code exists and is valid
     * @return owner Address of the code owner
     */
    function isValidReferralCode(
        bytes32 code
    ) external view returns (bool isValid, address owner) {
        owner = codeToAddress[code];
        isValid = (owner != address(0));
        return (isValid, owner);
    }

    /**
     * @notice Check if user has claimed their referral bonus
     * @param user Address of the user
     * @return claimed True if bonus has been claimed
     */
    function hasClaimedBonus(address user) external view returns (bool claimed) {
        return referrals[user].hasClaimedBonus;
    }

    /**
     * @notice Get referral statistics for a user
     * @param user Address of the user
     * @return referralCount Number of successful referrals
     * @return totalRewards Total rewards earned from referrals
     */
    function getReferralStats(
        address user
    ) external view returns (uint256 referralCount, uint256 totalRewards) {
        ReferralData storage data = referrals[user];
        return (data.referralCount, data.totalReferralRewards);
    }

    /**
     * @notice Update faucet contract address (emergency only)
     * @param newFaucet New faucet contract address
     * @dev This should be behind additional access control in production
     */
    function updateFaucet(address newFaucet) external {
        require(msg.sender == faucet, "Only current faucet");
        require(newFaucet != address(0), "Invalid address");

        address oldFaucet = faucet;
        faucet = newFaucet;

        emit FaucetUpdated(oldFaucet, newFaucet);
    }
}
