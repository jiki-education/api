class Concept::Update
  include Mandate

  initialize_with :concept, :attributes

  def call
    concept.update!(attributes)
    concept
  end
end
