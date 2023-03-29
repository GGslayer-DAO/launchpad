// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NftMeta is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    // 是否准许nft开卖-开关
    bool public _isSaleActive = false;
    // 初始化盲盒，等到一定时机可以随机开箱，变成true
    bool public _revealed = false;

    address private privateAddress;  //私人合约地址

    // nft的总数量
    uint256 MAX_SUPPLY;
    // 铸造Nft的价格
    uint256 public mintPrice = 0.3 ether;
    // 铸造的钱包最多只能有一个nft数量
    uint256 public maxBalance = 1;
    // 一次mint的nft的数量
    uint256 public maxMint = 1;

    // 盲盒开关打开后，需要显示开箱的图片的base地址
    string baseURI;
    // 盲盒图片的meta,json地址，后文会提到
    string public notRevealedUri;
    // 默认地址的扩展类型
    string public baseExtension = ".json";
    // 使用erc20铸币地址
    address erc20Address;
    
    event Mint(address indexed from, address indexed to, uint256 amount, uint256 num);

    mapping(uint256 => string) private _tokenURIs;

    // 构造器
    constructor(string memory initBaseURI, string memory initNotRevealedUri)
        ERC721("Nft Meta", "NM") // 实现了ERC721的父类构造器，是子类继承的一种实现方式
    {
        setBaseURI(initBaseURI);
        setNotRevealedURI(initNotRevealedUri);
    } 

    // 设置最大供应量
    function setMaxSupply(uint256  _maxSupply) public onlyOwner {
        MAX_SUPPLY = _maxSupply;
    }

    // 设置私人转账地址
    function setPrivateAddress(address _privateAddress) public onlyOwner {
        privateAddress = _privateAddress;
    }

    // 设置erc付款代币地址
    function setErc20Address(address _erc20Address) public onlyOwner {
        erc20Address = _erc20Address;
    }

    // 外部地址进行铸造nft的函数调用
    function mintNftMeta(uint256 tokenQuantity) public payable {
        // 校验总供应量+每次铸造的数量<= nft的总数量
        require(
            totalSupply() + tokenQuantity <= MAX_SUPPLY,
            "Sale would exceed max supply"
        );
        // 校验是否开启开卖状态
        require(_isSaleActive, "Sale must be active to mint NicMetas");
        // 校验铸造的钱包地址中的nft的数量 + 本次铸造的数量 <= 该钱包最大拥有的nft的数量
        require( 
            balanceOf(msg.sender) + tokenQuantity <= maxBalance,
            "Sale would exceed max balance"
        );
        // 校验本次铸造的数量*铸造的价格 <= 本次消息附带的eth的数量
        require(
            tokenQuantity * mintPrice <= msg.value,
            "Not enough ether sent"
        );
        // 校验本次铸造的数量 <= 本次铸造的最大数量
        require(tokenQuantity <= maxMint, "Can only mint 1 tokens at a time");
        // 以上校验条件满足，进行nft的铸造
        _mintNftMeta(tokenQuantity);
        // 铸币成功，转钱到私人账户
        payable(privateAddress).transfer(msg.value);
        emit Mint(msg.sender, privateAddress, msg.value, tokenQuantity);   //记录日志
    }

    // 使用erc20进行购买铸币
    function mintNftMetaByErc20(uint256 tokenQuantity, uint256 _value) public {
        // 校验总供应量+每次铸造的数量<= nft的总数量
        require(
            totalSupply() + tokenQuantity <= MAX_SUPPLY,
            "Sale would exceed max supply"
        );
        // 校验是否开启开卖状态
        require(_isSaleActive, "Sale must be active to mint NicMetas");
        // 校验铸造的钱包地址中的nft的数量 + 本次铸造的数量 <= 该钱包最大拥有的nft的数量
        require( 
            balanceOf(msg.sender) + tokenQuantity <= maxBalance,
            "Sale would exceed max balance"
        );
        // 校验本次铸造的数量*铸造的价格 <= 本次消息附带的eth的数量
        require(
            tokenQuantity * mintPrice <= _value,
            "Not enough money sent"
        );
        // 校验本次铸造的数量 <= 本次铸造的最大数量
        require(tokenQuantity <= maxMint, "Can only mint 1 tokens at a time");

        // 校验合约appove额度
        require(IERC20(erc20Address).allowance(msg.sender, address(this)) >= _value, "The allowance not enough!");  

        // 以上校验条件满足，进行nft的铸造
        _mintNftMeta(tokenQuantity);
        // 铸币成功，转钱到私人账户
        IERC20(erc20Address).safeTransferFrom(msg.sender, privateAddress, _value);   //转移代币到私人合约地址
        emit Mint(msg.sender, privateAddress, _value, tokenQuantity);   //记录日志
    }

    // 进行铸造
    function _mintNftMeta(uint256 tokenQuantity) internal {
        for (uint256 i = 0; i < tokenQuantity; i++) {
            // mintIndex是铸造nft的序号，按照总供应量从0开始累加
            uint256 mintIndex = totalSupply();
            if (totalSupply() < MAX_SUPPLY) {
                // 调用erc721的安全铸造方法进行调用
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    // 返回每个nft地址的Uri，这里包含了nft的整个信息，包括名字，描述，属性等
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        // 盲盒还没开启，那么默认是一张黑色背景图片或者其他图片
        if (_revealed == false) {
            return notRevealedUri;
        }

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return
            string(abi.encodePacked(base, tokenId.toString(), baseExtension));
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //only owner
    function flipSaleActive() public onlyOwner {
        _isSaleActive = !_isSaleActive;
    }

    function flipReveal() public onlyOwner {
        _revealed = !_revealed;
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setMaxBalance(uint256 _maxBalance) public onlyOwner {
        maxBalance = _maxBalance;
    }

    function setMaxMint(uint256 _maxMint) public onlyOwner {
        maxMint = _maxMint;
    }

    function withdraw(address to) public onlyOwner {
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
    }
}