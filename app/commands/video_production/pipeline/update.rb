class VideoProduction::Pipeline::Update
  include Mandate

  initialize_with :pipeline, :attributes

  def call
    pipeline.update!(attributes)
    pipeline
  end
end
