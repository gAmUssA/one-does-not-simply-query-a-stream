plugins {
    application
    id("com.avast.gradle.docker-compose") version "0.14.2"
}

repositories {
    mavenCentral()
}

dependencies {
    // Kafka Streams dependencies
    //TODO versions
    implementation("org.apache.kafka:kafka-streams:3.5.0")
    implementation("org.apache.kafka:kafka-clients:3.5.0")

    // Logging dependencies
    implementation("org.slf4j:slf4j-api:2.0.7")
    implementation("ch.qos.logback:logback-classic:1.4.6")
    // Spark Java for REST service
    implementation("com.sparkjava:spark-core:2.9.3")

    // Testing dependencies
    testImplementation("org.junit.jupiter:junit-jupiter-api:5.8.1")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.8.1")

    // Kafka Streams Test Utils
    testImplementation("org.apache.kafka:kafka-streams-test-utils:3.5.0")
}

application {
    // Define the main class for the application.
    mainClass.set("ai.startree.dev.query.kafka.WordCountApplication")
}

tasks.named<Test>("test") {
    // Use JUnit Platform for unit tests.
    useJUnitPlatform()
}

dockerCompose {
    useComposeFiles = listOf("docker-compose.yml")
    stopContainers = true
}

tasks.named<Task>("run") {
    dependsOn("composeUp")
}