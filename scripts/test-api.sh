#!/bin/bash

# Todo API Local Test Script
# This script tests all CRUD operations against the local Azure Functions app

set -e

BASE_URL="${BASE_URL:-http://localhost:7071}"
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

print_test() {
    echo -e "\n${YELLOW}TEST: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ PASSED: $1${NC}"
    PASSED=$((PASSED + 1))
}

print_failure() {
    echo -e "${RED}✗ FAILED: $1${NC}"
    echo -e "${RED}  Expected: $2${NC}"
    echo -e "${RED}  Got: $3${NC}"
    FAILED=$((FAILED + 1))
}

check_status() {
    local expected=$1
    local actual=$2
    local test_name=$3
    
    if [ "$actual" -eq "$expected" ]; then
        print_success "$test_name (Status: $actual)"
        return 0
    else
        print_failure "$test_name" "Status $expected" "Status $actual"
        return 1
    fi
}

# Wait for the function app to be ready
wait_for_app() {
    print_header "Waiting for Function App to be ready..."
    
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/todoitems" 2>/dev/null | grep -q "200\|404"; then
            echo -e "${GREEN}Function App is ready!${NC}"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts - waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}Function App did not start in time${NC}"
    exit 1
}

# Test 1: Get all todos (should be empty or have existing items)
test_get_all_initial() {
    print_test "GET /todoitems - Get all todos"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/todoitems")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    check_status 200 "$status" "Get all todos"
    echo "Response: $body"
}

# Test 2: Create a todo item
test_create_todo() {
    print_test "POST /todoitems - Create todo"
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/todoitems" \
        -H "Content-Type: application/json" \
        -d '{"name": "Test Item 1", "isComplete": false}')
    
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    check_status 201 "$status" "Create todo"
    echo "Response: $body"
    
    # Extract ID from response
    CREATED_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    echo "Created ID: $CREATED_ID"
}

# Test 3: Get todo by ID
test_get_by_id() {
    print_test "GET /todoitems/{id} - Get todo by ID"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/todoitems/$CREATED_ID")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    check_status 200 "$status" "Get todo by ID"
    echo "Response: $body"
}

# Test 4: Update todo (mark as complete)
test_update_todo() {
    print_test "PUT /todoitems/{id} - Update todo"
    
    response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/todoitems/$CREATED_ID" \
        -H "Content-Type: application/json" \
        -d '{"name": "Test Item 1 - Updated", "isComplete": true}')
    
    status=$(echo "$response" | tail -n1)
    
    check_status 204 "$status" "Update todo"
}

# Test 5: Get completed todos
test_get_complete() {
    print_test "GET /todoitems/complete - Get completed todos"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/todoitems/complete")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    check_status 200 "$status" "Get completed todos"
    echo "Response: $body"
    
    # Verify our updated item is in the list
    if echo "$body" | grep -q "Test Item 1 - Updated"; then
        print_success "Updated item found in completed list"
    else
        print_failure "Updated item in completed list" "Item present" "Item not found"
    fi
}

# Test 6: Delete todo
test_delete_todo() {
    print_test "DELETE /todoitems/{id} - Delete todo"
    
    response=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/todoitems/$CREATED_ID")
    status=$(echo "$response" | tail -n1)
    
    check_status 204 "$status" "Delete todo"
}

# Test 7: Verify deletion
test_verify_deletion() {
    print_test "GET /todoitems/{id} - Verify deletion (expect 404)"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/todoitems/$CREATED_ID")
    status=$(echo "$response" | tail -n1)
    
    check_status 404 "$status" "Verify deletion returns 404"
}

# Test 8: Get non-existent todo
test_get_nonexistent() {
    print_test "GET /todoitems/99999 - Get non-existent todo"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/todoitems/99999")
    status=$(echo "$response" | tail -n1)
    
    check_status 404 "$status" "Get non-existent todo returns 404"
}

# Test 9: Update non-existent todo
test_update_nonexistent() {
    print_test "PUT /todoitems/99999 - Update non-existent todo"
    
    response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/todoitems/99999" \
        -H "Content-Type: application/json" \
        -d '{"name": "Non-existent", "isComplete": false}')
    
    status=$(echo "$response" | tail -n1)
    
    check_status 404 "$status" "Update non-existent todo returns 404"
}

# Test 10: Delete non-existent todo
test_delete_nonexistent() {
    print_test "DELETE /todoitems/99999 - Delete non-existent todo"
    
    response=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/todoitems/99999")
    status=$(echo "$response" | tail -n1)
    
    check_status 404 "$status" "Delete non-existent todo returns 404"
}

# Print summary
print_summary() {
    print_header "TEST SUMMARY"
    
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    
    total=$((PASSED + FAILED))
    echo "Total: $total"
    
    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Main execution
main() {
    print_header "Todo API Test Suite"
    echo "Base URL: $BASE_URL"
    
    # Check if we should wait for the app
    if [ "$1" != "--no-wait" ]; then
        wait_for_app
    fi
    
    # Run tests
    test_get_all_initial
    test_create_todo
    test_get_by_id
    test_update_todo
    test_get_complete
    test_delete_todo
    test_verify_deletion
    test_get_nonexistent
    test_update_nonexistent
    test_delete_nonexistent
    
    # Summary
    print_summary
}

# Run main with all arguments
main "$@"

