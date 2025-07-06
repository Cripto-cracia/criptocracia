#!/bin/bash

echo "🧪 Testing Voter Authorization Fix"

# Clean start
rm -f ec/app.log ec/elections.db

# Start EC service in background
echo "📡 Starting EC service..."
cargo run --bin ec > /tmp/ec_auth_test.log 2>&1 &
EC_PID=$!

sleep 3

# Create election and add voters
echo "🗳️ Creating election and adding voters..."
cargo run --example grpc_client > /tmp/client_auth_test.log 2>&1

echo "📋 Checking for voter registration in logs..."

# Check if voters were successfully registered
if grep -q "Registering voter" /tmp/ec_auth_test.log; then
    echo "✅ Found voter registration messages in logs:"
    grep "Registering voter" /tmp/ec_auth_test.log
else
    echo "⚠️ No explicit voter registration messages found"
fi

# Check if voters were added to in-memory election
if grep -q "Added voter.*in-memory" /tmp/ec_auth_test.log; then
    echo "✅ Found in-memory voter addition messages:"
    grep "Added voter.*in-memory" /tmp/ec_auth_test.log
else
    echo "⚠️ No in-memory voter addition messages found"
fi

# Check for any authorization errors
if grep -q "not authorized for any election" /tmp/ec_auth_test.log; then
    echo "❌ Still found authorization errors:"
    grep "not authorized for any election" /tmp/ec_auth_test.log
else
    echo "✅ No authorization errors found - fix appears successful!"
fi

# Cleanup
kill $EC_PID 2>/dev/null
wait $EC_PID 2>/dev/null

echo "📊 Test Summary:"
echo "- Client result: $(grep -q "🎉 Demo complete" /tmp/client_auth_test.log && echo "✅ Success" || echo "❌ Failed")"
echo "- Authorization errors: $(grep -q "not authorized for any election" /tmp/ec_auth_test.log && echo "❌ Found errors" || echo "✅ No errors")"

echo "🎉 Test completed"