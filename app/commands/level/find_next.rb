class Level::FindNext
  include Mandate

  initialize_with :current_level

  def call
    course.levels.where("position > ?", current_level.position).order(:position).first
  end

  delegate :course, to: :current_level
end
