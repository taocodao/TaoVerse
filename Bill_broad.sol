pragma solidity >=0.4.21 <0.7.0;


contract Billboard{

	// Variable holds the amount of clients and sellers that are allowed
	// For simplification, there are the same number in our proof of concept
	// This can easily be extended to support different numbers of clients/sellers
	// Rather than using a threshold we could also implement a timer which closes the allocation registration after a specific number of blocks
	// We leave this for future versions
	uint public THRESHOLD;

	// Variables to keep track of point in operation
	bool public inProgress;
	bool public waitingForNode;

	// Node which is set as the worker node (with TEE) for the allocation round
    address public executionNode;

    // variables measuring capacities left
    bool public sFull;
    bool public cFull;

	// variables to indicate the amount of clients/sellers in a round
	uint public c;
	uint public s;

	// Arrays to hold the nodes in the allocation
	// This again is a simlification for proof of concept
	// These are used as mappings in Solidity are not easily deleted at the next allocation start
	// We have the following limitation: as the array size (number of nodes in allocation) grows, so does the time and cost
	// Especially in the contains function
	// Mappings would have been more efficient way with constant lookup
	// Instead, we can outsource the storage of the node addresses during the allocation using decentralised storage like IPFS/Storj
	// This saves the cost of on chain data sstorage and lookup. However, implementing this is out of the scope of this paper
	// Hence we can take our results as an upper bound of cost, as decentralised storage would only incur lower cost
	address[] public Clients;
    address[] public Sellers;

	// This funciton can be called to start an allocation when there is not already one in progress
	// It resets all parameters and clears out previous data. It also sets the boolean value letting other nodes know that they can join
	function startAllocation(uint threshold) external {
	    require(!inProgress);
	    delete Clients;
	    delete Sellers;
	    delete executionNode;
	    c = s = 0;
	    cFull = sFull = false;
	    THRESHOLD = threshold;
	    inProgress = true;
	    waitingForNode = false;
	}

	// This funciton allows nodes to register to the allocation as either a client or seller
	// We make sure that indeed an allocation has been called, and that the node is not already registered
	// The input parameter decides wether the node is registered as client or seller
	// When the node is the last node in the available threshold, it sets boolean values to signal to the rest of the network that the allocation is full
	// It also shows that a worker node may now be contracted
	function register(uint x) external{

		// make sure node is not already registered
	    require( !cN(msg.sender));
	    require(inProgress);
	    require(!waitingForNode);
	    if (x == 0){
	    	require(!cFull);
	        c++;
	        Clients.push(msg.sender);
	        if(c == THRESHOLD){
	        	cFull = true;
	        }
	    }
	    else if(x == 1){
	    	require(!sFull);
	        s++;
	        Sellers.push(msg.sender);
	        if(s == THRESHOLD){
	        	sFull = true;
	        }
	    }
	    if((sFull && cFull)){
	        waitingForNode = true;
	    }
	}

	// Fucntion allows a node to claim the task as a worker when parameters indicate allocation registration is full
	// We also ensure that a node can only become a worker if it is not already a client or seller
	// Again, this is quite a simplified implementation. We may add the necesity to have some proof that the node has available TEE (either by sumitting some proof
	//  or using some other decentralised service)
	function claimTask() public {
	    require(inProgress);
	    require(waitingForNode);
	    require(!cN(msg.sender));
	    executionNode = msg.sender;
	    inProgress =false;
	}

	// This internal function checks that a node is not already registered as client ot seller
	function cN(address _adddress) internal view returns (bool){
	    for(uint i = 0; i<Clients.length; i++)
	        require(Clients[i] != _adddress);
	    for(uint j = 0; j<Sellers.length; j++)
	        require(Sellers[j] != _adddress);
	}

}

import "https://github.com/smartcontractkit/chainlink/blob/master/evm-contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";



contract Oracle{
    uint public price;
    uint public ETHprice;
    uint private thr;
	Billboard billboard;
	AggregatorV3Interface private priceFeed;


    // add only if not already setup
	function setup(address contractAddress) external{
		billboard = Billboard(contractAddress);
		price = 103;
		// only for testing. In practise would be much larger
		thr = 3;
		// adress of pricefeed on the Kovan testnet
		priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
		ETHprice = getLatestPrice();
        // ETHprice = 2;
	}

	function getAllocData() internal view returns(uint){
	    return billboard.THRESHOLD();
	}

    // 	add only possible to update price when the contract has been initiated
	function updatePrice() external returns(uint){
	    //implement some function to dictate price
	    uint z = getAllocData();
	    uint p = getLatestPrice();
	   // uint p = 1;
	    price = price + (z-thr) + (ETHprice - p);
	   // price = price + (z-thr) ;
	    thr = z;
	    ETHprice = p;
	    return price;
	}

	    function getLatestPrice() private view returns (uint) {
        (uint80 roundID, int p,uint startedAt,uint timeStamp,uint80 answeredInRound) = priceFeed.latestRoundData();
        // If the round is not complete yet, timestamp is 0
        require(timeStamp > 0, "Round not complete");
        return uint(p);
    }
}
