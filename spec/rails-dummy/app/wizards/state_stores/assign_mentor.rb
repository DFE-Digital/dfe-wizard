module StateStores
  class AssignMentor
    include DfE::Wizard::StateStore

    def lead_provider_will_not_provide?
      lp_will_provide == 'no'
    end

    #    def mentor
    #      Steps::WhoWillBeTheMentor.eligible_mentors.find { |mentor| mentor.id == mentor_id.to_i }
    #    end
  end
end
