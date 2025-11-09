class VideoProduction::Pipeline::Create
  include Mandate

  initialize_with :params

  def call
    VideoProduction::Pipeline.create!(params)
  end
end
