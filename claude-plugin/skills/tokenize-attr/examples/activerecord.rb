# frozen_string_literal: true

# Example: tokenize_attr with ActiveRecord models
# Assumes `rails tokenize_attr:install` has been run.

# ─── Basic: delegates to has_secure_token ───────────────────────────────────

class User < ApplicationRecord
  tokenize :api_token           # delegates to has_secure_token, retries ignored
end

user = User.create!
user.api_token                  # => "aBcD1234..."  (64 base58 chars)
user.regenerate_api_token       # available via has_secure_token

# ─── Prefixed token ─────────────────────────────────────────────────────────

class AccessToken < ApplicationRecord
  tokenize :token, prefix: 'tok', size: 32
end

token = AccessToken.create!
token.token                     # => "tok-aBcD1234..."

# Pre-set token is preserved (present? check skips generation)
custom = AccessToken.create!(token: 'tok-my-custom-value')
custom.token                    # => "tok-my-custom-value"

# ─── Multiple tokenized attributes ──────────────────────────────────────────

class ApiCredential < ApplicationRecord
  tokenize :public_key,  prefix: 'pk', size: 32
  tokenize :private_key, prefix: 'sk', size: 64
end

cred = ApiCredential.create!
cred.public_key                 # => "pk-..."
cred.private_key                # => "sk-..."

# ─── Custom generator (proc as 2nd arg) ─────────────────────────────────────

class Order < ApplicationRecord
  tokenize :reference, proc { |size| SecureRandom.alphanumeric(size) },
           prefix: 'ord', size: 12
end

Order.create!.reference         # => "ord-aB3cD4eF5gH6"

# ─── Custom generator (inline block) ────────────────────────────────────────

class InviteCode < ApplicationRecord
  # Parentheses required when passing a block inside a class body
  tokenize(:code) { |size| SecureRandom.hex(size / 2) }
end

InviteCode.create!.code         # => "4a7f3b..." (hex string)

# ─── Error handling ─────────────────────────────────────────────────────────

class SparseToken < ApplicationRecord
  tokenize :code, prefix: 'sp', size: 4, retries: 2
end

begin
  SparseToken.create!
rescue TokenizeAttr::RetryExceededError => e
  puts e.message
  # => "Could not generate a unique token for :code after 2 retries"
end
