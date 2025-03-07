//SPDX-License-Identifier: Unlicense
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/SafeMath.sol";

pragma solidity >=0.7.0 <0.9.0;

interface INFT {
    function getWeight(uint256 nftId) external view returns (uint16);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;
}

interface Shady {
    function mint(address _to, uint256 _amount) external;
}

contract NFT_Staking is Ownable {
    using SafeMath for uint256;

    INFT public nft;
    Shady public shady;
    address public devAddress;

    uint256 public constant YIELD_CPS = 10185674340; // tokens created per nft weight per second
    uint256 public constant CLAIM_TOKEN_TAX_PERCENTAGE = 2; // 2%
    uint256 public constant UNSTAKE_COOLDOWN_DURATION = 1 days; // 1 Day cooldown

    struct StakeDetails {
        address owner;
        uint256 tokenId;
        uint256 startTimestamp;
        bool staked;
    }

    struct OwnedStakeInfo {
        uint256 tokenId;
        uint256 weight;
        uint256 accrual;
    }

    mapping(uint256 => StakeDetails) public stakes;

    struct UnstakeCooldown {
        address owner;
        uint256 tokenId;
        uint256 startTimestamp;
        bool present;
    }

    struct OwnedCooldownInfo {
        uint256 tokenId;
        uint256 weight;
        uint256 startTimestamp;
    }

    mapping(uint256 => UnstakeCooldown) public unstakeCooldowns;

    mapping(address => mapping(uint256 => uint256)) private ownedStakes; // (user, index) => stake
    mapping(uint256 => uint256) private ownedStakesIndex; // token id => index in its owner's stake list
    mapping(address => uint256) public ownedStakesBalance; // user => stake count

    mapping(address => mapping(uint256 => uint256)) private ownedCooldowns; // (user, index) => cooldown
    mapping(uint256 => uint256) private ownedCooldownsIndex; // token id => index in its owner's cooldown list
    mapping(address => uint256) public ownedCooldownsBalance; // user => cooldown count

    /**
     * @dev If staking is paused or not.
     */
    bool public isPaused = true;

    constructor(
        INFT _nft,
        Shady _shady,
        address _devAddress
    ) {
        nft = _nft;
        shady = _shady;
        devAddress = _devAddress;
    }

    /* View */
    function getTokensAccruedForMany(uint256[] calldata _tokenIds)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory tokenAmounts = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenAmounts[i] = _getTokensAccruedFor(_tokenIds[i], false);
        }
        return tokenAmounts;
    }

    function _getTokensAccruedFor(uint256 _tokenId, bool checkOwnership)
        internal
        view
        returns (uint256)
    {
        StakeDetails memory stake = stakes[_tokenId];
        require(stake.staked, "This token isn't staked");
        if (checkOwnership) {
            require(stake.owner == _msgSender(), "You don't own this token");
        }
        return
            (block.timestamp - stake.startTimestamp) *
            nft.getWeight(_tokenId) *
            YIELD_CPS;
    }

    /* Mutators */

    function stakeMany(uint256[] calldata _tokenIds) external {
        require(!isPaused, "Staking is not active.");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(
                nft.ownerOf(tokenId) == _msgSender(),
                "You don't own this token"
            );

            nft.transferFrom(_msgSender(), address(this), tokenId);
            _addNftToStaking(tokenId, _msgSender());
        }
    }

    function claimTokensAndMaybeUnstake(
        uint256[] calldata _tokenIds,
        bool unstake
    ) external {
        uint256 totalClaimed = 0;
        uint256 totalTaxed = 0;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 tokens = _getTokensAccruedFor(tokenId, true); // also checks that msg.sender owns this token
            uint256 taxAmount = (tokens * CLAIM_TOKEN_TAX_PERCENTAGE + 99) /
                100; // +99 to round the division up

            totalClaimed += tokens - taxAmount;
            totalTaxed += taxAmount;
            stakes[tokenId].startTimestamp = block.timestamp;

            if (unstake) {
                _moveNftToCooldown(tokenId);
            }
        }

        shady.mint(_msgSender(), totalClaimed);
        shady.mint(devAddress, totalTaxed);
    }

    function withdrawNfts(uint256[] calldata _tokenIds) external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            UnstakeCooldown memory cooldown = unstakeCooldowns[tokenId];

            require(cooldown.present, "Token is not in cooldown");
            require(_msgSender() == cooldown.owner, "You don't own this token");
            require(
                block.timestamp >=
                    cooldown.startTimestamp + UNSTAKE_COOLDOWN_DURATION,
                "Token is still in cooldown"
            );

            nft.transferFrom(address(this), _msgSender(), tokenId);
            _removeNftFromCooldown(tokenId);
        }
    }

    /**
     * @dev Changes pause state.
     */
    function flipPauseStatus() external onlyOwner {
        isPaused = !isPaused;
    }

    function _addNftToStaking(uint256 _tokenId, address _owner) internal {
        stakes[_tokenId] = StakeDetails({
            owner: _owner,
            tokenId: _tokenId,
            startTimestamp: block.timestamp,
            staked: true
        });
        _addStakeToOwnerEnumeration(_owner, _tokenId);
    }

    function _moveNftToCooldown(uint256 _tokenId) internal {
        address owner = stakes[_tokenId].owner;
        unstakeCooldowns[_tokenId] = UnstakeCooldown({
            owner: stakes[_tokenId].owner,
            tokenId: _tokenId,
            startTimestamp: block.timestamp,
            present: true
        });

        delete stakes[_tokenId];
        _removeStakeFromOwnerEnumeration(owner, _tokenId);
        _addCooldownToOwnerEnumeration(owner, _tokenId);
    }

    function _removeNftFromCooldown(uint256 _tokenId) internal {
        address owner = unstakeCooldowns[_tokenId].owner;
        delete unstakeCooldowns[_tokenId];
        _removeCooldownFromOwnerEnumeration(owner, _tokenId);
    }

    /* Enumeration, adopted from OpenZeppelin ERC721Enumerable */

    function stakeOfOwnerByIndex(address _owner, uint256 _index)
        public
        view
        returns (uint256)
    {
        require(
            _index < ownedStakesBalance[_owner],
            "owner index out of bounds"
        );
        return ownedStakes[_owner][_index];
    }

    function batchedStakesOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (OwnedStakeInfo[] memory) {
        if (_offset >= ownedStakesBalance[_owner]) {
            return new OwnedStakeInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedStakesBalance[_owner]) {
            outputSize = ownedStakesBalance[_owner] - _offset;
        }
        OwnedStakeInfo[] memory outputs = new OwnedStakeInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = stakeOfOwnerByIndex(_owner, _offset + i);

            outputs[i] = OwnedStakeInfo({
                tokenId: tokenId,
                weight: nft.getWeight(tokenId),
                accrual: _getTokensAccruedFor(tokenId, false)
            });
        }

        return outputs;
    }

    function _addStakeToOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 length = ownedStakesBalance[_owner];
        ownedStakes[_owner][length] = _tokenId;
        ownedStakesIndex[_tokenId] = length;
        ownedStakesBalance[_owner]++;
    }

    function _removeStakeFromOwnerEnumeration(address _owner, uint256 _tokenId)
        private
    {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ownedStakesBalance[_owner] - 1;
        uint256 tokenIndex = ownedStakesIndex[_tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedStakes[_owner][lastTokenIndex];

            ownedStakes[_owner][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ownedStakesIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete ownedStakesIndex[_tokenId];
        delete ownedStakes[_owner][lastTokenIndex];
        ownedStakesBalance[_owner]--;
    }

    function cooldownOfOwnerByIndex(address _owner, uint256 _index)
        public
        view
        returns (uint256)
    {
        require(
            _index < ownedCooldownsBalance[_owner],
            "owner index out of bounds"
        );
        return ownedCooldowns[_owner][_index];
    }

    function batchedCooldownsOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (OwnedCooldownInfo[] memory) {
        if (_offset >= ownedCooldownsBalance[_owner]) {
            return new OwnedCooldownInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedCooldownsBalance[_owner]) {
            outputSize = ownedCooldownsBalance[_owner] - _offset;
        }
        OwnedCooldownInfo[] memory outputs = new OwnedCooldownInfo[](
            outputSize
        );

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = cooldownOfOwnerByIndex(_owner, _offset + i);

            outputs[i] = OwnedCooldownInfo({
                tokenId: tokenId,
                weight: nft.getWeight(tokenId),
                startTimestamp: unstakeCooldowns[tokenId].startTimestamp
            });
        }

        return outputs;
    }

    function _addCooldownToOwnerEnumeration(address _owner, uint256 _tokenId)
        internal
    {
        uint256 length = ownedCooldownsBalance[_owner];
        ownedCooldowns[_owner][length] = _tokenId;
        ownedCooldownsIndex[_tokenId] = length;
        ownedCooldownsBalance[_owner]++;
    }

    function _removeCooldownFromOwnerEnumeration(
        address _owner,
        uint256 _tokenId
    ) private {
        uint256 lastTokenIndex = ownedCooldownsBalance[_owner] - 1;
        uint256 tokenIndex = ownedCooldownsIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedCooldowns[_owner][lastTokenIndex];
            ownedCooldowns[_owner][tokenIndex] = lastTokenId;
            ownedCooldownsIndex[lastTokenId] = tokenIndex;
        }

        delete ownedCooldownsIndex[_tokenId];
        delete ownedCooldowns[_owner][lastTokenIndex];
        ownedCooldownsBalance[_owner]--;
    }
}
