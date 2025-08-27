plugins {
    application
    id("com.avast.gradle.docker-compose") version "0.14.2"
    id("com.github.davidmc24.gradle.plugin.avro") version "1.9.1"
}

repositories {
    mavenCentral()
    maven { url = uri("https://packages.confluent.io/maven") }
}

dependencies {
    // Kafka Streams dependencies
    implementation("org.apache.kafka:kafka-streams:3.9.1")
    implementation("org.apache.kafka:kafka-clients:3.9.1")

    // Confluent Avro SerDes and Avro
    implementation("io.confluent:kafka-streams-avro-serde:7.9.1")
    implementation("io.confluent:kafka-avro-serializer:7.9.1")
    implementation("org.apache.avro:avro:1.12.0")

    // Logging dependencies
    implementation("org.slf4j:slf4j-api:2.0.7")
    implementation("ch.qos.logback:logback-classic:1.4.6")


    // Javalin for interactive queries
    implementation("io.javalin:javalin:6.7.0")

    // Jackson for JSON in query service
    implementation("com.fasterxml.jackson.core:jackson-databind:2.16.1")

    // Testing dependencies
    testImplementation("org.junit.jupiter:junit-jupiter-api:5.8.1")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.8.1")

    // Kafka Streams Test Utils
    testImplementation("org.apache.kafka:kafka-streams-test-utils:3.9.1")

    // Schema Registry client provides MockSchemaRegistryClient used by mock:// URL in tests
    testImplementation("io.confluent:kafka-schema-registry-client:7.9.1")
}

application {
    // Define the main class for the application.
    mainClass.set("dev.gamov.query.kafka.movies.WordCountApplication")
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