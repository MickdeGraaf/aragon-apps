/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

/* solium-disable function-order */

pragma solidity 0.4.24;

import "./TokenManagerBase.sol";

contract TokenManager is TokenManagerBase {
    uint256 public constant MAX_STAKES_PER_ADDRESS = 50;

    bytes32 public constant STAKING_TIER_MANAGER_ROLE = keccak256("STAKING_TIER_MANAGER_ROLE");

    string private constant ERROR_STAKE_TOO_LARGE = "STAKE_TOO_LARGE";
    string private constant ERROR_TOO_MANY_STAKES = "TOO_MANY_STAKES";
    string private constant ERROR_CANNOT_UNSTAKE = "CANNOT_UNSTAKE";
    string private constant ERROR_STAKE_DOES_NOT_EXIST = "STAKE_DOES_NOT_EXIST";

    struct TokenStake {
        uint256 amount;
        uint256 stakedTill;
        TokenManagerBase[] tiers;
    }

    struct StakingTier {
        uint256 minDuration;
        TokenManagerBase tokenManager;
    }

    // We are mimicing an array in the inner mapping, we use a mapping instead to make app upgrade more graceful
    mapping (address => mapping (uint256 => TokenStake)) internal stakes;
    mapping (address => uint256) public stakesLength;
    mapping (address => uint256) public totalStakedOf;

    StakingTier[] public stakingTiers;

    /**
    * @notice Mint `@tokenAmount(self.token(): address, _amount, false)` tokens to `_receiver` from the Token Manager's holdings with a `_revokable : 'revokable' : ''` vesting starting at `@formatDate(_start)`, cliff at `@formatDate(_cliff)` (first portion of tokens transferable), and completed vesting at `@formatDate(_vested)` (all tokens transferable)
    * @param _receiver The address receiving the tokens, cannot be Token Manager itself
    * @param _amount Number of tokens vested
    * @param _start Date the vesting calculations start
    * @param _cliff Date when the initial portion of tokens are transferable
    * @param _vested Date when all tokens are transferable
    * @param _revokable Whether the vesting can be revoked by the Token Manager
    * @author PIE DAO
    */
    function mintVested(
        address _receiver,
        uint256 _amount,
        uint64 _start,
        uint64 _cliff,
        uint64 _vested,
        bool _revokable
    )
        external
        authP(ASSIGN_ROLE, arr(_receiver, _amount))
        returns (uint256)
    {
        require(_receiver != address(this), ERROR_VESTING_TO_TM);
        require(vestingsLengths[_receiver] < MAX_VESTINGS_PER_ADDRESS, ERROR_TOO_MANY_VESTINGS);
        require(_start <= _cliff && _cliff <= _vested, ERROR_WRONG_CLIFF_DATE);

        uint256 vestingId = vestingsLengths[_receiver]++;
        vestings[_receiver][vestingId] = TokenVesting(
            _amount,
            _start,
            _cliff,
            _vested,
            _revokable
        );

        _mint(_receiver, _amount);

        emit NewVesting(_receiver, vestingId, _amount);

        return vestingId;
    }

    /**
    * @notice Stake tokens
    * @param _amount Number of tokens staked
    * @param _duration Lockup period
    * @author PIE DAO
    **/
    function stakeTokens(uint256 _amount, uint256 _duration) external returns(bool) {
        uint256 totalStaked = totalStakedOf[msg.sender].add(_amount);
        require(totalStaked <= token.balanceOf(msg.sender), ERROR_STAKE_TOO_LARGE);
        require(stakesLength[msg.sender] < MAX_STAKES_PER_ADDRESS, ERROR_TOO_MANY_STAKES);
        totalStakedOf[msg.sender] = totalStaked;
        stakesLength[msg.sender] ++;

        uint256 stakeId = stakesLength[msg.sender] ++;

        TokenStake storage stake = stakes[msg.sender][stakeId];

        stake.amount = _amount;
        stake.stakedTill = block.timestamp.add(_duration);

        for(uint256 i = 0; i < stakingTiers.length; i++) {
            if(stakingTiers[i].minDuration >= _duration) {
                stake.tiers.push(stakingTiers[i].tokenManager);
                stakingTiers[i].tokenManager.mint(msg.sender, _amount);
            }
        }

        return true;
    }

    /**
    * @notice Unstake staked tokens
    *
    *
    *
    *
    */
    function unstakeTokens(uint256 _stakeId) external returns(bool) {
        TokenStake storage stake = stakes[msg.sender][_stakeId];
        require(block.timestamp > stake.stakedTill, ERROR_CANNOT_UNSTAKE);
        require(_stakeId < stakesLength[msg.sender], ERROR_STAKE_DOES_NOT_EXIST);
        
        // burn voting shares from staking
        for(uint256 i = 0; i < stake.tiers.length; i ++) {
            // TODO consider handling failure of a burn
            stake.tiers[i].burn(msg.sender, stake.amount);
        }
        
        // decrease total staked amount
        totalStakedOf[msg.sender] -= stake.amount;

        // remove stake
        if(_stakeId != stakesLength[msg.sender] - 1) {
            stakes[msg.sender][_stakeId] = stakes[msg.sender][stakesLength[msg.sender] - 1];
        }

        // decrease stakes length
        stakesLength[msg.sender] -= 1;
    }

    function addStakingTier(uint256 _minDuration, address _tokenManager) external authP(STAKING_TIER_MANAGER_ROLE, arr(_tokenManager, _minDuration)) returns(bool) {
        uint256 stakingTierId = stakingTiers.length ++;
        
        StakingTier storage tier = stakingTiers[stakingTierId];

        tier.tokenManager = TokenManagerBase(_tokenManager);
        tier.minDuration = _minDuration;

        return true;
    }

    function removeStakingTier(uint256 _tierId) external authP(STAKING_TIER_MANAGER_ROLE, arr(_tierId)) returns (bool) {
        // If not removing the last one move the last to the one being removed
        if(_tierId != stakingTiers.length - 1) {
            stakingTiers[_tierId] = stakingTiers[stakingTiers.length - 1];
        }
        // Remove last one
        stakingTiers.length --;

        return true;
    }

    function _stakeableBalance(address _holder, uint256 _time) internal view returns (uint256) {
        uint256 stakeable = token.balanceOf(_holder);
        stakeable = stakeable.sub(totalStakedOf[_holder]);
        return stakeable;
    }


    function _transferableBalance(address _holder, uint256 _time) internal view returns (uint256) {
        return super._transferableBalance(_holder, _time);
    }


}