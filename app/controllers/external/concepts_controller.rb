class External::ConceptsController < ApplicationController
  before_action :use_concept!, only: [:show]

  def index
    concepts = Concept::Search.(
      title: params[:title],
      parent_slug: params[:parent_slug],
      page: params[:page],
      per: params[:per],
      user: nil
    )

    render json: SerializePaginatedCollection.(
      concepts,
      serializer: SerializeConcepts
    )
  end

  def show
    render json: {
      concept: SerializeConcept.(@concept)
    }
  end
end
