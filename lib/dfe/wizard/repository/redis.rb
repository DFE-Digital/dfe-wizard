module DfE
  module Wizard
    module Repository
      # Redis-backed repository for wizard state storage.
      #
      # Stores wizard data in Redis with automatic expiration and JSON serialization.
      # Supports optional nested state structure for multi-wizard scenarios.
      #
      # @attr_reader [Redis, ConnectionPool] redis
      #   The Redis client or connection pool used for all operations.
      # @attr_reader [String] key
      #   The Redis key used as the global identifier for this wizard state.
      # @attr_reader [String, nil] state_key
      #   Optional: a nested key, allowing for multiple wizard states under the same Redis key.
      # @attr_reader [Integer, nil] expiration
      #   Optional: expiration (TTL in seconds) for the Redis key or state.
      #
      # @example Simple single-wizard usage with no expiration
      #   repo = DfE::Wizard::Repository::Redis.new(
      #     redis: Redis.new,
      #     key: "wizard:assign_mentor:user_123"
      #   )
      #   repo.write(name: "Maria")
      #   repo.read # => { name: "Maria" }
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
      #
      # @example With encryption
      #   repo = DfE::Wizard::Repository::Redis.new(
      #     redis: Redis.new,
      #     key: "wizard:user_123",
      #     encrypted: true,
      #     encryptor: MyEncryptor.new(secret)
      #   )
      #
      # @api public
      class Redis < Base
        attr_reader :redis, :key, :state_key, :expiration

        # Initialize with Redis client, key, and additional options.
        #
        # @param redis [Redis, ConnectionPool] Redis client or connection pool.
        # @param key [String] Primary Redis key for the wizard state.
        # @param state_key [String, nil] Optional nested state key (for multi-wizard support).
        # @param expiration [Integer, ActiveSupport::Duration, nil] TTL in seconds or duration.
        # @param encrypted [Boolean] Enable encryption (default: false).
        # @param encryptor [Object, nil] Encryptor instance (required if encrypted: true).
        #
        # @raise [ArgumentError] if redis or key are nil.
        def initialize(redis:, key:, state_key: nil, expiration: nil, encrypted: false, encryptor: nil)
          raise ArgumentError, 'redis cannot be nil' if redis.nil?
          raise ArgumentError, 'key cannot be nil' if key.nil?

          @redis = redis
          @key = key
          @state_key = state_key
          @expiration = normalize_expiration(expiration)

          super(encrypted: encrypted, encryptor: encryptor)
        end

        # @return [Boolean] Whether the primary Redis key exists.
        def exists?
          with_redis { |conn| conn.exists?(@key) }
        end

        # @return [Integer, nil] Time-to-live in seconds for the Redis key, or nil if not set.
        def ttl
          with_redis do |conn|
            ttl_value = conn.ttl(@key)
            ttl_value >= 0 ? ttl_value : nil
          end
        end

        # Refresh the expiration TTL on the Redis key.
        # @return [Boolean] True if expiration was set, false if not configured.
        def refresh_expiration
          return false unless @expiration

          with_redis { |conn| conn.expire(@key, @expiration) }
        end

        # @api public
        # @return [Hash] Raw (possibly encrypted) data stored in Redis, symbolized keys.
        def read_data
          with_redis do |conn|
            json_data = conn.get(@key)
            return {} if json_data.nil?

            parsed = JSON.parse(json_data)
            @state_key ? parsed.fetch(@state_key, {}).deep_symbolize_keys : parsed.deep_symbolize_keys
          end
        end

        # @api public
        # Write raw (already-encrypted if needed) data to Redis.
        # @param hash [Hash] Flat or nested structure to persist.
        # @return [void]
        def write_data(hash)
          with_redis do |conn|
            @state_key ? write_nested(conn, hash) : write_flat(conn, hash)
          end
        end

        # Save state atomically by replacing entire data
        #
        # Overwrites all previous data. Use when you have a complete snapshot
        # or want to replace state entirely (e.g., during testing setup).
        # Data is encrypted if encryption is enabled.
        #
        # @param hash [Hash] Complete state to save
        # @return [void]
        #
        # @example Replace entire wizard state
        #   repository.save({ name: 'Jane', email: 'jane@example.com' })
        def save(hash)
          return if hash.nil?

          data_to_save = transform_for_write(hash)
          encrypted_data = encrypted? ? encrypt_hash(data_to_save) : data_to_save

          with_redis do |conn|
            if @state_key
              save_nested(conn, encrypted_data)
            else
              save_flat(conn, encrypted_data)
            end
          end
        end

        # @api public
        # Remove the wizard state from Redis.
        # @return [void]
        def delete_data
          with_redis { |conn| conn.del(@key) }
        end

        # @api public
        # Prepare data before saving (stringify keys for JSON/Redis).
        # @param data [Hash]
        # @return [Hash] Same structure with string keys.
        def transform_for_write(data)
          data.deep_stringify_keys
        end

        # @api public
        # Normalize expiration input into seconds.
        # @param value [Integer, ActiveSupport::Duration, nil]
        # @return [Integer, nil] seconds or nil.
        def normalize_expiration(value)
          return nil if value.nil?
          return value if value.is_a?(Integer)

          value.respond_to?(:to_i) ? value.to_i : value
        end

        # @api public
        # Execute Redis command, using ConnectionPool if available.
        # @yieldparam conn [Redis] The connection instance.
        def with_redis
          if @redis.is_a?(ConnectionPool)
            @redis.with { |conn| yield conn }
          else
            yield @redis
          end
        end

        # @api public
        # Merges new data with existing JSON for flat keys.
        def write_flat(conn, data)
          current_json = conn.get(@key)
          current_data = current_json ? JSON.parse(current_json) : {}
          merged_data = current_data.merge(data)
          json_output = JSON.generate(merged_data)

          persist_to_redis(json_output)
        end

        # @api public
        # Merges new nested state for state_key scenario.
        def write_nested(conn, data)
          current_json = conn.get(@key)
          current_data = current_json ? JSON.parse(current_json) : {}
          current_state = current_data.fetch(@state_key, {})
          merged_state = current_state.merge(data)
          current_data[@state_key] = merged_state
          json_output = JSON.generate(current_data)

          persist_to_redis(json_output)
        end

        # @api public
        # Save (atomic replace) for flat keys - replaces entire data
        def save_flat(_conn, data)
          json_output = JSON.generate(data)
          persist_to_redis(json_output)
        end

        # @api public
        # Save (atomic replace) for nested state - replaces only the state_key data
        def save_nested(conn, data)
          current_json = conn.get(@key)
          current_data = current_json ? JSON.parse(current_json) : {}
          current_data[@state_key] = data
          json_output = JSON.generate(current_data)

          persist_to_redis(json_output)
        end

        # @api public
        # Save into redis, passing expiration if any.
        def persist_to_redis(json)
          if @expiration
            with_redis { |conn| conn.setex(@key, @expiration, json) }
          else
            with_redis { |conn| conn.set(@key, json) }
          end
        end
      end
    end
  end
end
