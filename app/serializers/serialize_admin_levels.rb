class SerializeAdminLevels
  include Mandate

  initialize_with :levels

  def call
    levels.map { |level| SerializeAdminLevel.(level) }
  end
end
