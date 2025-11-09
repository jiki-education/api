class Admin::VideoProduction::PipelinesController < Admin::BaseController
  before_action :use_pipeline, only: %i[show update destroy]

  def index
    pipelines = VideoProduction::Pipeline.
      order(updated_at: :desc).
      page(params[:page]).
      per(params[:per] || 25)

    render json: SerializePaginatedCollection.(
      pipelines,
      serializer: SerializeAdminVideoProductionPipelines
    )
  end

  def show
    render json: {
      pipeline: SerializeAdminVideoProductionPipeline.(@pipeline)
    }
  end

  def create
    pipeline = VideoProduction::Pipeline::Create.(pipeline_params.to_h)
    render json: {
      pipeline: SerializeAdminVideoProductionPipeline.(pipeline)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def update
    pipeline = VideoProduction::Pipeline::Update.(@pipeline, pipeline_params.to_h)
    render json: {
      pipeline: SerializeAdminVideoProductionPipeline.(pipeline)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def destroy
    VideoProduction::Pipeline::Destroy.(@pipeline)
    head :no_content
  end

  private
  def use_pipeline
    @pipeline = VideoProduction::Pipeline.find_by!(uuid: params[:uuid])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Pipeline not found")
  end

  def pipeline_params
    params.require(:pipeline).permit(:title, :version, config: {}, metadata: {})
  end
end
