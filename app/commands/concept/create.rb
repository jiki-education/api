class Concept::Create
  include Mandate

  initialize_with :attributes

  def call
    Concept.create!(attributes)
  end
end
