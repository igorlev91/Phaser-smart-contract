// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// pragma experimental ABIEncoderV2;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
 *  @notice The Phaser Nft Marketplace is a trading platform on seascape network allowing to buy and sell Nfts
 */

contract Marketplace is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;

    uint256 public  salesAmount;    // keep count of SalesObject amount
    bool    public  salesEnabled;   // enable/disable trading
    uint256 public  feeRate;        // fee rate. feeAmount = (feeRate / 1000) * price
    address payable feeReceiver;    // fee reciever

    /// @notice individual sale related data
    struct SalesObject {
        uint256 id;               // sales ID
        uint256 tokenId;          // token unique id
        address nft;              // nft address
        address currency;         // currency address
        address payable seller;   // seller address
        address payable buyer;    // buyer address
        uint256 startTime;        // timestamp when the sale starts
        uint256 price;            // nft price
        uint8 status;             // 2 = sale canceled, 1 = sold, 0 = for sale
    }

    
    // nft token address => (nft id => salesObject)
    mapping(address => mapping(uint256 => SalesObject)) salesObjects;  // marketplace sales objects.

    mapping(address => bool) public supportedNft;                      // supported ERC721 contracts
    mapping(address => bool) public supportedCurrency;                 // supported ERC20 contracts


    event Buy(uint256 indexed saleId, uint256 tokenId, address buyer, uint256 price, uint256 tipsFee, address currency);
    event Sell( uint256 indexed saleId, uint256 tokenId, address nft, address currency, address seller, address buyer, uint256 startTime, uint256 price);
    event CancelSell(uint256 indexed saleId, uint256 tokenId);
    event NftReceived(address operator, address from, uint256 tokenId, bytes data);

    /// @dev set fee reciever address and fee rate
    /// @param _feeReceiver fee receiving address
    /// @param _feeRate fee amount
    constructor(address initialOwner, address payable _feeReceiver, uint256 _feeRate) Ownable(initialOwner) {
        feeReceiver = _feeReceiver;
        feeRate = _feeRate;
        // initReentrancyStatus();
    }

    //--------------------------------------------------
    // External methods
    //--------------------------------------------------

    /// @notice enable/disable sales
    /// @param _salesEnabled set sales to true/false
    function enableSales(bool _salesEnabled) external onlyOwner {
        salesEnabled = _salesEnabled; 
    }

    /// @notice add supported nft token
    /// @param _nftAddress ERC721 contract address
    function addSupportedNft(address _nftAddress) external onlyOwner {
        require(_nftAddress != address(0x0), "invalid address");
        supportedNft[_nftAddress] = true;
    }

    /// @notice disable supported nft token
    /// @param _nftAddress ERC721 contract address
    function removeSupportedNft(address _nftAddress) external onlyOwner {
        require(_nftAddress != address(0x0), "invalid address");
        supportedNft[_nftAddress] = false;
    }

    /// @notice add supported currency token
    /// @param _currencyAddress ERC20 contract address
    function addSupportedCurrency(address _currencyAddress) external onlyOwner {
        require(!supportedCurrency[_currencyAddress], "currency already supported");
        supportedCurrency[_currencyAddress] = true;
    }

    /// @notice disable supported currency token
    /// @param _currencyAddress ERC20 contract address
    function removeSupportedCurrency(address _currencyAddress) external onlyOwner {
        require(supportedCurrency[_currencyAddress], "currency already removed");
        supportedCurrency[_currencyAddress] = false;
    }

    /// @notice change fee receiver address
    /// @param _walletAddress address of the new fee receiver
    function setFeeReceiver(address payable _walletAddress) external onlyOwner {
        require(_walletAddress != address(0x0), "invalid address");
        feeReceiver = _walletAddress;
    }

    /// @notice change fee rate
    /// @param _rate amount value. Actual rate in percent = _rate / 10
    function setFeeRate(uint256 _rate) external onlyOwner {
        require(_rate <= 100, "Rate should be bellow 100 (10%)");
        feeRate = _rate;
    }

    /// @notice returns sales amount
    /// @return total amount of sales objects
    function getSalesAmount() external view returns(uint) {
        return salesAmount; 
    }

    //--------------------------------------------------
    // Public methods
    //--------------------------------------------------

    /// @notice cancel nft sale
    /// @param _tokenId nft unique ID
    /// @param _nftAddress nft token address
    function cancelSell(uint _tokenId, address _nftAddress) public {
        SalesObject storage obj = salesObjects[_nftAddress][_tokenId];
        require(obj.status == 0, "status: sold or canceled");
        require(obj.seller == msg.sender, "seller not nft owner");

        obj.status = 2;
        IERC721 nft = IERC721(obj.nft);
        nft.safeTransferFrom(address(this), obj.seller, obj.tokenId);

        emit CancelSell(obj.id, obj.tokenId);
    }

    /// @notice put nft for sale
    /// @param _tokenId nft unique ID
    /// @param _price required price to pay by buyer. Seller receives less: price - fees
    /// @param _nftAddress nft token address
    /// @param _currency currency token address
    /// @return salesAmount total amount of sales
    function sell(uint256 _tokenId, uint256 _price, address _nftAddress, address _currency) public returns(uint) {
        require(_nftAddress != address(0x0), "invalid nft address");
        require(_tokenId != 0, "invalid nft token");
        require(salesEnabled, "sales are closed");
        require(supportedNft[_nftAddress], "nft address unsupported");
        require(supportedCurrency[_currency], "currency not supported");
        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

        salesAmount++;

        salesObjects[_nftAddress][_tokenId] = SalesObject(
            salesAmount,
            _tokenId,
            _nftAddress,
            _currency,
            payable(msg.sender),
            payable(address(0x0)),
            block.timestamp,
            _price,
            0
        );

        emit Sell(salesAmount, _tokenId, _nftAddress, _currency, msg.sender, address(0x0), block.timestamp, _price);

        return salesAmount;
    }

    /// @dev encrypt token data
    /// @return encrypted data
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)public override returns (bytes4) {
        //only receive the _nft staff
        if (address(this) != operator) {
            //invalid from nft
            return 0;
        }

        //success
        emit NftReceived(operator, from, tokenId, data);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    /// @notice buy nft
    /// @param _tokenId nft unique ID
    /// @param _nftAddress nft token address
    /// @param _currency currency token address
    function buy(uint _tokenId, address _nftAddress, address _currency, uint _price) public payable {
        SalesObject storage obj = salesObjects[_nftAddress][_tokenId];
        require(obj.status == 0, "status: sold or canceled");
        require(obj.startTime <= block.timestamp, "not yet for sale");
        require(salesEnabled, "sales are closed");
        require(msg.sender != obj.seller, "cant buy from yourself");

        require(obj.currency == _currency, "must pay same currency as sold");
        uint256 price = this.getSalesPrice(_tokenId, _nftAddress);
        require(price == _price, "invalid price");
        uint256 tipsFee = price * feeRate / 1000;
        uint256 purchase = price - tipsFee;

        if (obj.currency == address(0x0)) {
            require (msg.value >= price, "your price is too low");
            uint256 returnBack = msg.value - price;
            if (returnBack > 0)
                payable(msg.sender).transfer(returnBack);
            if (tipsFee > 0)
                feeReceiver.transfer(tipsFee);
            obj.seller.transfer(purchase);
        } else {
            IERC20(obj.currency).safeTransferFrom(msg.sender, feeReceiver, tipsFee);
            IERC20(obj.currency).safeTransferFrom(msg.sender, obj.seller, purchase);
        }

        IERC721 nft = IERC721(obj.nft);
        nft.safeTransferFrom(address(this), msg.sender, obj.tokenId);
        obj.buyer = payable(msg.sender);

        obj.status = 1;
        emit Buy(obj.id, obj.tokenId, msg.sender, price, tipsFee, obj.currency);
    }

    /// @dev fetch sale object at nftId and nftAddress
    /// @param _tokenId unique nft ID
    /// @param _nftAddress nft token address
    /// @return SalesObject at given index
    function getSales(uint _tokenId, address _nftAddress) public view returns(SalesObject memory) {
        return salesObjects[_nftAddress][_tokenId];
    }

    /// @dev returns the price of sale
    /// @param _tokenId nft unique ID
    /// @param _nftAddress nft token address
    /// @return obj.price price of corresponding sale
    function getSalesPrice(uint _tokenId, address _nftAddress) public view returns (uint256) {
        SalesObject storage obj = salesObjects[_nftAddress][_tokenId];
        return obj.price;
    }

}
