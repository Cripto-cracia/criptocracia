#!/bin/bash

echo "🔍 Verifying Status Transition Implementation"

# Start fresh to ensure clean test
rm -f ec/app.log ec/elections.db

# Start EC service in background  
echo "📡 Starting EC service..."
cargo run --bin ec > /tmp/ec_verify.log 2>&1 &
EC_PID=$!

sleep 5

# Create election starting in 30 seconds
echo "🗳️ Creating election with start time in 30 seconds..."
timeout 30s cargo run --example grpc_client > /tmp/client_verify.log 2>&1

sleep 5

echo "⏳ Waiting 60 seconds for status transition..."
sleep 60

# Check logs for status transitions
echo "📋 Checking for status transitions in logs..."
if grep -q "status changed to" /tmp/ec_verify.log; then
    echo "✅ Status transition detected!"
    grep "status changed to" /tmp/ec_verify.log
else
    echo "❌ No status transition found in logs"
    echo "📋 Recent EC logs:"
    tail -20 /tmp/ec_verify.log
fi

# Cleanup
kill $EC_PID 2>/dev/null
wait $EC_PID 2>/dev/null

echo "🎉 Verification complete"