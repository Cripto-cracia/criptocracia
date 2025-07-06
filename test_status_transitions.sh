#!/bin/bash

echo "🧪 Testing Automatic Election Status Transitions"

# Start EC service in background
echo "📡 Starting EC service..."
cargo run --bin ec > ec_status_test.log 2>&1 &
EC_PID=$!

# Wait for service to start
echo "⏳ Waiting for EC service to start..."
sleep 3

# Check if gRPC port is listening
if ! netstat -an | grep -q ":50001.*LISTEN"; then
    echo "❌ gRPC server not listening on port 50001"
    kill $EC_PID 2>/dev/null
    exit 1
fi

echo "✅ EC service started successfully"

# Create election with start time in 30 seconds
echo "🗳️ Creating election with start time in 30 seconds..."
cargo run --example grpc_client > client_status_test.log 2>&1

CLIENT_EXIT_CODE=$?

if [ $CLIENT_EXIT_CODE -eq 0 ]; then
    echo "✅ Election created successfully"
    echo "⏳ Waiting 90 seconds to observe status transitions..."
    
    # Wait and check logs for status changes
    for i in {1..9}; do
        sleep 10
        echo "📊 Checking status transitions... (${i}0s)"
        
        # Check for status change logs
        if grep -q "status changed to" ec_status_test.log; then
            echo "✅ Status transition detected!"
            grep "status changed to" ec_status_test.log
        fi
        
        # Check for Nostr publishing logs
        if grep -q "Publishing election.*status" ec_status_test.log; then
            echo "✅ Nostr publishing detected!"
            grep "Publishing election.*status" ec_status_test.log
        fi
    done
    
    echo "📋 Final status check:"
    grep -E "(status changed|Publishing election)" ec_status_test.log | tail -5
else
    echo "❌ Failed to create election"
    cat client_status_test.log
fi

# Cleanup
echo "🧹 Cleaning up..."
kill $EC_PID 2>/dev/null
wait $EC_PID 2>/dev/null

echo "🎉 Test completed"