require "test_helper"

class Gemini::TranslateTest < ActiveSupport::TestCase
  setup do
    @prompt = "Translate this: Hello World"
  end

  test "successful translation returns parsed JSON" do
    translation_result = {
      subject: "Translated Subject",
      body_mjml: "<mj-text>Translated MJML</mj-text>",
      body_text: "Translated plain text"
    }

    # Mock the Gemini API response
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      to_return(
        status: 200,
        body: {
          candidates: [{
            content: {
              parts: [{
                text: translation_result.to_json
              }]
            }
          }]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Gemini::Translate.(@prompt, model: :flash)

    assert_equal "Translated Subject", result[:subject]
    assert_equal "<mj-text>Translated MJML</mj-text>", result[:body_mjml]
    assert_equal "Translated plain text", result[:body_text]
  end

  test "uses gemini-2.5-flash for :flash model" do
    stub_request(:post, /gemini-2.5-flash:generateContent/).
      to_return(
        status: 200,
        body: {
          candidates: [{
            content: { parts: [{ text: '{"subject":"test","body_mjml":"test","body_text":"test"}' }] }
          }]
        }.to_json
      )

    Gemini::Translate.(@prompt, model: :flash)

    assert_requested :post, /gemini-2.5-flash:generateContent/
  end

  test "uses gemini-2.5-pro for :pro model" do
    stub_request(:post, /gemini-2.5-pro:generateContent/).
      to_return(
        status: 200,
        body: {
          candidates: [{
            content: { parts: [{ text: '{"subject":"test","body_mjml":"test","body_text":"test"}' }] }
          }]
        }.to_json
      )

    Gemini::Translate.(@prompt, model: :pro)

    assert_requested :post, /gemini-2.5-pro:generateContent/
  end

  test "includes thinkingBudget: 0 in request payload" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      with(body: hash_including({
        generationConfig: hash_including({
          thinkingConfig: {
            thinkingBudget: 0
          }
        })
      })).
      to_return(
        status: 200,
        body: {
          candidates: [{
            content: { parts: [{ text: '{"subject":"test","body_mjml":"test","body_text":"test"}' }] }
          }]
        }.to_json
      )

    Gemini::Translate.(@prompt, model: :flash)

    assert_requested :post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent},
      body: hash_including({
        generationConfig: hash_including({
          thinkingConfig: {
            thinkingBudget: 0
          }
        })
      })
  end

  test "includes x-goog-api-key header" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      with(headers: { 'x-goog-api-key' => Jiki.secrets.google_api_key }).
      to_return(
        status: 200,
        body: {
          candidates: [{
            content: { parts: [{ text: '{"subject":"test","body_mjml":"test","body_text":"test"}' }] }
          }]
        }.to_json
      )

    Gemini::Translate.(@prompt, model: :flash)

    assert_requested :post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent},
      headers: { 'x-goog-api-key' => Jiki.secrets.google_api_key }
  end

  test "includes responseMimeType and responseSchema for JSON mode" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      with(body: hash_including({
        generationConfig: hash_including({
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              subject: { type: "string" },
              body_mjml: { type: "string" },
              body_text: { type: "string" }
            },
            required: %w[subject body_mjml body_text]
          }
        })
      })).
      to_return(
        status: 200,
        body: {
          candidates: [{
            content: { parts: [{ text: '{"subject":"test","body_mjml":"test","body_text":"test"}' }] }
          }]
        }.to_json
      )

    Gemini::Translate.(@prompt, model: :flash)

    assert_requested :post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent},
      body: hash_including({
        generationConfig: hash_including({
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              subject: { type: "string" },
              body_mjml: { type: "string" },
              body_text: { type: "string" }
            },
            required: %w[subject body_mjml body_text]
          }
        })
      })
  end

  test "raises RateLimitError on 429 response" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      to_return(status: 429, body: { error: "Rate limit exceeded" }.to_json)

    error = assert_raises Gemini::RateLimitError do
      Gemini::Translate.(@prompt)
    end

    assert_includes error.message, "Rate limit exceeded"
  end

  test "raises InvalidRequestError on 400 response" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      to_return(status: 400, body: { error: "Invalid request" }.to_json)

    error = assert_raises Gemini::InvalidRequestError do
      Gemini::Translate.(@prompt)
    end

    assert_includes error.message, "Invalid request"
  end

  test "raises APIError on other error responses" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      to_return(status: 500, body: { error: "Internal server error" }.to_json)

    error = assert_raises Gemini::APIError do
      Gemini::Translate.(@prompt)
    end

    assert_includes error.message, "API request failed with status 500"
  end

  test "raises InvalidRequestError if LLM response is not valid JSON" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      to_return(
        status: 200,
        body: {
          candidates: [{
            content: { parts: [{ text: "This is not valid JSON" }] }
          }]
        }.to_json
      )

    error = assert_raises Gemini::InvalidRequestError do
      Gemini::Translate.(@prompt)
    end

    assert_includes error.message, "Failed to parse LLM response as JSON"
  end

  test "raises APIError if response has no text" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent}).
      to_return(
        status: 200,
        body: { candidates: [{ content: { parts: [] } }] }.to_json
      )

    error = assert_raises Gemini::APIError do
      Gemini::Translate.(@prompt)
    end

    assert_includes error.message, "No text in response"
  end

  test "raises ArgumentError if prompt is blank" do
    error = assert_raises ArgumentError do
      Gemini::Translate.("", model: :flash)
    end

    assert_equal "prompt is required", error.message
  end

  test "raises ArgumentError if google_api_key is not set" do
    Jiki.secrets.expects(:google_api_key).returns(nil).at_least_once

    error = assert_raises ArgumentError do
      Gemini::Translate.(@prompt, model: :flash)
    end

    assert_equal "google_api_key secret is required", error.message
  end

  test "raises ArgumentError if model is invalid" do
    error = assert_raises ArgumentError do
      Gemini::Translate.(@prompt, model: :invalid)
    end

    assert_equal "model must be :flash or :pro", error.message
  end
end
