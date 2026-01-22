import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { amount } = body;

    // Mock Stripe PaymentIntent creation
    // In real app: const paymentIntent = await stripe.paymentIntents.create({ amount, currency: 'usd' })

    await new Promise(resolve => setTimeout(resolve, 1000));

    if (amount <= 0) throw new Error("Invalid amount");

    return NextResponse.json({
      success: true,
      clientSecret: "pi_mock_secret_" + Math.random().toString(36),
      message: `Payment of $${amount} simulated successfully.`
    });

  } catch (error) {
    return NextResponse.json({ error: "Payment failed" }, { status: 400 });
  }
}

