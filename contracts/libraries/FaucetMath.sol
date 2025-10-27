// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title FaucetMath
 * @notice Library for dynamic faucet calculations
 * @dev Contains pure functions for multiplier and amount calculations
 */
library FaucetMath {
    // Precision for percentage calculations (100% = 10000)
    uint256 private constant PRECISION = 10000;

    // Balance tier thresholds (percentage of max supply)
    uint256 private constant TIER_1_THRESHOLD = 7500; // 75%
    uint256 private constant TIER_2_THRESHOLD = 5000; // 50%
    uint256 private constant TIER_3_THRESHOLD = 2500; // 25%
    uint256 private constant TIER_4_THRESHOLD = 1000; // 10%

    // Balance tier multipliers (percentage)
    uint256 private constant TIER_1_MULTIPLIER = 10000; // 100%
    uint256 private constant TIER_2_MULTIPLIER = 8000;  // 80%
    uint256 private constant TIER_3_MULTIPLIER = 5000;  // 50%
    uint256 private constant TIER_4_MULTIPLIER = 3000;  // 30%
    uint256 private constant TIER_5_MULTIPLIER = 1000;  // 10%

    // Time-based multipliers (percentage)
    uint256 private constant OFF_PEAK_MULTIPLIER = 12000; // 120% (00:00-08:00 UTC)
    uint256 private constant NORMAL_MULTIPLIER = 10000;   // 100% (08:00-16:00 UTC)
    uint256 private constant PEAK_MULTIPLIER = 8000;      // 80%  (16:00-24:00 UTC)

    // Cooldown multipliers based on request count
    uint256 private constant LOW_TRAFFIC_MAX = 10;
    uint256 private constant MEDIUM_TRAFFIC_MAX = 50;
    uint256 private constant HIGH_TRAFFIC_MAX = 100;

    /**
     * @notice Calculate balance-based multiplier
     * @param currentBalance Current token balance in faucet
     * @param maxSupply Maximum supply allocated to faucet
     * @return multiplier Multiplier in basis points (10000 = 100%)
     */
    function calculateBalanceMultiplier(
        uint256 currentBalance,
        uint256 maxSupply
    ) internal pure returns (uint256 multiplier) {
        if (maxSupply == 0) return PRECISION;

        // Calculate percentage of max supply (in basis points)
        uint256 balanceRatio = (currentBalance * PRECISION) / maxSupply;

        // Determine tier and return corresponding multiplier
        if (balanceRatio >= TIER_1_THRESHOLD) {
            return TIER_1_MULTIPLIER; // 100%
        } else if (balanceRatio >= TIER_2_THRESHOLD) {
            return TIER_2_MULTIPLIER; // 80%
        } else if (balanceRatio >= TIER_3_THRESHOLD) {
            return TIER_3_MULTIPLIER; // 50%
        } else if (balanceRatio >= TIER_4_THRESHOLD) {
            return TIER_4_MULTIPLIER; // 30%
        } else {
            return TIER_5_MULTIPLIER; // 10%
        }
    }

    /**
     * @notice Calculate time-based multiplier
     * @param timestamp Current block timestamp
     * @return multiplier Multiplier in basis points (10000 = 100%)
     */
    function calculateTimeMultiplier(
        uint256 timestamp
    ) internal pure returns (uint256 multiplier) {
        // Get hour of day in UTC (0-23)
        uint256 hourOfDay = (timestamp / 1 hours) % 24;

        if (hourOfDay < 8) {
            // 00:00 - 08:00 UTC: Off-peak (120%)
            return OFF_PEAK_MULTIPLIER;
        } else if (hourOfDay < 16) {
            // 08:00 - 16:00 UTC: Normal (100%)
            return NORMAL_MULTIPLIER;
        } else {
            // 16:00 - 24:00 UTC: Peak (80%)
            return PEAK_MULTIPLIER;
        }
    }

    /**
     * @notice Calculate dynamic cooldown based on recent request count
     * @param requestCount Number of requests in the last hour
     * @param baseCooldown Base cooldown time in seconds
     * @return cooldown Adjusted cooldown time in seconds
     */
    function calculateDynamicCooldown(
        uint256 requestCount,
        uint256 baseCooldown
    ) internal pure returns (uint256 cooldown) {
        if (requestCount <= LOW_TRAFFIC_MAX) {
            // Low traffic: 1x base cooldown
            return baseCooldown;
        } else if (requestCount <= MEDIUM_TRAFFIC_MAX) {
            // Medium traffic: 2x base cooldown
            return baseCooldown * 2;
        } else if (requestCount <= HIGH_TRAFFIC_MAX) {
            // High traffic: 4x base cooldown
            return baseCooldown * 4;
        } else {
            // Very high traffic: 8x base cooldown
            return baseCooldown * 8;
        }
    }

    /**
     * @notice Calculate final amount with all multipliers applied
     * @param baseAmount Base amount to distribute
     * @param balanceMultiplier Balance-based multiplier (basis points)
     * @param timeMultiplier Time-based multiplier (basis points)
     * @return finalAmount Final calculated amount
     */
    function calculateFinalAmount(
        uint256 baseAmount,
        uint256 balanceMultiplier,
        uint256 timeMultiplier
    ) internal pure returns (uint256 finalAmount) {
        // Apply both multipliers: amount * (balanceMult/10000) * (timeMult/10000)
        finalAmount = (baseAmount * balanceMultiplier * timeMultiplier) / (PRECISION * PRECISION);
        return finalAmount;
    }

    /**
     * @notice Calculate referral bonus for new user
     * @param baseAmount Base amount per request
     * @return userBonus Bonus for the new user (20% of base)
     */
    function calculateNewUserBonus(
        uint256 baseAmount
    ) internal pure returns (uint256 userBonus) {
        // 20% bonus for new user
        return (baseAmount * 2000) / PRECISION;
    }

    /**
     * @notice Calculate referral reward for referrer
     * @param baseAmount Base amount per request
     * @return referrerReward Reward for the referrer (10% of base)
     */
    function calculateReferrerReward(
        uint256 baseAmount
    ) internal pure returns (uint256 referrerReward) {
        // 10% reward for referrer
        return (baseAmount * 1000) / PRECISION;
    }

    /**
     * @notice Get current hour index for tracking hourly statistics
     * @param timestamp Current timestamp
     * @return hourIndex Index representing the current hour slot
     */
    function getCurrentHourIndex(
        uint256 timestamp
    ) internal pure returns (uint256 hourIndex) {
        return timestamp / 1 hours;
    }

    /**
     * @notice Check if two timestamps are in the same UTC day
     * @param timestamp1 First timestamp
     * @param timestamp2 Second timestamp
     * @return True if both timestamps are in the same day
     */
    function isSameDay(
        uint256 timestamp1,
        uint256 timestamp2
    ) internal pure returns (bool) {
        return (timestamp1 / 1 days) == (timestamp2 / 1 days);
    }
}
