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
        message: vector<u8>,
        name: String
    }

    public struct RequestID has store, drop, copy {
        name: String,
        id: u32
    }


    public struct SendReceive has copy, store, drop {
        action: vector<u8>,
        amount: u64,
        message: vector<u8>,
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
        message: vector<u8>
    }

    public struct EventOwnershipRevoked has copy, drop {
        notification: vector<u8>
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

    // public entry fun update_user_name(sui_pay: &mut SuiPay, old_name: String, new_name: String, ctx: &mut TxContext){
    //     assert!(!user_exists(sui_pay, new_name), EUserAlreadyExists);
    //     let mut user = get_user(sui_pay, old_name);
    //     let old_name_copy = user.username.name;
    //     user.username.name = new_name;
    //     vec_map::remove(&mut sui_pay.accounts, &old_name);
    //     vec_map::insert(&mut sui_pay.accounts, new_name, user);
    //     event::emit(
    //         EventUserNameUpdated {
    //             old_name: old_name_copy,
    //             new_name,
    //             owner: ctx.sender()
    //         }
    //     );
    // }


    public entry fun add_user(name: String, owner: address, sui_pay: &mut SuiPay, img_url: vector<u8>, ctx: &mut TxContext) {
        assert!(!user_exists(sui_pay, name), EUserAlreadyExists);
        assert!(!vec_map::contains(&sui_pay.owner_map, &owner), EUserAlreadyExists);
        let sender = ctx.sender();
        let user = User {
            id: object::new(ctx),
            username: Username {
                name,
                owner
            },
            listAddress: vector::empty<address>(),
            requests: vec_map::empty<u32, Request>(),
            balance: balance::zero(),
            request_ids: vector::empty<RequestID>(),
            history: vector::empty<SendReceive>(),
            img_url: url::new_unsafe_from_bytes(img_url),
        };
        vec_map::insert(&mut sui_pay.accounts, name, user);
        vec_map::insert(&mut sui_pay.owner_map, owner, true);
        event::emit(
            EventUserAdded {
                name: name,
                owner: owner,
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
        //  coin::destroy_zero(split_coin);
          event::emit(
            EventDepositMade {
                name,
                amount
             }
           );
    }

     public entry fun create_request(sui_pay: &mut SuiPay, name: String, message: vector<u8>, amount: u64, requestor: String, rnd: &Random, ctx: &mut TxContext) {
        let mut generator = new_generator(rnd, ctx);
        let id = generate_u32(&mut generator);
        let address_requestor = get_user_address(sui_pay, requestor);
        let request = Request {
            name_requestor: name,
            address_requestor,
            amount,
            message,
            name
        };
        let request_id = RequestID{
            name,
            id
        };
        let mut user = vec_map::get_mut(&mut sui_pay.accounts, &name);
        vec_map::insert(&mut user.requests, id, request);
        user.request_ids.push_back(request_id);
        event::emit(
            EventPaymentRequestCreated {
                requestor,
                amount,
                address: address_requestor,
                name,
                id
            }
        )
    }


    public entry fun pay_request(
        sui_pay: &mut SuiPay, 
        name: String,
        request_id: u32, 
        coin: &mut Coin<SUI>, 
        ctx: &mut TxContext
    ) {
        let sender_address = ctx.sender();
        let (receiver, address_requestor, payment_amount, message, sender_name) = handle_user_request(sui_pay, name, request_id);
        handle_requestor_payment(sui_pay, receiver, address_requestor, payment_amount, coin, sender_name, message, sender_address, ctx);
            event::emit(EventPaymentMade { 
                receiver, 
                amount: payment_amount, 
                message 
            });
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


    fun handle_user_request(
        sui_pay: &mut SuiPay, 
        name: String, 
        request_id: u32
    ): (String, address, u64, vector<u8>, String) {
        let mut user = get_user(sui_pay, name);
       assert!(vec_map::contains(&user.requests, &request_id), ERequestNotFound);
        let request = vec_map::get_mut(&mut user.requests, &request_id);
        let sender_name = user.username.name;
        let receiver = request.name_requestor;
        let address_requestor = request.address_requestor;
        let payment_amount = request.amount;
        let message = request.message;
        let sender_entry = SendReceive {
            action: b"-", 
            amount: payment_amount, 
            message, 
            otherPartyAddress: address_requestor, 
            otherPartyName: receiver
        };
        user.history.push_back(sender_entry);
        vec_map::remove(&mut user.requests, &request_id);
        let (found, index) = vector::index_of(&user.request_ids, &RequestID{ name, id: request_id});
            if(found){
            vector::remove(&mut user.request_ids, index);
            };

        (receiver, address_requestor, payment_amount, message, sender_name)
    }

   fun handle_requestor_payment(
        sui_pay: &mut SuiPay, 
        receiver: String, 
        address_requestor: address, 
        payment_amount: u64, 
        coin: &mut Coin<SUI>,
        sender_name: String,
        message: vector<u8>,
        sender_address: address,
        ctx: &mut TxContext
    ) {
        let mut requestor = get_user(sui_pay, receiver);
        assert!(coin::value(coin) >= payment_amount, EInsufficientBalance);
        pay::split_and_transfer(coin, payment_amount, address_requestor, ctx);
        let receive_entry = SendReceive {
            action: b"+", 
            amount: payment_amount, 
            message, 
            otherPartyAddress: sender_address, 
            otherPartyName: sender_name
        };
        requestor.history.push_back(receive_entry);
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