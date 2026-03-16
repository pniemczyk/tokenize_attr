---
name: tokenize-attr
description: This skill should be used when the user asks to "add tokenize_attr", "install tokenize_attr", "use tokenize_attr", "generate secure tokens for model attributes", "add a token column to a Rails model", "add a prefixed token like tok-abc123", "create an API key or access token with a prefix", "use has_secure_token with a prefix", "custom token generator in Rails", or when working with the tokenize_attr gem in a Rails project. Also activate when the user wants to add `before_create` token generation, handle `RetryExceededError`, or use `tokenize :attr, prefix:` style declarations.
version: 1.0.0
---

# tokenize_attr Skill

`tokenize_attr` adds declarative secure token generation to ActiveRecord model attributes via a single `tokenize` class macro. It delegates to Rails' built-in `has_secure_token` when possible and switches to a custom `before_create` callback when a prefix or custom generator is needed.

## What It Does

```ruby
# Basic — delegates to has_secure_token
class User < ApplicationRecord
  tokenize :api_token
end

user = User.create!
user.api_token  # => "aBcD1234..."  (64 base58 chars, URL-safe)

# Prefixed — uses custom callback
class AccessToken < ApplicationRecord
  tokenize :token, prefix: "tok", size: 32
end

token = AccessToken.create!
token.token  # => "tok-aBcD1234..."  ("tok-" + 32 random chars)
```

Routing decision (automatic, invisible to the caller):

| Condition | Path used | `retries` honoured? |
|---|---|---|
| No `prefix`, no `generator`, `has_secure_token` available | `has_secure_token` delegation | No — ignored |
| `prefix:` given | Custom `before_create` callback | Yes |
| `generator` given (with or without `prefix`) | Custom `before_create` callback | Yes |
| `has_secure_token` unavailable | Custom `before_create` callback | Yes |

## Installation

See **`references/installation.md`** for full steps. Quick summary:

```ruby
# Gemfile
gem 'tokenize_attr'
```

```bash
bundle install
rails tokenize_attr:install   # writes config/initializers/tokenize_attr.rb
```

The installer writes a single `ActiveSupport.on_load(:active_record)` block that auto-includes `TokenizeAttr::Concern` into every AR model. No manual include needed in AR models.

## Core Usage

### Full signature

```ruby
tokenize(attribute, generator = nil, size: 64, prefix: nil, retries: 3, &block)
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `attribute` | Symbol | — | The attribute to tokenize |
| `generator` | Proc / nil | nil | Called as `generator.call(size)`. Also accepted as a `&block`. |
| `size` | Integer | 64 | Passed to the generator or to `SecureRandom.base58` |
| `prefix` | String / nil | nil | Prepended as `"prefix-<token>"` |
| `retries` | Integer | 3 | Max uniqueness-check attempts (callback path only) |

### Basic (no prefix) — delegates to `has_secure_token`

```ruby
class User < ApplicationRecord
  tokenize :api_token
end
```

`has_secure_token` is used automatically. The `retries` param is **ignored** on this path.

### With prefix — uses custom callback

```ruby
class AccessToken < ApplicationRecord
  tokenize :token, prefix: "tok", size: 32
end

token = AccessToken.create!
token.token  # => "tok-aBcD1234..."
```

### Custom generator

```ruby
class Order < ApplicationRecord
  tokenize :reference, proc { |size| SecureRandom.alphanumeric(size) },
           prefix: "ord", size: 12
end

Order.create!.reference  # => "ord-aB3cD4eF5gH6"
```

### Multiple tokenized attributes

```ruby
class ApiCredential < ApplicationRecord
  tokenize :public_key,  prefix: "pk", size: 32
  tokenize :private_key, prefix: "sk", size: 64
end
```

## ⚠️ Key Gotchas

### `retries` is ignored on the `has_secure_token` path

```ruby
# retries: 5 is silently ignored here — has_secure_token has no retry logic
tokenize :api_token, retries: 5

# retries: 5 IS used here — callback path
tokenize :api_token, prefix: "usr", retries: 5
```

### A generator always bypasses `has_secure_token`

Even when no `prefix:` is given, providing any generator routes through the callback:

```ruby
class User < ApplicationRecord
  # Custom generator → callback path, even without prefix
  tokenize :api_token, proc { |size| "usr_#{SecureRandom.hex(size / 2)}" }
end
```

### Pre-set token is always preserved

The callback skips generation if the attribute is already `present?`:

```ruby
token = AccessToken.create!(token: "tok-my-custom-value")
token.token  # => "tok-my-custom-value"  (unchanged)
```

### A DB unique index is required for real uniqueness guarantees

The gem checks uniqueness via `exists?` before committing, but only a DB constraint prevents race conditions:

```ruby
add_index :users, :api_token, unique: true
```

## Error Handling

```ruby
class InviteCode < ApplicationRecord
  tokenize :code, prefix: "inv", retries: 5
end

begin
  InviteCode.create!
rescue TokenizeAttr::RetryExceededError => e
  Rails.logger.error("Token generation failed: #{e.message}")
  # => "Could not generate a unique token for :code after 5 retries"
end
```

`TokenizeAttr::RetryExceededError` is a subclass of `TokenizeAttr::Error` which is a subclass of `StandardError`.

## Testing

```ruby
# Minitest
test 'generates a prefixed token on create' do
  record = AccessToken.create!
  assert_match(/\Atok-\w+\z/, record.token)
end

test 'does not overwrite a pre-set token' do
  record = AccessToken.create!(token: 'tok-custom')
  assert_equal 'tok-custom', record.token
end

test 'raises RetryExceededError when all retries exhausted' do
  always_exists = Class.new(AccessToken) { def self.exists?(*) = true }
  assert_raises(TokenizeAttr::RetryExceededError) { always_exists.create! }
end
```

## Additional Resources

### Reference Files

- **`references/installation.md`** — Step-by-step setup, initializer content, rake tasks, migration examples
- **`references/patterns.md`** — Full usage patterns: generators, multiple attrs, error handling, non-Rails use

### Examples

- **`examples/activerecord.rb`** — AR model examples covering all major options
- **`examples/testing.rb`** — Minitest and RSpec test patterns including collision simulation
