module StateStores
  class SessionStore
    def initialize(session, wizard_name)
      @session = session
      @wizard_name = wizard_name.to_sym

      @session[@wizard_name] ||= { steps: {} }
    end

    def read
      {
        steps: @session.dig(@wizard_name, 'steps').deep_dup,
      }.deep_symbolize_keys
    end

    # Accepts something like: { step_name => { data } }
    def write(step_data)
      step_key, step_value = step_data.first

      @session[@wizard_name]['steps'][step_key] = step_value
    end
  end
end
