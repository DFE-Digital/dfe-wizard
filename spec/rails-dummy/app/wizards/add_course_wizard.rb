class AddCourseWizard
  include DfE::Wizard

  delegate :further_education?,
           :further_education_and_skip_applications_open?,
           :design_technology?,
           :modern_languages?,
           :physics?,
           :fee_based?,
           :no_visa_sponsorship?,
           :visa_deadline_required?,
           to: :state_store

  def steps_processor
    @steps_processor ||= DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node(:level, Steps::Courses::Level)
      graph.add_node(:subjects, Steps::Courses::Subjects)

      # Specialism steps
      graph.add_node(:design_technology, Steps::Courses::DesignTechnology)
      graph.add_node(:modern_languages, Steps::Courses::ModernLanguages)
      graph.add_node(:engineers_teach_physics, Steps::Courses::EngineersTeachPhysics)

      # Common steps for all types
      graph.add_node(:age_range, Steps::Courses::AgeRange)
      graph.add_node(:outcome, Steps::Courses::Outcome)
      graph.add_node(:funding_type, Steps::Courses::FundingType)
      graph.add_node(:full_or_part_time, Steps::Courses::FullOrPartTime)
      graph.add_node(:school, Steps::Courses::School)
      graph.add_node(:study_site, Steps::Courses::StudySite)

      # Course-type specific steps
      graph.add_node(:accredited_provider, Steps::Courses::AccreditedProvider)
      graph.add_node(:can_sponsor_student_visa, Steps::Courses::CanSponsorStudentVisa)
      graph.add_node(:can_sponsor_skilled_worker_visa, Steps::Courses::CanSponsorSkilledWorkerVisa)
      graph.add_node(:visa_sponsorship_application_deadline_required, Steps::Courses::VisaSponsorshipDeadlineRequired)
      graph.add_node(:visa_sponsorship_application_deadline_at, Steps::Courses::VisaSponsorshipDeadlineAt)
      graph.add_node(:applications_open, Steps::Courses::ApplicationsOpen)

      # Final steps
      graph.add_node(:start_date, Steps::Courses::StartDate)
      graph.add_node(:review, Steps::Courses::Review)
      graph.add_node(:courses_list, DfE::Wizard::Redirect)

      # Root entry point
      graph.root(:level)

      # =====================================================
      # ENTRY POINT: Level determines entire flow path
      # =====================================================
      graph.add_multiple_conditional_edges(
        from: :level,
        branches: [
          { when: :further_education?, then: :outcome, label: 'Further Education' },
        ],
        default: :subjects,
      )

      # =====================================================
      # FLOW 1: FURTHER EDUCATION
      # =====================================================
      # level → outcome → funding_type → full_or_part_time → school → study_site
      graph.add_edge(from: :outcome,          to: :funding_type)
      graph.add_edge(from: :funding_type,     to: :full_or_part_time)
      graph.add_edge(from: :full_or_part_time, to: :school)
      graph.add_edge(from: :school, to: :study_site)

      # =====================================================
      # FLOW 2 & 3: SCHOOL DIRECT + UNI/SCITT (Shared specialism path)
      # =====================================================
      # subjects → specialism → age_range → outcome → funding_type → full_or_part_time → school → study_site
      graph.add_multiple_conditional_edges(
        from: :subjects,
        branches: [
          { when: :design_technology?, then: :design_technology,       label: 'Design Technology' },
          { when: :modern_languages?,  then: :modern_languages,        label: 'Modern Languages' },
          { when: :physics?,           then: :engineers_teach_physics, label: 'Physics' },
        ],
      )

      graph.add_edge(from: :design_technology,       to: :age_range)
      graph.add_edge(from: :modern_languages,        to: :age_range)
      graph.add_edge(from: :engineers_teach_physics, to: :age_range)

      graph.add_edge(from: :age_range, to: :outcome)
      # outcome → funding_type → full_or_part_time → school → study_site already defined above

      # =====================================================
      # CRITICAL POINT: study_site routes all flows
      # =====================================================
      # FE → applications_open
      # SD (single provider, fee_based)     → can_sponsor_student_visa
      # SD (single provider, non-fee)      → can_sponsor_skilled_worker_visa
      # SD (multi provider)                → accredited_provider
      # Uni/SCITT (fee_based)              → can_sponsor_student_visa
      # Uni/SCITT (non-fee)                → can_sponsor_skilled_worker_visa
      graph.add_multiple_conditional_edges(
        from: :study_site,
        branches: [
          {
            when: :further_education_and_skip_applications_open?,
            then: :start_date,
          },
          {
            when: :further_education?,
            then: :applications_open,
          },
        ],
        default: :accredited_provider,
      )

      # =====================================================
      # SCHOOL DIRECT (multi provider): Accredited Provider routing
      # =====================================================
      # Accredited provider always goes to the *first* visa step,
      # chosen by fee_based? (matches visas_to_remove behaviour)
      graph.add_conditional_edge(
        from: :accredited_provider,
        when: :fee_based?,
        then: :can_sponsor_student_visa,
        else: :can_sponsor_skilled_worker_visa,
      )

      # =====================================================
      # VISA SPONSORSHIP: match visas_to_remove + sponsorship_application_steps_to_remove
      # =====================================================
      # If no_visa_sponsorship? → skip all sponsorship steps, straight to applications_open
      # Otherwise:
      #   - from first visa bool → either:
      #       * applications_open (no_visa_sponsorship?) OR
      #       * visa_sponsorship_application_deadline_required
      #
      graph.add_multiple_conditional_edges(
        from: :can_sponsor_student_visa,
        branches: [
          {
            when: :no_visa_sponsorship?,
            then: :applications_open,
            label: 'No visa sponsorship → skip sponsorship',
          },
        ],
        default: :visa_sponsorship_application_deadline_required,
      )

      graph.add_multiple_conditional_edges(
        from: :can_sponsor_skilled_worker_visa,
        branches: [
          {
            when: :no_visa_sponsorship?,
            then: :applications_open,
            label: 'No visa sponsorship → skip sponsorship',
          },
        ],
        default: :visa_sponsorship_application_deadline_required,
      )

      # Deadline required step:
      # - if visa_deadline_required? → go to deadline_at
      # - else                      → go straight to applications_open
      graph.add_conditional_edge(
        from: :visa_sponsorship_application_deadline_required,
        when: :visa_deadline_required?,
        then: :visa_sponsorship_application_deadline_at,
        else: :applications_open,
      )

      # Date entry always leads to applications_open
      graph.add_edge(
        from: :visa_sponsorship_application_deadline_at,
        to: :applications_open,
      )

      # =====================================================
      # FINAL CONVERGENCE: All flows merge here
      # =====================================================
      graph.add_edge(from: :applications_open, to: :start_date)
      graph.add_edge(from: :start_date,       to: :review)
      graph.add_edge(from: :review,           to: :courses_list)
    end
  end

  def logger
    DfE::Wizard::Logger.new(Rails.logger)
  end

  def inspect
    DfE::Wizard::Inspect.new(wizard: self).inspect if Rails.env.local?
  end
end
