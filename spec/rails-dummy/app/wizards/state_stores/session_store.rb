module StateStores
  class SessionStore
    def initialize(session, wizard_name)
      @session = session
      @wizard_name = wizard_name

      @session[@wizard_name] ||= {}
    end

    def read
      @session[@wizard_name].deep_dup
    end

    def write(data)
      @session[@wizard_name].deep_merge!(data)
    end
  end
end
