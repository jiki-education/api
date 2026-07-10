class Challenge::Create
  include Mandate

  initialize_with :attributes

  def call
    Challenge.create!(attributes)
  end
end
