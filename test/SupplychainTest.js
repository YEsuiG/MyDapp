const Supplychain = artifacts.require("Supplychain");

contract("Supplychain", accounts => {
  let supplychainInstance;
  let globalOrderId;

  before(async () => {
    supplychainInstance = await Supplychain.new();
  });

  // Test Role Assignments
  it("should assign roles correctly", async () => {
    // Assign Herder Role
    await supplychainInstance.chooseRole(Supplychain.RoleChoice.Herder, { from: accounts[1] });
    let roleHerder = await supplychainInstance.getUserRole(accounts[1]);
    assert.equal(roleHerder.toString(), Supplychain.RoleChoice.Herder.toString(), "Role not assigned correctly to Herder");

    // Assign Slaughterhouse Role
    await supplychainInstance.chooseRole(Supplychain.RoleChoice.Slaughterhouse, { from: accounts[2] });
    let roleSlaughterhouse = await supplychainInstance.getUserRole(accounts[2]);
    assert.equal(roleSlaughterhouse.toString(), Supplychain.RoleChoice.Slaughterhouse.toString(), "Role not assigned correctly to Slaughterhouse");

    // Assign Transporter Role
    await supplychainInstance.chooseRole(Supplychain.RoleChoice.Transporter, { from: accounts[3] });
    let roleTransporter = await supplychainInstance.getUserRole(accounts[3]);
    assert.equal(roleTransporter.toString(), Supplychain.RoleChoice.Transporter.toString(), "Role not assigned correctly to Transporter");
  });

  // Test Registering a Herder
  it("should register a herder", async () => {
    await supplychainInstance.registerHerder("Location A", 100, 10, 1000, 500, 100, { from: accounts[1] });
    const herderId = await supplychainInstance.herderAddressToId(accounts[1]);
    const registeredHerder = await supplychainInstance.herders(herderId);
    assert.equal(registeredHerder.registered, true, "Herder not registered correctly");
  });

  // Test Registering a Slaughterhouse
  it("should register a slaughterhouse", async () => {
    await supplychainInstance.registerSlaughterhouse("Location B", 50, { from: accounts[2] });
    const slaughterhouseId = await supplychainInstance.slaughterhouseAddressToId(accounts[2]);
    const newSlaughterhouse = await supplychainInstance.slaughterhouses(slaughterhouseId);
    assert.equal(newSlaughterhouse.registered, true, "Slaughterhouse not registered correctly");
  });

  // Test Registering a Transporter
  it("should register a transporter", async () => {
    await supplychainInstance.registerTransporter("Location C", "Truck XYZ", 10, { from: accounts[3] });
    const transporterId = await supplychainInstance.transporterAddressToId(accounts[3]);
    const newTransporter = await supplychainInstance.transporters(transporterId);
    assert.equal(newTransporter.registered, true, "Transporter not registered correctly");
  });

  // Test Placing and Confirming an Order
  it("should allow placing and confirming an order", async () => {
    const herderId = await supplychainInstance.herderAddressToId(accounts[1]);
    await supplychainInstance.placeOrder(herderId, 10, { from: accounts[2] }); // accounts[2] as a buyer
    const orderId = await supplychainInstance.nextOrderId() - 1;
    await supplychainInstance.confirmOrder(orderId, true, { from: accounts[1] });
    const order = await supplychainInstance.orders(orderId);
    globalOrderId = await supplychainInstance.nextOrderId() - 1;
    assert.equal(order.status.toString(), Supplychain.OrderStatus.CONFIRMED.toString(), "Order not confirmed correctly");
  });

  it("should allow a buyer to request transportation", async () => {
    const orderId = await supplychainInstance.nextOrderId() - 1;
    await supplychainInstance.requestTransportation(orderId, accounts[3], 100, { from: accounts[2] }); // accounts[4] as buyer, accounts[3] as transporter

    const order = await supplychainInstance.orders(orderId);
    assert.equal(order.status.toString(), Supplychain.OrderStatus.IN_TRANSIT.toString(), "Transportation was not requested correctly");
  });

  // Test Confirming Transportation Request
  it("should allow a transporter to confirm a transportation request", async () => {
    const orderId = await supplychainInstance.nextOrderId() - 1;
    await supplychainInstance.confirmDeliveryRequest(orderId, { from: accounts[3] }); // accounts[3] as transporter

    const order = await supplychainInstance.orders(orderId);
    assert.equal(order.status.toString(), Supplychain.OrderStatus.IN_TRANSIT.toString(), "Transportation request was not confirmed correctly");
  });

  // Test Confirming Pick Up
  it("should allow a transporter to confirm pick up", async () => {
    const orderId = await supplychainInstance.nextOrderId() - 1;
    const quantityPickedUp = 10;

    await supplychainInstance.confirmPickUp(orderId, quantityPickedUp, { from: accounts[3] }); // accounts[3] as transporter

    const order = await supplychainInstance.orders(orderId);
    assert.equal(order.status.toString(), Supplychain.OrderStatus.IN_TRANSIT.toString(), "Order status was not updated correctly after pick up");
  });

  // Test Confirming Delivery
  it("should allow a buyer to confirm delivery", async () => {
    const orderId = await supplychainInstance.nextOrderId() - 1;
    const earTagNumbers = [123, 124];

    await supplychainInstance.confirmDelivery(orderId, earTagNumbers, { from: accounts[2] }); 

    const order = await supplychainInstance.orders(orderId);
    assert.equal(order.status.toString(), Supplychain.OrderStatus.COMPLETED.toString(), "Delivery was not confirmed correctly");
  });

  // Performance Measurement for chooseRole Herder
it("should measure performance of chooseRole for Herder", async () => {
    const roleChoice = Supplychain.RoleChoice.Herder; 
    const account = accounts[4]; // Make sure this account hasn't chosen a role yet

    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.chooseRole(roleChoice, { from: account });
    
    const end = process.hrtime.bigint();

    const executionTime = (end - start) / BigInt(1000000);
    console.log("chooseRole Herder execution time: ", executionTime.toString(), "ms");

    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("chooseRole Herder Gas Used: ", receipt.gasUsed);
});

// Performance Measurement for chooseRole Slaughterhouse
it("should measure performance of chooseRole for Slaughterhouse", async () => {
    const roleChoice = Supplychain.RoleChoice.Slaughterhouse; 
    const account = accounts[5]; // Make sure this account hasn't chosen a role yet

    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.chooseRole(roleChoice, { from: account });
    const end = process.hrtime.bigint();

    const executionTime = (end - start) / BigInt(1000000);
    console.log("chooseRole Slaughterhouse execution time: ", executionTime.toString(), "ms");

    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("chooseRole Slaughterhouse Gas Used: ", receipt.gasUsed);
});
  
  // Performance Measurement for chooseRole
it("should measure performance of chooseRole", async () => {
    const roleChoice = Supplychain.RoleChoice.Transporter; // Example role choice
    const account = accounts[6]; // Example account, ensure it hasn't chosen a role yet
  
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.chooseRole(roleChoice, { from: account });
    const end = process.hrtime.bigint();
  
    const executionTime = (end - start) / BigInt(1000000);
    console.log("chooseRole execution time: ", executionTime.toString(), "ms");
  
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("chooseRole Gas Used: ", receipt.gasUsed);
  });

  // Performance Measurement for registerHerder
  it("should measure performance of registerHerder", async () => {
    const account = accounts[4]; // Choose an unused account
    if (!account) {
        throw new Error("Account for registering herder is undefined");
    }
    // Provide necessary parameters for registerHerder function
    const location = "Location D";
    const totalLivestock = 50;
    const pricePerKg = 20;
    const aimagTotalLivestock = 1000;
    const aimagPastureCarryingCapacity = 500;
    const aimagTotalHerderNumber = 10;
    // Ensure this account has not previously chosen a role or registered as a herder
    //await supplychainInstance.chooseRole(Supplychain.RoleChoice.Herder, { from: account });
    //await supplychainInstance.registerHerder(location, totalLivestock, pricePerKg, aimagTotalLivestock, aimagPastureCarryingCapacity, aimagTotalHerderNumber, { from: account });
    const start = process.hrtime.bigint();
    const txHash = await supplychainInstance.registerHerder(location, totalLivestock, pricePerKg, aimagTotalLivestock, aimagPastureCarryingCapacity, aimagTotalHerderNumber, { from: account });
    const end = process.hrtime.bigint();
    const receipt = await web3.eth.getTransactionReceipt(txHash.tx);
    console.log("registerHerder Gas Used: ", receipt.gasUsed);
    const executionTime = (end - start) / BigInt(1000000);
    console.log("registerHerder execution time: ", executionTime.toString(), "ms");
});
  
  // Performance Measurement for registerSlaughterhouse
it("should measure performance of registerSlaughterhouse", async () => {
    const account = accounts[5]; // Example account, ensure it hasn't registered as a slaughterhouse yet
    const location = "Slaughterhouse X";
    const pricePerKg = 30;
  
    //await supplychainInstance.chooseRole(Supplychain.RoleChoice.Slaughterhouse, { from: account }); // First choose Slaughterhouse role
  
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.registerSlaughterhouse(location, pricePerKg, { from: account });
    const end = process.hrtime.bigint();
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("registerSlaughterhouse Gas Used: ", receipt.gasUsed);
    const executionTime = (end - start) / BigInt(1000000);
    console.log("registerSlaughterhouse execution time: ", executionTime.toString(), "ms");
  });
  
  // Performance Measurement for registerTransporter
  it("should measure performance of registerTransporter", async () => {
    const account = accounts[6]; // Example account, ensure it hasn't registered as a transporter yet
    const location = "Transporter Base";
    const truckInfo = "Truck Model Y";
    const pricePerKm = 5;
    //await supplychainInstance.chooseRole(Supplychain.RoleChoice.Transporter, { from: account }); // First choose Transporter role

    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.registerTransporter(location, truckInfo, pricePerKm, { from: account });
    const end = process.hrtime.bigint();
  
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("registerTransporter Gas Used: ", receipt.gasUsed);
    const executionTime = (end - start) / BigInt(1000000);
    console.log("registerTransporter execution time: ", executionTime.toString(), "ms"); 
  });

  // Performance Measurement Tests
  it("should measure performance of placeOrder", async () => {
    const herderId = 1;
    const quantity = 10;
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.placeOrder(herderId, quantity, { from: accounts[5] });
    const end = process.hrtime.bigint();
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("placeOrder Gas Used: ", receipt.gasUsed);
    const executionTime = (end - start) / BigInt(1000000);
    console.log("placeOrder execution time: ", executionTime.toString(), "ms");
    globalOrderId = await supplychainInstance.nextOrderId() - 1;
  
  });

  // Performance Measurement for confirmOrder
it("should measure performance of confirmOrder", async () => {
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.confirmOrder(globalOrderId, true, { from: accounts[4] });
    const end = process.hrtime.bigint();
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("confirmOrder Gas Used: ", receipt.gasUsed);
    const executionTime = (end - start) / BigInt(1000000);
    console.log("confirmOrder execution time: ", executionTime.toString(), "ms");
  
    
  });
  
  // Performance Measurement for requestTransportation
  it("should measure performance of requestTransportation", async () => {
    const transporterAddress = accounts[6];
    const distance = 100;
  
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.requestTransportation(globalOrderId, transporterAddress, distance, { from: accounts[5] });
    const end = process.hrtime.bigint();
    const executionTime = (end - start) / BigInt(1000000);
    console.log("requestTransportation execution time: ", executionTime.toString(), "ms");
  
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("requestTransportation Gas Used: ", receipt.gasUsed);
  });
  
  // Performance Measurement for confirmTransportationRequest
  it("should measure performance of confirmTransportationRequest", async () => {
  
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.confirmTransportationRequest(globalOrderId, { from: accounts[6] });
    const end = process.hrtime.bigint();
    const executionTime = (end - start) / BigInt(1000000);
    console.log("confirmTransportationRequest execution time: ", executionTime.toString(), "ms");
  
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("confirmTransportationRequest Gas Used: ", receipt.gasUsed);
  });
  
  // Performance Measurement for confirmPickUp
  it("should measure performance of confirmPickUp", async () => {
    const quantityPickedUp = 10;
  
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.confirmPickUp(globalOrderId, quantityPickedUp, { from: accounts[6] });
    const end = process.hrtime.bigint();
    const executionTime = (end - start) / BigInt(1000000);
    console.log("confirmPickUp execution time: ", executionTime.toString(), "ms");
  
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("confirmPickUp Gas Used: ", receipt.gasUsed);
  });
  
  // Performance Measurement for confirmDelivery
  it("should measure performance of confirmDelivery", async () => {
    const earTagNumbers = [123, 124];
  
    const start = process.hrtime.bigint();
    const tx = await supplychainInstance.confirmDelivery(globalOrderId, earTagNumbers, { from: accounts[5] });
    const end = process.hrtime.bigint();
    const executionTime = (end - start) / BigInt(1000000);
    console.log("confirmDelivery execution time: ", executionTime.toString(), "ms");
  
    const receipt = await web3.eth.getTransactionReceipt(tx.tx);
    console.log("confirmDelivery Gas Used: ", receipt.gasUsed);
  });
  
});
