class Level::Update
  include Mandate

  initialize_with :level, :attributes

  def call
    level.update!(attributes)
    level
  end
end
