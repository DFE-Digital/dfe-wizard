module DfE
  module Wizard
    module Repository
      # Redis-backed repository for wizard state storage
      #
      # Stores wizard data in Redis with automatic expiration and JSON serialization.
      # Supports optional nested state structure for multi-wizard scenarios.
      #
      # @example Basic usage
      #   repo = DfE::Wizard::Repository::Redis.new(
      #     redis: Redis.new,
      #     key: "wizard:assign_mentor:user_123"
      #   )
      #
      # @example With expiration
      #   repo = DfE::Wizard::Repository::Redis.new(
      #     redis: Redis.new,
      #     key: "wizard:user_123",
      #     expiration: 24.hours
      #   )
      #
      # @example Nested state (multiple wizards per user)
      #   repo = DfE::Wizard::Repository::Redis.new(
      #     redis: Redis.new,
      #     key: "wizards:user_123",
      #     state_key: params[:state_key] || SecureRandom.uuid
      #   )
      class Redis
        attr_reader :redis, :key, :state_key, :expiration

        # @param redis [Redis, ConnectionPool] Redis client or connection pool
        # @param key [String] Redis key for storage
        # @param state_key [String, nil] Optional nested key for multi-wizard scenarios
        # @param expiration [Integer, ActiveSupport::Duration, nil] TTL in seconds
        def initialize(redis:, key:, state_key: nil, expiration: nil)
          raise ArgumentError, 'redis cannot be nil' if redis.nil?
          raise ArgumentError, 'key cannot be nil' if key.nil?

          @redis = redis
          @key = key
          @state_key = state_key
          @expiration = normalize_expiration(expiration)
        end

        # Read wizard data from Redis
        #
        # @return [Hash] Flat hash of wizard attributes
        def read
          with_redis do |conn|
            json_data = conn.get(key)
            return {} if json_data.nil?

            parsed = JSON.parse(json_data)
            if state_key
              parsed.fetch(state_key, {}).deep_symbolize_keys
            else
              parsed.deep_symbolize_keys
            end
          end
        end

        # Write wizard data to Redis
        #
        # @param hash [Hash] Flat hash of attributes to merge
        # @return [void]
        def write(hash)
          normalized = hash.deep_stringify_keys
          with_redis do |conn|
            if state_key
              write_nested(conn, normalized)
            else
              write_flat(conn, normalized)
            end
          end
        end

        # Save state atomically by replacing entire data
        #
        # @param hash [Hash] Complete state to save
        # @return [void]
        def save(hash)
          normalized = hash.deep_stringify_keys
          with_redis do |conn|
            if state_key
              save_nested(conn, normalized)
            else
              save_flat(conn, normalized)
            end
          end
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

        # Clear all wizard data from Redis
        #
        # @return [void]
        def clear
          with_redis do |conn|
            conn.del(key)
          end
        end

        # Check if wizard data exists
        #
        # @return [Boolean]
        def exists?
          with_redis do |conn|
            conn.exists?(key)
          end
        end

        # Get remaining TTL
        #
        # @return [Integer, nil] Seconds until expiration, nil if no expiration
        def ttl
          with_redis do |conn|
            ttl_value = conn.ttl(key)
            ttl_value >= 0 ? ttl_value : nil
          end
        end

        # Refresh expiration timer
        #
        # @return [Boolean] true if expiration was set
        def refresh_expiration
          return false unless expiration

          with_redis do |conn|
            conn.expire(key, expiration)
          end
        end

        private

        def normalize_expiration(value)
          return nil if value.nil?
          return value if value.is_a?(Integer)

          value.respond_to?(:to_i) ? value.to_i : value
        end

        def with_redis(&)
          if redis.is_a?(ConnectionPool)
            redis.with(&)
          else
            yield redis
          end
        end

        def write_flat(conn, normalized)
          current_json = conn.get(key)
          current_data = current_json ? JSON.parse(current_json) : {}
          merged_data = current_data.merge(normalized)
          json_output = JSON.generate(merged_data)
          if expiration
            conn.setex(key, expiration, json_output)
          else
            conn.set(key, json_output)
          end
        end

        def write_nested(conn, normalized)
          current_json = conn.get(key)
          current_data = current_json ? JSON.parse(current_json) : {}
          current_state = current_data.fetch(state_key, {})
          merged_state = current_state.merge(normalized)
          current_data[state_key] = merged_state
          json_output = JSON.generate(current_data)
          if expiration
            conn.setex(key, expiration, json_output)
          else
            conn.set(key, json_output)
          end
        end

        def save_flat(conn, normalized)
          json_output = JSON.generate(normalized)
          if expiration
            conn.setex(key, expiration, json_output)
          else
            conn.set(key, json_output)
          end
        end

        def save_nested(conn, normalized)
          current_json = conn.get(key)
          current_data = current_json ? JSON.parse(current_json) : {}
          current_data[state_key] = normalized
          json_output = JSON.generate(current_data)
          if expiration
            conn.setex(key, expiration, json_output)
          else
            conn.set(key, json_output)
          end
        end
      end
    end
  end
end
