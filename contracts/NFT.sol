//SPDX-License-Identifier: Unlicense

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/SafeMath.sol";
import "./ERC2981.sol";

interface INFT_Minter {
    function claimReward(uint256 tokenId) external;
}

contract NFT is ERC721Enumerable, Ownable, ERC2981 {
    using Strings for uint256;
    using SafeMath for uint256;

    string public baseURI;

    /**
     * Royalties fee percent.
     */
    uint256 public royaltiesFees = 4; // 4%

    /**
     * Royalties address.
     */
    address public royaltiesAddress;

    /**
     * Staking address.
     */
    address public stakingAddress;

    /**
     * Address of the minting contract for the main collection.
     */
    INFT_Minter public mainMinter;

    /**
     * @dev Mapping of addresses that are authorized to add mint new tokens.
     */
    mapping(address => bool) public authorizedAddresses;

    /**
     * @dev Staking weight;
     */
    mapping(uint256 => uint16) tokenWeight;

    /**
     * @dev Input stuct
     */
    struct WeightInput {
        uint256 nftId;
        uint16 weight;
    }

    uint16 baseWeight;

    /**
     * @dev Only authorized addresses can call a function with this modifier.
     */
    modifier onlyAuthorized() {
        require(
            authorizedAddresses[msg.sender] || owner() == msg.sender,
            "Not authorized"
        );
        _;
    }

    /**
     * @dev Sets or revokes authorized address.
     * @param addr Address we are setting.
     * @param isAuthorized True is setting, false if we are revoking.
     */
    function setAuthorizedAddress(address addr, bool isAuthorized)
        external
        onlyOwner
    {
        authorizedAddresses[addr] = isAuthorized;
    }

    /**
     * @dev Sets or revokes authorized address.
     * @param _mainMinterAddress Address we are setting.
     */
    function setMainMinterAddress(address _mainMinterAddress)
        external
        onlyOwner
    {
        require(
            address(mainMinter) == address(0),
            "Main minter address already set"
        );
        mainMinter = INFT_Minter(_mainMinterAddress);
        authorizedAddresses[_mainMinterAddress] = true;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        address _royaltiesAddress,
        uint16 _baseWeight
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        royaltiesAddress = _royaltiesAddress;
        baseWeight = _baseWeight;
        // 15% of mint price goes to previous minters
        // rewardPerMint = cost.mul(15).div(100);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // public
    function mint(address _to, uint256 _id) public onlyAuthorized {
        _safeMint(_to, _id);
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (address(mainMinter) != address(0) && address(from) != address(0)) {
            mainMinter.claimReward(tokenId);
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
                : "";
    }

    /**
     * Pre approve staking contract
     */
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        if (_operator == stakingAddress) {
            return true;
        }

        return super.isApprovedForAll(_owner, _operator);
    }

    function setStakingAddress(address _stakingAddress) external onlyOwner {
        require(stakingAddress == address(0), "Staking address already set");
        stakingAddress = _stakingAddress;
    }

    function getWeight(uint256 nftId) public view returns (uint16) {
        require(
            _exists(nftId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if (tokenWeight[nftId] == 0) {
            return baseWeight;
        }
        return tokenWeight[nftId];
    }

    function setWeight(WeightInput[] calldata weights) public onlyAuthorized {
        for (uint256 i = 0; i < weights.length; i++) {
            tokenWeight[weights[i].nftId] = weights[i].weight;
        }
    }

    /**
     * Set royalties fees.
     */
    function setRoyaltiesFees(uint256 _royaltiesFees) public onlyOwner {
        royaltiesFees = _royaltiesFees;
    }

    /**
     * Set royalties address.
     */
    function setRoyaltiesAddress(address _royaltiesAddress) public onlyOwner {
        royaltiesAddress = _royaltiesAddress;
    }

    /**
     * Get royalties information.
     */
    function royaltyInfo(uint256 tokenId, uint256 value)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = royaltiesAddress;
        royaltyAmount = (value * royaltiesFees) / 100;
    }
}
