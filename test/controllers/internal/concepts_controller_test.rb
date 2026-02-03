require "test_helper"

class Internal::ConceptsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_concepts_path, method: :get
  guard_incorrect_token! :internal_concept_path, args: ["some-concept"], method: :get

  # GET /v1/concepts (index) tests
  test "GET index returns all concepts ordered by unlocked first" do
    Prosopite.finish
    concept_arrays = create(:concept, title: "Arrays")
    concept_strings = create(:concept, title: "Strings")
    concept_hashes = create(:concept, title: "Hashes")

    Concept::UnlockForUser.(concept_arrays, @current_user)
    Concept::UnlockForUser.(concept_hashes, @current_user)

    get internal_concepts_path, as: :json

    assert_response :success
    # Unlocked first (Arrays, Hashes alphabetically), then locked (Strings)
    assert_json_response({
      results: SerializeConcepts.([concept_arrays, concept_hashes, concept_strings], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 3,
        unlocked_count: 2,
        events: []
      }
    })
  end

  test "GET index filters by title parameter" do
    Prosopite.finish
    concept_basics = create(:concept, title: "String Basics")
    create(:concept, title: "Arrays")
    concept_advanced = create(:concept, title: "String Advanced")

    Concept::UnlockForUser.(concept_basics, @current_user)
    Concept::UnlockForUser.(concept_advanced, @current_user)

    get internal_concepts_path(title: "String"), as: :json

    assert_response :success
    # All unlocked, ordered alphabetically by title
    assert_json_response({
      results: SerializeConcepts.([concept_advanced, concept_basics], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        unlocked_count: 2,
        events: []
      }
    })
  end

  test "GET index title filter returns all matching with unlocked-first ordering" do
    Prosopite.finish
    concept_basics = create(:concept, title: "String Basics")
    concept_advanced = create(:concept, title: "String Advanced")

    Concept::UnlockForUser.(concept_basics, @current_user)
    # concept_advanced is locked

    get internal_concepts_path(title: "String"), as: :json

    assert_response :success
    # Unlocked first (String Basics), then locked (String Advanced)
    assert_json_response({
      results: SerializeConcepts.([concept_basics, concept_advanced], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        unlocked_count: 1,
        events: []
      }
    })
  end

  test "GET index filters by slugs parameter" do
    Prosopite.finish
    concept_arrays = create(:concept, title: "Arrays", slug: "arrays")
    concept_hashes = create(:concept, title: "Hashes", slug: "hashes")
    create(:concept, title: "Strings", slug: "strings")

    Concept::UnlockForUser.(concept_arrays, @current_user)
    Concept::UnlockForUser.(concept_hashes, @current_user)

    get internal_concepts_path(slugs: "arrays,hashes"), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeConcepts.([concept_arrays, concept_hashes], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        unlocked_count: 2,
        events: []
      }
    })
  end

  test "GET index slugs filter returns all matching with unlocked-first ordering" do
    Prosopite.finish
    concept_arrays = create(:concept, title: "Arrays", slug: "arrays")
    concept_hashes = create(:concept, title: "Hashes", slug: "hashes")

    Concept::UnlockForUser.(concept_arrays, @current_user)
    # concept_hashes is locked

    get internal_concepts_path(slugs: "arrays,hashes"), as: :json

    assert_response :success
    # Unlocked first (Arrays), then locked (Hashes)
    assert_json_response({
      results: SerializeConcepts.([concept_arrays, concept_hashes], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        unlocked_count: 1,
        events: []
      }
    })
  end

  test "GET index supports pagination with page parameter" do
    Prosopite.finish
    concept_a = create(:concept, title: "Concept A")
    concept_b = create(:concept, title: "Concept B")
    concept_c = create(:concept, title: "Concept C")

    Concept::UnlockForUser.(concept_a, @current_user)
    Concept::UnlockForUser.(concept_b, @current_user)
    Concept::UnlockForUser.(concept_c, @current_user)

    get internal_concepts_path(page: 1, per: 2), as: :json

    assert_response :success
    # All unlocked, ordered alphabetically: A, B (first page)
    assert_json_response({
      results: SerializeConcepts.([concept_a, concept_b], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 3,
        unlocked_count: 3,
        events: []
      }
    })
  end

  test "GET index supports pagination with per parameter" do
    Prosopite.finish
    concepts = Array.new(5) { |i| create(:concept, title: "Concept #{i}").tap { |c| Concept::UnlockForUser.(c, @current_user) } }

    get internal_concepts_path(per: 3), as: :json

    assert_response :success
    # All unlocked, ordered alphabetically: Concept 0, 1, 2
    assert_json_response({
      results: SerializeConcepts.([concepts[0], concepts[1], concepts[2]], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 5,
        unlocked_count: 5,
        events: []
      }
    })
  end

  test "GET index returns all concepts when user has no unlocked concepts" do
    Prosopite.finish
    concept_arrays = create(:concept, title: "Arrays")
    concept_strings = create(:concept, title: "Strings")

    get internal_concepts_path, as: :json

    assert_response :success
    # All concepts returned (all locked), ordered alphabetically
    assert_json_response({
      results: SerializeConcepts.([concept_arrays, concept_strings], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        unlocked_count: 0,
        events: []
      }
    })
  end

  # GET /v1/concepts/:slug (show) tests
  test "GET show returns unlocked concept with full details" do
    concept = create(:concept, title: "Arrays")
    Concept::UnlockForUser.(concept, @current_user)

    get internal_concept_path(concept_slug: concept.slug, as: :json), as: :json

    assert_response :success
    assert_json_response({
      concept: SerializeConcept.(concept)
    })
  end

  test "GET show returns 403 for locked concept" do
    concept = create(:concept, title: "Arrays")
    # Not unlocked for user

    get internal_concept_path(concept_slug: concept.slug, as: :json), as: :json

    assert_json_error(:forbidden, error_type: :concept_locked)
  end

  test "GET show returns 404 for non-existent concept" do
    get internal_concept_path(concept_slug: "non-existent-slug"), as: :json

    assert_json_error(:not_found, error_type: :concept_not_found)
  end

  test "GET show works with slug history" do
    concept = create(:concept, slug: "original-slug")
    Concept::UnlockForUser.(concept, @current_user)

    # Change the slug
    concept.update!(slug: "new-slug")

    # Old slug should still work
    get internal_concept_path(concept_slug: "original-slug"), as: :json

    assert_response :success
    assert_json_response({
      concept: SerializeConcept.(concept)
    })
  end

  test "GET show for old slug still respects lock status" do
    concept = create(:concept, slug: "original-slug")
    # Not unlocked for user

    concept.update!(slug: "new-slug")

    get internal_concept_path(concept_slug: "original-slug"), as: :json

    assert_json_error(:forbidden, error_type: :concept_locked)
  end
end
