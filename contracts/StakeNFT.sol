// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";

/**
 * @title quantlytica's StakeNFT Contract
 * @author quantlytica
 */
contract StakeNFT is ERC721EnumerableUpgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;

    struct StakeUserInfo {
        bool isWithdraw;
        uint256 mintCount;
    }

    mapping(address => StakeUserInfo) public stakeUserInfo;

    mapping(address => EnumerableMapUpgradeable.AddressToUintMap) stakeUserTokenInfo;

    struct StakeTokenInfo {
        address token;
        uint256 price;
    }

    mapping(address => StakeTokenInfo) public stakeTokenInfo;

    struct StakeSettingInfo {
        uint256 startStakeTime;
        uint256 endStakeTime;
        uint256 startWithdrawTime;   
        uint256 initNFTCount;
        uint256 minNFTCount;
        uint256 declineNFTCount;
        uint256 periodTime;   
    }

    StakeSettingInfo public stakeSettingInfo;
    uint256 public mintIDIndex;
    string private _baseTokenURI;

    event Stake(address user,address tokenAddr,uint256 tradeAmount,uint256 mintCount);
    event Unstake(address user,address tokenAddr,uint256 tradeAmount);
    event Mint(address user,uint256 mintCount,uint256 idStart);
    event SetStakeSettingInfo(StakeSettingInfo settings);
    event SetStakeTokenInfo(StakeTokenInfo[] tokens);
    event SetBaseTokenURI(string uri);
    event SetMintIDIndex(uint256 idIndex);

    constructor() initializer {}

    function initialize(address owner_,string memory name_, string memory symbol_) external initializer {
        _transferOwnership(owner_);
        __ERC721_init(name_,symbol_);
    }

    function setMintIDIndex(uint256 mintIDIndex_) external virtual onlyOwner {
        require(mintIDIndex_ > mintIDIndex,"id");
        mintIDIndex = mintIDIndex_;
        emit SetMintIDIndex(mintIDIndex_);
    }

    function setBaseTokenURI(string memory baseTokenURI) external virtual onlyOwner {
        _baseTokenURI = baseTokenURI;
        emit SetBaseTokenURI(baseTokenURI);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setStakeSettingInfo(StakeSettingInfo calldata stakeSettingInfo_) external virtual onlyOwner {
        require(stakeSettingInfo_.endStakeTime > stakeSettingInfo_.startStakeTime, "end");
        require(stakeSettingInfo_.startWithdrawTime >= stakeSettingInfo_.endStakeTime, "withdraw");
        require(stakeSettingInfo_.periodTime > 0, "periodTime");
        stakeSettingInfo = stakeSettingInfo_;
        emit SetStakeSettingInfo(stakeSettingInfo_);
    } 

    function setStakeTokenInfo(StakeTokenInfo[] calldata stakeTokenInfo_) external virtual onlyOwner {
        require(stakeTokenInfo_.length > 0, "size");
        for(uint i = 0; i < stakeTokenInfo_.length; i++) {
            require(stakeTokenInfo_[i].token != address(0), "token");
            stakeTokenInfo[ stakeTokenInfo_[i].token ] = stakeTokenInfo_[i];
        }
        emit SetStakeTokenInfo(stakeTokenInfo_);
    }    

    function getUserInfo(address user_) external view returns(StakeUserInfo memory _userInfo,address[] memory _tokens,uint256[] memory _amounts,uint256 _idCount,uint256[] memory _idList) {
        _userInfo = stakeUserInfo[user_];
        EnumerableMapUpgradeable.AddressToUintMap storage userTokenInfo = stakeUserTokenInfo[user_];
        uint256 tokenCount = userTokenInfo.length();
        if(tokenCount > 0){
            _tokens = new address[](tokenCount);
            _amounts = new uint256[](tokenCount);
            for(uint256 i=0;i<tokenCount;i++){
                (_tokens[i],_amounts[i]) = userTokenInfo.at(i);
            }  
        }
        _idCount = balanceOf(user_);
        if(_idCount > 0){
            _idList = new uint256[](_idCount);
            for(uint256 i=0;i<_idCount;i++){
                _idList[i] = tokenOfOwnerByIndex(user_,i);
            }
        }
    } 

    function stake(address token_,uint256 amount_) public payable nonReentrant returns (uint256 _mintCount,uint256 _mintAmount){
        require(block.timestamp >= stakeSettingInfo.startStakeTime,"start");
        require(block.timestamp < stakeSettingInfo.endStakeTime,"end");
        (_mintCount,_mintAmount) = calcMintInfo(token_,amount_);
        require(_mintCount > 0,"count");
        require(_mintAmount > 0 && _mintAmount <= amount_,"amount");
        address user_ = msg.sender;
        if(token_ == address(1)){
            require(msg.value == amount_,"value");
            if(msg.value > _mintAmount){
                payable(user_).transfer(msg.value.sub(_mintAmount));
            }
        }else{
            IERC20Upgradeable(token_).safeTransferFrom(user_, address(this), _mintAmount);
        }
        StakeUserInfo storage userInfo = stakeUserInfo[user_];
        userInfo.isWithdraw = false;
        userInfo.mintCount = userInfo.mintCount.add(_mintCount);
        EnumerableMapUpgradeable.AddressToUintMap storage userTokenInfo = stakeUserTokenInfo[user_];
        uint256 oldAmount = 0;
        if(userTokenInfo.contains(token_) == true){
            oldAmount = userTokenInfo.get(token_);
        }
        userTokenInfo.set(token_,oldAmount.add(_mintAmount));
        emit Stake(user_,token_,_mintAmount,_mintCount);
    }

    function unstake() public payable nonReentrant{
        require(block.timestamp >= stakeSettingInfo.startWithdrawTime,"start");
        address user_ = msg.sender;
        StakeUserInfo storage userInfo = stakeUserInfo[user_];
        require(userInfo.isWithdraw == false,"withdraw");
        userInfo.isWithdraw = true;
        EnumerableMapUpgradeable.AddressToUintMap storage userTokenInfo = stakeUserTokenInfo[user_];
        uint256 tokenCount = userTokenInfo.length();
        for(uint256 i=0;i<tokenCount;i++){
            (address token_,uint256 amount_) = userTokenInfo.at(i);
            require(amount_ > 0,"amount");
            if(token_ == address(1)){
                payable(user_).transfer(amount_);
            }else{
                IERC20Upgradeable(token_).safeTransfer(user_,amount_);
            }
            userTokenInfo.set(token_,0);
            emit Unstake(user_,token_,amount_);
        }
    }

    function calcMintInfo(address token_,uint256 amount_) public view returns(uint256 _mintCount,uint256 _mintAmount) {
        StakeTokenInfo memory tokenInfo = stakeTokenInfo[token_];
        if(tokenInfo.price > 0){
            uint256 _multiplier = calcMintMultiplier();
            _mintCount = amount_.div(tokenInfo.price);
            _mintAmount = _mintCount.mul(tokenInfo.price);
            _mintCount = _mintCount.mul(_multiplier);
        }
    }

    function calcMintMultiplier() public view returns(uint256 _multiplier) {
        if(block.timestamp >= stakeSettingInfo.startStakeTime && block.timestamp < stakeSettingInfo.endStakeTime){
            uint256 period = block.timestamp.sub(stakeSettingInfo.startStakeTime).div(stakeSettingInfo.periodTime);
            uint256 decline = stakeSettingInfo.declineNFTCount.mul(period);
            if(stakeSettingInfo.initNFTCount >= decline){
                _multiplier = stakeSettingInfo.initNFTCount.sub(decline);
            }
            if(_multiplier < stakeSettingInfo.minNFTCount){
                _multiplier = stakeSettingInfo.minNFTCount;
            }
        }
    }

    function mint(uint256 count) public {
        require(count > 0,"count");
        address user = msg.sender;
        StakeUserInfo storage userInfo = stakeUserInfo[user];
        require(userInfo.mintCount >= count,"left");
        userInfo.mintCount = userInfo.mintCount.sub(count);
        if(mintIDIndex == 0){
            mintIDIndex = totalSupply();
        }
        uint256 totalSupply_ = mintIDIndex;
        for(uint i = 0; i < count; i++){
            _mint(user, totalSupply_.add(i+1));
        }
        mintIDIndex = mintIDIndex + count;
        emit Mint(user,count,totalSupply_+1);
    }

    function _beforeTokenTransfer(address from,address to,uint256 tokenId,uint256 batchSize) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool){
        return super.supportsInterface(interfaceId);
    }
}