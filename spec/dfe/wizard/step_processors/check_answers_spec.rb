RSpec.describe 'graph.check_answers' do
  subject(:wizard) { CourseChange::Wizard.new(state_store:) }

  let(:state_store) { CourseChange::StateStore.new }

  def draw(&)
    DfE::Wizard::StepsProcessor::Graph.draw(wizard, predicate_caller: state_store) do |graph|
      graph.add_node :start_date, CourseChange::Steps::StartDate
      graph.root :start_date
      yield graph
    end
  end

  it 'adds an ordinary node that edges and paths reach' do
    state_store.write(CourseChange::Wizard.complete_answers)

    expect(wizard.find_step(:check_answers)).to eq(CourseChange::Steps::CheckAnswers)
    expect(wizard.flow_path(:check_answers)).to eq(
      %i[level subject qualification funding_type student_visa deadline_required deadline_at start_date
         check_answers],
    )
  end

  it 'is the wizard check answers step' do
    expect(wizard.check_answers_step).to eq(:check_answers)
  end

  it 'is in the metadata for documentation' do
    expect(wizard.steps_processor.metadata[:check_answers_step]).to eq(:check_answers)
  end

  it 'keeps the label for documentation' do
    graph = draw { |g| g.check_answers :review, CourseChange::Steps::CheckAnswers, label: 'Check your answers' }

    expect(graph.metadata[:steps][:review][:label]).to eq('Check your answers')
  end

  it 'is nil when the graph declares none' do
    graph = draw { |_g| nil }

    expect(graph.check_answers_step).to be_nil
    expect(graph.metadata).not_to have_key(:check_answers_step)
  end

  it 'raises when declared twice' do
    expect {
      draw do |g|
        g.check_answers :review, CourseChange::Steps::CheckAnswers
        g.check_answers :summary, CourseChange::Steps::CheckAnswers
      end
    }.to raise_error(ArgumentError, 'check_answers is already declared as :review')
  end

  it 'raises when the id is already a node' do
    expect {
      draw { |g| g.check_answers :start_date, CourseChange::Steps::CheckAnswers }
    }.to raise_error(ArgumentError, ':start_date is already a node')
  end

  it 'checks the node id and class like add_node' do
    expect {
      draw { |g| g.check_answers 'review', CourseChange::Steps::CheckAnswers }
    }.to raise_error(ArgumentError, 'node_id must be a symbol, got String')
  end

  it 'is nil for a linear processor' do
    linear = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
      l.add_step :start_date, CourseChange::Steps::StartDate
    end

    expect(linear.check_answers_step).to be_nil
  end
end
