class Admin::ConceptsController < Admin::BaseController
  before_action :use_concept, only: %i[show update destroy]

  def index
    concepts = Concept::Search.(
      title: params[:title],
      page: params[:page],
      per: params[:per]
    )

    render json: SerializePaginatedCollection.(
      concepts,
      serializer: SerializeAdminConcepts
    )
  end

  def create
    concept = Concept::Create.(concept_params)
    render json: {
      concept: SerializeAdminConcept.(concept)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def show
    render json: {
      concept: SerializeAdminConcept.(@concept)
    }
  end

  def update
    concept = Concept::Update.(@concept, concept_params)
    render json: {
      concept: SerializeAdminConcept.(concept)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e)
  end

  def destroy
    @concept.destroy!
    head :no_content
  end

  private
  def use_concept
    @concept = Concept.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Concept not found")
  end

  def concept_params
    params.require(:concept).permit(
      :title,
      :slug,
      :description,
      :content_markdown,
      :standard_video_provider,
      :standard_video_id,
      :premium_video_provider,
      :premium_video_id,
      :parent_concept_id
    )
  end
end
