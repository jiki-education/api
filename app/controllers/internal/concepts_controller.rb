class Internal::ConceptsController < Internal::BaseController
  before_action :use_concept!, only: [:show]

  def index
    concepts = Concept::Search.(
      title: params[:title],
      slugs: params[:slugs],
      parent_slug: params[:parent_slug],
      page: params[:page],
      per: params[:per],
      user: current_user
    )

    render json: SerializePaginatedCollection.(
      concepts,
      serializer: SerializeConcepts,
      serializer_kwargs: { for_user: current_user },
      meta: { unlocked_count: current_user.unlocked_concept_ids.count }
    )
  end

  def show
    return render_403(:concept_locked) unless current_user.unlocked_concept_ids.include?(@concept.id)

    render json: {
      concept: SerializeConcept.(@concept)
    }
  end
end
