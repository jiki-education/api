class Level::Create
  include Mandate

  initialize_with :attributes

  def call
    Level.create!(attributes)
  end
end
