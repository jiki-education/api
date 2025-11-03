class LevelDrop < Liquid::Drop
  def initialize(level)
    super()
    @level = level
  end

  delegate :title, :description, :slug, :position, to: :@level
end
