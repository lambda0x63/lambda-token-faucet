// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./libraries/FaucetMath.sol";

/**
 * @title FaucetAdmin
 * @notice Administrative functions for the Lambda Faucet
 * @dev Handles ownership, pausability, parameters, and access control
 */
contract FaucetAdmin is Ownable2Step, Pausable {
    using FaucetMath for uint256;

    // Faucet contract address
    address public faucet;

    // Operator role (limited admin privileges)
    address public operator;

    // Faucet parameters
    uint256 public baseAmountPerRequest;
    uint256 public baseCooldownTime;

    // Dynamic configuration
    struct DynamicConfig {
        bool enabled;                  // Whether dynamic adjustments are enabled
        uint256 maxSupply;            // Maximum token supply allocated to faucet
        uint256 requestCountWindow;   // Time window for counting requests (e.g., 1 hour)
    }

    DynamicConfig public dynamicConfig;

    // Hourly request tracking
    mapping(uint256 => uint256) public hourlyRequestCount;

    // Blacklist
    mapping(address => bool) public blacklist;

    // Events
    event FaucetUpdated(address indexed oldFaucet, address indexed newFaucet);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event BaseAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event BaseCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);
    event DynamicConfigUpdated(bool enabled, uint256 maxSupply, uint256 window);
    event BlacklistUpdated(address indexed user, bool status);
    event HourlyRequestIncremented(uint256 hourIndex, uint256 count);
    event EmergencyAction(string action, address indexed executor);

    // Modifiers
    modifier onlyFaucet() {
        require(msg.sender == faucet, "Only faucet can call");
        _;
    }

    modifier onlyOperatorOrOwner() {
        require(
            msg.sender == operator || msg.sender == owner(),
            "Only operator or owner"
        );
        _;
    }

    /**
     * @notice Constructor
     * @param initialOwner Address of the initial owner
     * @param _baseAmount Initial base amount per request
     * @param _baseCooldown Initial base cooldown time
     */
    constructor(
        address initialOwner,
        uint256 _baseAmount,
        uint256 _baseCooldown
    ) Ownable(initialOwner) {
        require(_baseAmount > 0, "Invalid base amount");
        require(_baseCooldown > 0, "Invalid cooldown");

        baseAmountPerRequest = _baseAmount;
        baseCooldownTime = _baseCooldown;

        // Default dynamic config
        dynamicConfig = DynamicConfig({
            enabled: true,
            maxSupply: 500_000 * 10**18, // 500k tokens
            requestCountWindow: 1 hours
        });
    }

    /**
     * @notice Set the faucet contract address
     * @param _faucet Address of the faucet contract
     */
    function setFaucet(address _faucet) external onlyOwner {
        require(_faucet != address(0), "Invalid faucet address");
        address oldFaucet = faucet;
        faucet = _faucet;
        emit FaucetUpdated(oldFaucet, _faucet);
    }

    /**
     * @notice Set the operator address
     * @param _operator Address of the new operator
     */
    function setOperator(address _operator) external onlyOwner {
        address oldOperator = operator;
        operator = _operator;
        emit OperatorUpdated(oldOperator, _operator);
    }

    /**
     * @notice Update base amount per request
     * @param newAmount New base amount
     */
    function setBaseAmountPerRequest(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Amount must be positive");
        uint256 oldAmount = baseAmountPerRequest;
        baseAmountPerRequest = newAmount;
        emit BaseAmountUpdated(oldAmount, newAmount);
    }

    /**
     * @notice Update base cooldown time
     * @param newCooldown New base cooldown in seconds
     */
    function setBaseCooldownTime(uint256 newCooldown) external onlyOwner {
        require(newCooldown > 0, "Cooldown must be positive");
        require(newCooldown <= 30 days, "Cooldown too long");
        uint256 oldCooldown = baseCooldownTime;
        baseCooldownTime = newCooldown;
        emit BaseCooldownUpdated(oldCooldown, newCooldown);
    }

    /**
     * @notice Update dynamic configuration
     * @param enabled Whether dynamic adjustments are enabled
     * @param maxSupply Maximum supply for the faucet
     * @param window Time window for request counting
     */
    function setDynamicConfig(
        bool enabled,
        uint256 maxSupply,
        uint256 window
    ) external onlyOwner {
        require(maxSupply > 0, "Invalid max supply");
        require(window > 0, "Invalid window");

        dynamicConfig.enabled = enabled;
        dynamicConfig.maxSupply = maxSupply;
        dynamicConfig.requestCountWindow = window;

        emit DynamicConfigUpdated(enabled, maxSupply, window);
    }

    /**
     * @notice Add address to blacklist
     * @param user Address to blacklist
     */
    function addToBlacklist(address user) external onlyOperatorOrOwner {
        require(user != address(0), "Invalid address");
        require(!blacklist[user], "Already blacklisted");
        blacklist[user] = true;
        emit BlacklistUpdated(user, true);
    }

    /**
     * @notice Remove address from blacklist
     * @param user Address to remove from blacklist
     */
    function removeFromBlacklist(address user) external onlyOperatorOrOwner {
        require(blacklist[user], "Not blacklisted");
        blacklist[user] = false;
        emit BlacklistUpdated(user, false);
    }

    /**
     * @notice Pause the faucet
     */
    function pause() external onlyOwner {
        _pause();
        emit EmergencyAction("pause", msg.sender);
    }

    /**
     * @notice Unpause the faucet
     */
    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyAction("unpause", msg.sender);
    }

    /**
     * @notice Increment hourly request count
     * @dev Called by faucet on each request
     */
    function incrementHourlyCount() external onlyFaucet {
        uint256 currentHour = FaucetMath.getCurrentHourIndex(block.timestamp);
        hourlyRequestCount[currentHour]++;
        emit HourlyRequestIncremented(currentHour, hourlyRequestCount[currentHour]);
    }

    /**
     * @notice Get current hour's request count
     * @return count Number of requests in current hour
     */
    function getCurrentHourRequestCount() external view returns (uint256 count) {
        uint256 currentHour = FaucetMath.getCurrentHourIndex(block.timestamp);
        return hourlyRequestCount[currentHour];
    }

    /**
     * @notice Get request count for a specific hour
     * @param hourIndex Hour index to query
     * @return count Number of requests in that hour
     */
    function getHourlyRequestCount(uint256 hourIndex) external view returns (uint256 count) {
        return hourlyRequestCount[hourIndex];
    }

    /**
     * @notice Calculate dynamic cooldown based on recent activity
     * @return cooldown Adjusted cooldown time
     */
    function getDynamicCooldown() external view returns (uint256 cooldown) {
        if (!dynamicConfig.enabled) {
            return baseCooldownTime;
        }

        uint256 currentHour = FaucetMath.getCurrentHourIndex(block.timestamp);
        uint256 requestCount = hourlyRequestCount[currentHour];

        return FaucetMath.calculateDynamicCooldown(requestCount, baseCooldownTime);
    }

    /**
     * @notice Check if address is blacklisted
     * @param user Address to check
     * @return isBlacklisted True if blacklisted
     */
    function isBlacklisted(address user) external view returns (bool) {
        return blacklist[user];
    }

    /**
     * @notice Check if faucet is paused
     * @return isPaused True if paused
     */
    function isPaused() external view returns (bool) {
        return paused();
    }

    /**
     * @notice Get max supply for dynamic calculations
     * @return maxSupply Maximum supply value
     */
    function getMaxSupply() external view returns (uint256) {
        return dynamicConfig.maxSupply;
    }

    /**
     * @notice Check if dynamic adjustments are enabled
     * @return enabled True if enabled
     */
    function isDynamicEnabled() external view returns (bool) {
        return dynamicConfig.enabled;
    }

    /**
     * @notice Get complete dynamic configuration
     * @return config DynamicConfig struct
     */
    function getDynamicConfig() external view returns (DynamicConfig memory) {
        return dynamicConfig;
    }

    /**
     * @notice Get all base parameters
     * @return baseAmount Base amount per request
     * @return baseCooldown Base cooldown time
     */
    function getBaseParameters() external view returns (uint256 baseAmount, uint256 baseCooldown) {
        return (baseAmountPerRequest, baseCooldownTime);
    }

    /**
     * @notice Get complete admin state
     * @return _owner Owner address
     * @return _operator Operator address
     * @return _faucet Faucet address
     * @return _paused Whether paused
     */
    function getAdminState()
        external
        view
        returns (
            address _owner,
            address _operator,
            address _faucet,
            bool _paused
        )
    {
        return (owner(), operator, faucet, paused());
    }

    /**
     * @notice Batch blacklist multiple addresses
     * @param users Array of addresses to blacklist
     */
    function batchBlacklist(address[] calldata users) external onlyOperatorOrOwner {
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] != address(0) && !blacklist[users[i]]) {
                blacklist[users[i]] = true;
                emit BlacklistUpdated(users[i], true);
            }
        }
    }

    /**
     * @notice Batch remove addresses from blacklist
     * @param users Array of addresses to remove
     */
    function batchRemoveFromBlacklist(address[] calldata users) external onlyOperatorOrOwner {
        for (uint256 i = 0; i < users.length; i++) {
            if (blacklist[users[i]]) {
                blacklist[users[i]] = false;
                emit BlacklistUpdated(users[i], false);
            }
        }
    }

    /**
     * @notice Reset hourly count for a specific hour (admin emergency)
     * @param hourIndex Hour index to reset
     */
    function resetHourlyCount(uint256 hourIndex) external onlyOwner {
        hourlyRequestCount[hourIndex] = 0;
        emit EmergencyAction("resetHourlyCount", msg.sender);
    }
}
