# tokenize_attr — Installation Guide

## Requirements

- Ruby ≥ 3.0
- Rails 7.x or 8.x (`activesupport`, `activerecord`, `railties` ≥ 7.0)
- `activesupport` is the only hard runtime dependency

## Step 1: Add to Gemfile

```ruby
# Gemfile
gem 'tokenize_attr'
```

```bash
bundle install
```

## Step 2: Generate the Initializer

Run the provided rake task from inside the Rails app:

```bash
rails tokenize_attr:install
```

This writes `config/initializers/tokenize_attr.rb` with the following content:

```ruby
# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  include TokenizeAttr::Concern
end
```

The `on_load` callback fires once when ActiveRecord is first loaded. Every
`ApplicationRecord` subclass automatically has `.tokenize` available — no
manual `include` in individual models.

**The task is idempotent:** running it again when the file already exists
prints a skip message and leaves the file unchanged.

## Step 3: Add a migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_token_to_access_tokens.rb
class AddTokenToAccessTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :access_tokens, :token, :string
    add_index  :access_tokens, :token, unique: true
  end
end
```

A unique index is strongly recommended. The gem checks uniqueness via
`exists?` before saving, but only a DB constraint prevents race conditions.

```bash
rails db:migrate
```

## Step 4: Use `tokenize` in any model

```ruby
class AccessToken < ApplicationRecord
  tokenize :token, prefix: "tok", size: 32
end
```

That's all that's needed for AR models.

## Uninstalling

```bash
rails tokenize_attr:uninstall
```

Removes `config/initializers/tokenize_attr.rb`. Idempotent — safe to run
when the file is already absent.

## Manual Include (non-AR or non-Rails classes)

For classes that do not inherit from `ActiveRecord::Base`, include the concern
explicitly and provide `before_create` and `self.exists?`:

```ruby
class MyModel
  include TokenizeAttr::Concern

  # Implement before_create and self.exists? for the concern to work.
  tokenize :token, prefix: "my"
end
```

## Verifying the Installation

Open a Rails console and check:

```ruby
# Check the initializer was loaded
TokenizeAttr::Concern                                          # should not raise NameError
ActiveRecord::Base.ancestors.include?(TokenizeAttr::Concern)  # => true

# Quick smoke test
token = AccessToken.create!
token.token.start_with?('tok-')  # => true (if prefix: "tok" is set)
token.token.length > 0           # => true
```

## Troubleshooting

**`NoMethodError: undefined method 'tokenize'` in a plain Ruby class**
→ Add `include TokenizeAttr::Concern` before calling `tokenize`.

**`TokenizeAttr::RetryExceededError` raised on create**
→ All uniqueness retries were exhausted. Check that the token column has
enough entropy (`size:` is large enough) and that you are not overriding
`exists?` to always return `true`.

**The initializer file already exists after `rails tokenize_attr:install`**
→ That is expected — the task skips silently. The existing file is intact.

**`retries:` seems to have no effect**
→ If no `prefix:` and no generator is given and `has_secure_token` is
available, `tokenize` delegates to `has_secure_token`. On that path `retries`
is not used. Add a `prefix:` or a generator to route through the callback.

**Token not generated — attribute stays nil after create**
→ Ensure the token column exists in the database and that the migration has
been run.
