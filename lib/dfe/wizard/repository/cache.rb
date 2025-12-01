module DfE
  module Wizard
    module Repository
      # Rails.cache-backed repository for wizard state storage
      #
      # Stores wizard data using Rails caching duck typing.
      # Works with any Rails cache store (Memory, Redis, Solid Cache, Memcached, etc.)
      #
      # @example Basic usage
      #   repo = DfE::Wizard::Repository::Cache.new(
      #     cache: Rails.cache,
      #     key: "wizard:assign_mentor:user_123"
      #   )
      #
      # @example With expiration
      #   repo = DfE::Wizard::Repository::Cache.new(
      #     cache: Rails.cache,
      #     key: "wizard:user_123",
      #     expires_in: 24.hours
      #   )
      #
      # @example With namespace
      #   repo = DfE::Wizard::Repository::Cache.new(
      #     cache: Rails.cache,
      #     key: "user_123",
      #     namespace: "wizards:assign_mentor"
      #   )
      class Cache
        attr_reader :cache, :key, :namespace, :expires_in

        # @param cache [ActiveSupport::Cache::Store] Rails cache instance
        # @param key [String] Cache key for storage
        # @param namespace [String, nil] Optional namespace prefix
        # @param expires_in [Integer, ActiveSupport::Duration, nil] TTL
        def initialize(cache:, key:, namespace: nil, expires_in: nil)
          raise ArgumentError, 'cache cannot be nil' if cache.nil?
          raise ArgumentError, 'key cannot be nil' if key.nil?

          @cache = cache
          @key = key
          @namespace = namespace
          @expires_in = expires_in
        end

        # Read wizard data from cache
        #
        # @return [Hash] Flat hash of wizard attributes
        def read
          data = cache.read(cache_key, namespace:)
          return {} if data.nil?

          data.deep_symbolize_keys
        end

        # Write wizard data to cache
        #
        # @param hash [Hash] Flat hash of attributes to merge
        # @return [void]
        def write(hash)
          normalized = hash.deep_stringify_keys
          current_data = cache.read(cache_key, namespace:) || {}
          merged_data = current_data.merge(normalized)
          cache.write(
            cache_key,
            merged_data,
            namespace:,
            expires_in:,
          )
        end

        # Save state atomically by replacing entire data
        #
        # @param hash [Hash] Complete state to save
        # @return [void]
        def save(hash)
          normalized = hash.deep_stringify_keys
          cache.write(
            cache_key,
            normalized,
            namespace:,
            expires_in:,
          )
        end

        # Execute an operation in the repository context
        #
        # Instantiates the operation class with this repository and the step,
        # then calls its `execute` method.
        #
        # @param operation_class [Class] Operation class to instantiate and execute
        #   Must respond to `new(repository:, step:).execute`
        # @param step [Object] Step instance containing data to operate on
        # @return [Hash] Operation result hash
        #   - `:success` [Boolean] Whether operation succeeded
        #   - `:errors` [Hash] Validation errors if success is false
        #
        # @example Execute validation operation
        #   result = repo.execute_operation(
        #     operation_class: DfE::Wizard::Operations::Validate,
        #     step: step_instance
        #   )
        #   # => { success: true } or { success: false, errors: {...} }
        #
        # @example Execute persistence operation
        #   result = repo.execute_operation(
        #     operation_class: DfE::Wizard::Operations::Persist,
        #     step: step_instance
        #   )
        #   # => { success: true }
        #
        # @see DfE::Wizard::Operations::Validate For validation operation
        # @see DfE::Wizard::Operations::Persist For persistence operation
        # @api public
        def execute_operation(operation_class:, step:)
          operation_class.new(repository: self, step:).execute
        end

        # Clear all wizard data from cache
        #
        # @return [void]
        def clear
          cache.delete(cache_key, namespace:)
        end

        # Check if wizard data exists
        #
        # @return [Boolean]
        def exists?
          cache.exist?(cache_key, namespace:)
        end

        # Refresh expiration timer
        #
        # Only works if cache store supports touch (e.g., Redis, Memcached)
        #
        # @return [Boolean] true if expiration was refreshed
        def refresh_expiration
          return false unless expires_in
          return false unless cache.respond_to?(:touch)

          cache.touch(cache_key, namespace:, expires_in:)
        end

        private

        def cache_key
          key
        end
      end
    end
  end
end
