<?php

namespace App\DataFixtures;

use App\Entity\Message;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Faker\Factory;

class AppFixtures extends Fixture
{
    public function load(ObjectManager $manager): void
    {
        $faker = Factory::create();

        for ($i = 0; $i < 100; ++$i) {
            $message = new Message();
            $message->setTitle($faker->sentence);
            $message->setBody($faker->paragraph);
            $manager->persist($message);
        }

        $manager->flush();
    }
}
