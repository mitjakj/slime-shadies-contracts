//SPDX-License-Identifier: Unlicense

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/SafeMath.sol";

interface INFT {
    struct WeightInput {
        uint256 nftId;
        uint16 weight;
    }

    function mint(address to, uint256 tokenId) external;

    function setWeight(WeightInput[] calldata weights) external;
}

contract NFT_Booster_Minter is Ownable {
    using SafeMath for uint256;

    uint256 public cost; // amount of $SHADY tokens
    uint256 public maxMintAmount;
    address public devAddress; // SOULD BE SET TO DEPLOYER ADDRESS !!!

    /**
     * @dev How much reserve is stil available.
     */
    uint16 public reserve = 100;

    /**
     * @dev If drop is paused or not.
     */
    bool public isPaused = true;

    /**
     * @dev Shady token address
     */
    IERC20 public shady;

    /**
     * @dev NFT contract
     */
    INFT public nft;

    /**
     * @dev AC token maxId (Total supply is  maxId - nextId + 1).
     */
    uint256 public maxId;

    /**
     * @dev token ids.
     */
    uint256 public nextId;

    /**
     * @dev Limiting per address max mint.
     */
    mapping(address => uint256) public minterBalances;

    /**
     * @dev weight of all booster tokens
     */
    uint16 private weight;

    constructor(
        address _nft,
        address _shady,
        address _devAddress,
        uint256 _nextId,
        uint256 _maxId,
        uint256 _cost,
        uint16 _reserve,
        uint16 _weight,
        uint256 _maxMintAmount
    ) {
        nft = INFT(_nft);
        shady = IERC20(_shady);
        nextId = _nextId;
        maxId = _maxId;
        cost = _cost;
        reserve = _reserve;
        devAddress = _devAddress;
        weight = _weight;
        maxMintAmount = _maxMintAmount;
    }

    /**
     * @dev Changes pause state.
     */
    function flipPauseStatus() external onlyOwner {
        isPaused = !isPaused;
    }

    /**
     * @dev Mint tokens reserved for owner.
     * @param _quantity Amount of reserve tokens to mint.
     * @param _receiver Receiver of the tokens.
     */
    function mintReserve(uint16 _quantity, address _receiver)
        external
        onlyOwner
    {
        require(_quantity <= reserve, "The quantity exceeds the reserve.");
        reserve -= _quantity;
        for (uint256 i = 0; i < _quantity; i++) {
            INFT.WeightInput[] memory weights = new INFT.WeightInput[](1);
            weights[0] = INFT.WeightInput(nextId, weight);
            nft.setWeight(weights);
            nft.mint(_receiver, nextId);
            nextId++;
        }
    }

    // public
    function mint(uint256 _mintAmount) public {
        require(!isPaused, "Drop is not active.");
        require(_mintAmount > 0, "Mint amount cannot be 0.");
        require(
            _mintAmount + minterBalances[msg.sender] <= maxMintAmount,
            "Exceeds max mint amount"
        );
        require(nextId <= maxId - reserve, "Drop is sold out.");
        require(
            shady.transferFrom(msg.sender, devAddress, cost * _mintAmount),
            "Transfer failed"
        );

        for (uint256 i = 0; i < _mintAmount; i++) {
            INFT.WeightInput[] memory weights = new INFT.WeightInput[](1);
            weights[0] = INFT.WeightInput(nextId, weight);
            nft.setWeight(weights);
            nft.mint(msg.sender, nextId);
            nextId++;
        }
        minterBalances[msg.sender] = minterBalances[msg.sender] + _mintAmount;
    }

    // only owner
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    // only owner
    function setDevAddress(address _devAddress) public onlyOwner {
        devAddress = _devAddress;
    }
}
