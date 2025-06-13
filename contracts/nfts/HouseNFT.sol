// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract HouseNFT is ERC721Enumerable, Ownable {
    
    uint256 private nextTokenId;
    string  private baseUri;
    address public verifier;
    address public heroNft;

    struct HouseParams {
        uint256 flagShape;
        uint256 houseSymbol;
        uint256 flagColor;
        string  houseName;
        uint256 lordNftId;
    }

    mapping(uint256 => bool) private soulbound;
    mapping(uint256 => HouseParams) public houseParams;
    mapping(address => uint256) public nonce;
    mapping(address => bool) public exists;

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed time);
    event SetHouse(address indexed player, uint256 indexed houseId, uint256 indexed lordNftId, uint256 time);
    event SetVerifier(address indexed verifier, uint256 indexed time);
    event SetHeroNft(address indexed heroNftAddress, uint256 indexed time);

    constructor(address initialOwner, address _heroNft, address _verifier) ERC721("Phaser House", "BLHS") Ownable(initialOwner) {
        require(_verifier != address(0), "verifier can't be zero address");
        require(_heroNft != address(0), "hero nft address not zero");

        nextTokenId = 1;
        verifier = _verifier;
        heroNft = _heroNft;
    }

    function safeMint(address _to, bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) external returns(uint256) {
        require(!exists[_to], "you already own the house nft");

        uint256 tokenId = nextTokenId++;

        (uint256 flagShape, uint256 houseSymbol, uint256 flagColor, string memory houseName) 
            = abi.decode(_data, (uint256, uint256, uint256, string));

        require(flagShape > 0 && flagColor > 0 && houseSymbol > 0 &&  bytes(houseName).length > 0, "house params err");
      
        verifySignature(_to, _data, _v, _r, _s);
        
        _safeMint(_to, tokenId);

        exists[_to]                = true;
        
        HouseParams storage house = houseParams[tokenId];
        house.flagShape           = flagShape;
        house.houseSymbol         = houseSymbol;
        house.flagColor           = flagColor;
        house.houseName           = houseName;
        house.lordNftId           = 0;

        soulbound[tokenId]        = true;
        nonce[_to]++;

        emit Minted(_to, tokenId, block.timestamp);
        return tokenId;
    }

    function setHouse (address _from, bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) external {
        (uint256 flagShape, uint256 houseSymbol, uint256 flagColor, string memory houseName, uint256 lordNftId, uint256 houseId) 
            = abi.decode(_data, (uint256, uint256, uint256, string, uint256, uint256));

        require(IERC721(address(this)).ownerOf(houseId) == _from, "not house nft owner");
        // require(IERC721(heroNft).ownerOf(lordNftId) == _from, "not hero nft owner");
        require(flagShape > 0 && flagColor > 0 && houseSymbol > 0 &&  bytes(houseName).length > 0, "house params err");

        verifySignature(_from, _data, _v, _r, _s);
        
        HouseParams storage house = houseParams[houseId];
        house.flagShape           = flagShape;
        house.houseSymbol         = houseSymbol;
        house.flagColor           = flagColor;
        house.houseName           = houseName;
        house.lordNftId           = lordNftId;
        
        nonce[_from]++;
        emit SetHouse(_from, houseId, lordNftId, block.timestamp);

    }

    // Verifying vrs
    function verifySignature(address _addr, bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
        bytes32 message         = keccak256(abi.encodePacked(nonce[_addr], _addr, _data, address(this)));
        bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "verification failed");
    }

    // Method called by the contract owner
    function setBaseURI(string calldata _baseUri) external onlyOwner() {
        baseUri = _baseUri;
    }

    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "verifier can't be zero address ");
        verifier = _verifier;

        emit SetVerifier(_verifier, block.timestamp);
    }

    function setHeroNft (address _nft) external onlyOwner {
        require(_nft != address(0), "verifier can't be zero address ");
        heroNft = _nft;
        
        emit SetHeroNft(_nft, block.timestamp);
    }

    // The following functions are overrides required by Solidity.
    function _increaseBalance(address account, uint128 amount) internal virtual override(ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }

    function supportsInterface(bytes4 interfaceId)public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721Enumerable) returns (address) {
        require(!soulbound[tokenId], "token is soulbound");
        return super._update(to, tokenId, auth);
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

}


