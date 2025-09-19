<?php

namespace App\Tests\Api;

use ApiPlatform\Symfony\Bundle\Test\ApiTestCase;

class MessageTest extends ApiTestCase
{
    public function testGetCollection(): void
    {
        $client = static::createClient();
        $response = $client->request('GET', '/api/messages');

        $this->assertResponseIsSuccessful();
        $this->assertResponseHeaderSame('content-type', 'application/ld+json; charset=utf-8');

        $this->assertJsonContains([
            '@context' => '/api/contexts/Message',
            '@id' => '/api/messages',
            '@type' => 'Collection',
            'totalItems' => 100,
        ]);
    }

    public function testFilterByTitle(): void
    {
        $client = static::createClient();
        // First, find a message to get a title to filter by
        $response = $client->request('GET', '/api/messages');
        $messages = $response->toArray()['member'];
        $this->assertNotEmpty($messages);

        $titleToFilter = $messages[0]['title'];

        // Now, filter by that title
        $response = $client->request('GET', '/api/messages', ['query' => ['title' => $titleToFilter]]);
        $this->assertResponseIsSuccessful();
        $this->assertJsonContains(['@type' => 'Collection']);

        $filteredMessages = $response->toArray()['member'];
        $this->assertNotEmpty($filteredMessages);

        foreach ($filteredMessages as $message) {
            $this->assertStringContainsString($titleToFilter, $message['title']);
        }
    }
}
