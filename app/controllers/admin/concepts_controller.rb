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
    render_422(:validation_error, errors: e.record.errors.as_json)
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
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def destroy
    @concept.destroy!
    head :no_content
  end

  private
  def use_concept
    @concept = Concept.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:concept_not_found)
  end

  def concept_params
    params.require(:concept).permit(
      :title,
      :slug,
      :description,
      :content_markdown,
      :parent_concept_id
    )
  end
end
