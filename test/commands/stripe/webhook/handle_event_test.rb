require "test_helper"

class Stripe::Webhook::HandleEventTest < ActiveSupport::TestCase
  test "routes checkout.session.completed event" do
    payload = '{"type":"checkout.session.completed"}'
    signature = "sig_123"

    event = mock
    event.stubs(:type).returns('checkout.session.completed')
    event.stubs(:data).returns(stub(object: stub(mode: 'subscription')))

    ::Stripe::Webhook.expects(:construct_event).
      with(payload, signature, Jiki.secrets.stripe_webhook_secret).
      returns(event)

    Stripe::Webhook::CheckoutCompleted.expects(:call).with(event)
    Stripe::Webhook::PurchaseCompleted.expects(:call).never

    Stripe::Webhook::HandleEvent.(payload, signature)
  end

  test "routes payment-mode checkout.session.completed to the premium purchase handler" do
    event = stub(type: 'checkout.session.completed', data: stub(object: stub(mode: 'payment')))
    ::Stripe::Webhook.expects(:construct_event).returns(event)

    Stripe::Webhook::PurchaseCompleted.expects(:call).with(event)
    Stripe::Webhook::CheckoutCompleted.expects(:call).never

    Stripe::Webhook::HandleEvent.("{}", "sig_123")
  end

  test "routes checkout.session.async_payment_succeeded event" do
    event = stub(type: 'checkout.session.async_payment_succeeded')
    ::Stripe::Webhook.expects(:construct_event).returns(event)

    Stripe::Webhook::PurchaseCompleted.expects(:call).with(event)

    Stripe::Webhook::HandleEvent.("{}", "sig_123")
  end

  test "routes checkout.session.async_payment_failed event" do
    event = stub(type: 'checkout.session.async_payment_failed')
    ::Stripe::Webhook.expects(:construct_event).returns(event)

    Stripe::Webhook::PurchaseFailed.expects(:call).with(event)

    Stripe::Webhook::HandleEvent.("{}", "sig_123")
  end

  test "routes charge.refunded event" do
    event = stub(type: 'charge.refunded')
    ::Stripe::Webhook.expects(:construct_event).returns(event)

    Stripe::Webhook::ChargeRefunded.expects(:call).with(event)

    Stripe::Webhook::HandleEvent.("{}", "sig_123")
  end

  test "routes charge.dispute.created event" do
    event = stub(type: 'charge.dispute.created')
    ::Stripe::Webhook.expects(:construct_event).returns(event)

    Stripe::Webhook::DisputeCreated.expects(:call).with(event)

    Stripe::Webhook::HandleEvent.("{}", "sig_123")
  end

  test "routes customer.subscription.created event" do
    payload = '{"type":"customer.subscription.created"}'
    signature = "sig_123"

    event = mock
    event.stubs(:type).returns('customer.subscription.created')

    ::Stripe::Webhook.expects(:construct_event).returns(event)
    Stripe::Webhook::SubscriptionCreated.expects(:call).with(event)

    Stripe::Webhook::HandleEvent.(payload, signature)
  end

  test "routes invoice.payment_failed event" do
    payload = '{"type":"invoice.payment_failed"}'
    signature = "sig_123"

    event = mock
    event.stubs(:type).returns('invoice.payment_failed')

    ::Stripe::Webhook.expects(:construct_event).returns(event)
    Stripe::Webhook::InvoicePaymentFailed.expects(:call).with(event)

    Stripe::Webhook::HandleEvent.(payload, signature)
  end

  test "logs unhandled event types" do
    payload = '{"type":"unknown.event"}'
    signature = "sig_123"

    event = mock
    event.stubs(:type).returns('unknown.event')

    ::Stripe::Webhook.expects(:construct_event).returns(event)

    Rails.logger.expects(:info).with("Unhandled Stripe webhook event: unknown.event")

    Stripe::Webhook::HandleEvent.(payload, signature)
  end
end
