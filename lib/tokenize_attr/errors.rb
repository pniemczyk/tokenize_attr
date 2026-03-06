# frozen_string_literal: true

module TokenizeAttr
  # Base error class for all tokenize_attr exceptions.
  class Error < StandardError; end

  # Raised when a unique token cannot be generated within the configured
  # number of retries.
  #
  # @example
  #   begin
  #     MyModel.create!
  #   rescue TokenizeAttr::RetryExceededError => e
  #     Rails.logger.error(e.message)
  #   end
  class RetryExceededError < Error
    # @param attribute [Symbol, String] the attribute that failed to tokenize
    # @param retries   [Integer]        the number of attempts that were made
    def initialize(attribute, retries)
      super("Could not generate a unique token for :#{attribute} after #{retries} retries")
    end
  end
end
