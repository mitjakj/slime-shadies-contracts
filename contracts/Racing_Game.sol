// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/SafeMath.sol";

pragma solidity >=0.7.0 <0.9.0;

interface INFT_Minter {
    function minter_balanceOf(address owner) external view returns (uint256);
}

interface INFT {
    function ownerOf(uint256 _tokenId) external view returns (address);
}

interface IStaking {
    function stakes(uint256 _tokenId)
        external
        view
        returns (
            address,
            uint256,
            uint256,
            bool
        );
}

contract Racing_Game is Ownable {
    using SafeMath for uint256;

    address public devAddress;
    address public addressDEAD = 0x000000000000000000000000000000000000dEaD;
    IERC20 public shady;
    INFT_Minter public nft_minter;
    INFT public nft;
    IStaking public nftStaking;

    uint256 public constant CLAIM_TAX_PERCENTAGE = 2; // 2%

    uint256 public pricePerRace = 5 ether; // amount of $SHADY tokens - ticket
    uint8 public minRacers = 5;
    uint8 public maxRacers = 20; // max number of unique addresses to participate in race
    uint8 public mintedUserNFTs = 1; // min number of minted NFTs required to participate in race

    uint256 public epochId = 0; // each epoch has multiple races, never reuse same epoch
    uint256 public raceId = 0; // when epoch increases, never reuse same raceId !!!

    uint256 public epochDuration;
    uint256 public epochStartTimestamp;
    uint256 public epochRacesWithoutCooldown; // number of races, without cooldown
    uint256 public epochCooldownDelay; // cooldown start delay after epochStartTimestamp
    uint256 public raceCooldownDuration; // when cooldown is active, how long is delay between races
    mapping(uint256 => mapping(address => uint256))
        public epochNoOfRacesPerUser; // counter of races per user
    mapping(address => uint256) public userLastRacingTimestamp; // timestamps of last racing of a user

    mapping(uint256 => mapping(address => uint256)) public booster1Usage;
    mapping(uint256 => mapping(address => uint256)) public booster2Usage;

    /*
     * raceStatus
     * 0 = pending
     * 1 = signups
     * 2 = racing
     */
    uint8 public raceStatus = 0; // max number of unique addresses to participate in race

    uint256 public raceSignupDuration = 60; // TODO: 300
    uint256 public raceDuration = 8; // TODO: 60
    uint256 public delayBeforeAndAfterRacing = 10; // TODO: 20

    uint16 public raceSpeedMIN = 100; // min speed in each quarter
    uint16 public raceSpeedMAX = 240; // max speed in each quarter

    uint256 public raceMAXTotalSpeed = 1000; // max total speed (SUM(quarters) speed)

    uint256 public booster1From = 10001;
    uint256 public booster1To = 10500;
    uint8 public booster1Cooldown = 2;

    uint256 public booster2From = 11001;
    uint256 public booster2To = 11200;
    uint8 public booster2Cooldown = 3;

    struct Race {
        uint256 raceId;
        uint256 startSignupTimestamp;
        uint256 startRacingTimestamp;
        uint256 numberOfRacers;
    }

    struct Participant {
        uint16 quarter1Speed;
        uint16 quarter2Speed;
        uint16 quarter3Speed;
        uint16 quarter4Speed;
        uint256 totalSpeed;
        uint8 booster;
        uint8 quarter;
    }

    mapping(uint256 => Race) public raceDetails; // list of race details
    mapping(uint256 => address[]) public raceAddressList; // list of participants addresses per raceId
    mapping(uint256 => mapping(uint256 => bool)) public raceTotalSpeedList; // list of totalSpeeds per race, each total speed allowed only once!
    mapping(uint256 => mapping(address => Participant))
        public raceAddressDetailsList; // list of participants details by raceId

    mapping(uint256 => uint256[]) public epochRaceIds; // list of raceIds per epoch
    mapping(uint256 => mapping(address => uint256)) public epochPoints; // list of participant points per epoch
    mapping(uint256 => address[]) public epochAddressList; // list of participants addresses per epoch
    mapping(uint256 => mapping(address => bool)) public epochAddressListMap; // list of participants addresses per epoch - mapping

    struct EpochResult {
        address first;
        uint256 firstScore;
        address second;
        uint256 secondScore;
        address third;
        uint256 thirdScore;
        uint256 timestamp;
    }
    mapping(uint256 => EpochResult) public epochResultList; // results of epoch

    constructor(
        address _nftMinter,
        address _shady,
        address _devAddress,
        address _nft,
        address _nftStaking
    ) {
        nft_minter = INFT_Minter(_nftMinter);
        shady = IERC20(_shady);
        devAddress = _devAddress;
        nft = INFT(_nft);
        nftStaking = IStaking(_nftStaking);
    }

    function getEpochAddressListLength(uint256 _epochId)
        external
        view
        returns (uint256)
    {
        return epochAddressList[_epochId].length;
    }

    function getEpochRaceIdsLength(uint256 _epochId)
        external
        view
        returns (uint256)
    {
        return epochRaceIds[_epochId].length;
    }

    // Start new epoch
    function startEpoch(
        uint8 _mintedUserNFTs,
        uint256 _epochDuration,
        uint256 _epochRacesWithoutCooldown,
        uint256 _epochCooldownDelay,
        uint256 _raceCooldownDuration
    ) public onlyOwner {
        require(raceStatus == 0, "Race status not 0 (pending)");
        epochId += 1;
        raceId += 1;
        epochRaceIds[epochId].push(raceId);

        mintedUserNFTs = _mintedUserNFTs;
        epochDuration = _epochDuration;
        epochRacesWithoutCooldown = _epochRacesWithoutCooldown;
        epochCooldownDelay = _epochCooldownDelay;
        raceCooldownDuration = _raceCooldownDuration;

        epochStartTimestamp = block.timestamp;
        raceDetails[raceId] = Race({
            raceId: raceId,
            startSignupTimestamp: block.timestamp,
            numberOfRacers: 0,
            startRacingTimestamp: 0
        });

        raceStatus = 1; // set to Signup
    }

    // Collecting racers
    function signUp(uint256 boosterId, uint16 booster2Threshold) public {
        uint8 booster = 0;
        uint8 quarter = 0;
        uint16 slowestQuarterTime;
        uint8 slowestQuarter = 0;
        if (boosterId > 0) {
            if (nft.ownerOf(boosterId) != msg.sender) {
                (address user, , , bool staked) = nftStaking.stakes(boosterId);
                if (user != msg.sender || !staked) {
                    revert("Not booster owner");
                }
            }

            if (boosterId >= booster1From && boosterId < booster1To) {
                booster = 1;
                require(
                    booster1Usage[epochId][msg.sender] + booster1Cooldown <
                        raceId ||
                        booster1Usage[epochId][msg.sender] == 0
                );
                booster1Usage[epochId][msg.sender] = raceId;
            } else if (boosterId >= booster2From && boosterId < booster2To) {
                booster = 2;
                require(
                    booster2Usage[epochId][msg.sender] + booster2Cooldown <
                        raceId ||
                        booster2Usage[epochId][msg.sender] == 0
                );
            } else {
                revert("Invalid boosterId");
            }
        }
        require(raceStatus == 1, "Race status not 1 (signups).");
        require(
            raceDetails[raceId].numberOfRacers < maxRacers,
            "All places already filled."
        );
        require(
            nft_minter.minter_balanceOf(msg.sender) >= mintedUserNFTs,
            "Minted balance lower then required."
        );
        require(
            shady.transferFrom(msg.sender, address(this), pricePerRace),
            "Payment failed."
        );
        require(!isRacingCooldown(msg.sender), "Racer in cooldown.");

        for (uint256 i; i < raceAddressList[raceId].length; i++) {
            if (raceAddressList[raceId][i] == msg.sender) {
                revert("User already signed up to this race.");
            }
        }

        raceAddressList[raceId].push(msg.sender);
        raceDetails[raceId].numberOfRacers += 1;
        epochNoOfRacesPerUser[epochId][msg.sender] += 1;
        userLastRacingTimestamp[msg.sender] = block.timestamp;

        // Also check if address in epoch, if not add it
        if (epochAddressListMap[epochId][msg.sender] != true) {
            epochAddressListMap[epochId][msg.sender] = true;
            epochAddressList[epochId].push(msg.sender);
        }
        uint16[4] memory quartersSpeed;

        quartersSpeed[0] = semirandomNumber(
            raceDetails[raceId].numberOfRacers,
            raceSpeedMIN,
            raceSpeedMAX
        );
        quartersSpeed[1] = semirandomNumber(
            block.timestamp,
            raceSpeedMIN,
            raceSpeedMAX
        );
        if (quartersSpeed[0] > quartersSpeed[1]) {
            slowestQuarterTime = quartersSpeed[1];
            slowestQuarter = 1;
        } else {
            slowestQuarterTime = quartersSpeed[0];
        }
        quartersSpeed[2] = semirandomNumber(
            nft_minter.minter_balanceOf(msg.sender),
            raceSpeedMIN,
            raceSpeedMAX
        );
        if (slowestQuarterTime > quartersSpeed[2]) {
            slowestQuarterTime = quartersSpeed[2];
            slowestQuarter = 2;
        }
        // if first booster is active regenerate the slowest of first 3 quarters with higher min/max
        if (booster == 1) {
            quartersSpeed[slowestQuarter] = semirandomNumber(
                block.timestamp,
                200,
                230
            );
        }
        uint256 totalSpeed;
        uint8 salt = 0;
        do {
            // it's enough if we recalc only one quarter to affect totalSpeed, in case of booster we
            // only calculate once since another logic makes sure of unique speed.
            if (booster != 2 || (booster == 2 && salt == 0)) {
                quartersSpeed[3] = semirandomNumber(
                    salt,
                    raceSpeedMIN,
                    raceSpeedMAX
                );
            }

            // should only be true once, in subsequential repeats should pass trough
            if (slowestQuarterTime > quartersSpeed[3]) {
                slowestQuarterTime = quartersSpeed[3];
                slowestQuarter = 3;
            }

            // If booster 2 is in usage (is false the first time) and total speed is already used
            // then add salt to the slowest quarter until we get a unique total speed.
            if (booster2Usage[epochId][msg.sender] == raceId) {
                quartersSpeed[slowestQuarter] = 230 + salt;
            }

            totalSpeed =
                quartersSpeed[0] +
                quartersSpeed[1] +
                quartersSpeed[2] +
                quartersSpeed[3];

            // If second booster is active and treshold is meet then set fix speed of 230 to the slowest quarter.
            // And set booster as used this race. If total speed is alredy used then condition above will take care of it.
            if (booster == 2 && totalSpeed < booster2Threshold) {
                quartersSpeed[slowestQuarter] = 230;
                totalSpeed =
                    quartersSpeed[0] +
                    quartersSpeed[1] +
                    quartersSpeed[2] +
                    quartersSpeed[3];

                booster2Usage[epochId][msg.sender] = raceId;
            }

            salt++;
        } while (raceTotalSpeedList[raceId][totalSpeed] == true);

        raceTotalSpeedList[raceId][totalSpeed] = true; // set totalSpeed for this race used

        raceAddressDetailsList[raceId][msg.sender] = Participant({
            quarter1Speed: quartersSpeed[0],
            quarter2Speed: quartersSpeed[1],
            quarter3Speed: quartersSpeed[2],
            quarter4Speed: quartersSpeed[3],
            totalSpeed: totalSpeed,
            booster: booster,
            quarter: quarter
        });

        bool startRace = false;
        if (raceDetails[raceId].numberOfRacers >= maxRacers) {
            // If all spots are filled
            startRace = true;
        } else if (
            raceDetails[raceId].numberOfRacers >= minRacers &&
            (raceDetails[raceId].startSignupTimestamp + raceSignupDuration) <
            block.timestamp
        ) {
            // If enough races have signup && signup time is over
            startRace = true;
        }

        if (startRace) {
            // start race
            raceStatus = 2; // racing
            raceDetails[raceId].startRacingTimestamp =
                block.timestamp +
                delayBeforeAndAfterRacing;
        }
    }

    function isRacingCooldown(address _address) public view returns (bool) {
        if (
            epochNoOfRacesPerUser[epochId][_address] < epochRacesWithoutCooldown
        ) {
            // If user didn't complete base number of races
            return false;
        }
        if (epochStartTimestamp + epochCooldownDelay > block.timestamp) {
            // If cooldown didn't start yet
            return true;
        }
        if (
            userLastRacingTimestamp[_address] + raceCooldownDuration >
            block.timestamp
        ) {
            // User in cooldown
            return true;
        }

        // No cooldown
        return false;
    }

    // Force start race
    function startRaceManually() public {
        require(raceStatus == 1, "Race status not 1 (signups).");
        require(
            raceDetails[raceId].numberOfRacers >= minRacers,
            "Minimum filled spots required."
        );

        // start race
        raceStatus = 2; // racing
        raceDetails[raceId].startRacingTimestamp =
            block.timestamp +
            delayBeforeAndAfterRacing;
    }

    function semirandomNumber(
        uint256 randomKey,
        uint16 min,
        uint16 max
    ) private view returns (uint16) {
        uint256 _randomNumber;
        uint256 _gasleft = gasleft();
        bytes32 _blockhash = blockhash(block.number - 1);
        bytes32 _structHash = keccak256(
            abi.encode(_blockhash, randomKey, _gasleft)
        );
        _randomNumber = uint256(_structHash);
        uint16 offset = min;
        uint16 scope = max - min;
        assembly {
            _randomNumber := add(mod(_randomNumber, scope), offset)
        }
        return uint16(_randomNumber);
    }

    // Reward winner and start new race signing
    function rewardWinnerAndStartNew() public {
        require(raceStatus == 2, "Race status not 2 (racing).");
        require(
            raceDetails[raceId].startRacingTimestamp +
                raceDuration +
                delayBeforeAndAfterRacing <=
                block.timestamp,
            "Race not finished yet."
        );

        uint256 epochMaxPoints = 0;
        address epochMaxPointsAddress;
        for (uint256 i = 0; i < raceAddressList[raceId].length; i++) {
            address participant = raceAddressList[raceId][i];
            epochPoints[epochId][participant] += raceAddressDetailsList[raceId][
                participant
            ].totalSpeed;
            if (epochPoints[epochId][participant] > epochMaxPoints) {
                // it's enough that we only check addresses that race, instead of all addresses in epoch
                epochMaxPoints = epochPoints[epochId][participant];
                epochMaxPointsAddress = participant;
            }
        }

        (address first, address second, ) = _getRaceWinner(raceId);

        uint256 shadyBal = shady.balanceOf(address(this));

        // return ticket-price to winner
        shady.transfer(first, pricePerRace);

        // return half ticket-price (pricePerRace) to 2nd place
        shady.transfer(second, pricePerRace / 2);

        // return quarter ticket-price (pricePerRace) to transaction executor
        shady.transfer(msg.sender, pricePerRace / 4);

        // collect fee
        uint256 taxAmount = (shadyBal * CLAIM_TAX_PERCENTAGE + 99) / 100; // +99 to round the division up
        shady.transfer(devAddress, taxAmount);

        // burn remaining tokens
        shady.transfer(addressDEAD, shady.balanceOf(address(this)));

        // Check if epoch over
        if (epochStartTimestamp + epochDuration < block.timestamp) {
            raceStatus = 0; // pending
            // Racing is BLOCKED until we again call startEpoch();
        } else {
            raceStatus = 1;
            raceId += 1;

            epochRaceIds[epochId].push(raceId);
            raceDetails[raceId] = Race({
                raceId: raceId,
                startSignupTimestamp: block.timestamp,
                numberOfRacers: 0,
                startRacingTimestamp: 0
            });
        }
    }

    function _getRaceWinner(uint256 _raceId)
        private
        view
        returns (
            address first,
            address second,
            address third
        )
    {
        uint256 speedFirst;
        uint256 speedSecond;
        uint256 speedThird;
        for (uint256 i; i < raceAddressList[_raceId].length; i++) {
            address user = raceAddressList[_raceId][i];
            uint256 currentSpeed = raceAddressDetailsList[_raceId][user]
                .totalSpeed;
            if (currentSpeed > speedFirst) {
                third = second;
                speedThird = speedSecond;
                second = first;
                speedSecond = speedFirst;
                first = user;
                speedFirst = currentSpeed;
            } else if (currentSpeed > speedSecond) {
                third = second;
                speedThird = speedSecond;
                second = user;
                speedSecond = currentSpeed;
            } else if (currentSpeed > speedThird) {
                third = user;
                speedThird = currentSpeed;
            }
        }
    }

    function getRaceWinner(uint256 _raceId)
        public
        view
        returns (
            address first,
            address second,
            address third
        )
    {
        require(
            _raceId < raceId || (raceId == _raceId && raceStatus == 0),
            "Race not finished."
        );
        (first, second, third) = _getRaceWinner(_raceId);
    }

    function _getEpochWinner(uint256 _epochId)
        private
        view
        returns (
            address first,
            address second,
            address third
        )
    {
        uint256 speedFirst;
        uint256 speedSecond;
        uint256 speedThird;
        for (uint256 i; i < epochAddressList[_epochId].length; i++) {
            address user = epochAddressList[_epochId][i];
            uint256 currentSpeed = epochPoints[_epochId][user];
            if (currentSpeed > speedFirst) {
                third = second;
                speedThird = speedSecond;
                second = first;
                speedSecond = speedFirst;
                first = user;
                speedFirst = currentSpeed;
            } else if (currentSpeed > speedSecond) {
                third = second;
                speedThird = speedSecond;
                second = user;
                speedSecond = currentSpeed;
            } else if (currentSpeed > speedThird) {
                third = user;
                speedThird = currentSpeed;
            }
        }
    }

    function getEpochWinner(uint256 _epochId)
        public
        view
        returns (
            address first,
            address second,
            address third
        )
    {
        require(
            _epochId < epochId || (_epochId == epochId && raceStatus == 0),
            "Epoch not finished."
        );
        (first, second, third) = _getEpochWinner(_epochId);
    }

    // Setters
    function setPricePerRace(uint256 _pricePerRace) public onlyOwner {
        pricePerRace = _pricePerRace;
    }

    function setMinRacers(uint8 _minRacers) public onlyOwner {
        minRacers = _minRacers;
    }

    function setMaxRacers(uint8 _maxRacers) public onlyOwner {
        maxRacers = _maxRacers;
    }

    function setEpochDuration(uint256 _epochDuration) public onlyOwner {
        epochDuration = _epochDuration;
    }

    function setEpochRacesWithoutCooldown(uint256 _epochRacesWithoutCooldown)
        public
        onlyOwner
    {
        epochRacesWithoutCooldown = _epochRacesWithoutCooldown;
    }

    function setEpochCooldownDelay(uint256 _epochCooldownDelay)
        public
        onlyOwner
    {
        epochCooldownDelay = _epochCooldownDelay;
    }

    function setRaceCooldownDuration(uint256 _raceCooldownDuration)
        public
        onlyOwner
    {
        raceCooldownDuration = _raceCooldownDuration;
    }

    function setRaceSignupDuration(uint256 _raceSignupDuration)
        public
        onlyOwner
    {
        raceSignupDuration = _raceSignupDuration;
    }

    function setRaceDuration(uint256 _raceDuration) public onlyOwner {
        raceDuration = _raceDuration;
    }

    function setRaceSpeedMIN(uint8 _raceSpeedMIN) public onlyOwner {
        raceSpeedMIN = _raceSpeedMIN;
    }

    function setRaceSpeedMAX(uint8 _raceSpeedMAX) public onlyOwner {
        raceSpeedMAX = _raceSpeedMAX;
    }

    function setRaceMAXTotalSpeed(uint256 _raceMAXTotalSpeed) public onlyOwner {
        raceMAXTotalSpeed = _raceMAXTotalSpeed;
    }

    function setBooster1(uint256 _from, uint256 _to, uint8 _cooldown) public onlyOwner {
        booster1From = _from;
        booster1To = _to;
        booster1Cooldown = _cooldown;
    }

    function setBooster2(uint256 _from, uint256 _to, uint8 _cooldown) public onlyOwner {
        booster2From = _from;
        booster2To = _to;
        booster2Cooldown = _cooldown;
    }
}
