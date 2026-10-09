RSpec.describe DfE::Wizard::StepsProcessor::Graph, 'check answers and depends_on' do
  include SubWizardSpecHelpers

  module JourneyGraphSpecSteps
    class Reserved
      include DfE::Wizard::Step

      attribute :_dfe_wizard, :string
    end
  end

  def draw(&block)
    build_wizard(store: SubWizardSpecStore.new(repository: DfE::Wizard::Repository::InMemory.new), &block)
      .steps_processor
  end

  def with_check_answers(graph)
    graph.add_node :check_answers, SubWizardSpecSteps::Review
    graph.check_answers :check_answers
  end

  describe 'graph.check_answers' do
    it 'records the node' do
      graph = draw do |g|
        parent_nodes(g)
        with_check_answers(g)
      end

      expect(graph.check_answers_step).to eq(:check_answers)
    end

    it 'is nil when not declared' do
      expect(draw { |g| parent_nodes(g) }.check_answers_step).to be_nil
    end

    it 'puts the node in no unit' do
      graph = draw do |g|
        parent_nodes(g)
        with_check_answers(g)
      end

      expect(graph.unit_for(:check_answers)).to be_nil
      expect(graph.unit(:check_answers)).to be_nil
    end

    it 'raises for a node that does not exist' do
      expect do
        draw do |g|
          parent_nodes(g)
          g.check_answers :nope
        end
      end.to raise_error(DfE::Wizard::InvalidGraph, 'graph.check_answers :nope is not a node')
    end

    it 'raises when declared twice' do
      expect do
        draw do |g|
          parent_nodes(g)
          with_check_answers(g)
          g.check_answers :review
        end
      end.to raise_error(DfE::Wizard::InvalidGraph, 'graph.check_answers is declared twice')
    end

    it 'raises for a node in a sub-wizard (rule 3)' do
      expect do
        draw do |g|
          parent_nodes(g)
          g.add_sub_wizard :tail, steps: %i[start_date review]
          g.check_answers :review
        end
      end.to raise_error(DfE::Wizard::InvalidGraph,
                         'the check answers node :review is in sub-wizard :tail; it belongs to no unit')
    end

    it 'raises for a node with depends_on' do
      expect do
        draw do |g|
          parent_nodes(g)
          g.add_node :check_answers, SubWizardSpecSteps::Review, depends_on: %i[funding]
          g.check_answers :check_answers
        end
      end.to raise_error(DfE::Wizard::InvalidGraph, 'the check answers node :check_answers cannot have depends_on')
    end

    it 'raises inside a sub-wizard class (rule 5)' do
      drawer = lambda do |graph|
        graph.add_node :student, SubWizardSpecSteps::Student
        graph.check_answers :student
      end

      expect do
        draw do |g|
          parent_nodes(g)
          g.add_sub_wizard :visa, drawer, exit_to: :start_date
        end
      end.to raise_error(DfE::Wizard::InvalidGraph,
                         'sub-wizard :visa calls check_answers; a sub-wizard adds nodes and edges only')
    end
  end

  describe 'depends_on' do
    it 'is on a single-step unit' do
      graph = draw do |g|
        parent_nodes(g)
        g.add_node :student, SubWizardSpecSteps::Student, depends_on: %i[funding]
      end

      expect(graph.unit_for(:student).depends_on).to eq(%i[funding])
    end

    it 'is on a sub-wizard, in either form' do
      explicit = draw do |g|
        parent_nodes(g)
        visa_nodes(g)
        g.add_sub_wizard :visa, steps: visa_steps, depends_on: %i[funding]
      end
      class_form = draw do |g|
        parent_nodes(g)
        g.add_sub_wizard :visa, SubWizardSpecVisa, exit_to: :start_date, depends_on: %i[funding]
      end

      expect(explicit.unit_for(:deadline_at).depends_on).to eq(%i[funding])
      expect(class_form.unit(:visa).depends_on).to eq(%i[funding])
    end

    it 'is empty by default' do
      graph = draw { |g| parent_nodes(g) }

      expect(graph.unit_for(:funding).depends_on).to eq([])
    end

    it 'raises for a name that is not a step attribute' do
      expect do
        draw do |g|
          parent_nodes(g)
          g.add_node :student, SubWizardSpecSteps::Student, depends_on: %i[fundng]
        end
      end.to raise_error(DfE::Wizard::InvalidGraph, ':student: depends_on :fundng is not a step attribute')
    end

    it 'raises for a value that is not an Array of Symbols' do
      expect do
        draw do |g|
          parent_nodes(g)
          g.add_sub_wizard :visa, SubWizardSpecVisa, depends_on: 'funding'
        end
      end.to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa: depends_on must be an Array of Symbols')
    end

    it 'raises for a node in an explicit sub-wizard' do
      expect do
        draw do |g|
          parent_nodes(g)
          g.add_node :student, SubWizardSpecSteps::Student, depends_on: %i[funding]
          g.add_sub_wizard :visa, steps: %i[student]
        end
      end.to raise_error(DfE::Wizard::InvalidGraph, ':student is in a sub-wizard; declare depends_on on add_sub_wizard')
    end

    it 'raises for a node added by a sub-wizard class' do
      drawer = lambda do |graph|
        graph.add_node :student, SubWizardSpecSteps::Student, depends_on: %i[funding]
      end

      expect do
        draw do |g|
          parent_nodes(g)
          g.add_sub_wizard :visa, drawer, exit_to: :start_date
        end
      end.to raise_error(DfE::Wizard::InvalidGraph,
                         'sub-wizard :visa: depends_on on :student; declare depends_on on add_sub_wizard')
    end
  end

  it 'raises for a step attribute named _dfe_wizard, in every graph' do
    expect do
      draw do |g|
        g.add_node :reserved, JourneyGraphSpecSteps::Reserved
        g.root :reserved
      end
    end.to raise_error(DfE::Wizard::InvalidGraph,
                       'step attribute _dfe_wizard on :reserved is reserved by dfe-wizard; rename it')
  end
end
