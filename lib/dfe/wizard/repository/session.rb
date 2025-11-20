# frozen_string_literal: true

module DfE
  module Wizard
    module Repository
      class Session
        attr_reader :session, :key, :state_key

        def initialize(session:, key: :wizard_store, state_key: nil)
          @session = session
          @key = key
          @state_key = state_key
        end

        def read
          data = session[key] || {}
          result = state_key ? (data[state_key] || {}) : data
          result.with_indifferent_access
        end

        def write(hash)
          normalized = hash.deep_stringify_keys

          if state_key
            current_data = session[key] || {}
            current_state = current_data[state_key] || {}
            session[key] = current_data.merge(state_key => current_state.deep_merge(normalized))
          else
            current = session[key] || {}
            session[key] = current.deep_merge(normalized)
          end
        end

        def save(hash)
          normalized = hash.deep_stringify_keys.deep_dup

          if state_key
            current_data = session[key] || {}
            session[key] = current_data.merge(state_key => normalized)
          else
            session[key] = normalized
          end
        end

        def clear
          if state_key
            current_data = session[key]
            current_data&.delete(state_key)
          else
            session.delete(key)
          end
        end
      end
    end
  end
end
