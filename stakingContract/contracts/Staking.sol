// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {

    address internal token; // only one token for the pools & reward
    bool internal locked;   // re-entrancy attack
    address internal immutable admin;   // admin to initiate the pools (Fixed + Flexible)

    struct FixedPool {
        string name;    // name of the pool
        uint tokenStaked;   // total tokens stake in this pool (fixed)
        uint stakeTime;     // total staking time
        uint reward;        // fixed reward on claim in tokens
    }

    struct FlexiblePool {
        string name;    // name 
        uint tokenStaked;   // total tokens stake in this pool (fixed)
        uint rewardPercent;     // reward in tokens on stake 
        uint stakeTime;     // min stake time
        uint levelUpReward; // if stake time > stakeTime then level is updated at max of 1 to 3
    }

    struct UserFlex {
        uint stakeTime;
        uint unstakeTime;
        bool claimed;
        uint level;
    }

    // creating pools as ids ["Gold", 8, 120, 3]
    mapping(uint => FixedPool) public FixedPools;
    mapping(uint => FlexiblePool) public FlexiblePools;

    // staking the tokens
    // owner -> pool -> userinfo
    mapping(address => mapping(uint => uint[])) internal fixedStake;
    mapping(address => mapping(uint => UserFlex[])) internal flexibleStake;

    constructor(address _token) {
        admin = msg.sender;
        token = _token;
    }

    modifier noReentrant() {    // attack stop
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyAdmin() {      // for initialization of pools
        require(msg.sender == admin, "Not the Admin!");
        _;
    }

    function initializeFixedPools(FixedPool[] memory _fixed) external onlyAdmin { // initialize by the admin
        for(uint index = 0; index < 3; index++) {
            FixedPool memory fixPool = _fixed[index];
            FixedPools[index] = fixPool;
        }
    }

    function initalizeFlexiblePools(FlexiblePool[] memory _flex) external onlyAdmin { // initialize by the admin
        for(uint index = 0; index < 3; index++) {
            FlexiblePool memory flexPool = _flex[index];
            FlexiblePools[index] = flexPool;
        }
    }

    function fixStake(uint _poolId) external noReentrant {
        assert(_poolId >= 0 && _poolId < 3);
        IERC20(token).transferFrom(msg.sender, address(this), FixedPools[_poolId].tokenStaked);
        uint unstake = block.timestamp + FixedPools[_poolId].stakeTime;
        fixedStake[msg.sender][_poolId].push(unstake);        
    }

    function getFixLen(address owner, uint _poolId) public view returns (uint len) {
        return fixedStake[owner][_poolId].length;
    }

    function removeFixedStake(uint _poolId, uint _index) internal {
        require(_index < fixedStake[msg.sender][_poolId].length, "Index out of bound!");

        for (uint i = _index; i < fixedStake[msg.sender][_poolId].length - 1; i++) {
            fixedStake[msg.sender][_poolId][i] = fixedStake[msg.sender][_poolId][i + 1];
        }
        fixedStake[msg.sender][_poolId].pop();
    }

    function claimFixStake(uint _poolId) external noReentrant {
        uint totalStakes = getFixLen(msg.sender, _poolId);
        require(totalStakes > 0, "Not staked in this pool!");

        uint index = 0;
        uint256 unstake = fixedStake[msg.sender][_poolId][index];
        require(block.timestamp > unstake && unstake > 0, "Staking time not completed!");
        uint amount = FixedPools[_poolId].reward + FixedPools[_poolId].tokenStaked;
        IERC20(token).transfer(msg.sender, amount);
        removeFixedStake(_poolId, index);
        
    }

    function flexStake(uint _poolId) external noReentrant {
        assert(_poolId >= 0 && _poolId < 3);
        IERC20(token).transferFrom(msg.sender, address(this), FlexiblePools[_poolId].tokenStaked);
        uint unstake = block.timestamp + FlexiblePools[_poolId].stakeTime;
        UserFlex memory user = UserFlex(block.timestamp, unstake, false, 1);
        flexibleStake[msg.sender][_poolId].push(user);
    }

    function getFlexLen(address owner, uint _poolId) public view returns (uint) {
        return flexibleStake[owner][_poolId].length;
    }

    function removeFlexibleStake(uint _poolId, uint _index) internal  {
        require(_index < flexibleStake[msg.sender][_poolId].length, "Index out of bound!");

        for (uint i = _index; i < flexibleStake[msg.sender][_poolId].length - 1; i++) {
            flexibleStake[msg.sender][_poolId][i] = flexibleStake[msg.sender][_poolId][i + 1];
        }
        flexibleStake[msg.sender][_poolId].pop();
    }

    function claimFlexReward(uint _poolId) external noReentrant {
        uint totalStakes = getFlexLen(msg.sender, _poolId);
        require(totalStakes > 0, "Not staked in this pool!");

        uint index = 0;
        uint256 unstake = flexibleStake[msg.sender][_poolId][index].unstakeTime;
        flexibleStake[msg.sender][_poolId][index].level = updateLevel(unstake);
        require(block.timestamp > unstake && unstake > 0, "Staking time not completed!");
        uint amount = (FlexiblePools[_poolId].rewardPercent + FlexiblePools[_poolId].tokenStaked);
        amount += FlexiblePools[_poolId].levelUpReward * flexibleStake[msg.sender][_poolId][index].level;
        IERC20(token).transfer(msg.sender, amount);
        removeFlexibleStake(_poolId, index);
    }

    function updateLevel(uint unstakeTime) internal view returns (uint) {
        if(block.timestamp >= (unstakeTime * 2) && block.timestamp < (unstakeTime * 3)) {
            return 2;
        }
        else {
            return 3;
        }
    }

    function balance() public view returns (uint) {
        return IERC20(token).balanceOf(address(this));
    }    

}
