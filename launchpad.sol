// SPDX-License-Identifier: SimPL-3.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


// igo众筹智能合约
contract Launchpad {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address privateAddress;  //私人合约地址

    string public symbol;  //募资交换代币符号
    address lpAddress; //募资人代币合约地址
    uint256 lpAmountSwap; //募资人代币交换数量
    uint256 totalRaise;   //集资总额
    uint256 raised;       //已集资金额
    address tpAddress;     //集资代币合约地址
    string public tpSymbol;   //集资所用代币符号
    uint256 lpPercentRate; //价格比例:1个sab对应比例
    uint256 tpPercentRate; //价格比例:1个usdt对应比例
    uint256 public decimals = 18;   //18位数
    uint256 claimNumber;  //已领取代币数量
    bool status;   //合约状态,true为开始工作
    // tp最小数额(稳定币最小数额限制)
    uint256 public lowPrice;

    uint256 startTime;  //开始时间
    uint256 endTime;  //结束时间

    uint256 claimPercentage;   //总领取比率,不能超过100

    address payable owner; //合约拥有者

    struct Participant {
        uint256 userId;  //用户id
        address addr;   //igo钱包地址
        uint256 maxSwapAmount;  //用户可置换最大额度
        uint256 swapAmount;  //用户已置换额度
        uint256 swapPercentageAmount;   //用户已领取兑换比例额度
        uint256 totalClaimAmount;  //用户可领取代币的最大数额
        uint256 claimAmount;  //用户已领取代币数额
        mapping(uint256 => bool) claimMapFlag;    //领取用户标识
        uint256 refundAmount;  //退款数额
    }

    address[] participantArrs;    //参与人地址集合

    mapping(address => Participant) igoParticipantMap; //igo参与人数字典

    event Swap(address indexed from, address indexed to, uint256 amount);
    event Claim(address indexed from, address indexed to, uint256 amount);
    event Refund(address indexed from, address indexed to, uint256 amount);

    //领取时间线
    struct ClaimTimeline {
        uint256 claimTime;   //领取时间戳
        uint256 percentage;  //领取百分比
    }

    mapping(uint256 => ClaimTimeline) claimTimelineMap;

     // 构造函数
    constructor(){
        // 设置合约拥有者
        owner = payable(msg.sender);
        privateAddress = address(0xEBE2b323193368d5Ac52cBd5E0631E742FBF312E);
    }

     // 校验合约拥有者
    modifier onlyOwner() {
        // 判断函数调用者是否为owner
        require(msg.sender == owner);
        _;
    }

    // 设置igo信息
    // lpAddress项目方代币合约地址
    // tpAddress募资稳定币token地址
    // 
    function setIgoInfo(address _lpAddress, address _tpAddress, uint256 _totalRaise, uint256 _startTime, uint256 _endTime, 
        uint256 _lpPercentRate, uint256 _tpPercentRate) public onlyOwner {
        require(_lpAddress != address(0), "_lpAddress address cannot be 0!");
        lpAddress = _lpAddress;
        require(_tpAddress != address(0), "_tpAddress address cannot be 0!");
        tpAddress = _tpAddress;

        (,symbol) = balanceOfByAccount(_lpAddress);
        (,tpSymbol) = balanceOfByAccount(_tpAddress);
        startTime = _startTime;
        endTime = _endTime;
        totalRaise = _totalRaise;   //募资总额
        tpPercentRate = _tpPercentRate;  //价格比例
        lpPercentRate = _lpPercentRate;  //价格比例
        lpAmountSwap = _totalRaise.mul(_lpPercentRate).div(_tpPercentRate);  //计算募资人代币数量
    }

    // 设置最小数额交易
    function setLowPrice(uint256 _lowprice) public onlyOwner {
        lowPrice = _lowprice;
    }
    
    // 获取合约代币信息
    function balanceOfByAccount(address _lpAddress) private view returns (uint256, string memory) {
        return (IERC20(_lpAddress).balanceOf(address(this)), ERC20(_lpAddress).symbol());
    }

    // 设置igo钱包所能领取到的额度
    function setIgoWalletAmount(address _wallAddress, uint256 _userId, uint256 _maxSwapAmount) public onlyOwner {
        //先判断igo项目信息是否已存在
        require(lpAddress != address(0), "Igo information does not exist");

        // 校验是否到申请时间
        require(block.timestamp >= startTime && block.timestamp < endTime, "The time has not started or ended!");

        Participant storage participant = igoParticipantMap[_wallAddress];
        require(participant.userId == 0, "You have applied for igo");

        participant.addr = _wallAddress;
        participant.userId = _userId;
        participant.maxSwapAmount = _maxSwapAmount;
        //增加数组
        participantArrs.push(_wallAddress);
    }

    // 获取代币数据信息
    function getLpTokenClaimInfo() public view returns(uint256, uint256) {
        return (lpAmountSwap, claimNumber);
    }

    // 获取参与者数量
    function getParticipantNumber() public view returns(uint256) {
        return participantArrs.length;
    }

    // 重置igo申请钱包
    function resetIgoWalletAmount(address _wallAddress) public onlyOwner {
        delete igoParticipantMap[_wallAddress];   //删除指定的igo钱包地址
    }

    // 获取igo项目基本数据信息
    function getIgoPadsInfo() public view returns(address, uint256, uint256, uint256, string memory, string memory, uint256, uint256) {
        return (lpAddress, lpAmountSwap, totalRaise, raised, symbol, tpSymbol, lpPercentRate, tpPercentRate);
    }

    // 获取参与者数据信息
    function getParticipant(address addr) public view returns(uint256, address, uint256, uint256, uint256, uint256) {
        Participant storage participant = igoParticipantMap[addr];
        require(participant.userId != 0, "Igo Information does not exist!");

        return (participant.userId, participant.addr, participant.maxSwapAmount, participant.swapAmount, participant.totalClaimAmount, participant.claimAmount);
    } 

    // 获取开始时间和结束时间
    function getStartOrEndTime() public view returns(uint256, uint256) {
        return (startTime, endTime);
    }

    // 获取领取额度
    function swap(uint256 _value) public {
        Participant storage participant = igoParticipantMap[msg.sender];
        require(participant.userId != 0, "Igo Information does not exist!");

        //判断交易金额最小值
        require(_value >= lowPrice, "Cannot be less than the minimum amount!");

        //交易开始时间和结束时间
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Not in IGO time range at this time!");

        // 个人可领额度校验
        require(_value > 0 && _value <= participant.maxSwapAmount.sub(participant.swapAmount), "The Max swapallocation has been exceeded!");

        // 校验全部额度
        require(_value <= totalRaise.sub(raised), "The totalRaise has been exceeded");

        // 校验合约appove额度
        require(IERC20(tpAddress).allowance(msg.sender, address(this)) >= _value, "The allowance not enough!");   


        participant.swapAmount = participant.swapAmount.add(_value);
        raised = raised.add(_value);
        participant.totalClaimAmount =  participant.totalClaimAmount.add(_value.mul(lpPercentRate).div(tpPercentRate));    //最大可领取代币

        IERC20(tpAddress).safeTransferFrom(msg.sender, privateAddress, _value);   //转移代币到私人合约地址

        emit Swap(msg.sender, privateAddress, _value);   //记录日志
    }

    // 设置领取时间线
    function setClaimTimeline(uint256 claimTimeId, uint256 _claimTime, uint256 _percentage, uint256 _del) public onlyOwner {
        require(_percentage > 0 && _percentage <= 100, "claim percentage verfiy fail");

        require(_claimTime > 0, "_claimTime verfiy fail");

        require(claimTimeId > 0, "claimTimeId verfiy fail");

        ClaimTimeline storage claimTimeline = claimTimelineMap[claimTimeId];
        if (_del != 0) {
            delete claimTimelineMap[claimTimeId];   //删除指定的时间线
            claimPercentage = claimPercentage.sub(_percentage);
            return;
        }

        if (claimTimeline.claimTime != 0) {
            //如果是更新，要先减去原有的再进行校验
            claimPercentage = claimPercentage.sub(claimTimeline.percentage);
        } 

        require(claimPercentage.add(_percentage) <= 100, "claim percentage verfiy fail, claimPercentage have more than 100");

        claimPercentage = claimPercentage.add(_percentage);

        claimTimeline.claimTime = _claimTime;
        claimTimeline.percentage = _percentage;
    } 

    // claim用户领取
    function claim(uint256 claimTimeId) public {
        // 校验用户是不是有资格领取
        Participant storage participant = igoParticipantMap[msg.sender];
        require(participant.userId != 0, "Igo Information does not exist!");

        ClaimTimeline storage claimTimeline = claimTimelineMap[claimTimeId];
        require(claimTimeline.claimTime > 0, "ClaimTimeline does not exist!");

        // 校验是否到claim领取时间
        require(block.timestamp > endTime && block.timestamp > claimTimeline.claimTime, "Claim time not reached!");

        // 校验用户是否已领取
        require(!participant.claimMapFlag[claimTimeId], "You have received it");

        uint256 claimAmount = participant.totalClaimAmount.mul(claimTimeline.percentage).div(100);

        // 校验合约中的数量是否足够
        require(IERC20(lpAddress).balanceOf(address(this)) >= claimAmount, "The amount not enough!");

        participant.claimAmount = participant.claimAmount.add(claimAmount);

        uint256 swapPercentageAmount = participant.swapAmount.mul(claimTimeline.percentage).div(100);   //领取兑换额度比例
        participant.swapPercentageAmount = participant.swapPercentageAmount.add(swapPercentageAmount);  

        claimNumber = claimNumber.add(claimAmount);   //已领取数量增加

        IERC20(lpAddress).safeTransfer(msg.sender, claimAmount);   //从合约地址转移代币到用户

        // 记录领取标识
        participant.claimMapFlag[claimTimeId] = true;

        emit Claim(address(this), msg.sender, claimAmount);   //记录日志
    }

    // refund合约退款
    function refund() public onlyOwner {
        for (uint256 i = 0; i < participantArrs.length; i++) {
            Participant storage participant = igoParticipantMap[participantArrs[i]];
            if (participant.swapAmount == 0) {
                continue;
            }
            uint256 refundSwapAmount = participant.swapAmount.sub(participant.swapPercentageAmount).sub(participant.refundAmount);

            if (refundSwapAmount <= 0) {
                continue;
            }

            //记录已退款金额
            participant.refundAmount = participant.refundAmount.add(refundSwapAmount);

            IERC20(tpAddress).transferFrom(address(this), participant.addr, refundSwapAmount);   //退款给回用户

            emit Refund(address(this), participant.addr, refundSwapAmount);   //记录日志
        }
    }

    // 给某个用户退款
    function refundByAddr(address _addr) public onlyOwner {
        Participant storage participant = igoParticipantMap[_addr];
        require(participant.swapAmount > 0, "Non-conformance with requirements!");

        uint256 refundSwapAmount = participant.swapAmount.sub(participant.swapPercentageAmount).sub(participant.refundAmount);

        require(refundSwapAmount > 0, "Non-conformance with requirements!");

        participant.refundAmount = participant.refundAmount.add(refundSwapAmount);
        IERC20(tpAddress).transferFrom(address(this), participant.addr, refundSwapAmount);   //退款给回用户
        emit Refund(address(this), participant.addr, refundSwapAmount);   //记录日志
    }

    //  根据token和用户信息查余额
    function balanceTokenOfByUser(address _account, address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(_account);
    }

    // 给项目方退代币
    function tokenRefund(address _addr) public onlyOwner {
        uint256 bmount = balanceTokenOfByUser(_addr, lpAddress);
        IERC20(lpAddress).safeTransfer(_addr, bmount);
        emit Refund(address(this), _addr, bmount);   //记录日志
    }

    // vip用户申请额度
    function vipAccountMake(address _addr, uint256 _amount) public onlyOwner {
        //先判断igo项目信息是否已存在
        require(lpAddress != address(0), "Igo information does not exist");

        Participant storage participant = igoParticipantMap[_addr];

        participant.addr = _addr;
        participant.maxSwapAmount = _amount;
        //增加数组
        participantArrs.push(_addr);
    }

    //  查看claim时间线
    function getClaimTimeline(uint256 claimTimeId) public view returns(ClaimTimeline memory) {
        ClaimTimeline storage claimTimeline = claimTimelineMap[claimTimeId];
        return claimTimeline;
    }

    // 获取用户阶段领取标识
    function getUserClaimflag(address _addr, uint256 claimTimeId) public view returns(bool) {
        Participant storage participant = igoParticipantMap[_addr];
        return participant.claimMapFlag[claimTimeId];
    }

    // 查找所有参与者
    function FindAllParticipants() public view onlyOwner returns(address[] memory) {
        return participantArrs;
    }
}