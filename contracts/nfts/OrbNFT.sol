// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title Phaser
 * @dev This contract provides functionality for minting, burning, and managing Phaser Orb NFTs.
 * @notice ERC721 token contract representing the Phaser Orbs token.
 */
 
contract OrbNFT is ERC721, ERC721Burnable, ERC721Enumerable, Ownable {

    bool    private lock;              // Reentrancy guard
    uint256 private nextTokenId;       // Next available token ID
    string  private baseUri;           // Base URI for token metadata
    address public  verifier;          // Address of the verifier for signature verification
    address private factory;           // Address of the NFT factory contract

    
    mapping(uint256 => uint256) public quality;        // Mapping from token ID to quality (tokenId => quality), quality represented by numbers (1 to 6)
    mapping(uint256 => uint256) public qualityLimit;   // Mapping from quality to quality limits (maximum supply per quality)
    mapping(address => uint256) public nonce;          // Mapping from address to nonce for signature verification

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed time);
    event SetFactory(address indexed factory, uint256 indexed time);
    event SetVerifier(address indexed verifier, uint256 indexed time);

    /**
     * @dev Contract constructor
     * @param initialOwner Address of the initial owner
     * @param _verifier Address of the verifier for signature verification
     */
    constructor(address initialOwner, address _verifier) ERC721("Phaser Orbs", "ORB") Ownable(initialOwner) {
        require(_verifier != address(0), "Verifier can't be zero address");

        nextTokenId = 1;
        verifier    = _verifier;
        factory     = initialOwner;

        // set quality limits
        qualityLimit[1] = 10000;
        qualityLimit[2] = 3000;
        qualityLimit[3] = 1000;
        qualityLimit[4] = 500;
        qualityLimit[5] = 200;
        qualityLimit[6] = 100;
    }
    
    /**
     * @dev Modifier to prevent reentrancy attacks.
     */
    modifier nonReentrant() {
        require(!lock, "No reentrant call");
        lock = true;
        _;
        lock = false;
    }
    
    /**
     * @dev Modifier to restrict access to only the factory contract.
     */
    modifier onlyFactory() {
        require(factory == _msgSender(), "Only NFT Factory can call the method");
        _;
    }
     
    /**
     * @dev Safely mints a new Orb NFT.
     * @param _to Address to mint the token to.
     * @param _quality Quality of the orb to mint.
     * @param _deadline Expiry timestamp for the signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     * @return The ID of the minted token.
     */
    function safeMint(address _to, uint256 _quality, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant returns (uint256) {
        require(_quality >= 1 && _quality <= 6, "Invalid quality");
        require(_deadline >= block.timestamp, "Signature has expired");
        require(qualityLimit[_quality] > 0, "Quality has reached its limit");

        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_to, _quality, address(this), nonce[_to], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about mint hero nft");
        }

        uint256 _tokenId = nextTokenId++;

        // decrease quality limit
        qualityLimit[_quality]--;
        quality[_tokenId] = _quality;
        nonce[_to]++;

        _safeMint(_to, _tokenId);
        
        emit Minted(_to, _tokenId, block.timestamp);
        return _tokenId;
    }

    
    /**
     * @dev Mints a new Orb NFT.
     * @param _to Address to mint the token to.
     * @param _quality Quality of the orb to mint.
     * @return The ID of the minted token.
     */
    function mint(address _to, uint256 _quality) external onlyFactory nonReentrant returns (uint256) {
        require(_quality >= 1 && _quality <= 6, "Invalid quality");
        require(qualityLimit[_quality] > 0, "Quality has reached its limit");

        uint256 _tokenId = nextTokenId++;

        // decrease quality limit
        qualityLimit[_quality]--;
        quality[_tokenId] = _quality;
        nonce[_to]++;

        _safeMint(_to, _tokenId);
        
        emit Minted(_to, _tokenId, block.timestamp);
        return _tokenId;
    }

    // Method called by the contract owner
    /**
     * @dev Sets the base URI for token metadata.
     * @param _baseUri The base URI to set.
     */
    function setBaseURI(string calldata _baseUri) external onlyOwner() {
        baseUri = _baseUri;
    }

    /**
     * @dev Sets the factory address.
     * @param _factory Address of the factory contract.
     */
    function setFactory(address _factory) public onlyOwner {
        require(_factory != address(0), "Factory can't be zero address ");
	    factory = _factory;

        emit SetFactory(_factory, block.timestamp);
    }

    /**
     * @dev Sets the verifier address for signature verification.
     * @param _verifier The verifier address to set.
     */
    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "Verifier can't be zero address ");
        verifier = _verifier;

        emit SetVerifier(_verifier, block.timestamp);
    }

    // The following functions are overrides required by Solidity.
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }
}


