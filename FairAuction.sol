pragma solidity ^0.4.2;
contract token { 
    function transfer(address, uint256){  }
    function balanceOf(address) constant returns (uint256) { }
}

/// @title FairAuction contract
/// @author Christopher Grant - <christopher@delphi.markets>
contract FairAuction {
    /* State */
    address public beneficiary;
    uint public amountRaised; uint public startTime; uint public deadline; uint public memberCount; uint public crowdsaleCap;
    uint256 public tokenSupply;
    token public tokenReward;
    mapping(address => uint256) public balanceOf;
    mapping (uint => address) accountIndex;

    /* Events */
    event TokenAllocation(address recipient, uint amount);
    event Finalized(address beneficiary, uint amountRaised);
    event FundTransfer(address backer, uint amount);
    event FundClaim(address claimant, uint amount);

    /* Initialize relevant crowdsale contract details */
    function FairAuction(
        address fundedAddress,
        uint epochStartTime,
        uint durationInMinutes,
        uint256 capOnCrowdsale,
        token contractAddressOfRewardToken
    ) {
        beneficiary = fundedAddress;
        startTime = epochStartTime;
        deadline = startTime + (durationInMinutes * 1 minutes);
        tokenReward = token(contractAddressOfRewardToken);
        crowdsaleCap = capOnCrowdsale * 1 ether;
    }

    /* default function (called whenever funds are sent to the FairAuction) */
    function () payable {
        /* Ensure that auction is ongoing */
        if (now < startTime) throw;
        if (now >= deadline) throw;

        uint amount = msg.value;

        /* Ensure that we do not pass the cap */
        if (amountRaised + amount > crowdsaleCap) throw;

        uint256 existingBalance = balanceOf[msg.sender];

        /* Tally new members (helps iteration later) */
        if (existingBalance == 0) {
            accountIndex[memberCount] = msg.sender;
            memberCount += 1;
        } 
        
        /* Track contribution amount */
        balanceOf[msg.sender] = existingBalance + amount;
        amountRaised += amount;

        /* Fire FundTransfer event */
        FundTransfer(msg.sender, amount);
    }

    /* finalize() can be called once the FairAuction has ended and will allocate the auctioned tokens and crowdsale proceeds */
    function finalize() {
        /* Nothing to finalize */
        if (amountRaised == 0) throw;

        /* Auction still ongoing */
        if (now < deadline) {
            /* Don't terminate auction before cap is reached */
            if (amountRaised < crowdsaleCap) throw;
        }
        
        /* Send proceeds to beneficiary */
        if (beneficiary.send(amountRaised)) {
            /* Fire FundClaim event */
            FundClaim(beneficiary, amountRaised);
        }

        tokenSupply = tokenReward.balanceOf(this);
        /* Distribute auctioned tokens among participants fairly */
        for (uint i=0; i<memberCount; i++) {
            /* Should not occur */
            if (accountIndex[i] == 0)
                continue;
            /* Grant tokens due */
            tokenReward.transfer(accountIndex[i], (balanceOf[accountIndex[i]] * tokenSupply / amountRaised));
            /* Fire TokenAllocation event */
            TokenAllocation(accountIndex[i], (balanceOf[accountIndex[i]] * tokenSupply / amountRaised));
        }

        /* Fire Finalized event */
        Finalized(beneficiary, amountRaised);        
    }
}