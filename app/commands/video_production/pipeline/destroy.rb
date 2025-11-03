class VideoProduction::Pipeline::Destroy
  include Mandate

  initialize_with :pipeline

  def call
    # Cascade deletion is handled by the foreign key constraint (on_delete: :cascade)
    # All associated nodes will be automatically deleted
    pipeline.destroy!
  end
end
