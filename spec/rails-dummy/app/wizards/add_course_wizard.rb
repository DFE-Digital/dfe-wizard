class AddCourseWizard
  include DfE::Wizard

  delegate :further_education?,
           :applications_open_feature_flag_inactive?,
           :design_technology?,
           :modern_languages?,
           :physics?,
           :teacher_degree_apprenticeship?,
           :single_accredited_provider_or_self_accredited?,
           :fee_based?,
           :can_sponsor_student_visa?,
           :can_sponsor_skilled_worker_visa?,
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
      graph.add_node(
        :accredited_provider, Steps::Courses::AccreditedProvider,
        skip_when: :single_accredited_provider_or_self_accredited?
      )

      graph.add_node(:can_sponsor_student_visa, Steps::Courses::CanSponsorStudentVisa)
      graph.add_node(:can_sponsor_skilled_worker_visa, Steps::Courses::CanSponsorSkilledWorkerVisa)
      graph.add_node(:visa_sponsorship_application_deadline_required, Steps::Courses::VisaSponsorshipDeadlineRequired)
      graph.add_node(:visa_sponsorship_application_deadline_at, Steps::Courses::VisaSponsorshipDeadlineAt)
      graph.add_node(
        :applications_open, Steps::Courses::ApplicationsOpen,
        skip_when: :applications_open_feature_flag_inactive?
      )

      # Final steps
      graph.add_node(:start_date, Steps::Courses::StartDate)
      graph.add_node(:review, Steps::Courses::Review)
      graph.add_node(:courses_list, DfE::Wizard::Redirect)

      # Root entry point
      graph.root(:level)

      graph.add_multiple_conditional_edges(
        from: :level,
        branches: [
          { when: :further_education?, then: :outcome },
        ],
        default: :subjects,
      )

      graph.add_conditional_edge(
        from: :outcome,
        when: :teacher_degree_apprenticeship?,
        then: :school,
        else: :funding_type,
      )

      graph.add_edge(from: :funding_type, to: :full_or_part_time)
      graph.add_edge(from: :full_or_part_time, to: :school)
      graph.add_edge(from: :school, to: :study_site)

      graph.add_multiple_conditional_edges(
        from: :subjects,
        branches: [
          { when: :design_technology?, then: :design_technology },
          { when: :modern_languages?,  then: :modern_languages },
          { when: :physics?,           then: :engineers_teach_physics },
        ],
        default: :age_range,
      )

      graph.add_edge(from: :design_technology,       to: :age_range)
      graph.add_edge(from: :modern_languages,        to: :age_range)
      graph.add_edge(from: :engineers_teach_physics, to: :age_range)

      graph.add_edge(from: :age_range, to: :outcome)

      graph.add_conditional_edge(
        from: :study_site,
        when: :further_education?,
        then: :applications_open,
        else: :accredited_provider,
      )

      graph.add_multiple_conditional_edges(
        from: :accredited_provider,
        branches: [
          {
            when: :teacher_degree_apprenticeship?,
            then: :applications_open,
          },
          {
            when: :fee_based?,
            then: :can_sponsor_student_visa,
          },
        ],
        default: :can_sponsor_skilled_worker_visa,
      )

      graph.add_conditional_edge(
        from: :can_sponsor_student_visa,
        when: :can_sponsor_student_visa?,
        then: :visa_sponsorship_application_deadline_required,
        else: :applications_open,
      )

      graph.add_conditional_edge(
        from: :can_sponsor_skilled_worker_visa,
        when: :can_sponsor_skilled_worker_visa?,
        then: :visa_sponsorship_application_deadline_required,
        else: :applications_open,
      )

      graph.add_conditional_edge(
        from: :visa_sponsorship_application_deadline_required,
        when: :visa_deadline_required?,
        then: :visa_sponsorship_application_deadline_at,
        else: :applications_open,
      )

      graph.add_edge(
        from: :visa_sponsorship_application_deadline_at,
        to: :applications_open,
      )

      graph.add_edge(from: :applications_open, to: :start_date)
      graph.add_edge(from: :start_date,       to: :review)
      graph.add_edge(from: :review,           to: :courses_list)
    end
  end

  def route_strategy
    RouteStrategy::DynamicRoutes.new(
      state_store:,
      path_builder: lambda { |step_id, state_store, url_helpers, opts|
        url_helpers.step_recruitment_cycle_provider_add_course_courses_path(
          recruitment_cycle_year: state_store.recruitment_cycle_year,
          provider_code: state_store.provider_code,
          state_key: state_store.state_key,
          step: step_id,
          **opts,
        )
      },
    )
  end

  def logger
    DfE::Wizard::Logger.new(Rails.logger)
  end

  def inspect
    DfE::Wizard::Inspect.new(wizard: self).inspect if Rails.env.local?
  end
end
