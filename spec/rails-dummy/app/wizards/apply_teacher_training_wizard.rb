class ApplyTeacherTrainingWizard
  include DfE::Wizard

  delegate :know_the_course_to_apply?,
           :completed?,
           :reapplication_limit_reached?,
           :duplicate_course?,
           :course_closed?,
           :course_unavailable?,
           :multiple_study_modes?,
           :multiple_schools?,
           to: :state_store

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node :do_you_know_the_course, Steps::DoYouKnowTheCourse
      graph.add_node :go_to_find_explanation, Steps::GoToFindExplanation
      graph.add_node :provider_selection, Steps::ProviderSelection
      graph.add_node :course_selection, Steps::CourseSelection
      graph.add_node :reached_reapplication_limit, Steps::ReachedReapplicationLimit
      graph.add_node :duplicate_course_selection, Steps::DuplicateCourseSelection
      graph.add_node :closed_course_selection, Steps::ClosedCourseSelection
      graph.add_node :full_course_selection, Steps::FullCourseSelection
      graph.add_node :study_mode_selection, Steps::StudyModeSelection
      graph.add_node :school_selection, Steps::SchoolSelection
      graph.add_node :review, Steps::ApplyReview
      graph.add_node :confirm_apply, Steps::ConfirmApply
      graph.add_node :application_choices_list, DfE::Wizard::Redirect

      graph.root :do_you_know_the_course

      graph.add_conditional_edge(
        from: :do_you_know_the_course,
        when: :know_the_course_to_apply?,
        then: :provider_selection,
        else: :go_to_find_explanation,
      )

      graph.add_edge from: :provider_selection, to: :course_selection

      graph.add_multiple_conditional_edges(
        from: :course_selection,
        branches: [
          { when: :reapplication_limit_reached?, then: :reached_reapplication_limit },
          { when: :duplicate_course?, then: :duplicate_course_selection },
          { when: :course_closed?, then: :closed_course_selection },
          { when: :course_unavailable?, then: :full_course_selection },
          { when: :completed?, then: :review },
          { when: :multiple_study_modes?, then: :study_mode_selection },
          { when: :multiple_schools?, then: :school_selection },
        ],
        default: :study_mode_selection,
      )

      graph.add_conditional_edge(
        from: :study_mode_selection,
        when: :completed?,
        then: :review,
        else: :school_selection,
      )

      graph.add_edge from: :school_selection, to: :review

      graph.add_edge from: :review, to: :confirm_apply
      graph.add_edge from: :confirm_apply, to: :application_choices_list
    end
  end

  def steps_operator
    DfE::Wizard::StepsOperator::Builder.draw(wizard: self) do |builder|
      builder.on_step(
        :course_selection,
        use: [
          DfE::Wizard::Operations::Validate,
          StepOperations::CreateApplicationChoice,
        ],
      )
      builder.on_step(
        :study_mode,
        use: [
          DfE::Wizard::Operations::Validate,
          StepOperations::UpdateApplicationChoiceStudyMode,
        ],
      )
      builder.on_step(
        :school_selection,
        use: [
          DfE::Wizard::Operations::Validate,
          StepOperations::UpdateApplicationChoiceSchool,
        ],
      )
      builder.on_step(
        :confirm_apply,
        use: [StepOperations::SubmitApplicationChoice],
      )
    end
  end
end
