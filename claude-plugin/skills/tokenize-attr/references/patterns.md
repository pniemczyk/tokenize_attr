# tokenize_attr — Usage Patterns

## Pattern 1: Basic (delegates to `has_secure_token`)

When no `prefix:` and no generator are provided, `tokenize` delegates entirely
to Rails' `has_secure_token`. The `retries` param is ignored on this path.

```ruby
class User < ApplicationRecord
  tokenize :api_token
end

user = User.create!
user.api_token  # => "aBcD1234..."  (64 base58 URL-safe chars)

# regenerate_ helper is available (Rails adds it via has_secure_token)
user.regenerate_api_token
```

## Pattern 2: Prefixed Token

Adding `prefix:` routes through the custom callback. The token becomes
`"prefix-<random_portion>"`.

```ruby
class AccessToken < ApplicationRecord
  tokenize :token, prefix: "tok", size: 32
end

token = AccessToken.create!
token.token  # => "tok-aBcD1234..."  ("tok-" + 32 chars)
```

Common prefix conventions: `"tok"`, `"key"`, `"sk"` (secret key),
`"pk"` (public key), `"inv"` (invite), `"ord"` (order reference).

## Pattern 3: Custom Size

```ruby
class Session < ApplicationRecord
  tokenize :session_id, size: 128
end

# Without prefix → delegates to has_secure_token(length: 128)
# With prefix    → SecureRandom.base58(128) + prefix
```

## Pattern 4: Custom Generator — Proc as Second Argument

The proc receives `size` and must return a `String`.

```ruby
class Order < ApplicationRecord
  tokenize :reference, proc { |size| SecureRandom.alphanumeric(size) },
           prefix: "ord", size: 12
end

Order.create!.reference  # => "ord-aB3cD4eF5gH6"
```

## Pattern 5: Custom Generator — Method Reference

```ruby
class Order < ApplicationRecord
  def self.reference_generator(size)
    SecureRandom.alphanumeric(size)
  end

  tokenize :reference, &method(:reference_generator)
end
```

## Pattern 6: Custom Generator — Inline Block

```ruby
class Order < ApplicationRecord
  # Parentheses required when passing a block to a method call inside a class
  tokenize(:reference) { |size| SecureRandom.alphanumeric(size) }
end
```

## Pattern 7: Generator Without Prefix — Still Bypasses `has_secure_token`

Any generator always routes through the callback, even when `prefix:` is absent.

```ruby
class User < ApplicationRecord
  tokenize :api_token, proc { |size| "usr_#{SecureRandom.hex(size / 2)}" }
end
```

## Pattern 8: Multiple Tokenized Attributes

```ruby
class ApiCredential < ApplicationRecord
  tokenize :public_key,  prefix: "pk", size: 32
  tokenize :private_key, prefix: "sk", size: 64
end

cred = ApiCredential.create!
cred.public_key   # => "pk-..."
cred.private_key  # => "sk-..."
```

## Pattern 9: Custom Retry Budget

```ruby
class InviteCode < ApplicationRecord
  tokenize :code, prefix: "inv", retries: 10
end
```

Increase `retries` when your token space is small (low `size:`) or when you
expect frequent near-collisions (high existing record count + small keyspace).

## Pattern 10: Pre-Set Token Is Preserved

The `before_create` callback skips generation when `present?` is already true.

```ruby
token = AccessToken.create!(token: "tok-my-custom-value")
token.token  # => "tok-my-custom-value"  (unchanged)
```

Useful for seeding or importing records with predetermined tokens.

## Pattern 11: Handling `RetryExceededError`

```ruby
begin
  InviteCode.create!
rescue TokenizeAttr::RetryExceededError => e
  # e.message => "Could not generate a unique token for :code after 3 retries"
  Rails.logger.error("Token collision: #{e.message}")
  render json: { error: 'Could not generate a unique token' }, status: :conflict
end
```

Error hierarchy:

```
StandardError
  └── TokenizeAttr::Error
        └── TokenizeAttr::RetryExceededError
```

## Pattern 12: Checking Which Path Will Be Used

```ruby
# In a Rails console
AccessToken.respond_to?(:has_secure_token)
# true  → tokenize without prefix/generator will delegate to has_secure_token
# false → tokenize always uses the custom callback

# Force callback path even without prefix — just add a generator:
tokenize :api_token, proc { |size| SecureRandom.base58(size) }
```

## Pattern 13: Recommended Migration

```ruby
class AddApiTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :api_token, :string
    add_index  :users, :api_token, unique: true
  end
end
```

Always add a unique index. The gem's `exists?` check prevents collisions at
the application level, but the index is the safety net for concurrent inserts.

## Pattern 14: Manual Include (non-AR)

For classes that do not inherit from `ActiveRecord::Base`, include the concern
explicitly and implement `before_create` and `self.exists?`:

```ruby
class MyPlainModel
  include TokenizeAttr::Concern

  attr_accessor :token
  tokenize :token, prefix: "my"

  def before_create
    # implement or call super in your framework
  end

  def self.exists?(conditions)
    # implement lookup against your store
    false
  end
end
```
