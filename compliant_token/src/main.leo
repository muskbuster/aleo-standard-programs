import credits.aleo;
import token_registry.aleo;

// The 'compliant_token' program with added age and credit score verification.
program compliant_token.aleo {
  // Constants defining the token parameters.
  const COMPLAINT_TOKEN_ID: field = 71619063553950105623552field; // Unique token identifier
  const ADMIN_ADDRESS: address = aleo10047h9c9efxz3d0u69xn7alclvsvt96ysuhts80p7h2eh57kh5zsjwsp8f; // Admin address with minting and issuing privileges
  const MAX_SUPPLY: u128 = 1_000_000_000_000_000u128; // Maximum supply of the token
  const BLOCKS_IN_A_DAY: u32 = 28_800u32; // Number of blocks per day for epoch-based calculations
  const MAX_SPEND_PER_DAY: u128 = 10_000_000_000u128; // Daily spending limit per user
  const MAX_U32: u32 = 4294967295u32; // Maximum value of a u32, used for transaction expiration
  const MINIMUM_AGE: u8 = 18u8; // Minimum age required to use the token
  const MINIMUM_CREDIT_SCORE: u16 = 500u16; // Minimum credit score required to use the token

  // Record defining the spend limit for a user.
  record SpendLimit {
    owner: address,      // The owner of the spend limit
    amount_spent: u128,  // Amount spent in the current epoch
    epoch_spent: u32,    // The epoch in which the last transaction occurred
    age_verified: bool,  // Whether the user's age has been verified
    credit_verified: bool // Whether the user's credit score has been verified
  }

  // Record for storing user verification data
  record UserVerification {
    owner: address,         // The owner of the verification record
    age: u8,                // User's age
    credit_score: u16,      // User's credit score
    verification_block: u32 // Block at which verification occurred
  }

  // Mapping to track whether the token has been minted (prevents multiple minting).
  mapping has_minted: u8 => bool;
  
  // Mapping to track whether a user has an active spend limit.
  mapping has_spend_limit: field => bool;
  
  // Mapping to track verified users
  mapping verified_users: address => bool;

  /**
   * Initializes the compliant token by registering it with the token registry.
   * Can only be called by the ADMIN_ADDRESS.
   */
  async transition initialize() -> Future {
    assert_eq(self.caller, ADMIN_ADDRESS);

    let name: u128 = 71619063553950105623552u128; // "compliant" encoded in ASCII
    let symbol: u128 = 71619063553950105623552u128; // "compliant" encoded in ASCII
    let decimals: u8 = 6u8; // Decimal places for the token
    let max_supply: u128 = 10_000_000_000_000_000u128; // Maximum supply
    let external_authorization_required: bool = true; // Requires external authorization
    let external_authorization_party: address = self.address; // Authorization controlled by this contract

    // Register the token in the token registry
    let f0: Future = token_registry.aleo/register_token(
      COMPLAINT_TOKEN_ID,
      name,
      symbol,
      decimals,
      max_supply,
      external_authorization_required,
      external_authorization_party
    );

    return finalize_register_token(f0);
  }

  /**
   * Awaits the completion of the token registration process.
   */
  async function finalize_register_token(f0: Future) {
    f0.await();
  }

  /**
   * Mints the maximum supply of tokens to the ADMIN_ADDRESS.
   * Can only be called once by the ADMIN_ADDRESS.
   */
  async transition mint_private() -> (token_registry.aleo/Token, Future) {
    assert_eq(self.caller, ADMIN_ADDRESS);
    
    // Mint private tokens to the admin
    let mint_output: (token_registry.aleo/Token, Future) = token_registry.aleo/mint_private(
      COMPLAINT_TOKEN_ID,
      ADMIN_ADDRESS,
      MAX_SUPPLY,
      true,
      MAX_U32
    );

    return (mint_output.0, finalize_mint_private(mint_output.1));
  }

  /**
   * Finalizes the minting process and ensures that tokens are minted only once.
   */
  async function finalize_mint_private(f0: Future) {
    f0.await();

    let has_already_minted: bool = has_minted.contains(0u8);
    assert(!has_already_minted); // Ensure tokens are minted only once
    has_minted.set(0u8, true);
  }

  /**
   * Registers a user's verification data.
   * Can only be called by the ADMIN_ADDRESS.
   */
  transition register_user_verification(
    user: address,
    age: u8,
    credit_score: u16
  ) -> UserVerification {
    assert_eq(self.caller, ADMIN_ADDRESS);
    
    // Create a verification record for the user
    return UserVerification {
      owner: user,
      age: age,
      credit_score: credit_score,
      verification_block: block.height
    };
  }

  /**
   * Verifies a user's age and credit score against minimum requirements.
   * Can only be called by the owner of the verification record.
   */
  async transition verify_user(
    verification: UserVerification
  ) -> Future {
    // Ensure only the owner can verify themselves
    assert_eq(self.caller, verification.owner);
    
    // Check if the user meets the minimum age requirement
    assert(verification.age >= MINIMUM_AGE);
    
    // Check if the user meets the minimum credit score requirement
    assert(verification.credit_score >= MINIMUM_CREDIT_SCORE);
    
    return finalize_verify_user(verification.owner);
  }

  /**
   * Finalizes the user verification process by marking them as verified.
   */
  async function finalize_verify_user(
    user: address
  ) {
    // Mark the user as verified in the verified_users mapping
    verified_users.set(user, true);
  }

  /**
   * Issues a new spend limit record for a specific user.
   * Can only be called by the ADMIN_ADDRESS.
   * Requires the user to be verified.
   */
  async transition issue_limit(
    owner: address
  ) -> (SpendLimit, Future) {
    assert_eq(self.caller, ADMIN_ADDRESS);

    // Create a new spend limit record for the user
    let spend_limit = SpendLimit {
      owner: owner,
      amount_spent: 0u128,
      epoch_spent: 0u32,
      age_verified: false,
      credit_verified: false
    };

    return (spend_limit, finalize_issue_limit(owner));
  }

  /**
   * Finalizes the issuance of a spend limit by checking if the user is verified.
   */
  async function finalize_issue_limit(
    owner: address
  ) {
    // Check if the user is verified
    let is_verified: bool = verified_users.contains(owner);
    assert(is_verified);
  }

  /**
   * Updates a user's spend limit with verification status.
   * Can only be called by the ADMIN_ADDRESS.
   */
  transition update_verification_status(
    spend_limit: SpendLimit,
    age_verified: bool,
    credit_verified: bool
  ) -> SpendLimit {
    assert_eq(self.caller, ADMIN_ADDRESS);
    
    return SpendLimit {
      owner: spend_limit.owner,
      amount_spent: spend_limit.amount_spent,
      epoch_spent: spend_limit.epoch_spent,
      age_verified: age_verified,
      credit_verified: credit_verified
    };
  }

  /**
   * Transfers tokens privately while enforcing the user's spend limit.
   * Ensures that the user cannot exceed the daily spend limit and has passed verification checks.
   */
  async transition transfer_private(
    input_token: token_registry.aleo/Token, // The input token record to be spent
    spend_limit: SpendLimit, // The user's spend limit record
    amount: u128, // Amount to transfer
    recipient: address, // Recipient address
    public epoch: u32 // Current epoch
  ) -> (SpendLimit, token_registry.aleo/Token, token_registry.aleo/Token, token_registry.aleo/Token, Future) {
    
    // Verify that the user has passed both age and credit score checks
    assert(spend_limit.age_verified);
    assert(spend_limit.credit_verified);
    
    // Determine the updated amount spent based on the epoch
    let updated_amount_spent: u128 = spend_limit.epoch_spent < epoch 
        ? amount // Reset the spend amount if in a new epoch
        : amount + spend_limit.amount_spent; // Otherwise, accumulate the spend amount
    
    // Ensure the updated spend amount does not exceed the daily limit
    assert(updated_amount_spent <= MAX_SPEND_PER_DAY);

    // Create the updated spend limit record
    let updated_spend_limit: SpendLimit = SpendLimit {
      owner: spend_limit.owner,
      amount_spent: updated_amount_spent,
      epoch_spent: epoch,
      age_verified: spend_limit.age_verified,
      credit_verified: spend_limit.credit_verified
    };

    // **Authorize the token record**: Converts it into an authorized state so it can be transferred.
    let prehook_output: (token_registry.aleo/Token, token_registry.aleo/Token, Future) = token_registry.aleo/prehook_private(
      input_token,
      amount,
      MAX_U32
    );

    // **Transfer the authorized token** to the recipient.
    let transfer_output: (token_registry.aleo/Token, token_registry.aleo/Token, Future) = token_registry.aleo/transfer_private(
      recipient,
      amount,
      prehook_output.1
    );

    return (
      updated_spend_limit, // The updated spend limit record
      prehook_output.0,    // Remaining balance from authorization
      transfer_output.0,   // Remaining balance from transfer (should be 0)
      transfer_output.1,   // The token record sent to the recipient
      finalize_transfer_private(prehook_output.2, transfer_output.2, epoch) // Await the finalization process
    );
  }

  /**
   * Finalizes the transfer by awaiting the completion of both authorization and transfer transactions.
   */
  async function finalize_transfer_private(
    f0: Future, // Future from prehook_private
    f1: Future, // Future from transfer_private
    epoch: u32
  ) {
    f0.await();
    f1.await();

    let current_epoch: u32 = block.height % BLOCKS_IN_A_DAY;
    assert_eq(epoch, current_epoch);
  }

  /**
   * Allows a recipient to check if they can receive tokens from a specific sender
   * based on both parties' verification status.
   */
  async function can_transact(
    sender: address,
    recipient: address
  ) -> bool {
    // Check if both sender and recipient are verified
    let sender_verified: bool = verified_users.contains(sender);
    let recipient_verified: bool = verified_users.contains(recipient);
    
    // Both parties must be verified for a transaction to be allowed
    return sender_verified && recipient_verified;
  }
}
