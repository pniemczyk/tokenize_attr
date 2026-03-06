# frozen_string_literal: true

require "test_helper"

# ---------------------------------------------------------------------------
# Model definitions
# All models share the `records` table so the schema stays flat.
# ---------------------------------------------------------------------------

# Uses prefix => always exercises the custom callback path.
class Widget < ActiveRecord::Base
  self.table_name = "records"
  tokenize :token, prefix: "wgt", size: 32
end

# No prefix => delegates to has_secure_token when available.
class Gadget < ActiveRecord::Base
  self.table_name = "records"
  tokenize :token
end

# Custom prefix + small retry budget (retries: 2) for collision tests.
class ApiClient < ActiveRecord::Base
  self.table_name = "records"
  tokenize :api_key, prefix: "ak", size: 16, retries: 2
end

# No prefix, custom size — exercises has_secure_token length delegation.
class SecretKey < ActiveRecord::Base
  self.table_name = "records"
  tokenize :secret, size: 48
end

# Generator as second positional argument (proc form), no prefix.
class ProcToken < ActiveRecord::Base
  self.table_name = "records"
  tokenize :token, proc { |size| SecureRandom.alphanumeric(size) }
end

# Generator as second positional argument with prefix.
class ProcTokenWithPrefix < ActiveRecord::Base
  self.table_name = "records"
  tokenize :api_key, proc { |size| SecureRandom.alphanumeric(size) }, prefix: "gen", size: 16
end

# Generator supplied as a block (parenthesised call required).
class BlockToken < ActiveRecord::Base
  self.table_name = "records"
  tokenize(:secret) { |size| SecureRandom.alphanumeric(size) }
end

# Method-reference style: a class-level method is converted to a Proc via &.
class MethodRefToken < ActiveRecord::Base
  self.table_name = "records"

  def self.build_token(size)
    SecureRandom.alphanumeric(size)
  end

  tokenize :token, &method(:build_token)
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

module RecordCleaner
  def setup
    ActiveRecord::Base.connection.execute("DELETE FROM records")
  end
end

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------

class TestTokenizeAttrVersion < Minitest::Test
  def test_has_a_version_constant
    refute_nil ::TokenizeAttr::VERSION
  end

  def test_version_is_a_semver_string
    assert_match(/\A\d+\.\d+\.\d+\z/, ::TokenizeAttr::VERSION)
  end
end

# ---------------------------------------------------------------------------
# tokenize with prefix  (custom callback path)
# ---------------------------------------------------------------------------

class TestTokenizeWithPrefix < Minitest::Test
  include RecordCleaner

  def test_generates_token_on_create
    widget = Widget.create!
    refute_nil widget.token
  end

  def test_token_is_nil_before_create
    assert_nil Widget.new.token
  end

  def test_token_starts_with_prefix
    widget = Widget.create!
    assert widget.token.start_with?("wgt-"), "expected token to start with 'wgt-', got: #{widget.token}"
  end

  def test_token_has_expected_length
    # "wgt-" (4 chars) + 32 random base58 chars = 36
    assert_equal 36, Widget.create!.token.length
  end

  def test_does_not_overwrite_existing_token
    widget = Widget.create!(token: "wgt-custom-value")
    assert_equal "wgt-custom-value", widget.token
  end

  def test_two_tokens_differ
    a = Widget.create!
    b = Widget.create!
    refute_equal a.token, b.token
  end

  def test_token_contains_only_base58_chars_after_prefix
    random_part = Widget.create!.token.sub(/\Awgt-/, "")
    assert_match(/\A[A-HJ-NP-Za-km-z1-9]+\z/, random_part)
  end
end

# ---------------------------------------------------------------------------
# tokenize without prefix  (has_secure_token delegation path)
# ---------------------------------------------------------------------------

class TestTokenizeWithoutPrefix < Minitest::Test
  include RecordCleaner

  def test_generates_token_on_create
    gadget = Gadget.create!
    refute_nil gadget.token
    assert gadget.token.length.positive?
  end

  def test_token_is_nil_before_create
    assert_nil Gadget.new.token
  end

  def test_token_is_alphanumeric
    # has_secure_token uses base58 (no ambiguous chars like 0, O, I, l)
    assert_match(/\A[A-Za-z0-9]+\z/, Gadget.create!.token)
  end

  def test_does_not_overwrite_existing_token
    gadget = Gadget.create!(token: "already-set")
    assert_equal "already-set", gadget.token
  end

  def test_two_tokens_differ
    a = Gadget.create!
    b = Gadget.create!
    refute_equal a.token, b.token
  end
end

# ---------------------------------------------------------------------------
# Retry logic and RetryExceededError
# ---------------------------------------------------------------------------

class TestRetryBehavior < Minitest::Test
  include RecordCleaner

  # AR 8+ intercepts Object#stub via method_missing before minitest can
  # provide it, so we override exists? on anonymous subclasses instead.
  # The before_create callback inherited from the parent calls self.class.exists?,
  # so subclass overrides are picked up correctly inside the callback.

  def test_raises_retry_exceeded_error_when_all_retries_fail
    # exists? always returns true => every candidate looks taken
    model = Class.new(ApiClient) { def self.exists?(*) = true }
    assert_raises(TokenizeAttr::RetryExceededError) { model.create! }
  end

  def test_error_message_contains_attribute_name
    model = Class.new(ApiClient) { def self.exists?(*) = true }
    err = assert_raises(TokenizeAttr::RetryExceededError) { model.create! }
    assert_match(/api_key/, err.message)
  end

  def test_error_message_contains_retry_count
    model = Class.new(ApiClient) { def self.exists?(*) = true }
    err = assert_raises(TokenizeAttr::RetryExceededError) { model.create! }
    assert_match(/2/, err.message) # retries: 2 configured on ApiClient
  end

  def test_succeeds_after_transient_collision
    # First exists? call returns true (collision), subsequent calls return false
    call_count = 0
    model = Class.new(ApiClient) do
      define_singleton_method(:exists?) { |*| (call_count += 1) == 1 }
    end
    client = model.create!
    refute_nil client.api_key
    assert client.api_key.start_with?("ak-")
  end

  def test_does_not_raise_when_first_attempt_is_unique
    model = Class.new(ApiClient) { def self.exists?(*) = false }
    client = model.create!
    assert client.api_key.start_with?("ak-")
  end
end

# ---------------------------------------------------------------------------
# Error class hierarchy
# ---------------------------------------------------------------------------

class TestErrorClasses < Minitest::Test
  def test_retry_exceeded_error_is_a_tokenize_attr_error
    err = TokenizeAttr::RetryExceededError.new(:token, 3)
    assert_kind_of TokenizeAttr::Error, err
  end

  def test_retry_exceeded_error_is_a_standard_error
    err = TokenizeAttr::RetryExceededError.new(:token, 3)
    assert_kind_of StandardError, err
  end

  def test_error_message_format
    err = TokenizeAttr::RetryExceededError.new(:my_token, 5)
    assert_match(/my_token/, err.message)
    assert_match(/5/, err.message)
  end
end

# ---------------------------------------------------------------------------
# Custom generator (proc / block / method reference)
# ---------------------------------------------------------------------------

class TestTokenizeWithGenerator < Minitest::Test
  include RecordCleaner

  # --- proc as second positional argument -----------------------------------

  def test_proc_generates_token_on_create
    record = ProcToken.create!
    refute_nil record.token
  end

  def test_proc_generator_is_called_not_has_secure_token
    # Use a deterministic generator so we can assert the exact value,
    # proving the proc — not has_secure_token — produced the token.
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "records"
      tokenize :token, proc { |_size| "PROC-WAS-HERE" }
    end
    assert_equal "PROC-WAS-HERE", klass.create!.token
  end

  def test_proc_generator_receives_size_argument
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "records"
      tokenize :token, proc { |size| "X" * size }, size: 10
    end
    assert_equal "X" * 10, klass.create!.token
  end

  def test_proc_generator_default_size_is_64 # rubocop:disable Naming/VariableNumber
    assert_equal 64, ProcToken.create!.token.length
  end

  def test_proc_generator_does_not_overwrite_existing_token
    record = ProcToken.create!(token: "already-set")
    assert_equal "already-set", record.token
  end

  # --- proc + prefix --------------------------------------------------------

  def test_proc_generator_with_prefix_prepends_prefix
    record = ProcTokenWithPrefix.create!
    assert record.api_key.start_with?("gen-"),
           "expected api_key to start with 'gen-', got: #{record.api_key}"
  end

  def test_proc_generator_with_prefix_length
    # "gen-" (4) + 16 alphanumeric chars = 20
    assert_equal 20, ProcTokenWithPrefix.create!.api_key.length
  end

  # --- block form -----------------------------------------------------------

  def test_block_generates_token_on_create
    record = BlockToken.create!
    refute_nil record.secret
    assert record.secret.length.positive?
  end

  def test_block_generator_is_called
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "records"
      tokenize(:token) { |_size| "BLOCK-WAS-HERE" }
    end
    assert_equal "BLOCK-WAS-HERE", klass.create!.token
  end

  # --- method reference via & -----------------------------------------------

  def test_method_reference_generates_token
    record = MethodRefToken.create!
    refute_nil record.token
    assert record.token.length.positive?
  end

  def test_method_reference_is_called
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "records"

      def self.my_gen(_size)
        "METHOD-REF-HERE"
      end

      tokenize :token, &method(:my_gen)
    end
    assert_equal "METHOD-REF-HERE", klass.create!.token
  end

  # --- retries still work with a generator ----------------------------------

  def test_generator_raises_retry_exceeded_when_all_retries_fail
    model = Class.new(ProcTokenWithPrefix) { def self.exists?(*) = true }
    assert_raises(TokenizeAttr::RetryExceededError) { model.create! }
  end

  def test_generator_succeeds_after_transient_collision
    call_count = 0
    model = Class.new(ProcTokenWithPrefix) do
      define_singleton_method(:exists?) { |*| (call_count += 1) == 1 }
    end
    record = model.create!
    assert record.api_key.start_with?("gen-")
  end
end

# ---------------------------------------------------------------------------
# Concern inclusion
# ---------------------------------------------------------------------------

class TestConcernInclusion < Minitest::Test
  def test_tokenize_macro_available_on_active_record_base
    assert ActiveRecord::Base.respond_to?(:tokenize),
           "expected ActiveRecord::Base to respond to :tokenize"
  end

  def test_tokenize_macro_available_on_subclass
    assert Widget.respond_to?(:tokenize)
  end
end
