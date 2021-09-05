//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";
import "./@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./curves/BondingCurve.sol";

/**
 * @title CreatorToken
 * @author Javier Gonzalez
 * @dev Implementation of a Creator Token.
 * @notice Creator Tokens are the basis of valorize.app. They stake
 *         some amount of ether that can be traded out at any point.
 */
contract CreatorToken is BondingCurve, ERC20, Ownable {
    using SafeMath for uint256;
    uint256 immutable initialSupply;
    uint8 public founderPercentage;
    uint256 public reserveBalance = (10**18);
    uint256 public reserveRatio;

    constructor(
        uint256 _initialSupply,
        uint256 _reserveRatio,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        if(_initialSupply > 0){
            _mint(msg.sender, _initialSupply);
            reserveBalance.add(_initialSupply);
        }
        initialSupply = _initialSupply;
        founderPercentage = 10;
        reserveRatio = _reserveRatio;
    }

    event Burned(
        address _To,
        uint256 _amountMinted,
        uint256 _amountDeposited
    );

    event Minted(
        address buyer,
        uint256 deposited,
        uint256 amountMinted,
        uint256 amountDistributedToBuyer,
        uint256 amountDistributedToOwner
    );

    /**
     * @dev the minting mechanism requires a 'deposit' of ETH into
     *       the contract in order to generate a new token. The minted tokens
     *       are then distributed to the buyer and the owner according to the
     *       founderPercentage.
     **/
    function buyNewTokens() external payable {
        require(msg.value > 0, "Must send ETH to buy tokens");
        uint256 amountToMint = calculateTotalMintAmount(msg.value);
        _mintAndDistribute(amountToMint, msg.value);
    }
    function sellTokensForEth(uint256 _amount) external {
        require(_amount > 0, "Amount must be non-zero.");
        require(
            balanceOf(msg.sender) >= _amount,
            "not enough tokens to sell"
        );
        uint256 reimburseAmount = calculateTotalSaleReturn(_amount);
        if(payable(msg.sender).send(reimburseAmount)){
            reserveBalance = reserveBalance.sub(reimburseAmount);
            _burn(msg.sender, _amount);
            emit Burned(msg.sender, _amount, reimburseAmount);
        } else {
            revert("withdrawing failed");
        }
    }

    function _mintAndDistribute(uint256 amountToMint, uint256 _deposit) internal {
        uint256 amountForSender = (amountToMint * (100 - founderPercentage))
            .div(100);
        uint256 amountForOwner = (amountToMint * founderPercentage).div(100);

        _mint(msg.sender, amountForSender);
        _mint(owner(), amountForOwner);

        uint256 minted = amountForSender + amountForOwner; // Because of rounding errors, this is preferable than using amountToMint
        reserveBalance = reserveBalance.add(_deposit);
        emit Minted(msg.sender, _deposit, minted, amountForSender, amountForOwner);
    }

    function calculateTotalMintAmount(uint256 _deposit)
        internal
        view
        returns (uint256 mintAmount)
    {
        return
            calculatePurchaseReturn(
                totalSupply(),
                address(this).balance,
                uint32(reserveRatio),
                _deposit
            );
    }

    function calculateTotalSaleReturn(uint256 _amount)
        internal
        view
        returns (uint256 burnAmount)
    {
        return
            calculateSaleReturn(
                totalSupply(),
                address(this).balance,
                uint32(reserveRatio),
                _amount
            );
    }


    function changeFounderPercentage(uint8 _newPercentage) external onlyOwner {
        require(_newPercentage <= 100, "Founder percentage must be less than 100");
        founderPercentage = _newPercentage;
    }


    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function calculateTokenBuyReturns(uint256 _amount)
        public
        view
        returns (uint256 amountForSender, uint256 amountForOwner)
    {
        uint256 amountToMint = calculatePurchaseReturn(
                totalSupply(),
                address(this).balance + _amount,
                uint32(reserveRatio),
                _amount
            );
        amountForSender = (amountToMint * (100 - founderPercentage))
            .div(100);
        amountForOwner = (amountToMint * founderPercentage).div(100);
    }
}
