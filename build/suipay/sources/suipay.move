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
    const EPaymentIntentNotFound: u64 = 10;
    const EPaymentIntentAlreadyPaid: u64 = 11;
    const EInvalidStatus: u64 = 12;
    const EConditionalEscrowNotFound: u64 = 13;
    const EConditionalEscrowAlreadyFulfilled: u64 = 14;
    const EConditionalEscrowExpired: u64 = 15;

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
        payment_intents: VecMap<u32, PaymentIntent>,
        payment_intent_ids: vector<PaymentIntentID>,
        conditional_escrows: VecMap<u32, ConditionalEscrow>,
        conditional_escrow_ids: vector<ConditionalEscrowID>
    }
    
    public struct ConditionalEscrow has store, drop, copy {
        escrow_id: u32,
        buyer_name: String,
        seller_name: String,
        amount: u64,
        condition_price: u64, //1 SUI = x USD ( x * 10^8 )
        status: u8, // 0: pending, 1: fulfilled, 2: canceled
        token: String, // SUI
        created_at: u64,
        metadata: vector<u8>,
        expiry: u64,
    }
     
    public struct ConditionalEscrowID has store, drop, copy {
        escrow_id: u32,
    }


    public struct PaymentIntent has store, drop, copy {
        payment_intent_id: u32,
        merchant_name: String,
        amount: u64,
        currency: String, // SUI
        customer_address: address,
        status: u8, // 0: pending, 1: paid, 2: refunded, 3: canceled
        timestamp: u64,
        metadata: vector<u8>,
    }

    public struct PaymentIntentID has store, drop, copy {
        payment_intent_id: u32
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
    
    public struct EventPaymentIntentCreated has copy, drop {
        payment_intent_id: u32,
        merchant_name: String,
        amount: u64
    }
     public struct EventPaymentIntentPaid has copy, drop {
        payment_intent_id: u32,
        merchant_name: String,
        amount: u64
    }
    
    public struct EventPaymentIntentRefunded has copy, drop {
       payment_intent_id: u32,
        merchant_name: String,
        amount: u64
    }

     public struct EventPaymentIntentCanceled has copy, drop {
       payment_intent_id: u32,
       merchant_name: String
    }
    
    public struct EventConditionalEscrowCreated has copy, drop{
        escrow_id: u32,
        buyer_name: String,
        seller_name: String,
        amount: u64,
        condition_price: u64
    }
    
    public struct EventConditionalEscrowFulfilled has copy, drop {
        escrow_id: u32,
        buyer_name: String,
        seller_name: String
    }
    
     public struct EventConditionalEscrowCanceled has copy, drop {
       escrow_id: u32,
        buyer_name: String
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
            payment_intents: vec_map::empty<u32, PaymentIntent>(),
            payment_intent_ids:  vector::empty<PaymentIntentID>(),
            conditional_escrows: vec_map::empty<u32, ConditionalEscrow>(),
            conditional_escrow_ids: vector::empty<ConditionalEscrowID>()
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
    
    // public entry fun create_conditional_escrow(
    //     sui_pay: &mut SuiPay,
    //     buyer_name: String,
    //     seller_name: String,
    //     amount: u64,
    //     condition_price: u64,
    //     metadata: vector<u8>,
    //     expiry: u64,
    //     rnd: &Random,
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ) {
    //     let mut generator = new_generator(rnd, ctx);
    //     let escrow_id = generate_u32(&mut generator);
    //     let timestamp = clock::timestamp_ms(clock);
    //     let conditional_escrow = ConditionalEscrow {
    //         escrow_id,
    //         buyer_name,
    //         seller_name,
    //         amount,
    //         condition_price,
    //         status: 0, // pending
    //         token: string::utf8(b"SUI"),
    //         created_at: timestamp,
    //         metadata,
    //          expiry
    //     };
    //     let escrow_id_struct = ConditionalEscrowID {
    //         escrow_id
    //     };
    //     let mut buyer = get_user(sui_pay, buyer_name);
    //     vec_map::insert(&mut buyer.conditional_escrows, escrow_id, conditional_escrow);
    //     buyer.conditional_escrow_ids.push_back(escrow_id_struct);
    //     event::emit(
    //         EventConditionalEscrowCreated {
    //             escrow_id,
    //             buyer_name,
    //             seller_name,
    //             amount,
    //              condition_price
    //         }
    //     )
    // }
    
    // public entry fun fulfill_conditional_escrow(
    //     sui_pay: &mut SuiPay,
    //     buyer_name: String,
    //     escrow_id: u32,
    //     coin: &mut Coin<SUI>,
    //     price: u64, // Current Price
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ) {
    //     let (seller_name, amount, expiry, condition_price, buyer_address) = get_conditional_escrow_info(sui_pay, buyer_name, escrow_id, clock, price, ctx);
    //     assert!(clock::timestamp_ms(clock) <= expiry, EConditionalEscrowExpired);
    //     assert!(price >= condition_price, EInsufficientBalance);
    //     let seller_address =  get_seller_address(sui_pay, seller_name);
    //     handle_conditional_escrow_payment(sui_pay, seller_name, seller_address, amount, coin, buyer_address, ctx);
    //     event::emit(EventConditionalEscrowFulfilled {
    //         escrow_id,
    //         buyer_name,
    //         seller_name
    //     });
    // }
    // fun get_seller_address(sui_pay: &mut SuiPay,seller_name: String) : address {
    //     let mut seller = get_user(sui_pay, seller_name);
    //     seller.username.owner
    // }
    // fun get_conditional_escrow_info(
    //     sui_pay: &mut SuiPay,
    //     buyer_name: String,
    //     escrow_id: u32,
    //     clock: &Clock,
    //     price: u64,
    //     ctx: &mut TxContext
    // ) : (String, u64, u64, u64, address) {
    //     let mut buyer = get_user(sui_pay, buyer_name);
    //     assert!(vec_map::contains(&buyer.conditional_escrows, &escrow_id), EConditionalEscrowNotFound);
    //     let mut conditional_escrow = vec_map::get_mut(&mut buyer.conditional_escrows, &escrow_id);
    //     assert!(conditional_escrow.status == 0, EConditionalEscrowAlreadyFulfilled);
    //     let seller_name = conditional_escrow.seller_name;
    //     let amount = conditional_escrow.amount;
    //     let expiry = conditional_escrow.expiry;
    //     let condition_price = conditional_escrow.condition_price;
    //     let buyer_address = buyer.username.owner;
    //     conditional_escrow.status = 1;
    //     (seller_name, amount, expiry, condition_price, buyer_address)
    // }
    
      
    // fun handle_conditional_escrow_payment(
    //     sui_pay: &mut SuiPay, 
    //     seller_name: String, 
    //     receiver_address: address, 
    //     payment_amount: u64, 
    //     coin: &mut Coin<SUI>,
    //     sender_address: address,
    //     message: String,
    //     ctx: &mut TxContext
    // ) {
    //     assert!(coin::value(coin) >= payment_amount, EInsufficientBalance);
    //     pay::split_and_transfer(coin, payment_amount, receiver_address, ctx);
    //     let mut seller = get_user(sui_pay, seller_name);
    //     let receive_entry = SendReceive {
    //         action: b"+", 
    //         amount: payment_amount, 
    //         message,
    //         otherPartyAddress: sender_address, 
    //         otherPartyName: b"Customer".to_string()
    //     };
    //     seller.history.push_back(receive_entry);
    // }
    
    // public entry fun cancel_conditional_escrow(sui_pay: &mut SuiPay, buyer_name: String, escrow_id: u32) {
    //     let mut buyer = get_user(sui_pay, buyer_name);
    //     assert!(vec_map::contains(&buyer.conditional_escrows, &escrow_id), EConditionalEscrowNotFound);
    //     let mut conditional_escrow = vec_map::get_mut(&mut buyer.conditional_escrows, &escrow_id);
    //     assert!(conditional_escrow.status == 0, EConditionalEscrowAlreadyFulfilled);
    //     conditional_escrow.status = 2; //cancel
    //     let (found, index) = vector::index_of(&buyer.conditional_escrow_ids, &ConditionalEscrowID{escrow_id});
    //       if(found){
    //         vector::remove(&mut buyer.conditional_escrow_ids, index);
    //         event::emit(
    //             EventConditionalEscrowCanceled {
    //                escrow_id,
    //                buyer_name
    //             }
    //         )
    //     }
    // }
    

    // public entry fun create_payment_intent(
    //     sui_pay: &mut SuiPay,
    //     merchant_name: String,
    //     amount: u64,
    //     metadata: vector<u8>,
    //     rnd: &Random,
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ) {
    //     let mut generator = new_generator(rnd, ctx);
    //     let payment_intent_id = generate_u32(&mut generator);
    //     let timestamp = clock::timestamp_ms(clock);
    //     let sender = ctx.sender();
    //     let payment_intent = PaymentIntent {
    //        payment_intent_id,
    //         merchant_name,
    //         amount,
    //         currency: string::utf8(b"SUI"),
    //         customer_address: sender,
    //         status: 0, // pending
    //         timestamp,
    //         metadata,
    //     };
        
    //     let payment_intent_id_struct = PaymentIntentID {
    //         payment_intent_id
    //     };

    //     let mut user = get_user(sui_pay, merchant_name);
    //     vec_map::insert(&mut user.payment_intents, payment_intent_id, payment_intent);
    //     user.payment_intent_ids.push_back(payment_intent_id_struct);
    //     event::emit(EventPaymentIntentCreated {
    //          payment_intent_id,
    //         merchant_name,
    //         amount,
    //     });
    // }

    // // public entry fun pay_with_payment_intent(
    // //     sui_pay: &mut SuiPay,
    // //     name: String,
    // //     payment_intent_id: u32,
    // //     coin: &mut Coin<SUI>,
    // //     ctx: &mut TxContext
    // //     ) {
    // //     let sender_address = ctx.sender();
    // //     let (merchant_name, payment_amount, receiver_address) = handle_user_payment_intent(sui_pay, name, payment_intent_id, sender_address);
    // //     handle_merchant_payment(sui_pay, merchant_name, receiver_address, payment_amount, coin, sender_address, ctx);
    // //     event::emit(EventPaymentIntentPaid {
    // //         payment_intent_id,
    // //         merchant_name,
    // //         amount: payment_amount
    // //     });
    // // }

    // // fun handle_user_payment_intent(
    // //     sui_pay: &mut SuiPay,
    // //     name: String,
    // //     payment_intent_id: u32,
    // //     sender_address: address
    // //  ) : (String, u64, address){
    // //     let mut user = get_user(sui_pay, name);
    // //     assert!(vec_map::contains(&user.payment_intents, &payment_intent_id), EPaymentIntentNotFound);
    // //     let mut payment_intent = vec_map::get_mut(&mut user.payment_intents, &payment_intent_id);
    // //     assert!(payment_intent.status == 0, EPaymentIntentAlreadyPaid); // Check if order is still pending
    // //     payment_intent.status = 1; // Update status to paid
    // //     let merchant_name = user.username.name;
    // //     let payment_amount = payment_intent.amount;
    // //     let receiver_address = user.username.owner;
    // //     (merchant_name, payment_amount, receiver_address)
    // // }
    
    // // fun handle_merchant_payment(
    // //     sui_pay: &mut SuiPay, 
    // //     merchant_name: String, 
    // //     receiver_address: address, 
    // //     payment_amount: u64, 
    // //     coin: &mut Coin<SUI>,
    // //     sender_address: address,
    // //     message: String,
    // //     ctx: &mut TxContext
    // // ) {
    // //     assert!(coin::value(coin) >= payment_amount, EInsufficientBalance);
    // //     pay::split_and_transfer(coin, payment_amount, receiver_address, ctx);
    // //     let mut user = get_user(sui_pay, merchant_name);
    // //     let receive_entry = SendReceive {
    // //         action: b"+", 
    // //         amount: payment_amount, 
    // //         message,
    // //         otherPartyAddress: sender_address, 
    // //         otherPartyName: b"Customer".to_string()
    // //     };
    // //     user.history.push_back(receive_entry);
    // // }

    // // public entry fun refund_with_payment_intent(sui_pay: &mut SuiPay, name: String, payment_intent_id: u32, ctx: &mut TxContext){
    // //     let mut user = get_user(sui_pay, name);
    // //     assert!(vec_map::contains(&user.payment_intents, &payment_intent_id), EPaymentIntentNotFound);
    // //     let mut payment_intent = vec_map::get_mut(&mut user.payment_intents, &payment_intent_id);
    // //     assert!(payment_intent.status == 1, EInvalidStatus);
    // //     payment_intent.status = 2;
    // //     let amount = payment_intent.amount;
    // //        let sender = ctx.sender();
    // //        let cash = coin::take(&mut user.balance, amount, ctx);
    // //     transfer::public_transfer(cash, sender);
    // //         event::emit(EventPaymentIntentRefunded {
    // //              payment_intent_id,
    // //             merchant_name: name,
    // //             amount
    // //         });
    // // }

    // // public entry fun cancel_payment_intent(sui_pay: &mut SuiPay, name: String, payment_intent_id: u32) {
    // //     let mut user = get_user(sui_pay, name);
    // //     assert!(vec_map::contains(&user.payment_intents, &payment_intent_id), EPaymentIntentNotFound);
    // //     let mut payment_intent = vec_map::get_mut(&mut user.payment_intents, &payment_intent_id);
    // //     assert!(payment_intent.status == 0, EInvalidStatus);
    // //     payment_intent.status = 3;
    // //     let (found, index) = vector::index_of(&user.payment_intent_ids, &PaymentIntentID{payment_intent_id});
    // //     if(found){
    // //         vector::remove(&mut user.payment_intent_ids, index);
    // //         event::emit(
    // //             EventPaymentIntentCanceled {
    // //                 payment_intent_id,
    // //                 merchant_name: name
    // //             }
    // //         )
    // //     }

    // // }

    
    
    
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
        receiver_name: String, 
        request_message: String, 
        request_amount: u64,
        requestor_name: String, 
        rnd: &Random,
        ctx: &mut TxContext
    ) {
        let mut generator = new_generator(rnd, ctx);
        let request_id = generate_u32(&mut generator);
        let requestor_address = get_user_address(sui_pay, requestor_name); 

        let request = Request {
            name_requestor: receiver_name, 
            address_requestor: requestor_address, 
            amount: request_amount, 
            message: request_message,
            name: receiver_name
        };
        let request_id_struct = RequestID{ 
            name: receiver_name,
            id: request_id
        };
        let mut user = vec_map::get_mut(&mut sui_pay.accounts, &receiver_name);
        vec_map::insert(&mut user.requests, request_id, request);
        user.request_ids.push_back(request_id_struct);
        event::emit(
            EventPaymentRequestCreated {
                requestor: requestor_name,
                amount: request_amount, 
                address: requestor_address, 
                name: receiver_name,
                id: request_id 
            }
        )
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
            payer_name_from_request,
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

        // 3. Update the receiver's balance and history
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

    public fun get_all_payment_intent_by_merchant(name: String, sui_pay: &mut SuiPay, _ctx: &mut TxContext) : vector<PaymentIntentID>{
        let mut user = get_user(sui_pay, name);
        user.payment_intent_ids
    }

    
    public fun get_payment_intent(name: String, sui_pay: &mut SuiPay, payment_intent_id: u32, _ctx: &mut TxContext): PaymentIntent{
         let mut user = get_user(sui_pay, name);
         assert!(vec_map::contains(&user.payment_intents, &payment_intent_id), EPaymentIntentNotFound);
        *vec_map::get_mut(&mut user.payment_intents, &payment_intent_id)
    }
    public fun get_all_conditional_escrow_by_buyer(name: String, sui_pay: &mut SuiPay, _ctx: &mut TxContext): vector<ConditionalEscrowID>{
         let mut user = get_user(sui_pay, name);
         user.conditional_escrow_ids
    }
    public fun get_all_conditional_escrow_by_seller(name: String, sui_pay: &mut SuiPay, _ctx: &mut TxContext): vector<ConditionalEscrowID>{
        let mut user = get_user(sui_pay, name);
        let mut result = vector::empty<ConditionalEscrowID>();
        let mut i = 0;
        let len = vector::length(&user.conditional_escrow_ids);
        while (i < len) {
            let escrow_id_struct =  vector::borrow(&user.conditional_escrow_ids, i);
            let conditional_escrow = vec_map::get_mut(&mut user.conditional_escrows, &escrow_id_struct.escrow_id);
            if(&conditional_escrow.seller_name == &name){
                vector::push_back(&mut result, *escrow_id_struct);
            };
            i = i + 1;
        };
        result
    }

    public fun get_conditional_escrow(name: String, sui_pay: &mut SuiPay, escrow_id: u32, _ctx: &mut TxContext): ConditionalEscrow {
        let mut user = get_user(sui_pay, name);
        assert!(vec_map::contains(&user.conditional_escrows, &escrow_id), EConditionalEscrowNotFound);
        *vec_map::get_mut(&mut user.conditional_escrows, &escrow_id)
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

 