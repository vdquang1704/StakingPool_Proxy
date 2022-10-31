//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "hardhat/console.sol";

contract StakingPoolV2 is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // hash role admin
    bytes32 public constant ADMIN = keccak256("ADMIN");

    // hash role super admin
    bytes32 public constant SUPER_ADMIN = keccak256("SUPER_ADMIN");

    uint32 private constant ONE_YEAR = 365 days;

    uint256 private _value;

    // The reward distribution address
    address public rewardDistributor;

    // address to receive the money
    address public coldWalletAddress;

    // info each pool
    StakingPoolInfo[] public poolInfo;

    //data staking of user in a pool
    mapping(uint256 => mapping(address => StakingData)) userStakingData;

    // pool info
    struct StakingPoolInfo {
        IERC20Upgradeable acceptedToken;
        uint256 cap;
        uint256 totalStaked;
        uint256 APR;
        uint256 lockDuration;
        uint256 delayDuration;
    }

    // data staking in user
    struct UserStakingData {
        uint256 balance;
        uint256 stakeTime;
        uint256 lastClaimTime;
        uint256 pendingReward;
        uint256 APR;
    }

    // data withdraw of user
    struct UserPendingWithdrawl {
        uint256 amount;
        uint256 applicableAt;
    }

    // data of all user
    struct StakingData {
        uint256 balance;
        uint256 stakingDataRecordCount;
        mapping(uint256 => UserStakingData) stakingDatas;
        mapping(uint256 => mapping(uint256 => UserPendingWithdrawl)) totalWithdrawals;
        mapping(uint256 => uint256) totalWithdrawalsCount;
    }

    event StakingPoolCreate(
        uint256 indexed poolId,
        IERC20Upgradeable acceptedToken,
        uint256 cap,
        uint256 APR,
        uint256 lockDuration,
        uint256 delayDuration      
    );

    event StakingPoolDeposit(address account, uint256 poolId, uint256 amount, uint256 stakedId, uint256 time);
    event StakingPoolWithdraw(address account, uint256 poolId, uint256 amount, uint256 stakedId, uint256 time);
    event StakingPoolClaimReward(address account, uint256 poolId, uint256 totalReward, uint256 stakedId, uint256 time);

    function __StakingPool_init() public initializer {
        __AccessControl_init(); 
        _setRoleAdmin(ADMIN, SUPER_ADMIN);
        _setupRole(SUPER_ADMIN, msg.sender);
        _setupRole(ADMIN, msg.sender);
        // set owner is msg.sender
        __Ownable_init(); 

        // stop contract
        __Pausable_init();

        coldWalletAddress = address(0x306366DE0bF312786C0af82089Fc914eF578fe0c);
    }

    function store(uint256 value) public {
        _value = value;
    }
    
    function retrieve() public view returns(uint256) {
        return _value+1;
    }

    

    function createPool(
        IERC20Upgradeable _acceptedToken,
        uint256 _cap,
        // uint256 _minInvestment,
        // uint256 _maxInvestment,
        uint256 _APR,
        uint256 _lockDuration,
        uint256 _delayDuration
    ) external onlyRole(ADMIN) {
        poolInfo.push(
            StakingPoolInfo({
                acceptedToken: _acceptedToken,
                cap: _cap,
                totalStaked: 0,
                // minInvestment: _minInvestment,
                // maxInvestment: _maxInvestment,
                APR: _APR,
                lockDuration: _lockDuration,
                delayDuration: _delayDuration
            })
        );
        emit StakingPoolCreate(
            poolInfo.length - 1,
            _acceptedToken,
            _cap,
             _APR,
            _lockDuration,
            _delayDuration  
        );
    }

    function deposit(uint256 _poolId, uint256 _amount) external {
        address account = msg.sender;

        StakingPoolInfo storage pool = poolInfo[_poolId];
        StakingData storage user = userStakingData[_poolId][account];

        require(
            coldWalletAddress != address(0),
            "StakingPool: Cold Wallet address is not address 0"
        );

        pool.acceptedToken.transferFrom(account, coldWalletAddress, _amount);
        
        uint256 recordId = user.stakingDataRecordCount++;
        user.stakingDatas[recordId] = UserStakingData({
            balance: _amount,
            stakeTime: block.timestamp,
            lastClaimTime: 0,
            pendingReward: 0,
            APR: pool.APR
        });
        user.balance += _amount;
        pool.totalStaked += _amount;

        emit StakingPoolDeposit(account, _poolId, _amount, recordId, block.timestamp);
    }

    function withdraw(uint256 _poolId, uint256 _amount, uint256 _stakedId) external {
        address account = msg.sender;
        StakingPoolInfo storage pool = poolInfo[_poolId];
        StakingData storage user = userStakingData[_poolId][account];
        UserStakingData storage userStaking = user.stakingDatas[_stakedId];

        uint256 currentTime = block.timestamp;
        require(
            currentTime >= userStaking.stakeTime + pool.lockDuration,
            "StakingPool: still locked"
        );

        require(
            _amount <= userStaking.balance,
            "StakingPool: Insufficient unstake amount"
        );

        require(_amount > 0, "StakingPool: Unstake amount must greater than 0");

        userStaking.pendingReward += _getPendingReward(_poolId, account, _stakedId);

        uint256 countWithdrawal = user.totalWithdrawalsCount[_stakedId]++;
        user.totalWithdrawals[_stakedId][countWithdrawal] = UserPendingWithdrawl({amount: _amount, applicableAt: currentTime});


        pool.totalStaked -= _amount;
        user.balance -= _amount;
        userStaking.balance -= _amount;
        
        emit StakingPoolWithdraw(account, _poolId, _amount, _stakedId, currentTime);
    } 

    function claimRewardPool(uint256 _poolId, uint256 _stakedId) external {
        _claimReward(_poolId, _stakedId);
    }

    function _claimReward(uint256 _poolId, uint256 _stakedId) private {
        address account = msg.sender;
        StakingPoolInfo storage pool = poolInfo[_poolId]; 
        StakingData storage user = userStakingData[_poolId][account];
        UserStakingData storage userStaking = user.stakingDatas[_stakedId];

        uint256 countWithdrawal = user.totalWithdrawalsCount[_stakedId];
        uint256 totalToken = 0;
        uint256 totalReward = 0;
        for(uint256 i = 0; i < countWithdrawal; i++) {
            totalReward += ((user.totalWithdrawals[_stakedId][i].amount * userStaking.APR * (user.totalWithdrawals[_stakedId][i].applicableAt - userStaking.stakeTime)) / ONE_YEAR) / 1e20;
            totalToken += totalReward + user.totalWithdrawals[_stakedId][i].amount;
        }

        // uint256 rewardAmount = user.totalWithdrawals[_stakedId][countWithdrawal];
        // console.log('totalReward: ',totalReward);
        require(
            totalToken > 0,
            "StakingPool: nothing is currently pending or not realese yet"
        );

        userStaking.pendingReward -= totalReward;

        pool.acceptedToken.transferFrom(rewardDistributor, account, totalToken  );

        emit StakingPoolClaimReward(account, _poolId, totalToken , _stakedId, block.timestamp);
    }

    function totalStakedOfPool(uint256 _poolId) external view returns(uint256 totalStaked) {
        uint256 totalStaked = poolInfo[_poolId].totalStaked;
        return totalStaked;
    }

    function _getPendingReward(uint256 _poolId, address _account, uint256 _stakedId) public view returns(uint256 pendingReward) {
        StakingData storage user = userStakingData[_poolId][_account];
        UserStakingData storage userStaking = user.stakingDatas[_stakedId];

        console.log('userStaking.balance:',userStaking.balance);
        uint256 timeInSecond = block.timestamp  - userStaking.stakeTime;
        uint256 pendingReward = ((userStaking.balance * userStaking.APR * timeInSecond) / ONE_YEAR) / 1e20;
        return pendingReward;
    }

    function getPendingReward(uint256 _poolId, address _account, uint256 _stakedId) external view returns(uint256) {
        StakingData storage user = userStakingData[_poolId][_account];
        UserStakingData storage userStaking = user.stakingDatas[_stakedId];
        // uint256 pendingReward = userStaking.pendingReward;
        // return pendingReward;
        uint256 pendingReward = _getPendingReward(_poolId, _account, _stakedId) + userStaking.pendingReward;
        return pendingReward;
    }

    function getTotalReward(uint256 _poolId, address _account) external view returns(uint256 totalReward) {
        StakingPoolInfo storage pool = poolInfo[_poolId];
        StakingData storage user = userStakingData[_poolId][_account];

        uint256 len = user.stakingDataRecordCount;
        console.log('len: ',len);
        uint256 totalReward = 0;
        for(uint256 i = 0; i < len; i++) {
            totalReward += _getPendingReward(_poolId, _account, i) + user.stakingDatas[i].pendingReward;
        }
        
        return totalReward;
    }

    function getInfoStaking(uint256 _poolId, address _account, uint256 _stakedId) external view returns(UserStakingData memory) {
        StakingData storage user = userStakingData[_poolId][_account];
        UserStakingData storage userStaking = user.stakingDatas[_stakedId];
        return userStaking;
    }



    function setRewardDistributor(address _account) external {
        rewardDistributor = _account;    
    }

    function setColdWalletAddress(address _account) external {
        coldWalletAddress = _account;
    }

    function getBalanceOfStakingPool(address _account, uint256 _poolId, uint256 _stakedId) external view returns (uint256) {
        StakingData storage user = userStakingData[_poolId][_account];
        UserStakingData storage userStaking = user.stakingDatas[_stakedId];
        return userStaking.balance;
    }

    function version() public pure returns (uint256) {
        return 2;
    }
}