# frozen_string_literal: true

module TokenizeAttr
  # Internal class that holds all token-generation logic.
  #
  # Keeping this logic here — rather than inside +TokenizeAttr::Concern+'s
  # +class_methods+ block — ensures that none of these methods are mixed
  # into the including model class, eliminating any risk of method-name
  # collisions on user models.
  #
  # @api private
  class Tokenizer
    class << self
      # Determines which generation strategy to use and configures +klass+.
      #
      # Routes to +has_secure_token+ when all of the following are true:
      # - +generator+ is +nil+
      # - +prefix+ is +nil+
      # - +klass+ responds to +has_secure_token+ (Rails 5+)
      #
      # Otherwise installs a custom +before_create+ callback.
      #
      # @param klass     [Class]         the model class to configure
      # @param attribute [Symbol]        the attribute to assign the token to
      # @param generator [Proc, nil]     optional callable invoked as
      #   +generator.call(size)+ to produce the random portion
      # @param size      [Integer]       length passed to the generator or to
      #   +SecureRandom.base58+
      # @param prefix    [String, nil]   optional prefix, joined as
      #   +"prefix-<token>"+
      # @param retries   [Integer]       max uniqueness-check attempts;
      #   ignored on the +has_secure_token+ path
      def apply(klass, attribute, generator:, size:, prefix:, retries:) # rubocop:disable Metrics/ParameterLists
        if generator.nil? && prefix.nil? && has_secure_token?(klass)
          via_has_secure_token(klass, attribute, size)
        else
          via_callback(klass, attribute, size: size, prefix: prefix,
                                         retries: retries, generator: generator)
        end
      end

      private

      def has_secure_token?(klass) # rubocop:disable Naming/PredicatePrefix
        klass.respond_to?(:has_secure_token)
      end

      # Delegates to Rails' has_secure_token. Passes +length:+ when supported
      # (Rails 6.1+); falls back silently on older Rails versions.
      def via_has_secure_token(klass, attribute, size)
        klass.has_secure_token(attribute, length: size)
      rescue ArgumentError
        klass.has_secure_token(attribute)
      end

      # Installs a +before_create+ callback for custom token generation.
      #
      # When +generator+ is provided it is called as +generator.call(size)+
      # to produce the random portion; otherwise +SecureRandom.base58(size)+
      # is used.
      def via_callback(klass, attribute, size:, prefix:, retries:, generator: nil) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
        klass.before_create do
          next if send(attribute).present?

          token_generated = false

          retries.times do
            random_part = generator ? generator.call(size) : SecureRandom.base58(size)
            candidate   = [prefix, random_part].compact.join("-")
            send(:"#{attribute}=", candidate)

            unless self.class.exists?(attribute => candidate)
              token_generated = true
              break
            end
          end

          raise TokenizeAttr::RetryExceededError.new(attribute, retries) unless token_generated
        end
      end
    end
  end
end
