class External::ConceptsController < ApplicationController
  before_action :use_concept!, only: [:show]

  def index
    concepts = Concept::Search.(
      query: params[:query],
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
