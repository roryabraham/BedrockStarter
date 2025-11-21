<?php
/**
 * Simple PHP API for Bedrock Starter
 */

declare(strict_types=1);

require __DIR__ . '/vendor/autoload.php';
use Expensify\Bedrock\Client;
use Monolog\Logger;
use Monolog\Handler\SyslogHandler;

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function callBedrock(string $method, array $data = []): array {
    $pluginLogger = new Logger("ToDoApp-plugin");
    $pluginSyslogHandler = new SyslogHandler("todo-app-plugin");
    $pluginLogger->pushHandler($pluginSyslogHandler);
    $client = Client::getInstance([
        'clusterName' => 'todo',
        'mainHostConfigs' => ['127.0.0.1' => ['port' => 8888]],
        'failoverHostConfigs' => ['127.0.0.1' => ['port' => 8888]],
        'connectionTimeout' => 1,
        'readTimeout' => 300,
        'maxBlackListTimeout' => 60,
        'logger' => $pluginLogger,
        'commandPriority' => Client::PRIORITY_NORMAL,
        'bedrockTimeout' => 300,
        'writeConsistency' => 'ASYNC',
        'logParam' =>  null,
        'stats' => null,
    ]);

    try {
        // Log::info("Calling bedrock method $method");
        $response = $client->call($method, $data);
        if ($response["code"] == 200) {
            return $response['body'];
        } else {
            // Log::error('Received error response from bedrock: '.$response['codeLine']);

            // Try to parse status code from error message
            $statusCode = intval($response['codeLine']);
            // Log::error('Got status code: '.$statusCode);
            if ($statusCode > 0) {
                http_response_code($statusCode);
            }

            return ['error' => $response['codeLine']];
        }
    } catch (BedrockError $exception) {
        return ["error" => "Error connecting to Bedrock", "ex" => $exception];
    }
}


// Simple routing
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];

switch ($path) {
    case '/api/status':
        $response = [
            'status' => 'ok',
            'service' => 'bedrock-starter-api',
            'timestamp' => date('c'),
            'php_version' => PHP_VERSION
        ];

        echo json_encode($response, JSON_PRETTY_PRINT);
        break;

    case '/api/hello':
        $name = $_GET['name'] ?? $_POST['name'] ?? 'World';

        echo json_encode(callBedrock("HelloWorld", ["name" => $name]));
        break;

    default:
        http_response_code(404);
        echo json_encode(['error' => 'Endpoint not found']);
        break;
}
