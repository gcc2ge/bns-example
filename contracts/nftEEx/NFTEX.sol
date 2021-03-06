pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract NFTEX is ERC721Holder, Ownable {
    using SafeMath for uint256;

    struct Order {
        uint8 orderType; //0:Fixed Price, 1:Dutch Auction, 2:English Auction
        address seller;
        IERC721 token;
        uint256 tokenId;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startBlock;
        uint256 endBlock;
        uint256 lastBidPrice;
        address lastBidder;
        bool isSold;
    }

    mapping(IERC721 => mapping(uint256 => bytes32[])) public orderIdByToken;
    mapping(address => bytes32[]) public orderIdBySeller;
    mapping(bytes32 => Order) public orderInfo;

    address public feeAddress;
    uint16 public feePercent;
    IERC20 public cashToken;

    event MakeOrder(
        IERC721 indexed token,
        uint256 id,
        bytes32 indexed hash,
        address seller
    );
    event CancelOrder(
        IERC721 indexed token,
        uint256 id,
        bytes32 indexed hash,
        address seller
    );
    event Bid(
        IERC721 indexed token,
        uint256 id,
        bytes32 indexed hash,
        address bidder,
        uint256 bidPrice
    );
    event Claim(
        IERC721 indexed token,
        uint256 id,
        bytes32 indexed hash,
        address seller,
        address taker,
        uint256 price
    );

    constructor(uint16 _feePercent, IERC20 _cashToken) public {
        require(_feePercent <= 10000, "input value is more than 100%");
        feeAddress = msg.sender;
        feePercent = _feePercent;
        cashToken = _cashToken;
    }

    // view fx
    function getCurrentPrice(bytes32 _order) public view returns (uint256) {
        Order storage o = orderInfo[_order];
        uint8 orderType = o.orderType;
        if (orderType == 0) {
            return o.startPrice;
        } else if (orderType == 2) {
            uint256 lastBidPrice = o.lastBidPrice;
            return lastBidPrice == 0 ? o.startPrice : lastBidPrice;
        } else {
            uint256 _startPrice = o.startPrice;
            uint256 _startBlock = o.startBlock;
            uint256 _endPrice = o.endPrice;
            uint256 tickPerBlock =
                (_startPrice - o.endPrice) / (o.endBlock - _startBlock);
            uint256 tickPrice = (block.number - _startBlock) * tickPerBlock;
            if (tickPrice >= _startPrice - _endPrice) {
                return _endPrice;
            } else {
                return _startPrice - tickPrice;
            }
        }
    }

    function tokenOrderLength(IERC721 _token, uint256 _id)
        external
        view
        returns (uint256)
    {
        return orderIdByToken[_token][_id].length;
    }

    function sellerOrderLength(address _seller)
        external
        view
        returns (uint256)
    {
        return orderIdBySeller[_seller].length;
    }

    // make order fx
    //0:Fixed Price, 1:Dutch Auction, 2:English Auction
    function dutchAuction(
        IERC721 _token,
        uint256 _id,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _endBlock
    ) public {
        require(
            _startPrice > _endPrice,
            "End price should be lower than start price"
        );
        _makeOrder(1, _token, _id, _startPrice, _endPrice, _endBlock);
    } //sp != ep

    function englishAuction(
        IERC721 _token,
        uint256 _id,
        uint256 _startPrice,
        uint256 _endBlock
    ) public {
        _makeOrder(2, _token, _id, _startPrice, 0, _endBlock);
    } //ep=0. for gas saving.

    function fixedPrice(
        IERC721 _token,
        uint256 _id,
        uint256 _price,
        uint256 _endBlock
    ) public {
        _makeOrder(0, _token, _id, _price, 0, _endBlock);
    } //ep=0. for gas saving.

    function _makeOrder(
        uint8 _orderType,
        IERC721 _token,
        uint256 _id,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _endBlock
    ) internal {
        require(_endBlock > block.number, "Duration must be more than zero");

        //push
        bytes32 hash = _hash(_token, _id, msg.sender);
        orderInfo[hash] = Order(
            _orderType,
            msg.sender,
            _token,
            _id,
            _startPrice,
            _endPrice,
            block.number,
            _endBlock,
            0,
            address(0),
            false
        );
        orderIdByToken[_token][_id].push(hash);
        orderIdBySeller[msg.sender].push(hash);

        //check if seller has a right to transfer the NFT token. safeTransferFrom.
        _token.safeTransferFrom(msg.sender, address(this), _id);

        emit MakeOrder(_token, _id, hash, msg.sender);
    }

    function _hash(
        IERC721 _token,
        uint256 _id,
        address _seller
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.number, _token, _id, _seller));
    }

    // take order fx
    //you have to pay only ETH for bidding and buying.

    //In this contract, since send function is used instead of transfer or low-level call function,
    //if a participant is a contract, it must have receive payable function.
    //But if it has some code in either receive or fallback fx, they might not be able to receive their ETH.
    //Even though some contracts can't receive their ETH, the transaction won't be failed.

    //Bids must be at least 5% higher than the previous bid.
    //If someone bids in the last 5 minutes of an auction, the auction will automatically extend by 5 minutes.
    function bid(bytes32 _order, uint256 amount) external {
        Order storage o = orderInfo[_order];
        uint256 endBlock = o.endBlock;
        uint256 lastBidPrice = o.lastBidPrice;
        address lastBidder = o.lastBidder;

        require(o.orderType == 2, "only for English Auction");
        require(endBlock != 0, "Canceled order");
        require(block.number <= endBlock, "It's over");
        require(o.seller != msg.sender, "Can not bid to your order");

        require(
            cashToken.transferFrom(msg.sender, address(this), amount),
            "no enough token"
        );

        if (lastBidPrice != 0) {
            require(
                amount >= lastBidPrice + (lastBidPrice / 20),
                "low price bid"
            ); //5%
        } else {
            require(amount >= o.startPrice && amount > 0, "low price bid");
        }

        if (block.number > endBlock - 20) {
            //20blocks = 5 mins in Etherium.
            o.endBlock = endBlock + 20;
        }

        o.lastBidder = msg.sender;
        o.lastBidPrice = amount;

        // pay back lastbider money
        if (lastBidPrice != 0) {
            require(
                cashToken.transfer(lastBidder, lastBidPrice),
                "pay back tokens"
            );
        }

        emit Bid(o.token, o.tokenId, _order, msg.sender, amount);
    }

    function buyItNow(bytes32 _order) external {
        Order storage o = orderInfo[_order];
        uint256 endBlock = o.endBlock;
        require(endBlock != 0, "Canceled order");
        require(endBlock > block.number, "It's over");
        require(o.orderType < 2, "It's a English Auction");
        require(o.isSold == false, "Already sold");

        uint256 currentPrice = getCurrentPrice(_order);
        uint256 amount = cashToken.balanceOf(msg.sender);
        require(amount >= currentPrice, "price error");

        o.isSold = true; //reentrancy proof

        uint256 fee = currentPrice.mul(feePercent).div(10000);
        require(
            cashToken.transferFrom(msg.sender, o.seller, currentPrice.sub(fee)),
            "no enough token pay NFT"
        );
        require(
            cashToken.transferFrom(msg.sender, feeAddress, fee),
            "no enouht token pay fee"
        );

        o.token.safeTransferFrom(address(this), msg.sender, o.tokenId);

        emit Claim(
            o.token,
            o.tokenId,
            _order,
            o.seller,
            msg.sender,
            currentPrice
        );
    }

    //both seller and taker can call this fx in English Auction. Probably the taker(last bidder) might call this fx.
    //In both DA and FP, buyItNow fx include claim fx.
    function claim(bytes32 _order) external {
        Order storage o = orderInfo[_order];
        address seller = o.seller;
        address lastBidder = o.lastBidder;
        require(o.isSold == false, "Already sold");

        require(
            seller == msg.sender || lastBidder == msg.sender,
            "Access denied"
        );
        require(o.orderType == 2, "This function is for English Auction");
        require(block.number > o.endBlock, "Not yet");

        IERC721 token = o.token;
        uint256 tokenId = o.tokenId;
        uint256 lastBidPrice = o.lastBidPrice;

        uint256 fee = lastBidPrice.mul(feePercent).div(10000);

        o.isSold = true;

        require(cashToken.transfer(seller, lastBidPrice.sub(fee)));
        require(cashToken.transfer(feeAddress, fee));

        token.safeTransferFrom(address(this), lastBidder, tokenId);

        emit Claim(token, tokenId, _order, seller, lastBidder, lastBidPrice);
    }

    function cancelOrder(bytes32 _order) external {
        Order storage o = orderInfo[_order];
        require(o.seller == msg.sender, "Access denied");
        require(o.lastBidPrice == 0, "Bidding exist"); //for EA. but even in DA, FP, seller can withdraw his/her token with this fx.
        require(o.isSold == false, "Already sold");

        IERC721 token = o.token;
        uint256 tokenId = o.tokenId;

        o.endBlock = 0; //0 endBlock means the order was canceled.

        token.safeTransferFrom(address(this), msg.sender, tokenId);
        emit CancelOrder(token, tokenId, _order, msg.sender);
    }

    //feeAddress must be either an EOA or a contract must have payable receive fx and doesn't have some codes in that fx.
    //If not, it might be that it won't be receive any fee.
    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }

    function updateFeePercent(uint16 _percent) external onlyOwner {
        require(_percent <= 10000, "input value is more than 100%");
        feePercent = _percent;
    }

    function setCashToken(IERC20 _cashToken) external onlyOwner {
        cashToken = _cashToken;
    }
}
