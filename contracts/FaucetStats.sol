// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title FaucetStats
 * @notice Tracks global and per-user statistics for the Lambda Faucet
 * @dev Stores simple statistics without complex time-series data
 */
contract FaucetStats {
    // Faucet contract address (only faucet can update stats)
    address public faucet;

    // Global statistics
    struct GlobalStats {
        uint256 totalRequests;         // Total number of requests
        uint256 totalDistributed;      // Total tokens distributed
        uint256 uniqueUsers;           // Number of unique users
        uint256 lastUpdateTime;        // Last time stats were updated
    }

    // Per-user statistics
    struct UserStats {
        uint256 requestCount;          // Number of requests made
        uint256 totalReceived;         // Total tokens received
        uint256 firstRequestTime;      // Timestamp of first request
        uint256 lastRequestTime;       // Timestamp of last request
        uint256 largestRequest;        // Largest single request amount
        uint256 averageRequest;        // Average request amount
    }

    // Storage
    GlobalStats public globalStats;
    mapping(address => UserStats) public userStats;

    // Track unique users
    mapping(address => bool) private hasRequested;

    // Events
    event StatsRecorded(
        address indexed user,
        uint256 amount,
        uint256 requestCount,
        uint256 totalDistributed
    );
    event GlobalStatsUpdated(
        uint256 totalRequests,
        uint256 totalDistributed,
        uint256 uniqueUsers
    );
    event StatsReset(address indexed admin, uint256 timestamp);
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
        globalStats.lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Record a faucet request and update statistics
     * @param user Address of the user making the request
     * @param amount Amount of tokens distributed
     * @param isFirstTime Whether this is the user's first request
     * @dev Can only be called by the faucet contract
     */
    function recordRequest(
        address user,
        uint256 amount,
        bool isFirstTime
    ) external onlyFaucet {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be positive");

        // Update global stats
        globalStats.totalRequests++;
        globalStats.totalDistributed += amount;
        globalStats.lastUpdateTime = block.timestamp;

        // Track unique users
        if (isFirstTime || !hasRequested[user]) {
            globalStats.uniqueUsers++;
            hasRequested[user] = true;
        }

        // Update user stats
        UserStats storage stats = userStats[user];

        if (stats.requestCount == 0) {
            // First request
            stats.firstRequestTime = block.timestamp;
        }

        stats.requestCount++;
        stats.totalReceived += amount;
        stats.lastRequestTime = block.timestamp;

        // Update largest request
        if (amount > stats.largestRequest) {
            stats.largestRequest = amount;
        }

        // Update average (running average calculation)
        stats.averageRequest = stats.totalReceived / stats.requestCount;

        emit StatsRecorded(user, amount, stats.requestCount, globalStats.totalDistributed);
        emit GlobalStatsUpdated(
            globalStats.totalRequests,
            globalStats.totalDistributed,
            globalStats.uniqueUsers
        );
    }

    /**
     * @notice Get global statistics
     * @return stats Global statistics struct
     */
    function getGlobalStats() external view returns (GlobalStats memory stats) {
        return globalStats;
    }

    /**
     * @notice Get user statistics
     * @param user Address of the user
     * @return stats User statistics struct
     */
    function getUserStats(address user) external view returns (UserStats memory stats) {
        return userStats[user];
    }

    /**
     * @notice Get average request amount across all users
     * @return average Average amount per request
     */
    function getAverageRequestAmount() external view returns (uint256 average) {
        if (globalStats.totalRequests == 0) {
            return 0;
        }
        return globalStats.totalDistributed / globalStats.totalRequests;
    }

    /**
     * @notice Check if a user has ever made a request
     * @param user Address of the user
     * @return requested True if user has made at least one request
     */
    function hasUserRequested(address user) external view returns (bool requested) {
        return hasRequested[user];
    }

    /**
     * @notice Get total number of requests
     * @return total Total requests
     */
    function getTotalRequests() external view returns (uint256 total) {
        return globalStats.totalRequests;
    }

    /**
     * @notice Get total tokens distributed
     * @return total Total distributed
     */
    function getTotalDistributed() external view returns (uint256 total) {
        return globalStats.totalDistributed;
    }

    /**
     * @notice Get number of unique users
     * @return count Unique user count
     */
    function getUniqueUsers() external view returns (uint256 count) {
        return globalStats.uniqueUsers;
    }

    /**
     * @notice Get user's request count
     * @param user Address of the user
     * @return count Number of requests
     */
    function getUserRequestCount(address user) external view returns (uint256 count) {
        return userStats[user].requestCount;
    }

    /**
     * @notice Get user's total received amount
     * @param user Address of the user
     * @return total Total tokens received
     */
    function getUserTotalReceived(address user) external view returns (uint256 total) {
        return userStats[user].totalReceived;
    }

    /**
     * @notice Get user's activity timeframe
     * @param user Address of the user
     * @return firstRequest Timestamp of first request
     * @return lastRequest Timestamp of last request
     */
    function getUserTimeframe(
        address user
    ) external view returns (uint256 firstRequest, uint256 lastRequest) {
        UserStats storage stats = userStats[user];
        return (stats.firstRequestTime, stats.lastRequestTime);
    }

    /**
     * @notice Get user's largest single request
     * @param user Address of the user
     * @return amount Largest request amount
     */
    function getUserLargestRequest(address user) external view returns (uint256 amount) {
        return userStats[user].largestRequest;
    }

    /**
     * @notice Get user's average request amount
     * @param user Address of the user
     * @return average Average request amount
     */
    function getUserAverageRequest(address user) external view returns (uint256 average) {
        return userStats[user].averageRequest;
    }

    /**
     * @notice Reset all statistics (admin function)
     * @dev Can only be called by the faucet contract (which should have admin controls)
     */
    function resetStats() external onlyFaucet {
        delete globalStats;
        globalStats.lastUpdateTime = block.timestamp;

        emit StatsReset(msg.sender, block.timestamp);
    }

    /**
     * @notice Update faucet contract address (emergency only)
     * @param newFaucet New faucet contract address
     */
    function updateFaucet(address newFaucet) external {
        require(msg.sender == faucet, "Only current faucet");
        require(newFaucet != address(0), "Invalid address");

        address oldFaucet = faucet;
        faucet = newFaucet;

        emit FaucetUpdated(oldFaucet, newFaucet);
    }

    /**
     * @notice Get comprehensive user report
     * @param user Address of the user
     * @return requestCount Total requests
     * @return totalReceived Total received
     * @return averageAmount Average per request
     * @return largestAmount Largest single request
     * @return daysSinceFirst Days since first request
     */
    function getUserReport(
        address user
    )
        external
        view
        returns (
            uint256 requestCount,
            uint256 totalReceived,
            uint256 averageAmount,
            uint256 largestAmount,
            uint256 daysSinceFirst
        )
    {
        UserStats storage stats = userStats[user];

        requestCount = stats.requestCount;
        totalReceived = stats.totalReceived;
        averageAmount = stats.averageRequest;
        largestAmount = stats.largestRequest;

        if (stats.firstRequestTime > 0) {
            daysSinceFirst = (block.timestamp - stats.firstRequestTime) / 1 days;
        }

        return (requestCount, totalReceived, averageAmount, largestAmount, daysSinceFirst);
    }
}
