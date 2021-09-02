pragma solidity 0.5.3;

import "./Ownable.sol";
import "./Counter.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./ReentrancyGuard.sol";


contract Bileto is Ownable, ReentrancyGuard {
    using SafeMath for uint;
    using Counter_ for Counter_.Counter;
    using Address for address;
    using Address for address payable;

    enum StoreStatus {
        Created,   // 0
        Open,      // 1
        Suspended, // 2
        Closed     // 3
    }

    enum EventStatus {
        Created,        // 0
        SalesStarted,   // 1
        SalesSuspended, // 2
        SalesFinished,  // 3
        Completed,      // 4
        Settled,        // 5
        Cancelled       // 6
    }

    enum PurchaseStatus {
        Completed, // 0
        Cancelled, // 1
        Refunded,  // 2
        CheckedIn  // 3
    }

    struct Store {
        StoreStatus status;
        string name;
        uint settledBalance;
        uint excessBalance;
        uint refundableBalance;
        Counter_.Counter counterEvents;
        Counter_.Counter counterPurchases;
    }

    struct Event {
        EventStatus status;
        bytes32 externalId;
        address payable organizer;
        string name;
        uint storeIncentive;
        uint ticketPrice;
        uint ticketsOnSale;
        uint ticketsSold;
        uint ticketsLeft;
        uint ticketsCancelled;
        uint ticketsRefunded;
        uint ticketsCheckedIn;
        uint eventBalance;
        uint refundableBalance;
    }

    struct Purchase {
        PurchaseStatus status;
        bytes32 externalId;
        uint timestamp;
        address payable customer;
        bytes32 customerId;
        uint quantity;
        uint total;
        uint eventId;
    }

    Store private store;

    address[] private organizers;

    mapping(uint => Event) private events;

    mapping(address => uint[]) private organizerEvents;

    address[] private customers;

    mapping(uint => Purchase) private purchases;

    mapping(address => uint[]) private customerPurchases;


    event StoreOpen(address indexed _by);


    event StoreSuspended(address indexed _by);


    event StoreClosed(address indexed _by, uint _settlement, uint _excess);


    event EventCreated(uint indexed _id, bytes32 indexed _extId, address indexed _by);


    event EventSalesStarted(uint indexed _id, bytes32 indexed _extId, address indexed _by);


    event EventSalesSuspended(uint indexed _id, bytes32 indexed _extId, address indexed _by);


    event EventSalesFinished(uint indexed _id, bytes32 indexed _extId, address indexed _by);


    event EventCompleted(uint indexed _id, bytes32 indexed _extId, address indexed _by);


    event EventSettled(uint indexed _id, bytes32 indexed _extId, address indexed _by, uint _settlement);


    event EventCancelled(uint indexed _id, bytes32 indexed _extId, address indexed _by);


    event PurchaseCompleted(uint indexed _id, bytes32 indexed _extId, address indexed _by, uint _eventId);


    event PurchaseCancelled(uint indexed _id, bytes32 indexed _extId, address indexed _by, uint _eventId);


    event PurchaseRefunded(uint indexed _id, bytes32 indexed _extId, address indexed _by, uint _eventId);


    event CustomerCheckedIn(uint indexed _eventId, uint indexed _purchaseId, address indexed _by);

    modifier storeOpen() {
        require(store.status == StoreStatus.Open,
            "ERROR-001: ticket store must be open in order to proceed");
        _;
    }

    modifier validEventId(uint _eventId) {
        require(_eventId <= store.counterEvents.current,
            "ERROR-002: invalid event ID");
        _;
    }

    modifier validPurchaseId(uint _purchaseId) {
        require(_purchaseId <= store.counterPurchases.current,
            "ERROR-003: invalid purchase ID");
        _;
    }

    modifier onlyOrganizer(uint _eventId) {
        require(msg.sender == events[_eventId].organizer,
            "ERROR-004: must be triggered by event organizer in order to proceed");
        _;
    }

    modifier onlyOwnerOrOrganizer(uint _eventId) {
        require(isOwner() || msg.sender == events[_eventId].organizer,
            "ERROR-005: must be triggered by event organizer or store owner in order to proceed");
        _;
    }

    modifier purchaseCompleted(uint _purchaseId) {
        require(purchases[_purchaseId].status == PurchaseStatus.Completed,
            "ERROR-006: ticket purchase have to be completed in order to proceed");
        _;
    }

    /// @notice Initialize the ticket store and its respective owner.
    /// @dev store owner is set by the account who created the store
    constructor(string memory _name) public {
        require(bytes(_name).length != 0,
            "ERROR-007: store name must not be empty in order to proceed");
        store.name = _name;
        store.status = StoreStatus.Created;
    }

    /// @notice Fallback function.
    /// @notice Funds will be locked until store is closed, when owner will be able to withdraw them.
    function()
        external
        payable
    {
        require(msg.data.length == 0,
            "ERROR-008: only funds transfer (i.e. no data) accepted on fallback");
        store.excessBalance = store.excessBalance.add(msg.value);
    }


    function openStore()
        external
        nonReentrant
        onlyOwner
    {
        require(store.status == StoreStatus.Created
            || store.status == StoreStatus.Suspended,
            "ERROR-009: ticket store must be created or suspended in order to proceed");
        store.status = StoreStatus.Open;
        emit StoreOpen(msg.sender);
    }


    function suspendStore()
        external
        nonReentrant
        onlyOwner
        storeOpen
    {
        store.status = StoreStatus.Suspended;
        emit StoreSuspended(msg.sender);
    }


    function closeStore()
        external
        nonReentrant
        onlyOwner
    {
        require(store.status != StoreStatus.Closed,
            "ERROR-010: ticket store cannot be closed in order to proceed");
        // require(store.refundableBalance == 0,
        //     "ERROR-011: ticket store refundable balance must be zero in order to proceed");
        store.status = StoreStatus.Closed;
        uint _total = store.settledBalance.add(store.excessBalance);
        if (_total > 0) {
            owner().transfer(_total);
        }
        emit StoreClosed(msg.sender, store.settledBalance, store.excessBalance);
    }

    function createEvent(
        string calldata _externalId,
        address payable _organizer,
        string calldata _name,
        uint _storeIncentive,
        uint _ticketPrice,
        uint _ticketsOnSale
    )
        external
        nonReentrant
        onlyOwner
        storeOpen
        returns (uint eventId)
    {
        require(!_organizer.isContract(),
            "ERROR-012: organizer address must refer to an account (i.e. not a contract) in order to proceed");
        require(bytes(_externalId).length != 0,
            "ERROR-013: ticket event external ID must not be empty in order to proceed");
        require(bytes(_name).length != 0,
            "ERROR-014: ticket event name must not be empty in order to proceed");
        require(_storeIncentive >= 0
            && _storeIncentive <= 10000,
            "ERROR-015: store incentive must be between 0.00% (000) to 100.00% (10000) in order to proceed");
        require(_ticketsOnSale > 0,
            "ERROR-016: number of tickets available for sale cannot be zero in order to proceed");
        eventId = store.counterEvents.next();
        events[eventId].status = EventStatus.Created;
        events[eventId].externalId = keccak256(bytes(_externalId));
        events[eventId].organizer = _organizer;
        events[eventId].name = _name;
        events[eventId].storeIncentive = _storeIncentive;
        events[eventId].ticketPrice = _ticketPrice;
        events[eventId].ticketsOnSale = _ticketsOnSale;
        events[eventId].ticketsLeft = _ticketsOnSale;
        organizerEvents[_organizer].push(eventId);
        if (organizerEvents[_organizer].length == 1) {
            organizers.push(_organizer);
        }
        emit EventCreated(eventId, events[eventId].externalId, msg.sender);
        return (eventId);
    }

    function startTicketSales(uint _eventId)
        external
        nonReentrant
        storeOpen
        validEventId(_eventId)
        onlyOrganizer(_eventId)
    {
        require(events[_eventId].status == EventStatus.Created
            || events[_eventId].status == EventStatus.SalesSuspended,
            "ERROR-017: ticket event must be created or with sales suspended in order to proceed");
        events[_eventId].status = EventStatus.SalesStarted;
        emit EventSalesStarted(_eventId, events[_eventId].externalId, msg.sender);
    }

    function suspendTicketSales(uint _eventId)
        external
        nonReentrant
        storeOpen
        validEventId(_eventId)
        onlyOrganizer(_eventId)
    {
        require(events[_eventId].status == EventStatus.SalesStarted,
            "ERROR-018: event ticket sales must have started in order to proceed");
        events[_eventId].status = EventStatus.SalesSuspended;
        emit EventSalesSuspended(_eventId, events[_eventId].externalId, msg.sender);
    }

    function endTicketSales(uint _eventId)
        external
        nonReentrant
        storeOpen
        validEventId(_eventId)
        onlyOrganizer(_eventId)
    {
        require(events[_eventId].status == EventStatus.SalesStarted
            || events[_eventId].status == EventStatus.SalesSuspended,
            "ERROR-019: event ticket sales must have started or be suspended in order to proceed");
        events[_eventId].status = EventStatus.SalesFinished;
        emit EventSalesFinished(_eventId, events[_eventId].externalId, msg.sender);
    }


    function completeEvent(uint _eventId)
        external
        nonReentrant
        storeOpen
        validEventId(_eventId)
        onlyOrganizer(_eventId)
    {
        require(events[_eventId].status == EventStatus.SalesFinished,
            "ERROR-020: event ticket sales must have finished in order to proceed");
        events[_eventId].status = EventStatus.Completed;
        emit EventCompleted(_eventId, events[_eventId].externalId, msg.sender);
    }


    function settleEvent(uint _eventId)
        external
        nonReentrant
        storeOpen
        onlyOwner
    {
        require(events[_eventId].status == EventStatus.Completed,
            "ERROR-021: ticket event must have been completed in order to proceed");
        events[_eventId].status = EventStatus.Settled;
        uint _eventBalance = events[_eventId].eventBalance;
        uint _storeIncentive = events[_eventId].storeIncentive;
        uint _storeIncentiveBalance = _eventBalance.mul(_storeIncentive).div(10000);
        uint _settlement = _eventBalance.sub(_storeIncentiveBalance);
        store.settledBalance = store.settledBalance.add(_storeIncentiveBalance);
        if (_settlement > 0) {
            events[_eventId].organizer.transfer(_settlement);
        }
        emit EventSettled(_eventId, events[_eventId].externalId, msg.sender, _settlement);
    }

    function cancelEvent(uint _eventId)
        external
        nonReentrant
        storeOpen
        validEventId(_eventId)
        onlyOrganizer(_eventId)
    {
        require(events[_eventId].status == EventStatus.Created
            || events[_eventId].status == EventStatus.SalesStarted
            || events[_eventId].status == EventStatus.SalesSuspended
            || events[_eventId].status == EventStatus.SalesFinished,
            "ERROR-022: event must be created or have its ticket sales not completed in order to proceed");
        events[_eventId].status = EventStatus.Cancelled;
        emit EventCancelled(_eventId, events[_eventId].externalId, msg.sender);
    }

    function purchaseTickets(
        uint _eventId,
        uint _quantity,
        string calldata _externalId,
        uint _timestamp,
        string calldata _customerId
    )
        external
        payable
        nonReentrant
        storeOpen
        validEventId(_eventId)
        returns (uint purchaseId)
    {
        require(events[_eventId].status == EventStatus.SalesStarted,
            "ERROR-023: event ticket sales have to had started in order to proceed");
        require(!msg.sender.isContract(),
            "ERROR-024: customer address must refer to an account (i.e. not a contract) in order to proceed");
        require(_quantity > 0,
            "ERROR-025: quantity of tickets must be greater than zero in order to proceed");
        require(_quantity <= events[_eventId].ticketsLeft,
            "ERROR-026: not enough tickets left for the quantity requested. please change quantity in order to proceed");
        require(bytes(_externalId).length != 0,
            "ERROR-027: purchase external ID must not be empty in order to proceed");
        require(_timestamp > 0,
            "ERROR-028: purchase date must be provided (not zero)");
        require(bytes(_customerId).length != 0,
            "ERROR-029: customer ID cannot be empty in order to proceed");
        require(msg.value == _quantity.mul(events[_eventId].ticketPrice),
            "ERROR-030: customer funds sent on transaction must be equal to purchase total in order to proceed");
        purchaseId = store.counterPurchases.next();
        purchases[purchaseId].status = PurchaseStatus.Completed;
        purchases[purchaseId].eventId = _eventId;
        purchases[purchaseId].quantity = _quantity;
        purchases[purchaseId].externalId = keccak256(bytes(_externalId));
        purchases[purchaseId].timestamp = _timestamp;
        purchases[purchaseId].customer = msg.sender;
        purchases[purchaseId].customerId = keccak256(bytes(_customerId));
        purchases[purchaseId].total = _quantity.mul(events[_eventId].ticketPrice);
        events[_eventId].ticketsSold = events[_eventId].ticketsSold.add(_quantity);
        events[_eventId].ticketsLeft = events[_eventId].ticketsLeft.sub(_quantity);
        events[_eventId].eventBalance = events[_eventId].eventBalance.add(purchases[purchaseId].total);
        customerPurchases[msg.sender].push(purchaseId);
        if (customerPurchases[msg.sender].length == 1) {
            customers.push(msg.sender);
        }
        emit PurchaseCompleted(purchaseId, purchases[purchaseId].externalId, msg.sender, _eventId);
        return (purchaseId);
    }

    function cancelPurchase(
        uint _purchaseId,
        string calldata _externalId,
        string calldata _customerId
    )
        external
        nonReentrant
        validPurchaseId(_purchaseId)
        purchaseCompleted(_purchaseId)
    {
        uint _eventId = purchases[_purchaseId].eventId;
        require((store.status == StoreStatus.Open || store.status == StoreStatus.Closed)
            && (events[_eventId].status == EventStatus.SalesStarted
                || events[_eventId].status == EventStatus.SalesSuspended
                || events[_eventId].status == EventStatus.SalesFinished
                || events[_eventId].status == EventStatus.Cancelled),
            "ERROR-031: event status must allow cancellation in order to proceed");
        require(msg.sender == purchases[_purchaseId].customer,
            "ERROR-032: purchase cancellation must be initiated by purchase customer in order to proceed");
        require(keccak256(bytes(_customerId)) == purchases[_purchaseId].customerId,
            "ERROR-033: hashed customer ID must match with stored one in order to proceed");
        require(keccak256(bytes(_externalId)) == purchases[_purchaseId].externalId,
            "ERROR-034: hashed purchase external ID must match with stored one in order to proceed");
        purchases[_purchaseId].status = PurchaseStatus.Cancelled;
        events[_eventId].ticketsCancelled = events[_eventId].ticketsCancelled.add(purchases[_purchaseId].quantity);
        events[_eventId].ticketsLeft = events[_eventId].ticketsLeft.add(purchases[_purchaseId].quantity);
        events[_eventId].eventBalance = events[_eventId].eventBalance.sub(purchases[_purchaseId].total);
        events[_eventId].refundableBalance = events[_eventId].refundableBalance.add(purchases[_purchaseId].total);
        store.refundableBalance = store.refundableBalance.add(purchases[_purchaseId].total);
        emit PurchaseCancelled(_purchaseId, purchases[_purchaseId].externalId, msg.sender, _eventId);
    }

    function refundPurchase(uint _eventId, uint _purchaseId)
        external
        nonReentrant
        validEventId(_eventId)
        onlyOrganizer(_eventId)
        validPurchaseId(_purchaseId)
    {
        require((store.status == StoreStatus.Open || store.status == StoreStatus.Closed)
            && purchases[_purchaseId].status == PurchaseStatus.Cancelled,
            "ERROR-035: ticket purchase have to be cancelled in order to proceed");
        purchases[_purchaseId].status = PurchaseStatus.Refunded;
        events[_eventId].ticketsRefunded = events[_eventId].ticketsRefunded.add(purchases[_purchaseId].quantity);
        events[_eventId].refundableBalance = events[_eventId].refundableBalance.sub(purchases[_purchaseId].total);
        store.refundableBalance = store.refundableBalance.sub(purchases[_purchaseId].total);
        purchases[_purchaseId].customer.transfer(purchases[_purchaseId].total);
        emit PurchaseRefunded(_purchaseId, purchases[_purchaseId].externalId, msg.sender, _eventId);
    }

    function checkIn(uint _purchaseId)
        external
        nonReentrant
        storeOpen
        validPurchaseId(_purchaseId)
        purchaseCompleted(_purchaseId)
    {
        uint _eventId = purchases[_purchaseId].eventId;
        require(events[_eventId].status == EventStatus.SalesStarted
            || events[_eventId].status == EventStatus.SalesSuspended
            || events[_eventId].status == EventStatus.SalesFinished,
            "ERROR-036: event ticket sales should have been started/suspended/finished in order to proceed");
        require(msg.sender == purchases[_purchaseId].customer,
            "ERROR-037: check-in request must be initiated from customer own account in order to proceed");
        purchases[_purchaseId].status = PurchaseStatus.CheckedIn;
        emit CustomerCheckedIn(_eventId, _purchaseId, msg.sender);
    }

    /// @notice Fetch store basic information.
    /// @notice Basic info are those static attributes set when store is created.
    /// @return Store attributes.
    function fetchStoreInfo()
        external
        view
        returns (
            address storeOwner,
            uint storeStatus,
            string memory storeName,
            uint storeSettledBalance,
            uint storeExcessBalance,
            uint storeRefundableBalance,
            uint storeCounterEvents,
            uint storeCounterPurchases
        )
    {
        storeOwner = owner();
        storeStatus = uint(store.status);
        storeName = store.name;
        storeSettledBalance = store.settledBalance;
        storeExcessBalance = store.excessBalance;
        storeRefundableBalance = store.refundableBalance;
        storeCounterEvents = store.counterEvents.current;
        storeCounterPurchases = store.counterPurchases.current;
    }

    /// @notice Fetch event basic information.
    /// @notice Basic info are those static attributes set when event is created.
    /// @param _eventId event internal ID
    /// @return Event status, external ID, organizer address, event name, store incentive, ticket price and quantity of tickets for sale.
    function fetchEventInfo(uint _eventId)
        external
        view
        validEventId(_eventId)
        returns (
            uint eventStatus,
            bytes32 eventExternalId,
            address eventOrganizer,
            string memory eventName,
            uint eventStoreIncentive,
            uint eventTicketPrice,
            uint eventTicketsOnSale
        )
    {
        eventStatus = uint(events[_eventId].status);
        eventExternalId = events[_eventId].externalId;
        eventOrganizer = events[_eventId].organizer;
        eventName = events[_eventId].name;
        eventStoreIncentive = events[_eventId].storeIncentive;
        eventTicketPrice = events[_eventId].ticketPrice;
        eventTicketsOnSale = events[_eventId].ticketsOnSale;
    }

    /// @notice Fetch event sales information.
    /// @notice Sales info are those attributes which change upon each purchase/cancellation transaction.
    /// @param _eventId event internal ID
    /// @return Event status, tickets sold/left/cancelled/refunded/checked-in, event total/refundable balances.
    function fetchEventSalesInfo(uint _eventId)
        external
        view
        validEventId(_eventId)
        returns (
            uint eventStatus,
            uint eventTicketsSold,
            uint eventTicketsLeft,
            uint eventTicketsCancelled,
            uint eventTicketsRefunded,
            uint eventTicketsCheckedIn,
            uint eventBalance,
            uint eventRefundableBalance
        )
    {
        eventStatus = uint(events[_eventId].status);
        eventTicketsSold = events[_eventId].ticketsSold;
        eventTicketsLeft = events[_eventId].ticketsLeft;
        eventTicketsCancelled = events[_eventId].ticketsCancelled;
        eventTicketsRefunded = events[_eventId].ticketsRefunded;
        eventTicketsCheckedIn = events[_eventId].ticketsCheckedIn;
        eventBalance = events[_eventId].eventBalance;
        eventRefundableBalance = events[_eventId].refundableBalance;
    }

    /// @notice Fetch purchase information.
    /// @param _purchaseId purchase internal ID
    /// @return Purchase status, external ID, timestamp, customer address/ID, quantity of tickets, total and event ID.
    function fetchPurchaseInfo(uint _purchaseId)
        external
        view
        validPurchaseId(_purchaseId)
        returns (
            uint purchaseStatus,
            bytes32 purchaseExternalId,
            uint purchaseTimestamp,
            address purchaseCustomer,
            bytes32 purchaseCustomerId,
            uint purchaseQuantity,
            uint purchaseTotal,
            uint purchaseEventId
        )
    {
        require(isOwner()
            || msg.sender == purchases[_purchaseId].customer
            || msg.sender == events[purchases[_purchaseId].eventId].organizer,
            "ERROR-038: must be triggered by customer, event organizer or store owner in order to proceed");
        purchaseStatus = uint(purchases[_purchaseId].status);
        purchaseExternalId = purchases[_purchaseId].externalId;
        purchaseTimestamp = purchases[_purchaseId].timestamp;
        purchaseCustomer = purchases[_purchaseId].customer;
        purchaseCustomerId = purchases[_purchaseId].customerId;
        purchaseQuantity = purchases[_purchaseId].quantity;
        purchaseTotal = purchases[_purchaseId].total;
        purchaseEventId = purchases[_purchaseId].eventId;
    }

    /// @notice Get number of events created by an organizer.
    /// @param _organizer organizer address
    /// @return Count of events. Zero in case organizer hasn't yet created any events.
    function getCountOrganizerEvents(address _organizer)
        external
        view
        returns (uint countEvents)
    {
        // require(msg.sender == owner() || msg.sender == _organizer,
        //     "ERROR-039: not allowed to retrieve such information");
        countEvents = organizerEvents[_organizer].length;
        return countEvents;
    }

    /// @notice Get ID of an event, according to its position on list of events created by an organizer.
    /// @param _organizer organizer address
    /// @param _index position in the list. Starting from zero
    /// @return  Event ID
    function getEventIdByIndex(address _organizer, uint _index)
        external
        view
        returns (uint eventId)
    {
        require(organizerEvents[_organizer].length != 0,
            "ERROR-040: organizer has not created events yet");
        require(_index < organizerEvents[_organizer].length,
            "ERROR-041: invalid index (organizerEvents)");
        eventId = organizerEvents[_organizer][_index];
        return eventId;
    }

    /// @notice Get number of ticket purchases performed by a customer.
    /// @param _customer customer address
    /// @return Count of purchases. Zero in case customer hasn't yet purchased any tickets.
    function getCountCustomerPurchases(address _customer)
        external
        view
        returns (uint countPurchases)
    {
        // require(msg.sender == owner() || msg.sender == _customer,
        //     "ERROR-042: not allowed to retrieve such information");
        countPurchases = customerPurchases[_customer].length;
        return countPurchases;
    }

    /// @notice Get ID of a purchase, according to its position on list of purchases performed by a customer.
    /// @param _customer customer address
    /// @param _index position in the list. Starting from zero
    /// @return Purchase ID
    function getPurchaseIdByIndex(address _customer, uint _index)
        external
        view
        returns (uint purchaseId)
    {
        require(customerPurchases[_customer].length != 0,
            "ERROR-043: customer has not purchased tickets yet");
        require(_index < customerPurchases[_customer].length,
            "ERROR-044: invalid index (customerPurchases)");
        purchaseId = customerPurchases[_customer][_index];
        return purchaseId;
    }

    /// @notice Get number of organizers who dealt with the store.
    /// @return Count of organizers. Zero in case of none yet.
    function getCountOrganizers()
        external
        view
        returns (uint countOrganizers)
    {
        countOrganizers = organizers.length;
        return countOrganizers;
    }

    /// @notice Get address of an organizer, according to its position on list of organizers who delt with the store.
    /// @param _index position in the list. Starting from zero
    /// @return Organizer address
    function getOrganizerByIndex(uint _index)
        external
        view
        returns (address organizer)
    {
        require(_index < organizers.length,
            "ERROR-045: invalid index (organizers)");
        organizer = organizers[_index];
        return organizer;
    }

    /// @notice Get number of customers who purchased tickets from the store.
    /// @return Count of customers. Zero in case of none yet.
    function getCountCustomers()
        external
        view
        returns (uint countCustomers)
    {
        countCustomers = customers.length;
        return countCustomers;
    }

    /// @notice Get address of an customer, according to its position on list of customers who purchased from the store.
    /// @param _index position in the list. Starting from zero
    /// @return Customer address
    function getCustomerByIndex(uint _index)
        external
        view
        returns (address customer)
    {
        require(_index < customers.length,
            "ERROR-046: invalid index (customers)");
        customer = customers[_index];
        return customer;
    }

    /// @notice Get role of an account in relation to the store.
    /// @param _account address of the account to be checked
    /// @return True or False for each of the possible roles
    function getAccountRole(address _account)
        external
        view
        returns (bool accountIsOwner, bool accountIsOrganizer, bool accountIsCustomer)
    {
        accountIsOwner = _account == owner();
        accountIsOrganizer = organizerEvents[_account].length > 0;
        accountIsCustomer = customerPurchases[_account].length > 0;
    }

}
