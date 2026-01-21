import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json({
    paymentIntentId: "pi_mock_123",
    status: "requires_confirmation",
    nextAction: "client_secret_provided",
    receiptUrl: "https://example.com/receipt/mock"
  });
}

