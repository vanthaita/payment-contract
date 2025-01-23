module suipay::suipay {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::vec_map::{Self, VecMap, contains, insert};
    use sui::coin::{Self, Coin, value, split, destroy_zero};
    use sui::balance::{Self, Balance,join, split as balance_split};
    use sui::pay;
    use sui::sui::SUI;
    use sui::event;
    use sui::random::{Self, Random, RandomGenerator, new_generator, generate_u32};
    use std::string::{Self, String};
    use sui::url::{Self, Url};
    use sui::clock::{Self, Clock};
    // Error codes
    const EUserAlreadyExists: u64 = 1;
    const EUserNotFound: u64 = 2;
    const ERequestNotFound: u64 = 3;
    const EInsufficientBalance: u64 = 4;
    const EAddressAlreadyLinked: u64 = 5;
    const EAddressNotLinked: u64 = 6;
    const EInvalidDepositAmount: u64 = 7;
    const ENotOwner: u64 = 8;
    const EInvalidUserOwner: u64 = 9;
    const EInvalidStatus: u64 = 12;

    public struct Username has store {
        name: String,
        owner: address,
    }

    public struct User has key, store {
        id: UID,
        username: Username,
        listAddress: vector<address>,
        requests: VecMap<u32, Request>,
        balance: Balance<SUI>,
        request_ids: vector<RequestID>,
        history: vector<SendReceive>,
        img_url: Url,
    }
    


    public struct Request has store, drop, copy {
        name_requestor: String,
        address_requestor: address,
        amount: u64,
        message: String,
        name: String
    }

    public struct RequestID has store, drop, copy {
        name: String,
        id: u32
    }


    public struct SendReceive has copy, store, drop {
        action: vector<u8>,
        amount: u64,
        message: String,
        otherPartyAddress: address,
        otherPartyName: String
    }

    public struct SuiPay has key, store {
        id: UID,
        accounts: VecMap<String, User>,
        owner_map: VecMap<address, bool>,
    }

    public struct EventUserAdded has copy, drop {
        name: String,
        owner: address,
    }

     public struct EventUserNameUpdated has copy, drop {
        old_name: String,
        new_name: String,
        owner: address,
    }

    public struct EventPaymentRequestCreated has copy, drop {
        requestor: String,
        amount: u64,
        address: address,
        name: String,
        id: u32
    }

    public struct EventPaymentMade has copy, drop {
        receiver: String,
        amount: u64,
        message: String
    }

    public struct EventOwnershipRevoked has copy, drop {
        notification: String
    }

    public struct EventWithDrawal has copy, drop {
        owner: String,
        amount: u64
    }

    public struct EventAddressAdded has copy, drop {
        name: String,
        address: address,
    }

    public struct EventAddressRemoved has copy, drop {
        name: String,
        address: address
    }
    
    public struct EventRequestCanceled has copy, drop {
        name: String,
        request_id: u32
    }
    
    public struct EventDepositMade has copy, drop {
        name: String,
        amount: u64
    }
    
    fun init(ctx: &mut TxContext) {
        let accounts= vec_map::empty<String, User>();
          let owner_map= vec_map::empty<address, bool>();
        let sui_pay = SuiPay {
            id: object::new(ctx),
            accounts,
            owner_map
        };
        let sender = ctx.sender();
        transfer::share_object(sui_pay);
    } 

    public entry fun add_user(name: String, sui_pay: &mut SuiPay, img_url: vector<u8>, ctx: &mut TxContext) {
        assert!(!user_exists(sui_pay, name), EUserAlreadyExists);
        let sender = ctx.sender();
        assert!(!vec_map::contains(&sui_pay.owner_map, &sender), EUserAlreadyExists);
        let user = User {
            id: object::new(ctx),
            username: Username {
                name,
                owner: sender
            },
            listAddress: vector::empty<address>(),
            requests: vec_map::empty<u32, Request>(),
            balance: balance::zero(),
            request_ids: vector::empty<RequestID>(),
            history: vector::empty<SendReceive>(),
            img_url: url::new_unsafe_from_bytes(img_url),
        };
        vec_map::insert(&mut sui_pay.accounts, name, user);
        vec_map::insert(&mut sui_pay.owner_map, sender, true);
        event::emit(
            EventUserAdded {
                name: name,
                owner: sender,
            }
        );
    }
    public entry fun deposit(sui_pay: &mut SuiPay, name: String, coin: &mut Coin<SUI>, amount: u64, ctx: &mut TxContext) {
        assert!(amount > 0, EInvalidDepositAmount);
        let sender = ctx.sender();
        let mut user = get_user(sui_pay, name);
        assert!(user.username.owner == sender, ENotOwner);
        assert!(coin::value(coin) >= amount, EInsufficientBalance);
        let split_balance = balance_split(coin::balance_mut(coin), amount);
        balance::join(&mut user.balance, split_balance);
        event::emit(
            EventDepositMade {
                name,
                amount
            }
        );
    }

    public entry fun create_request(
        sui_pay: &mut SuiPay,
        request_receiver_name: String,
        request_message: String,
        request_amount: u64,
        request_initiator_name: String,
        rnd: &Random,
        ctx: &mut TxContext
    ) {
        let mut generator = new_generator(rnd, ctx);
        let request_id = generate_u32(&mut generator);
        let request_initiator_address = get_user_address(sui_pay, request_initiator_name);

        let request = Request {
            name_requestor: request_initiator_name,
            address_requestor: request_initiator_address,
            amount: request_amount,
            message: request_message,
            name: request_receiver_name
        };
        let request_id_struct = RequestID{
            name: request_receiver_name,
            id: request_id
        };

        let mut user = vec_map::get_mut(&mut sui_pay.accounts, &request_receiver_name);
        vec_map::insert(&mut user.requests, request_id, request);
        user.request_ids.push_back(request_id_struct);
        event::emit(
            EventPaymentRequestCreated {
                requestor: request_initiator_name,
                amount: request_amount,
                address: request_initiator_address,
                name: request_receiver_name,
                id: request_id
            }
        )
    }

    
    
    public entry fun cancel_request(sui_pay: &mut SuiPay, name: String, request_id: u32) {
       let mut user = get_user(sui_pay, name);
       assert!(vec_map::contains(&user.requests, &request_id), ERequestNotFound);
        vec_map::remove(&mut user.requests, &request_id);
        let (found, index) = vector::index_of(&user.request_ids, &RequestID{ name, id: request_id});
        if(found){
          vector::remove(&mut user.request_ids, index);
           event::emit(
                EventRequestCanceled {
                    name,
                    request_id
                }
            )
        }
    }


    public entry fun pay_request(
        sui_pay: &mut SuiPay,
        payer_name: String, 
        request_id: u32,
        ctx: &mut TxContext
    ) {
        let payer_address = ctx.sender();
        let (receiver_name, receiver_address, payment_amount, message, payer_name_from_request) = 
            handle_user_request(sui_pay, payer_name, request_id); 
        handle_requestor_payment_balance(
            sui_pay, 
            receiver_name, 
            receiver_address, 
            payment_amount, 
            payer_name,
            message, 
            payer_address, 
            ctx
        );
        event::emit(EventPaymentMade {
            receiver: receiver_name, 
            amount: payment_amount,
            message
        });
    }
    
    fun handle_user_request(
        sui_pay: &mut SuiPay, 
        payer_name: String, 
        request_id: u32
    ): (String, address, u64, String, String) {
        let mut payer = get_user(sui_pay, payer_name); 
        assert!(vec_map::contains(&payer.requests, &request_id), ERequestNotFound);
        let request = vec_map::get_mut(&mut payer.requests, &request_id);
        let payer_name_from_request = payer.username.name;
        let receiver_name = request.name_requestor; 
        let receiver_address = request.address_requestor; 
        let payment_amount = request.amount;
        let message = request.message;
        let payer_entry = SendReceive {
            action: b"-",
            amount: payment_amount,
            message,
            otherPartyAddress: receiver_address, 
            otherPartyName: receiver_name 
        };
        payer.history.push_back(payer_entry);
        vec_map::remove(&mut payer.requests, &request_id); 
        let (found, index) = vector::index_of(&payer.request_ids, &RequestID{ name: payer_name, id: request_id});
        if(found){
             vector::remove(&mut payer.request_ids, index);
        };
        (receiver_name, receiver_address, payment_amount, message, payer_name_from_request) 
    }

    
    fun handle_requestor_payment_balance(
        sui_pay: &mut SuiPay,
        receiver_name: String,
        receiver_address: address,
        payment_amount: u64,
        payer_name: String,
        message: String,
        payer_address: address,
        ctx: &mut TxContext
    ) {
        let receiver_balance_before = {
            let receiver = get_user(sui_pay, receiver_name);
            balance::value(&receiver.balance)
        };

        let payer_balance = {
            let mut payer = get_user(sui_pay, payer_name);
            assert!(balance::value(&payer.balance) >= payment_amount, EInsufficientBalance);
            balance::split(&mut payer.balance, payment_amount)
        };

        let mut receiver = get_user(sui_pay, receiver_name);
        balance::join(&mut receiver.balance, payer_balance);
        let receive_entry = SendReceive {
            action: b"+",
            amount: payment_amount,
            message,
            otherPartyAddress: payer_address,
            otherPartyName: payer_name
        };
        receiver.history.push_back(receive_entry);
    }

    public entry fun add_linked_address(sui_pay: &mut SuiPay, name: String, address: address, _ctx: &mut TxContext) {
        let mut user = get_user(sui_pay, name);
        assert!(!vector::contains(&user.listAddress, &address), EAddressAlreadyLinked);
        user.listAddress.push_back(address);
        event::emit(
            EventAddressAdded {
               name,
               address
            }
        );
    }

    public entry fun remove_linked_address(sui_pay: &mut SuiPay, name: String, address: address, _ctx: &mut TxContext) {
        let mut user = get_user(sui_pay, name);
        let (found, index) = vector::index_of(&user.listAddress, &address);
        assert!(found, EAddressNotLinked);
        vector::remove(&mut user.listAddress, index);
          event::emit(
            EventAddressRemoved {
                name,
                address
            }
        );
    }

    public entry fun withdraw(sui_pay: &mut SuiPay, name: String, amount: u64,  ctx: &mut TxContext) {
        let sender = ctx.sender();
        let mut user = get_user(sui_pay, name);
        assert!(balance::value(&user.balance) >= amount, EInsufficientBalance);
        assert!(user.username.owner == sender, ENotOwner);
        let cash = coin::take(&mut user.balance, amount, ctx);
        transfer::public_transfer(cash, sender);
        user.history.push_back(SendReceive {
            action: b"withdraw",
            amount,
            message: string::utf8(b"Withdrawal processed"),
            otherPartyAddress: sender,
            otherPartyName: name
        });
            event::emit(
                EventWithDrawal {
                    owner: name,
                    amount
            }
        );
    }

    public fun get_requests(name: String, sui_pay: &mut SuiPay, _ctx: &mut TxContext) : vector<RequestID> {
        let mut user = get_user(sui_pay, name);
        user.request_ids
    }
    
    public fun get_request_detail(name: String, sui_pay: &mut SuiPay, id: u32, _ctx: &mut TxContext): Request{
         let mut user = get_user(sui_pay, name);
         assert!(vec_map::contains(&user.requests, &id), ERequestNotFound);
        *vec_map::get_mut(&mut user.requests, &id)
    }
    
    public fun get_linked_addresses(name: String, sui_pay: &mut SuiPay, _ctx: &mut TxContext): vector<address> {
       let  user = get_user(sui_pay, name);
       user.listAddress
    }

    public fun get_receives(name: String, sui_pay: &mut SuiPay,ctx: &mut TxContext) : vector<SendReceive> {
        let mut user = get_user(sui_pay, name);
       let receives = user.history;
        receives
    }
     
    public fun get_filtered_history(
        name: String,
        sui_pay: &mut SuiPay,
        action: vector<u8>
    ): vector<SendReceive> {
        let mut user = get_user(sui_pay, name);
        let mut filtered_history = vector::empty<SendReceive>();
        let mut i = 0;
        let len = vector::length(&user.history);
         while (i < len) {
            let entry = vector::borrow(&user.history, i);
            if (&entry.action == &action) {
                vector::push_back(&mut filtered_history, *entry);
            };
            i = i + 1;
        };
        filtered_history
    }



    
    public fun get_all_history(name: String, sui_pay: &mut SuiPay,ctx: &mut TxContext) : vector<SendReceive> {
        let mut user = get_user(sui_pay, name);
        user.history
    }
     
    // public fun get_user_detail(name: String, sui_pay: &mut SuiPay, _ctx: &mut TxContext): &User{
    //     let mut user = get_user(sui_pay, name);
    //     *user
    // }

    fun get_user(sui_pay: &mut SuiPay, name: String): &mut User {
        assert!(user_exists(sui_pay, name), EUserNotFound);
        vec_map::get_mut(&mut sui_pay.accounts, &name)
    }

    public fun user_exists(sui_pay: &SuiPay, name: String): bool {
        vec_map::contains(&sui_pay.accounts, &name)
    }
    
    fun get_user_address(sui_pay: &mut SuiPay, name: String): address {
         let user = get_user(sui_pay, name);
        user.username.owner
    }
     
    fun user_owner_address(sui_pay: &mut SuiPay, owner: address): bool {
       vec_map::contains(&sui_pay.owner_map, &owner)
    }

    
}

 