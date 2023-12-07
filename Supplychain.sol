// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Supplychain is Ownable, AccessControl {

    // Define roles with the AccessControl framework
    bytes32 public constant HERDER_ROLE = keccak256("HERDER");
    bytes32 public constant SLAUGHTERHOUSE_ROLE = keccak256("SLAUGHTERHOUSE");
    bytes32 public constant TRANSPORTER_ROLE = keccak256("TRANSPORTER");
    bytes32 public constant MARKET_ROLE = keccak256("MARKET");
    //bytes32 public constant INDIVIDUAL_ROLE = keccak256("INDIVIDUAL");

    // Define enums with consistent naming
    enum OrderStatus { PENDING, CONFIRMED, IN_TRANSIT, COMPLETED, CANCELED }
    enum RoleChoice { Herder, Slaughterhouse, Transporter, Market, Individual }

    // Counter for generating unique IDs
    uint256 private herderIdCounter = 1;
    uint256 private slaughterhouseIdCounter = 1;
    uint256 private transporterIdCounter = 1;
    
    // Define structs for each stakeholder
    struct Herder {
        uint256 id;
        string location;
        uint256 grade;
        uint256 totalLivestock; // Total number of livestock
        uint256 pricePerKg; // Price per kilogram
        bool registered;
        uint256 aimagTotalLivestock;
        uint256 aimagPastureCarryingCapacity;
        uint256 aimagTotalHerderNumber;
    }
    
    struct Slaughterhouse {
        uint256 id;
        string location;
        uint256 pricePerKg;
        bool registered;
    }
    
    struct Transporter {
        uint256 id;
        string truckInfo;
        uint256 pricePerKm;
        bool registered;
        string location;
    }
    
    /*struct Market {
        uint256 id;
        string location;
        uint256 pricePerKg;
        bool registered;
    }*/
    
    /*struct Individual {
        uint256 id;
        string location;
        bool registered;
    }*/

    // Define struct for orders
    struct Order {
        uint256 id;
        address buyer;
        address seller;
        uint256 quantity;
        uint256 price;
        uint256 distance; // Distance in kilometers or any unit of measure
        uint256 transportationCost; // Calculated based on distance and pricePerKm
        OrderStatus status;
        uint256[] earTagNumber;
    }
    
    // Define events with parameters
    event RegisteredHerder(uint256 indexed herderId, uint256 grade, address herderAddress);
    event OrderPlaced(uint256 indexed orderId, address indexed buyer, uint256 quantity, uint256 price);
    event OrderConfirmed(uint256 indexed orderId);
    event TransportationRequested(uint256 indexed orderId, address indexed transporter, uint256 distance);
    event DeliveryConfirmed(uint256 indexed orderId);
    event LivestockPickedUp(uint256 indexed orderId, uint256 quantityPickedUp);
    event LivestockDelivered(uint256 indexed orderId, uint256[] earTagNumbers);
    event OrderCanceled(uint256 indexed orderId);

    // Define state variables
    mapping(uint256 => Herder) public herders;
    mapping(uint256 => Slaughterhouse) public slaughterhouses;
    mapping(uint256 => Transporter) public transporters;
    //mapping(address => Market) public markets;
    //mapping(address => Individual) public individuals;
    mapping(uint256 => Order) public orders;

    // Mapping to link an Ethereum address with its numerical herder ID
    mapping(address => uint256) public herderAddressToId;
    mapping(uint256 => address) public herderIdToAddress;
    mapping(address => uint256) public slaughterhouseAddressToId;
    mapping(address => uint256) public transporterAddressToId;
    mapping(uint256 => uint256) public earTagToOrderId;
    mapping(address => bool) public hasChosenRole;
    mapping(address => RoleChoice) private userRoles;
    uint256 public nextOrderId = 1;
   


    // Modifiers for access control
    modifier onlyHerder() {
        require(hasRole(HERDER_ROLE, msg.sender), "Caller is not a herder");
        _;
    }

    modifier onlySlaughterhouse() {
        require(hasRole(SLAUGHTERHOUSE_ROLE, msg.sender), "Caller is not a slaughterhouse");
        _;
    }
    
    modifier onlyTransporter() {
        require(hasRole(TRANSPORTER_ROLE, msg.sender), "Caller is not a transporter");
        _;
    }

    modifier onlyMarket() {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market");
        _;
    }
    
    /*modifier onlyIndividual() {
        require(hasRole(INDIVIDUAL_ROLE, msg.sender), "Caller is not an individual");
        _;
    }*/

    // Constructor to initialize the Aimag data
    constructor() Ownable(msg.sender) {
        // Set the deployer as the admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    // Function for users to choose a role
    function chooseRole(RoleChoice choice) public {
        require(!hasChosenRole[msg.sender], "User has already chosen a role");

        bytes32 role;
        if (choice == RoleChoice.Herder) {
            role = HERDER_ROLE;
        } else if (choice == RoleChoice.Slaughterhouse) {
            role = SLAUGHTERHOUSE_ROLE;
        } else if (choice == RoleChoice.Transporter) {
            role = TRANSPORTER_ROLE;
        } else if (choice == RoleChoice.Market) {
            role = MARKET_ROLE;
        //} else if (choice == RoleChoice.Individual) {
            //role = INDIVIDUAL_ROLE;
        } else {
            revert("Invalid role choice");
        }

        _grantRole(role, msg.sender);
        userRoles[msg.sender] = choice; // Store the user's chosen role
        hasChosenRole[msg.sender] = true;
    }

    function getUserRole(address user) public view returns (RoleChoice) {
        require(hasChosenRole[user], "User has not chosen a role");
        return userRoles[user];
    }
    
    // Function to register a herder
    function registerHerder(
        string memory location, 
        uint256 totalLivestock, 
        uint256 pricePerKg,
        uint256 aimagTotalLivestock,
        uint256 aimagPastureCarryingCapacity,
        uint256 aimagTotalHerderNumber
    ) public {
        require(hasRole(HERDER_ROLE, msg.sender), "Caller is not a herder");
        require(herderAddressToId[msg.sender] == 0, "Herder already registered.");
       
        uint256 herderId = herderIdCounter;
        herderIdCounter++;
        
        herderAddressToId[msg.sender] = herderId;
        herderIdToAddress[herderId] = msg.sender; 
        
        uint256 gradePoints = calculateGradePoints(aimagTotalLivestock, aimagPastureCarryingCapacity, totalLivestock, aimagTotalHerderNumber);
        uint256 grade = getGrade(gradePoints);

        Herder storage newHerder = herders[herderId];
        newHerder.id = herderId;
        newHerder.totalLivestock = totalLivestock;
        newHerder.pricePerKg = pricePerKg;
        newHerder.location = location;
        newHerder.grade = grade;
        newHerder.registered = true;
        newHerder.aimagTotalLivestock = aimagTotalLivestock;
        newHerder.aimagPastureCarryingCapacity = aimagPastureCarryingCapacity;
        newHerder.aimagTotalHerderNumber = aimagTotalHerderNumber;
        
        emit RegisteredHerder(herderId, grade, msg.sender);
    }

    
    function calculateGradePoints(
        uint256 aimagTotalLivestock, 
        uint256 aimagPastureCarryingCapacity, 
        uint256 totalLivestock, 
        uint256 aimagTotalHerderNumber
        ) internal pure returns (uint256) {
        uint256 pcr = aimagTotalLivestock  / aimagPastureCarryingCapacity; // Multiply by 10 to preserve some decimal accuracy
        uint256 livestockPerHerder = aimagPastureCarryingCapacity  / aimagTotalHerderNumber;
        uint256 gradePoints = pcr + (totalLivestock  / livestockPerHerder) ; // Adjust the final result
        return gradePoints;
        }
    
    function getGrade(uint256 gradePoints) internal pure returns (uint256) {
        if (gradePoints >= 0 && gradePoints <= 2) return 1;
    if (gradePoints > 2 && gradePoints <= 4) return 2;
    if (gradePoints > 4 && gradePoints <= 6) return 3;
    if (gradePoints > 6 && gradePoints <= 8) return 4;
    if (gradePoints > 8 && gradePoints <= 10) return 5;
    return 6; // For gradePoints greater than 10
    }
    // Function to register a slaughterhouse
    function registerSlaughterhouse(string memory location, uint256 pricePerKg) public {
        require(hasRole(SLAUGHTERHOUSE_ROLE, msg.sender), "Caller is not a slaughterhouse");
        require(slaughterhouseAddressToId[msg.sender] == 0, "Slaughterhouse already registered.");
        
        uint256 id = slaughterhouseIdCounter++;
        Slaughterhouse storage newSlaughterhouse = slaughterhouses[id];
        newSlaughterhouse.id = id;
        newSlaughterhouse.location = location;
        newSlaughterhouse.pricePerKg = pricePerKg;
        newSlaughterhouse.registered = true;
        slaughterhouseAddressToId[msg.sender] = id;

        // Emit an event if needed
    }

    // Function to register a transporter
    function registerTransporter(string memory location, string memory truckInfo, uint256 pricePerKm) public {
        require(hasRole(TRANSPORTER_ROLE, msg.sender), "Caller is not a transporter");
        require(transporterAddressToId[msg.sender] == 0, "Transporter already registered.");
        
        uint256 id = transporterIdCounter++;
        Transporter storage newTransporter = transporters[id];
        newTransporter.id = id;
        newTransporter.truckInfo = truckInfo;
        newTransporter.pricePerKm = pricePerKm;
        newTransporter.location = location;
        newTransporter.registered = true;
        transporterAddressToId[msg.sender] = id;

        // Emit an event if needed
    }
    
    /*function registerMarket(
        string memory location, 
        uint256 pricePerKg
        ) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market");
        Market storage m = markets[msg.sender];
        require(!m.registered, "Market already registered.");
        m.registered = true;
        m.location = location;
        m.pricePerKg = pricePerKg;
    }*/
    
    /*function registerIndividual(string memory location) public {
        require(hasRole(INDIVIDUAL_ROLE, msg.sender), "Caller is not an individual");
        Individual storage ind = individuals[msg.sender];
        require(!ind.registered, "Individual already registered.");

        ind.registered = true;
        ind.location = location;
    }*/

    // Function to place an order
function placeOrder(uint256 herderId, uint256 quantity) public {
    require(herderId != 0 && herderId < herderIdCounter, "Invalid herder ID.");
    require(herderAddressToId[msg.sender] != herderId, "Cannot place an order with yourself.");

    Herder storage herder = herders[herderId];
    require(herder.registered, "Seller is not a registered herder.");
    require(herder.totalLivestock >= quantity, "Not enough livestock available.");
    uint256 price = herder.pricePerKg * quantity;

    Order storage newOrder = orders[nextOrderId];
    newOrder.id = nextOrderId++;
    newOrder.buyer = msg.sender;
    newOrder.seller = herderIdToAddress[herderId];
    
    newOrder.quantity = quantity;
    newOrder.price = price;
    newOrder.status = OrderStatus.PENDING;
    newOrder.earTagNumber = new uint256[](0);

    emit OrderPlaced(newOrder.id, msg.sender, price, quantity);
}

    // Function to confirm an order
    function confirmOrder(uint256 orderId, bool confirm) public onlyHerder {
        require(orders[orderId].seller == msg.sender, "Only the seller can confirm the order");
        require(orders[orderId].status == OrderStatus.PENDING, "Order is not pending.");
        
        if (confirm) {
            orders[orderId].status = OrderStatus.CONFIRMED;
            emit OrderConfirmed(orderId);
        } else {
            orders[orderId].status = OrderStatus.CANCELED;
            emit OrderCanceled(orderId);
        }
    }

    // Function to request transportation
    function requestTransportation(uint256 orderId, address transporter, uint256 distance) public {
        require(orders[orderId].buyer == msg.sender, "Only the buyer can request transportation");
        require(orders[orderId].status == OrderStatus.CONFIRMED, "Order not confirmed yet");
        
        // Calculate transportation cost
        uint256 transporterId = transporterAddressToId[transporter];
        Transporter storage transporterStruct = transporters[transporterId];
        require(transporterStruct.registered, "Transporter not registered");
        
        uint256 transportationCost = distance * transporterStruct.pricePerKm;

        // Update the order with transportation details
        Order storage order = orders[orderId];
        order.distance = distance;
        order.transportationCost = transportationCost;
        order.status = OrderStatus.IN_TRANSIT;
        emit TransportationRequested(orderId, transporter, distance);
    }

    // Function to confirm delivery request
    function confirmDeliveryRequest(uint256 orderId) public onlyTransporter {
        require(orders[orderId].status == OrderStatus.IN_TRANSIT, "Transport request not in transit state");
        emit DeliveryConfirmed(orderId);
    }

    // Function to confirm pick up
    function confirmPickUp(uint256 orderId, uint256 quantityPickedUp) public onlyTransporter {
        require(orders[orderId].status == OrderStatus.IN_TRANSIT, "Order must be in transit");
        emit LivestockPickedUp(orderId, quantityPickedUp);
    }

    // Function to confirm delivery
    function confirmDelivery(uint256 orderId, uint256[] calldata earTagNumbers) public {
        require(orders[orderId].status == OrderStatus.IN_TRANSIT, "Order must be in transit");
        require(orders[orderId].buyer == msg.sender, "Only the buyer can confirm delivery");
        for (uint i = 0; i < earTagNumbers.length; i++) {
            earTagToOrderId[earTagNumbers[i]] = orderId;
        }
        Order storage order = orders[orderId]; // Fix here, properly access the order object
        order.status = OrderStatus.COMPLETED;
        
        emit LivestockDelivered(orderId, earTagNumbers);
    }

    // Function to get information of all herders
    function getAllHerders() public view returns (Herder[] memory) {
        Herder[] memory herdersArray = new Herder[](herderIdCounter);
        for (uint256 i = 1; i < herderIdCounter; i++) {
            Herder storage herder = herders[i];
            herdersArray[i - 1] = herder;
        }
        return herdersArray;
    }
    // Function to get information of all slaughterhouses
    function getAllSlaughterhouses() public view returns (Slaughterhouse[] memory) {
        Slaughterhouse[] memory allSlaughterhouses = new Slaughterhouse[](slaughterhouseIdCounter);
        for (uint256 i = 1; i < slaughterhouseIdCounter; i++) {
            allSlaughterhouses[i - 1] = slaughterhouses[i];
        }
        return allSlaughterhouses;
    }

    // Function to get information of all transporters
    function getAllTransporters() public view returns (Transporter[] memory) {
        Transporter[] memory allTransporters = new Transporter[](transporterIdCounter);
        for (uint256 i = 1; i < transporterIdCounter; i++) {
            allTransporters[i - 1] = transporters[i];
        }
        return allTransporters;
    }

    function getAllOrders() public view returns (Order[] memory) {
        Order[] memory ordersArray = new Order[](nextOrderId);
        for (uint256 i = 1; i < nextOrderId; i++) {
            Order storage order = orders[i];
            ordersArray[i - 1] = order;
        }
        return ordersArray;
    }
    function getLivestockDataByEarTag(uint256 earTagNumber) public view returns (
        string memory herderLocation, 
        uint256 herderGrade, 
        uint256 herderPricePerKg, 
        string memory slaughterhouseLocation,
        uint256 slaughterhousePricePerKg,
        string memory transporterInfo,
        uint256 transporterPricePerKm
    ) {
        uint256 orderId = earTagToOrderId[earTagNumber];
        Order memory order = orders[orderId];
        Herder memory herder = herders[herderAddressToId[order.seller]];

        uint256 slaughterhouseId = slaughterhouseAddressToId[order.buyer];
        Slaughterhouse memory slaughterhouse = slaughterhouses[slaughterhouseId]; // Assuming buyer is linked to a slaughterhouse

        uint256 transporterId = transporterAddressToId[order.buyer];
        Transporter memory transporter = transporters[transporterId]; // Assuming buyer is linked to a transporter

        // Return the requested details
        return (
            herder.location,
            herder.grade,
            herder.pricePerKg,
            slaughterhouse.location,
            slaughterhouse.pricePerKg,
            transporter.truckInfo,
            transporter.pricePerKm
        );
}
}
