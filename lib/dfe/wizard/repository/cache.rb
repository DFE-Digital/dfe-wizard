module DfE
  module Wizard
    module Repository
      # Rails.cache-backed repository for wizard state storage
      #
      # Stores wizard data using Rails caching duck typing.
      # Works with any Rails cache store (Memory, Redis, Solid Cache, Memcached, etc.)
      # Supports optional encryption for sensitive data.
      # Developer MUST provide encryptor when encryption is enabled.
      #
      # ## Configuration Options
      #
      # - `cache` (required) - Rails cache store instance (e.g., Rails.cache)
      # - `key` (required) - Cache key for storage (e.g., "wizard:user_123")
      # - `namespace` (optional) - Cache namespace prefix
      # - `expires_in` (optional) - TTL in seconds or ActiveSupport::Duration
      # - `encrypted` (optional) - Enable encryption (default: false)
      # - `encryptor` (optional) - Encryptor instance (required if encrypted: true)
      #
      # ## Encryption
      #
      # When `encrypted: true`, all string values are encrypted before storage
      # and decrypted transparently on read. Non-string values (nil, integers, booleans)
      # are NOT encrypted, only stored as-is.
      #
      # To use encryption, provide an encryptor implementing:
      # - `encrypt_and_sign(value)` → encrypted string
      # - `decrypt_and_verify(value)` → original value
      #
      # Raises `RuntimeError` if decryption fails.
      #
      # ## Inheritance
      #
      # Inherits from Base and implements the repository pattern for cache storage.
      # The Base class handles all encryption/decryption orchestration.
      #
      # @example Basic usage (no encryption)
      #   repository = DfE::Wizard::Repository::Cache.new(
      #     cache: Rails.cache,
      #     key: "wizard:assign_mentor:user_123"
      #   )
      #   repository.write({ first_name: 'John', last_name: 'Doe' })
      #   repository.read  # => { first_name: 'John', last_name: 'Doe' }
      #
      # @example With namespace for multiple wizards
      #   repository = DfE::Wizard::Repository::Cache.new(
      #     cache: Rails.cache,
      #     key: "wizard:data",
      #     namespace: "user_#{user_id}:wizard_session"
      #   )
      #
      # @example With expiration
      #   repository = DfE::Wizard::Repository::Cache.new(
      #     cache: Rails.cache,
      #     key: "wizard:temporary",
      #     expires_in: 1.hour
      #   )
      #
      # @example With encryption
      #   encryptor = Rails.application.message_encryptor
      #   repository = DfE::Wizard::Repository::Cache.new(
      #     cache: Rails.cache,
      #     key: "wizard:sensitive",
      #     encrypted: true,
      #     encryptor: encryptor
      #   )
      #   repository.write({ ssn: '123-45-6789' })  # Encrypted in cache
      #   repository.read[:ssn]                      # => '123-45-6789' (decrypted)
      #
      # @api public
      class Cache < Base
        attr_reader :cache, :cache_key, :namespace, :expires_in

        # Initialize cache repository
        #
        # @param cache [ActiveSupport::Cache::Store] Rails cache instance
        # @param key [String] Cache key for storage
        # @param namespace [String, nil] Optional namespace prefix
        # @param expires_in [Integer, ActiveSupport::Duration, nil] TTL in seconds
        # @param encrypted [Boolean] Enable encryption (default: false)
        # @param encryptor [Object, nil] Encryptor instance (required if encrypted: true)
        #
        # @return [void]
        #
        # @raise [ArgumentError] if cache is nil
        # @raise [ArgumentError] if key is nil
        # @raise [ArgumentError] if encrypted: true but no encryptor provided
        #
        # @example
        #   cache = Rails.cache
        #   repository = DfE::Wizard::Repository::Cache.new(
        #     cache: cache,
        #     key: "wizard:user:123"
        #   )
        def initialize(cache:, key:, namespace: nil, expires_in: nil, encrypted: false, encryptor: nil)
          raise ArgumentError, 'cache cannot be nil' if cache.nil?
          raise ArgumentError, 'key cannot be nil' if key.nil?

          super(encrypted: encrypted, encryptor: encryptor)
          @cache = cache
          @cache_key = key
          @namespace = namespace
          @expires_in = expires_in
        end

        # Check if wizard data exists in cache
        #
        # @return [Boolean] true if data exists in cache
        def exists?
          @cache.exist?(@cache_key, namespace: @namespace)
        end

        # Refresh the expiration timer on cached data
        #
        # Only works if the cache store supports touch (e.g., Redis, Memcached).
        # Memory store does not support touch.
        #
        # @return [Boolean] true if expiration was refreshed, false if not supported
        #
        # @example
        #   if repository.refresh_expiration
        #     puts "Cache expiration refreshed"
        #   else
        #     puts "Cache store doesn't support expiration refresh"
        #   end
        def refresh_expiration
          return false unless @expires_in
          return false unless @cache.respond_to?(:touch)

          @cache.touch(@cache_key, namespace: @namespace, expires_in: @expires_in)
        end

        # Read raw data from cache
        #
        # Called by Base#read to fetch raw (potentially encrypted) data.
        # Symbolizes keys for Ruby convenience.
        #
        # @return [Hash] Raw data from cache (empty hash if not cached)
        # @api public
        def read_data
          data = @cache.read(@cache_key, namespace: @namespace)
          data ? data.deep_symbolize_keys : {}
        end

        # Write raw data to cache
        #
        # Called by Base#write to persist raw (potentially encrypted) data.
        # Respects namespace and expiration settings.
        #
        # @param hash [Hash] Raw data to write
        # @return [void]
        # @api public
        def write_data(hash)
          @cache.write(
            @cache_key,
            hash,
            namespace: @namespace,
            expires_in: @expires_in,
          )
        end

        # Delete data from cache
        #
        # Called by Base#clear to remove all wizard data.
        #
        # @return [void]
        # @api public
        def delete_data
          @cache.delete(@cache_key, namespace: @namespace)
        end

        # Transform data before encryption
        #
        # Converts symbol keys to string keys for Rails cache compatibility.
        # Called by Base#write before encryption.
        #
        # @param data [Hash] Data to transform
        # @return [Hash] Transformed data with string keys
        # @api public
        def transform_for_write(data)
          data.deep_stringify_keys
        end
      end
    end
  end
end
