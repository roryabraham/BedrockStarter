<?php
/**
 * Simple PHP API for Bedrock Starter
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Simple routing
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];

switch ($path) {
    case '/api/status':
        handleStatus();
        break;
    
    case '/api/hello':
        handleHello();
        break;
    
    default:
        http_response_code(404);
        echo json_encode(['error' => 'Endpoint not found']);
        break;
}

function handleStatus() {
    $response = [
        'status' => 'ok',
        'service' => 'bedrock-starter-api',
        'timestamp' => date('c'),
        'php_version' => PHP_VERSION
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT);
}

function handleHello() {
    $name = $_GET['name'] ?? 'World';
    
    $response = [
        'message' => "Hello, {$name}!",
        'from' => 'Bedrock Starter API',
        'timestamp' => date('c')
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT);
}
?>
