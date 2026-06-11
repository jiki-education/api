class Exercism::FetchUserStatus
  include Mandate

  initialize_with :exercism_id

  def call
    response = HTTParty.get(
      "#{Jiki.config.exercism_base_url}/api/v2/jiki/user_status/#{exercism_id}",
      headers: { "Authorization" => "Bearer #{Jiki.secrets.exercism_api_key}" }
    )

    raise FetchExercismUserStatusesError, "Exercism returned #{response.code}: #{response.body}" unless response.success?

    {
      'is_insider' => response.parsed_response['is_insider'] == true,
      'is_bootcamp_member' => response.parsed_response['is_bootcamp_member'] == true
    }
  end
end
