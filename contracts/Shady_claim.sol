//SPDX-License-Identifier: Unlicense

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/SafeMath.sol";

interface INFT {
    function ownerOf(uint256 nftId) external view returns (address);
}

interface INFT_Staking {
    function stakes(uint256 nftId)
        external
        view
        returns (
            address,
            uint256,
            uint256,
            bool
        );
}

contract Shady_claim is Ownable {
    using SafeMath for uint256;

    uint256 public amount; // amount of $SHADY tokens

    /**
     * @dev If drop is paused or not.
     */
    bool public isPaused = true;

    /**
     * @dev Shady token address
     */
    IERC20 public shady;

    /**
     * @dev Nft address
     */
    INFT public nft;

    /**
     * @dev Nft staking address
     */
    INFT_Staking public nftStaking;

    /**
     * @dev mapping of claimed boosters
     */
    mapping(uint256 => bool) public claimedNfts;

    constructor(
        address _shady,
        address _nft,
        address _nftStaking
    ) {
        shady = IERC20(_shady);
        nft = INFT(_nft);
        nftStaking = INFT_Staking(_nftStaking);
    }

    function claim(uint256[] calldata nfts) public {
        require(!isPaused, "Claim is not active.");

        uint256 claimAmount = 0;

        for (uint256 i = 0; i < nfts.length; i++) {
            require(nfts[i] <= 5000, "Can only claim for first 5000 ids");
            require(!claimedNfts[nfts[i]], "NFT already claimed");
            address stakedOwner;
            (stakedOwner, , , ) = nftStaking.stakes(nfts[i]);
            require(
                stakedOwner == msg.sender || nft.ownerOf(nfts[i]) == msg.sender,
                "Not NFT owner."
            );
            claimedNfts[nfts[i]] = true;
            claimAmount = claimAmount + 150 ether;
        }
        shady.transfer(msg.sender, claimAmount);
    }

    /**
     * @dev Changes pause state.
     */
    function flipPauseStatus() external onlyOwner {
        isPaused = !isPaused;
    }

    // Backup function
    function withdrawTokens(uint256 _amount) external onlyOwner {
        shady.transfer(msg.sender, _amount);
    }
}
