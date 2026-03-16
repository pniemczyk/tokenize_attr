# frozen_string_literal: true

# Example: Testing models that use tokenize_attr
# Works with both Minitest and RSpec.

# ─── Minitest ────────────────────────────────────────────────────────────────

require 'minitest/autorun'

class AccessTokenTest < Minitest::Test
  # Basic: token is generated on create
  def test_token_generated_on_create
    record = AccessToken.create!
    refute_nil record.token
    assert record.token.start_with?('tok-')
  end

  # Token matches expected format
  def test_token_format
    record = AccessToken.create!
    assert_match(/\Atok-\w+\z/, record.token)
  end

  # Pre-set token is preserved
  def test_pre_set_token_is_preserved
    record = AccessToken.create!(token: 'tok-custom-value')
    assert_equal 'tok-custom-value', record.token
  end

  # Token is not regenerated on update
  def test_token_not_regenerated_on_update
    record = AccessToken.create!
    original = record.token
    record.update!(updated_at: Time.now)
    assert_equal original, record.reload.token
  end

  # Uniqueness: two records have different tokens
  def test_tokens_are_unique
    a = AccessToken.create!
    b = AccessToken.create!
    refute_equal a.token, b.token
  end
end

# ─── Collision simulation (Minitest) ─────────────────────────────────────────
#
# Use an anonymous subclass that overrides self.exists? to simulate exhausted
# uniqueness retries. Do NOT use minitest's `stub` on AR model classes —
# ActiveRecord 8.x method_missing intercepts stub before minitest can install it.

class CollisionTest < Minitest::Test
  def test_retry_exceeded_error_is_raised
    always_collides = Class.new(AccessToken) do
      def self.exists?(*) = true
    end

    assert_raises(TokenizeAttr::RetryExceededError) { always_collides.create! }
  end

  def test_error_message_includes_attribute_and_retry_count
    always_collides = Class.new(AccessToken) do
      self.tokenize :token, prefix: 'tok', size: 32, retries: 2
      def self.exists?(*) = true
    end

    error = assert_raises(TokenizeAttr::RetryExceededError) { always_collides.create! }
    assert_includes error.message, ':token'
    assert_includes error.message, '2'
  end
end

# ─── RSpec ───────────────────────────────────────────────────────────────────

RSpec.describe AccessToken do
  describe 'token generation' do
    subject(:record) { described_class.create! }

    it 'generates a token on create' do
      expect(record.token).to be_present
    end

    it 'uses the correct prefix' do
      expect(record.token).to start_with('tok-')
    end

    it 'generates unique tokens' do
      other = described_class.create!
      expect(record.token).not_to eq(other.token)
    end
  end

  describe 'pre-set token' do
    it 'preserves a token set before create' do
      record = described_class.create!(token: 'tok-custom')
      expect(record.token).to eq('tok-custom')
    end
  end

  describe 'collision handling' do
    let(:always_collides) do
      Class.new(described_class) { def self.exists?(*) = true }
    end

    it 'raises RetryExceededError when all retries fail' do
      expect { always_collides.create! }
        .to raise_error(TokenizeAttr::RetryExceededError)
    end
  end
end

# ─── Testing the Installer (no Rails, no Rake) ───────────────────────────────

class InstallerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @root   = Pathname.new(@tmpdir)
    FileUtils.mkdir_p(@root.join('config', 'initializers'))
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_install_creates_initializer
    result = TokenizeAttr::Installer.install!(@root)
    assert_equal :created, result
    assert @root.join('config/initializers/tokenize_attr.rb').exist?
  end

  def test_install_skips_when_already_present
    TokenizeAttr::Installer.install!(@root)
    result = TokenizeAttr::Installer.install!(@root)
    assert_equal :skipped, result
  end

  def test_uninstall_removes_initializer
    TokenizeAttr::Installer.install!(@root)
    result = TokenizeAttr::Installer.uninstall!(@root)
    assert_equal :removed, result
    refute @root.join('config/initializers/tokenize_attr.rb').exist?
  end

  def test_uninstall_skips_when_not_present
    result = TokenizeAttr::Installer.uninstall!(@root)
    assert_equal :skipped, result
  end
end
