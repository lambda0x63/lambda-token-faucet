// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FaucetAdmin.sol";
import "./ReferralSystem.sol";
import "./FaucetStats.sol";
import "./libraries/FaucetMath.sol";

/**
 * @title LambdaFaucet
 * @notice Main faucet contract that integrates all modules
 * @dev Coordinates admin, referral, stats, and dynamic distribution logic
 */
contract LambdaFaucet is ReentrancyGuard {
    using FaucetMath for uint256;

    // Token being distributed
    IERC20 public immutable token;

    // Module contracts
    FaucetAdmin public admin;
    ReferralSystem public referralSystem;
    FaucetStats public stats;

    // User request tracking
    mapping(address => uint256) public lastRequestTime;

    // Events
    event TokensRequested(
        address indexed user,
        uint256 amount,
        uint256 balanceMultiplier,
        uint256 timeMultiplier
    );
    event ReferralRewardPaid(
        address indexed referrer,
        address indexed referee,
        uint256 amount
    );
    event FaucetFunded(address indexed funder, uint256 amount);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Constructor
     * @param _token Address of the ERC20 token to distribute
     * @param _admin Address of the FaucetAdmin contract
     * @param _referralSystem Address of the ReferralSystem contract
     * @param _stats Address of the FaucetStats contract
     */
    constructor(
        address _token,
        address _admin,
        address _referralSystem,
        address _stats
    ) {
        require(_token != address(0), "Invalid token address");
        require(_admin != address(0), "Invalid admin address");
        require(_referralSystem != address(0), "Invalid referral address");
        require(_stats != address(0), "Invalid stats address");

        token = IERC20(_token);
        admin = FaucetAdmin(_admin);
        referralSystem = ReferralSystem(_referralSystem);
        stats = FaucetStats(_stats);
    }

    /**
     * @notice Request tokens from the faucet
     * @param referralCode Optional referral code for new users
     * @dev Main entry point for users to receive tokens
     */
    function requestTokens(bytes32 referralCode) external nonReentrant {
        address user = msg.sender;

        // 1. Admin checks
        require(!admin.isPaused(), "Faucet is paused");
        require(!admin.isBlacklisted(user), "Address is blacklisted");

        // 2. Cooldown check with dynamic adjustment
        uint256 cooldown = admin.getDynamicCooldown();
        require(
            block.timestamp >= lastRequestTime[user] + cooldown,
            "Please wait before requesting again"
        );

        // 3. Check if first-time user
        bool isFirstTime = (lastRequestTime[user] == 0);

        // 4. Handle referral code (first-time users)
        if (isFirstTime) {
            if (referralCode != bytes32(0)) {
                // User provided a referral code
                _registerWithReferral(user, referralCode);
            } else {
                // Generate code for new user (even without referral)
                referralSystem.generateReferralCode(user);
            }
        }

        // 5. Calculate final distribution amount
        uint256 finalAmount = _calculateDistributionAmount(user, isFirstTime);

        // 6. Verify faucet has sufficient balance
        uint256 faucetBalance = token.balanceOf(address(this));
        require(faucetBalance >= finalAmount, "Faucet is empty");

        // 7. Update request timestamp
        lastRequestTime[user] = block.timestamp;

        // 8. Transfer tokens to user
        require(token.transfer(user, finalAmount), "Token transfer failed");

        // 9. Process referral reward if applicable
        _processReferralReward(user);

        // 10. Update statistics
        stats.recordRequest(user, finalAmount, isFirstTime);
        admin.incrementHourlyCount();

        // 11. Emit event
        (uint256 balanceMult, uint256 timeMult) = _getMultipliers();
        emit TokensRequested(user, finalAmount, balanceMult, timeMult);
    }

    /**
     * @notice Calculate the final distribution amount for a user
     * @param user Address of the user
     * @param isFirstTime Whether this is user's first request
     * @return amount Final calculated amount
     */
    function _calculateDistributionAmount(
        address user,
        bool isFirstTime
    ) internal view returns (uint256 amount) {
        // Get base amount from admin
        (uint256 baseAmount, ) = admin.getBaseParameters();

        // Calculate dynamic multipliers if enabled
        if (admin.isDynamicEnabled()) {
            uint256 currentBalance = token.balanceOf(address(this));
            uint256 maxSupply = admin.getMaxSupply();

            uint256 balanceMultiplier = FaucetMath.calculateBalanceMultiplier(
                currentBalance,
                maxSupply
            );

            uint256 timeMultiplier = FaucetMath.calculateTimeMultiplier(block.timestamp);

            amount = FaucetMath.calculateFinalAmount(
                baseAmount,
                balanceMultiplier,
                timeMultiplier
            );
        } else {
            // Dynamic disabled, use base amount
            amount = baseAmount;
        }

        // Add referral bonus for first-time users
        if (isFirstTime) {
            (uint256 userBonus, ) = referralSystem.calculateReferralBonus(user, baseAmount);
            amount += userBonus;
        }

        return amount;
    }

    /**
     * @notice Register new user with referral code
     * @param user Address of the new user
     * @param referralCode Referral code to use
     */
    function _registerWithReferral(address user, bytes32 referralCode) internal {
        try referralSystem.registerReferral(user, referralCode) {
            // Referral registration successful
        } catch {
            // If referral registration fails, still generate user's own code
            referralSystem.generateReferralCode(user);
        }
    }

    /**
     * @notice Process referral reward for the referrer
     * @param user Address of the user who made the request
     */
    function _processReferralReward(address user) internal {
        (uint256 baseAmount, ) = admin.getBaseParameters();
        (address referrer, uint256 bonus) = referralSystem.getReferrerAndBonus(user, baseAmount);

        if (referrer != address(0) && bonus > 0) {
            uint256 faucetBalance = token.balanceOf(address(this));

            // Only pay if faucet has enough balance
            if (faucetBalance >= bonus) {
                require(token.transfer(referrer, bonus), "Referral reward transfer failed");
                referralSystem.recordReferralReward(referrer, bonus);
                emit ReferralRewardPaid(referrer, user, bonus);
            }
        }
    }

    /**
     * @notice Get current multipliers
     * @return balanceMultiplier Current balance-based multiplier
     * @return timeMultiplier Current time-based multiplier
     */
    function _getMultipliers()
        internal
        view
        returns (uint256 balanceMultiplier, uint256 timeMultiplier)
    {
        if (admin.isDynamicEnabled()) {
            uint256 currentBalance = token.balanceOf(address(this));
            uint256 maxSupply = admin.getMaxSupply();

            balanceMultiplier = FaucetMath.calculateBalanceMultiplier(
                currentBalance,
                maxSupply
            );
            timeMultiplier = FaucetMath.calculateTimeMultiplier(block.timestamp);
        } else {
            balanceMultiplier = 10000; // 100%
            timeMultiplier = 10000;    // 100%
        }

        return (balanceMultiplier, timeMultiplier);
    }

    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Get time until user can make next request
     * @param user Address of the user
     * @return timeLeft Seconds until next request (0 if can request now)
     */
    function getTimeUntilNextRequest(address user) external view returns (uint256 timeLeft) {
        uint256 cooldown = admin.getDynamicCooldown();
        uint256 nextAvailable = lastRequestTime[user] + cooldown;

        if (block.timestamp >= nextAvailable) {
            return 0;
        }

        return nextAvailable - block.timestamp;
    }

    /**
     * @notice Estimate amount user would receive if requesting now
     * @param user Address of the user
     * @return estimatedAmount Estimated token amount
     */
    function getEstimatedAmount(address user) external view returns (uint256 estimatedAmount) {
        bool isFirstTime = (lastRequestTime[user] == 0);
        return _calculateDistributionAmount(user, isFirstTime);
    }

    /**
     * @notice Get user's referral code
     * @return code User's unique referral code
     */
    function getMyReferralCode() external view returns (bytes32 code) {
        return referralSystem.getMyReferralCode(msg.sender);
    }

    /**
     * @notice Get comprehensive faucet information
     * @return balance Current token balance in faucet
     * @return baseAmount Base amount per request
     * @return currentCooldown Current cooldown time
     * @return paused Whether faucet is paused
     * @return dynamicEnabled Whether dynamic adjustments are enabled
     */
    function getFaucetInfo()
        external
        view
        returns (
            uint256 balance,
            uint256 baseAmount,
            uint256 currentCooldown,
            bool paused,
            bool dynamicEnabled
        )
    {
        balance = token.balanceOf(address(this));
        (baseAmount, ) = admin.getBaseParameters();
        currentCooldown = admin.getDynamicCooldown();
        paused = admin.isPaused();
        dynamicEnabled = admin.isDynamicEnabled();

        return (balance, baseAmount, currentCooldown, paused, dynamicEnabled);
    }

    /**
     * @notice Get current multipliers being applied
     * @return balanceMultiplier Balance-based multiplier (basis points)
     * @return timeMultiplier Time-based multiplier (basis points)
     */
    function getCurrentMultipliers()
        external
        view
        returns (uint256 balanceMultiplier, uint256 timeMultiplier)
    {
        return _getMultipliers();
    }

    /**
     * @notice Get user's complete faucet status
     * @param user Address of the user
     * @return canRequest Whether user can request now
     * @return timeUntilNext Seconds until next request
     * @return estimatedAmount Amount user would receive
     * @return totalReceived Total tokens received so far
     * @return requestCount Number of requests made
     */
    function getUserStatus(address user)
        external
        view
        returns (
            bool canRequest,
            uint256 timeUntilNext,
            uint256 estimatedAmount,
            uint256 totalReceived,
            uint256 requestCount
        )
    {
        // Check if can request
        uint256 cooldown = admin.getDynamicCooldown();
        uint256 nextAvailable = lastRequestTime[user] + cooldown;
        canRequest = (block.timestamp >= nextAvailable) && !admin.isPaused() && !admin.isBlacklisted(user);

        // Time until next
        if (block.timestamp >= nextAvailable) {
            timeUntilNext = 0;
        } else {
            timeUntilNext = nextAvailable - block.timestamp;
        }

        // Estimated amount
        bool isFirstTime = (lastRequestTime[user] == 0);
        estimatedAmount = _calculateDistributionAmount(user, isFirstTime);

        // Stats
        (requestCount, totalReceived, , , ) = stats.getUserReport(user);

        return (canRequest, timeUntilNext, estimatedAmount, totalReceived, requestCount);
    }

    /**
     * @notice Get referral information for a user
     * @param user Address of the user
     * @return referralCode User's referral code
     * @return referralCount Number of successful referrals
     * @return totalRewards Total referral rewards earned
     */
    function getUserReferralInfo(address user)
        external
        view
        returns (
            bytes32 referralCode,
            uint256 referralCount,
            uint256 totalRewards
        )
    {
        ReferralSystem.ReferralData memory data = referralSystem.getReferralInfo(user);
        return (data.myReferralCode, data.referralCount, data.totalReferralRewards);
    }

    // ========== ADMIN FUNCTIONS ==========

    /**
     * @notice Fund the faucet with tokens
     * @param amount Amount of tokens to fund
     * @dev Anyone can fund the faucet
     */
    function fundFaucet(uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        emit FaucetFunded(msg.sender, amount);
    }

    /**
     * @notice Emergency withdrawal function (owner only)
     * @param tokenAddress Address of token to withdraw
     * @param to Recipient address
     * @param amount Amount to withdraw
     * @dev Can only be called by the admin contract owner
     */
    function emergencyWithdraw(
        address tokenAddress,
        address to,
        uint256 amount
    ) external {
        require(msg.sender == admin.owner(), "Only admin owner");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        IERC20 withdrawToken = IERC20(tokenAddress);
        require(
            withdrawToken.transfer(to, amount),
            "Withdrawal failed"
        );

        emit EmergencyWithdrawal(tokenAddress, to, amount);
    }

    /**
     * @notice Get contract version
     * @return version Version string
     */
    function version() external pure returns (string memory) {
        return "LambdaFaucet v1.0.0";
    }
}
