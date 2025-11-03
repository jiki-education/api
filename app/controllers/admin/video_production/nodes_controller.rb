class Admin::VideoProduction::NodesController < Admin::BaseController
  before_action :use_pipeline
  before_action :use_node, only: %i[show update destroy execute output]

  def index
    nodes = @pipeline.nodes.order(:created_at)

    render json: {
      nodes: SerializeAdminVideoProductionNodes.(nodes)
    }
  end

  def show
    render json: {
      node: SerializeAdminVideoProductionNode.(@node)
    }
  end

  def create
    node = VideoProduction::Node::Create.(
      @pipeline,
      params.require(:node).permit(:title, :type, inputs: {}, config: {}, asset: {})
    )
    render json: {
      node: SerializeAdminVideoProductionNode.(node)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def update
    node = VideoProduction::Node::Update.(
      @node,
      params.require(:node).permit(:title, inputs: {}, config: {}, asset: {})
    )
    render json: {
      node: SerializeAdminVideoProductionNode.(node)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def destroy
    VideoProduction::Node::Destroy.(@node)
    head :no_content
  end

  def execute
    node = VideoProduction::Node::Execute.(@node)
    render json: {
      node: SerializeAdminVideoProductionNode.(node)
    }
  rescue VideoProductionBadInputsError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def output
    presigned_url = VideoProduction::Node::GenerateOutputUrl.(@node)
    redirect_to presigned_url, allow_other_host: true
  rescue VideoProduction::Node::GenerateOutputUrl::NoOutputError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private
  def use_pipeline
    @pipeline = VideoProduction::Pipeline.find_by!(uuid: params[:pipeline_uuid])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Pipeline not found")
  end

  def use_node
    @node = @pipeline.nodes.find_by!(uuid: params[:uuid])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Node not found")
  end
end
