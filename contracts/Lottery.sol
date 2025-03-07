// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/SafeMath.sol";

pragma solidity >=0.7.0 <0.9.0;

interface INFT_Minter {
    function minter_balanceOf(address owner) external view returns (uint256);
}

contract Lottery is Ownable {
    using SafeMath for uint256;

    address public devAddress;
    address public addressDEAD = 0x000000000000000000000000000000000000dEaD;
    IERC20 public shady;
    INFT_Minter public nft_minter;

    uint256 public roundId = 0;
    uint256 public roundStatus = 0; // 0 = pending or drawing, 1 = active
    uint256 public roundNoOfPicks = 5; // number of picks
    uint16 public minNumber = 1; // min random number
    uint16 public maxNumber = 9; // max random number

    uint256 public ticketId = 0; // current ticket id, each address can have multiple tickets
    uint256 public ticketPrice = 5 ether; // in shady tokens

    struct Ticket {
        address ticketOwner;
        uint8[] numbers;
    }

    mapping(uint256 => uint256[]) public roundTicketList;
    mapping(uint256 => uint256) public roundDrawTimestamp;
    mapping(uint256 => uint256) public roundReward;
    mapping(uint256 => mapping(uint256 => Ticket)) public roundTicketDetails; // roundId => ticketId => Ticket
    mapping(uint256 => mapping(address => uint256[])) public roundAddressTickets; // roundId => address => ticketId
    mapping(uint256 => mapping(address => uint256)) public roundAddressFreeTickets;

    mapping(uint256 => uint16[]) public roundResult;

    constructor(
        address _nftMinter,
        address _shady,
        address _devAddress
    ) {
        nft_minter = INFT_Minter(_nftMinter);
        shady = IERC20(_shady);
        devAddress = _devAddress;
    }

    function getRoundTicketListLength(uint256 _roundId) external view returns (uint256) {
        return roundTicketList[_roundId].length;
    }

    function getRoundAddressTicketsLength(uint256 _roundId, address _address) external view returns (uint256) {
        return roundAddressTickets[_roundId][_address].length;
    }

    function getRoundTicketDetailsOwner(uint256 _roundId, uint256 _ticketId) external view returns (address) {
        return roundTicketDetails[_roundId][_ticketId].ticketOwner;
    }

    function getRoundTicketDetailsNumbers(uint256 _roundId, uint256 _ticketId, uint256 _index) external view returns (uint8) {
        return roundTicketDetails[_roundId][_ticketId].numbers[_index];
    }

    function getSubmitExpired() public view returns (bool) {
        return block.timestamp >= roundDrawTimestamp[roundId];
    }

    function startRound(
        uint256 _roundReward,
        uint256 _roundDrawTimestamp
    ) public onlyOwner {
        require(roundStatus == 0, 'Round already started.');
        require(_roundReward > 0, '_roundReward needs to be greater than 0.');
        roundId += 1;
        roundStatus = 1; // active
        roundReward[roundId] = _roundReward;
        roundDrawTimestamp[roundId] = _roundDrawTimestamp;
    }

    function submitTicket(uint8[][] calldata _numbers) public {
        require(roundStatus == 1, 'Round not started yet.');
        require(!getSubmitExpired(), 'Time to submit ticket expired.');
        require(_numbers.length > 0, 'No ticket submitted.');

        uint256 shadyRequired = 0;
        for (uint16 iTicket = 0; iTicket < _numbers.length; iTicket ++) {
            require(_numbers[iTicket].length == roundNoOfPicks, 'Invalid number of picks in ticket.');

            // each minter allowed to submit as many free tickets as mints done
            if (roundAddressFreeTickets[roundId][msg.sender] >= nft_minter.minter_balanceOf(msg.sender)) {
                shadyRequired += ticketPrice;
            } else {
                // Free ticket
                roundAddressFreeTickets[roundId][msg.sender] += 1;
            }

            ticketId += 1; // set ticket number
            roundTicketList[roundId].push(ticketId);
            roundAddressTickets[roundId][msg.sender].push(ticketId);

            roundTicketDetails[roundId][ticketId] = Ticket({
               ticketOwner: msg.sender,
               numbers: _numbers[iTicket]
            });
        }

        if (shadyRequired > 0) {
            require(
                shady.transferFrom(msg.sender, addressDEAD, shadyRequired),
                "Payment failed."
            );
        }
    }

    function drawResult() public onlyOwner {
        require(roundStatus == 1, 'Round not started yet.');
        require(getSubmitExpired(), 'Time to submit ticket did NOT expire yet.');

        for (uint16 numberIdx = 0; numberIdx < roundNoOfPicks; numberIdx ++) {
            uint16 randNumber;
            if (numberIdx == 0) {
                randNumber = semirandomNumber(roundTicketList[roundId].length);
            } else if (numberIdx == 1) {
                randNumber = semirandomNumber(block.timestamp);
            } else if (numberIdx == 2) {
                randNumber = semirandomNumber(block.timestamp - roundTicketList[roundId].length);
            } else if (numberIdx == 3) {
                randNumber = semirandomNumber(block.timestamp + roundTicketList[roundId].length);
            } else {
                randNumber = semirandomNumber(numberIdx);
            }
            roundResult[roundId].push(randNumber);
        }

        roundStatus = 0; // pending
    }

    function semirandomNumber(uint256 randomKey) private view returns (uint16) {
        uint256 _randomNumber;
        uint256 _gasleft = gasleft();
        bytes32 _blockhash = blockhash(block.number - 1);
        bytes32 _structHash = keccak256(
            abi.encode(_blockhash, randomKey, _gasleft)
        );
        _randomNumber = uint256(_structHash);
        uint16 offset = minNumber;
        uint16 scope = maxNumber - minNumber;
        assembly {
            _randomNumber := add(mod(_randomNumber, scope), offset)
        }
        return uint16(_randomNumber);
    }

    // Setters
    function setTicketPrice(uint256 _ticketPrice) public onlyOwner {
        ticketPrice = _ticketPrice;
    }

    function setMinNumber(uint16 _minNumber) public onlyOwner {
        minNumber = _minNumber;
    }

    function setMaxNumber(uint16 _maxNumber) public onlyOwner {
        maxNumber = _maxNumber;
    }

    function setRoundNoOfPicks(uint256 _roundNoOfPicks) public onlyOwner {
        roundNoOfPicks = _roundNoOfPicks;
    }

    function setRoundReward(uint256 _roundReward) public onlyOwner {
        roundReward[roundId] = _roundReward;
    }

    function setRoundDrawTimestamp(uint256 _roundDrawTimestamp) public onlyOwner {
        require(roundStatus == 1, 'Round not in progress.');
        roundDrawTimestamp[roundId] = _roundDrawTimestamp;
    }
}
