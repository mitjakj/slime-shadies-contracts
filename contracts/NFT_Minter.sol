//SPDX-License-Identifier: Unlicense

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/SafeMath.sol";
import "hardhat/console.sol";

interface INFT {
    function mint(address to, uint256 tokenId) external;
}

contract NFT_Minter is Ownable {
    using SafeMath for uint256;

    uint256 public cost = 1.25 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmount = 30;
    address public lotteryAddress = 0x88feAd011E238c0182c6cd9e4Ab3191261714d01;
    address public devAddress = 0x12562fA3c4F5161D51E5D2E54E4e05aa75eac6DB;
    mapping(address => uint8) public whitelisted;
    mapping(address => bool) public freelisted;

    uint256 public reflectionBalance;
    uint256 public totalDividend;
    mapping(uint256 => uint256) public lastDividendAt;

    // original minter data
    mapping(uint256 => address) public minter;
    mapping(address => mapping(uint256 => uint256)) public minter_tokens;
    mapping(address => uint256) public minter_balances;

    /**
     * @dev Contract sale state.
     * 0 - closed / paused.
     * 1 - presale - whitelisted, and freelisted
     * 2 - open - sale
     */
    uint8 public saleState = 0;

    /**
     * @dev Amount of premint tokens.
     */
    uint16 public premint = 50;

    /**
     * @dev How much preminted tokens are stil available.
     */
    uint16 public reserve = premint;

    /**
     * @dev Amount of presale tokens.
     */
    uint16 public presale = 1000;

    /**
     * @dev Max mint amount in presale.
     */
    uint8 public maxPresaleMintAmount = 4;

    /**
     * @dev Presale cost.
     */
    uint256 public presaleCost = 0.9 ether;

    /**
     * @dev NFT contract
     */
    INFT public nft;

    /**
     * @dev AC token ids.
     */
    uint256 public nextId = 1;

    /**
     * @dev amount of freemints.
     */
    uint256 public freemints = 0;

    constructor(address _nft) {
        nft = INFT(_nft);
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
            nft.mint(_receiver, nextId);
            nextId++;
        }
    }

    function freeMint() public {
        require(saleState > 0, "Freemint not opened.");
        require(freelisted[msg.sender], "Not freelisted.");
        require(nextId + reserve <= maxSupply, "Sold out");
        freelisted[msg.sender] = false;
        nft.mint(msg.sender, nextId);
        minter[nextId] = msg.sender;
        minter_tokens[msg.sender][minter_balanceOf(msg.sender)] = nextId;
        minter_balances[msg.sender] += 1;
        lastDividendAt[nextId] = totalDividend;
        nextId++;
        freemints++; // otherwise calculation for presale price in mint fails.
    }

    // public
    function mint(uint256 _mintAmount) public payable {
        uint256 supply = nextId - 1;
        if (saleState == 0) {
            // closed
            revert("Sale not opened.");
        }

        require(_mintAmount > 0, "Mint amount cannot be 0.");
        if (saleState == 1) {
            // presale
            require(whitelisted[msg.sender] != 0, "Not whitelisted.");
            require(
                _mintAmount <= whitelisted[msg.sender],
                "Mint amount exceeded max presale mint amount."
            );
            whitelisted[msg.sender] =
                whitelisted[msg.sender] -
                uint8(_mintAmount);
        } else {
            // sale
            require(
                minter_balanceOf(msg.sender) + _mintAmount <= maxMintAmount,
                "Mint amount exceeded max mint amount."
            );
        }

        require(supply + _mintAmount + reserve <= maxSupply, "Sold out");

        uint256 totalCost = 0;
        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 price = 0;
            if (nextId > presale + premint + freemints) {
                price = cost;
            } else {
                price = presaleCost;
            }
            totalCost = totalCost + price;
            nft.mint(msg.sender, nextId);
            minter[nextId] = msg.sender;
            minter_tokens[msg.sender][minter_balanceOf(msg.sender)] = nextId;
            minter_balances[msg.sender] += 1;
            lastDividendAt[nextId] = totalDividend;
            nextId++;
            splitBalance(price);
        }

        require(msg.value >= totalCost, "Not enough funds.");
    }

    function tokenMinter(uint256 tokenId) public view returns (address) {
        return minter[tokenId];
    }

    function currentRate() public view returns (uint256) {
        if (nextId - 1 == 0) return 0;
        return reflectionBalance / (nextId - 1 - premint);
    }

    // only owner
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setSaleState(uint8 _state) public onlyOwner {
        saleState = _state;
    }

    function whitelistUsers(address[] calldata _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whitelisted[_users[i]] = maxPresaleMintAmount;
        }
    }

    function removeWhitelistUsers(address[] calldata _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whitelisted[_users[i]] = 0;
        }
    }

    function freelistUsers(address[] calldata _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            freelisted[_users[i]] = true;
        }
    }

    function removeFreelistUsers(address[] calldata _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            freelisted[_users[i]] = false;
        }
    }

    function setLotteryAddress(address _lotteryAddress) public onlyOwner {
        lotteryAddress = _lotteryAddress;
    }

    function setDevAddress(address _devAddress) public onlyOwner {
        devAddress = _devAddress;
    }

    function minter_balanceOf(address owner)
        public
        view
        virtual
        returns (uint256)
    {
        require(
            owner != address(0),
            "ERC721: balance query for the zero address"
        );
        return minter_balances[owner];
    }

    function minter_tokenByIndex(address owner, uint256 index)
        public
        view
        virtual
        returns (uint256)
    {
        require(
            index < minter_balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        return minter_tokens[owner][index];
    }

    function claimRewards() public {
        uint256 count = minter_balanceOf(msg.sender);
        uint256 balance = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = minter_tokenByIndex(msg.sender, i);
            if (tokenId > premint) {
                balance += getReflectionBalance(tokenId);
                lastDividendAt[tokenId] = totalDividend;
            }
        }
        payable(msg.sender).transfer(balance);
    }

    function getReflectionBalances() public view returns (uint256) {
        uint256 count = minter_balanceOf(msg.sender);
        uint256 total = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = minter_tokenByIndex(msg.sender, i);
            total += getReflectionBalance(tokenId);
        }
        return total;
    }

    function claimReward(uint256 tokenId) public {
        if (tokenId > premint && tokenId <= maxSupply) {
            uint256 balance = getReflectionBalance(tokenId);
            payable(tokenMinter(tokenId)).transfer(balance);
            lastDividendAt[tokenId] = totalDividend;
        }
    }

    function getReflectionBalance(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return totalDividend - lastDividendAt[tokenId];
    }

    function splitBalance(uint256 amount) private {
        uint256 reflectionShare = (amount * 15) / 100; // 15%
        uint256 lotteryShare = (amount * 5) / 100; // 5%;
        uint256 devShare = amount - reflectionShare - lotteryShare; // should be 80%;
        reflectDividend(reflectionShare);

        payable(lotteryAddress).transfer(lotteryShare);
        payable(devAddress).transfer(devShare);
    }

    function reflectDividend(uint256 amount) private {
        reflectionBalance = reflectionBalance + amount;
        totalDividend = totalDividend + (amount / (nextId - 1 - premint));
    }

    function reflectToOwners() public payable {
        reflectDividend(msg.value);
    }
}
