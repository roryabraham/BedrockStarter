<?php

declare(strict_types=1);

namespace BedrockStarter;

use Monolog\Handler\SyslogHandler;
use Monolog\Logger;

class Log
{
    private static ?Logger $instance = null;

    private static function getInstance(): Logger
    {
        if (self::$instance === null) {
            self::$instance = new Logger('BedrockStarterApi');
            self::$instance->pushHandler(new SyslogHandler('bedrock-starter-api'));
        }
        return self::$instance;
    }

    public static function debug(string $message, array $context = []): void
    {
        self::getInstance()->debug($message, $context);
    }

    public static function info(string $message, array $context = []): void
    {
        self::getInstance()->info($message, $context);
    }

    public static function warn(string $message, array $context = []): void
    {
        self::getInstance()->warning($message, $context);
    }

    public static function error(string $message, array $context = []): void
    {
        self::getInstance()->error($message, $context);
    }
}


