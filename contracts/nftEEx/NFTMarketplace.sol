pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



contract NFTMarketplace is Ownable {

    event Sent(address indexed payee, uint256 amount, uint256 balance);
    event Received(address indexed payer, uint256 tokenId, uint256 amount, uint256 balance);

    IERC721 public nftAddress;
    IERC20 public manaAddress;
    uint256 public ethPrice;
    uint256 public tokenPrice;
    mapping(uint256 => address) public tokenSeller;

    /**
    * @dev Contract Constructor
    * @param _nftAddress address for non-fungible token contract 
    * @param _ethPrice initial price
    */
    constructor(address _nftAddress,address _manaAddress, uint256 _ethPrice,uint256 _tokenPrice) public { 
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(_ethPrice > 0);
        require(_tokenPrice > 0);
        nftAddress = IERC721(_nftAddress);
        manaAddress = IERC20(_manaAddress);
        ethPrice = _ethPrice;
        tokenPrice = _tokenPrice;
    }
    
    /**
    * @dev Deposit _tokenId
    * @param _tokenId uint256 token ID 
    */
    function depositToken(uint256 _tokenId) public {
        require(msg.sender != address(0) && msg.sender != address(this));
        require(msg.sender == nftAddress.ownerOf(_tokenId),"You are Owner of NFT");
        nftAddress.transferFrom(msg.sender, address(this), _tokenId);
        tokenSeller[_tokenId] = msg.sender;
    }
    
    /**
    * @dev Purchase _tokenId
    * @param _tokenId uint256 token ID 
    */
    function purchaseTokenETH(uint256 _tokenId) public payable {
        require(msg.sender != address(0) && msg.sender != address(this),"wrong addresses interaction");
        require(msg.value >= ethPrice,"not enough ETH funds");
        address temp = tokenSeller[_tokenId];
        address payable Seller = address(uint160(temp));
        Seller.transfer(msg.value);
        nftAddress.transferFrom(address(this), msg.sender, _tokenId);
        
        emit Received(msg.sender, _tokenId, msg.value, address(this).balance);
    }
    
    /**
    * @dev Purchase _tokenId
    * @param _tokenId uint256 token ID 
    * @param _amount uint256 amount of ERC20 token
    */
    function purchaseToken(uint256 _tokenId,uint256 _amount) public returns (bool) {
        require(msg.sender != address(0) && msg.sender != address(this),"wrong addresses interaction");
        require(_amount >= tokenPrice,"not enough Mana funds");
        nftAddress.approve(msg.sender,_tokenId);
        address temp = tokenSeller[_tokenId];
        require(manaAddress.transferFrom(msg.sender, temp, _amount),"Not Enough tokens Transfered");
        nftAddress.transferFrom(address(this), msg.sender, _tokenId);
        emit Received(msg.sender, _tokenId, _amount, address(this).balance);
        return true;
    }

    /**
    * @dev send / withdraw _amount to _payee
    */
    function sendTo(address payable _payee, uint256 _amount) public onlyOwner {
        require(_payee != address(0) && _payee != address(this));
        require(_amount > 0 && _amount <= address(this).balance);
        _payee.transfer(_amount);
        emit Sent(_payee, _amount, address(this).balance);
    }    

    /**
    * @dev set _ethPrice
    */
    function setEthPrice(uint256 _ethPrice) public onlyOwner {
        require(_ethPrice >= 0);
        ethPrice = _ethPrice;
    } 
    
    function getEthPrice() public view returns (uint256) {
        return ethPrice;
    }

    /**
    * @dev set _tokenPrice
    */
    function setTokenPrice(uint256 _tokenPrice) public onlyOwner {
        require(_tokenPrice >= 0);
        ethPrice = _tokenPrice;
    } 
    
    function getTokenPrice() public view returns (uint256) {
        return tokenPrice;
    }

}